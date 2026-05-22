# fly2themoon

[English](README.md) | [中文](README_CN.md)

快速找到最适合你的 Vultr 节点。默认跑 3 轮测试，用中位数排名，过滤掉 GFW 造成的随机波动。单脚本，零依赖。

## 快速开始

```bash
curl -fsSL https://raw.githubusercontent.com/AlexLiuuu/fly2themoon/main/vultr-speed-test.sh | bash
```

## 使用方法

```
vultr-speed-test.sh [选项]
```

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-c, --count N` | 每个节点 ping 次数 | `50` |
| `-R, --rounds N` | 测试轮数（多轮取中位数） | `3` |
| `-r, --region REGIONS` | 只测指定区域：ap,na,sa,eu,me | 全部 |
| `-v, --verbose` | 显示 TCP/TLS 详细耗时 | 关 |
| `-j, --jobs N` | 最大并发数（0=不限） | `0` |
| `-d, --download` | 对排名靠前的节点做下载测速 | 关 |
| `-n, --top N` | 下载测速取前 N 个 | `5` |
| `-o, --output FILE` | 保存结果到 CSV | — |
| `-h, --help` | 显示帮助 | — |

## 示例

```bash
./vultr-speed-test.sh                # 3 轮测试，全部 33 个节点
./vultr-speed-test.sh -R 1           # 单轮快测
./vultr-speed-test.sh -r ap,na       # 只测亚太+北美
./vultr-speed-test.sh -v             # 显示 TCP/TLS 详情
./vultr-speed-test.sh -d -n 3        # 对前 3 名做下载测速
./vultr-speed-test.sh -o result.csv  # 保存 CSV
```

## 输出示例

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

**Stab（稳定性）** 是关键指标 — 分数高但 ±30+ 的节点不可靠，实际使用时好时坏。优先选分数高且 Stab 低的节点。

## 评分公式

| 指标 | 权重 | 说明 |
|------|------|------|
| 丢包率 | 35% | 二次惩罚，丢包对代理体验伤害最大 |
| HTTPS TTFB | 30% | 首包时间，最接近真实浏览体验 |
| Ping 延迟 | 20% | 基础网络质量 |
| 抖动 (Jitter) | 15% | 延迟波动，影响视频流畅度 |

多轮测试取中位数排名，过滤 GFW 造成的随机干扰。

## 测试节点 (33 个)

| 区域 | 节点 |
|------|------|
| 亚太 (9) | 东京、大阪、新加坡、首尔、班加罗尔、德里、孟买、悉尼、墨尔本 |
| 北美 (11) | 洛杉矶、硅谷、西雅图、檀香山、芝加哥、亚特兰大、迈阿密、新泽西、达拉斯、多伦多、墨西哥城 |
| 南美 (2) | 圣保罗、圣地亚哥 |
| 欧洲 (9) | 伦敦、曼彻斯特、巴黎、法兰克福、阿姆斯特丹、华沙、马德里、斯德哥尔摩、米兰 |
| 中东/非洲 (2) | 特拉维夫、约翰内斯堡 |

## 注意事项

- 部分网络或防火墙可能屏蔽 ICMP（ping），受影响的节点显示 `---` 并排到最后
- 在中国大陆，部分 Vultr IP 段可能被封锁。新建实例无法连接时，可销毁重建获取新 IP，或换区域
- 输出重定向到文件时自动禁用颜色

## 在 Vultr 上自建梯子

用本工具找到最佳节点后，可以在 Vultr 上自建代理服务器。参考教程：

[自建 v2ray 服务器教程](https://github.com/Alvin9999-newpac/fanqiang/blob/main/%E8%87%AA%E5%BB%BAv2ray%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B.md)

## License

MIT
