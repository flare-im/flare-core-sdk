# Native Boundary

The only native boundary is:

```text
../flare-core-sdk-engine/bindings/c
```

This workspace does not maintain a second native implementation.

## Contents

```text
abi/        copied or generated headers for platform package builds
artifacts/  produced .so/.a/.dylib/.xcframework files
```

Native artifacts are build outputs. Keep them out of source control unless a release process explicitly requires checked-in binaries.
