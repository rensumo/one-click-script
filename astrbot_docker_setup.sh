#!/bin/bash

# 一键部署AstrBot脚本

# 检查是否以root权限运行
if [ "$(id -u)" -ne 0 ]; then
    echo "请使用sudo运行此脚本"
    exit 1
fi

# 添加雨云广告信息（部署前输出）
echo "本脚本由雨云提供云计算服务"
echo "雨云注册链接：https://www.rainyun.com/ssl_"
echo "通过此链接注册后并且在后台检测到后，可加我qq:3241535443获取技术支持"
echo ""

# 获取服务器IP地址
get_server_ip() {
    # 尝试获取公网IP
    public_ip=$(curl -s --connect-timeout 5 ifconfig.me)
    
    # 如果获取公网IP失败，则获取内网IP
    if [ -z "$public_ip" ]; then
        # 获取第一个非127的内网IP
        private_ip=$(hostname -I | awk '{print $1}')
        echo "$private_ip"
    else
        echo "$public_ip"
    fi
}



# 创建astrbot目录
mkdir -p astrbot
cd astrbot || exit


# 步骤1/3: 下载配置文件
echo "步骤1/3: 下载配置文件..."
wget -q http://r2.rensumo.top/astrbot.yml || {
    echo "❌ 配置文件下载失败！"
    exit 1
}
echo "✅ 配置文件下载完成"

# 步骤2/3: 检查并安装Docker环境

echo "步骤2/5: 检查并安装Docker环境..."
    
# 检查Docker是否已安装
if ! command -v docker &> /dev/null; then
    echo "未检测到Docker，开始安装..."
fi
    
# 检查Docker Compose是否已安装
if ! docker compose version &> /dev/null; then
    echo "未检测到Docker Compose，将一同安装..."
fi
    
# 如果任一组件缺失，执行安装脚本
if ! command -v docker &> /dev/null || ! docker compose version &> /dev/null; then
    # 执行指定的Docker安装脚本
    echo "正在运行Docker安装脚本..."
    if ! bash <(curl -sSL https://linuxmirrors.cn/docker.sh); then
        echo "❌ Docker环境安装失败！"
        exit 1
    fi
    # 确保Docker服务启动
    systemctl enable --now docker
    sleep 2  # 等待Docker服务启动
else
    echo "Docker和Docker Compose已安装，跳过安装步骤"
fi
    
echo "✅ Docker环境检查/安装完成"

# 步骤3/3: 启动AstrBot容器
echo "步骤3/3: 启动AstrBot容器..."
if docker compose -f astrbot.yml up -d; then
    echo "✅ AstrBot部署成功！"
    
    # 获取服务器IP
    SERVER_IP=$(get_server_ip)
    
    # 显示访问地址
    echo -e "\n=============================================="
    echo "AstrBot 访问地址: http://$SERVER_IP:6185"
    echo "NapCat  访问地址: http://$SERVER_IP:6099"
    echo "=============================================="
    
    # 显示常用命令
    echo -e "\n使用以下命令查看日志: docker compose logs -f"
    echo "停止服务: docker compose down"
    echo "重启服务: docker compose restart"
else
    echo "❌ 容器启动失败！"
    exit 1
fi

# 显示部署后状态
echo -e "\n部署状态检查:"
docker compose ps
