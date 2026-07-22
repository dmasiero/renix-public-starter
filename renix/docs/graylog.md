# Graylog CLI lifecycle

`graylog` is packaged in this flake as a custom build sourced from the production Graylog repository on Gitea.

## Source of truth

The source repository is:

```text
git@gitea.masiero.internal:masiero/graylog.git
```

The packaged file is:

```text
cli/graylog
```

Do not package this by symlinking to a local checkout and do not copy an ad-hoc local script into `~/dotfiles`. The Nix package must obtain the script from the Gitea Graylog repository.

## Release model

Renix consumes tagged releases from the Graylog repo through the `graylogCli` flake input in `flake.nix`.

Current input:

```nix
graylogCli = {
  url = "git+ssh://git@gitea.masiero.internal:2222/masiero/graylog.git?ref=refs/tags/v0.2.0";
  flake = false;
};
```

The initial production CLI release is:

```text
v0.2.0
```

## Update workflow

1. Make and test changes in `/home/doug/dev/graylog`.
2. Commit and push to `masiero/graylog`.
3. Create a new SemVer-style tag in the Graylog repo:

   ```sh
   git tag -a v0.2.1 -m 'graylog release v0.2.1'
   git push origin v0.2.1
   ```

4. Update `graylogCli.url` in `/home/doug/renix/flake.nix` to the new tag.
5. Update the lock file:

   ```sh
   nix flake update graylogCli
   ```

6. Build or evaluate before committing:

   ```sh
   nix build .#nixosConfigurations.$(hostname -s).config.home-manager.users.doug.home.path
   ```

7. Commit and push the renix changes.
8. Apply later with `renix` when ready.

## Runtime settings

The command expects local runtime settings in:

```text
~/dotfiles/graylog/.env
```

That file is intentionally not built into Nix. It contains local API settings such as:

```text
GRAYLOG_URL=https://graylog.masiero.internal:9000
GRAYLOG_CA_CERT=/home/doug/dev/masiero/fissionable/infrastructure/certs/ca.crt
GRAYLOG_SEARCH_TOKEN=...
```
