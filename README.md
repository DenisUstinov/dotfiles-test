# dotfiles
Personal CLI tools, shell configs, and automation scripts for a personal developer laptop.

### /bin
Executable scripts for automating tasks.

- [**/bootstrap-local-misc-server.sh**](https://github.com/DenisUstinov/dotfiles/blob/main/bin/bin/bootstrap-local-misc-server.sh) — intended for a one-time run immediately after a fresh reinstall of Ubuntu Server on a personal laptop. The script installs required software and prepares the working environment. It is used on a personal, password-protected device with disk encryption enabled, providing sufficient security.

**Download and run the bootstrap script**
```bash
curl -sL https://raw.githubusercontent.com/DenisUstinov/dotfiles-test/refs/heads/main/bin/bootstrap-local-misc-server.sh -o script.sh
chmod +x script.sh
./script.sh
```

**Copy your public SSH key to the clipboard for GitHub or authorized_keys**
```bash
pbcopy < ~/.ssh/keys/local_misc_server_1_ed25519.pub
```

**Prepare GitHub CLI personal access token**
```bash
# Copy it from your secure storage before running the script
```

**After reboot, delete the script file**
```bash
rm script.sh
```

**Reboot system for docker group changes to take effect**
```bash
sudo reboot
```

**Show your public SSH key and copy it to GitHub**
```bash
cat ~/.ssh/id_ed25519.pub
