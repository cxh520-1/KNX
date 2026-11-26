# KNX 项目申报书（仓库版）

**许可证：** Apache-2.0
**说明：** 本文件是提交版申报书的仓库副本，已去掉个人联系方式；提交以正式申报表为准。

## 基本信息

- 项目名称：KNX：楼宇总线协议栈的 MoonBit 实现
- GitHub 仓库链接：https://github.com/cxh520-1/KNX.git
- 项目方向：MoonBit 楼宇自动化协议库 / 网关与调试工具基础设施
- 是否为移植项目：否，原创项目

## 项目简介

KNX 用 MoonBit 实现楼宇总线协议链路，覆盖从串口帧到 IP 网关的完整路径：FT1.2 串口帧（PEI16/RS-232 物理外部接口）、cEMI L_Data 消息层（EMI 标准接口）、TP1 标准帧与扩展帧、组服务、数据点编解码、设备与虚拟总线、KNX/IP 隧道以及客户端状态机。项目面向需要在 MoonBit 中接入或模拟 KNX 的库作者、网关开发者和调试工具作者，提供可直接组合的协议层，而不是绑定某一家网关厂商的 SDK。当前版本 MoonBit 源码 5364 行（含 1616 行测试；有效代码 3748 行），120 项测试通过，CI 每次推送执行 check、test 与 wasm 构建。

## 使用场景

- 楼宇网关：从串口收到 FT1.2 帧 `68 0C 0C 68 73 11 00 BC E0 11 01 11 01 01 00 81 C6 16`，解出 cEMI L_Data 消息 `11 00 BC E0 11 01 11 01 01 00 81`，再解出源 1.1.1、组 2/1/1、GroupWrite、值 true，经 KNX/IP 隧道转发给平台，平台侧用同一库还原。
- 现场调试：抓包后用 `knx mon` 直接得到 `TUNNELLING_REQUEST channel=1 seq=0 L_Data 2/1/1 (group) GroupWrite value=1`；工程表交给 `project` 校验重复组地址和未知 DPT。
- 一致性测试：用 `net` 挂载虚拟设备、用 `gateway` 模拟隧道客户端，在 CI 中跑标准帧、扩展帧、长 TPDU、FT1.2 校验错误与 Ack 重发的字节级向量。

## 核心功能范围

- 提供个体地址与组地址模型，字段宽度不同，越界在构造时失败；
- 提供 FT1.2 串口帧编解码：变长 SEND_UDAT 帧 `68 L L 68 … 16` 双向收发（DIR=0 主机→设备、DIR=1 设备→主机）、定长 SEND_RESET `10 40 40 16`、REQ_STATUS `10 49 49 16` 与 RESPOND_STATUS `10 8B … 16`、单字节 ACK `E5`，8 位算术和校验、FCB/FCV 与 DIR/PRM 控制字段，字节与真实 KNX 串口（PEI16/RS-232）一致；
- 提供 cEMI L_Data 消息层（EMI 标准接口）：`L_Data.req/ind/con` 编解码，与 TP1 报文互转，是 FT1.2 串口与 KNX/IP 隧道共同承载的消息格式；
- 提供 TP1 标准帧与扩展帧，覆盖控制字段、源/目的地址、NPCI、XOR 校验，TPDU 超过 16 字节自动切换布局；
- 提供 GroupRead、GroupWrite、GroupResponse 三种组服务，支持短值内联与长值带长度；
- 提供管理服务（点对点 APCI）：个体地址读写（`A_IndividualAddress_Read/Write/Response`）、设备描述符读取（`A_DeviceDescriptor_Read/Response`）、内存读写（`A_Memory_Read/Write/Response`），用于把出厂设备从初始模式编程到可通信状态；
- 提供 DPT-1/5/6/7/8/9/10/11/12/13/14/16/17 编解码，以及 DPT-5.004 百分比与 DPT-17 场景子类型；
- 提供组对象表与设备行为，支持写入更新、读取应答、未知组忽略，以及出厂设备（`15.15.255`、编程模式）的个体地址编程与设备描述符应答；
- 提供虚拟总线，支持写广播、读收集应答、活动轨迹与按组统计；
- 提供 KNX/IP 头与 SEARCH、DESCRIPTION、CONNECT、CONNECTION_STATE（保活）、TUNNELLING、ROUTING、设备管理、DISCONNECT 服务；
- 提供隧道客户端状态机，管理通道号、序号、Ack、重发、入站自动应答、保活心跳与失联判定、断开；
- 提供组地址工程表的解析、重复检测、合并、反写与按 DPT 统计；
- 提供单帧解释与抓包逐帧渲染的监控模块；
- 提供 CLI，包含 `decode`、`demo`、`frames`、`cemi`、`tunnel`、`search`、`device`、`plan`、`desc`、`mon`；
- 提供 120 个 MoonBit 测试与 GitHub Actions，覆盖字面字节、双向往返和错误路径；
- 提供 README 与 `docs/` 示例，覆盖总线演示、隧道组帧和监控输出。

