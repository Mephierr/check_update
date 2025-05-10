#!/bin/bash


RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' 

# ========== НАСТРОЙКИ ==========
AUTO_UPDATE=false  
INSTALL_DEPS=true  
PACKAGES_FILE="packages.txt"  
# ===============================


fail() {
    echo -e "${RED}[ОШИБКА] $1${NC}"
    exit 1
}


detect_package_manager() {
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    elif command -v zypper &> /dev/null; then
        echo "zypper"
    elif command -v brew &> /dev/null; then
        echo "brew"
    else
        fail "Не удалось определить менеджер пакетов!"
    fi
}


install_dependencies() {
    local pkg_manager="$1"
    echo -e "${BLUE}[ИНФО] Проверка зависимостей...${NC}"

    
    local common_deps=("curl" "grep" "awk")
    case "$pkg_manager" in
        apt)
            for dep in "${common_deps[@]}"; do
                if ! command -v "$dep" &> /dev/null; then
                    echo -e "${YELLOW}[ИНФО] Устанавливаем $dep...${NC}"
                    sudo apt update && sudo apt install -y "$dep" || fail "Не удалось установить $dep"
                fi
            done
            ;;
        dnf|yum)
            for dep in "${common_deps[@]}"; do
                if ! command -v "$dep" &> /dev/null; then
                    echo -e "${YELLOW}[ИНФО] Устанавливаем $dep...${NC}"
                    sudo "$pkg_manager" install -y "$dep" || fail "Не удалось установить $dep"
                fi
            done
            ;;
        pacman)
            for dep in "${common_deps[@]}"; do
                if ! command -v "$dep" &> /dev/null; then
                    echo -e "${YELLOW}[ИНФО] Устанавливаем $dep...${NC}"
                    sudo pacman -Sy --noconfirm "$dep" || fail "Не удалось установить $dep"
                fi
            done
            ;;
        brew)
            for dep in "${common_deps[@]}"; do
                if ! command -v "$dep" &> /dev/null; then
                    echo -e "${YELLOW}[ИНФО] Устанавливаем $dep...${NC}"
                    brew install "$dep" || fail "Не удалось установить $dep"
                fi
            done
            ;;
    esac

    
    if ! command -v jq &> /dev/null; then
        echo -e "${YELLOW}[ИНФО] Устанавливаем jq...${NC}"
        case "$pkg_manager" in
            apt) sudo apt install -y jq ;;
            dnf|yum) sudo "$pkg_manager" install -y jq ;;
            pacman) sudo pacman -Sy --noconfirm jq ;;
            brew) brew install jq ;;
        esac || echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] Не удалось установить jq${NC}"
    fi
}


check_os_updates() {
    local pkg_manager="$1"
    echo -e "${BLUE}[ИНФО] Проверка обновлений ОС...${NC}"

    case "$pkg_manager" in
        apt)
            sudo apt update > /dev/null
            updates=$(apt list --upgradable 2>/dev/null | grep -v "^Listing...")
            if [ -n "$updates" ]; then
                echo -e "${RED}[!] Доступны обновления ОС:${NC}"
                echo "$updates"
                if $AUTO_UPDATE; then
                    echo -e "${BLUE}[ИНФО] Устанавливаем обновления...${NC}"
                    sudo apt upgrade -y
                fi
            else
                echo -e "${GREEN}[✓] Система актуальна${NC}"
            fi
            ;;
        dnf)
            updates=$(sudo dnf check-update -q)
            if [ $? -eq 100 ]; then
                echo -e "${RED}[!] Доступны обновления ОС:${NC}"
                sudo dnf check-update
                if $AUTO_UPDATE; then
                    echo -e "${BLUE}[ИНФО] Устанавливаем обновления...${NC}"
                    sudo dnf upgrade -y
                fi
            else
                echo -e "${GREEN}[✓] Система актуальна${NC}"
            fi
            ;;
        yum)
            if sudo yum check-update -q; then
                echo -e "${GREEN}[✓] Система актуальна${NC}"
            else
                echo -e "${RED}[!] Доступны обновления ОС:${NC}"
                sudo yum check-update
                if $AUTO_UPDATE; then
                    echo -e "${BLUE}[ИНФО] Устанавливаем обновления...${NC}"
                    sudo yum update -y
                fi
            fi
            ;;
        pacman)
            updates=$(sudo pacman -Sy --print-format '%n %v %s' | awk '{print $1, $2}')
            if [ -n "$updates" ]; then
                echo -e "${RED}[!] Доступны обновления ОС:${NC}"
                echo "$updates"
                if $AUTO_UPDATE; then
                    echo -e "${BLUE}[ИНФО] Устанавливаем обновления...${NC}"
                    sudo pacman -Syu --noconfirm
                fi
            else
                echo -e "${GREEN}[✓] Система актуальна${NC}"
            fi
            ;;
        zypper)
            updates=$(sudo zypper list-updates | grep -v "^S\?|")
            if [ -n "$updates" ]; then
                echo -e "${RED}[!] Доступны обновления ОС:${NC}"
                echo "$updates"
                if $AUTO_UPDATE; then
                    echo -e "${BLUE}[ИНФО] Устанавливаем обновления...${NC}"
                    sudo zypper update -y
                fi
            else
                echo -e "${GREEN}[✓] Система актуальна${NC}"
            fi
            ;;
        brew)
            brew update > /dev/null
            outdated=$(brew outdated)
            if [ -n "$outdated" ]; then
                echo -e "${RED}[!] Доступны обновления:${NC}"
                echo "$outdated"
                if $AUTO_UPDATE; then
                    echo -e "${BLUE}[ИНФО] Устанавливаем обновления...${NC}"
                    brew upgrade
                fi
            else
                echo -e "${GREEN}[✓] Система актуальна${NC}"
            fi
            ;;
    esac
}


