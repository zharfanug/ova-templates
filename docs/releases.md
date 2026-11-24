# Releases

Every build installs the latest packages of the day, so two releases can
differ (a Debian point release, a new kernel, a new Docker Engine) without
any change in this repository. Each release records what is inside:

- [`CHANGELOG.md`](../CHANGELOG.md): every release, newest first;
- the [GitHub release](https://github.com/zharfanug/ova-templates/releases)
  notes: the same text;
- `<ova>.manifest.json` attached to the release, one per template.

## Release files

| File | |
|---|---|
| `<name>.ova` | the template |
| `<name>.ova.sha256` | checksum of the OVA |
| `<name>.ovf` | the descriptor inside the OVA, to read without downloading it |
| `<name>.manifest.json` | what the template contains (below) |

Releases before v1.4.2 got their manifests later, read from their own
OVAs (`build_id` is empty for them).

## Manifest

```json
{
  "template": "debian-13-docker-amd64-efi",
  "version": "1.4.1",
  "ova": "zn-debian-13-docker-amd64-efi-vmware.ova",
  "build_id": "202611141630",
  "os": { "id": "debian", "name": "Debian GNU/Linux", "version": "13.7", "codename": "trixie" },
  "kernel": "6.12.117+deb13-amd64",
  "core": {
    "docker-ce": "5:29.9.3-1~debian.13~trixie",
    "containerd.io": "2.4.2-4~debian.13~trixie",
    "docker-buildx-plugin": "0.39.0-1~debian.13~trixie",
    "docker-compose-plugin": "5.7.1-1~debian.13~trixie"
  }
}
```

| Field | |
|---|---|
| `template`, `version`, `ova` | template name, product version, OVA file |
| `build_id` | build start time (`YYYYMMDDhhmm`) of the tested build the release repackages |
| `os` | from the image's `/etc/os-release`; `version` is the point release (`/etc/debian_version` on Debian) |
| `kernel` | the kernel installed in the image |
| `core` | package versions of the role's core packages (`roles/<role>/<os>/manifest.list`); empty without a role |

How it is made: build step `os/<os>/steps/79-contents.sh` reads the
finished image (`os/<os>/contents.py`) into
`build/<ID>/<image>.contents.json`, next to the image, not inside it.
`scripts/make-ova.py` adds the product version and writes
`<name>.manifest.json` beside the OVA, at the build and again when a
release repackages the build. Release notes come from
`scripts/release-notes.py`, `CHANGELOG.md` from `scripts/changelog.py`.

## Version in a deployed VM

The template's version is in the VM: the OVA has a read-only VM property
`template_version` (the product version), and first boot writes it to
`/etc/zn-release` (`/etc/<OVA_PREFIX>-release`):

```sh
$ cat /etc/zn-release
ZN_TEMPLATE="debian-13-docker-amd64-efi"
ZN_VERSION="1.4.2"
```

The release notes or the manifest of that version tell what was inside it.
A build that was not released has its build version there
(`1.0.0.<ID>` by default, `PRODUCT_VERSION`).

## Making a release

A tag `vX.Y.Z` on the tested commit starts the release workflow: it
repackages the tested build with version X.Y.Z, attaches the OVAs, their
checksums, descriptors and manifests, and writes the notes. Then add the
release to `CHANGELOG.md` (the tag stays on the tested commit, so this is a
separate commit; `.md` changes start no build):

```sh
python3 scripts/changelog.py vX.Y.Z    # needs gh with access to the repository
```
