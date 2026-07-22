# Customizing a Renix fork

Start with the `demo` host. It intentionally avoids hardware configuration and is intended for evaluation inside the Docker lab.

## 1. Choose your identity

The shared flake currently uses `doug` as its example username. Change `username` in `renix/flake.nix`, then search for remaining example paths:

```sh
rg 'doug|/home/doug|/Users/doug' renix dotfiles
```

Keep Linux home directories under `/home/<username>` and macOS home directories under `/Users/<username>`.

## 2. Copy the demo host

```sh
cp -R renix/hosts/x86_64-linux/demo renix/hosts/x86_64-linux/my-laptop
```

Change `networking.hostName`, then expose the host in `renix/flake.nix`:

```nix
nixosConfigurations.my-laptop =
  mkHost "x86_64-linux" "my-laptop" "x86_64-linux";
```

Verify it before adding hardware-specific settings:

```sh
renix-lab verify my-laptop
```

Supported host groups are based on Nix system names, such as `x86_64-linux`, `aarch64-linux`, and `aarch64-darwin`.

## 3. Edit shared configuration

Use the ownership-oriented module layout:

- Shared user tools and preferences belong in `renix/modules/home/`.
- Shared NixOS behavior belongs in `renix/modules/system/`.
- Shared macOS behavior belongs in `renix/modules/darwin/`.
- Machine-specific behavior belongs under `renix/hosts/<system>/<host>/`.
- User-maintained application configuration belongs under `dotfiles/`.

Run `renix-lab verify HOST` inside the container after each meaningful change.

## 4. Replace public fixtures

The public flake uses local fixtures for a certificate input and the example Graylog package. They exist only to keep forks independently evaluable.

Choose one of these approaches:

1. Replace the fixture URLs in `renix/flake.nix` with your own public sources.
2. Manage private inputs with authenticated Git and encrypted credentials.
3. Remove the inputs and the modules that consume them.

Never commit private keys, access tokens, passwords, or production certificates.

## 5. Add real hardware only after evaluation

The Docker lab validates configuration evaluation, not bootability or hardware compatibility. For an actual NixOS installation, generate that machine's `hardware-configuration.nix` on the target and import it from the host configuration.

For macOS, create a host under `renix/hosts/aarch64-darwin/` and expose it through `darwinConfigurations`.

## 6. Activate outside Docker

Only activate after reviewing the configuration for your machine.

On a configured NixOS host:

```sh
sudo nixos-rebuild switch --flake ./renix#my-laptop
```

On a configured macOS host:

```sh
darwin-rebuild switch --flake ./renix#my-mac
```

After installation, the normal unified workflow is:

```sh
renix
```