get_current_version() {
    local package="$1"
    local pkg_manager="$2"
    
    case "$pkg_manager" in
        apt)
            dpkg -s "$package" 2>/dev/null | grep -i version | awk '{print $2}'
            ;;
        dnf|yum|zypper)
            rpm -q "$package" 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+"
            ;;
        pacman)
            pacman -Qi "$package" 2>/dev/null | grep -i version | awk '{print $3}'
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
        echo -e "${YELLOW}[?] ${package}: Не установлен${NC}"
        return
    fi

    
    case "$package" in
        nginx)
            latest_version=$(curl -s https://nginx.org/en/download.html | grep -oP "nginx-\K[0-9]+\.[0-9]+\.[0-9]+" | head -1)
            ;;
        openssl)
            latest_version=$(curl -s https://www.openssl.org/source/ | grep -oP "openssl-\K[0-9]+\.[0-9]+\.[0-9]+[a-z]?" | head -1)
            ;;
        docker|docker-ce)
            latest_version=$(curl -s https://api.github.com/repos/docker/docker-ce/releases/latest | jq -r '.tag_name' | sed 's/^v//')
            ;;
        python|python3)
            latest_version=$(curl -s https://www.python.org/downloads/ | grep -oP 'Python \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        postgresql|postgresql-*)
            latest_version=$(curl -s https://www.postgresql.org/download/ | grep -oP 'PostgreSQL \K[0-9]+\.[0-9]+\.[0-9]+' | head -1)
            ;;
        node|nodejs)
            latest_version=$(curl -s https://nodejs.org/en/download/ | grep -oP 'Latest LTS Version: <strong>\K[0-9]+\.[0-9]+\.[0-9]+')
            ;;
        *)
            echo -e "${YELLOW}[?] ${package}: Проверка версий не поддерживается${NC}"
            return
            ;;
    esac

    
    if [ -z "$latest_version" ]; then
        echo -e "${YELLOW}[?] ${package}: Не удалось проверить обновления${NC}"
    elif [ "$current_version" != "$latest_version" ]; then
        echo -e "${RED}[!] ${package}: Текущая: ${current_version}, Доступна: ${latest_version}${NC}"
        if $AUTO_UPDATE; then
            echo -e "${BLUE}[ИНФО] Обновляем ${package}...${NC}"
            case "$pkg_manager" in
                apt) sudo apt install --only-upgrade -y "$package" ;;
                dnf|yum) sudo "$pkg_manager" update -y "$package" ;;
                pacman) sudo pacman -Syu --noconfirm "$package" ;;
                zypper) sudo zypper update -y "$package" ;;
                brew) brew upgrade "$package" ;;
            esac
        fi
    else
        echo -e "${GREEN}[✓] ${package}: Актуальная (${current_version})${NC}"
    fi
}


clear
echo -e "${BLUE}=== Скрипт проверки обновлений ==="
echo -e "Автоматическое обновление: ${AUTO_UPDATE}"
echo -e "Установка зависимостей: ${INSTALL_DEPS}${NC}"


PKG_MANAGER=$(detect_package_manager)
echo -e "${BLUE}[ИНФО] Менеджер пакетов: ${PKG_MANAGER}${NC}"


if $INSTALL_DEPS; then
    install_dependencies "$PKG_MANAGER"
fi


check_os_updates "$PKG_MANAGER"


if [ -f "$PACKAGES_FILE" ]; then
    echo -e "${BLUE}[ИНФО] Проверка пакетов из ${PACKAGES_FILE}...${NC}"
    while IFS= read -r package; do
        
        if [[ -n "$package" && ! "$package" =~ ^[[:space:]]*# ]]; then
            check_package_version "$package" "$PKG_MANAGER"
        fi
    done < "$PACKAGES_FILE"
else
    echo -e "${YELLOW}[ПРЕДУПРЕЖДЕНИЕ] Файл ${PACKAGES_FILE} не найден${NC}"
fi

echo -e "${BLUE}=== Проверка завершена ===${NC}"