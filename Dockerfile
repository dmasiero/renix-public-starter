FROM nixos/nix@sha256:377d4887aca98f0dfa12971c1ea6d6a625a435d8b610d4c95a436843da6fbfd1

ENV NIX_CONFIG="experimental-features = nix-command flakes"

RUN nix profile add \
      nixpkgs#python3 \
      nixpkgs#nano \
      nixpkgs#ripgrep \
      nixpkgs#jq \
      nixpkgs#gawk \
      nixpkgs#gnused \
      nixpkgs#perl \
      nixpkgs#util-linux \
    && nix store gc

# Cache the real demo closure in the image without activating it. Copy only
# its Nix inputs first so documentation and adapter edits retain this layer.
COPY renix/ /opt/renix-public-starter/renix/
COPY demo/demo-tools.nix /opt/renix-public-starter/demo/demo-tools.nix
RUN RENIX_FLAKE_DIR=/opt/renix-public-starter/renix \
    nix build \
      --extra-experimental-features 'nix-command flakes' \
      --impure \
      --file /opt/renix-public-starter/demo/demo-tools.nix \
      --out-link /opt/renix-demo-cache

COPY . /opt/renix-public-starter/

RUN chmod +x \
      /opt/renix-public-starter/demo/entrypoint.sh \
      /opt/renix-public-starter/demo/bin/* \
    && mkdir -p /workspace /home/doug/.local/state/nix/profiles \
    && ln -s /opt/renix-public-starter/demo/entrypoint.sh /root/.nix-profile/bin/renix-lab \
    && ln -s /opt/renix-public-starter/demo/bin/renix /root/.nix-profile/bin/renix

WORKDIR /workspace

ENV HOME=/home/doug \
    RENIX_HOST=demo \
    RENIX_DEMO=1 \
    RENIX_IMAGE=ghcr.io/dmasiero/renix-public-starter:latest \
    RENIX_SEED=/opt/renix-public-starter \
    RENIX_WORKSPACE=/workspace/renix-public-starter \
    PATH=/workspace/.renix-demo-activated/bin:/root/.nix-profile/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin

VOLUME ["/workspace", "/nix"]

ENTRYPOINT ["/opt/renix-public-starter/demo/entrypoint.sh"]
CMD ["tour"]
