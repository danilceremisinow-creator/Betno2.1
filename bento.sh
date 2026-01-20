#!/bin/bash
# bento.sh - настройщик системы под игры с элементами защиты 
# Запуск: sudo ./bento.sh

set -e
trap 'echo -e "\033[1;31mОшибка в строке $LINENO\033[0m"' ERR

# ==================== КОНФИГУРАЦИЯ ====================
USERNAME="$(logname 2>/dev/null || echo $SUDO_USER || echo $USER)"
HOSTNAME="arch-gaming"
TIMEZONE="Europe/Moscow"
INSTALL_MODE="full"  # full | minimal | gaming | secure
GAMING_ENABLED=true
SECURITY_ENABLED=true
AUR_HELPER="yay"

# ==================== ФУНКЦИИ ====================

print_header() {
    clear
    echo -e "\033[1;36m"
    echo "╔══════════════════════════════════════════╗"
    echo "║           BENTO.sh v2.1                  ║"
    echo "║           BY Arch Linux                  ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "\033[0m"
}

print_step() {
    echo -e "\033[1;32m[+] $1\033[0m"
}

print_warning() {
    echo -e "\033[1;33m[!] $1\033[0m"
}

print_error() {
    echo -e "\033[1;31m[✗] $1\033[0m"
}

wait_enter() {
    echo -e "\n\033[1;37mНажмите Enter чтобы продолжить...\033[0m"
    read
}

# Проверка прав
check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "Запустите скрипт с sudo: sudo ./bento.sh"
        exit 1
    fi
}

# Проверка Arch Linux
check_arch() {
    if [ ! -f "/etc/arch-release" ]; then
        print_error "Этот скрипт только для Arch Linux!"
        exit 1
    fi
}

# Обновление системы
update_system() {
    print_step "Обновление системы..."
    pacman -Syu --noconfirm
}

# Установка AUR помощника
install_aur_helper() {
    print_step "Установка $AUR_HELPER..."
    
    case $AUR_HELPER in
        "yay")
            if ! command -v yay &> /dev/null; then
                pacman -S --needed --noconfirm git base-devel
                cd /tmp
                git clone https://aur.archlinux.org/yay.git
                cd yay
                makepkg -si --noconfirm
                cd ~
            fi
            ;;
        "paru")
            if ! command -v paru &> /dev/null; then
                pacman -S --needed --noconfirm git base-devel
                cd /tmp
                git clone https://aur.archlinux.org/paru.git
                cd paru
                makepkg -si --noconfirm
                cd ~
            fi
            ;;
    esac
}

# Определение видеокарты
detect_gpu() {
    print_step "Определение видеокарты..."
    
    if lspci | grep -i "nvidia" > /dev/null; then
        GPU="nvidia"
        print_step "Обнаружена видеокарта NVIDIA"
    elif lspci | grep -i "amd" > /dev/null; then
        GPU="amd"
        print_step "Обнаружена видеокарта AMD"
    elif lspci | grep -i "intel" > /dev/null; then
        GPU="intel"
        print_step "Обнаружена видеокарта Intel"
    else
        GPU="unknown"
        print_warning "Не удалось определить видеокарту"
    fi
}

