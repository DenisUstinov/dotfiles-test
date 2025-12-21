# dotfiles
Personal CLI tools, shell configs, and automation scripts for a personal developer laptop.

### bin
Executable scripts for automating tasks.

- [**/bootstrap-local-misc-server.sh**](https://github.com/DenisUstinov/dotfiles/blob/main/bin/bin/bootstrap-local-misc-server.sh) — intended for a one-time run immediately after a fresh reinstall of Ubuntu Server on a personal laptop. The script installs required software and prepares the working environment. It is used on a personal, password-protected device with disk encryption enabled, providing sufficient security.

**Installation and SSH setup:**
```bash
# Download and run the bootstrap script
curl -sL https://raw.githubusercontent.com/DenisUstinov/dotfiles-test/refs/heads/main/bin/bootstrap-local-misc-server.sh -o script.sh
chmod +x script.sh
./script.sh
```

```bash
# Copy your public SSH key to the clipboard for GitHub or authorized_keys
pbcopy < ~/.ssh/keys/local_misc_server_1_ed25519.pub
```

```bash
# Prepare GitHub CLI personal access token
# Copy it from your secure storage before running the script
```
