#!/usr/bin/env python3
"""
Xray集群管理 - Node Agent
负责与Master通信，管理本地Xray服务
"""

import os
import json
import hashlib
import hmac
import subprocess
import time
from datetime import datetime
from flask import Flask, request, jsonify, make_response
import requests
import threading
import logging
import re

# 配置日志
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 环境变量配置
NODE_UUID = os.environ.get('NODE_UUID', '')
CLUSTER_SECRET = os.environ.get('CLUSTER_SECRET', '')
MASTER_DOMAIN = os.environ.get('MASTER_DOMAIN', '')
API_PATH = os.environ.get('API_PATH', '')

# Flask应用
app = Flask(__name__)

# 节点状态
node_status = {
    'node_id': None,
    'api_secret': None,
    'registered': False,
    'last_heartbeat': None,
    'xray_status': 'unknown'
}

def sanitize_input(input_str, allowed_pattern=r'^[a-zA-Z0-9_\-\.\/]+$'):
    """输入验证和清理"""
    if not input_str:
        return None
    
    # 移除危险字符
    input_str = input_str.strip()
    
    # 验证模式
    if not re.match(allowed_pattern, input_str):
        logger.warning(f"输入验证失败: {input_str}")
        return None
    
    # 防止路径遍历
    if '..' in input_str or '//' in input_str:
        logger.warning(f"检测到路径遍历尝试: {input_str}")
        return None
    
    return input_str

def safe_execute_command(cmd, timeout=30):
    """安全执行命令，防止命令注入"""
    # 命令白名单验证
    allowed_commands = ['docker-compose', 'docker', 'ps', 'restart', 'logs']
    
    cmd_parts = cmd.split()
    if not cmd_parts:
        return False, "Empty command"
    
    # 验证基础命令
    base_cmd = cmd_parts[0]
    if base_cmd not in allowed_commands:
        return False, f"Command not allowed: {base_cmd}"
    
    # 验证参数
    for part in cmd_parts[1:]:
        if not sanitize_input(part):
            return False, f"Invalid parameter: {part}"
    
    try:
        result = subprocess.run(
            cmd_parts,
            capture_output=True,
            text=True,
            timeout=timeout,
            shell=False  # 重要：不使用 shell=True
        )
        
        if result.returncode == 0:
            return True, result.stdout
        else:
            return False, result.stderr
            
    except subprocess.TimeoutExpired:
        return False, "Command timeout"
    except Exception as e:
        return False, str(e)

def verify_signature(data, signature):
    """验证HMAC签名"""
    if not node_status['api_secret']:
        return False
    
    expected_signature = hmac.new(
        node_status['api_secret'].encode(),
        json.dumps(data, sort_keys=True).encode(),
        hashlib.sha256
    ).hexdigest()
    
    return hmac.compare_digest(expected_signature, signature)

def get_xray_status():
    """获取Xray服务状态"""
    try:
        result = subprocess.run(
            ['docker', 'ps', '--filter', 'name=xray-node-xray', '--format', '{{.Status}}'],
            capture_output=True,
            text=True,
            timeout=10,
            shell=False
        )
        
        if result.returncode == 0 and result.stdout.strip():
            if 'Up' in result.stdout:
                return 'running'
            else:
                return 'stopped'
        return 'unknown'
    except Exception as e:
        logger.error(f"获取Xray状态失败: {e}")
        return 'error'

def get_xray_stats():
    """获取Xray统计信息"""
    # 这里可以通过Xray API获取统计信息
    # 暂时返回模拟数据
    return {
        'uptime': int(time.time()),
        'connections': 0,
        'traffic_up': 0,
        'traffic_down': 0
    }

def register_to_master():
    """向Master注册节点"""
    try:
        base_url = MASTER_DOMAIN if "://" in MASTER_DOMAIN else f"https://{MASTER_DOMAIN}"
        url = f"{base_url}/api/node/register"
        data = {
            'token': NODE_UUID,
            'timestamp': int(time.time())
        }
        
        response = requests.post(url, json=data, timeout=30, verify=True)
        
        if response.status_code == 200:
            config = response.json()
            node_status['node_id'] = config.get('node_id')
            node_status['api_secret'] = config.get('api_secret')
            node_status['registered'] = True
            logger.info(f"成功注册到Master，节点ID: {node_status['node_id']}")
            return True
        else:
            logger.error(f"注册失败: {response.status_code} - {response.text}")
            return False
            
    except Exception as e:
        logger.error(f"注册到Master失败: {e}")
        return False

