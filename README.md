# Flare IM Core Client SDK

English · [中文](README.zh-CN.md)

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


This workspace contains typed client SDK adapters for `flare-im-core-sdk`.

The Rust core remains the only place for IM behavior. This workspace owns platform API shape, generated contracts, native artifact placement, docs, examples and contract tests.

## Architecture

```text
App
  -> L3 typed platform facade
  -> L2 runtime adapter
  -> L1 C ABI: ../flare-core-sdk-engine/bindings/c
  -> L0 Rust core: ../flare-core-sdk-engine
```

## Directory Map

```text
sdk-spec/        split contract source of truth
native/          C ABI index and produced native artifacts
packages/        platform SDK packages
examples/        platform smoke apps
docs/            generated and hand-written SDK docs
```

## Commands

```bash
make help
make all
make check

cargo xtask verify
cargo xtask sync-spec
cargo xtask codegen
cargo xtask wire-boundary-check
```

Common `make` targets:

- `make codegen`: regenerate SDK contracts **and sync official/docs/sdk** (11, 17, client-platform-api.json).
- `make spec`: validate split spec invariants.
- `make verify`: validate spec, core-contract parity, and package structure.
- `make all`: sync spec, verify, regenerate packages, and verify structure.
- `make codegen-check`: verify generated SDK outputs are up to date.
- `make wire-boundary-check`: verify Rust-owned wire boundary artifacts.
- `make check`: run spec/codegen/structure plus TypeScript, Dart, Swift, and optional Cangjie checks.
- `make clean`: remove local package/tool build caches.

## Rules

- Update `sdk-spec/modules/*.json` before changing public SDK APIs.
- Never duplicate message, conversation, sync, delivery, auth, presence, media, call or plugin business rules in platform packages.
- Keep platform wrappers thin: validate input, call C ABI, map result, emit typed event or typed error.
- Generated files are disposable. Do not edit generated files by hand.

## Production Contracts

- Runtime behavior: `docs/runtime-contracts.md`
- Architecture review and next steps: `docs/architecture-review.md`

---

## 下一步

| 想做什么 | 去哪里 |
|---|---|
| **五分钟跑起来** | [QUICKSTART](https://github.com/flare-im/flare-core-server/blob/main/QUICKSTART.md) —— 起服务、手签 token、调通接口，**不需要自建用户体系** |
| 接入自己的用户系统 | 实现 `TokenValidator`（`CoreJwtTokenValidator` 本地验签 / `HttpHookTokenValidator` 调你的接口） |
| 加自己的业务规则 | `flare-im-hooks` 的 9 个扩展点：PreSend / PostSend / Delivery / Recall / MessageRead / MessageReaction / ConversationLifecycle / ConversationMember / GetConversationParticipants |
| 做界面 | [`@flare-im/vue-ui`](https://www.npmjs.com/package/@flare-im/vue-ui) —— 107 个组件，四端一致的契约 |
| 报安全问题 | [SECURITY.md](.github/SECURITY.md)，**请勿开公开 issue** |

## 需要账号体系与社交能力时

开源部分是**通信基础设施**。如果你需要的是现成的账号、好友关系、群治理（角色 / 入群审批 / 禁言）、朋友圈，
这些在商业模块里 —— 自研这一层通常要数月，且都是与通信无关的重复劳动。

企业场景另有 SSO / 组织架构 / 审计导出 / 数据驻留 / SLA 支持。

咨询：`flare1522@163.com`

> 边界划分与不变承诺见 [GOVERNANCE](https://github.com/flare-im/flare-core-server/blob/main/GOVERNANCE.md)。
> 简言之：**已开源的不会被收回，鉴权与 hooks 契约永远开源、不会为逼迫付费而阉割。**