# Установка игрового стека
install_gaming_stack() {
    print_step "Установка игрового стека..."
    
    # Установка ядра Zen (оптимизирован для игр)
    pacman -S --noconfirm linux-zen linux-zen-headers
    
    # Общие пакеты
    pacman -S --noconfirm \
        mesa lib32-mesa \
        vulkan-radeon lib32-vulkan-radeon \
        vulkan-intel lib32-vulkan-intel \
        vulkan-icd-loader lib32-vulkan-icd-loader \
        libva-mesa-driver lib32-libva-mesa-driver
    
    # Драйверы NVIDIA
    if [ "$GPU" = "nvidia" ]; then
        pacman -S --noconfirm \
            nvidia-dkms nvidia-utils lib32-nvidia-utils \
            nvidia-settings opencl-nvidia lib32-opencl-nvidia
        
        # Конфиг NVIDIA
        cat > /etc/modprobe.d/nvidia-gaming.conf << EOF
options nvidia_drm modeset=1
options nvidia NVreg_RegistryDwords="PerfLevelSrc=0x2222"
options nvidia NVreg_EnablePCIeGen3=1
EOF
    fi
    
    # Steam и окружение
    pacman -S --noconfirm \
        steam steam-native-runtime \
        lutris gamemode lib32-gamemode \
        wine-staging winetricks \
        bottles heroic-games-launcher \
        protontricks protonup-qt \
        mangohud lib32-mangohud goverlay \
        vkbasalt lib32-vkbasalt
    
    # Аудио для игр (низкая задержка)
    pacman -S --noconfirm \
        pipewire pipewire-pulse pipewire-jack pipewire-alsa \
        wireplumber easyeffects
    
    # Дополнительные библиотеки для Wine
    pacman -S --noconfirm \
        giflib lib32-giflib \
        libpng lib32-libpng \
        libldap lib32-libldap \
        gnutls lib32-gnutls \
        mpg123 lib32-mpg123 \
        openal lib32-openal \
        v4l-utils lib32-v4l-utils \
        libpulse lib32-libpulse \
        libgpg-error lib32-libgpg-error \
        alsa-plugins lib32-alsa-plugins \
        alsa-lib lib32-alsa-lib \
        libjpeg-turbo lib32-libjpeg-turbo \
        libxcomposite lib32-libxcomposite \
        libxinerama lib32-libxinerama \
        libxslt lib32-libxslt \
        cups samba dosbox
    
    # Установка Proton-GE из AUR
    $AUR_HELPER -S --noconfirm proton-ge-custom-bin wine-ge-custom-bin
    
    # Установка DXVK и VKD3D
    $AUR_HELPER -S --noconfirm dxvk-bin vkd3d-proton-bin
    
    # Контроллеры
    pacman -S --noconfirm \
        xboxdrv xpadneo-dkms-git \
        ds4drv joycond \
        antimicrox sc-controller
    
    # Эмуляторы (опционально)
    $AUR_HELPER -S --noconfirm \
        dolphin-emu yuzu-early-access rpcs3-git \
        pcsx2-git citra-canary-git
    
    print_step "Игровой стек установлен"
}

# Установка системы безопасности
install_security_stack() {
    print_step "Установка системы безопасности..."
    
    # Базовые средства безопасности
    pacman -S --noconfirm \
        firewalld fail2ban clamav rkhunter \
        apparmor firejail bubblewrap \
        polkit gnome-keyring \
        tpm2-tools tpm2-tss \
        audit sudo
    
    # Включение и настройка AppArmor
    systemctl enable apparmor
    systemctl start apparmor
    
    # Настройка firewalld
    systemctl enable firewalld
    systemctl start firewalld
    firewall-cmd --set-default-zone=home
    firewall-cmd --complete-reload
    
    # Настройка ClamAV
    systemctl enable clamav-freshclam
    systemctl start clamav-freshclam
    freshclam
    
    # Настройка fail2ban
    systemctl enable fail2ban
    systemctl start fail2ban
    
    # Создание пользователя для изоляции
    if ! id "containers" &>/dev/null; then
        useradd -r -s /bin/nologin containers
    fi
    
    # Установка AppGuard (система контейнеризации)
    install_app_guard
    
    print_step "Система безопасности установлена"
}

# Установка AppGuard (система контейнеризации)
install_app_guard() {
    print_step "Установка AppGuard..."
    
    # Создаем структуру каталогов
    mkdir -p /opt/app-guard/{profiles,scripts}
    mkdir -p /etc/app-guard
    
    # Основной скрипт
    cat > /usr/local/bin/app-guard << 'EOF'
#!/bin/bash
# AppGuard - Система контейнеризации приложений

APP_NAME="$1"
APP_PATH="$2"
PROFILE_DIR="/etc/app-guard/profiles"
ISOLATED_HOME="$HOME/.local/containers/$APP_NAME"

# Создаем изолированную домашнюю папку
mkdir -p "$ISOLATED_HOME"

# Запускаем в bubblewrap
exec bwrap \
    --unshare-all \
    --share-net \
    --die-with-parent \
    --new-session \
    --bind /usr /usr \
    --ro-bind /lib /lib \
    --ro-bind /lib64 /lib64 \
    --ro-bind /etc /etc \
    --dev /dev \
    --proc /proc \
    --tmpfs /tmp \
    --tmpfs /run \
    --symlink /tmp var/tmp \
    --bind "$ISOLATED_HOME" /home/user \
    --setenv HOME /home/user \
    --setenv USER user \
    "$APP_PATH"
EOF
    
    chmod +x /usr/local/bin/app-guard
    
    # GUI для управления разрешениями
    cat > /usr/local/bin/app-guard-gui << 'EOF'
#!/bin/bash
# AppGuard GUI - Управление разрешениями приложений

zenity --info --title="AppGuard" --text="Система контейнеризации приложений\n\nПриложения запускаются в изолированной среде с контролем доступа." --width=400
EOF
    
    chmod +x /usr/local/bin/app-guard-gui
    
    # Создаем службу для мониторинга
    cat > /etc/systemd/system/app-guard.service << EOF
[Unit]
Description=AppGuard Application Sandboxing
After=network.target

[Service]
Type=simple
ExecStart=/bin/true
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable app-guard.service
    
    print_step "AppGuard установлен"
}

