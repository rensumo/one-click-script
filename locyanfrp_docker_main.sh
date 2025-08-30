#!/bin/bash

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
NC='\033[0m' # 恢复默认颜色

# 镜像源配置
IMAGE_SOURCE="dockerhub"  # 默认镜像源
DOCKERHUB_REPO="rensumo/locyanfrp"
GHCR_REPO="ghcr.io/rensumo/locyanfrp"

# 显示logo
show_logo() {
    echo -e "${GREEN}"
    echo -e " ____          _________                      ___________       "       
    echo -e "|    |    ____ \_   ___ \___.__._____    ____ \_   _____/____________  "
    echo -e "|    |   /  _ \/    \  \<   |  |\__  \  /    \ |    __) \_  __ \____ \ "
    echo -e "|    |__(  <_> )     \___\___  | / __ \|   |  \|     \   |  | \/  |_> >"
    echo -e "|_______ \____/ \______  / ____|(____  /___|  /\___  /   |__|  |   __/ "
    echo -e "        \/             \/\/          \/     \/     \/          |__|    "
    echo -e "${NC}"
    echo -e "${BLUE}官网: https://www.locyanfrp.cn/     (隧道需在官网创建)${NC}"
    echo -e "${BLUE}本脚本由雨云提供云计算服务${NC}"
    echo -e "${BLUE}雨云注册链接：https://www.rainyun.com/ssl_${NC}"
    echo
}

# 获取系统架构并设置镜像标签
get_arch_tag() {
    local arch
    arch=$(uname -m)
    case "$arch" in
        "x86_64")
            echo "v0.51.3-amd64"
            ;;
        "aarch64"|"arm64")
            echo "v0.51.3-arm64"
            ;;
        "armv7l"|"armv6l")
            echo "v0.51.3-arm"
            ;;
        *)
            echo -e "${RED}错误: 不支持的系统架构: $arch${NC}" >&2
            return 1
            ;;
    esac
}

# 获取完整镜像名称
get_full_image_name() {
    local image_tag
    image_tag=$(get_arch_tag)
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    case "$IMAGE_SOURCE" in
        "dockerhub")
            echo "$DOCKERHUB_REPO:$image_tag"
            ;;
        "ghcr")
            echo "$GHCR_REPO:$image_tag"
            ;;
        *)
            echo -e "${RED}错误: 未知的镜像源: $IMAGE_SOURCE${NC}" >&2
            return 1
            ;;
    esac
}

# 检查命令是否存在
check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo -e "${RED}错误: 未安装 $1${NC}"
        return 1
    fi
    return 0
}

# 安装Docker
install_docker() {
    echo -e "${YELLOW}正在安装Docker...${NC}"
    curl -fsSL https://get.docker.com | sh
    if [ $? -eq 0 ]; then
        systemctl enable docker
        systemctl start docker
        echo -e "${GREEN}Docker 安装成功！${NC}"
        return 0
    else
        echo -e "${RED}Docker 安装失败${NC}"
        return 1
    fi
}

# 安全读取输入（兼容非Bash shell）
safe_read() {
    local prompt="$1"
    local silent="$2"
    local var="$3"
    
    if [ "$silent" = "silent" ]; then
        # 使用stty来隐藏输入
        stty -echo
        printf "%s" "$prompt"
        read "$var"
        stty echo
        echo
    else
        printf "%s" "$prompt"
        read "$var"
    fi
}

# 拉取LocyanFRP镜像
pull_locyanfrp() {
    echo -e "${YELLOW}正在拉取LocyanFRP镜像...${NC}"
    
    # 获取完整镜像名称
    local full_image_name
    full_image_name=$(get_full_image_name)
    if [ $? -ne 0 ]; then
        safe_read "按回车键继续... " dummy
        return 1
    fi
    
    echo -e "${BLUE}当前镜像源: $IMAGE_SOURCE${NC}"
    echo -e "${BLUE}检测到系统架构: $(uname -m)${NC}"
    echo -e "${BLUE}拉取镜像: $full_image_name${NC}"
    
    docker pull "$full_image_name"
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}镜像拉取成功！${NC}"
        return 0
    else
        echo -e "${RED}镜像拉取失败${NC}"
        return 1
    fi
}

