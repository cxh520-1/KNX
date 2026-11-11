# KNX

楼宇总线协议栈，用 MoonBit 写成。它不替你连网关，而是把 KNX 的报文、数据点和网关链路做成可直接编进程序的库：拿到字节就能解，给出值就能编码。

当前版本尚未发布到 mooncakes，接入方式是仓库源码或路径依赖。

![demo](docs/demo.gif)

```text
BC 11 01 11 01 81 00 81 BC
│  │     │     │  │  └── TPDU：GroupWrite，值 true
│  │     │     │  └───── NPCI：组地址，长度 2 字节
│  │     │     └──────── 目的组地址 2/1/1
│  │     └────────────── 源地址 1.1.1
│  └──────────────────── 控制字节
```

这条帧由 `moon run cmd -- demo` 真实打印，不是示意。

## 它补的是什么

KNX 是楼宇自动化的通用语言，但 MoonBit 生态里没有它的实现。这个仓库补的是协议底座：FT1.2 串口帧、TP1 标准帧与扩展帧、组服务、数据点、设备模型、cEMI、KNX/IP 隧道与客户端状态机。做网关、做调试工具、做一致性测试的人，可以按需取其中一层，不必绑厂商 SDK。

## 五分钟跑通

```bash
moon run cmd -- demo
moon run cmd -- decode "BC 11 01 11 01 81 00 81 BC"
moon run cmd -- tunnel
moon run cmd -- mon "061004200015040100001100BC8011011101810081"
moon run cmd -- search
moon run cmd -- device
moon run cmd -- plan
```

`demo` 走完一条完整链路：三台设备的总线交互 → 五条真实帧 → 同一帧包成 cEMI 与 KNX/IP 隧道请求 → 监控器解释成一行。`plan` 解析样例工程表，`search` 与 `device` 打印发现和设备管理帧。

## 包的划分

```
lib/addrmodel   个体地址与组地址
lib/busframe    FT1.2 串口帧
lib/telegram    TP1 标准帧、扩展帧与组服务
lib/datapoint   DPT 编解码与缩放
lib/device      组对象与读写行为
lib/net         虚拟总线、轨迹与统计
lib/cemi        cEMI L_Data 与 TP1 互转
lib/knxip       KNX/IP 头、发现、隧道、路由、设备管理
lib/gateway     隧道客户端状态机
lib/project     组地址 ↔ DPT 工程表
lib/trace       帧解释与抓包渲染
cmd             命令行
```

依赖单向：`telegram` 只认 `addrmodel`，`device` 不认总线，`net` 把设备接起来，`cmd` 只做输入输出。任何一层都能单独引用。

## 协议范围

| 层 | 内容 | 状态 |
|---|---|---|
| 地址 | 个体地址 `1.2.3`、组地址 `1/2/3` | 可用 |
| 报文 | TP1 标准帧与扩展帧（TPDU > 16 字节自动切换） | 可用 |
| 服务 | GroupRead / GroupWrite / GroupResponse | 可用 |
| 串口 | FT1.2 `68 L L 68 … 16` / `10 … 16` / `E5`，算术和校验，FCB/FCV | 可用 |
| 数据点 | DPT-1/5/6/7/8/9/10/11/12/13/14/16/17，含百分比与场景 | 可用 |
| 设备与总线 | 组对象、写更新、读应答、广播、按组统计 | 可用 |
| 网关载荷 | cEMI `L_Data.req/ind/con` | 可用 |
| KNX/IP | SEARCH/DESCRIPTION/CONNECT/TUNNELLING/ROUTING/设备管理/DISCONNECT | 可用 |
| 客户端 | 连接、序号、Ack、重发、入站应答、断开 | 可用 |
| 工程表 | 解析、重复检测、合并、反写、按 DPT 统计 | 可用 |
| 监控 | 单帧解释、抓包逐帧渲染 | 可用 |
| 安全 | KNX Secure | 未实现 |

未实现的部分在文档里标为缺失，不用占位实现冒充。

## 几处实现取舍

**FT1.2 只做字符级帧规程。** 变长帧 `68 L L 68 … 16` 承载 SEND_UDAT，定长帧 `10 … 16` 用于 SEND_RESET，确认用单字节 `E5`；校验是控制字段加数据字节的 8 位算术和（模 256），FCB 逐帧翻转抑制重复。这条规则只放在 `busframe`，其他层只看到报文。

**短值内联。** 组服务的低六位可以携带 0..63 的小值，也可以表示后续字节数；一条布尔写入因此只有两个字节的 TPDU。

**2 字节浮点按规则算。** DPT-9 是「1 位符号 + 4 位指数 + 11 位尾数」，值等于 `0.01 × 尾数 × 2^指数`。21.0 °C 必须用指数 1 才装得下，编码是 `0C 1A`，不是把两个字节当整数。

**长报文换布局。** TPDU 超过 16 字节时控制字节 bit7 清零，多一个控制字节，长度占满一字节；解码入口按这个位分派，调用方仍只看到一种 `Telegram`。

## 边界与未实现

- 只做报文与设备模型，不做电气层，不做总线仲裁时序。
- KNX Secure、ETS 工程导入未实现；组地址由调用方配置。
- native 目标需要系统 C 编译器，当前环境未安装；wasm-gc 可正常构建。

细节见 [`docs/architecture.md`](docs/architecture.md)、[`docs/protocol.md`](docs/protocol.md) 与 [`docs/proposal.md`](docs/proposal.md)。

## 构建与测试

```bash
moon check --deny-warn
moon test --deny-warn     # 99 个用例
moon fmt --check
moon build --target wasm
```

CI 在每次推送时跑 `moon check`、`moon test` 与 wasm 构建。测试覆盖地址越界、标准/扩展帧往返、校验失败、FT1.2 帧校验与 FCB 翻转、13 种 DPT 的字面编码、设备读写、总线统计、cEMI 互转、KNX/IP 各服务字段与客户端状态机。

## 许可证

Apache-2.0，见 `LICENSE`。协议字段依据 KNX 公开标准（ISO/IEC 14543-3）与公开资料核对，代码为自写，无第三方代码。
