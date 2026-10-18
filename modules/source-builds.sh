#!/usr/bin/env bash

# Existing checkouts must belong to the requested HTTPS repository.
check_repo() {
    local url=$1
    local path=$2
    local origin

    if [[ -e $path || -L $path ]]; then
        if [[ ! -d $path/.git ]]; then
            fail "Not a Git checkout: $path"
        fi

        if ! origin=$(git -C "$path" config --get remote.origin.url); then
            fail "Missing origin: $path"
        fi

        if [[ ${origin%.git} != "${url%.git}" ]]; then
            fail "Unexpected origin in $path: $origin"
        fi
    fi
}

preflight_sources() {
    if contains personal "${selected_modules[@]}"; then
        check_repo "https://github.com/$GIT_USERNAME/scripts.git" "$HOME/.local/scripts"
    fi

    if contains mnu "${selected_modules[@]}"; then
        check_repo "https://github.com/$GIT_USERNAME/mnu.git" "$GIT_DIR/mnu"
    fi
}

plan_sources() {
    if contains aur-helper "${selected_modules[@]}"; then
        echo 'AUR helper: keep existing paru, otherwise review and build https://aur.archlinux.org/paru.git.'
    fi

    if contains neovim-source "${selected_modules[@]}"; then
        echo 'Build Neovim stable from HTTPS in a unique temporary directory, install to /usr/local. Running editors remain open.'
    fi

    if contains mnu "${selected_modules[@]}"; then
        printf 'Build https://github.com/%s/mnu.git under %s/mnu. Install to its Makefile prefix.\n' "$GIT_USERNAME" "$GIT_DIR"
    fi

    if contains personal "${selected_modules[@]}"; then
        printf 'Clone https://github.com/%s/scripts.git to %s/.local/scripts, preserve matching checkouts.\n' "$GIT_USERNAME" "$HOME"
    fi
}

clone_repo() {
    local url=$1
    local path=$2
    check_repo "$url" "$path"

    if [[ ! -d $path ]]; then
        mkdir -p "$(dirname "$path")"
        git clone "$url" "$path"
    fi
}

install_paru() (
    operation='paru build'

    if command -v paru >/dev/null; then
        exit 0
    fi

    mkdir -p "$TMP_DIR"
    work_dir=$(mktemp -d "$TMP_DIR/unix-bootstrap-paru.XXXXXXXX")
    trap 'rm -rf -- "$work_dir"' EXIT
    git clone https://aur.archlinux.org/paru.git "$work_dir/paru"
    echo 'Review PKGBUILD, sources and any install scripts before building.'
    git -C "$work_dir/paru" ls-files
    printf 'Review checkout: %s\n' "$work_dir/paru"
    less "$work_dir/paru/PKGBUILD"
    read -r -p 'Have you reviewed the build files and want to build paru? [y/N] ' answer

    if [[ $answer != y && $answer != Y ]]; then
        exit 1
    fi

    cd "$work_dir/paru"
    makepkg -si
)

build_neovim() (
    operation='Neovim build'
    mkdir -p "$TMP_DIR"
    work_dir=$(mktemp -d "$TMP_DIR/unix-bootstrap-neovim.XXXXXXXX")
    trap 'rm -rf -- "$work_dir"' EXIT
    git clone --branch stable --single-branch https://github.com/neovim/neovim.git "$work_dir/neovim"
    make -C "$work_dir/neovim" CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo make -C "$work_dir/neovim" install
)

configure_sources() {
    case "$1" in
        neovim-source)
            build_neovim
            ;;
        mnu)
            clone_repo "https://github.com/$GIT_USERNAME/mnu.git" "$GIT_DIR/mnu"
            make -C "$GIT_DIR/mnu"
            sudo make -C "$GIT_DIR/mnu" install
            ;;
        composer)
            if [[ ${#composer_packages[@]} -gt 0 ]]; then
                composer global require -- "${composer_packages[@]}"
            fi
            ;;
        personal)
            clone_repo "https://github.com/$GIT_USERNAME/scripts.git" "$HOME/.local/scripts"
            ;;
    esac
}
