# unix_bootstrap

Bash configurator for an existing Arch based Linux workstation. Choose package
and service modules, inspect the plan, and confirm before applying changes.

This project does not partition disks or install Arch Linux. Supported hosts are
Arch Linux x86_64 installations running systemd. Derivatives and other
architectures are not supported.

## Requirements

- A regular user account with working `sudo` access. Do not run with `sudo`.
- `bash`, `sudo`, `pacman`, `systemctl`, `git`, and `mktemp` already available.
- Internet access, configured official repositories, and a maintained Arch system.
- A working systemd user session for audio.
- `lspci` from `pciutils` installed before selecting the hardware module.

Review [Arch news](https://archlinux.org/news/) before upgrading. Package names
and AUR recipes can change on a rolling distribution. The installer stops on a
failure instead of skipping unavailable packages. Official package availability
is checked against the existing local sync databases before confirmation.

## Quick start

Clone or download this repository, then run:

```bash
./bootstrap --help
./bootstrap list
./bootstrap install base desktop-sway --dry-run
./bootstrap install base desktop-sway
```

Help and module listing do not require Arch. Installation and dry-run plans check
that the host is supported. A dry run performs read-only host checks without
`sudo`, package installation, cloning, service changes, or file creation. Local
configuration is trusted shell code and must itself be free of side effects.

The installer resolves module dependencies and deduplicates package lists. It
prints the plan and asks `Apply this plan? [y/N]`. Only `y` or `Y` proceeds. There
is no unattended confirmation flag.

Official packages are installed together using `pacman -Syu --needed`. This is a
full system upgrade and can affect packages outside the selected modules. Partial
upgrades are [unsupported by Arch](https://wiki.archlinux.org/title/System_maintenance#Partial_upgrades_are_unsupported).

## Modules

| Module | Packages and behavior |
| --- | --- |
| `base` | Common CLI tools, Zsh, networking. Enables NetworkManager. Does not change login shells. |
| `desktop-sway` | Wayland, Sway, swaybar/i3status, Mako, Foot, wmenu, screenshots, clipboard, locking and desktop portals. Includes `base` and shared desktop utilities. |
| `desktop-i3` | Xorg, i3, i3status, Picom, Dunst and X11 utilities. Includes `base` and shared desktop utilities. |
| `development` | Compilers, CMake, Go, Node.js, Python and developer tools. Includes `base`. |
| `docker` | Docker and supporting tools. Includes `base`, starts Docker and adds the current user to its group. |
| `bluetooth` | BlueZ and Blueman. Includes `base`, starts Bluetooth. |
| `audio` | PipeWire and WirePlumber. Includes `base`, starts user units. |
| `aur-helper` | Builds paru from AUR if it is missing. Existing paru is kept. |
| `hardware-amd-nvidia` | Conservative desktop-only AMD CPU and NVIDIA GPU setup. See hardware limitations below. |
| `php` | PHP, PHP-FPM and GD. Enables GD without starting PHP-FPM. |
| `composer` | Includes `php`, installs Composer. Supports optional global packages. |
| `nginx` | Includes `php`, starts Nginx and PHP-FPM. |
| `apache` | Includes `php`, installs Apache integration packages, starts httpd and PHP-FPM. |
| `mariadb` | Initializes an empty data directory, starts MariaDB, optionally creates a localhost account without grants. |
| `postgres` | Initializes an empty cluster, starts PostgreSQL, enables PHP PostgreSQL extensions. |
| `mail` | Installs Mailpit from AUR and starts its service. |
| `betterdmenu` | Builds betterdmenu from HTTPS. No GitHub account or SSH key is needed for a public repository. |
| `neovim-source` | Builds the stable branch of Neovim and installs into `/usr/local`. Running editors remain open. |
| `personal` | Personal applications, imv, AUR choices and bin(scripts) repository. Includes `base`. |

Modules with AUR packages automatically include `aur-helper`. Paru runs as the
regular user with build review enabled. When bootstrapping paru, inspect its
PKGBUILD and any referenced sources or install scripts before confirming the
build. The temporary checkout location is shown by Git. AUR recipes execute code
and should be reviewed as described in the [Arch AUR guide](https://wiki.archlinux.org/title/Arch_User_Repository).

Docker group membership grants root-equivalent access. Log out and back in after
it is added. PipeWire can conflict with an existing audio setup. Review package
manager prompts rather than forcing conflicting replacements.

Nginx and Apache are alternatives. Selecting both, or selecting one while the
other is installed, enabled or running, fails before installation. Virtual hosts,
TLS, PHP routing and Apache module configuration remain manual.

## Desktop selection

Choose one desktop variant per invocation:

```bash
./install_desktop.sh --wayland --dry-run
./install_desktop.sh --wayland
./install_desktop.sh --xorg
# Equivalent module interface:
./bootstrap install desktop-sway
./bootstrap install desktop-i3
```

The desktop wrapper defaults to Wayland with Sway. Selecting both variants in one
invocation is rejected. Existing desktop packages and configuration are preserved,
so switching the selected variant does not uninstall the previous environment.

Shared utilities are listed in `packages/desktop-common.txt`. The Sway variant
omits Xorg-specific tools such as Picom, xclip, maim and xdotool. It does not
explicitly install Xwayland. Applications and their dependencies may still pull
in X11 libraries or compatibility components.

Desktop installation supplies packages, not personal dotfiles or session
autostart configuration. Start Sway from a TTY with `sway`. Keep the packaged
`include /etc/sway/config.d/*` in custom Sway configurations for session environment
integration. Configure Mako, swayidle, swaylock and wallpaper startup yourself.
PipeWire is included for portal screen sharing, but the `audio` module remains
an explicit choice for the complete audio setup. See the
[Sway guide](https://wiki.archlinux.org/title/Sway) and
[portal guide](https://wiki.archlinux.org/title/XDG_Desktop_Portal).

## Configuration

Defaults are in `config.sh`. Existing `GIT_DIR`, `GIT_USERNAME` and `TMP_DIR`
environment values are respected. Optional `config.local.sh` overrides defaults
and is ignored by Git:

```bash
cp config.example.sh config.local.sh
```

Both configuration files are sourced as trusted Bash code. `GIT_DIR` and
`TMP_DIR` must be absolute paths. The default temporary parent is `$TMPDIR` or
`/tmp`. Builds use unique subdirectories and remove only their own temporary
checkout on exit.

`GIT_USERNAME` defaults to `pr0sp3ro` and is used only for `personal` and
`betterdmenu`. Changing it requires that the corresponding public repositories
exist. Other modules do not clone repositories from that account. Existing
checkouts must have the expected HTTPS origin. They are preserved without pulling
or resetting local work. Migrate old SSH origins manually if appropriate.

Examples:

```bash
./bootstrap install development docker audio
./bootstrap install betterdmenu --dry-run
./bootstrap install betterdmenu
./bootstrap install composer --dry-run -- laravel/installer
./bootstrap install composer -- laravel/installer
./bootstrap install neovim-source
```

Source builds install files outside pacman's ownership. Neovim uses `/usr/local`.
Betterdmenu uses its Makefile installation prefix. Review its source and build
settings before installation. Global Composer packages also execute upstream
package code as your user.

## Hardware limitations

The hardware module requires an AMD CPU, exactly one NVIDIA display GPU, a
recognizable Turing-or-newer architecture code (TU, GA, AD or GB) in `lspci`, and
an installed supported kernel (`linux`, `linux-lts`, `linux-zen`, or
`linux-hardened`). It selects `nvidia-open-dkms` and matching kernel headers.
Unknown GPUs, laptop chassis, custom kernels and conflicting existing drivers
require manual configuration. This deliberately conservative check may reject
otherwise usable hardware.

The module requires mkinitcpio and rebuilds initramfs. It does not change the
bootloader, activate multilib or install 32-bit graphics packages. Verify AMD
microcode loading in your boot configuration yourself. See the current
[Arch NVIDIA guide](https://wiki.archlinux.org/title/NVIDIA) and
[DKMS guide](https://wiki.archlinux.org/title/Dynamic_Kernel_Module_Support).

NVIDIA Docker integration is configured only when both `hardware-amd-nvidia` and
`docker` are selected in the same invocation. It modifies Docker's daemon
configuration and restarts Docker, interrupting running containers. Reboot after
driver installation and check `nvidia-smi` and `vulkaninfo --summary`.

## Repeated runs and failures

Installed packages are skipped when current. Selected services are enabled and
started again. Existing Git checkouts are preserved, but source builds can run
again. Composer commands may update dependencies on repeated runs.

Database modules keep recognized existing clusters and refuse to initialize
nonempty unrecognized data directories. They use the standard Arch data paths
and service configuration. Custom data paths must be managed manually. Existing
MariaDB accounts are left unchanged. Password input is hidden and SQL is sent on
standard input, not in command arguments or installer output. Configure database grants
manually. For PostgreSQL, optional role creation is:

```bash
sudo -u postgres createuser --interactive
```

A failure stops the run and reports the module and operation. Earlier changes
remain applied. There is no automatic rollback of package upgrades, services or
configuration. Resolve the failure, review a new plan, and rerun the selected
modules. Back up important configuration and database data before using database
or hardware modules.

## Legacy entry points

Existing script names remain wrappers. `install_base.sh` now selects only `base`.
`install_desktop.sh` defaults to `desktop-sway`, accepts `--wayland` for Sway
and `--xorg` for i3. Docker, audio, Bluetooth and personal
applications require separate explicit selections. The other install and `dev/`
scripts select their corresponding module.

`build_betterdmenu.sh` builds betterdmenu. `build_suckless.sh` remains a compatibility
wrapper for the same module, without component selection flags.
`dev/composer.sh laravel/installer` preserves the old global-package interface.
Wrappers accept `--dry-run`, `-h` and `--help`.

## Verification

Syntax and optional static analysis commands:

```bash
bash -n bootstrap
find . -type f -name '*.sh' -exec bash -n {} \;
shellcheck -x bootstrap modules/*.sh ./*.sh dev/*.sh
```

No automated installation tests are bundled. Before using a release on a primary
machine, manually verify on a disposable Arch VM:

- Help, listing and dry-run leave packages, files and services unchanged.
- Public modules work without a GitHub account or SSH key.
- Cancelling the final prompt makes no changes.
- A missing paru is built only after build-file review and confirmation.
- A package installation failure stops before module configuration.
- A repeated run preserves existing database data, accounts and Git work.
- Nonempty unrecognized database directories are rejected.
- Selecting conflicting web servers or both desktop variants stops before installation.
- In a new Sway session, check terminal/menu, notifications, clipboard, screenshots,
  locking and portal screen sharing after configuring session startup.
- In an i3 session, check the Xorg-specific tools and session startup.
- Services are started only by the selected modules and their documented dependencies.

GPU installation requires separate verification on supported physical hardware.
A VM does not establish driver compatibility.

## License

[MIT](LICENSE). External packages and cloned repositories retain their own licenses.
