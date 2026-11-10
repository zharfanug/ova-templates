# VMware (vCenter / ESXi)

File: `[<prefix>-]<os>-<ver>[-<role>]-<arch>-efi-vmware.ova`, e.g.
`zn-debian-13-amd64-efi-vmware.ova`

## Requirements

ESXi / vCenter **8.0 U2 or later** (virtual hardware version `vmx-21`).

## Virtual hardware

Follows vCenter's defaults for a new Debian VM.

| Item | Value |
|---|---|
| Hardware version | `vmx-21` |
| Guest OS | Debian 12 64-bit (`debian12_64Guest`; ESXi 8.0 has no Debian 13 entry) |
| Firmware | EFI, Secure Boot off |
| CPU / memory | from the template (default 2 vCPU as 1 socket × 2 cores, 2048 MB) |
| Disk | VMware Paravirtual SCSI (PVSCSI), disk on SCSI 0:0 |
| CD/DVD | SATA (AHCI), empty |
| Network | VMXNET3, mapped from the OVF network `VM Network` |
| VMware Tools | upgrade manually; no periodic time sync with the host (the guest uses NTP, `systemd-timesyncd`), one-off syncs allowed |

## Import

### vSphere Client

**Deploy OVF Template** → select the `.ova` → choose name, folder,
compute resource, then:

- **Storage:** choose **Thin Provision** as the virtual disk format. The
  disk is 128 GiB but holds well under 1 GiB after import.
- **Networks:** map `VM Network` to your port group.
- **Customize template:** fill in the VM properties (below).

### govc

```sh
govc import.spec zn-debian-13-amd64-efi-vmware.ova > options.json
# edit options.json: DiskProvisioning "thin", NetworkMapping, PropertyMapping
govc import.ova -folder=<folder> -name=<vm name> -options=options.json zn-debian-13-amd64-efi-vmware.ova
govc vm.power -on <vm name>
```

## VM properties (vApp)

Shown in the import wizard and editable later under **Configure → vApp
Options**. vCenter passes them to the VM (`guestinfo.ovfEnv`); what the VM
does with them is in [`first-boot.md`](../first-boot.md).

| Property | Default | Notes |
|---|---|---|
| VM UUID (`vm_uuid`) | empty | UUIDv7, generated before deployment; the VM's identity |
| VM Hostname (`vm_hostname`) | empty | without domain, e.g. `web01` |
| VM Domain (`vm_domain`) | `example.com` (build setting `DEFAULT_DOMAIN`) | |
| Time Zone (`vm_timezone`) | `UTC` (build setting `DEFAULT_TIMEZONE`) | tz database name, e.g. `Asia/Jakarta` |
| Admin Username (`vm_username`) | `admin` (build setting `DEFAULT_USERNAME`) | |
| Admin Password (`vm_password`) | empty → last 12 characters of the VM UUID | console and `sudo` only |
| SSH Public Key (`vm_ssh_key`) | **required** | one or more keys, comma-separated (SSH is key-only) |

A UUIDv7 can be generated with:

```sh
python3 -c 'import os,time; b=bytearray(int(time.time()*1000).to_bytes(6,"big")+os.urandom(10)); b[6]=b[6]&15|112; b[8]=b[8]&63|128; h=b.hex(); print(h[:8],h[8:12],h[12:16],h[16:20],h[20:],sep="-")'
```

## OVA contents

| File | |
|---|---|
| `<name>.ovf` | descriptor (first in the archive) |
| `<name>.mf` | SHA256 of the descriptor and the disk |
| `<name>-disk1.vmdk` | disk, streamOptimized |

`<name>.ova.sha256` next to the OVA is the checksum of the whole file.
