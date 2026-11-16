# KNX 项目申报书（仓库版）

**许可证：** Apache-2.0
**说明：** 本文件是提交版申报书的仓库副本，已去掉个人联系方式；提交以正式申报表为准。

## 基本信息

- 项目名称：KNX：楼宇总线协议栈的 MoonBit 实现
- GitHub 仓库链接：https://github.com/cxh520-1/KNX.git
- 项目方向：MoonBit 楼宇自动化协议库 / 网关与调试工具基础设施
- 是否为移植项目：否，原创项目

## 项目简介

KNX 用 MoonBit 实现楼宇总线协议链路，覆盖从串口帧到 IP 网关的完整路径：FT1.2 串口帧（PEI16/RS-232 物理外部接口）、TP1 标准帧与扩展帧、组服务、数据点编解码、设备与虚拟总线、cEMI、KNX/IP 隧道以及客户端状态机。项目面向需要在 MoonBit 中接入或模拟 KNX 的库作者、网关开发者和调试工具作者，提供可直接组合的协议层，而不是绑定某一家网关厂商的 SDK。当前版本 MoonBit 源码 4676 行（含 1367 行测试；有效代码 3309 行），103 项测试通过，CI 每次推送执行 check、test 与 wasm 构建。

## 使用场景

- 楼宇网关：从串口收到 `68 0A 0A 68 73 BC 11 01 11 01 81 00 81 BC 11 16`，解出 FT1.2 报文 `BC 11 01 11 01 81 00 81 BC`，再解出源 1.1.1、组 2/1/1、GroupWrite、值 true，经 cEMI 与 KNX/IP 隧道转发给平台，平台侧用同一库还原。
- 现场调试：抓包后用 `knx mon` 直接得到 `TUNNELLING_REQUEST channel=1 seq=0 L_Data 2/1/1 (group) GroupWrite value=1`；工程表交给 `project` 校验重复组地址和未知 DPT。
- 一致性测试：用 `net` 挂载虚拟设备、用 `gateway` 模拟隧道客户端，在 CI 中跑标准帧、扩展帧、长 TPDU、FT1.2 校验错误与 Ack 重发的字节级向量。

## 核心功能范围

- 提供个体地址与组地址模型，字段宽度不同，越界在构造时失败；
- 提供 FT1.2 串口帧编解码：变长 SEND_UDAT 帧 `68 L L 68 … 16`（主站→从站）与 RESPOND_UDAT 帧（从站→主站）、定长 SEND_RESET `10 40 40 16` 与 REQ_STATUS `10 49 49 16`、单字节 ACK `E5`，8 位算术和校验、FCB/FCV 与 DIR/PRM 控制字段，字节与真实 KNX 串口（PEI16/RS-232）一致；
- 提供 TP1 标准帧与扩展帧，覆盖控制字段、源/目的地址、NPCI、XOR 校验，TPDU 超过 16 字节自动切换布局；
- 提供 GroupRead、GroupWrite、GroupResponse 三种组服务，支持短值内联与长值带长度；
- 提供 DPT-1/5/6/7/8/9/10/11/12/13/14/16/17 编解码，以及 DPT-5.004 百分比与 DPT-17 场景子类型；
- 提供组对象表与设备行为，支持写入更新、读取应答、未知组忽略；
- 提供虚拟总线，支持写广播、读收集应答、活动轨迹与按组统计；
- 提供 cEMI `L_Data.req/ind/con` 编解码，并与 TP1 报文互转；
- 提供 KNX/IP 头与 SEARCH、DESCRIPTION、CONNECT、TUNNELLING、ROUTING、设备管理、DISCONNECT 服务；
- 提供隧道客户端状态机，管理通道号、序号、Ack、重发、入站自动应答与断开；
- 提供组地址工程表的解析、重复检测、合并、反写与按 DPT 统计；
- 提供单帧解释与抓包逐帧渲染的监控模块；
- 提供 CLI，包含 `decode`、`demo`、`frames`、`cemi`、`tunnel`、`search`、`device`、`plan`、`desc`、`mon`；
- 提供 103 个 MoonBit 测试与 GitHub Actions，覆盖字面字节、双向往返和错误路径；
- 提供 README 与 `docs/` 示例，覆盖总线演示、隧道组帧和监控输出。

## 标准互操作机制

FT1.2 这一层不是自造的封装，而是按 KNX 物理外部接口（PEI16/RS-232）的既有约定实现，目标是能和真实设备在字节上互通：

