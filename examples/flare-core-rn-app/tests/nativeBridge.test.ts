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

test('React Native connects where the bundle\'s access configuration says, with no server settings on sign-in', () => {
  const service = read('src/application/sdk/rnWorkbenchSdkService.ts');
  const loginScreen = read('src/components/auth/LoginScreen.tsx');
  const types = read('src/types.ts');
  const packageJson = read('package.json');
  const indexJs = read('index.js');

  assert.match(service, /userId:\s*'11'/);
  assert.match(service, /access:\s*buildAccessConfig\(\)/);
  assert.match(service, /client\.connection\.getStatus\(\)/);
  // The forbidden names are spelled from parts, so this test does not trip the repository grep gate it mirrors.
  const addressField = new RegExp(`\\b(${['ws', 'quic', 'http', 'gateway'].map((prefix) => `${prefix}Url`).join('|')})\\b`);
  for (const source of [service, loginScreen, types]) {
    assert.doesNotMatch(source, addressField);
    assert.doesNotMatch(source, /transportMode|transportPolicy|protocolRaceOrder|tlsCaCertPath/);
  }
  assert.doesNotMatch(service, new RegExp(['notify' + 'NetworkChange', 'setHeartbeat' + 'AppState', 'getConnection' + 'State'].join('|')));
  assert.match(loginScreen, /Token 将根据用户 ID 自动生成/);
  assert.doesNotMatch(loginScreen, /粘贴 dev token|Token\s*</);
  assert.match(packageJson, /sync:dev-token-secret/);
  assert.match(packageJson, /scripts\/sync-dev-token-secret\.js/);
  assert.match(packageJson, /"sync:access-config":\s*"node scripts\/sync-access-config\.js"/);
  assert.match(indexJs, /__FLARE_ACCESS_JSON__ = require\('\.\/\.generated\/flare-access\.json'\)\.json/);
});

