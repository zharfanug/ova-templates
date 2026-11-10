# Logs and monitoring

| Log | Where | Rotation | Kept |
|---|---|---|---|
| system journal | `/var/log/journal/` (`journalctl`) | journald | journald's size limits |
| package logs (apt, dpkg, fail2ban, cloud-init, …) | `/var/log/` | logrotate (daily timer), per package | per package |
| sudo | `/var/log/sudo.log` (root only) | logrotate, daily, compressed | 40 days |
| audit | `/var/log/audit/audit.log`, archives in `/var/log/archives/audit/` ([`auditing.md`](auditing.md)) | daily archive job | 40 days |
| file integrity | `/var/log/aide/` ([`integrity.md`](integrity.md)) | per check / accept | 7 checks, accept reports 40 days |
| performance history | `/var/log/sysstat/` | sysstat | 7 days |

All logs live on their own Btrfs subvolumes (`/var/log`,
`/var/log/audit`, `/var/log/archives`; see
[`disk-layout.md`](disk-layout.md)), mounted `nodev,nosuid,noexec`.

## Performance history (sysstat)

sysstat records CPU, memory, disk and network usage every 10 minutes,
with a daily summary:

```sh
sar               # CPU today
sar -r            # memory
sar -d -p         # disks
sar -n DEV        # network
sar -f /var/log/sysstat/sa09   # the 9th of the month
```

The login summary uses it to show CPU usage. Its data files are not
audited and not checked by AIDE (they change every 10 minutes).
