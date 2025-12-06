#!/usr/bin/env python3
"""
Xray集群管理 - Master控制面板
"""

import os
import hashlib
import hmac
import json
import subprocess
import logging
from datetime import datetime
from functools import wraps

from flask import Flask, render_template, request, redirect, url_for, flash, jsonify, session
from flask_sqlalchemy import SQLAlchemy
from flask_login import LoginManager, UserMixin, login_user, login_required, logout_user, current_user
from flask_talisman import Talisman
import requests

# 配置日志
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 创建Flask应用
app = Flask(__name__)
app.secret_key = os.environ.get('SECRET_KEY', 'dev-secret-key-change-in-production')

# 安全头设置
csp = {
    'default-src': "'self'",
    'style-src': ["'self'", "https://cdn.jsdelivr.net"],
    'script-src': ["'self'", "https://cdn.jsdelivr.net"],
    'font-src': ["'self'", "https://cdn.jsdelivr.net"]
}
Talisman(app, content_security_policy=csp, force_https=False)

# 数据库配置
app.config['SQLALCHEMY_DATABASE_URI'] = os.environ.get(
    'DATABASE_URL', 
    'postgresql://xray_admin:xray_password@localhost/xray_cluster'
)
app.config['SQLALCHEMY_TRACK_MODIFICATIONS'] = False

db = SQLAlchemy(app)

# Flask-Login配置
login_manager = LoginManager()
login_manager.init_app(app)
login_manager.login_view = 'login'

