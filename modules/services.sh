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
                echo 'Desktop: Wayland with Sway, Waybar, Mako, Alacritty, awww and wlsunset.'
                echo 'Install screenshot, clipboard, lock, keyring and portal tools. Configure startup in Sway manually.'
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
                echo 'Enable gd in /etc/php/conf.d unless already enabled. PHP-FPM remains stopped unless a server module is selected.'
                ;;
            mail)
                echo 'Enable/start: mailpit.'
                ;;
        esac
    done
}

# Use conf.d instead of editing php.ini, so package upgrades do not create
# php.ini.pacnew. Skip extensions already enabled to avoid duplicate loading.
enable_php_extension() {
    local extension=$1
    local enabled_pattern="^[[:space:]]*extension[[:space:]]*=[[:space:]]*\"?$extension(\.so)?\"?[[:space:]]*$"

    if [[ ! -d /etc/php/conf.d ]]; then
        fail 'PHP configuration directory not found: /etc/php/conf.d'
    fi

    if grep -rEqs --include='*.ini' "$enabled_pattern" /etc/php/php.ini /etc/php/conf.d; then
        return 0
    fi

    printf 'extension=%s\n' "$extension" | sudo tee "/etc/php/conf.d/$extension.ini" >/dev/null

    # A running PHP-FPM loads extensions only on start.
    sudo systemctl try-restart php-fpm
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
            enable_php_extension gd
            ;;
        mail)
            sudo systemctl enable --now mailpit
            ;;
    esac
}
