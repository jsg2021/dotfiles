# Install test harness

Runs `./install` and the installer scripts against a throwaway Linux container,
so a broken install is caught before it wrecks a real machine.

Nothing here touches your machine. The repo is mounted **read-only** at `/src`;
the container copies it to `~/.dotfiles` inside itself and works on that.

## Running

```sh
./tests/run                              # unit tests only, fast, no Docker
./tests/run --container                  # unit tests + all scenarios (Debian)
./tests/run --container --base fedora:41 # same, on the dnf path
./tests/run --container --platform linux/amd64   # emulate the other CPU arch
./tests/run --container fresh dirty-repo # just those scenarios
./tests/run --shell                      # interactive poke-around in the sandbox
./tests/run --container --real fresh     # no stubs: real network, real packages
```

CI runs all of this — see [.github/workflows/test.yml](../.github/workflows/test.yml).

## How the sandbox works

The container has real `git`, `zsh`, `jq`, `stow` and nothing else that matters.
Everything that would download a file, install a package, or need root is
shadowed by a stub in [stubs/bin](stubs/bin) that just records the call to
`/tmp/stub.log`. Tests then assert on that log. `--network none` is passed, so a
missing stub shows up as a failure rather than a slow silent download.

Only the stubs matching the container's real package manager are kept, so a
Debian box cannot accidentally take the `dnf` branch.

The fake `curl` serves each GitHub repo its own release listing, carrying every
architecture a real release carries. An installer whose filter does not pin the
architecture therefore matches more than one asset, and `github_asset_url`
refuses rather than guessing. The `arch-alt` scenario re-runs the whole install
with `uname -m` faked to the other architecture, which is far cheaper than
emulating a second platform (`--platform` does that if you want the real thing).

`--real` drops the stubs and the network block. Slow, and only worth it when you
suspect a stub is lying.

## Layout

| Path | What it is |
| --- | --- |
| [run](run) | The entry point. Everything below is driven from here. |
| [lib/harness.sh](lib/harness.sh) | `assert_*` helpers and the PASS/FAIL counter. |
| [unit/](unit/) | Host-side checks: script syntax, JSON validity, exec bits, `helpers` functions. |
| [stubs/bin/](stubs/bin/) | Fake `curl`, `sudo`, `apt-get`, `dnf`, `chsh`, … |
| [container/Dockerfile](container/Dockerfile) | The sandbox image. `--build-arg BASE=` picks the distro. |
| [container/entrypoint.sh](container/entrypoint.sh) | Resets `$HOME`, copies the repo, sets up stubs, runs one scenario. |
| [container/scenarios/](container/scenarios/) | One file per situation being tested. |

## Checking config links

The core dotfiles (`.zshrc`, `.gitconfig`, and friends) are asserted by name, so
a silent change to the stow rules cannot pass. Everything else is derived at run
time: the harness asks `stow --simulate` what it would link, then checks each
planned file really resolves from `$HOME` back into the repo. Adding a config to
the repo needs no test change. Anything stow skipped must be covered by a line
in `.stow-local-ignore`, so a config that quietly stops being linked is caught.

## Scenarios

| Name | What it proves |
| --- | --- |
| `fresh` | Empty machine: every config gets linked, every installer gets called. |
| `idempotent` | Running install twice is safe and changes nothing. |
| `dirty-repo` | Uncommitted changes abort the install before anything is touched. |
| `existing-configs` | Hand-written dotfiles are adopted, then stashed, not lost. |
| `codespaces` | `CODESPACES=true` links configs but skips OS and app installs. |
| `piped` | The README's `curl … \| bash` path works from any directory. |
| `arch-alt` | The same install while pretending to be the other CPU architecture. |

## Adding a scenario

Drop `tests/container/scenarios/<name>.sh` in place and add `<name>` to
`ALL_SCENARIOS` in [run](run). The file is sourced with `$DOT`, `$HOME`,
`$STUB_LOG` and every `assert_*` helper already set up. Use `run_install` from
`_common.sh` to invoke the installer.

## House rules the unit tests enforce

- **Installer scripts are executable and called directly** — `"$DIR/tools"`, not
  `sh "$DIR/tools"`. They declare `#!/bin/bash`; naming an interpreter overrides
  that shebang and silently drops every bashism (this is what broke Debian).
- **`has_binary`, never `command -v`** — one lookup path, so the rule that an
  installer script must not shadow the binary it installs applies everywhere.
- **`binary_path`, never `which`** — `which` is not installed on Fedora 41+ or
  on slim images.
- **Release assets are chosen with `arch_for` + `github_asset_url`** — never a
  hardcoded arch, and never a filter loose enough to match two assets.