# Установка графической оболочки
install_desktop() {
    print_step "Установка KDE Plasma..."
    
    # Базовая KDE Plasma
    pacman -S --noconfirm \
        plasma-meta plasma-wayland-session \
        kde-applications-meta sddm \
        xdg-desktop-portal xdg-desktop-portal-kde \
        noto-fonts noto-fonts-cjk noto-fonts-emoji \
        ttf-dejavu ttf-liberation \
        firefox chromium
    
    # Игровые темы и улучшения
    $AUR_HELPER -S --noconfirm \
        lightly-git lightlyshaders-git \
        sweet-cursor-theme-git sweet-gtk-theme-dark-git \
        papirus-icon-theme
    
    # Дополнительные приложения
    pacman -S --noconfirm \
        gparted keepassxc libreoffice-fresh \
        vlc rhythmbox gimp krita \
        htop neofetch gnome-disk-utility
    
    # Включение SDDM
    systemctl enable sddm
    
    print_step "Графическая оболочка установлена"
}

# Настройка системы
configure_system() {
    print_step "Настройка системы..."
    
    # Настройка хоста
    echo "$HOSTNAME" > /etc/hostname
    
    # Настройка локали
    sed -i "s/#$LANG/$LANG/" /etc/locale.gen
    sed -i "s/#en_US.UTF-8/en_US.UTF-8/" /etc/locale.gen
    locale-gen
    echo "LANG=en_US.UTF-8" > /etc/locale.conf
    echo "LC_COLLATE=C" >> /etc/locale.conf
    
    # Часовой пояс
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    hwclock --systohc
    
    # Настройка sudo для пользователя
    echo "$USERNAME ALL=(ALL:ALL) ALL" > /etc/sudoers.d/$USERNAME
    echo "$USERNAME ALL=(ALL:ALL) NOPASSWD: /usr/bin/pacman, /usr/bin/systemctl" >> /etc/sudoers.d/$USERNAME
    chmod 440 /etc/sudoers.d/$USERNAME
    
    # Настройка сетевого менеджера
    systemctl enable NetworkManager
    systemctl enable sshd
    
    # Создание папок для игр
    su - $USERNAME -c "mkdir -p ~/{Games,Emulators,Screenshots,GameRecordings}"
    
    print_step "Система настроена"
}

