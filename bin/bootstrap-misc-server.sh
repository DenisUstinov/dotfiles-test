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
sudo timedatectl set-timezone "$TARGET_TIMEZONE"
sudo apt-get install -y locales
sudo locale-gen "$TARGET_LOCALE"
sudo update-locale LANG="$TARGET_LOCALE"
current_timezone=$(timedatectl show --property=Timezone --value)
current_locale=$(locale | grep LANG= | cut -d= -f2)
errors=()
[[ "$current_timezone" != "$TARGET_TIMEZONE" ]] && errors+=("timezone: desired $TARGET_TIMEZONE, current $current_timezone")
[[ "$current_locale" != "$TARGET_LOCALE" ]] && errors+=("locale: desired $TARGET_LOCALE, current $current_locale")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Locales & Timezone applied successfully"
else
    log_block_result_error "Locales & Timezone ERROR: ${errors[*]}"
fi









log_section "SSH Key Setup"
mkdir -p ~/.ssh
log_step "Directory ~/.ssh created (if not existed)"
chmod 700 ~/.ssh
log_step "Permissions 700 set on ~/.ssh"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMw3IIbDBLKI1PYwe9vXIV2A33BwkXHPfMFtYL2HBNMw ssh.f5tq0a@denisustinov.ru" >> ~/.ssh/authorized_keys
log_step "SSH public key appended to ~/.ssh/authorized_keys"
chmod 600 ~/.ssh/authorized_keys
log_step "Permissions 600 set on ~/.ssh/authorized_keys"
ssh_dir_perms=$(stat -c "%a" ~/.ssh)
ssh_file_perms=$(stat -c "%a" ~/.ssh/authorized_keys)
log_step "Permissions .ssh: $ssh_dir_perms, authorized_keys: $ssh_file_perms"
log_block_result_ok "SSH key setup completed successfully"

log_section "Base Packages"
sudo apt-get install -y make tree vim git
pkg_versions=$(dpkg -l make tree vim git | grep -E "make|tree|vim|git" | awk '{print $2, $3}')  # заменено на вывод всех пакетов сразу
log_step "Installed package versions: $pkg_versions"
log_block_result_ok "Base Packages installation completed successfully"

log_section "Kernel Parameters"
if grep -q 'GRUB_CMDLINE_LINUX_DEFAULT=.*nosgx' /etc/default/grub; then
    log_step "'nosgx' already present in GRUB_CMDLINE_LINUX_DEFAULT"
else
    current=$(grep -oP '(?<=GRUB_CMDLINE_LINUX_DEFAULT=")[^"]*' /etc/default/grub)
    if [ -z "$current" ]; then
        sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""/GRUB_CMDLINE_LINUX_DEFAULT="nosgx"/' /etc/default/grub
    else
        sudo sed -i "s/GRUB_CMDLINE_LINUX_DEFAULT=\"$current\"/GRUB_CMDLINE_LINUX_DEFAULT=\"$current nosgx\"/" /etc/default/grub
    fi
    log_step "Added 'nosgx' to GRUB_CMDLINE_LINUX_DEFAULT"
fi
sudo update-grub
log_step "Grub configuration updated"
grub_cmdline=$(grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub | cut -d'"' -f2)
grub_nosgx_check=$(grep 'linux' /boot/grub/grub.cfg | head -1 | grep -q 'nosgx' && echo "applied" || echo "not applied")
log_step "GRUB nosgx parameter applied in grub.cfg: $grub_nosgx_check"
log_block_result_ok "Kernel parameters applied: GRUB_CMDLINE_LINUX_DEFAULT=$grub_cmdline"

log_section "Git Configuration"
mkdir -p "$HOME/projects"
log_step "Project directory created: $HOME/projects"
git config --global user.name "Denis Ustinov"
log_step "Git user.name set: $(git config --global user.name)"
git config --global user.email "83418606+DenisUstinov@users.noreply.github.com"
log_step "Git user.email set: $(git config --global user.email)"
log_block_result_ok "Git configuration completed successfully"

log_section "Docker Installation"
sudo install -m 0755 -d /etc/apt/keyrings
log_step "Directory /etc/apt/keyrings created"
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
log_step "Docker GPG key downloaded"
sudo chmod a+r /etc/apt/keyrings/docker.asc
log_step "Permissions set on Docker GPG key"
arch=$(dpkg --print-architecture)
codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list
log_step "Docker repository added"
sudo apt-get update
log_step "Package lists updated"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
log_step "Docker packages installed"
sudo usermod -aG docker $USER
log_step "User added to docker group"
docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
in_docker_group=$(groups $USER | grep -q docker && echo "yes" || echo "no")
docker_status=$(systemctl is-active docker)
log_step "Docker service status: $docker_status"
log_block_result_ok "Docker installed: $docker_version, User in docker group: $in_docker_group"

log_warning "Reboot or re-login required for docker group to take effect"