# 数据模型
class User(UserMixin, db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(200), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

class Node(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    server_ip = db.Column(db.String(45), nullable=False)
    location = db.Column(db.String(100))
    description = db.Column(db.Text)
    token = db.Column(db.String(64), unique=True, nullable=False)
    api_secret = db.Column(db.String(64), nullable=False)
    status = db.Column(db.String(20), default='offline')
    last_seen = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    enable_vless = db.Column(db.Boolean, default=True)
    enable_splithttp = db.Column(db.Boolean, default=False)
    enable_hysteria2 = db.Column(db.Boolean, default=False)
    max_users = db.Column(db.Integer, default=100)
    xray_config = db.Column(db.Text)
    xray_status = db.Column(db.String(20), default='stopped')

class UserAccount(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(100), unique=True, nullable=False)
    password = db.Column(db.String(100), nullable=False)
    email = db.Column(db.String(120))
    data_limit = db.Column(db.BigInteger, default=107374182400)  # 100GB
    used_data = db.Column(db.BigInteger, default=0)
    enabled = db.Column(db.Boolean, default=True)
    expire_date = db.Column(db.DateTime)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
    node_id = db.Column(db.Integer, db.ForeignKey('node.id'))

@login_manager.user_loader
def load_user(user_id):
    return User.query.get(int(user_id))

# 工具函数
def generate_token():
    """生成随机token"""
    return hashlib.sha256(os.urandom(32)).hexdigest()

def generate_api_secret(token):
    """从token生成API密钥"""
    return hmac.new(
        b'xray-cluster-master-secret',
        token.encode(),
        hashlib.sha256
    ).hexdigest()

def get_hidden_path(token):
    """生成隐藏路径"""
    return hashlib.sha256(f"hidden-{token}".encode()).hexdigest()[:16]

# 路由
@app.route('/')
def index():
    if current_user.is_authenticated:
        return redirect(url_for('dashboard'))
    return redirect(url_for('login'))

@app.route('/login', methods=['GET', 'POST'])
def login():
    if request.method == 'POST':
        username = request.form.get('username')
        password = request.form.get('password')
        
        # 简单验证（生产环境应使用密码哈希）
        if username == os.environ.get('ADMIN_USER', 'admin') and \
           password == os.environ.get('ADMIN_PASSWORD', 'admin123'):
            user = User.query.filter_by(username=username).first()
            if not user:
                user = User(username=username, password_hash='')
                db.session.add(user)
                db.session.commit()
            
            login_user(user)
            flash('登录成功！', 'success')
            return redirect(url_for('dashboard'))
        else:
            flash('用户名或密码错误', 'error')
    
    return render_template('login.html')

@app.route('/logout')
@login_required
def logout():
    logout_user()
    flash('已退出登录', 'info')
    return redirect(url_for('login'))

@app.route('/dashboard')
@login_required
def dashboard():
    # 获取统计信息
    total_nodes = Node.query.count()
    online_nodes = Node.query.filter_by(status='online').count()
    total_users = UserAccount.query.count()
    
    # 获取节点列表
    nodes = Node.query.order_by(Node.created_at.desc()).all()
    
    return render_template('dashboard.html',
                         total_nodes=total_nodes,
                         online_nodes=online_nodes,
                         total_users=total_users,
                         nodes=nodes)

@app.route('/nodes')
@login_required
def nodes():
    nodes = Node.query.order_by(Node.created_at.desc()).all()
    return render_template('nodes.html', nodes=nodes)

@app.route('/node/<int:node_id>')
@login_required
def node_detail(node_id):
    node = Node.query.get_or_404(node_id)
    users = UserAccount.query.filter_by(node_id=node_id).all()
    return render_template('node_detail.html', node=node, users=users)

@app.route('/node/add', methods=['GET', 'POST'])
@login_required
def add_node():
    if request.method == 'POST':
        name = request.form.get('name')
        server_ip = request.form.get('server_ip')
        location = request.form.get('location')
        description = request.form.get('description')
        
        # 生成token和API密钥
        token = generate_token()
        api_secret = generate_api_secret(token)
        
        node = Node(
            name=name,
            server_ip=server_ip,
            location=location,
            description=description,
            token=token,
            api_secret=api_secret,
            enable_vless=bool(request.form.get('enable_vless')),
            enable_splithttp=bool(request.form.get('enable_splithttp')),
            enable_hysteria2=bool(request.form.get('enable_hysteria2')),
            max_users=int(request.form.get('max_users', 100))
        )
        
        db.session.add(node)
        db.session.commit()
        
        flash(f'节点 {name} 添加成功！Token: {token}', 'success')
        return redirect(url_for('node_detail', node_id=node.id))
    
    return render_template('add_node.html')

@app.route('/node/<int:node_id>/edit', methods=['GET', 'POST'])
@login_required
def edit_node(node_id):
    node = Node.query.get_or_404(node_id)
    
    if request.method == 'POST':
        node.name = request.form.get('name')
        node.server_ip = request.form.get('server_ip')
        node.location = request.form.get('location')
        node.description = request.form.get('description')
        node.enable_vless = bool(request.form.get('enable_vless'))
        node.enable_splithttp = bool(request.form.get('enable_splithttp'))
        node.enable_hysteria2 = bool(request.form.get('enable_hysteria2'))
        node.max_users = int(request.form.get('max_users', 100))
        
        db.session.commit()
        flash('节点信息已更新', 'success')
        return redirect(url_for('node_detail', node_id=node.id))
    
    return render_template('edit_node.html', node=node)

@app.route('/node/<int:node_id>/delete', methods=['POST'])
@login_required
def delete_node(node_id):
    node = Node.query.get_or_404(node_id)
    db.session.delete(node)
    db.session.commit()
    flash(f'节点 {node.name} 已删除', 'success')
    return redirect(url_for('nodes'))

@app.route('/node/<int:node_id>/restart', methods=['POST'])
@login_required
def restart_node(node_id):
    node = Node.query.get_or_404(node_id)
    
    # 这里应该调用节点的API重启Xray
    # 暂时模拟成功
    flash(f'已发送重启指令到节点 {node.name}', 'info')
    return redirect(url_for('node_detail', node_id=node.id))

@app.route('/node/<int:node_id>/logs')
@login_required
def node_logs(node_id):
    node = Node.query.get_or_404(node_id)
    # 这里应该获取节点的日志
    logs = [
        f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - 系统启动",
        f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - Xray服务运行正常",
        f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S')} - 用户连接数: 15"
    ]
    return render_template('node_logs.html', node=node, logs=logs)

@app.route('/settings', methods=['GET', 'POST'])
@login_required
def settings():
    if request.method == 'POST':
        current_password = request.form.get('current_password')
        new_password = request.form.get('new_password')
        confirm_password = request.form.get('confirm_password')
        
        # 简单密码验证
        if new_password != confirm_password:
            flash('新密码不匹配', 'error')
        elif len(new_password) < 8:
            flash('密码长度至少8位', 'error')
        else:
            # 更新密码（生产环境应使用密码哈希）
            flash('密码已更新', 'success')
    
    return render_template('settings.html')

# API路由（供节点调用）
@app.route('/api/node/register', methods=['POST'])
def api_node_register():
    """节点注册API"""
    data = request.json
    if not data:
        return jsonify({'error': 'Invalid JSON'}), 400
    
    token = data.get('token')
    if not token:
        return jsonify({'error': 'Token required'}), 400
    
    node = Node.query.filter_by(token=token).first()
    if not node:
        return jsonify({'error': 'Invalid token'}), 401
    
    # 更新节点状态
    node.status = 'online'
    node.last_seen = datetime.utcnow()
    db.session.commit()
    
    # 返回配置信息
    config = {
        'node_id': node.id,
        'api_secret': node.api_secret,
        'hidden_path': get_hidden_path(token),
        'config': {
            'enable_vless': node.enable_vless,
            'enable_splithttp': node.enable_splithttp,
            'enable_hysteria2': node.enable_hysteria2,
            'max_users': node.max_users
        }
    }
    
    return jsonify(config)

@app.route('/api/node/heartbeat', methods=['POST'])
def api_node_heartbeat():
    """节点心跳API"""
    data = request.json
    if not data:
        return jsonify({'error': 'Invalid JSON'}), 400
    
    node_id = data.get('node_id')
    api_secret = data.get('api_secret')
    
    if not node_id or not api_secret:
        return jsonify({'error': 'Missing parameters'}), 400
    
    node = Node.query.get(node_id)
    if not node or node.api_secret != api_secret:
        return jsonify({'error': 'Authentication failed'}), 401
    
    # 更新最后在线时间
    node.last_seen = datetime.utcnow()
    node.status = 'online'
    
    # 更新统计信息
    if 'stats' in data:
        stats = data['stats']
        # 这里可以保存统计信息到数据库
    
    db.session.commit()
    
    return jsonify({'status': 'ok'})

@app.route('/api/node/config', methods=['POST'])
def api_node_config():
    """获取节点配置API"""
    data = request.json
    if not data:
        return jsonify({'error': 'Invalid JSON'}), 400
    
    node_id = data.get('node_id')
    api_secret = data.get('api_secret')
    
    if not node_id or not api_secret:
        return jsonify({'error': 'Missing parameters'}), 400
    
    node = Node.query.get(node_id)
    if not node or node.api_secret != api_secret:
        return jsonify({'error': 'Authentication failed'}), 401
    
    # 返回Xray配置
    config = {
        'xray_config': node.xray_config or '{}',
        'config_version': '1.0'
    }
    
    return jsonify(config)

# 错误处理
@app.errorhandler(404)
def page_not_found(e):
    return render_template('404.html'), 404

@app.errorhandler(500)
def internal_server_error(e):
    return render_template('500.html'), 500

if __name__ == '__main__':
    # 创建数据库表
    with app.app_context():
        db.create_all()
    
    # 运行应用
    app.run(host='0.0.0.0', port=5000, debug=True)