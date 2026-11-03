# Flare IM Performance Baselines

This document records the public benchmark entrypoints that must remain
available while the SDK evolves. The numbers are intentionally produced by
explicit benchmark commands, while the default CI gate only verifies that the
benchmark surfaces and coverage stay present.

## Transport Core

Run the transport/core baseline:

```bash
cargo bench --manifest-path ../flare-transport/Cargo.toml --bench perf_baseline --features server,compression-gzip
```

Covered scenarios:

- `codec.protobuf.round_trip.256b`
- `pipeline.process_raw.validate_no_response.256b`
- `connection_manager.broadcast.1000x256b`
- `connection_manager.cleanup_timeout_trait.1000`

The benchmark prints JSON so trend collection can store and compare results
without scraping human-formatted output.

## IM Core SDK

Run the SDK baseline:

```bash
cargo bench --manifest-path ../flare-core-sdk-engine/Cargo.toml --bench perf_baseline
```

Covered scenarios:

- Event bus steady-state publish and filtered receive.
- Text message prepare, encode, and local store.
- Received batch fan-out for timeline refresh.
- One thousand message sync event fan-out.
- Event JSON serialization.
- Protocol codec decode.

These scenarios protect the user-visible send→render and sync→render hot paths
without duplicating runtime behavior in client examples.

## Regression Gate

Run the lightweight gate:

```bash
cargo xtask performance
```

The gate is also part of `cargo xtask verify`. It does not execute heavy
benchmarks; it fails when benchmark manifests, benchmark files, or required
coverage anchors are removed.

## Live Large-Group SDK E2E Gate

These examples require local Flare IM Core services and the signaling gateway to
be running. By default they connect to `ws://localhost:60051` and read the local
dev token secret from `../flare-core-server/logs/.dev-token-secret`.

Two-user receive convergence:

```bash
cd ../flare-core-sdk-engine
FLARE_E2E_TOTAL=20 \
FLARE_E2E_IN_FLIGHT=8 \
FLARE_E2E_RECEIVE_TIMEOUT_MS=30000 \
rtk cargo run --example two_user_latency_throughput --features lifecycle-sqlite
```

Large-group correctness baseline:

```bash
cd ../flare-core-sdk-engine
FLARE_GROUP_E2E_USERS="$(seq -s, 1000 1099)" \
FLARE_GROUP_E2E_PER_USER=1 \
FLARE_GROUP_E2E_IN_FLIGHT=64 \
FLARE_GROUP_E2E_ACK_TIMEOUT_MS=120000 \
FLARE_GROUP_E2E_RECEIVE_TIMEOUT_MS=180000 \
FLARE_GROUP_E2E_SETTLE_MS=1000 \
rtk cargo run --example group_latency_throughput --features lifecycle-sqlite
```

Multi-message group convergence:

```bash
cd ../flare-core-sdk-engine
FLARE_GROUP_E2E_USERS="$(seq -s, 2000 2019)" \
FLARE_GROUP_E2E_PER_USER=5 \
FLARE_GROUP_E2E_IN_FLIGHT=64 \
FLARE_GROUP_E2E_ACK_TIMEOUT_MS=120000 \
FLARE_GROUP_E2E_RECEIVE_TIMEOUT_MS=180000 \
FLARE_GROUP_E2E_SETTLE_MS=1000 \
rtk cargo run --example group_latency_throughput --features lifecycle-sqlite
```

Collaboration-state convergence:

```bash
cd ../flare-core-sdk-engine
rtk cargo run --example typing_relay_e2e --features lifecycle-sqlite
rtk cargo run --example read_receipt_e2e --features lifecycle-sqlite
```

2026-06-30 local baseline:

| Scenario | Result |
|----------|--------|
| Two users, 20 messages | 20/20 sent, 20/20 persisted ACK, 20/20 received, 0 lost, 0 duplicate, p99 receive latency 1762.335 ms. |
| 100 users x 1 message | 100 persisted ACK, 9900/9900 remote deliveries, 0 lost, 0 duplicate, end-to-end remote delivery throughput 878.00 deliveries/s, p99 remote latency 9836.168 ms. |
| 20 users x 5 messages | 100 persisted ACK, 1900/1900 remote deliveries, 0 lost, 0 duplicate, end-to-end remote delivery throughput 545.66 deliveries/s, p99 remote latency 3337.454 ms. |
| Typing aggregate | `TYPING_AGGREGATE_OK`. |
| Read receipt | `READ_RECEIPT_OK`, read cursor `read_seq=1`. |

These numbers are correctness and local-scale baselines, not production SLOs.
Production gates should repeat the same profiles on dedicated hardware and store
the JSON/run metadata for trend comparison.
