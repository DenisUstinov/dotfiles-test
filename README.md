# dotfiles
Personal CLI tools, shell configs, and development environment setup scripts.

### bin
Executable scripts for automating tasks.

- [**/bootstrap-misc-server.sh**](https://github.com/DenisUstinov/dotfiles/blob/main/bin/bootstrap-misc-server.sh) — Local misc server
```bash
curl -sL "" | bash
ssh ubuntu@192.168.0.100 \
  "TARGET_SSH_KEY='$(cat ~/.ssh/keys/local_misc_servir_1.pub)' curl -sL https://raw.githubusercontent.com/DenisUstinov/dotfiles-test/refs/heads/main/bin/bootstrap-misc-server.sh | bash"
```
