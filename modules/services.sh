#!/usr/bin/env bash

preflight_services() {
    local requested
    local other
    local unit

    for requested in nginx apache; do
        if ! contains "$requested" "${selected_modules[@]}"; then
            continue
        fi

        other=nginx
        unit=nginx

        if [[ $requested == nginx ]]; then
            other=apache
            unit=httpd
        fi

        if pacman -Q "$other" >/dev/null 2>&1 || systemctl is-active --quiet "$unit" || systemctl is-enabled --quiet "$unit" 2>/dev/null; then
            fail "Conflicting server $other is installed, enabled or active. Resolve it manually first."
        fi
    done

    if contains audio "${selected_modules[@]}"; then
        if ! systemctl --user show-environment >/dev/null; then
            fail 'A working systemd user session is required'
        fi
    fi
}

plan_services() {
    local name

    for name in "${selected_modules[@]}"; do
        case "$name" in
            base)
                echo 'Enable/start: NetworkManager. Install Zsh without changing login shells.'
                ;;
            desktop-sway)
                echo 'Desktop: Wayland with Sway, swaybar/i3status, Mako, Foot and wmenu.'
                echo 'Install screenshot, clipboard, lock and portal tools. Configure startup in Sway manually.'
                ;;
            desktop-i3)
                echo 'Desktop: Xorg with i3, i3status, Picom and Dunst. Configure the session manually.'
                ;;
            docker)
                printf 'Enable/start: docker. Add %s to docker group (root-equivalent access).\n' "$(id -un)"
                ;;
            bluetooth)
                echo 'Enable/start: bluetooth.'
                ;;
            audio)
                echo 'Enable/start user units: pipewire, pipewire-pulse, wireplumber.'
                ;;
            nginx)
                echo 'Enable/start: nginx, php-fpm. Virtual hosts and PHP routing require manual configuration.'
                ;;
            apache)
                echo 'Enable/start: httpd, php-fpm. Virtual hosts and PHP routing require manual configuration.'
                ;;
            php)
                echo 'Enable gd in /etc/php/php.ini. PHP-FPM remains stopped unless a server module is selected.'
                ;;
            mail)
                echo 'Enable/start: mailpit.'
                ;;
        esac
    done
}

enable_php_extension() {
    local file=$1
    local extension=$2

    if [[ ! -f $file ]]; then
        fail "PHP configuration not found: $file"
    fi

    sudo sed -i "s/^;[[:space:]]*extension=$extension[[:space:]]*$/extension=$extension/" "$file"
}

configure_services() {
    local -a user_groups=()

    case "$1" in
        base)
            sudo systemctl enable --now NetworkManager
            echo 'Optional login shell change: chsh -s /bin/zsh'
            ;;
        docker)
            sudo systemctl enable --now docker
            read -r -a user_groups <<< "$(id -nG)"

            if ! contains docker "${user_groups[@]}"; then
                sudo usermod -aG docker "$(id -un)"
                echo 'Log out and back in to apply docker group membership.'
            fi
            ;;
        bluetooth)
            sudo systemctl enable --now bluetooth
            ;;
        audio)
            systemctl --user enable --now pipewire pipewire-pulse wireplumber
            ;;
        nginx)
            sudo systemctl enable --now nginx php-fpm
            ;;
        apache)
            sudo systemctl enable --now httpd php-fpm
            ;;
        php)
            enable_php_extension /etc/php/php.ini gd
            ;;
        mail)
            sudo systemctl enable --now mailpit
            ;;
    esac
}