# 启动LocyanFRP容器
start_locyanfrp() {
    echo -e "${GREEN}==== 启动LocyanFRP容器 ====${NC}"
    
    # 获取完整镜像名称
    local full_image_name
    full_image_name=$(get_full_image_name)
    if [ $? -ne 0 ]; then
        safe_read "按回车键继续... " dummy
        return 1
    fi
    
    safe_read "请输入访问密钥: " silent token
    safe_read "请输入隧道ID (多个用逗号分隔): " dummy tunnel_ids
    
    if [ -z "$token" ] || [ -z "$tunnel_ids" ]; then
        echo -e "${RED}错误: 密钥和隧道ID不能为空${NC}"
        safe_read "按回车键继续... " dummy
        return 1
    fi
    
    # 检查容器是否已存在
    if docker ps -a --format '{{.Names}}' | grep -q "locyanfrp"; then
        echo -e "${YELLOW}发现已存在的容器，正在停止并删除...${NC}"
        docker stop locyanfrp >/dev/null 2>&1
        docker rm locyanfrp >/dev/null 2>&1
    fi
    
    # 启动新容器
    echo -e "${YELLOW}正在启动容器...${NC}"
    echo -e "${BLUE}使用镜像: $full_image_name${NC}"
    
    docker run -d \
        --name locyanfrp \
        --network=host \
        --restart=always \
        "$full_image_name" \
        -u "$token" \
        -p "$tunnel_ids"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}容器启动成功！${NC}"
        echo -e "${BLUE}使用以下命令查看日志: docker logs -f locyanfrp${NC}"
    else
        echo -e "${RED}容器启动失败${NC}"
    fi
    
    safe_read "按回车键继续... " dummy
}

# 停止LocyanFRP容器
stop_locyanfrp() {
    echo -e "${GREEN}==== 停止LocyanFRP容器 ====${NC}"
    
    if docker ps --format '{{.Names}}' | grep -q "locyanfrp"; then
        docker stop locyanfrp >/dev/null 2>&1
        docker rm locyanfrp >/dev/null 2>&1
        echo -e "${GREEN}容器已停止并移除${NC}"
    else
        echo -e "${YELLOW}没有运行中的LocyanFRP容器${NC}"
    fi
    
    safe_read "按回车键继续... " dummy
}

# 查看容器状态
check_container_status() {
    echo -e "${GREEN}==== 容器状态 ====${NC}"
    docker ps -a --filter "name=locyanfrp"
    safe_read "按回车键继续... " dummy
}

# 查看容器日志
view_container_logs() {
    echo -e "${GREEN}==== 容器日志 ====${NC}"
    if docker ps -a --format '{{.Names}}' | grep -q "locyanfrp"; then
        echo -e "${YELLOW}按 Ctrl+C 退出日志查看${NC}"
        docker logs -f locyanfrp
    else
        echo -e "${RED}没有找到LocyanFRP容器${NC}"
        safe_read "按回车键继续... " dummy
    fi
}

# 修改容器配置
modify_container_config() {
    echo -e "${GREEN}==== 修改容器配置 ====${NC}"
    
    # 获取完整镜像名称
    local full_image_name
    full_image_name=$(get_full_image_name)
    if [ $? -ne 0 ]; then
        safe_read "按回车键继续... " dummy
        return 1
    fi
    
    # 获取当前容器参数
    current_cmd=$(docker inspect --format='{{.Config.Cmd}}' locyanfrp 2>/dev/null)
    
    if [ -n "$current_cmd" ]; then
        current_token=$(echo "$current_cmd" | grep -oP -- '-u \K[^ ]+')
        current_tunnel_ids=$(echo "$current_cmd" | grep -oP -- '-p \K[^ ]+')
        
        echo -e "${BLUE}当前密钥: $current_token${NC}"
        echo -e "${BLUE}当前隧道ID: $current_tunnel_ids${NC}"
    fi
    
    safe_read "请输入新的访问密钥 (留空则保持不变): " silent new_token
    safe_read "请输入新的隧道ID (多个用逗号分隔，留空则保持不变): " dummy new_tunnel_ids
    
    if [ -z "$new_token" ] && [ -z "$new_tunnel_ids" ]; then
        echo -e "${YELLOW}没有修改任何配置${NC}"
        safe_read "按回车键继续... " dummy
        return
    fi
    
    # 使用当前值作为默认值
    new_token=${new_token:-$current_token}
    new_tunnel_ids=${new_tunnel_ids:-$current_tunnel_ids}
    
    # 停止并删除旧容器
    if docker ps -a --format '{{.Names}}' | grep -q "locyanfrp"; then
        docker stop locyanfrp >/dev/null 2>&1
        docker rm locyanfrp >/dev/null 2>&1
    fi
    
    # 启动新容器
    docker run -d \
        --name locyanfrp \
        --network=host \
        --restart=always \
        "$full_image_name" \
        -u "$new_token" \
        -p "$new_tunnel_ids"
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}配置已更新并重新启动容器！${NC}"
    else
        echo -e "${RED}容器启动失败${NC}"
    fi
    
    safe_read "按回车键继续... " dummy
}

