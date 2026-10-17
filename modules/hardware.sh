#!/usr/bin/env bash

preflight_hardware() {
    if ! command -v lspci >/dev/null; then
        fail 'Hardware inspection requires lspci. Install pciutils manually first.'
    fi

    if ! grep -q 'vendor_id[[:space:]]*: AuthenticAMD' /proc/cpuinfo; then
        fail 'hardware-amd-nvidia requires an AMD CPU'
    fi

    local line
    local kernel
    local path
    local old_driver
    local -a gpus=()
    local -a kernels=()

    while IFS= read -r line; do
        if [[ $line == *'[10de:'* ]] && [[ $line == *'[0300]'* || $line == *'[0302]'* ]]; then
            gpus+=("$line")
        fi
    done < <(lspci -nn)

    if [[ ${#gpus[@]} != 1 ]]; then
        fail 'Expected exactly one NVIDIA GPU. Configure ambiguous or multi-GPU systems manually.'
    fi

    gpu_description=${gpus[0]}
    # Accept only explicit, known Turing-or-newer architecture codes.
    if [[ ! $gpu_description =~ (TU|GA|AD|GB)[0-9]{3} ]]; then
        fail "Unsupported or unknown NVIDIA architecture: $gpu_description. Check https://wiki.archlinux.org/title/NVIDIA"
    fi

    if [[ ! -r /sys/class/dmi/id/chassis_type ]]; then
        fail 'Cannot determine chassis type'
    fi

    case "$(cat /sys/class/dmi/id/chassis_type)" in
        8|9|10|11|14|30|31|32)
            fail 'Laptop GPU power management requires manual driver selection. This module supports desktop systems only.'
            ;;
    esac

    local -a conflicting_drivers=(
        nvidia
        nvidia-dkms
        nvidia-lts
        nvidia-open
        nvidia-open-lts
        nvidia-580xx-dkms
        nvidia-580xx-utils
    )

    for old_driver in "${conflicting_drivers[@]}"; do
        if pacman -Q "$old_driver" >/dev/null 2>&1; then
            fail "Existing driver $old_driver requires manual migration before using this module"
        fi
    done

    shopt -s nullglob

    for path in /usr/lib/modules/*/pkgbase; do
        IFS= read -r kernel < "$path"

        case "$kernel" in
            linux|linux-lts|linux-zen|linux-hardened)
                ;;
            *)
                fail "Unsupported kernel: $kernel"
                ;;
        esac

        if ! pacman -Q "$kernel" >/dev/null 2>&1; then
            fail "Unmanaged kernel tree: $path"
        fi

        if ! contains "$kernel" "${kernels[@]}"; then
            kernels+=("$kernel")
        fi
    done

    shopt -u nullglob

    if [[ ${#kernels[@]} == 0 ]]; then
        fail 'No supported installed kernel found'
    fi

    for kernel in "${kernels[@]}"; do
        official_packages+=("$kernel-headers")
    done

    official_packages+=(
        amd-ucode
        nvidia-open-dkms
        nvidia-utils
        nvidia-settings
        opencl-nvidia
        egl-wayland
        libva-nvidia-driver
        vulkan-icd-loader
        vulkan-tools
    )
    if contains docker "${selected_modules[@]}"; then
        official_packages+=(nvidia-container-toolkit)
    fi

    if ! command -v mkinitcpio >/dev/null; then
        fail 'This hardware module requires mkinitcpio. Configure other initramfs generators manually.'
    fi
}

plan_hardware() {
    printf 'Detected GPU: %s\n' "$gpu_description"
    echo 'Driver: nvidia-open-dkms with headers for all detected supported kernels. Rebuild initramfs with mkinitcpio -P.'
    echo 'No bootloader changes or automatic multilib activation. Reboot and verify the driver manually.'

    if contains docker "${selected_modules[@]}"; then
        echo 'Configure NVIDIA Docker runtime in /etc/docker/daemon.json and restart Docker (interrupts running containers).'
    fi
}

configure_hardware() {
    if contains docker "${selected_modules[@]}"; then
        sudo nvidia-ctk runtime configure --runtime=docker
        sudo systemctl restart docker
    fi

    sudo mkinitcpio -P
    echo 'Reboot, then verify: nvidia-smi and vulkaninfo --summary'
}
