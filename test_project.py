#!/usr/bin/env python3
"""
Xray集群管理系统 - 测试脚本
测试项目的各个组件
"""

import os
import sys
import json
import subprocess
import time
from pathlib import Path

# 颜色定义
class Colors:
    GREEN = '\033[92m'
    RED = '\033[91m'
    YELLOW = '\033[93m'
    BLUE = '\033[94m'
    END = '\033[0m'

def print_test(name):
    print(f"\n{Colors.BLUE}[TEST]{Colors.END} {name}")

def print_pass(msg):
    print(f"{Colors.GREEN}✓ PASS:{Colors.END} {msg}")

def print_fail(msg):
    print(f"{Colors.RED}✗ FAIL:{Colors.END} {msg}")

def print_warn(msg):
    print(f"{Colors.YELLOW}⚠ WARN:{Colors.END} {msg}")

def test_file_structure():
    """测试文件结构完整性"""
    print_test("检查文件结构")
    
    required_files = [
        'README.md',
        'requirements.txt',
        '.env.example',
        'install.sh',
        'master/app.py',
        'master/Caddyfile',
        'master/web/Dockerfile',
        'node/agent.py',
        'node/docker-compose.yml',
        'node/Dockerfile.agent',
        'node/xray_config/config.json',
    ]
    
    missing_files = []
    for file_path in required_files:
        if not Path(file_path).exists():
            missing_files.append(file_path)
            print_fail(f"缺少文件: {file_path}")
        else:
            print_pass(f"找到文件: {file_path}")
    
    return len(missing_files) == 0

def test_python_syntax():
    """测试Python文件语法"""
    print_test("检查Python语法")
    
    python_files = [
        'master/app.py',
        'node/agent.py',
    ]
    
    all_valid = True
    for file_path in python_files:
        try:
            with open(file_path, 'r') as f:
                compile(f.read(), file_path, 'exec')
            print_pass(f"语法正确: {file_path}")
        except SyntaxError as e:
            print_fail(f"语法错误 {file_path}: {e}")
            all_valid = False
    
    return all_valid

def test_json_syntax():
    """测试JSON文件语法"""
    print_test("检查JSON语法")
    
    json_files = [
        'node/xray_config/config.json',
    ]
    
    all_valid = True
    for file_path in json_files:
        try:
            with open(file_path, 'r') as f:
                json.load(f)
            print_pass(f"JSON有效: {file_path}")
        except json.JSONDecodeError as e:
            print_fail(f"JSON错误 {file_path}: {e}")
            all_valid = False
    
    return all_valid

def test_bash_syntax():
    """测试Bash脚本语法"""
    print_test("检查Bash脚本语法")
    
    bash_files = [
        'install.sh',
    ]
    
    all_valid = True
    for file_path in bash_files:
        try:
            result = subprocess.run(
                ['bash', '-n', file_path],
                capture_output=True,
                text=True
            )
            if result.returncode == 0:
                print_pass(f"Bash语法正确: {file_path}")
            else:
                print_fail(f"Bash语法错误 {file_path}: {result.stderr}")
                all_valid = False
        except Exception as e:
            print_warn(f"无法检查 {file_path}: {e}")
    
    return all_valid

def test_dependencies():
    """测试依赖项"""
    print_test("检查Python依赖")
    
    try:
        with open('requirements.txt', 'r') as f:
            requirements = f.read().strip().split('\n')
        
        print_pass(f"找到 {len(requirements)} 个依赖项")
        
        # 检查关键依赖
        key_deps = ['Flask', 'requests', 'psycopg2-binary']
        for dep in key_deps:
            if any(dep in req for req in requirements):
                print_pass(f"包含关键依赖: {dep}")
            else:
                print_fail(f"缺少关键依赖: {dep}")
                return False
        
        return True
    except Exception as e:
        print_fail(f"读取requirements.txt失败: {e}")
        return False

def test_security_features():
    """测试安全特性"""
    print_test("检查安全特性")
    
    security_checks = []
    
    # 检查master/app.py的安全特性
    with open('master/app.py', 'r') as f:
        master_content = f.read()
    
    if 'flask_talisman' in master_content or 'Talisman' in master_content:
        print_pass("Master使用Flask-Talisman安全头")
        security_checks.append(True)
    else:
        print_fail("Master未使用Flask-Talisman")
        security_checks.append(False)
    
    if 'hmac' in master_content:
        print_pass("Master使用HMAC签名")
        security_checks.append(True)
    else:
        print_fail("Master未使用HMAC签名")
        security_checks.append(False)
    
    # 检查node/agent.py的安全特性
    with open('node/agent.py', 'r') as f:
        agent_content = f.read()
    
    if 'sanitize_input' in agent_content:
        print_pass("Agent实现输入验证")
        security_checks.append(True)
    else:
        print_fail("Agent未实现输入验证")
        security_checks.append(False)
    
    if 'shell=False' in agent_content:
        print_pass("Agent防止命令注入")
        security_checks.append(True)
    else:
        print_fail("Agent可能存在命令注入风险")
        security_checks.append(False)
    
    if 'verify_signature' in agent_content:
        print_pass("Agent验证API签名")
        security_checks.append(True)
    else:
        print_fail("Agent未验证API签名")
        security_checks.append(False)
    
    return all(security_checks)

