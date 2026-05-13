# fly2themoon

[中文](README.md) | [English](README_EN.md)

Find the best Vultr region for your current network by testing latency, packet loss, and HTTPS timing. Ranked by a weighted score. One script, zero dependencies.

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
./vultr-speed-test.sh              # Test all 33 data centers
./vultr-speed-test.sh -c 5         # 5 pings each (faster)
./vultr-speed-test.sh -d -n 3      # Include download speed test for top 3
./vultr-speed-test.sh -o result.csv # Save results to CSV
```

## Sample Output

```
  fly2themoon - Vultr Speed Test
  2026-05-12 21:48 | 33 DCs | Pings: 5

  #    Location           Score  Ping(ms)   Loss  TTFB(ms)
  ---  ------------------ -----  --------  -----  --------
  1    Delhi NCR             71   142.659   0.0%     551.1
  2    Atlanta               55   278.087   0.0%     731.9
  3    Silicon Valley        48   170.187   0.0%    1109.0
  4    Dallas                45   208.180   0.0%    1191.1
  5    Honolulu              43   233.663   0.0%    1099.6
  ...

  Score = 35% ping + 30% loss + 35% HTTPS TTFB (higher is better)
```

## Scoring

The script runs two rounds of tests per node:

1. **ICMP Ping** — measures latency and packet loss
2. **HTTPS Timing** — measures TCP connect, TLS handshake, and Time to First Byte (TTFB)

Weighted scoring formula:

| Metric | Weight | Why |
|--------|--------|-----|
| Ping latency | 35% | Baseline network quality |
| Packet loss | 30% | Loss is the biggest killer for proxy experience |
| HTTPS TTFB | 35% | Closest to real-world browsing experience |

Higher score = better. Nodes where HTTPS fails are penalized.

## Notes

- Some networks or firewalls may block ICMP (ping) — affected hosts will show as `---` and sort to the bottom.
- In mainland China, some Vultr IP ranges may be blocked. If a newly created instance is unreachable, try destroying and recreating to get a new IP, or try a different region.
- Colors are auto-disabled when piping output to a file.

## Build Your Own VPN on Vultr

After finding the best region with this tool, you can set up your own proxy server on Vultr. See this guide:
[v2ray server setup tutorial](https://github.com/Alvin9999-newpac/fanqiang/blob/main/%E8%87%AA%E5%BB%BAv2ray%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B.md)

## License

MIT
