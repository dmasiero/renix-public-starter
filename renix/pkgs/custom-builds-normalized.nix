{
  customBuildsFile ? ./custom-builds.nix,
  system ? builtins.currentSystem,
}:
let
  allCustomBuilds = import customBuildsFile;
  customBuilds = builtins.filter
    (build: !(build ? systems) || builtins.elem system build.systems)
    allCustomBuilds;
in
{
  builds = customBuilds;
  displayList = builtins.concatStringsSep ", " (map (build: build.displayName or build.id) customBuilds);
  attrNames = map (build: build.attrName) customBuilds;
}
