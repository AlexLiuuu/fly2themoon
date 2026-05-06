# fly2themoon

Find the best Vultr region for your current network by testing latency, packet loss, and download speed. One script, zero dependencies.

快速测试当前网络下最适合的 Vultr 节点：延迟、丢包、下载速度一键对比。单脚本，零依赖。

---

## Quick Start / 快速开始

```bash
git clone https://github.com/YOUR_USERNAME/fly2themoon.git
cd fly2themoon
chmod +x fly2themoon.sh
./fly2themoon.sh
```

## Usage / 使用方法

```
fly2themoon.sh [OPTIONS]
```

| Option | Description | 说明 | Default |
|--------|-------------|------|---------|
| `-c, --count N` | Number of pings per host | 每个节点 ping 次数 | `20` |
| `-d, --download` | Run download speed test on top results | 对排名靠前的节点做下载测速 | off |
| `-n, --top N` | How many top hosts to speed-test | 下载测速取前 N 个 | `5` |
| `-o, --output FILE` | Save results to CSV file | 保存结果到 CSV 文件 | — |
| `-h, --help` | Show help | 显示帮助 | — |

## Data Centers / 测试节点 (33)

**Asia Pacific / 亚太**: Tokyo, Osaka, Singapore, Seoul, Bangalore, Delhi, Mumbai, Sydney, Melbourne
**North America / 北美**: Los Angeles, Silicon Valley, Seattle, Honolulu, Chicago, Atlanta, Miami, New Jersey, Dallas, Toronto, Mexico City
**South America / 南美**: Sao Paulo, Santiago
**Europe / 欧洲**: London, Manchester, Paris, Frankfurt, Amsterdam, Warsaw, Madrid, Stockholm, Bucharest
**Middle East & Africa / 中东非洲**: Tel Aviv, Johannesburg

## Examples / 示例

```bash
# Test all 33 data centers / 测试全部 33 个节点
./fly2themoon.sh

# 5 pings each (faster) / 每个 ping 5 次（更快）
./fly2themoon.sh -c 5

# Include download speed test for top 3 / 对前 3 名做下载测速
./fly2themoon.sh -d -n 3

# Save results to CSV / 保存结果到 CSV
./fly2themoon.sh -o results.csv
```

## Sample Output / 输出示例

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

## How It Works / 工作原理

1. **Parallel ping / 并行 ping** — All data centers are pinged simultaneously for speed. 所有节点同时 ping，速度快。
2. **Cross-platform / 跨平台** — Works on both macOS and Linux (handles different ping output formats). 同时支持 macOS 和 Linux。
3. **Smart ranking / 智能排序** — Results sorted by average latency; unreachable hosts (100% loss) are placed at the bottom. 按平均延迟排序，不可达的排最后。
4. **Color-coded / 彩色输出** — Green (<50ms), Yellow (50-150ms), Red (>150ms), Gray (timeout). 绿色（<50ms），黄色（50-150ms），红色（>150ms），灰色（超时）。
5. **Optional speed test / 可选测速** — Download test uses Vultr's 100MB test file, runs sequentially to avoid bandwidth contention. 下载测速使用 Vultr 官方 100MB 测试文件，串行执行保证准确。

## Requirements / 环境要求

- Bash 3.2+（macOS 自带即可）
- `ping`（macOS/Linux 预装）
- `curl`（仅 `-d` 下载测速时需要）

## Notes / 注意事项

- Some networks or firewalls may block ICMP (ping) — affected hosts will show as `---` and sort to the bottom.
  部分网络或防火墙可能屏蔽 ICMP，受影响的节点会显示 `---` 并排到最后。
- In mainland China, some Vultr IP ranges may be blocked. If a newly created instance is unreachable, try destroying and recreating to get a new IP, or try a different region.
  在中国大陆，部分 Vultr IP 段可能被封锁。如果新建实例无法连接，可以销毁重建获取新 IP，或尝试其他区域。
- Colors are auto-disabled when piping output to a file.
  输出重定向到文件时自动禁用颜色。

## Build Your Own VPN on Vultr / 在 Vultr 上自建梯子

After finding the best region with this tool, you can set up your own proxy server on Vultr.
用本工具找到最佳节点后，可以在 Vultr 上自建代理服务器。

Refer to this guide / 参考教程：
[自建 v2ray 服务器教程](https://github.com/Alvin9999-newpac/fanqiang/blob/main/%E8%87%AA%E5%BB%BAv2ray%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B.md)

## License

MIT
