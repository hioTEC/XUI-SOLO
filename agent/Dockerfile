FROM python:3.11-slim

WORKDIR /app

# 安装Docker CLI用于管理容器
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 创建配置目录
RUN mkdir -p /app/config

# 复制应用文件
COPY agent.py .

EXPOSE 8080

CMD ["python", "agent.py"]