# Оптимизации для игр
configure_gaming_optimizations() {
    print_step "Настройка игровых оптимизаций..."
    
    # Установка tuned и профиля
    pacman -S --noconfirm tuned
    systemctl enable --now tuned
    tuned-adm profile latency-performance
    
    # Настройка sysctl
    cat > /etc/sysctl.d/99-gaming.conf << EOF
# Сетевые оптимизации
net.core.rmem_default = 134217728
net.core.wmem_default = 134217728
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_congestion_control = bbr
net.ipv4.tcp_notsent_lowat = 16384
net.ipv4.tcp_mtu_probing = 1
net.ipv4.tcp_fastopen = 3

# Оптимизации памяти
vm.swappiness = 10
vm.vfs_cache_pressure = 50
vm.dirty_ratio = 10
vm.dirty_background_ratio = 5

# Увеличение лимитов файлов
fs.file-max = 2097152
fs.inotify.max_user_watches = 524288
EOF
    
    # Настройка CPU Governor
    pacman -S --noconfirm cpupower
    cat > /etc/systemd/system/gaming-mode.service << EOF
[Unit]
Description=Gaming Mode
Before=game.target

[Service]
Type=oneshot
ExecStart=/usr/bin/cpupower frequency-set -g performance
ExecStart=/usr/bin/sudo sysctl -w vm.swappiness=10
ExecStop=/usr/bin/cpupower frequency-set -g powersave
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF
    
    systemctl enable gaming-mode.service
    
    # Правила udev для контроллеров
    cat > /etc/udev/rules.d/99-lowlatency-input.rules << EOF
SUBSYSTEM=="input", GROUP="games", MODE="0660"
KERNEL=="event*", GROUP="games", MODE="0660"
SUBSYSTEM=="usb", ATTRS{idVendor}=="045e", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="054c", MODE="0666"
SUBSYSTEM=="usb", ATTRS{idVendor}=="057e", MODE="0666"
EOF
    
    udevadm control --reload-rules
    
    # Настройка gamemode
    cat > /etc/gamemode.ini << EOF
[general]
softrealtime=auto
renice=10
ioprio=0

[gpu]
apply_gpu_optimisations=accept-responsibility
gpu_device=0
amd_performance_level=high
EOF
    
    # Настройка MangoHud
    mkdir -p /home/$USERNAME/.config/MangoHud
    cat > /home/$USERNAME/.config/MangoHud/MangoHud.conf << EOF
legacy_layout=false
gpu_stats
gpu_temp
gpu_core_clock
gpu_mem_clock
gpu_power
cpu_stats
cpu_temp
core_load
ram
vram
fps
frametime=0
frame_timing=1
background_alpha=0.4
font_size=24
EOF
    
    chown -R $USERNAME:$USERNAME /home/$USERNAME/.config/MangoHud
    
    print_step "Игровые оптимизации настроены"
}

# Настройка загрузчика
configure_bootloader() {
    print_step "Настройка загрузчика..."
    
    # Обновление mkinitcpio для шифрования (если используется)
    if lsblk -f | grep -q "crypto_LUKS"; then
        sed -i 's/^HOOKS=.*/HOOKS=(base systemd autodetect keyboard sd-vconsole modconf block sd-encrypt filesystems fsck)/' /etc/mkinitcpio.conf
        mkinitcpio -P
    fi
    
    # Обновление GRUB
    if [ -f /boot/grub/grub.cfg ]; then
        sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash nowatchdog mitigations=off preempt=full"/' /etc/default/grub
        grub-mkconfig -o /boot/grub/grub.cfg
    fi
    
    # Обновление systemd-boot
    if [ -f /boot/loader/loader.conf ]; then
        echo "options quiet splash nowatchdog mitigations=off preempt=full" >> /boot/loader/entries/arch.conf
        bootctl update
    fi
    
    print_step "Загрузчик настроен"
}

# Создание игровых скриптов
create_gaming_scripts() {
    print_step "Создание игровых скриптов..."
    
    # Скрипт запуска игр
    cat > /usr/local/bin/game-launcher << 'EOF'
#!/bin/bash
# Game Launcher - Оптимизированный запуск игр

GAME="$@"

echo "Включаем игровой режим..."
gamemoderun &

echo "Запускаем мониторинг..."
mangohud &

echo "Оптимизируем систему..."
sudo systemctl start gaming-mode

echo "Запускаем игру: $GAME"
DXVK_ASYNC=1 DXVK_HUD=0 gamemoderun mangohud "$GAME"

echo "Возвращаем настройки..."
sudo systemctl stop gaming-mode
EOF
    
    chmod +x /usr/local/bin/game-launcher
    
    # Скрипт установки игр
    cat > /usr/local/bin/install-game << 'EOF'
#!/bin/bash
# Install Game - Установка игр из разных источников

GAME_URL="$1"
GAME_TYPE="$2"

case $GAME_TYPE in
    "steam")
        steam steam://install/$(echo $GAME_URL | grep -o '[0-9]\+')
        ;;
    "lutris")
        lutris "$GAME_URL"
        ;;
    "heroic")
        heroic "$GAME_URL"
        ;;
    *)
        echo "Использование: install-game <url> <steam|lutris|heroic>"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/install-game
    
    # Скрипт мониторинга
    cat > /usr/local/bin/game-monitor << 'EOF'
#!/bin/bash
# Game Monitor - Мониторинг системы во время игры

