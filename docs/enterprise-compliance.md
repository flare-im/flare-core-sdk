# Enterprise Compliance Contract

Flare keeps enterprise policy hooks explicit and product-neutral. Core provides
the enforcement anchors; product consoles, approval flows, and organization
models remain business-owned integrations.

## Admin Write Audit Contract

Admin gateway write APIs require:

- authenticated admin gateway scope,
- tenant context through `x-tenant-id`,
- actor context through `x-actor-id`,
- audit reason through `x-audit-reason`,
- either `x-request-id` or `idempotency-key`.

Read APIs still require admin scope and tenant context. A principal bound to one
tenant cannot operate under another tenant header.

## Enterprise Policy Discovery

`GET /api/v1/admin/capabilities` exposes structured enterprise policy
descriptors instead of stringly owned-feature hints:

- `organization_policy` declares that operator identity lifecycle, business
  roles, and approval flows come from the enterprise admin identity provider.
- `data_residency_policy` declares tenant-scoped placement through
  `x-tenant-id` and protects storage query, export, and media access paths.
- `retention_legal_policy` declares the core guardrails already available for
  retention events, compliance hooks, and `capability_audit_log`.

Authority, role source, protected operation, and retention anchor fields are
typed enums in the OpenAPI contract. Their JSON representation uses stable
snake_case values, but server code does not construct those fields as arbitrary
strings.

The admin gateway remains product-neutral: it enforces tenant/audit context and
publishes the policy contract, while the enterprise console supplies role
authoring, approval workflows, tenant-region mapping, and legal-hold decisions.

## Capability Policy Audit

Capability policy mutations are audited in `capability_audit_log`. The table is
indexed by tenant/time and action/time, and `PostgresCapabilityAuditLog` writes
Grant / Revoke / tenant switch policy events. Dispatch hot paths do not write
this table by default.

## Message Compliance Hooks

Message compliance is pluggable through hooks:

- `pre_send` can block a message, for example `compliance-text-check`.
- `post_send` can fan out audit records, for example `audit-log-sink`.
- `recall` can record recall policy decisions, for example `recall-audit`.

Hooks carry tenant selectors and transport declarations in
`flare-core-server/config/hooks.example.toml`. Core does not embed business-specific
moderation or legal-retention rules.

## Remaining Enterprise Scope

Still out of the current core implementation:

- concrete organization hierarchy storage and role lifecycle APIs,
- tenant-region placement engine and cross-region export approval,
- admin console UX,
- legal-hold policy authoring and external case-management integration.

Those must be implemented as product or enterprise plugins on top of the typed
policy descriptors and auditable core boundaries.

## Verification

Run:

```bash
cargo xtask enterprise-compliance
```

The gate is also part of `cargo xtask verify`. It checks admin write audit
headers, admin capability descriptors, capability audit persistence, deploy SQL
schema, and compliance hook examples.
