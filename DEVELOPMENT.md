# Xray集群管理系统 - 开发指南

## 开发环境设置

### 前置要求

- Python 3.11+
- Docker & Docker Compose
- PostgreSQL 15+
- Redis 7+
- Git

### 本地开发环境

#### 1. 克隆项目

```bash
git clone https://github.com/hioTEC/XUI-SOLO.git
cd XUI-SOLO
```

#### 2. 创建虚拟环境

```bash
python3 -m venv venv
source venv/bin/activate  # Linux/Mac
# 或
venv\Scripts\activate  # Windows
```

#### 3. 安装依赖

```bash
pip install -r requirements.txt
pip install -r requirements-dev.txt  # 开发依赖
```

#### 4. 配置环境变量

```bash
cp .env.example .env
# 编辑 .env 文件，配置本地开发环境
```

#### 5. 启动数据库服务

```bash
# 使用Docker启动PostgreSQL和Redis
docker-compose -f docker-compose.dev.yml up -d postgres redis
```

#### 6. 初始化数据库

```bash
cd master
python app.py
# 首次运行会自动创建数据库表
```

## 项目结构

```
xray-cluster/
├── master/                 # Master节点（控制面板）
│   ├── app.py             # Flask应用主文件
│   ├── Caddyfile          # Caddy配置
│   ├── templates/         # HTML模板
│   │   ├── base.html
│   │   ├── dashboard.html
│   │   ├── nodes.html
│   │   └── ...
│   └── web/
│       └── Dockerfile     # Web应用Docker镜像
│
├── node/                  # Worker节点
│   ├── agent.py          # 节点Agent
│   ├── docker-compose.yml
│   ├── Dockerfile.agent
│   └── xray_config/
│       └── config.json   # Xray配置模板
│
├── requirements.txt       # Python依赖
├── install.sh            # 安装脚本
├── test_project.py       # 测试脚本
├── README.md
├── DEPLOYMENT.md         # 部署指南
├── API.md               # API文档
└── DEVELOPMENT.md       # 本文档
```

## 代码规范

### Python代码风格

遵循 PEP 8 规范：

```bash
# 安装代码检查工具
pip install flake8 black pylint

# 格式化代码
black master/app.py node/agent.py

# 检查代码风格
flake8 master/app.py node/agent.py

# 静态分析
pylint master/app.py node/agent.py
```

### 命名规范

- **变量名**: 小写字母+下划线 (`node_id`, `api_secret`)
- **函数名**: 小写字母+下划线 (`get_xray_status()`)
- **类名**: 驼峰命名 (`UserAccount`, `NodeManager`)
- **常量**: 大写字母+下划线 (`MAX_USERS`, `API_TIMEOUT`)

### 注释规范

```python
def register_to_master():
    """
    向Master注册节点
    
    Returns:
        bool: 注册成功返回True，失败返回False
    
    Raises:
        ConnectionError: 无法连接到Master
    """
    pass
```

## 开发工作流

### 1. 创建功能分支

```bash
git checkout -b feature/new-feature
```

### 2. 开发和测试

```bash
# 运行测试
python test_project.py

# 运行单元测试
pytest tests/

# 代码覆盖率
pytest --cov=master --cov=node tests/
```

### 3. 提交代码

```bash
git add .
git commit -m "feat: 添加新功能"
```

提交信息格式：
- `feat`: 新功能
- `fix`: 修复bug
- `docs`: 文档更新
- `style`: 代码格式调整
- `refactor`: 代码重构
- `test`: 测试相关
- `chore`: 构建/工具相关

### 4. 推送和创建PR

```bash
git push origin feature/new-feature
# 在GitHub创建Pull Request
```

## 测试

### 运行所有测试

```bash
python test_project.py
```

### 单元测试

创建测试文件 `tests/test_master.py`:

```python
import unittest
from master.app import app, db

class TestMasterAPI(unittest.TestCase):
    def setUp(self):
        app.config['TESTING'] = True
        app.config['SQLALCHEMY_DATABASE_URI'] = 'sqlite:///:memory:'
        self.client = app.test_client()
        
        with app.app_context():
            db.create_all()
    
    def tearDown(self):
        with app.app_context():
            db.drop_all()
    
    def test_node_register(self):
        """测试节点注册API"""
        response = self.client.post('/api/node/register', json={
            'token': 'test-token',
            'timestamp': 1234567890
        })
        self.assertEqual(response.status_code, 401)  # 无效token

if __name__ == '__main__':
    unittest.main()
```

运行单元测试：

```bash
python -m pytest tests/
```

### 集成测试

```bash
# 启动测试环境
docker-compose -f docker-compose.test.yml up -d

# 运行集成测试
python tests/integration_test.py

# 清理测试环境
docker-compose -f docker-compose.test.yml down -v
```

## 调试

### Master应用调试

```python
# master/app.py
if __name__ == '__main__':
    # 开启调试模式
    app.run(host='0.0.0.0', port=5000, debug=True)
```

使用VSCode调试配置 `.vscode/launch.json`:

```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Python: Flask",
      "type": "python",
      "request": "launch",
      "module": "flask",
      "env": {
        "FLASK_APP": "master/app.py",
        "FLASK_ENV": "development"
      },
      "args": ["run", "--no-debugger", "--no-reload"],
      "jinja": true
    }
  ]
}
```

### Agent调试

