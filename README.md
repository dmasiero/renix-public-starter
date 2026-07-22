# Renix Container Lab

Renix is a unified command layer for reproducible Linux and macOS systems managed with Nix. The entire demonstration runs inside a disposable Nix-powered Linux container, including editing, tests, host selection, package discovery, and real NixOS configuration evaluation.

You do not need to install Nix or clone the repository onto your computer. Docker is the only local requirement.

## Start the demo

```sh
docker run --rm -it \
  -v renix-workspace:/workspace \
  -v renix-nix:/nix \
  ghcr.io/dmasiero/renix-public-starter:latest
```

The image initializes a writable project under `/workspace/renix-public-starter` and runs the guided tour. The Docker-managed volume preserves edits between containers.

## Enter the container workspace

```sh
docker run --rm -it \
  -v renix-workspace:/workspace \
  -v renix-nix:/nix \
  ghcr.io/dmasiero/renix-public-starter:latest shell
```

Everything after this point runs inside the container. Start with the complete workflow:

```sh
renix full
```

`renix full` evaluates the demo host, performs a real Nix build, and activates a focused CLI environment. It includes Fish, fd, fping, fzf, Git, htop, jq, lazygit, mtr, ouch, pwgen, ripgrep, tea, archive and DNS tools, wget, whois, yazi, Herdr, Pi 0.81.1, and Doug's configured Neovim. Heavy desktop, media, cloud, hardware, and chat packages are intentionally excluded. These commands are unavailable before the first activation. After it completes, the container automatically moves into Fish:

```fish
fd --version
fping --version
yazi --version
herdr --help
pi --help
nvim
```

Renix remains available directly from Fish. Running `exit` leaves Fish and stops the disposable container:

```fish
renix --help
renix update
renix upgrade
```

Use `RENIX_HOST` to select another configuration:

```sh
RENIX_HOST=coregate renix
```

Container-specific editing and evaluation helpers remain separate:

```sh
renix-lab hosts
renix-lab edit
renix-lab test
renix-lab verify demo
```

`edit` opens the demo host in `nano`. You can also edit any path explicitly:

```sh
renix-lab edit renix/modules/home/base.nix
```

## Test a GitHub fork without a local clone

Create a GitHub fork, then start the image with an empty Docker volume:

```sh
docker volume create my-renix-fork

docker run --rm -it \
  -e RENIX_REPO=https://github.com/dmasiero/renix-public-starter.git \
  -v my-renix-fork:/workspace \
  -v my-renix-store:/nix \
  ghcr.io/dmasiero/renix-public-starter:latest shell
```

The container clones the fork into its own persistent workspace. Alternatively, replace an existing container workspace from inside it:

```sh
renix-lab clone https://github.com/dmasiero/renix-public-starter.git
```

The repository checkout and Nix store remain isolated in Docker-managed volumes.

## Container interface

Renix commands run directly:

```text
renix                          Run the safe rebuild workflow
renix update                   Discover custom package updates, then rebuild
renix upgrade                  Preview flake input and package changes
renix overview                 Show generations, store paths, and disk usage
renix rollback                 Demonstrate a generation rollback
```

Container-only helpers use the separate lab command:

```text
renix-lab tour                 Run the guided demonstration
renix-lab hosts                List available configurations
renix-lab test                 Run Python and shell tests
renix-lab verify [HOST]        Evaluate a complete host with real Nix
renix-lab edit [PATH]          Edit a workspace file with nano
renix-lab clone URL            Replace the workspace with a compatible fork
renix-lab reset                Restore the image's original workspace
```

## What is tested

The lab runs the real project source and verifies:

- Python package-discovery behavior
- Shell update dispatch
- Host and architecture selection
- Renix command orchestration
- Complete NixOS or nix-darwin evaluation
- Changes made in the persistent container workspace

A Docker container cannot replace its host operating system. The final `sudo`, `nixos-rebuild`, and `darwin-rebuild` calls therefore use explicit safety adapters. The demo NixOS adapter performs a real evaluation and build, then activates the resulting user tools inside the container without modifying the Docker host.

## Repository layout

- `renix/flake.nix`: flake inputs and host outputs
- `renix/hosts/`: Linux and macOS host configurations
- `renix/modules/`: NixOS, nix-darwin, and Home Manager modules
- `renix/pkgs/renix/`: command implementation and tests
- `dotfiles/`: sanitized user-managed configuration examples
- Focused CLI environment, Fish, Herdr, Pi, and configured Neovim: built and activated by `renix full`
- `demo/`: container interface and safety adapters
- `Dockerfile`: self-contained lab image

See [docs/CUSTOMIZING.md](docs/CUSTOMIZING.md) for the customization path.

## Build the image from source

Repository maintainers can build the same entry image with:

```sh
docker build -t renix-public-starter .
docker run --rm -it \
  -v renix-workspace:/workspace \
  -v renix-nix:/nix \
  renix-public-starter
```

End users should pull the published GHCR image instead.

## Sanitized public starter

Credentials, SSH private keys, private service configuration, communication history, and AI session history are excluded. Public fixtures replace private flake inputs. TickTick, Helium, and Keymapp are also omitted to keep the public demo focused.

Before activating a fork on real hardware, review every module, replace the example identity and networking settings, and use an encrypted secret manager.

## License

MIT. See [LICENSE](LICENSE).
