# nfrastack/container-openwrt_builder

Builds custom [OpenWRT](https://openwrt.org) firmware.

Presently builds custom firmware for Cudy AP3000, Cudy AP3000 Wall, Asus MAP AC-2200, and Wavlink D6 with Dawn roaming, VLANs, and client isolation on Cudy models.

## Maintainer

- [Nfrastack](https://www.nfrastack.com)

## Table of Contents

- [Quick Start](#quick-start)
- [Configuration](#configuration)
  - [Persistent Storage](#persistent-storage)
- [Build Models](#build-models)
- [Environment Variables](#environment-variables)
  - [VLANs (`NETWORK_01_` through `NETWORK_99_`)](#vlans-network_01_-through-network_99_)
  - [SSIDs (`SSID_01_` through `SSID_99_`)](#ssids-ssid_01_-through-ssid_99_)
  - [MAC-based Hostname](#mac-based-hostname)
  - [Per-VLAN Watchcat (connection monitoring)](#per-vlan-watchcat-connection-monitoring)
  - [Client Isolation (ebtables)](#client-isolation-ebtables)
  - [Live Tools (on the device)](#live-tools-on-the-device)
  - [Other](#other)
- [What gets provisioned on first boot (Cudy models only)](#what-gets-provisioned-on-first-boot-cudy-models-only)
- [Support & Maintenance](#support--maintenance)
- [License](#license)

## Quick Start

```yaml
# docker-compose.yml
services:
  openwrt_builder:
    build: .
    image: docker.io/nfrastack/openwrt_builder
    volumes:
      - ./data:/data
    environment:
      - NETWORK_01_VLAN=230
      - NETWORK_01_NAME=MGMT
      - NETWORK_01_NETWORK=10.60.230
      - NETWORK_01_MASK=255.255.255.0
      - NETWORK_01_GATEWAY=10.60.230.1

      - SSID_01_BAND=5g
      - SSID_01_NAME=meatverse
      - SSID_01_NETWORK=MEAT
      - SSID_01_KEY=burgerchickenhotdog
      - SSID_01_MOBILITY_DOMAIN=6328

      - ROOT_PASSWORD=yourpass
```

```
docker compose up -d
docker exec -it openwrt_builder openwrt_builder cudy
```

Output: `/data/builds/YYYYMMDD-HHMMSS_cudy_ap3000`

## Configuration

### Persistent Storage

The following directories are used for configuration and can be optionally mapped for persistent storage.

| Directory | Description  |
| --------- | ------------ |
| `/data`   | Build Output |

## Build Models

| Model       | Board               | Target           |
| ----------- | ------------------- | ---------------- |
| `cudy`      | Cudy AP3000 v1      | mediatek/filogic |
| `cudy-wall` | Cudy AP3000 Wall v1 | mediatek/filogic |
| `asus`      | Asus MAP AC-2200    | ipq40xx/generic  |
| `wavlink`   | Wavlink D6          | ramips/mt7621    |

## Environment Variables

### VLANs (`NETWORK_01_` through `NETWORK_99_`)

| Variable             | Required | Description                                         |
| -------------------- | -------- | --------------------------------------------------- |
| `NETWORK_01_VLAN`    | yes      | VLAN ID (e.g. 230)                                  |
| `NETWORK_01_NAME`    | yes      | Interface name (e.g. MGMT)                          |
| `NETWORK_01_NETWORK` | yes      | Network prefix (e.g. 10.60.230)                     |
| `NETWORK_01_MASK`    | yes      | Netmask (e.g. 255.255.255.0)                        |
| `NETWORK_01_GATEWAY` | no       | Gateway IP (defaults to x.x.x.1)                    |
| `NETWORK_01_DNS`     | no       | DNS server IP (defaults to gateway)                 |
| `NETWORK_01_IP`      | no       | Static IP for this VLAN (omit = DHCP)               |
| `NETWORK_01_TAGGED`  | no       | `true` (tagged, default) or `false` (untagged/PVID) |
| `NETWORK_01_EXCLUDE_APS` | no   | Skip this VLAN (interface, watchcat, ebtables) on specific APs |

Add up to 99 networks (`NETWORK_02_*`, `NETWORK_03_*`, etc.).

Use `TAGGED=false` for your native/untagged VLAN (usually VLAN 1). All other VLANs should leave the default `true` (802.1q tagged on the uplink).

### SSIDs (`SSID_01_` through `SSID_99_`)

| Variable                  | Required | Description                                                 |
| ------------------------- | -------- | ----------------------------------------------------------- |
| `SSID_01_BAND`            | yes      | `2g`, `5g`, or `both`                                       |
| `SSID_01_NAME`            | yes      | Broadcast SSID name                                         |
| `SSID_01_NETWORK`         | yes      | Associates to which VLAN (must match a `NETWORK_xx_NAME`)   |
| `SSID_01_KEY`             | yes      | WiFi password                                               |
| `SSID_01_ENCRYPTION`      | no       | `sae-mixed` (default), `sae`, `psk2+ccmp`, `psk2`, `none`   |
| `SSID_01_MOBILITY_DOMAIN` | no       | 802.11r mobility domain (e.g. 6328)                         |
| `SSID_01_BEACON_INT`      | no       | Beacon interval in ms (default 100)                         |
| `SSID_01_IE_R`            | no       | 802.11r Fast Roaming (1=enabled, 0=disabled, default 1)     |
| `SSID_01_IE_K`           | no       | 802.11k Neighbor Reports (1=enabled, 0=disabled, default 1) |
| `SSID_01_IE_V`           | no       | 802.11v BSS Transition (1=enabled, 0=disabled, default 1) |
| `SSID_01_EXCLUDE_APS`    | no       | Skip SSID on specific APs. `ap3:2g` skips 2.4GHz only, `ap3` skips both bands |

Example — IOT on both bands, WPA2-only, no 802.11r/k:

```yaml
- SSID_02_BAND=both
- SSID_02_NAME=TTTTTT
- SSID_02_NETWORK=IOT
- SSID_02_KEY=internetofshit
- SSID_02_ENCRYPTION=psk2+ccmp
- SSID_02_IE_R=0
- SSID_02_IE_K=0
```

### AP MAC → Hostname (`AP_01_` through `AP_99_`)

| Variable | Required | Description |
|----------|----------|-------------|
| `AP_01_MAC` | no | MAC address (uppercase, colon-separated) |
| `AP_01_HOSTNAME` | no | Hostname (e.g. `ap1`) |

Default: `ap-unknown` if no MAC matches. The hostname's numeric suffix determines the IP octet: `OCTET = AP_OCTET_BASE + AP_NUM`.

Example — map 3 APs:
```yaml
- AP_01_MAC=D4:0D:AB:50:32:0C
- AP_01_HOSTNAME=ap1
- AP_02_MAC=AA:BB:CC:DD:EE:01
- AP_02_HOSTNAME=ap2
```

### Per-VLAN Watchcat (connection monitoring)

| Variable                       | Description                         | Default      |
| ------------------------------ | ----------------------------------- | ------------ |
| `NETWORK_01_WATCHCAT=true`     | Enable watchcat on this VLAN        | off          |
| `NETWORK_01_WATCHCAT_HOSTS`    | Hosts to ping                       | VLAN gateway |
| `NETWORK_01_WATCHCAT_PERIOD`   | Ping interval                       | `1m`         |
| `NETWORK_01_WATCHCAT_FAILURES` | Consecutive failures before reboot  | `3`          |
| `NETWORK_01_WATCHCAT_DELAY`    | Seconds before reboot after failure | `15`         |

Default: OFF. Must explicitly set `WATCHCAT=true`.

```yaml
# Monitor MEAT gateway — ping every minute, reboot after 3 failures
- NETWORK_02_WATCHCAT=true

# Monitor IOT gateway — ping every 30s, reboot after 5 failures
- NETWORK_03_WATCHCAT=true
- NETWORK_03_WATCHCAT_PERIOD=30s
- NETWORK_03_WATCHCAT_FAILURES=5

# Ping a specific host instead of the gateway
- NETWORK_05_WATCHCAT=true
- NETWORK_05_WATCHCAT_HOSTS=10.60.137.50
```

### Client Isolation (ebtables)

Opt-in per VLAN. When enabled, clients on the same VLAN can only reach the gateway and any allowlisted IPs.

| Variable                                              | Description                                                                       |
| ----------------------------------------------------- | --------------------------------------------------------------------------------- |
| `NETWORK_01_EB_ENABLED=true`                          | Enable isolation on this VLAN                                                     |
| `NETWORK_01_EB_ALLOW=10.60.230.50,10.60.230.100:9100` | Comma-separated allowlist — clients can reach these IPs (IP or IP:port)           |
| `NETWORK_01_EB_ALLOW_SRC=10.60.230.100`               | Comma-separated source allowlist — these clients bypass isolation (IP or IP:port) |

Default: isolation OFF. Must explicitly set `EB_ENABLED=true`.

```yaml
# Full isolation — only gateway access
- NETWORK_03_EB_ENABLED=true

# Isolation with printer exception (port 9100)
- NETWORK_01_EB_ENABLED=true
- NETWORK_01_EB_ALLOW=10.60.230.50:9100

# Isolation with server subnet exception
- NETWORK_02_EB_ENABLED=true
- NETWORK_02_EB_ALLOW=10.60.23.0/24

# Specific client bypasses isolation entirely
- NETWORK_03_EB_ENABLED=true
- NETWORK_03_EB_ALLOW_SRC=10.68.0.23
```

### Live Tools (on the device)

| Command                     | Description                                                                      |
| --------------------------- | -------------------------------------------------------------------------------- |
| `restart-network [secs]`    | Safely apply network — rollback if no confirmation within timeout (default 230s) |
| `restart-network --confirm` | Apply immediately, no rollback                                                   |
| `restart-network --revert`  | Revert to last backup                                                            |
| `restart-network --list`    | List backups in `/root/config.backup/`                                           |
| `apply-ebtables`            | Apply rules from `/etc/ebtables.d/*.conf`                                        |
| `apply-ebtables --show`     | Preview what would be applied                                                    |
| `apply-ebtables --status`   | Show current ebtables rules                                                      |
| `status`                    | Dashboard — interfaces, SSIDs with radio stats, watchcat per VLAN, client count  |
| `help`                      | Compact cheatsheet of all commands                                               |

### Other

| Variable              | Description                                                  |
| --------------------- | ------------------------------------------------------------ |
| `ROOT_PASSWORD`       | Root password baked into the firmware                        |
| `OPENWRT_VERSION`     | OpenWRT release (default 25.12.5)                            |
| `OPENWRT_CHIPSET`     | Target chipsets (default `ipq40xx:generic,mediatek/filogic`) |
| `OPENWRT_MIRROR`      | Package mirror (default `https://downloads.openwrt.org`)     |
| `DAWN_BROADCAST_IP`   | Dawn broadcast IP (default `255.255.255.255`)                |
| `DAWN_BROADCAST_PORT` | Dawn broadcast UDP port (default `1025`)                     |
| `DAWN_SHARED_KEY`     | Dawn cluster shared key (default built-in)                   |
| `DAWN_IV`             | Dawn cluster initialization vector (default built-in)        |
| `DAWN_USE_SYMM_ENC`   | Enable Dawn symmetric encryption (`1` or `0`, default `0`)   |
| `AP_OCTET_BASE`       | Base octet for IP calculation — `ap1` → `.11` (default `10`) |

## What gets provisioned on first boot (Cudy models only)

- WAN port renamed to LAN, set to DHCP (main router assigns IP)
- Services disabled at build time: dnsmasq, odhcpd, firewall
- IPv6 packages removed (`-odhcpd-ipv6only -odhcp6c -luci-proto-ipv6 -ppp*`)
- `/etc/config/firewall` and `/etc/config/dhcp` cleaned up
- LuCI firewall/DHCP menu entries removed
- Timezone America/Vancouver, LuCI 24h clock, English
- Root password from `ROOT_PASSWORD` env var
- VLAN interfaces (DHCP or static per env)
- WiFi radios enabled, channels/txpower set
- SSIDs per env var config
- Dawn roaming daemon started
- Bridge VLAN filtering: WiFi BSS traffic tagged to correct VLAN on uplink
- ebtables client isolation rules (opt-in per VLAN)

Asus and Wavlink models get the package set and disabled services at build time but do not run a first-boot provisioning script.

## Support & Maintenance

- For community help, tips, and community discussions, visit the [Discussions board](../../discussions).
- For personalized support or a support agreement, see [Nfrastack Support](https://nfrastack.com/).
- To report bugs, submit a [Bug Report](issues/new). Usage questions may be closed as not-a-bug.
- Feature requests are welcome, but not guaranteed. For prioritized development, consider a support agreement.
- Updates are best-effort, with priority given to active production use and support agreements.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
