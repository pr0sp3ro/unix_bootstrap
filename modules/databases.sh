#!/usr/bin/env bash

plan_databases() {
    if contains mariadb "${selected_modules[@]}"; then
        echo 'MariaDB: initialize only an empty data directory, enable/start mariadb, optionally create a localhost account without grants.'
    fi

    if contains postgres "${selected_modules[@]}"; then
        echo 'PostgreSQL: initialize only an empty data directory, enable/start postgresql, enable PHP pgsql extensions. Optional role creation remains manual.'
    fi
}

configure_databases() {
    # Never expose secrets if the caller enabled shell tracing.
    set +x
    local db_user
    local db_password
    local escaped_password
    local exists

    case "$1" in
        mariadb)
            if ! sudo test -d /var/lib/mysql/mysql; then
                if sudo test -d /var/lib/mysql && [[ -n $(sudo find /var/lib/mysql -mindepth 1 -maxdepth 1 -print -quit) ]]; then
                    fail 'MariaDB directory contains unrecognized data. Initialize or migrate it manually.'
                fi

                sudo mariadb-install-db --user=mysql --basedir=/usr --datadir=/var/lib/mysql
            fi

            sudo systemctl enable --now mariadb
            read -r -p 'New MariaDB localhost username (blank to skip): ' db_user

            if [[ -z $db_user ]]; then
                return 0
            fi

            if [[ ! $db_user =~ ^[a-zA-Z_][a-zA-Z0-9_]{0,79}$ ]]; then
                fail 'Use a username of up to 80 letters, digits and underscores, starting with a letter or underscore'
            fi

            exists=$(
                sudo mariadb --batch --skip-column-names \
                    -e "SELECT COUNT(*) FROM mysql.user WHERE User='$db_user' AND Host='localhost'"
            )
            if [[ $exists != 0 ]]; then
                echo 'Account already exists. Leaving it unchanged.'
                return 0
            fi

            read -r -s -p 'New account password: ' db_password
            printf '\n'

            if [[ -z $db_password ]]; then
                fail 'An empty password is not accepted'
            fi

            escaped_password=${db_password//\'/\'\'}
            # Disable backslash escapes and escape single quotes in SQL string literals.
            # Input is sent over stdin, never as a process argument or output.
            if ! printf '%s\n' \
                "SET SESSION sql_mode='NO_BACKSLASH_ESCAPES';" \
                "CREATE USER IF NOT EXISTS '$db_user'@'localhost' IDENTIFIED BY '$escaped_password';" \
                | sudo mariadb --binary-mode --batch >/dev/null 2>&1; then
                fail 'Account creation failed. Server details suppressed to avoid exposing the password.'
            fi

            unset db_password escaped_password
            echo 'Account created without database grants. Configure grants manually.'
            ;;
        postgres)
            if ! sudo test -f /var/lib/postgres/data/PG_VERSION; then
                if sudo test -d /var/lib/postgres/data && [[ -n $(sudo find /var/lib/postgres/data -mindepth 1 -maxdepth 1 -print -quit) ]]; then
                    fail 'PostgreSQL directory contains unrecognized data. Initialize or migrate it manually.'
                fi

                sudo -u postgres initdb --locale=C.UTF-8 --encoding=UTF8 -D /var/lib/postgres/data
            fi

            sudo systemctl enable --now postgresql
            enable_php_extension /etc/php/php.ini pdo_pgsql
            enable_php_extension /etc/php/php.ini pgsql
            echo 'Optional PostgreSQL role: sudo -u postgres createuser --interactive'
            ;;
    esac
}
