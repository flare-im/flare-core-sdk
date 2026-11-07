# Client Network Changes

Platform SDKs report network reachability and foreground/background changes to the
core; the core's link supervisor alone decides whether and how to reconnect. Apps do
not wire this themselves: each platform package installs its platform lifecycle when
`client.init` runs (tests can turn it off with the platform's init option).

```ts
await client.connection.notifyNetworkChange({
  available: true,
  interface: "wifi",
  fingerprintHint: "wifi",
  reason: "connection_change",
})

await client.lifecycle.setAppState({ appState: "background" })
```

The SDK operations are `connection.notify_network_change` and
`lifecycle.set_app_state`.

- `available: false` suspends the link (`waitingForNetwork`); the next available
  report resumes it.
- `interface` is a typed `NetworkInterfaceKind` value: `unknown`, `wifi`,
  `cellular`, `ethernet`, or `other`. Platform-specific raw interface names stay
  out of the SDK protocol; put diagnostics in `reason` if needed.
- `fingerprintHint` is a coarse network identity (native: Wi-Fi gateway prefix or
  cellular MCC-MNC; web: `navigator.connection.type`). The core hashes it locally
  with `interface` into the network fingerprint that keys access point health; it is
  never sent anywhere. Never pass an SSID.
- Without a session the report only updates the fingerprint. With one, the link
  supervisor probes the current connection or switches as its state machine says;
  there is no reconnect loop outside it.
- The call returns nothing.

Platform code should not duplicate reconnect loops. It should only translate OS
reachability and lifecycle callbacks into these two calls.

## Verification

Run the lightweight gate:

```bash
cargo xtask network-reconnect
```

The gate is also part of `cargo xtask verify`. It checks the core entrypoint, the
direct invoke contract, the SDK API/model contract, every platform codec and adapter,
the TypeScript platform lifecycle, and the no-session regression test.