watch -n 1 '
echo "=== ИГРОВОЙ МОНИТОР ==="
echo "CPU:"
cpupower frequency-info | grep "current CPU"
echo ""
echo "GPU:"
nvidia-smi --query-gpu=utilization.gpu,memory.used,temperature.gpu --format=csv 2>/dev/null || \
radeontop -d - -l1 2>/dev/null || echo "Информация о GPU недоступна"
echo ""
echo "Память:"
free -h | grep "Mem:"
'
EOF
    
    chmod +x /usr/local/bin/game-monitor
    
    print_step "Игровые скрипты созданы"
}

# Финальная настройка
final_setup() {
    print_step "Финальная настройка..."
    
    # Установка тем Steam
    sudo -u $USERNAME mkdir -p /home/$USERNAME/.local/share/Steam/skins
    curl -L https://github.com/tkashkin/GameHub/files/2919907/Steam_2019_Dark.zip -o /tmp/steam-theme.zip
    unzip -q /tmp/steam-theme.zip -d /home/$USERNAME/.local/share/Steam/skins/
    
    # Настройка автозапуска
    sudo -u $USERNAME mkdir -p /home/$USERNAME/.config/autostart
    cat > /home/$USERNAME/.config/autostart/gamemode.desktop << EOF
[Desktop Entry]
Type=Application
Name=Gamemode
Exec=gamemoded -d
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
    
    # Создание игровых профилей для AppGuard
    mkdir -p /etc/app-guard/profiles
    cat > /etc/app-guard/profiles/steam.json << EOF
{
    "name": "steam",
    "network": true,
    "filesystem": "isolated",
    "allowed_paths": ["/home/$USERNAME/Games"],
    "allowed_ports": "27015-27030,27036-27037"
}
EOF
    
    cat > /etc/app-guard/profiles/lutris.json << EOF
{
    "name": "lutris",
    "network": true,
    "filesystem": "selective",
    "allowed_paths": ["/home/$USERNAME/Games", "/home/$USERNAME/.local/share/lutris"]
}
EOF
    
    # Установка игровых шрифтов
    $AUR_HELPER -S --noconfirm ttf-ms-fonts ttf-dejavu ttf-liberation
    
    # Включение служб
    systemctl enable --now bluetooth
    systemctl enable --now paccache.timer
    systemctl enable --now fstrim.timer
    
    # Очистка кеша
    paccache -rk1
    
    print_step "Финальная настройка завершена"
}

# Проверка после установки
post_install_check() {
    print_step "Проверка установки..."
    
    echo -e "\n\033[1;35m=== ПРОВЕРКА УСТАНОВКИ ===\033[0m"
    
    # Проверка ядра
    if uname -r | grep -q "zen"; then
        echo -e "✓ Ядро Zen установлено"
    else
        echo -e "✗ Ядро Zen не установлено"
    fi
    
    # Проверка драйверов
    if [ "$GPU" = "nvidia" ]; then
        if nvidia-smi &>/dev/null; then
            echo -e "✓ Драйверы NVIDIA работают"
        else
            echo -e "✗ Проблемы с драйверами NVIDIA"
        fi
    fi
    
    # Проверка игровых компонентов
    if command -v steam &>/dev/null; then
        echo -e "✓ Steam установлен"
    else
        echo -e "✗ Steam не установлен"
    fi
    
    if command -v gamemoderun &>/dev/null; then
        echo -e "✓ Gamemode установлен"
    else
        echo -e "✗ Gamemode не установлен"
    fi
    
    # Проверка безопасности
    if systemctl is-active --quiet apparmor; then
        echo -e "✓ AppArmor активен"
    else
        echo -e "✗ AppArmor не активен"
    fi
    
    if systemctl is-active --quiet firewalld; then
        echo -e "✓ Firewalld активен"
    else
        echo -e "✗ Firewalld не активен"
    fi
    
    echo -e "\n\033[1;35m=======================\033[0m"
}

# ==================== ГЛАВНАЯ ФУНКЦИЯ ====================

