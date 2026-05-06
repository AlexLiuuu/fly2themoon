# fly2themoon

[English](README.md) | [中文](README_CN.md)

快速测试当前网络下最适合的 Vultr 节点：延迟、丢包、下载速度一键对比。单脚本，零依赖。

## 快速开始

```bash
git clone https://github.com/YOUR_USERNAME/fly2themoon.git
cd fly2themoon
chmod +x fly2themoon.sh
./fly2themoon.sh
```

## 使用方法

```
fly2themoon.sh [选项]
```

| 选项 | 说明 | 默认值 |
|------|------|--------|
| `-c, --count N` | 每个节点 ping 次数 | `20` |
| `-d, --download` | 对排名靠前的节点做下载测速 | 关 |
| `-n, --top N` | 下载测速取前 N 个 | `5` |
| `-o, --output FILE` | 保存结果到 CSV 文件 | — |
| `-h, --help` | 显示帮助 | — |

## 测试节点 (33 个)

| 区域 | 节点 |
|------|------|
| 亚太 (9) | 东京、大阪、新加坡、首尔、班加罗尔、德里、孟买、悉尼、墨尔本 |
| 北美 (11) | 洛杉矶、硅谷、西雅图、檀香山、芝加哥、亚特兰大、迈阿密、新泽西、达拉斯、多伦多、墨西哥城 |
| 南美 (2) | 圣保罗、圣地亚哥 |
| 欧洲 (9) | 伦敦、曼彻斯特、巴黎、法兰克福、阿姆斯特丹、华沙、马德里、斯德哥尔摩、布加勒斯特 |
| 中东/非洲 (2) | 特拉维夫、约翰内斯堡 |

## 示例

```bash
./fly2themoon.sh              # 测试全部 33 个节点
./fly2themoon.sh -c 5         # 每个 ping 5 次（更快）
./fly2themoon.sh -d -n 3      # 对前 3 名做下载测速
./fly2themoon.sh -o result.csv # 保存结果到 CSV
```

## 输出示例

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

## 工作原理

1. **并行 ping** — 所有节点同时 ping，速度快
2. **跨平台** — 同时支持 macOS 和 Linux（自动适配不同 ping 输出格式）
3. **智能排序** — 按平均延迟排序，不可达的节点排到最后
4. **彩色输出** — 绿色（<50ms）、黄色（50-150ms）、红色（>150ms）、灰色（超时）
5. **可选测速** — 使用 Vultr 官方 100MB 测试文件，串行执行保证准确

## 环境要求

- Bash 3.2+（macOS 自带即可）
- `ping`（macOS/Linux 预装）
- `curl`（仅 `-d` 下载测速时需要）

## 注意事项

- 部分网络或防火墙可能屏蔽 ICMP（ping），受影响的节点会显示 `---` 并排到最后
- 在中国大陆，部分 Vultr IP 段可能被封锁。如果新建实例无法连接，可以销毁重建获取新 IP，或尝试其他区域
- 输出重定向到文件时自动禁用颜色

## 在 Vultr 上自建梯子

用本工具找到最佳节点后，可以在 Vultr 上自建代理服务器。参考教程：

[自建 v2ray 服务器教程](https://github.com/Alvin9999-newpac/fanqiang/blob/main/%E8%87%AA%E5%BB%BAv2ray%E6%9C%8D%E5%8A%A1%E5%99%A8%E6%95%99%E7%A8%8B.md)

## License

MIT
