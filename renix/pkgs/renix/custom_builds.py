#!/usr/bin/env python3
"""Structured, concurrent custom-build discovery for renix."""

from __future__ import annotations

import argparse
import concurrent.futures
import email.utils
import json
import re
import subprocess
import sys
import urllib.request
from typing import Any, Callable

UNKNOWN = "unknown"
SOURCE_REQUIREMENTS = {
    "github-release": ("owner", "repo"),
    "npm": ("package",),
    "crates": ("package",),
    "pypi": ("package",),
    "http-redirect-regex": ("url", "regex"),
    "http-header-last-modified": ("url",),
    "flake-input": ("flake", "versionPath"),
}


class SourceRuntime:
    """Runtime adapter used by source discovery."""

    def json(self, url: str) -> Any:
        request = urllib.request.Request(url, headers={"User-Agent": "renix"})
        with urllib.request.urlopen(request, timeout=20) as response:
            return json.load(response)

    def redirected_url(self, url: str) -> str:
        request = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request, timeout=20) as response:
            return response.url

    def last_modified_date(self, url: str) -> str:
        request = urllib.request.Request(url, method="HEAD", headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(request, timeout=20) as response:
            value = response.headers.get("Last-Modified")
            return email.utils.parsedate_to_datetime(value).date().isoformat() if value else UNKNOWN

    def flake_version(self, flake: str, path: str) -> str:
        result = subprocess.run(
            ["nix", "eval", "--impure", "--raw", "--expr", f'(builtins.getFlake "{flake}").{path}'],
            capture_output=True,
            text=True,
            timeout=60,
        )
        return result.stdout.strip() or UNKNOWN


def normalize(build: dict[str, Any]) -> dict[str, Any]:
    source = build.get("source", {})
    update = build.get("update", {"type": "manual"})
    return {
        **build,
        "displayName": build.get("displayName", build["id"]),
        "source": source,
        "update": {"type": "manual", **update},
    }


def validate(build: dict[str, Any]) -> None:
    for field in ("id", "attrName", "source"):
        if not build.get(field):
            raise ValueError(f"custom build requires {field}")
    source = build["source"]
    kind = source.get("type")
    if kind not in SOURCE_REQUIREMENTS:
        raise ValueError(f"unsupported source type: {kind}")
    missing = [field for field in SOURCE_REQUIREMENTS[kind] if not source.get(field)]
    if missing:
        raise ValueError(f"{kind} source requires {', '.join(missing)}")


def discover_source(build: dict[str, Any], runtime: SourceRuntime) -> str:
    source = build["source"]
    kind = source["type"]
    if kind == "github-release":
        tag = runtime.json(f"https://api.github.com/repos/{source['owner']}/{source['repo']}/releases/latest").get("tag_name", "")
        return tag[1:] if source.get("stripV") and tag.startswith("v") else tag or UNKNOWN
    if kind == "npm":
        data = runtime.json(f"https://registry.npmjs.org/{source['package']}")
        return data.get("dist-tags", {}).get(source.get("distTag", "latest"), UNKNOWN)
    if kind == "crates":
        return runtime.json(f"https://crates.io/api/v1/crates/{source['package']}").get("crate", {}).get("newest_version", UNKNOWN)
    if kind == "pypi":
        return runtime.json(f"https://pypi.org/pypi/{source['package']}/json").get("info", {}).get("version", UNKNOWN)
    if kind == "http-redirect-regex":
        match = re.match(source["regex"], runtime.redirected_url(source["url"]))
        return match.group(1) if match else UNKNOWN
    if kind == "http-header-last-modified":
        return runtime.last_modified_date(source["url"])
    if kind == "flake-input":
        return runtime.flake_version(source["flake"], source["versionPath"])
    return UNKNOWN


def check_build(build: dict[str, Any], configured: Callable[[str], str], runtime: SourceRuntime) -> dict[str, Any]:
    build = normalize(build)
    try:
        current = configured(build["attrName"]) or UNKNOWN
    except Exception:
        current = UNKNOWN
    try:
        latest = discover_source(build, runtime)
    except Exception:
        latest = UNKNOWN
    return {"build": build, "configured": current, "latest": latest}


def check_all(builds: list[dict[str, Any]], configured: Callable[[str], str], runtime: SourceRuntime, workers: int = 4) -> list[dict[str, Any]]:
    for build in builds:
        validate(build)
    with concurrent.futures.ThreadPoolExecutor(max_workers=workers) as pool:
        futures = [pool.submit(check_build, build, configured, runtime) for build in builds]
        return [future.result() for future in futures]


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--flake-dir", required=True)
    parser.add_argument("--host", required=True)
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    builds = json.load(sys.stdin)

    def configured(attr: str) -> str:
        expr = f'''let flake = builtins.getFlake "{args.flake_dir}"; cfg = if flake ? nixosConfigurations && flake.nixosConfigurations ? "{args.host}" then flake.nixosConfigurations."{args.host}" else flake.darwinConfigurations."{args.host}"; in cfg.pkgs."{attr}".version'''
        result = subprocess.run(["nix", "eval", "--impure", "--raw", "--expr", expr], capture_output=True, text=True, timeout=60)
        return result.stdout.strip() or UNKNOWN

    json.dump(check_all(builds, configured, SourceRuntime(), args.workers), sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