## 标准互操作机制

FT1.2 这一层不是自造的封装，而是按 KNX 物理外部接口（PEI16/RS-232）的既有约定实现，目标是能和真实设备在字节上互通：

- **链路形态**：点对点 RS-232 串口，FT1.2 模式线参数为 19200 bit/s、8 数据位、偶校验、1 停止位（8E1），区别于旧 PEI16 模式的 9600 8N1 加 RTS/CTS 硬件流控；库为 sans-IO，只产/消字节，线参数由调用方在打开 UART 时配置，因此同一套帧可直接连 PEI16 耦合器（BCU2）或 EMI 串口网关。
- **帧结构**（IEC 870-5-1 FT1.2 字符规程）：变长帧 `68 L L 68 C [数据] CS 16`、定长帧 `10 C [数据] CS 16`、单字节确认 `E5`；`CS` 为控制字段与数据字节的 8 位算术和（模 256）。载荷 `[数据]` 是一条 cEMI L_Data 消息，不是裸 TP1 帧。
- **控制字段**：`DIR|PRM|FCB|FCV|功能码(4 位)`。KNX 的 FT1.2 是平衡模式：两个方向都用 SEND_UDAT（功能码 0x3、FCV=1），只靠 DIR 位区分方向——主机→设备为 `53`/`73`（FCB 0/1），设备→主机为 `D3`/`F3`（FCB 0/1），FCB 各自独立翻转，用于抑制报文丢失/重复；SEND_RESET 功能码 0x0、REQ_STATUS 功能码 0x9、RESPOND_STATUS 功能码 0xB。每帧以 `E5` 确认。
- **双向收发**：上电先 `reset()` 发 `10 40 40 16` → 对方回 `E5`；主机以 `wrap(cemi, fcb)` 把 cEMI L_Data 消息包成 SEND_UDAT（DIR=0）发送，设备以 `respond_udat(cemi, fcb)` 把回传消息包成 SEND_UDAT（DIR=1）发回，两组 FCB 各自逐帧翻转。`unwrap(frame)` 同时接受两个方向的 SEND_UDAT，校验定界、长度与算术和，错误时报 `BadStart/BadEnd/BadLength/BadChecksum`，非数据帧报 `NotUserData`；`req_status()`/`respond_status(status)` 提供链路状态查询。
- **消息转换边界**：TP1 帧（总线物理层，含 XOR 校验，由 BCU 收发时计算/校验）⇄ cEMI L_Data（EMI 消息层，消息码 + 控制字段 + 源/目的 + 长度 + TPDU，不含 XOR）⇄ FT1.2（串口链路层，加定界与算术和）。`telegram` 层管 TP1 帧，`cemi` 层管 EMI 消息，`busframe` 层管 FT1.2 定界；XOR 校验只在 `telegram` 层出现，算术和校验只在 `busframe` 层出现，两个校验不重叠。

## 最终标准符合性目标

本库的符合性目标是：**在字节层面符合下列标准的公开规定——产出的帧与解析的帧与标准规定的字节格式逐字节一致**。库为 sans-IO（只处理字节，不涉及电气层、时序与物理介质），因此符合性落在「帧格式 / 消息格式 / 编码」三类，不涉及总线电气层与调度时序。下表逐层给出标准依据（含版本）与本库实现并测试的符合性范围；每一层所列即该标准中与字节格式相关的**全部必需行为**，其余部分在下方清单中明确排除。

