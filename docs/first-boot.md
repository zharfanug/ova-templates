# First boot and VM properties

How a deployed VM configures itself from its VM properties (vApp, see
[`platforms/vmware.md`](platforms/vmware.md)), and what happens when they
change later.

## Every boot

1. `vapp-seed.service` runs early, before cloud-init. It reads the VM
   properties from VMware Tools (`guestinfo.ovfEnv`), validates all of
   them and writes a cloud-init seed (`/var/lib/cloud/seed/nocloud/`).
2. cloud-init applies the seed.

If any property is invalid, `vapp-seed` logs every problem and changes
nothing: the VM keeps its previous settings. See the log with:

```sh
sudo journalctl -u vapp-seed
```

## First boot

cloud-init:

- creates the admin account (`vm_username`): member of `sudo` and `ssh`, shell
  bash, password from `vm_password`, SSH keys from `vm_ssh_key`;
- sets the hostname and FQDN (`vm_hostname`.`vm_domain`) and
  `/etc/hosts`;
- configures the first network interface with DHCP, IPv4 only (see
  [`network.md`](network.md));
- generates the SSH host keys.

`vapp-seed` sets the time zone (`vm_timezone`) and the GRUB password
(last 12 characters of `vm_uuid`, see [`hardening.md`](hardening.md)).

About 15 seconds after the first power-on the VM **reboots once by
itself**: the audit rules for the new admin account can only be loaded
at boot ([`auditing.md`](auditing.md)). 5 minutes after that boot the
file integrity baseline is created ([`integrity.md`](integrity.md)).

Root is locked. `sudo` always asks for the admin's password. With an
empty `vm_password` the password is the last 12 characters of `vm_uuid`.

## Changing properties later

Edit the properties in vCenter (**Configure → vApp Options**, VM powered
off, or while running and then reboot). They are applied at the next
boot:

| Property | Effect |
|---|---|
| `vm_hostname`, `vm_domain` | hostname / FQDN updated |
| `vm_timezone` | time zone updated |
| `vm_username` | admin account renamed (home directory moved, its own group renamed; same uid, files, keys) |
| `vm_password` | admin password set |
| `vm_ssh_key` | keys from the previous value that are gone are removed from `authorized_keys`, new ones added |
| `vm_uuid` | machine identity reset (see below) |

Changes made inside the VM are kept until the matching property changes:
a password set with `passwd`, or keys added to `authorized_keys` by
hand, survive reboots. Entering the same property value again does
nothing; to push a password from vCenter after changing it inside the
VM, enter a different value.

Hostname, domain and time zone always follow the properties: changes
made inside the VM are reset at the next boot.

## Machine identity (`vm_uuid`)

`vm_uuid` is the VM's identity (UUIDv7, also cloud-init's instance ID).
When it changes on a VM that was already deployed, the next boot resets:

- `/etc/machine-id` (and the D-Bus machine ID),
- the systemd random seed and credential secret,
- persistent network interface names,
- the SSH host keys,
- the GRUB password (new `vm_uuid`),

then reboots once. cloud-init then treats the VM as a new instance (new
SSH host keys; the admin account is kept).

The journal of the old identity is kept; `journalctl` shows only the
current machine ID by default, `journalctl -m` shows all. After the
reboot, `journalctl -u vapp-seed -b` shows "before the last reboot:
reset machine identity for vm_uuid <old> -> <new>" (the message from
before the reboot itself may be missing: it can happen before the journal
is written to disk).

**Clones:** a clone starts with the source's identity. Give it a new
`vm_uuid` before its first power-on and it resets itself. Same
`vm_uuid` means same identity.

## Disk growth

cloud-init grows the root partition and filesystem at boot when disk 1
was enlarged; `swap-grow` grows the swap area when disk 2 was enlarged
(see [`disk-layout.md`](disk-layout.md)).
