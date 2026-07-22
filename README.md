# Renix

Renix is a command layer for managing reproducible Linux and macOS systems with Nix.

You can try Renix in a disposable Docker container. You do not need to install Nix or clone this repository.

## Run with Docker

### 1. Install Docker

Install and start [Docker](https://docs.docker.com/get-docker/).

### 2. Start the container

```sh
docker run --rm -it ghcr.io/dmasiero/renix-public-starter:latest shell
```

Docker downloads the image and opens a shell inside the container.

### 3. Run Renix

At the container prompt, run:

```sh
renix full
```

This evaluates the example configuration, builds it with Nix, and opens a Fish shell with the configured command-line tools.

You can then try commands such as:

```fish
renix --help
pi --help
nvim
```

### 4. Exit

Run `exit` to leave Fish and stop the container.

The container is disposable. Any changes made inside it are removed when it stops. Run the Docker command again whenever you want a fresh environment.

## Renix commands

```text
renix             Run the rebuild workflow
renix full        Build and activate the complete example environment
renix update      Check for package updates, then rebuild
renix upgrade     Preview flake input and package changes
renix overview    Show generations, store paths, and disk usage
renix rollback    Demonstrate a generation rollback
```

## Customize Renix

See [docs/CUSTOMIZING.md](docs/CUSTOMIZING.md) to create and customize your own configuration. Review all example identity, networking, and hardware settings before using a configuration on a real machine.

## License

MIT. See [LICENSE](LICENSE).
