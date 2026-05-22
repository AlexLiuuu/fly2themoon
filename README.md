# fly2themoon

[English](README.md) | [中文](README_CN.md)

Find the best Vultr region for your network. Runs 3 rounds by default, ranks by median score, and filters out transient GFW interference. One script, zero dependencies.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/AlexLiuuu/fly2themoon/main/vultr-speed-test.sh | bash
```

## Usage

```
vultr-speed-test.sh [OPTIONS]
```

| Option | Description | Default |
|--------|-------------|---------|
| `-c, --count N` | Number of pings per host | `50` |
| `-R, --rounds N` | Test rounds (median across rounds) | `3` |
| `-r, --region REGIONS` | Filter regions: ap,na,sa,eu,me | all |
| `-v, --verbose` | Show TCP connect and TLS handshake times | off |
| `-j, --jobs N` | Max parallel jobs (0 = unlimited) | `0` |
| `-d, --download` | Run download speed test on top results | off |
| `-n, --top N` | How many top hosts to speed-test | `5` |
| `-o, --output FILE` | Save results to CSV | — |
| `-h, --help` | Show help | — |

## Examples

```bash
./vultr-speed-test.sh                # 3 rounds, all 33 regions
./vultr-speed-test.sh -R 1           # Single round (quick test)
./vultr-speed-test.sh -r ap,na       # Only Asia Pacific + North America
./vultr-speed-test.sh -v             # Show TCP/TLS breakdown
./vultr-speed-test.sh -d -n 3        # Download test for top 3
./vultr-speed-test.sh -o result.csv  # Save to CSV
```

## Sample Output

```
  fly2themoon - Vultr Speed Test
  2026-05-23 01:49 | 33 DCs | 3 rounds x 5 pings

  #    Location           Score   Stab  Ping(ms)   Loss  TTFB(ms)
  ---  ------------------ -----  -----  --------  -----  --------
  1    Los Angeles           86   ±11   176.713   0.0%     657.3
  2    Dallas                83    ±5   200.167   0.0%     748.1
  3    New Jersey            82    ±2   231.989   0.0%     762.8
  4    Silicon Valley        76   ±34   160.688   0.0%     629.9
  5    Tokyo                 28   ±43   150.515  20.0%    2821.7
  ...

  Recommended: Los Angeles (86, ±11), Dallas (83, ±5), New Jersey (82, ±2)

  Score = 20% ping + 35% loss + 30% TTFB + 15% jitter (median of 3 rounds)
  Stab = score range across rounds (lower = more consistent)
```

**Stab (stability)** is the key column — a high score with ±30+ means the node is unreliable. Pick nodes with high score AND low Stab.

## Scoring

| Metric | Weight | Why |
|--------|--------|-----|
| Packet loss | 35% | Quadratic penalty — loss kills proxy experience |
| HTTPS TTFB | 30% | Time to first byte, closest to real browsing |
| Ping latency | 20% | Baseline network quality |
| Jitter | 15% | Latency variance, affects video streaming |

Multi-round testing uses median scores to filter out random GFW interference.

## Data Centers (33)

| Region | Locations |
|--------|-----------|
| Asia Pacific (9) | Tokyo, Osaka, Singapore, Seoul, Bangalore, Delhi, Mumbai, Sydney, Melbourne |
| North America (11) | Los Angeles, Silicon Valley, Seattle, Honolulu, Chicago, Atlanta, Miami, New Jersey, Dallas, Toronto, Mexico City |
| South America (2) | Sao Paulo, Santiago |
| Europe (9) | London, Manchester, Paris, Frankfurt, Amsterdam, Warsaw, Madrid, Stockholm, Milan |
| Middle East & Africa (2) | Tel Aviv, Johannesburg |

## Notes

- Some networks or firewalls may block ICMP (ping) — affected hosts show as `---` and sort to the bottom.
- In mainland China, some Vultr IP ranges may be blocked. If a new instance is unreachable, destroy and recreate to get a new IP, or try a different region.
- Colors are auto-disabled when piping output to a file.

## Build Your Own VPN on Vultr

After finding the best region with this tool, set up your own proxy server on Vultr:

[v2ray server setup tutorial](https://github.com/Alvin9999-newpac/fanqiang/blob/main/%E8%87%AA%E5%BB%BAv2ray%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B.md)

## License

MIT
