#!/bin/bash
set -euo pipefail

log_section() {
    printf "\n%b\n" "$(tput setaf 4)$(tput bold)==> $1$(tput sgr0)"
}

log_step() {
    printf "    %b\n" "$(tput setaf 2)✔ $1$(tput sgr0)"
}

log_block_result() {
    printf "%b\n" "$(tput setaf 4)✓ $1$(tput sgr0)"
}

log_warning() {
    printf "%b\n" "$(tput setaf 3)⚠ $1$(tput sgr0)"
}

sudo -v

log_section "System Update"
sudo apt-get update
log_step "apt-get update completed"
sudo apt-get -y upgrade
log_step "apt-get upgrade completed"
log_step "Current kernel: $(uname -r)"
log_block_result "System Update completed successfully"

log_section "Cleanup"
sudo apt-get -y autoremove
log_step "apt-get autoremove completed"
sudo apt-get -y autoclean
log_step "apt-get autoclean completed"
sudo apt-get clean
log_step "apt-get clean completed"
free_space=$(df -h / --output=avail | tail -1 | tr -d ' ')
log_block_result "Cleanup completed, free space: $free_space"

log_section "Locales & Timezone"
sudo timedatectl set-timezone UTC
log_step "Timezone set to UTC"
sudo apt-get install -y locales
log_step "Locales package installed"
sudo locale-gen C.UTF-8
log_step "Locale C.UTF-8 generated"
sudo update-locale LANG=C.UTF-8
log_step "System locale updated to C.UTF-8"
current_timezone=$(timedatectl show --property=Timezone --value)
current_locale=$(locale | grep LANG= | cut -d= -f2)
log_block_result "Locales & Timezone configured: Timezone=$current_timezone, Locale=$current_locale"

log_section "SSH Key Setup"
mkdir -p ~/.ssh
log_step "Directory ~/.ssh created (if not existed)"
chmod 700 ~/.ssh
log_step "Permissions 700 set on ~/.ssh"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMw3IIbDBLKI1PYwe9vXIV2A33BwkXHPfMFtYL2HBNMw ssh.f5tq0a@denisustinov.ru" >> ~/.ssh/authorized_keys
log_step "SSH public key appended to ~/.ssh/authorized_keys"
chmod 600 ~/.ssh/authorized_keys
log_step "Permissions 600 set on ~/.ssh/authorized_keys"
log_block_result "SSH key setup completed successfully"

log_section "Base Packages"
sudo apt-get install -y make
log_step "make installed: $(dpkg -s make | grep Version | awk '{print $2}')"
sudo apt-get install -y tree
log_step "tree installed: $(dpkg -s tree | grep Version | awk '{print $2}')"
sudo apt-get install -y vim
log_step "vim installed: $(dpkg -s vim | grep Version | awk '{print $2}')"
sudo apt-get install -y git
log_step "git installed: $(dpkg -s git | grep Version | awk '{print $2}')"
log_block_result "Base Packages installation completed successfully"

log_section "Kernel Parameters"
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="\(.*\)"/GRUB_CMDLINE_LINUX_DEFAULT="\1 nosgx"/' /etc/default/grub
log_step "Added 'nosgx' to GRUB_CMDLINE_LINUX_DEFAULT"
sudo update-grub
log_step "Grub configuration updated"
grub_cmdline=$(grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub | cut -d'"' -f2)
log_block_result "Kernel parameters applied: GRUB_CMDLINE_LINUX_DEFAULT=$grub_cmdline"

log_section "Git Configuration"
mkdir -p "$HOME/projects"
log_step "Project directory created: $HOME/projects"
git config --global user.name "Denis Ustinov"
log_step "Git user.name set: $(git config --global user.name)"
git config --global user.email "83418606+DenisUstinov@users.noreply.github.com"
log_step "Git user.email set: $(git config --global user.email)"
log_block_result "Git configuration completed successfully"

log_section "Docker Installation"
sudo install -m 0755 -d /etc/apt/keyrings
log_step "Directory /etc/apt/keyrings created"
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
log_step "Docker GPG key downloaded"
sudo chmod a+r /etc/apt/keyrings/docker.asc
log_step "Permissions set on Docker GPG key"
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list
log_step "Docker repository added"
sudo apt-get update
log_step "Package lists updated"
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
log_step "Docker packages installed"
sudo usermod -aG docker $USER
log_step "User added to docker group"
docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
in_docker_group=$(groups $USER | grep -q docker && echo "yes" || echo "no")
log_block_result "Docker installed: $docker_version, User in docker group: $in_docker_group"

log_warning "Reboot or re-login required for docker group to take effect"