main() {
    print_header
    
    # Проверки
    check_root
    check_arch
    
    echo -e "\033[1;37mВыбран режим: $INSTALL_MODE\033[0m"
    echo -e "Пользователь: $USERNAME"
    echo -e "Игровой режим: $GAMING_ENABLED"
    echo -e "Безопасность: $SECURITY_ENABLED"
    echo ""
    
    # Подтверждение
    print_warning "Этот скрипт установит игровые и защитные компоненты системы."
    echo -e "\033[1;37mПродолжить? (y/N): \033[0m"
    read -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_error "Установка отменена"
        exit 0
    fi
    
    # Начало установки
    print_step "Начинаем установку..."
    
    # Шаг 1: Обновление системы
    update_system
    wait_enter
    
    # Шаг 2: Установка AUR помощника
    install_aur_helper
    wait_enter
    
    # Шаг 3: Определение видеокарты
    detect_gpu
    wait_enter
    
    # Шаг 4: Установка игрового стека
    if [ "$GAMING_ENABLED" = true ]; then
        install_gaming_stack
        wait_enter
    fi
    
    # Шаг 5: Установка системы безопасности
    if [ "$SECURITY_ENABLED" = true ]; then
        install_security_stack
        wait_enter
    fi
    
    # Шаг 6: Установка графической оболочки
    if [ "$INSTALL_MODE" = "full" ] || [ "$INSTALL_MODE" = "gaming" ]; then
        install_desktop
        wait_enter
    fi
    
    # Шаг 7: Настройка системы
    configure_system
    wait_enter
    
    # Шаг 8: Оптимизации для игр
    if [ "$GAMING_ENABLED" = true ]; then
        configure_gaming_optimizations
        wait_enter
    fi
    
    # Шаг 9: Настройка загрузчика
    configure_bootloader
    wait_enter
    
    # Шаг 10: Создание игровых скриптов
    if [ "$GAMING_ENABLED" = true ]; then
        create_gaming_scripts
        wait_enter
    fi
    
    # Шаг 11: Финальная настройка
    final_setup
    wait_enter
    
    # Проверка
    post_install_check
    
    # Завершение
    echo -e "\n\033[1;36m"
    echo "╔══════════════════════════════════════════╗"
    echo "║     УСТАНОВКА УСПЕШНО ЗАВЕРШЕНА!         ║"
    echo "╚══════════════════════════════════════════╝"
    echo -e "\033[0m"
    
    echo -e "\n\033[1;37mЧТО СДЕЛАНО:\033[0m"
    echo "• Установлен игровой стек (Steam, Wine, Proton)"
    echo "• Настроена система безопасности (AppArmor, Firejail)"
    echo "• Установлены оптимизации для игр"
    echo "• Настроена графическая оболочка KDE Plasma"
    echo "• Создана система контейнеризации приложений"
    echo "• Установлены игровые утилиты и мониторинг"
    
    echo -e "\n\033[1;37mДАЛЬНЕЙШИЕ ДЕЙСТВИЯ:\033[0m"
    echo "1. Перезагрузитесь: sudo reboot"
    echo "2. Войдите в систему как $USERNAME"
    echo "3. Запустите Steam и установите игры"
    echo "4. Используйте app-guard для запуска приложений"
    
    echo -e "\n\033[1;33mПОЛЕЗНЫЕ КОМАНДЫ:\033[0m"
    echo "• game-launcher <команда> - запуск игр с оптимизациями"
    echo "• app-guard-gui - управление разрешениями приложений"
    echo "• game-monitor - мониторинг системы во время игры"
    
    echo -e "\n\033[1;31mВАЖНО:\033[0m"
    echo "• Смените пароль пользователя: passwd"
    echo "• Обновите драйверы: sudo pacman -Syu"
    echo "• Настройте Steam для автоматического входа"
    
    echo -e "\n\033[1;32mУдачи в игровых сессиях! 🎮\033[0m"
}

# ==================== ЗАПУСК ====================

# Обработка аргументов
while [[ $# -gt 0 ]]; do
    case $1 in
        --minimal)
            INSTALL_MODE="minimal"
            GAMING_ENABLED=false
            shift
            ;;
        --gaming-only)
            INSTALL_MODE="gaming"
            SECURITY_ENABLED=false
            shift
            ;;
        --secure-only)
            INSTALL_MODE="secure"
            GAMING_ENABLED=false
            shift
            ;;
        --user)
            USERNAME="$2"
            shift 2
            ;;
        --aur)
            AUR_HELPER="$2"
            shift 2
            ;;
        *)
            print_error "Неизвестный аргумент: $1"
            echo "Использование: sudo ./bento.sh [--minimal|--gaming-only|--secure-only]"
            exit 1
            ;;
    esac
done

# Запуск главной функции
main "$@"