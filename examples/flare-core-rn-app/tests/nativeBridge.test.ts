import assert from 'node:assert/strict';
import { existsSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { test } from 'node:test';

const appRoot = join(import.meta.dirname, '..');

function read(path: string): string {
  return readFileSync(join(appRoot, path), 'utf8');
}

test('React Native app exposes FlareImCoreSdk native module on Android and iOS', () => {
  const androidModulePath = 'android/app/src/main/java/com/flarecorernapp/FlareImCoreSdkModule.kt';
  const androidPackagePath = 'android/app/src/main/java/com/flarecorernapp/FlareImCoreSdkPackage.kt';
  const iosModulePath = 'ios/FlareCoreRnApp/FlareImCoreSdk.swift';
  const iosBridgePath = 'ios/FlareCoreRnApp/FlareImCoreSdkBridge.m';

  assert.equal(existsSync(join(appRoot, androidModulePath)), true);
  assert.equal(existsSync(join(appRoot, androidPackagePath)), true);
  assert.equal(existsSync(join(appRoot, iosModulePath)), true);
  assert.equal(existsSync(join(appRoot, iosBridgePath)), true);

  const androidModule = read(androidModulePath);
  assert.match(androidModule, /class FlareImCoreSdkModule/);
  assert.match(androidModule, /override fun getName\(\): String = "FlareImCoreSdk"/);
  assert.match(androidModule, /@ReactMethod\s+fun invoke\(/);
  assert.match(androidModule, /JniNativeBridge\(\)/);

  const androidPackage = read(androidPackagePath);
  assert.match(androidPackage, /class FlareImCoreSdkPackage/);
  assert.match(androidPackage, /FlareImCoreSdkModule\(reactContext\)/);

  const mainApplication = read('android/app/src/main/java/com/flarecorernapp/MainApplication.kt');
  assert.match(mainApplication, /add\(FlareImCoreSdkPackage\(\)\)/);

  const settings = read('android/settings.gradle');
  assert.match(settings, /include ':flare-core-android-sdk'/);

  const androidBuild = read('android/app/build.gradle');
  assert.match(androidBuild, /implementation\(project\(":flare-core-android-sdk"\)\)/);

  const androidSdkBuild = read('../../packages/flare-core-android-sdk/build.gradle.kts');
  assert.match(androidSdkBuild, /native\/artifacts\/android/);
  assert.doesNotMatch(androidSdkBuild, /abiFilters \+= "arm64-v8a"/);

  const iosModule = read(iosModulePath);
  assert.match(iosModule, /@objc\(FlareImCoreSdk\)/);
  assert.match(iosModule, /func invoke\([\s\S]*_ operation: String,[\s\S]*requestJson: String/);
  assert.match(iosModule, /diagnostics\.ffi_contract_version/);

  const iosBridge = read(iosBridgePath);
  assert.match(iosBridge, /RCT_EXTERN_MODULE\(FlareImCoreSdk, NSObject\)/);
  assert.match(iosBridge, /RCT_EXTERN_METHOD\(invoke:/);
});

test('TypeScript native host passes the generated descriptor to React Native modules', () => {
  const sdkBridge = read('../../packages/flare-core-typescript-sdk/src/bridge/ffiNativeBridge.ts');
  const sdkBridgeTemplate = read('../../../flare-core-sdk-engine/xtask/templates/bridge/typescript/bridge/ffiNativeBridge.ts');

  for (const source of [sdkBridge, sdkBridgeTemplate]) {
    assert.match(source, /invoke\(operation: string, requestJson: string, descriptorJson\?: string\)/);
    assert.match(source, /JSON\.stringify\(descriptor\)/);
    assert.match(source, /host\.invoke\(descriptor\.operation, payload, descriptorJson\)/);
  }
});

test('React Native login defaults to WebSocket and exposes native protocol selection', () => {
  const service = read('src/application/sdk/rnWorkbenchSdkService.ts');
  const loginScreen = read('src/components/auth/LoginScreen.tsx');
  const types = read('src/types.ts');
  const packageJson = read('package.json');

  assert.match(types, /export type LoginTransportMode = 'websocket' \| 'quic' \| 'race'/);
  assert.match(service, /transportMode:\s*'websocket'/);
  assert.match(service, /userId:\s*'11'/);
  assert.match(service, /buildNativeTransportConfig\(form\)/);
  assert.match(service, /generateCoreLoginToken/);
  assert.match(service, /generateCoreToken/);
  assert.match(service, /transportPolicy:\s*'websocket_only'/);
  assert.match(service, /protocolRaceOrder:\s*\['quic', 'websocket'\]/);
  assert.match(loginScreen, /transportOptions/);
  assert.match(loginScreen, /loginSelectRow/);
  assert.match(loginScreen, /Token 将根据用户 ID 自动生成/);
  assert.doesNotMatch(loginScreen, /粘贴 dev token|Token\s*</);
  assert.match(packageJson, /sync:dev-token-secret/);
  assert.match(packageJson, /scripts\/sync-dev-token-secret\.js/);
});