```python
# node/agent.py
if __name__ == '__main__':
    # 开启调试日志
    logging.basicConfig(level=logging.DEBUG)
    app.run(host='0.0.0.0', port=8080, debug=True)
```

### Docker日志

```bash
# 查看实时日志
docker-compose logs -f

# 查看特定服务日志
docker-compose logs -f web
docker-compose logs -f xray
docker-compose logs -f agent
```

## 数据库管理

### 数据库迁移

使用Flask-Migrate管理数据库版本：

```bash
# 安装Flask-Migrate
pip install Flask-Migrate

# 初始化迁移
flask db init

# 创建迁移
flask db migrate -m "添加新字段"

# 应用迁移
flask db upgrade
```

### 数据库查询

```bash
# 连接到PostgreSQL
docker-compose exec postgres psql -U xray_admin -d xray_cluster

# 查看表
\dt

# 查询节点
SELECT * FROM node;

# 查询用户
SELECT * FROM user_account;
```

## 性能优化

### 1. 数据库查询优化

```python
# 使用索引
class Node(db.Model):
    __tablename__ = 'node'
    __table_args__ = (
        db.Index('idx_node_status', 'status'),
        db.Index('idx_node_token', 'token'),
    )

# 使用查询优化
nodes = Node.query.filter_by(status='online').options(
    db.joinedload(Node.users)
).all()
```

### 2. 缓存策略

```python
from flask_caching import Cache

cache = Cache(app, config={
    'CACHE_TYPE': 'redis',
    'CACHE_REDIS_URL': os.environ.get('REDIS_URL')
})

@app.route('/api/stats')
@cache.cached(timeout=60)
def get_stats():
    # 缓存60秒
    return jsonify(stats)
```

### 3. 异步任务

使用Celery处理耗时任务：

```python
from celery import Celery

celery = Celery('tasks', broker=os.environ.get('REDIS_URL'))

@celery.task
def sync_node_config(node_id):
    """异步同步节点配置"""
    node = Node.query.get(node_id)
    # 执行同步操作
    pass
```

## 安全开发

### 1. 输入验证

```python
from flask import request
import re

def validate_domain(domain):
    """验证域名格式"""
    pattern = r'^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$'
    return re.match(pattern, domain) is not None

@app.route('/api/node/add', methods=['POST'])
def add_node():
    domain = request.json.get('domain')
    if not validate_domain(domain):
        return jsonify({'error': 'Invalid domain'}), 400
```

### 2. SQL注入防护

```python
# 使用参数化查询
node = Node.query.filter_by(id=node_id).first()

# 避免字符串拼接
# 错误示例：
# query = f"SELECT * FROM node WHERE id = {node_id}"
```

### 3. XSS防护

```python
from markupsafe import escape

@app.route('/node/<int:node_id>')
def node_detail(node_id):
    node = Node.query.get_or_404(node_id)
    # Jinja2自动转义
    return render_template('node_detail.html', node=node)
```

### 4. CSRF防护

```python
from flask_wtf.csrf import CSRFProtect

csrf = CSRFProtect(app)

# API端点可以豁免CSRF
@app.route('/api/node/register', methods=['POST'])
@csrf.exempt
def api_node_register():
    pass
```

## 贡献指南

### 提交PR前检查清单

- [ ] 代码通过所有测试
- [ ] 代码符合PEP 8规范
- [ ] 添加了必要的注释和文档
- [ ] 更新了相关文档（README、API文档等）
- [ ] 提交信息清晰明确
- [ ] 没有引入安全漏洞
- [ ] 性能没有明显下降

### 代码审查标准

1. **功能性**: 代码是否实现了预期功能
2. **可读性**: 代码是否易于理解
3. **可维护性**: 代码是否易于修改和扩展
4. **性能**: 是否有性能问题
5. **安全性**: 是否存在安全隐患
6. **测试**: 是否有足够的测试覆盖

## 常见问题

### Q: 如何添加新的API端点？

A: 在 `master/app.py` 或 `node/agent.py` 中添加路由：

```python
@app.route('/api/new-endpoint', methods=['POST'])
def new_endpoint():
    # 验证请求
    data = request.json
    if not data:
        return jsonify({'error': 'Invalid JSON'}), 400
    
    # 处理逻辑
    result = process_data(data)
    
    # 返回响应
    return jsonify({'status': 'ok', 'result': result})
```

### Q: 如何添加新的数据库模型？

A: 在 `master/app.py` 中定义模型：

```python
class NewModel(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)
```

然后运行数据库迁移。

### Q: 如何添加新的前端页面？

A: 在 `master/templates/` 中创建HTML模板，继承 `base.html`：

```html
{% extends "base.html" %}

{% block title %}新页面{% endblock %}

{% block content %}
<div class="container">
    <h1>新页面内容</h1>
</div>
{% endblock %}
```

在 `master/app.py` 中添加路由：

```python
@app.route('/new-page')
@login_required
def new_page():
    return render_template('new_page.html')
```

## 资源链接

- [Flask文档](https://flask.palletsprojects.com/)
- [SQLAlchemy文档](https://docs.sqlalchemy.org/)
- [Xray文档](https://xtls.github.io/)
- [Docker文档](https://docs.docker.com/)
- [PostgreSQL文档](https://www.postgresql.org/docs/)

## 技术支持

- GitHub Issues: 报告bug和功能请求
- GitHub Discussions: 技术讨论
- Email: dev@hiotec.dev