def send_heartbeat():
    """发送心跳到Master"""
    if not node_status['registered']:
        logger.warning("节点未注册，跳过心跳")
        return False
    
    try:
        base_url = MASTER_DOMAIN if "://" in MASTER_DOMAIN else f"https://{MASTER_DOMAIN}"
        url = f"{base_url}/api/node/heartbeat"
        data = {
            'node_id': node_status['node_id'],
            'api_secret': node_status['api_secret'],
            'timestamp': int(time.time()),
            'stats': get_xray_stats()
        }
        
        response = requests.post(url, json=data, timeout=30, verify=True)
        
        if response.status_code == 200:
            node_status['last_heartbeat'] = datetime.utcnow()
            logger.debug("心跳发送成功")
            return True
        else:
            logger.error(f"心跳发送失败: {response.status_code}")
            return False
            
    except Exception as e:
        logger.error(f"发送心跳失败: {e}")
        return False

def heartbeat_loop():
    """心跳循环线程"""
    while True:
        try:
            if not node_status['registered']:
                logger.info("尝试注册到Master...")
                register_to_master()
            else:
                send_heartbeat()
            
            # 更新Xray状态
            node_status['xray_status'] = get_xray_status()
            
        except Exception as e:
            logger.error(f"心跳循环错误: {e}")
        
        time.sleep(60)  # 每60秒发送一次心跳

# API路由
@app.route('/health', methods=['GET'])
def health_check():
    """健康检查"""
    return jsonify({
        'status': 'ok',
        'registered': node_status['registered'],
        'xray_status': node_status['xray_status'],
        'timestamp': int(time.time())
    })

@app.route('/api/restart', methods=['POST'])
def restart_xray():
    """重启Xray服务"""
    data = request.json
    if not data:
        return jsonify({'error': 'Invalid JSON'}), 400
    
    signature = request.headers.get('X-Signature')
    if not signature or not verify_signature(data, signature):
        return jsonify({'error': 'Invalid signature'}), 401
    
    logger.info("收到重启Xray指令")
    
    success, output = safe_execute_command('docker-compose restart xray')
    
    if success:
        return jsonify({'status': 'ok', 'message': 'Xray重启成功'})
    else:
        return jsonify({'status': 'error', 'message': output}), 500

@app.route('/api/config', methods=['POST'])
def update_config():
    """更新Xray配置"""
    data = request.json
    if not data:
        return jsonify({'error': 'Invalid JSON'}), 400
    
    signature = request.headers.get('X-Signature')
    if not signature or not verify_signature(data, signature):
        return jsonify({'error': 'Invalid signature'}), 401
    
    config = data.get('config')
    if not config:
        return jsonify({'error': 'Missing config'}), 400
    
    try:
        # 验证配置格式
        json.loads(config)
        
        # 保存配置文件
        with open('/app/config/config.json', 'w') as f:
            f.write(config)
        
        # 重启Xray应用配置
        success, output = safe_execute_command('docker-compose restart xray')
        
        if success:
            return jsonify({'status': 'ok', 'message': '配置更新成功'})
        else:
            return jsonify({'status': 'error', 'message': output}), 500
            
    except json.JSONDecodeError:
        return jsonify({'error': 'Invalid JSON config'}), 400
    except Exception as e:
        logger.error(f"更新配置失败: {e}")
        return jsonify({'error': str(e)}), 500

@app.route('/api/logs', methods=['POST'])
def get_logs():
    """获取Xray日志"""
    data = request.json
    if not data:
        return jsonify({'error': 'Invalid JSON'}), 400
    
    signature = request.headers.get('X-Signature')
    if not signature or not verify_signature(data, signature):
        return jsonify({'error': 'Invalid signature'}), 401
    
    lines = data.get('lines', 100)
    if not isinstance(lines, int) or lines < 1 or lines > 1000:
        lines = 100
    
    success, output = safe_execute_command(f'docker logs --tail {lines} xray-node-xray')
    
    if success:
        return jsonify({'status': 'ok', 'logs': output})
    else:
        return jsonify({'status': 'error', 'message': output}), 500

@app.route('/api/stats', methods=['POST'])
def get_stats():
    """获取统计信息"""
    data = request.json
    if not data:
        return jsonify({'error': 'Invalid JSON'}), 400
    
    signature = request.headers.get('X-Signature')
    if not signature or not verify_signature(data, signature):
        return jsonify({'error': 'Invalid signature'}), 401
    
    stats = get_xray_stats()
    stats['xray_status'] = get_xray_status()
    
    return jsonify({'status': 'ok', 'stats': stats})

if __name__ == '__main__':
    # 启动心跳线程
    heartbeat_thread = threading.Thread(target=heartbeat_loop, daemon=True)
    heartbeat_thread.start()
    
    logger.info("Node Agent启动")
    logger.info(f"Master域名: {MASTER_DOMAIN}")
    logger.info(f"节点UUID: {NODE_UUID}")
    
    # 运行Flask应用
    app.run(host='0.0.0.0', port=8080, debug=False)
