# dotfiles
Personal CLI tools, shell configs, and development environment setup scripts.

### bin
Executable scripts for automating tasks.

- [**/bootstrap-local-misc-server.sh**](https://github.com/DenisUstinov/dotfiles/blob/main/bin/bin/bootstrap-local-misc-server.sh) — bootstrap local misc server
```bash
curl -sL https://raw.githubusercontent.com/DenisUstinov/dotfiles-test/refs/heads/main/bin/bootstrap-local-misc-server.sh -o script.sh
chmod +x script.sh
./script.sh
pbcopy < ~/.ssh/keys/local_misc_server_1_ed25519.pub
```