- **链路形态**：点对点 RS-232 串口，FT1.2 模式线参数为 19200 bit/s、8 数据位、偶校验、1 停止位（8E1），区别于旧 PEI16 模式的 9600 8N1 加 RTS/CTS 硬件流控；库为 sans-IO，只产/消字节，线参数由调用方在打开 UART 时配置，因此同一套帧可直接连 PEI16 耦合器（BCU2）或 EMI 串口网关。
- **帧结构**（IEC 870-5-1 FT1.2 字符规程）：变长帧 `68 L L 68 C [数据] CS 16`、定长帧 `10 C [数据] CS 16`、单字节确认 `E5`；`CS` 为控制字段与数据字节的 8 位算术和（模 256）。
- **控制字段**：`DIR|PRM|FCB|FCV|功能码(4 位)`。主站发送 SEND_UDAT 功能码 0x3、FCV=1，FCB 每条新报文翻转（复位后首帧为 1），用于抑制报文丢失/重复；SEND_RESET 功能码 0x0。从站以 `E5` 确认。
- **握手与收发**：上电先 `reset()` 发 `10 40 40 16` → 对方回 `E5` → 以 `wrap(telegram, fcb)` 发 SEND_UDAT（主站→从站），FCB 逐帧翻转；从站侧数据用 `respond_udat(telegram)` 以 RESPOND_UDAT 帧回传，主站以 `req_status()` 发 `10 49 49 16` 轮询。`unwrap(frame)` 同时接受 SEND_UDAT 与 RESPOND_UDAT，校验定界、长度与算术和，错误时报 `BadStart/BadEnd/BadLength/BadChecksum`，非数据帧报 `NotUserData`。
- **上层衔接**：FT1.2 的 SEND_UDAT 承载的是完整 TP1 报文（控制/源/目的/NPCI/TPDU/XOR 校验），剥离后与 `telegram`、`cemi`（L_Data.req/ind/con）、`knxip`（TUNNELLING/ROUTING）逐层互通，链路全程字节级可验证；EMI 应用消息层（EMI1/EMI2 的设备管理消息语义）不在本库承载范围内，见下方「最终标准符合性目标」。

## 最终标准符合性目标

本库在字节层面符合下列标准的公开部分，符合范围逐层列明；未列出的部分不在本项目范围内，且在 `docs/protocol.md` 中标为「未实现」。

| 协议层 | 符合的标准 | 本库实现并测试的范围 |
|---|---|---|
| FT1.2 串口数据链路 | IEC 870-5-1 子集，经 KNX 系统规范 Volume 3/3「物理外部接口（PEI16/RS-232）」采用 | 变长 SEND_UDAT `68 L L 68 … 16`、变长 RESPOND_UDAT、定长 SEND_RESET `10 40 40 16`、定长 REQ_STATUS `10 49 49 16`、单字节 ACK `E5`、8 位算术和校验（模 256）、DIR/PRM/FCB/FCV 控制字段；线参数 19200 bit/s、8 数据位、偶校验、1 停止位（8E1） |
| TP1 数据链路帧 | ISO/IEC 14543-3-2 | 标准帧与扩展帧、控制字节校验 `(ctrl & 0x53) == 0x10`、源/目的地址、NPCI、逐字节 XOR 校验 |
| 组服务 | KNX 系统规范（TP1 应用层） | GroupRead / GroupWrite / GroupResponse，短值内联与长值长度 |
| 数据点 | KNX Standard 3/7/1 | DPT-1/5/6/7/8/9/10/11/12/13/14/16/17，及 DPT-5.004 百分比、DPT-17 场景子类型 |
| 网关承载 | KNX 系统规范（cEMI） | L_Data.req / ind / con 编解码及与 TP1 报文互转 |
| KNXnet/IP | ISO/IEC 14543-3-5 | 固定头 `06 10`、SEARCH / DESCRIPTION / CONNECT / TUNNELLING / ROUTING / 设备管理 / DISCONNECT |

明确不在范围内（不影响上表字节级互操作，但本库不实现）：

- 电气层与总线仲裁时序；
- EMI 应用消息层（EMI1/EMI2 的设备管理消息语义；FT1.2 承载的是 TP1 报文本身）；
- KNX Secure 安全封装与会话握手；
- ETS 工程导入（`.knxproj` 解析）；
- 个体地址服务、设备描述符读取、内存读写；
- 厂商自定义 DPT。

本库为 sans-IO：不打开串口、不配置线参数，只产生/消费字节；19200 8E1 是 PEI16 FT1.2 模式的约定（区别于旧 PEI16 模式的 9600 8N1 加 RTS/CTS），由调用方在打开 UART 时设定。

## 端到端报文案例

以「设备 1.1.1 向组地址 2/1/1 写布尔真（DPT-1）」为例，同一份数据从值到 IP 帧逐层编码，字节可逐步核对：

