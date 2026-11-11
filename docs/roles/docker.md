# Role: docker

`zn-debian-13-docker-amd64-efi-vmware.ova` ("ZN Debian 13 Docker
Template") is the Debian 13 template plus Docker Engine. Everything in
the base applies (hardening, firewall, auditd, AIDE, first boot); this
page lists what the role adds or changes. Hardware: 2 vCPU, 4 GB, disks
as in the base (50 GiB system + 2 GiB swap).

## Installed

Docker Engine from Docker's own apt repository, set up the way Docker's
[install guide for Debian](https://docs.docker.com/engine/install/debian/)
does, but at build time:

| | |
|---|---|
| key | `/etc/apt/keyrings/docker.asc` (the build checks its fingerprint `9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88`) |
| source | `/etc/apt/sources.list.d/docker.sources` (`https://download.docker.com/linux/debian`, `trixie`, `stable`) |
| packages | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` |

Updates come with `apt upgrade` like everything else (the AIDE apt hook
accepts them). `docker`, `containerd` and `docker.socket` start at boot.

## The admin user

The admin account (VM property `vm_username`) is in the `docker` group
and uses Docker **without sudo**. Membership in `docker` is equivalent
to root: a container can mount the host's files. Give it only to
accounts that may be root anyway.

## Daemon settings

`/etc/docker/daemon.json`:

| Setting | Effect |
|---|---|
| `"log-driver": "json-file"`, `"max-size": "100m"`, `"max-file": "3"` | container logs as files, at most 3 × 100 MB per container |
| `"live-restore": true` | containers keep running while the daemon restarts or is updated |
| `"no-new-privileges": true` | processes in containers can't gain privileges (setuid binaries) |
| `"userland-proxy": false` | published ports through NAT only, no `docker-proxy` processes |
| `"icc": false` | containers on the default bridge can't talk to each other (compose / user networks are not affected) |

### Container logs: 14 days

Docker rotates logs only by size. `/etc/logrotate.d/docker-containers`
also rotates every container log daily and keeps 14 days (compressed,
`<container>-json.log-<date>.gz` next to the log). `docker logs` shows
the current file (today); older days are in the `.gz` files:

```sh
sudo ls /var/lib/docker/containers/<id>/
sudo zcat /var/lib/docker/containers/<id>/<id>-json.log-20261110.gz
```

## Network and firewall

- **IP forwarding is on** (`/etc/sysctl.d/70-docker.conf`,
  `net.ipv4.ip_forward = 1`): containers need it. This is a deviation from
  the CIS setting in the base ([`hardening.md`](../hardening.md)).
- The firewall's forward chain accepts traffic from and to Docker's
  bridges (`/etc/nftables.d/std-forward.nft`: `docker0`, `br-*`). Docker's
  own rules still decide which ports reach which container.

### Published ports are reachable from anywhere

Docker publishes ports through NAT and the forward path, **not** the
input chain: `docker run -p 8080:80 …` is reachable from every network
that can reach the VM, whatever `custom-input.nft` says
([`firewall.md`](../firewall.md)). To restrict it:

- Publish on loopback only, for a reverse proxy on the VM itself:
  `-p 127.0.0.1:8080:80`.
- Or filter in Docker's `DOCKER-USER` chain (checked before Docker's own
  rules), e.g. only private networks may reach containers:

  ```sh
  sudo iptables -I DOCKER-USER -i ens192 ! -s 10.0.0.0/8 -j DROP
  ```

  `iptables` rules are not saved by default; make them permanent with a
  systemd unit that runs after `docker.service`, or the
  `iptables-persistent` package.

## Data on the system disk

Images, containers and volumes are in `/var/lib/docker` on the system
Btrfs pool (Docker 29 keeps them in containerd's image store, driver `overlayfs`). They
share the free space with the system: if they fill the disk, auditd
halts the VM at 3 % free ([`auditing.md`](../auditing.md)).

For real workloads, put Docker's data on its own disk:

1. Add a virtual disk, find it with `lsblk`
   ([`disk-layout.md`](../disk-layout.md)).
2. Format and mount it on `/var/lib/docker` with Docker stopped:

   ```sh
   sudo systemctl stop docker.socket docker containerd
   sudo mkfs.btrfs -L docker /dev/sdX
   sudo mv /var/lib/docker /var/lib/docker.old && sudo mkdir /var/lib/docker
   echo 'LABEL=docker /var/lib/docker btrfs defaults,noatime 0 0' | sudo tee -a /etc/fstab
   sudo mount /var/lib/docker
   sudo systemctl start containerd docker
   ```

   The old data stays in `/var/lib/docker.old` (copy what you need, then
   delete it). Grow the disk later with `sudo btrfs filesystem resize max
   /var/lib/docker`. AIDE reports the new device once
   ([`integrity.md`](../integrity.md)).

## Auditing and integrity

- auditd (`/etc/audit/rules.d/60-docker.rules`, key `docker`): changes to
  `/etc/docker`, `/etc/containerd`, `/etc/default/docker`, the Docker
  and containerd service units and programs (CIS Docker Benchmark).
  Not audited: `/var/lib/docker` (every container write) and the runtime
  sockets.
- AIDE watches `/etc/docker` and `/etc/containerd`; Docker's programs are
  in `/usr/bin` (watched as in the base); `/var/lib/docker` is not.
