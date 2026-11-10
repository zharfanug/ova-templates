# SSH and login

## SSH

```sh
ssh -p 10022 admin@<vm>
```

- **Port 10022** only; port 22 is not used
  (`/etc/ssh/sshd_config.d/port.conf`).
- **Keys only.** The keys come from the `vm_ssh_key` property (see
  [`first-boot.md`](first-boot.md)); keys added to `~/.ssh/authorized_keys`
  by hand are kept. The admin password works on the console and for
  `sudo`, never over SSH.
- **Only members of group `sudo` or `ssh`** may log in
  (`AllowGroups sudo ssh`). The admin is in both. To let another user
  log in without sudo rights:

  ```sh
  sudo usermod -aG ssh <user>
  ```

- Root login is refused (root is locked anyway).
- No forwarding: `ssh -L`, `-R`, `-D`, `-W` and agent / X11 forwarding are
  refused ("administratively prohibited").
- Strong algorithms only: no CBC ciphers, no SHA-1, UMAC or MD5 MACs, no
  SHA-1 key exchange. Very old clients fail with "Unable to negotiate".
- Dead connections are dropped after about 15 minutes without an answer
  (`ClientAliveInterval 300`, `ClientAliveCountMax 3`).

Settings are drop-ins in `/etc/ssh/sshd_config.d/` (mode 0600). Debian's
`sshd_config` reads them first, and the first value read wins, so a
change goes into a drop-in, not into `sshd_config`. Test with
`sudo sshd -t`, apply with `sudo systemctl restart ssh`.

The image has no SSH host keys; each VM creates its own at first boot
(and again after a machine identity reset).

## Login banners

| When | Shown | File |
|---|---|---|
| Console, before login | host name, terminal, date + warning | `/etc/issue` |
| SSH, before authentication | warning | `/etc/issue.net` |

The static MOTD (`/etc/motd`, `/etc/update-motd.d/`) is empty.

## Login summary (zn-motd)

Every login shell (console, SSH, `sudo -i`) shows a system summary:
system information, resource usage, services, active logins, pending
reboot. It is [zn-motd](https://github.com/zharfanug/zn-motd), the
newest release at build time, installed as `/etc/profile.d/zn-motd.sh`;
`motd` shows it on demand (`motd --help`).

Once a day per user it looks up the VM's public IP address
(`ifconfig.co`) and checks for a newer zn-motd version (GitHub), 3
seconds each. Without internet access a login can therefore take a few
seconds longer. `sudo motd --update` installs a newer version.

Not shown for `ssh <vm> <command>`, `scp` and `sftp`.