| 阶段 | 编码 | 字节 |
|---|---|---|
| 值 → APCI | GroupWrite + 短值 1 | `00 81`（TPDU） |
| APCI → TP1 标准帧 | 控制 `BC` + 源 `11 01` + 组 `11 01` + NPCI `81` + TPDU + XOR 校验 | `BC 11 01 11 01 81 00 81 BC` |
| TP1 → FT1.2 | SEND_UDAT（FCB=1，控制 `73`）+ 算术和校验 | `68 0A 0A 68 73 BC 11 01 11 01 81 00 81 BC 11 16` |
| TP1 → cEMI | L_Data.req（`11`） | `11 00 BC 80 11 01 11 01 81 00 81` |
| cEMI → KNX/IP | TUNNELLING_REQUEST，channel=1 seq=0 | `06 10 04 20 00 15 04 01 00 00 11 00 BC 80 11 01 11 01 81 00 81` |

FT1.2 帧的校验字节为 `0x11`：`0x73 + 0xBC + 0x11 + 0x01 + 0x11 + 0x01 + 0x81 + 0x00 + 0x81 + 0xBC = 0x311`，模 256 取 `0x11`。反向解链用同一套规则逐层还原，任一字节错误都会在校验处被拒绝。

## 实际帧交互案例

上面的表是单向编码链；下面是一次完整串口交互，展示主站（外部设备）与从站（PEI16 耦合器/BCU2）之间的请求与应答。以下字节均由 `moon run cmd -- demo` 真实打印（见 `docs/demo.txt`），方向一栏以主站视角描述。

| 步骤 | 方向 | 帧 | 字节 |
|---|---|---|---|
| 复位链路 | 主站 → 从站 | SEND_RESET（定长帧，功能码 0x0） | `10 40 40 16` |
| 确认 | 从站 → 主站 | 单字节 ACK | `E5` |
| 写布尔真 | 主站 → 从站 | SEND_UDAT（FCB=1，功能码 0x3）承载 GroupWrite | `68 0A 0A 68 73 BC 11 01 11 01 81 00 81 BC 11 16` |
| 确认 | 从站 → 主站 | 单字节 ACK | `E5` |
| 读请求 | 主站 → 从站 | SEND_UDAT（FCB=0）承载 GroupRead | `68 0A 0A 68 53 BC 11 01 11 01 81 00 00 3D F1 16` |
| 确认 | 从站 → 主站 | 单字节 ACK | `E5` |
| 请求状态 | 主站 → 从站 | REQ_STATUS（定长帧，功能码 0x9） | `10 49 49 16` |
| 读应答 | 从站 → 主站 | RESPOND_UDAT（功能码 0x8，DIR=1）承载 GroupResponse 值 true | `68 0A 0A 68 88 BC 11 0A 11 01 81 00 41 77 AA 16` |
| 确认 | 主站 → 从站 | 单字节 ACK | `E5` |

交互要点：

- 复位后主站首帧 FCB=1，随后每条新 SEND_UDAT 翻转（1→0→1），用于抑制报文丢失/重复；每组 SEND_UDAT 都收到 `E5` 确认后才发下一帧。
- 主站发的 SEND_UDAT 控制字段为 DIR=0、PRM=1（`73`/`53`）；从站回的数据用 RESPOND_UDAT，DIR=1、PRM=0（`88`）。两者承载同一份 TP1 报文，`unwrap` 对两者一视同仁。
- 读请求（GroupRead `00 00`）由对端设备以 GroupResponse（`00 41`，值 true）回答，这条响应在串口上以 RESPOND_UDAT 帧回传给主站。
- 任一帧的算术和校验或 XOR 校验出错，`unwrap`/`Telegram::decode` 以 `BadChecksum` 拒绝，保证与目标设备在字节上互通。

## 原创与参考说明

- 本项目为原创项目，不是移植项目，无原项目名称、来源链接与许可证需要声明；
- 协议字段依据 ISO/IEC 14543-3、IEC 870-5-1 与 KNX 公开资料核对，代码为自写，不包含第三方代码，不依赖 FFI；
- 本项目许可证：Apache-2.0；
- 与常见实现相比的设计取舍：
  - 使用 MoonBit 原生包结构与测试方式组织代码，而不是复刻 Java 或 C 工程结构；
  - 只实现协议与设备模型，不模拟电气层与总线仲裁时序；
  - 核心为 sans-IO，只处理字节与字符串，传输由调用方接入；
  - 标准帧与扩展帧共用同一 Telegram 类型，由解码入口按控制位分派；
  - FT1.2 只做字符级帧规程（定界、控制字段、算术和校验），承载 TP1 报文本身，不叠加私有封装；EMI 应用消息层不在本库范围；
  - 以 cEMI、KNX/IP 和 CLI 为主要交付接口，便于接入网关、调试器与 Web 渲染；
  - KNX Secure 与 ETS 工程导入暂不实现，保留扩展位置并在文档中列明。
