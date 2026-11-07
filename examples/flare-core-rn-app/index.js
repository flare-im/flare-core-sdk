import 'react-native-gesture-handler';
import { AppRegistry, NativeModules } from 'react-native';
import App from './src/screens/App';
import { name as appName } from './app.json';

globalThis.nativeModules = NativeModules;

try {
  globalThis.__FLARE_RN_DEV_TOKEN_SECRET__ = require('./.generated/dev-token-secret.json').secret || '';
} catch {
  globalThis.__FLARE_RN_DEV_TOKEN_SECRET__ = '';
}

// Where to connect: the access configuration the bundle was built with (scripts/sync-access-config.js).
try {
  globalThis.__FLARE_ACCESS_JSON__ = require('./.generated/flare-access.json').json || '';
} catch {
  globalThis.__FLARE_ACCESS_JSON__ = '';
}

const flareNativeModule = NativeModules.FlareImCoreSdk;
if (flareNativeModule?.invoke) {
  globalThis.__FLARE_IM_CORE_NATIVE__ = {
    invoke: flareNativeModule.invoke.bind(flareNativeModule),
  };
}

AppRegistry.registerComponent(appName, () => App);
