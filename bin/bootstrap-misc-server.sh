#!/bin/bash
set -euo pipefail

log_section() {
    printf "\n%b\n" "$(tput setaf 4)$(tput bold)=> $1 $(tput sgr0)"
}

log_result() {
    printf "%b\n" "$(tput setaf 2)✔ $1$(tput sgr0)"
}

log_warning() {
    printf "%b\n" "$(tput setaf 3)⚠ $1$(tput sgr0)"
}

log_section "System Update"
sudo apt-get update -qq
sudo apt-get -y upgrade -qq
log_result "Kernel: $(uname -r)"

log_section "Cleanup"
sudo apt-get -y autoremove
sudo apt-get -y autoclean
sudo apt-get clean
log_result "Free space: $(df -h / --output=avail | tail -1 | tr -d ' ')"

log_section "Locales & Timezone"
sudo timedatectl set-timezone UTC
sudo apt-get install -y locales
sudo locale-gen C.UTF-8
sudo update-locale LANG=C.UTF-8
log_result "Timezone: $(timedatectl show --property=Timezone --value)"
log_result "Locale: $(locale | grep LANG= | cut -d= -f2)"

log_section "SSH Key Setup"
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMw3IIbDBLKI1PYwe9vXIV2A33BwkXHPfMFtYL2HBNMw ssh.f5tq0a@denisustinov.ru" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
log_result "SSHK installed in ~/.ssh/authorized_keys"

log_section "Base Packages"
sudo apt-get install -y make tree vim git
log_result "make installed: $(dpkg -s make | grep Version | awk '{print $2}')"
log_result "tree installed: $(dpkg -s tree | grep Version | awk '{print $2}')"
log_result "vim installed: $(dpkg -s vim | grep Version | awk '{print $2}')"
log_result "git installed: $(dpkg -s git | grep Version | awk '{print $2}')"

log_section "Kernel Parameters"
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=".*"/GRUB_CMDLINE_LINUX_DEFAULT="nosgx"/' /etc/default/grub
sudo update-grub
log_result "GRUB_CMDLINE_LINUX_DEFAULT: $(grep GRUB_CMDLINE_LINUX_DEFAULT /etc/default/grub | cut -d'"' -f2)"

log_section "Git Configuration"
mkdir -p "$HOME/projects"
git config --global user.name "Denis Ustinov"
git config --global user.email "83418606+DenisUstinov@users.noreply.github.com"
log_result "Git user.name: $(git config --global user.name)"
log_result "Git user.email: $(git config --global user.email)"
log_result "Project directory created: $HOME/projects"

log_section "Docker Installation"
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | sudo tee /etc/apt/sources.list.d/docker.list
sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker $USER
log_result "Docker installed: $(docker --version | awk '{print $3}' | tr -d ',')"
log_result "User in docker group: $(groups $USER | grep -q docker && echo "yes" || echo "no")"
log_warning "Reboot or re-login required for docker group to take effect"
