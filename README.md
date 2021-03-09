# dotfiles
my profile &amp; utility scripts

run install in terminal to link in configs.

## Setup:
```sh
git clone git@github.com:jsg2021/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
git submodule update --init --recursive
./install
```

## Signing commits

```sh
sudo port install gnupg2
```

check current keys:

```sh
gpg2 --list-secret-keys --keyid-format LONG
```

Generate a new pgp key:

```sh
gpg2 --gen-key
```

Setup git:

```sh
git config --global gpg.program gpg2
git config --global user.signingkey your_key_id
git config --global commit.gpgsign true
```
