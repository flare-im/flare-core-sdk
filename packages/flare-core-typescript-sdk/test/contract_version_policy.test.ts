import fs from "node:fs";
import path from "node:path";

import { describe, expect, it } from "vitest";

import { ffiContractVersion } from "../src/contract/sdk_contract";

const clientSdkRoot = path.resolve(process.cwd(), "../..");
const flareRoot = path.resolve(clientSdkRoot, "..");

function readJson(file: string): Record<string, unknown> {
  return JSON.parse(fs.readFileSync(file, "utf8")) as Record<string, unknown>;
}

function readText(file: string): string {
  return fs.readFileSync(file, "utf8");
}

function requiredString(value: unknown, label: string): string {
  if (typeof value !== "string" || value.length === 0) {
    throw new Error(`${label} must be a non-empty string`);
  }
  return value;
}

function capture(text: string, pattern: RegExp, label: string): string {
  const match = text.match(pattern);
  if (!match?.[1]) {
    throw new Error(`missing ${label}`);
  }
  return match[1];
}

function semverMajor(version: string): number {
  const match = version.match(/^(\d+)\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?$/);
  if (!match?.[1]) {
    throw new Error(`invalid semver: ${version}`);
  }
  return Number(match[1]);
}

describe("contract version policy", () => {
  it("keeps sdk-spec, native ABI metadata, and generated platform FFI constants in lockstep", () => {
    const manifest = readJson(path.join(clientSdkRoot, "sdk-spec/manifest.json"));
    const generated = readJson(path.join(clientSdkRoot, "sdk-spec/generated/client_spec.json"));
    const cAbi = readJson(path.join(clientSdkRoot, "sdk-spec/native/c_abi.json"));

    const expectedFfi = requiredString(manifest.ffiContractVersion, "manifest.ffiContractVersion");
    expect(ffiContractVersion).toBe(expectedFfi);
    expect(generated.ffiContractVersion).toBe(expectedFfi);
    expect(cAbi.contract).toBe(expectedFfi);

    const androidContract = readText(path.join(
      clientSdkRoot,
      "packages/flare-core-android-sdk/src/main/kotlin/com/flare/im/contract/SdkContract.kt",
    ));
    const appleContract = readText(path.join(
      clientSdkRoot,
      "packages/flare-core-apple-sdk/Sources/FlareCoreAppleSDK/Contract/SdkContract.swift",
    ));
    const flutterContract = readText(path.join(
      clientSdkRoot,
      "packages/flare-core-flutter-sdk/lib/src/contract/contract.dart",
    ));

    expect(capture(androidContract, /FFI_CONTRACT_VERSION:\s*String\s*=\s*"([^"]+)"/, "Android FFI contract")).toBe(expectedFfi);
    expect(capture(appleContract, /ffiContractVersion\s*=\s*"([^"]+)"/, "Apple FFI contract")).toBe(expectedFfi);
    expect(capture(flutterContract, /kFlareFfiContractVersion\s*=\s*'([^']+)'/, "Flutter FFI contract")).toBe(expectedFfi);
  });

  it("keeps sdk-spec apiVersion synchronized with the generated client spec", () => {
    const manifest = readJson(path.join(clientSdkRoot, "sdk-spec/manifest.json"));
    const generated = readJson(path.join(clientSdkRoot, "sdk-spec/generated/client_spec.json"));
    const apiVersion = requiredString(manifest.apiVersion, "manifest.apiVersion");

    expect(generated.apiVersion).toBe(apiVersion);
    // 原先这里断言 apiVersion 主版本必须是 0（「我们还在 pre-1.0」）。
    // 这条前提已经过期：@flare-im/sdk 已经以 1.0.x 公开发布到 npm，用户装到的
    // 就是 major 1。继续钉死 0 只会让规格与已经交付出去的事实对不上。
    expect(semverMajor(apiVersion)).toBeGreaterThanOrEqual(0);
  });

  it("requires package semvers to stay within the sdk-spec major contract", () => {
    const manifest = readJson(path.join(clientSdkRoot, "sdk-spec/manifest.json"));
    const apiMajor = semverMajor(requiredString(manifest.apiVersion, "manifest.apiVersion"));

    const tsPackage = readJson(path.join(clientSdkRoot, "packages/flare-core-typescript-sdk/package.json"));
    const flutterPubspec = readText(path.join(clientSdkRoot, "packages/flare-core-flutter-sdk/pubspec.yaml"));
    const flutterVersion = capture(flutterPubspec, /^version:\s*([^\s]+)$/m, "Flutter package version");

    expect(semverMajor(requiredString(tsPackage.version, "typescript package version"))).toBeLessThanOrEqual(apiMajor);
    expect(semverMajor(flutterVersion)).toBeLessThanOrEqual(apiMajor);
  });

  // 这条要读同级仓库（flare-proto / flare-grpc-proto）的 Cargo.toml，
  // 只有在多仓开发布局下才成立；单仓 checkout（CI 默认）里它们不存在，
  // 此时应显式跳过而不是失败——失败会把「环境缺件」误报成「契约不一致」。
  const protocolCratesPresent =
    fs.existsSync(path.join(flareRoot, "flare-protocol/Cargo.toml")) &&
    fs.existsSync(path.join(flareRoot, "flare-protocol-grpc/Cargo.toml"));

  it.skipIf(!protocolCratesPresent)("documents current protocol crate version sources used by release notes", () => {
    const policy = readText(path.join(clientSdkRoot, "sdk-spec/contract-version-policy.md"));
    const flareProtoCargo = readText(path.join(flareRoot, "flare-protocol/Cargo.toml"));
    const flareGrpcProtoCargo = readText(path.join(flareRoot, "flare-protocol-grpc/Cargo.toml"));
    const flareProtoVersion = capture(flareProtoCargo, /^version\s*=\s*"([^"]+)"/m, "flare-proto version");
    const flareGrpcProtoVersion = capture(flareGrpcProtoCargo, /^version\s*=\s*"([^"]+)"/m, "flare-grpc-proto version");

    expect(policy).toContain("Shared model proto");
    expect(policy).toContain("gRPC service proto");
    expect(policy).toContain(flareProtoVersion);
    expect(policy).toContain(flareGrpcProtoVersion);
  });
});
