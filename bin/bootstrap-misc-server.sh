#!/bin/bash
set -euo pipefail

log_section() {
    printf "\n%b\n" "$(tput setaf 4)$(tput bold)==> $1$(tput sgr0)"
}

log_step() {
    printf "    %b\n" "$(tput setaf 10)✔ $1$(tput sgr0)"
}

log_block_result_ok() {
    printf "%b\n" "$(tput setaf 4)✓ $1$(tput sgr0)"
}

log_block_result_error() {
    printf "%b\n" "$(tput setaf 1)✗ $1$(tput sgr0)"
}

log_warning() {
    printf "%b\n" "$(tput setaf 3)⚠ $1$(tput sgr0)"
}

sudo -v

log_section "System Update"
sudo apt-get update
sudo apt-get -y upgrade
log_block_result_ok "System Update completed successfully"

log_section "Cleanup"
sudo apt-get -y autoremove
sudo apt-get -y autoclean
sudo apt-get clean
log_block_result_ok "Cleanup completed successfully"

log_section "Locales & Timezone"
TARGET_TIMEZONE="UTC"
TARGET_LOCALE="C.UTF-8"
errors=()
sudo timedatectl set-timezone "$TARGET_TIMEZONE"
sudo apt-get install -y locales
sudo locale-gen "$TARGET_LOCALE"
sudo update-locale LANG="$TARGET_LOCALE"
current_timezone=$(timedatectl show --property=Timezone --value)
current_locale=$(locale | grep LANG= | cut -d= -f2)
[[ "$current_timezone" != "$TARGET_TIMEZONE" ]] && errors+=("timezone: desired $TARGET_TIMEZONE, current $current_timezone")
[[ "$current_locale" != "$TARGET_LOCALE" ]] && errors+=("locale: desired $TARGET_LOCALE, current $current_locale")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Locales & Timezone applied successfully"
else
    log_block_result_error "Locales & Timezone ERROR: ${errors[*]}"
fi

log_section "SSH Key Setup"
TARGET_SSH_KEY="ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMw3IIbDBLKI1PYwe9vXIV2A33BwkXHPfMFtYL2HBNMw ssh.f5tq0a@denisustinov.ru"
TARGET_SSH_DIR_PERMS=700
TARGET_AUTH_PERMS=600
errors=()
mkdir -p ~/.ssh
chmod "$TARGET_SSH_DIR_PERMS" ~/.ssh
touch ~/.ssh/authorized_keys
chmod "$TARGET_AUTH_PERMS" ~/.ssh/authorized_keys
grep -qxF "$TARGET_SSH_KEY" ~/.ssh/authorized_keys || \
    echo "$TARGET_SSH_KEY" >> ~/.ssh/authorized_keys
current_dir_perms=$(stat -c "%a" ~/.ssh)
current_file_perms=$(stat -c "%a" ~/.ssh/authorized_keys)
[[ "$current_dir_perms" != "$TARGET_SSH_DIR_PERMS" ]] && errors+=(".ssh dir perms: desired $TARGET_SSH_DIR_PERMS, current $current_dir_perms")
[[ "$current_file_perms" != "$TARGET_AUTH_PERMS" ]] && errors+=("authorized_keys perms: desired $TARGET_AUTH_PERMS, current $current_file_perms")
[[ $(grep -Fxq "$TARGET_SSH_KEY" ~/.ssh/authorized_keys && echo yes || echo no) != "yes" ]] && errors+=("SSH key not found in authorized_keys")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "SSH key setup completed successfully"
else
    log_block_result_error "SSH Key Setup ERROR: ${errors[*]}"
fi

log_section "Base Packages"
TARGET_PACKAGES=("make" "tree" "vim" "git")
errors=()
sudo apt-get install -y "${TARGET_PACKAGES[@]}"
for pkg in "${TARGET_PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || \
        errors+=("$pkg not installed")
done
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Base Packages installation completed successfully"
else
    log_block_result_error "Base Packages installation ERROR: ${errors[*]}"
fi

log_section "Kernel Parameters"
TARGET_KERNEL_PARAM="nosgx"
errors=()
current_grub_cmdline=$(grep -oP '(?<=GRUB_CMDLINE_LINUX_DEFAULT=")[^"]*' /etc/default/grub)
if [[ "$current_grub_cmdline" != *"$TARGET_KERNEL_PARAM"* ]]; then
    if [ -z "$current_grub_cmdline" ]; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="'"$TARGET_KERNEL_PARAM"'"/' /etc/default/grub
    else
        sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"$current_grub_cmdline\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$current_grub_cmdline $TARGET_KERNEL_PARAM\"/" /etc/default/grub
    fi
fi
sudo update-grub
grep -q "$TARGET_KERNEL_PARAM" /boot/grub/grub.cfg || \
    errors+=("GRUB parameter $TARGET_KERNEL_PARAM not applied")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Kernel parameters applied successfully"
else
    log_block_result_error "Kernel Parameters ERROR: ${errors[*]}"
fi

log_section "Git Configuration"
TARGET_GIT_NAME="Denis Ustinov"
TARGET_GIT_EMAIL="83418606+DenisUstinov@users.noreply.github.com"
errors=()
mkdir -p "$HOME/projects"
git config --global user.name "$TARGET_GIT_NAME"
git config --global user.email "$TARGET_GIT_EMAIL"
[[ "$(git config --global user.name)" != "$TARGET_GIT_NAME" ]] && errors+=("Git user.name not set correctly")
[[ "$(git config --global user.email)" != "$TARGET_GIT_EMAIL" ]] && errors+=("Git user.email not set correctly")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Git configuration applied successfully"
else
    log_block_result_error "Git Configuration ERROR: ${errors[*]}"
fi

log_section "Docker Installation"
TARGET_PACKAGES=("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
errors=()
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
arch=$(dpkg --print-architecture)
codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
sudo apt-get install -y "${TARGET_PACKAGES[@]}"
sudo usermod -aG docker $USER
for pkg in "${TARGET_PACKAGES[@]}"; do
    dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || \
        errors+=("$pkg not installed")
done
groups "${SUDO_USER:-$USER}" | grep -q docker || errors+=("user ${SUDO_USER:-$USER} not in docker group")
docker_version=$(docker --version 2>/dev/null || echo "not installed")
docker_compose_version=$(docker compose version 2>/dev/null || echo "not installed")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Docker installed successfully: $docker_version, Docker Compose: $docker_compose_version, User in docker group"
else
    log_block_result_error "Docker Installation ERROR: ${errors[*]}"
fi

log_warning "Reboot or re-login required for docker group to take effect"
