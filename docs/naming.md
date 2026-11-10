# Naming

## OVA files

```
[<prefix>-]<os>-<ver>[-<role>...]-<arch>-efi-<platform>.ova
```

| Part | Example | From |
|---|---|---|
| prefix | `zn` | `OVA_PREFIX` in `.env` (default `zn`; `""` = no prefix) |
| os, ver | `debian-13` | template |
| role | `docker` | template `ROLES` (none for the base image) |
| arch | `amd64` | template |
| firmware | `efi` | template (UEFI only) |
| platform | `vmware` | the platform the OVA is built for |

Examples: `zn-debian-13-amd64-efi-vmware.ova`,
`zn-debian-13-docker-amd64-efi-vmware.ova` (planned).

One OVA is built per platform: the image content differs (guest agent,
first-boot setup), not only the virtual hardware.

Next to each OVA: `<name>.ova.sha256` (checksum) and `<name>.ovf` (the
descriptor, for inspection).

## Templates

A template is `templates/<os>-<ver>[-<role>...]-<arch>-<firmware>.env`.
The file name must match its values (the build stops otherwise). See
[`adding-a-template.md`](adding-a-template.md).

## Product information

Shown when the OVA is imported (`.env`, see
[`building.md`](building.md#settings-env)):

| Field | Default | Example |
|---|---|---|
| Product | `ZN {os} {ver} {role} Template` | `ZN Debian 13 Template` |
| Version | `1.0.0.{timestamp}` | `1.0.0.202611101613` (build start) |
| Vendor | `zharfanug` | |

## Inside the VM

| Item | Value |
|---|---|
| Host name in the image | `<os>-<ver>-template`, e.g. `debian-13-template`; replaced at first boot by `vm_hostname` |
| Admin account | `vm_username` (default `admin`, `DEFAULT_USERNAME`) |
| Domain | `vm_domain` (default `example.com`, `DEFAULT_DOMAIN`) |
