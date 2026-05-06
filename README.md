# fly2themoon

[English](README.md) | [中文](README_CN.md)

Find the best Vultr region for your current network by testing latency, packet loss, and download speed. One script, zero dependencies.

## Quick Start

```bash
git clone https://github.com/YOUR_USERNAME/fly2themoon.git
cd fly2themoon
chmod +x fly2themoon.sh
./fly2themoon.sh
```

## Usage

```
fly2themoon.sh [OPTIONS]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-c, --count N` | Number of pings per host | `20` |
| `-d, --download` | Run download speed test on top results | off |
| `-n, --top N` | How many top hosts to speed-test | `5` |
| `-o, --output FILE` | Save results to CSV file | — |
| `-h, --help` | Show help | — |

## Data Centers (33)

| Region | Locations |
|--------|-----------|
| Asia Pacific (9) | Tokyo, Osaka, Singapore, Seoul, Bangalore, Delhi, Mumbai, Sydney, Melbourne |
| North America (11) | Los Angeles, Silicon Valley, Seattle, Honolulu, Chicago, Atlanta, Miami, New Jersey, Dallas, Toronto, Mexico City |
| South America (2) | Sao Paulo, Santiago |
| Europe (9) | London, Manchester, Paris, Frankfurt, Amsterdam, Warsaw, Madrid, Stockholm, Bucharest |
| Middle East & Africa (2) | Tel Aviv, Johannesburg |

## Examples

```bash
./fly2themoon.sh              # Test all 33 data centers
./fly2themoon.sh -c 5         # 5 pings each (faster)
./fly2themoon.sh -d -n 3      # Include download speed test for top 3
./fly2themoon.sh -o result.csv # Save results to CSV
```

## Sample Output

```
  fly2themoon - Vultr Latency Test
  2026-05-06 17:30 | 33 DCs | Pings: 20

  #    Location           Avg(ms)  Min(ms)  Max(ms)   Loss
  ---  ------------------ -------  -------  -------  -----
  1    Singapore             81.4     79.7     84.7   0.0%
  2    Silicon Valley       163.3    163.3    163.3  66.7%
  3    Los Angeles          180.5    180.1    181.0   0.0%
  4    Delhi NCR            200.3    200.3    200.4  33.3%
  5    Seoul                205.9    205.7    206.2  33.3%
  ...
```

## How It Works

1. **Parallel ping** — All data centers are pinged simultaneously for speed.
2. **Cross-platform** — Works on both macOS and Linux.
3. **Smart ranking** — Sorted by average latency; unreachable hosts placed at bottom.
4. **Color-coded** — Green (<50ms), Yellow (50-150ms), Red (>150ms), Gray (timeout).
5. **Optional speed test** — Download test uses Vultr's 100MB test file.

## Requirements

- Bash 3.2+ (macOS default works)
- `ping` (pre-installed on macOS/Linux)
- `curl` (only needed for `-d` download speed test)

## Notes

- Some networks or firewalls may block ICMP (ping) — affected hosts will show as `---` and sort to the bottom.
- In mainland China, some Vultr IP ranges may be blocked. If a newly created instance is unreachable, try destroying and recreating to get a new IP, or try a different region.
- Colors are auto-disabled when piping output to a file.

## Build Your Own VPN on Vultr

After finding the best region with this tool, you can set up your own proxy server on Vultr. See this guide:
[v2ray server setup tutorial](https://github.com/Alvin9999-newpac/fanqiang/blob/main/%E8%87%AA%E5%BB%BAv2ray%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B.md)

## License

MIT
