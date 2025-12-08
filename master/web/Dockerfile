FROM python:3.11-slim

WORKDIR /app

# 安装系统依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# 复制requirements文件
COPY requirements.txt .

# 安装Python依赖
RUN pip install --no-cache-dir -r requirements.txt

# 创建日志目录
RUN mkdir -p /var/log/xray-master

EXPOSE 5000

# 使用gunicorn运行应用
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "app:app"]