| 协议层 | 标准依据（含版本） | 本库实现并测试的符合性范围 |
|---|---|---|
| FT1.2 串口数据链路 | IEC 870-5-1（FT1.2 字符规程），经 KNX 系统规范 Volume 3/3「物理外部接口（PEI16/RS-232）」采用 | SEND_UDAT 变长帧 `68 L L 68 … 16` 双向（DIR=0 主机→设备、DIR=1 设备→主机）、SEND_RESET `10 40 40 16`、REQ_STATUS `10 49 49 16`、RESPOND_STATUS `10 8B … 16`、单字节 ACK `E5`、8 位算术和校验（模 256）、DIR/PRM/FCB/FCV 控制字段；载荷为 cEMI L_Data 消息；线参数 19200 8E1 |
| EMI 消息层（cEMI L_Data） | KNX 系统规范（Common EMI / External Message Interface） | L_Data.req / ind / con（消息码 `11`/`29`/`2E`）、附加信息长度、控制字段 1/2、源/目的地址、NPDU 长度、TPDU，与 TP1 报文互转 |
| TP1 数据链路帧 | ISO/IEC 14543-3-6（KNX TP1 双绞线数据链路层） | 标准帧与扩展帧、控制字节校验 `(ctrl & 0x53) == 0x10`、源/目的地址、NPCI、逐字节 XOR 校验 |
| 组服务（APCI） | KNX 系统规范（TP1 应用层） | GroupRead / GroupWrite / GroupResponse，短值内联与长值长度 |
| 管理服务（APCI，点对点） | KNX 系统规范（TP1 应用层 / 管理） | `A_IndividualAddress_Write/Read/Response`、`A_DeviceDescriptor_Read/Response`、`A_Memory_Read/Write/Response`——设备初始化（个体地址编程 + 描述符读取 + 内存读写） |
| 数据点 | KNX Standard Volume 3/7（Data Point Types） | DPT-1/5/6/7/8/9/10/11/12/13/14/16/17，及 DPT-5.004 百分比、DPT-17 场景子类型 |
| KNXnet/IP | ISO 22510:2019（KNXnet/IP communication） | 固定头 `06 10`、SEARCH / DESCRIPTION / CONNECT / CONNECTION_STATE（保活）/ TUNNELLING / ROUTING / 设备管理 / DISCONNECT |

明确不在范围内（不影响上表字节级互操作，但本库不实现）：

- 电气层与总线仲裁时序；
- KNX Secure 安全封装与会话握手；
- ETS 工程导入（`.knxproj` 解析）；
- 厂商自定义 DPT。

本库为 sans-IO：不打开串口、不配置线参数，只产生/消费字节；19200 8E1 是 PEI16 FT1.2 模式的约定（区别于旧 PEI16 模式的 9600 8N1 加 RTS/CTS），由调用方在打开 UART 时设定。

## 连接生命周期与责任边界

KNXnet/IP 隧道是一条持续连接，其完整生命周期由库与调用方分工完成。库为 sans-IO、不持有时钟，因此**帧的生成与响应处理归库，定时与传输归调用方**：

| 阶段 | 库负责 | 调用方负责 |
|---|---|---|
| 建立 | `connect()` 生成 CONNECT_REQUEST，`on_frame` 处理 CONNECT_RESPONSE 并进入 Connected | 发送帧、接收响应 |
| 数据 | `send()`/`retry()` 生成 TUNNELLING_REQUEST，`on_frame` 处理 TUNNELLING_ACK 与入站 TUNNELLING_REQUEST | 收发帧 |
| 保活 | `connection_state()` 生成 CONNECTION_STATE_REQUEST，`on_frame` 处理 CONNECTION_STATE_RESPONSE 并清除待确认标记 | 周期性（约 60s）调用 `connection_state()` 发心跳；在超时（约 120s）内未收到响应时用 `keep_alive_pending()` 判定失联并触发重连 |
| 断开 | `disconnect()` 生成 DISCONNECT_REQUEST；`on_frame` 处理 DISCONNECT_RESPONSE 与服务端主动 DISCONNECT_REQUEST（自动回 DISCONNECT_RESPONSE），进入 Closed | 发送断开帧、关闭套接字 |

保活采用 KNXnet/IP CONNECTION_STATE 服务（CONNECTION_STATE_REQUEST `0x0207` / CONNECTION_STATE_RESPONSE `0x0208`），默认心跳间隔 60s、失联判定 120s，均由调用方调度。这样持续隧道连接的保活与失联反馈都有明确归属，库不做定时器、不抢调用方的传输与调度职责。

