#!/bin/bash
set -euo pipefail

log_section() {
    printf "\n%b\n" "$(tput setaf 4)$(tput bold)==> $1$(tput sgr0)"
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

log_info() {
    printf "%b\n" "$(tput setaf 8)    $1$(tput sgr0)"
}

cleanup() {
    unset GH_TOKEN 2>/dev/null || true
    unset TARGET_SSH_KEY 2>/dev/null || true
}
trap cleanup EXIT

sudo -v

# System Update:
log_section "System Update"
log_info "update apt repositories"
sudo apt-get update
log_info "upgrade all installed packages"
sudo apt-get -y upgrade
log_block_result_ok "System Update completed successfully"

# Cleanup:
log_section "Cleanup"
log_info "remove unused packages"
sudo apt-get -y autoremove
log_info "clean package cache"
sudo apt-get -y autoclean
sudo apt-get clean
log_block_result_ok "Cleanup completed successfully"

# Locales & Timezone:
log_section "Locales & Timezone"
log_info "set system timezone"
TARGET_TIMEZONE="UTC"
TARGET_LOCALE="C.UTF-8"
errors=()
sudo timedatectl set-timezone "$TARGET_TIMEZONE"
log_info "generate and set system locale"
sudo apt-get install -y locales
sudo locale-gen "$TARGET_LOCALE"
sudo update-locale LANG="$TARGET_LOCALE"
current_timezone=$(timedatectl show --property=Timezone --value)
current_locale=$(locale | grep LANG= | cut -d= -f2)
[[ "$current_timezone" != "$TARGET_TIMEZONE" ]] && errors+=("timezone: desired $TARGET_TIMEZONE, current $current_timezone")
[[ "$current_locale" != "$TARGET_LOCALE" ]] && errors+=("locale: desired $TARGET_LOCALE, current $current_locale")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Locales & Timezone completed successfully"
else
    log_block_result_error "Locales & Timezone ERROR: ${errors[*]}"
fi

# SSH Key Setup:
log_section "SSH Key Setup"
log_info "create .ssh directory and set permissions"
TARGET_SSH_DIR_PERMS=700
TARGET_AUTH_PERMS=600
TARGET_SSH_KEY=""
while [[ -z "$TARGET_SSH_KEY" ]]; do
    read -rp "Enter SSH public key: " TARGET_SSH_KEY
done
errors=()
mkdir -p ~/.ssh
chmod "$TARGET_SSH_DIR_PERMS" ~/.ssh
touch ~/.ssh/authorized_keys
chmod "$TARGET_AUTH_PERMS" ~/.ssh/authorized_keys
log_info "add public key to authorized_keys (without duplicates)"
grep -qxF "$TARGET_SSH_KEY" ~/.ssh/authorized_keys || \
    echo "$TARGET_SSH_KEY" >> ~/.ssh/authorized_keys
log_info "verify permissions and key presence"
current_dir_perms=$(stat -c "%a" ~/.ssh)
current_file_perms=$(stat -c "%a" ~/.ssh/authorized_keys)
[[ "$current_dir_perms" != "$TARGET_SSH_DIR_PERMS" ]] && errors+=(".ssh dir perms: desired $TARGET_SSH_DIR_PERMS, current $current_dir_perms")
[[ "$current_file_perms" != "$TARGET_AUTH_PERMS" ]] && errors+=("authorized_keys perms: desired $TARGET_AUTH_PERMS, current $current_file_perms")
[[ $(grep -Fxq "$TARGET_SSH_KEY" ~/.ssh/authorized_keys && echo yes || echo no) != "yes" ]] && errors+=("SSH key not found in authorized_keys")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "SSH Key Setup completed successfully"
else
    log_block_result_error "SSH Key Setup ERROR: ${errors[*]}"
fi

# Base Development Tools:
log_section "Base Development Tools"
log_info "install common development packages"
TARGET_PACKAGES=("make" "tree" "vim" "git")
errors=()
sudo apt-get install -y "${TARGET_PACKAGES[@]}"
log_info "verify installation of each package"
for pkg in "${TARGET_PACKAGES[@]}"; do
    if ! command -v "$pkg" &> /dev/null; then
        errors+=("$pkg not installed")
    fi
done
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Base Development Tools completed successfully"
else
    log_block_result_error "Base Development Tools installation ERROR: ${errors[*]}"
fi

# GitHub CLI Setup:
log_section "GitHub CLI Setup"
log_info "add GitHub CLI repository"
errors=()
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/etc/apt/keyrings/githubcli-archive-keyring.gpg
sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
sudo apt-get update
log_info "install gh package"
sudo apt-get install -y gh
if ! command -v gh &> /dev/null; then
    errors+=("gh CLI not installed")
fi
if [ ${#errors[@]} -eq 0 ]; then
    GH_TOKEN=""
    while [[ -z "$GH_TOKEN" ]]; do
        log_info ""
        log_info "Create GitHub Personal Access Token with these permissions:"
        log_info "  ✓ repo (Full control of private repositories)"
        log_info "  ✓ workflow (Update GitHub Actions workflows)"
        log_info "  ✓ read:user + user:email (Read user profile and email)"
        log_info "  ✓ read:org (Read organization membership and team information)"
        log_info ""
        log_info "How to create token:"
        log_info "1. Go to https://github.com/settings/tokens"
        log_info "2. Click 'Generate new token'"
        log_info "3. Select 'classic token'"
        log_info "4. Check: repo, workflow, read:user, user:email, read:org"
        log_info "5. Copy the token and paste below"
        log_info ""
        read -rsp "Enter GitHub Personal Access Token: " GH_TOKEN
        echo
    done
    log_info "authenticate with GitHub token (full repo access for dev server)"
    echo "$GH_TOKEN" | gh auth login --with-token
    unset GH_TOKEN
    log_info "verify authentication"
    if ! gh auth status &> /dev/null; then
        errors+=("GitHub authentication failed")
    fi
fi
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "GitHub CLI Setup completed successfully"
else
    log_block_result_error "GitHub CLI Setup ERROR: ${errors[*]}"
    exit 1
fi

# Git Configuration:
log_section "Git Configuration"
log_info "create projects directory"
errors=()
mkdir -p "$HOME/projects"
log_info "get git global username and email from GitHub API"
TARGET_GIT_NAME=$(gh api user --jq '.name' 2>/dev/null || echo "")
TARGET_GIT_EMAIL=$(gh api user/emails --jq '.[] | select(.email | contains("noreply")) | .email' 2>/dev/null || echo "")
if [ -z "$TARGET_GIT_NAME" ] || [ "$TARGET_GIT_NAME" == "null" ]; then
    read -rp "Failed to get name from GitHub. Enter your Git name: " TARGET_GIT_NAME
fi
if [ -z "$TARGET_GIT_EMAIL" ] || [ "$TARGET_GIT_EMAIL" == "null" ]; then
    read -rp "Failed to get email from GitHub. Enter your Git email: " TARGET_GIT_EMAIL
fi
log_info "set git global username and email"
git config --global user.name "$TARGET_GIT_NAME"
git config --global user.email "$TARGET_GIT_EMAIL"
log_info "verify configuration"
[[ "$(git config --global user.name)" != "$TARGET_GIT_NAME" ]] && errors+=("Git user.name not set correctly")
[[ "$(git config --global user.email)" != "$TARGET_GIT_EMAIL" ]] && errors+=("Git user.email not set correctly")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Git Configuration completed successfully"
else
    log_block_result_error "Git Configuration ERROR: ${errors[*]}"
fi

# Kernel Parameters:
log_section "Kernel Parameters"
log_info "add 'nosgx' to GRUB_CMDLINE_LINUX_DEFAULT"
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
log_info "update grub configuration"
sudo update-grub
log_info "verify parameter applied"
sudo grep -q "$TARGET_KERNEL_PARAM" /boot/grub/grub.cfg || \
    errors+=("GRUB parameter $TARGET_KERNEL_PARAM not applied")
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Kernel Parameters completed successfully"
else
    log_block_result_error "Kernel Parameters ERROR: ${errors[*]}"
fi

# Docker Installation:
log_section "Docker Installation"
log_info "set up Docker apt repository and keyrings"
TARGET_PACKAGES=("docker-ce" "docker-ce-cli" "containerd.io" "docker-buildx-plugin" "docker-compose-plugin")
errors=()
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc
arch=$(dpkg --print-architecture)
codename=$(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}")
echo "deb [arch=$arch signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $codename stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update
log_info "install Docker packages"
sudo apt-get install -y "${TARGET_PACKAGES[@]}"
log_info "add user to docker group"
sudo usermod -aG docker "$USER"
log_info "verify installation and group membership"
for pkg in "${TARGET_PACKAGES[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed"; then
        errors+=("$pkg not installed")
    fi
done
if ! getent group docker | grep -q "\b${SUDO_USER:-$USER}\b"; then
    errors+=("docker group entry not found for user ${SUDO_USER:-$USER}")
fi
if [ ${#errors[@]} -eq 0 ]; then
    log_block_result_ok "Docker Installation completed successfully"
else
    log_block_result_error "Docker Installation ERROR: ${errors[*]}"
fi

log_warning "Reboot or re-login required for docker group to take effect"
