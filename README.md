# dotfiles

This sets up my profile & dev environment that I use across all my machines.

## Setup

This script will clone the dotfiles repo to `~/.dotfiles` and link all the config files plus install all the packages I use.

```sh
curl -fsSL https://raw.githubusercontent.com/jsg2021/dotfiles/main/install | sh
```

## Signing commits

My commit signing is handled by 1Password. If you use a different signing method, you should update the `gpg` blocks in the gitconfig. However, if you also use 1Password, you can use my setup, just set the `signingkey` property in `configs/gitconfig` to your public key.