# 卸载LocyanFRP
uninstall_locyanfrp() {
    echo -e "${GREEN}==== 卸载LocyanFRP ====${NC}"
    
    safe_read "确定要卸载LocyanFRP吗？(y/N): " dummy confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        echo -e "${YELLOW}已取消卸载${NC}"
        safe_read "按回车键继续... " dummy
        return
    fi
    
    # 获取完整镜像名称
    local full_image_name
    full_image_name=$(get_full_image_name)
    if [ $? -ne 0 ]; then
        safe_read "按回车键继续... " dummy
        return 1
    fi
    
    # 停止并删除容器
    if docker ps -a --format '{{.Names}}' | grep -q "locyanfrp"; then
        docker stop locyanfrp >/dev/null 2>&1
        docker rm locyanfrp >/dev/null 2>&1
    fi
    
    # 删除镜像
    docker rmi "$full_image_name" >/dev/null 2>&1
    
    echo -e "${GREEN}LocyanFRP已卸载！${NC}"
    safe_read "按回车键继续... " dummy
}

# 切换镜像源
switch_image_source() {
    echo -e "${GREEN}==== 切换镜像源 ====${NC}"
    echo "当前镜像源: $IMAGE_SOURCE"
    echo "1. Docker Hub (默认)"
    echo "2. GitHub Container Registry (ghcr.io)"
    echo "0. 返回"
    echo
    
    safe_read "请选择镜像源 [0-2]: " dummy choice
    
    case "$choice" in
        1)
            IMAGE_SOURCE="dockerhub"
            echo -e "${GREEN}已切换到 Docker Hub 镜像源${NC}"
            ;;
        2)
            IMAGE_SOURCE="ghcr"
            echo -e "${GREEN}已切换到 GitHub Container Registry 镜像源${NC}"
            ;;
        0)
            return
            ;;
        *)
            echo -e "${RED}无效选择${NC}"
            ;;
    esac
    
    # 显示当前镜像源详细信息
    echo -e "${BLUE}当前镜像源: $IMAGE_SOURCE${NC}"
    case "$IMAGE_SOURCE" in
        "dockerhub")
            echo -e "镜像仓库: $DOCKERHUB_REPO"
            ;;
        "ghcr")
            echo -e "镜像仓库: $GHCR_REPO"
            ;;
    esac
    
    safe_read "按回车键继续... " dummy
}

# 显示当前镜像源信息
show_image_source_info() {
    echo -e "${BLUE}当前镜像源: $IMAGE_SOURCE${NC}"
    case "$IMAGE_SOURCE" in
        "dockerhub")
            echo -e "镜像仓库: $DOCKERHUB_REPO"
            ;;
        "ghcr")
            echo -e "镜像仓库: $GHCR_REPO"
            ;;
    esac
    echo
}

# 主菜单
show_main_menu() {
    while true; do
        clear
        show_logo
        echo -e "${BLUE}===== Docker版LocyanFRP管理 =====${NC}"
        show_image_source_info
        echo "1. 安装Docker"
        echo "2. 拉取LocyanFRP镜像"
        echo "3. 启动LocyanFRP容器"
        echo "4. 停止LocyanFRP容器"
        echo "5. 查看容器状态"
        echo "6. 查看容器日志"
        echo "7. 修改容器配置"
        echo "8. 卸载LocyanFRP"
        echo "9. 切换镜像源"
        echo "0. 退出"
        echo
        
        safe_read "请选择操作 [0-9]: " dummy choice
        
        case "$choice" in
            1) 
                check_command "docker" && {
                    echo -e "${YELLOW}Docker 已安装${NC}"
                    safe_read "按回车键继续... " dummy
                } || install_docker
                ;;
            2) pull_locyanfrp ;;
            3) start_locyanfrp ;;
            4) stop_locyanfrp ;;
            5) check_container_status ;;
            6) view_container_logs ;;
            7) modify_container_config ;;
            8) uninstall_locyanfrp ;;
            9) switch_image_source ;;
            0) echo -e "${GREEN}感谢使用，再见！${NC}"; exit 0 ;;
            *) echo -e "${RED}无效选择，请重试${NC}"; safe_read "按回车键继续... " dummy; ;;
        esac
    done
}

# 检查root权限
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}错误: 此脚本需要root权限运行${NC}"
    echo -e "${YELLOW}请使用 sudo 运行此脚本${NC}"
    exit 1
fi

# 启动主菜单
show_main_menu