下面是 `moon run cmd -- demo` 真实打印的 KNXnet/IP 隧道完整交互（互操作边界，channel=1）：

| 步骤 | 服务 | 字节 |
|---|---|---|
| 建立连接 | CONNECT_REQUEST `0x0205` | `06 10 02 05 00 1A 08 01 C0 A8 01 0A 0E 57 08 01 C0 A8 01 0A 0E 58 04 04 02 00` |
| 隧道转发 | TUNNELLING_REQUEST `0x0420`（承载 cEMI L_Data.req） | `06 10 04 20 00 15 04 01 00 00 11 00 BC E0 11 01 11 01 01 00 81` |
| 保活心跳 | CONNECTION_STATE_REQUEST `0x0207` | `06 10 02 07 00 10 01 00 08 01 C0 A8 01 0A 0E 57` |
| 断开连接 | DISCONNECT_REQUEST `0x0209` | `06 10 02 09 00 10 01 00 08 01 00 00 00 00 00 00` |

## 设备接入流程（初始模式 → 可通信状态）

下面用一次真实的设备初始化说明「出厂 → 可通信 → 组读写」的接入流程。设备出厂时个体地址为 `15.15.255`、处于编程模式；调试工具先给它编址，再读回地址与设备描述符，之后设备即可加入组通信。以下字节由 `moon run cmd -- demo` 真实打印。

| 步骤 | 服务 | 字节 | 结果 |
|---|---|---|---|
| 1. 编址 | `A_IndividualAddress_Write`（APCI `03C0`）+ 目标地址 `1.1.20` | `03 C0 11 14` | 设备存下 `1.1.20`、退出编程模式 |
| 2. 读回 | `A_IndividualAddress_Read`（APCI `0100`） | `01 00` | 设备回 `A_IndividualAddress_Response`：`01 40 11 14` |
| 3. 描述符 | `A_DeviceDescriptor_Read`（APCI `0300`） | `03 00` | 设备回 `A_DeviceDescriptor_Response`：`03 40 00 02`（TP1） |
| 4. 配置 | 组对象表（`device.add` API；`A_Memory_Write` 提供线缆级编解码） | — | 绑定组地址 + DPT |
| 5. 组读写 | `GroupRead` / `GroupWrite`（组服务） | `00 00` / `00 81`（TPDU） | 进入可通信状态，参与组通信 |

其中 1–3 是设备从「初始模式」进入「可通信状态」的关键：个体地址编程负责把 `15.15.255` 替换成真实地址，描述符读取负责识别设备类型；这两步由库的管理 APCI（`A_IndividualAddress_*`、`A_DeviceDescriptor_*`）与设备端 `commission()` 共同完成，责任边界清晰——调试工具发管理帧、设备在编程模式下应答并落地地址。第 4 步的组对象配置，库用 `add()` API 在设备模型里直接完成（这是内存写入配置的编程等价物）；`A_Memory_Read/Write/Response` 的字节级编解码也已实现并测试，供调试工具侧按真实设备的内存地址读写，而具体内存布局属于设备厂商的 ETS 产品数据库、不在本库范围内。

## 端到端报文案例

以「设备 1.1.1 向组地址 2/1/1 写布尔真（DPT-1）」为例，同一份数据从值到串口帧逐层编码，字节可逐步核对：

| 阶段 | 编码 | 字节 |
|---|---|---|
| 值 → APCI | GroupWrite + 短值 1 | `00 81`（TPDU） |
| APCI → TP1 标准帧 | 控制 `BC` + 源 `11 01` + 组 `11 01` + NPCI `81` + TPDU + XOR 校验 | `BC 11 01 11 01 81 00 81 BC`（总线层） |
| TP1 → cEMI L_Data | 去掉 XOR 校验，加消息码 `11` 与控制字段 | `11 00 BC E0 11 01 11 01 01 00 81`（EMI 消息层） |
| cEMI → FT1.2 | SEND_UDAT（FCB=1，控制 `73`）+ 算术和校验 | `68 0C 0C 68 73 11 00 BC E0 11 01 11 01 01 00 81 C6 16` |
| cEMI → KNX/IP | TUNNELLING_REQUEST，channel=1 seq=0 | `06 10 04 20 00 15 04 01 00 00 11 00 BC E0 11 01 11 01 01 00 81` |

