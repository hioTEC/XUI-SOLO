# 重新安装指南

## 保留配置重装

```bash
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | \
    sudo bash -s -- --solo --panel 面板域名 --node-domain 节点域名
```

安装时选择「保留现有配置」(y)

## 完全重装

```bash
# 停止服务
cd /opt/xray-cluster/master && docker-compose down -v
cd /opt/xray-cluster/node && docker-compose down -v

# 删除数据
rm -rf /opt/xray-cluster

# 重新安装
curl -fsSL https://raw.githubusercontent.com/hioTEC/XUI-SOLO/main/install.sh | sudo bash
```
