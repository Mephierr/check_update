#!/bin/bash


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color


detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"  # Debian/Ubuntu
    elif command -v dnf &> /dev/null; then
        echo "dnf"  # Fedora/RHEL 8+
    elif command -v yum &> /dev/null; then
        echo "yum"  # CentOS/RHEL 7
    elif command -v pacman &> /dev/null; then
        echo "pacman"  # Arch Linux
    elif command -v zypper &> /dev/null; then
        echo "zypper"  # openSUSE
    elif command -v brew &> /dev/null; then
        echo "brew"  # macOS (Homebrew)
    else
        echo "unknown"
    fi
}


get_current_version() {
    local package="$1"
    local pkg_manager="$2"
    
    case "$pkg_manager" in
        apt)
            dpkg -s "$package" 2>/dev/null | grep -i version | awk '{print $2}'
            ;;
        dnf|yum)
            rpm -q "$package" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+"
            ;;
        pacman)
            pacman -Qi "$package" 2>/dev/null | grep -i version | awk '{print $3}'
            ;;
        zypper)
            rpm -q "$package" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+"
            ;;
        brew)
            brew list --versions "$package" | awk '{print $2}'
            ;;
        *)
            echo ""
            ;;
    esac
}


check_package_version() {
    local package="$1"
    local pkg_manager="$2"
    local current_version
    local latest_version

    current_version=$(get_current_version "$package" "$pkg_manager")

    if [ -z "$current_version" ]; then
        echo -e "${YELLOW}[?] ${package}: Не установлен или не поддерживается${NC}"
        return
    fi

    
    case "$package" in
        nginx)
            latest_version=$(curl -s https://nginx.org/en/download.html | grep -oP "nginx-\K[0-9]+\.[0-9]+\.[0-9]+" | head -1)
            ;;
        openssl)
            latest_version=$(curl -s https://www.openssl.org/source/ | grep -oP "openssl-\K[0-9]+\.[0-9]+\.[0-9]+[a-z]?" | head -1)
            ;;
        docker-ce|docker)
            latest_version=$(curl -s https://api.github.com/repos/docker/docker-ce/releases/latest | grep -oP '"tag_name": "\Kv?[0-9]+\.[0-9]+\.[0-9]+')
            ;;
        python3)
            latest_version=$(curl -s https://www.python.org/downloads/ | grep -oP 'Python \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        postgresql*)
            latest_version=$(curl -s https://www.postgresql.org/download/ | grep -oP 'PostgreSQL \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        *)
            echo -e "${YELLOW}[?] ${package}: Проверка версий не поддерживается${NC}"
            return
            ;;
    esac

    
    if [ "$current_version" != "$latest_version" ] && [ -n "$latest_version" ]; then
        echo -e "${RED}[!] ${package}: Текущая: ${current_version}, Доступна: ${latest_version}${NC}"
    else
        echo -e "${GREEN}[✓] ${package}: Актуальная (${current_version})${NC}"
    fi
}


PACKAGES_FILE="packages.txt"
if [ ! -f "$PACKAGES_FILE" ]; then
    echo -e "${RED}Ошибка: Файл ${PACKAGES_FILE} не найден!${NC}"
    exit 1
fi


PKG_MANAGER=$(detect_package_manager)
if [ "$PKG_MANAGER" = "unknown" ]; then
    echo -e "${RED}Ошибка: Не удалось определить менеджер пакетов!${NC}"
    exit 1
fi

echo -e "=== Проверка обновлений (менеджер: ${YELLOW}${PKG_MANAGER}${NC}) ==="

while IFS= read -r package; do
    
    if [[ -n "$package" && ! "$package" =~ ^# ]]; then
        check_package_version "$package" "$PKG_MANAGER"
    fi
done < "$PACKAGES_FILE"