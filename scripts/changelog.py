#!/usr/bin/env python3
"""Add releases to CHANGELOG.md from their GitHub release notes.

Usage: scripts/changelog.py <vX.Y.Z>...

Each release becomes a section "## vX.Y.Z - YYYY-MM-DD" with the release
notes (written by scripts/release-notes.py), newest first. A release
already in the file is left as it is. Needs `gh` (GH_TOKEN).

Run it after a release (the tag must stay on the tested commit, so the
entry is committed after it; CHANGELOG.md doesn't start a build).
"""

import json
import re
import subprocess
import sys
from pathlib import Path

PATH = Path(__file__).resolve().parent.parent / "CHANGELOG.md"
HEADER = """# Changelog

Every release with what is inside each template (OS, kernel, core
packages) and what changed. Builds always take the latest packages, so a
release can change versions without any change in this repository. The
same notes are on each [GitHub release](https://github.com/zharfanug/ova-templates/releases),
with `<ova>.manifest.json` attached.
"""
SECTION = re.compile(r"^## (v\d+\.\d+\.\d+)\b", re.M)


def key(tag):
    return tuple(int(x) for x in tag[1:].split("."))


def release(tag):
    res = subprocess.run(["gh", "release", "view", tag, "--json", "body,publishedAt"],
                         capture_output=True, text=True)
    if res.returncode != 0:
        sys.exit("gh release view %s: %s" % (tag, res.stderr.strip()))
    data = json.loads(res.stdout)
    return data["publishedAt"][:10], data["body"].strip()


def sections(text):
    """[(tag, text)] of the existing sections."""
    marks = list(SECTION.finditer(text))
    return [(m.group(1), text[m.start():marks[i + 1].start() if i + 1 < len(marks) else len(text)]
             .rstrip() + "\n") for i, m in enumerate(marks)]


def main():
    tags = sys.argv[1:]
    if not tags or not all(re.fullmatch(r"v\d+\.\d+\.\d+", t) for t in tags):
        sys.exit("usage: changelog.py <vX.Y.Z>...")
    existing = dict(sections(PATH.read_text())) if PATH.is_file() else {}
    for tag in tags:
        if tag in existing:
            print("%s: already in %s" % (tag, PATH.name))
            continue
        date, body = release(tag)
        existing[tag] = "## %s - %s\n\n%s\n" % (tag, date, body)
        print("%s: added" % tag)
    out = HEADER + "".join("\n" + existing[t] for t in sorted(existing, key=key, reverse=True))
    PATH.write_text(out)


if __name__ == "__main__":
    main()