def test_docker_configs():
    """测试Docker配置"""
    print_test("检查Docker配置")
    
    # 检查node的docker-compose.yml
    try:
        with open('node/docker-compose.yml', 'r') as f:
            compose_content = f.read()
        
        if 'xray-node-net' in compose_content:
            print_pass("Node使用隔离网络")
        else:
            print_fail("Node未配置隔离网络")
            return False
        
        if 'restart: unless-stopped' in compose_content:
            print_pass("Node配置自动重启")
        else:
            print_warn("Node未配置自动重启")
        
        return True
    except Exception as e:
        print_fail(f"读取docker-compose.yml失败: {e}")
        return False

def test_api_endpoints():
    """测试API端点定义"""
    print_test("检查API端点")
    
    # 检查Master API
    with open('master/app.py', 'r') as f:
        master_content = f.read()
    
    master_apis = [
        '/api/node/register',
        '/api/node/heartbeat',
        '/api/node/config',
    ]
    
    for api in master_apis:
        if api in master_content:
            print_pass(f"Master API存在: {api}")
        else:
            print_fail(f"Master API缺失: {api}")
            return False
    
    # 检查Agent API
    with open('node/agent.py', 'r') as f:
        agent_content = f.read()
    
    agent_apis = [
        '/health',
        '/api/restart',
        '/api/config',
        '/api/logs',
        '/api/stats',
    ]
    
    for api in agent_apis:
        if api in agent_content:
            print_pass(f"Agent API存在: {api}")
        else:
            print_fail(f"Agent API缺失: {api}")
            return False
    
    return True

def test_environment_variables():
    """测试环境变量配置"""
    print_test("检查环境变量")
    
    try:
        with open('.env.example', 'r') as f:
            env_content = f.read()
        
        required_vars = [
            'SECRET_KEY',
            'ADMIN_USER',
            'ADMIN_PASSWORD',
            'DATABASE_URL',
        ]
        
        for var in required_vars:
            if var in env_content:
                print_pass(f"环境变量定义: {var}")
            else:
                print_fail(f"环境变量缺失: {var}")
                return False
        
        return True
    except Exception as e:
        print_fail(f"读取.env.example失败: {e}")
        return False

def main():
    """运行所有测试"""
    print(f"\n{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BLUE}Xray集群管理系统 - 项目测试{Colors.END}")
    print(f"{Colors.BLUE}{'='*60}{Colors.END}")
    
    tests = [
        ("文件结构", test_file_structure),
        ("Python语法", test_python_syntax),
        ("JSON语法", test_json_syntax),
        ("Bash语法", test_bash_syntax),
        ("依赖项", test_dependencies),
        ("安全特性", test_security_features),
        ("Docker配置", test_docker_configs),
        ("API端点", test_api_endpoints),
        ("环境变量", test_environment_variables),
    ]
    
    results = []
    for name, test_func in tests:
        try:
            result = test_func()
            results.append((name, result))
        except Exception as e:
            print_fail(f"测试异常: {e}")
            results.append((name, False))
    
    # 打印总结
    print(f"\n{Colors.BLUE}{'='*60}{Colors.END}")
    print(f"{Colors.BLUE}测试总结{Colors.END}")
    print(f"{Colors.BLUE}{'='*60}{Colors.END}\n")
    
    passed = sum(1 for _, result in results if result)
    total = len(results)
    
    for name, result in results:
        status = f"{Colors.GREEN}✓ PASS{Colors.END}" if result else f"{Colors.RED}✗ FAIL{Colors.END}"
        print(f"{status} - {name}")
    
    print(f"\n{Colors.BLUE}总计:{Colors.END} {passed}/{total} 测试通过")
    
    if passed == total:
        print(f"\n{Colors.GREEN}🎉 所有测试通过！项目已准备就绪。{Colors.END}\n")
        return 0
    else:
        print(f"\n{Colors.RED}❌ 部分测试失败，请修复问题。{Colors.END}\n")
        return 1

if __name__ == '__main__':
    sys.exit(main())
