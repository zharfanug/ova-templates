# Firewall and fail2ban

## Firewall (nftables)

Incoming traffic is dropped unless a rule accepts it. Out of the box:

| Accepted | Rule file |
|---|---|
| replies to the VM's own connections | `/etc/nftables.conf` |
| loopback | `std-input.nft` |
| IPv4 ping | `std-input.nft` |
| DHCP replies from private networks | `std-input.nft` |
| SSH (10022) from private networks | `std-input.nft` |
| **all TCP ports, from anywhere** | `custom-input.nft` |

Private networks (`net_locals`) are 10.0.0.0/8, 172.16.0.0/12,
192.168.0.0/16 and 100.64.0.0/10. Loopback addresses arriving on any
other interface are dropped. Forwarding is dropped (`std-forward.nft`
is empty; the docker role adds its bridges there,
[`roles/docker.md`](roles/docker.md)), outgoing traffic is allowed.

### Changing the rules

`/etc/nftables.conf` and the `std-*.nft` files belong to the template;
change only the `custom-*.nft` files in `/etc/nftables.d/`:

| File | For |
|---|---|
| `custom-define.nft` | your own `define`s |
| `custom-sets.nft` | your own sets |
| `custom-input.nft` | your own input rules (checked after the standard rules) |

Example: instead of all TCP, accept only HTTP(S) from private networks.
`/etc/nftables.d/custom-input.nft`:

```
ip saddr @net_locals tcp dport { 80, 443 } accept
```

Check and apply:

```sh
sudo nft -c -f /etc/nftables.conf && sudo systemctl reload nftables
```

SSH from private networks keeps working (standard rule). The reload
replaces only the template's table (`inet base-nft`); fail2ban's bans
stay.

## fail2ban

fail2ban watches sshd's log (journal) and bans an address after **5
failures within 10 minutes**. Since SSH is key-only, failures are mostly
scanners: refused users (root, users not in `sudo` / `ssh`), wrong keys,
clients that offer only refused algorithms, connections closed before
authentication.

- A ban drops **all TCP and UDP** from that address, without an answer.
  Ping still works.
- The first ban lasts 1 hour; each further ban of the same address
  doubles it, up to 7 days (plus up to 30 random minutes).
- Bans survive a fail2ban restart and `systemctl reload nftables`.
- Only localhost is never banned.

Settings: `/etc/fail2ban/jail.d/ssh-nft.conf`.

```sh
sudo fail2ban-client status sshd                 # banned addresses
sudo fail2ban-client set sshd unbanip <address>  # unban
```

If you lock yourself out (e.g. while testing refused logins), unban from
the VM console.
