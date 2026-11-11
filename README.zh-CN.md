# Flare IM Core Client SDK

[English](README.md) · 简体中文

> ## ℹ 这是通信基础设施，不是开箱即用的 IM 产品
>
> 说在前面，免得你 clone 完才发现登不上去：**开源部分不含账号体系**
> （没有注册登录、好友关系、群角色/审批/禁言、朋友圈）。
>
> 但它自带完整且可插拔的鉴权契约，两条路都在开源侧：
>
> - **`CoreJwtTokenValidator`** —— 本地验 JWT。手签一个 token 就能跑起来做
>   demo / POC，**不需要任何用户体系**。
> - **`HttpHookTokenValidator`** —— 把 token POST 到你自己的接口，
>   **这是接入自有用户体系的入口**。
>
> 业务规则同理：`flare-core-server/crates/flare-im-hooks` 提供 9 个扩展点
> （PreSend / PostSend / Delivery / Recall / MessageRead / MessageReaction /
> ConversationLifecycle / ConversationMember / GetConversationParticipants）。
>
> 要上生产，你需要自行实现用户体系并按上述契约接入 —— 与 Sendbird /
> Twilio Conversations 的「自带身份」模型一致，区别是 Flare 可自托管、
> 协议与核心可审计。
>
> 边界详情见 [GOVERNANCE.md](.github/GOVERNANCE.md)。


本工作区包含面向 `flare-im-core-sdk` 的类型化客户端 SDK 适配层。

Rust 核心仍是 IM 行为的唯一归属地。本工作区负责平台 API 形态、生成的契约、原生产物落位、文档、示例与契约测试。

## 架构

```text
App
  -> L3 typed platform facade
  -> L2 runtime adapter
  -> L1 C ABI: ../flare-core-sdk-engine/bindings/c
  -> L0 Rust core: ../flare-core-sdk-engine
```

## 目录结构

```text
sdk-spec/        split contract source of truth
native/          C ABI index and produced native artifacts
packages/        platform SDK packages
examples/        契约验证数据与独立示例仓入口
docs/            generated and hand-written SDK docs
```

## 命令

```bash
make help
make all
make check

cargo xtask verify
cargo xtask sync-spec
cargo xtask codegen
cargo xtask wire-boundary-check
```

常用 `make` 目标：

- `make codegen`：重新生成 SDK 契约，**并同步 official/docs/sdk**（11、17、client-platform-api.json）。
- `make spec`：校验 split spec 不变量。
- `make verify`：校验 spec、core-contract 一致性与包结构。
- `make all`：同步 spec、校验、重新生成包并校验结构。
- `make codegen-check`：校验生成的 SDK 产物是否为最新。
- `make wire-boundary-check`：校验 Rust 归属的 wire 边界产物。
- `make check`：运行 spec/codegen/structure，外加 TypeScript、Dart、Swift 以及可选的 Cangjie 检查。
- `make clean`：清除本地包/工具构建缓存。

## 规则

- 在改动公开 SDK API 之前，先更新 `sdk-spec/modules/*.json`。
- 切勿在平台包中重复实现消息、会话、同步、投递、鉴权、在线状态、媒体、通话或插件的业务规则。
- 保持平台封装层轻薄：校验输入、调用 C ABI、映射结果、发出类型化事件或类型化错误。
- 生成的文件是可丢弃的。不要手工编辑生成的文件。

## 生产契约

- 运行时行为：`docs/runtime-contracts.md`
- 架构评审与后续步骤：`docs/architecture-review.md`

---

## 下一步

| 想做什么 | 去哪里 |
|---|---|
| **五分钟跑起来** | [QUICKSTART](https://github.com/flare-im/flare-core-server/blob/main/docs/QUICKSTART.zh-CN.md) —— 起服务、手签 token、调通接口，**不需要自建用户体系** |
| 接入自己的用户系统 | 实现 `TokenValidator`（`CoreJwtTokenValidator` 本地验签 / `HttpHookTokenValidator` 调你的接口） |
| 加自己的业务规则 | `flare-im-hooks` 的 9 个扩展点：PreSend / PostSend / Delivery / Recall / MessageRead / MessageReaction / ConversationLifecycle / ConversationMember / GetConversationParticipants |
| 做界面 | [`@flare-im/vue-ui`](https://www.npmjs.com/package/@flare-im/vue-ui) —— 107 个组件，四端一致的契约 |
| 报安全问题 | [SECURITY.md](.github/SECURITY.md)，**请勿开公开 issue** |

## 需要账号体系与社交能力时

开源部分是**通信基础设施**。如果你需要的是现成的账号、好友关系、群治理（角色 / 入群审批 / 禁言）、朋友圈，
这些在商业模块里 —— 自研这一层通常要数月，且都是与通信无关的重复劳动。

企业场景另有 SSO / 组织架构 / 审计导出 / 数据驻留 / SLA 支持。

咨询：`flare1522@163.com`

> 边界划分与不变承诺见 [GOVERNANCE](https://github.com/flare-im/flare-core-server/blob/main/.github/GOVERNANCE.md)。
> 简言之：**已开源的不会被收回，鉴权与 hooks 契约永远开源、不会为逼迫付费而阉割。**

## 集成示例

各端接入方式见 [Core 示例应用](https://github.com/flare-im/flare-core-examples)。共享的发送、排序和同步行为由 [Rust SDK 引擎](https://github.com/flare-im/flare-core-sdk-engine) 维护。
