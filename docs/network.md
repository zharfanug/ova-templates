# Networking

The image uses **ifupdown** with the **dhcpcd** DHCP client, like a
standard Debian server install.

- At first boot cloud-init writes the configuration for the first network
  interface to `/etc/network/interfaces.d/50-cloud-init`: DHCP, IPv4.
  `/etc/network/interfaces` itself only holds the loopback interface and
  includes that directory.
- dhcpcd writes `/etc/resolv.conf` (DNS servers and search domain from
  the DHCP server). `systemd-resolved` is not installed.
- `systemd-networkd` is installed with systemd but disabled, so only one
  DHCP client manages the interface.

## IPv6

IPv6 is disabled (`/etc/sysctl.d/60-cis.conf`): the interfaces get no
IPv6 address, not even link-local, and dhcpcd runs IPv4 only
(`ipv4only` in `/etc/dhcpcd.conf`). To use IPv6, remove the three
`disable_ipv6` lines (or set them to `0`), run `sudo sysctl --system`,
remove `ipv4only` and add an `inet6` stanza for the interface.

## Static address

Put the configuration in its own file, e.g.
`/etc/network/interfaces.d/60-static`, and stop cloud-init from writing
its file again:

```sh
echo 'network: {config: disabled}' | sudo tee /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
sudo rm /etc/network/interfaces.d/50-cloud-init
```

See `interfaces(5)` for the syntax.
