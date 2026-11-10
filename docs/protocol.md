# 协议覆盖

## 报文

| 能力 | 状态 | 位置 |
|---|---|---|
| TP1 标准帧编码/解码 | 可用 | `lib/telegram/frame.mbt` |
| 控制字节校验 `(ctrl & 0x53) == 0x10` | 可用 | 同上 |
| NPCI：组/个体、跳数、长度 | 可用 | 同上 |
| 校验字节（逐字节异或） | 可用 | 同上 |
| 扩展帧（长 TPDU） | 可用 | `lib/telegram/frame.mbt` |
| FT1.2 封装与 `0x10` 双写 | 可用 | `lib/busframe/ft12.mbt` |

## 组服务

| 服务 | 码 | 状态 |
|---|---|---|
| GroupRead | `0x0000` | 可用 |
| GroupResponse | `0x0040` | 可用 |
| GroupWrite | `0x0080` | 可用 |
| 个体地址服务 | — | 未实现 |
| 设备描述符读取 | — | 未实现 |
| 内存读写 | — | 未实现 |

## 数据点

| DPT | 含义 | 长度 | 范围/格式 |
|---|---|---|---|
| 1 | 布尔 | 1 bit（短值内联） | true / false |
| 5 | 8 位无符号 | 1 字节 | 0..255 |
| 6 | 8 位有符号 | 1 字节 | -128..127 |
| 7 | 16 位无符号 | 2 字节 | 0..65535 |
| 8 | 16 位有符号 | 2 字节 | -32768..32767 |
| 9 | 2 字节浮点 | 2 字节 | `0.01 × 尾数 × 2^指数` |
| 16 | 字符串 | 14 字节 | ASCII，NUL 补齐 |
| 17 | 场景号 + 存储位 | 1 字节 | 号码 0..63，bit7 存储 |
| 5.004 | 百分比 | 1 字节 | 0..100 % 映射到 0..255 |
| 10 | 时间 | 3 字节 | 未实现 |
| 11 | 日期 | 3 字节 | 未实现 |
| 12/13 | 32 位整数 | 4 字节 | 未实现 |
| 14 | 4 字节浮点 | 4 字节 | 未实现 |

## 设备与总线

| 能力 | 状态 |
|---|---|
| 组对象表（地址 + DPT + 当前值） | 可用 |
| 写入更新、读取应答 | 可用 |
| 未知组地址忽略 | 可用 |
| 虚拟总线广播与应答收集 | 可用 |
| 活动轨迹与帧记录 | 可用 |
| 电气层 / 仲裁时序 | 未实现 |

## 网关与 KNX/IP

| 能力 | 状态 | 位置 |
|---|---|---|
| cEMI L_Data.req / ind / con | 可用 | `lib/cemi/cemi.mbt` |
| cEMI 与 TP1 报文互转 | 可用 | 同上 |
| KNX/IP 固定头（`06 10`，服务码，总长） | 可用 | `lib/knxip/knxip.mbt` |
| CONNECT_REQUEST / CONNECT_RESPONSE | 可用 | 同上 |
| TUNNELLING_REQUEST / TUNNELLING_ACK | 可用 | 同上 |
| HPAI（IPv4 + UDP 端口） | 可用 | 同上 |
| SEARCH_REQUEST / SEARCH_RESPONSE | 可用 | `lib/knxip/knxip.mbt` |
| DESCRIPTION_REQUEST | 可用 | 同上 |
| ROUTING_INDICATION / ROUTING_BUSY | 可用 | 同上 |
| 服务族 DIB（能力协商） | 可用 | 同上 |
| DEVICE_CONFIGURATION_REQUEST / ACK | 可用 | 同上 |`r`n| DESCRIPTION_RESPONSE | 可用 | 同上 |`r`n| ROUTING_LOST_MESSAGE | 可用 | 同上 |
| 安全封装（SECURE_WRAPPER） | 未实现 | — |
## 工程表

| 能力 | 状态 |
|---|---|
| `1/2/3 = DPT9 温度` 行解析 | 可用 |
| 重复组地址检测 | 可用 |
| 未知 DPT 名称检测 | 可用 |
| 表报告（条目数与逐行输出） | 可用 |
## 隧道客户端

| 能力 | 状态 |
|---|---|
| CONNECT_REQUEST 发起连接 | 可用 |
| CONNECT_RESPONSE 打开通道、记录 channel | 可用 |
| 发送 telegram（cEMI + TUNNELLING_REQUEST） | 可用 |
| 序号分配与 Ack 匹配 | 可用 |
| 未确认请求重发 | 可用 |
| 入站 TUNNELLING_REQUEST 自动应答 | 可用 |
| 超时判定 | 由调用方负责 |
## 监控与统计

| 能力 | 状态 |
|---|---|
| 单帧解释（服务、通道、cEMI、APCI） | 可用 |
| 抓包逐帧渲染（带序号） | 可用 |
| 工程表合并（重复地址报错） | 可用 |
| 工程表反写为文本 | 可用 |
| 按 DPT 统计条目数 | 可用 |
| 总线按组地址统计读写次数 | 可用 |