FT1.2 帧的校验字节为 `0xC6`：`0x73 + 0x11 + 0x00 + 0xBC + 0xE0 + 0x11 + 0x01 + 0x11 + 0x01 + 0x01 + 0x00 + 0x81 = 0x2C6`，模 256 取 `0xC6`。反向解链用同一套规则逐层还原，任一字节错误都会在校验处被拒绝。

## 实际帧交互案例

上面的表是单向编码链；下面是一次完整串口交互，展示主机（外部设备）与设备（PEI16 耦合器/BCU2）之间的双向收发。以下字节均由 `moon run cmd -- demo` 真实打印（见 `docs/demo.txt`），方向一栏以主机视角描述。

| 步骤 | 方向 | 帧 | 字节 |
|---|---|---|---|
| 复位链路 | 主机 → 设备 | SEND_RESET（定长帧，功能码 0x0） | `10 40 40 16` |
| 确认 | 设备 → 主机 | 单字节 ACK | `E5` |
| 写布尔真 | 主机 → 设备 | SEND_UDAT（DIR=0，FCB=1）承载 L_Data.req GroupWrite | `68 0C 0C 68 73 11 00 BC E0 11 01 11 01 01 00 81 C6 16` |
| 确认 | 设备 → 主机 | 单字节 ACK | `E5` |
| 读请求 | 主机 → 设备 | SEND_UDAT（DIR=0，FCB=0）承载 L_Data.req GroupRead | `68 0C 0C 68 53 11 00 BC E0 11 01 11 01 01 00 00 25 16` |
| 确认 | 设备 → 主机 | 单字节 ACK | `E5` |
| 读应答 | 设备 → 主机 | SEND_UDAT（DIR=1，FCB=1）承载 L_Data.ind GroupResponse 值 true | `68 0C 0C 68 F3 29 00 BC E0 11 0A 11 01 01 00 41 27 16` |
| 确认 | 主机 → 设备 | 单字节 ACK | `E5` |

交互要点：

- 复位后两个方向各自的首帧 FCB=1，随后每条新 SEND_UDAT 各自翻转（主机侧 1→0，设备侧本次保持 1），用于抑制报文丢失/重复；每组 SEND_UDAT 都收到 `E5` 确认后才发下一帧。
- 两个方向都用 SEND_UDAT（功能码 0x3、PRM=1），只靠 DIR 位区分：主机→设备控制字段为 `73`/`53`（DIR=0），设备→主机为 `F3`/`D3`（DIR=1）。两者承载同一份 cEMI L_Data 消息，`unwrap` 对两个方向一视同仁。
- 读请求以 L_Data.req（消息码 `11`）承载 GroupRead `00 00`；对端设备以 L_Data.ind（消息码 `29`）承载 GroupResponse `00 41`（值 true）回答，这条响应在串口上以 DIR=1 的 SEND_UDAT 帧回传给主机。
- 任一帧的算术和校验或 XOR 校验出错，`unwrap`/`Telegram::decode` 以 `BadChecksum` 拒绝，保证与目标设备在字节上互通。

## 原创与参考说明

- 本项目为原创项目，不是移植项目，无原项目名称、来源链接与许可证需要声明；
- 协议字段依据 ISO/IEC 14543-3、ISO 22510（KNXnet/IP）、IEC 870-5-1 与 KNX 公开资料核对，代码为自写，不包含第三方代码，不依赖 FFI；
- 本项目许可证：Apache-2.0；
- 与常见实现相比的设计取舍：
  - 使用 MoonBit 原生包结构与测试方式组织代码，而不是复刻 Java 或 C 工程结构；
  - 只实现协议与设备模型，不模拟电气层与总线仲裁时序；
  - 核心为 sans-IO，只处理字节与字符串，传输由调用方接入；
  - 标准帧与扩展帧共用同一 Telegram 类型，由解码入口按控制位分派；
  - 把 TP1 帧、cEMI L_Data（EMI 消息层）、FT1.2 串口帧分成三层：XOR 校验只在 TP1 帧，算术和校验只在 FT1.2，EMI 消息层只做报文封装，不叠加私有封装；
  - 以 cEMI、KNX/IP 和 CLI 为主要交付接口，便于接入网关、调试器与 Web 渲染；
  - KNX Secure 与 ETS 工程导入暂不实现，保留扩展位置并在文档中列明。
