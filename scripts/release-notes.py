#!/usr/bin/env python3
"""Release notes from the release manifests (Markdown on stdout).

Usage: scripts/release-notes.py <tag> <manifest.json>... [--prev <tag>] [--prev-dir <dir>]

  Contents         per template: OS, kernel, core packages
  Version changes  against the previous release's manifests
  Changes          commit subjects since the previous release

The previous release (highest vX.Y.Z below <tag>, unless --prev) and its
manifests (or *.manifest.json in --prev-dir) and the commits come from
GitHub through `gh` (GH_TOKEN). The
repository is $GITHUB_REPOSITORY, or the one `gh` sees here. Used by the
release workflow and for CHANGELOG.md (scripts/changelog.py).
"""

import json
import os
import re
import subprocess
import sys
import tempfile
from pathlib import Path

TAG = re.compile(r"v(\d+)\.(\d+)\.(\d+)")
# Commits that only record a release.
SKIP = re.compile(r"^(changelog|CHANGELOG)\b|^Merge ")


def gh(*args, check=True):
    res = subprocess.run(["gh", *args], capture_output=True, text=True)
    if check and res.returncode != 0:
        sys.exit("gh %s: %s" % (" ".join(args), res.stderr.strip()))
    return res


def repo():
    return os.environ.get("GITHUB_REPOSITORY") or gh(
        "repo", "view", "--json", "nameWithOwner", "-q", ".nameWithOwner").stdout.strip()


def tag_key(tag):
    m = TAG.fullmatch(tag)
    return tuple(int(x) for x in m.groups()) if m else None


def previous_tag(tag, rep):
    out = gh("release", "list", "-R", rep, "--limit", "200",
             "--json", "tagName,isDraft", "-q", ".[] | select(.isDraft | not) | .tagName")
    key = tag_key(tag)
    older = [t for t in out.stdout.split() if tag_key(t) and tag_key(t) < key]
    return max(older, key=tag_key) if older else None


def release_manifests(tag, rep):
    """{template: manifest} attached to a release (empty if none)."""
    with tempfile.TemporaryDirectory() as d:
        res = gh("release", "download", tag, "-R", rep, "--pattern", "*.manifest.json",
                 "--dir", d, check=False)
        if res.returncode != 0:
            return {}
        return load([str(p) for p in Path(d).glob("*.manifest.json")])


def load(paths):
    manifests = {}
    for p in paths:
        m = json.loads(Path(p).read_text())
        manifests[m["template"]] = m
    return manifests


def commits(prev, tag, rep):
    if not prev:
        return []
    out = gh("api", "repos/%s/compare/%s...%s" % (rep, prev, tag),
             "-q", ".commits[].commit.message | split(\"\\n\")[0]")
    return [c for c in out.stdout.splitlines() if c and not SKIP.search(c)]


def short(version):
    """Upstream part of a Debian package version: 5:29.0.1-1~debian.13 -> 29.0.1."""
    v = version.split(":", 1)[-1]
    return v.rsplit("-", 1)[0] if "-" in v else v


def os_label(m):
    o = m["os"]
    name = (o.get("name") or o.get("id", "")).replace(" GNU/Linux", "")
    return "%s %s%s" % (name, o.get("version", ""),
                        " (%s)" % o["codename"] if o.get("codename") else "")


def contents_table(manifests):
    core = []
    for m in manifests.values():
        core += [k for k in m.get("core", {}) if k not in core]
    head = ["Template", "OS", "Kernel"] + core
    rows = ["| " + " | ".join(head) + " |", "|" + "---|" * len(head)]
    for name in sorted(manifests):
        m = manifests[name]
        cells = [name, os_label(m), m.get("kernel", "")]
        cells += [short(m.get("core", {}).get(k, "")) or "—" for k in core]
        rows.append("| " + " | ".join(cells) + " |")
    return "\n".join(rows)


def version_changes(manifests, before):
    lines = []
    for name in sorted(manifests):
        m, old = manifests[name], before.get(name)
        if old is None:
            lines.append("- %s: new template" % name)
            continue
        diffs = []
        if os_label(old) != os_label(m):
            diffs.append("%s → %s" % (os_label(old), os_label(m)))
        if old.get("kernel") != m.get("kernel"):
            diffs.append("kernel %s → %s" % (old.get("kernel") or "?", m.get("kernel")))
        for pkg, ver in m.get("core", {}).items():
            was = old.get("core", {}).get(pkg)
            if was != ver:
                # Same upstream version: show the package revisions.
                old_v, new_v = (short(was), short(ver)) if was and short(was) != short(ver) \
                    else (was or "new", ver)
                diffs.append("%s %s → %s" % (pkg, old_v, new_v))
        lines.append("- %s: %s" % (name, ", ".join(diffs) if diffs else "no version changes"))
    return "\n".join(lines)


def notes(tag, manifests, prev, before, subjects, rep):
    parts = ["### Contents", "", contents_table(manifests), ""]
    if prev and before:
        parts += ["### Version changes since %s" % prev, "", version_changes(manifests, before), ""]
    if prev:
        parts += ["### Changes since %s" % prev, ""]
        parts += ["- %s" % s for s in subjects] or ["- Package updates only."]
        parts.append("")
    parts.append("Each template's `<ova>.manifest.json` lists these versions.")
    if prev:
        parts += ["", "**Full Changelog**: https://github.com/%s/compare/%s...%s" % (rep, prev, tag)]
    return "\n".join(parts) + "\n"


def main():
    args = sys.argv[1:]
    opts = {}
    for opt in ("--prev", "--prev-dir"):
        if opt in args:
            i = args.index(opt)
            opts[opt] = args[i + 1]
            del args[i:i + 2]
    prev, prev_dir = opts.get("--prev"), opts.get("--prev-dir")
    if len(args) < 2 or not tag_key(args[0]):
        sys.exit("usage: release-notes.py <vX.Y.Z> <manifest.json>... [--prev <tag>]")
    tag, paths = args[0], args[1:]
    rep = repo()
    prev = prev or previous_tag(tag, rep)
    if prev_dir:
        before = load([str(p) for p in Path(prev_dir).glob("*.manifest.json")])
    else:
        before = release_manifests(prev, rep) if prev else {}
    sys.stdout.write(notes(tag, load(paths), prev, before, commits(prev, tag, rep), rep))


if __name__ == "__main__":
    main()
