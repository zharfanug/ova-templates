#!/usr/bin/env python3
"""What a Debian image contains: OS release, kernel and the roles' core
packages, as JSON on stdout. Reads only files under <root>, so it works on
a mounted image (build step 79-contents.sh, or an old release's disk).

Usage: os/debian/contents.py <root> <template> [role...]

Core packages per role: roles/<role>/debian/manifest.list (one package
name per line, # comments).
"""

import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent


def os_release(root):
    values = {}
    for name in ("etc/os-release", "usr/lib/os-release"):
        path = root / name
        if path.is_file():
            for line in path.read_text().splitlines():
                m = re.fullmatch(r'([A-Z_]+)=(.*)', line.strip())
                if m:
                    values[m.group(1)] = m.group(2).strip('"\'')
            break
    return values


def dpkg_versions(root):
    """{package: version} of installed packages (/var/lib/dpkg/status)."""
    versions = {}
    status = root / "var/lib/dpkg/status"
    for block in status.read_text().split("\n\n"):
        fields = dict(re.findall(r"^([A-Za-z-]+): (.*)$", block, re.M))
        if fields.get("Status", "").endswith(" installed") and "Package" in fields:
            versions[fields["Package"]] = fields.get("Version", "")
    return versions


def version_key(v):
    return [int(p) if p.isdigit() else p for p in re.split(r"(\d+)", v)]


def kernel(root):
    names = [p.name[len("vmlinuz-"):] for p in (root / "boot").glob("vmlinuz-*")]
    return max(names, key=version_key) if names else ""


def core_packages(roles, versions):
    core = {}
    for role in roles:
        listing = REPO / "roles" / role / "debian" / "manifest.list"
        if not listing.is_file():
            continue
        for line in listing.read_text().splitlines():
            pkg = line.split("#", 1)[0].strip()
            if pkg:
                core[pkg] = versions.get(pkg, "")
    return core


def contents(root, template, roles):
    rel = os_release(root)
    point = (root / "etc/debian_version")
    version = point.read_text().strip() if point.is_file() else rel.get("VERSION_ID", "")
    return {
        "template": template,
        "os": {
            "id": rel.get("ID", "debian"),
            "name": rel.get("NAME", ""),
            "version": version,
            "codename": rel.get("VERSION_CODENAME", ""),
        },
        "kernel": kernel(root),
        "core": core_packages(roles, dpkg_versions(root)),
    }


def main():
    if len(sys.argv) < 3:
        sys.exit("usage: contents.py <root> <template> [role...]")
    root, template, roles = Path(sys.argv[1]), sys.argv[2], sys.argv[3:]
    print(json.dumps(contents(root, template, roles), indent=2))


if __name__ == "__main__":
    main()
