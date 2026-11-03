#!/usr/bin/env node

const fs = require('node:fs');
const path = require('node:path');
const {spawnSync} = require('node:child_process');

const defaultAppRoot = path.resolve(__dirname, '..');

function listDirectory(dir) {
  if (!fs.existsSync(dir)) {
    return [];
  }

  return fs.readdirSync(dir);
}

function hasFile(dir, filename) {
  return fs.existsSync(path.join(dir, filename));
}

function hasAnyFile(dir, predicate) {
  return listDirectory(dir).some(predicate);
}

function printMissingNativeProject(platformName, checks) {
  const projectField = platformName === 'iOS' ? 'project.ios' : 'project.android';

  console.error(`[flare-core-rn-app] ${platformName} native project is not present.`);
  console.error('');
  console.error(
    'This repository currently commits only the React Native JS/TS example entry.',
  );
  console.error(
    `The native directory is a placeholder, so the React Native CLI resolves ${projectField} as null.`,
  );
  console.error('');
  console.error('Use the bundle scripts to validate the JS side:');
  console.error(`  npm run bundle:${platformName.toLowerCase()}`);
  console.error('');
  console.error('To run on a simulator or device, add a React Native 0.86 native');
  console.error('project and link the Flare native bridge from:');
  console.error('  ../../../flare-core-sdk-engine/bindings/c');
  console.error('');
  console.error('Missing checks:');
  checks.forEach((check) => console.error(`  - ${check}`));
}

function validateIosProject(appRoot = defaultAppRoot) {
  const iosDir = path.join(appRoot, 'ios');
  const missing = [];

  if (!fs.existsSync(iosDir)) {
    missing.push('ios/ directory');
  }

  if (
    !hasAnyFile(
      iosDir,
      (entry) => entry.endsWith('.xcodeproj') || entry.endsWith('.xcworkspace'),
    )
  ) {
    missing.push('ios/*.xcodeproj or ios/*.xcworkspace');
  }

  if (!hasFile(iosDir, 'Podfile')) {
    missing.push('ios/Podfile');
  }

  return missing;
}

function validateAndroidProject(appRoot = defaultAppRoot) {
  const androidDir = path.join(appRoot, 'android');
  const appDir = path.join(androidDir, 'app');
  const missing = [];

  if (!fs.existsSync(androidDir)) {
    missing.push('android/ directory');
  }

  if (
    !hasFile(androidDir, 'settings.gradle') &&
    !hasFile(androidDir, 'settings.gradle.kts')
  ) {
    missing.push('android/settings.gradle or android/settings.gradle.kts');
  }

  if (!hasFile(appDir, 'build.gradle') && !hasFile(appDir, 'build.gradle.kts')) {
    missing.push('android/app/build.gradle or android/app/build.gradle.kts');
  }

  return missing;
}

function runReactNative(command, forwardedArgs, appRoot = defaultAppRoot) {
  const executable = process.platform === 'win32' ? 'npx.cmd' : 'npx';
  const result = spawnSync(executable, ['react-native', command, ...forwardedArgs], {
    cwd: appRoot,
    stdio: 'inherit',
  });

  if (result.error) {
    console.error(result.error.message);
    process.exit(1);
  }

  process.exit(result.status ?? 1);
}

function main(argv = process.argv.slice(2), appRoot = defaultAppRoot) {
  const platform = argv[0];
  const forwardedArgs = argv.slice(1);

  if (platform === 'ios') {
    const missing = validateIosProject(appRoot);
    if (missing.length > 0) {
      printMissingNativeProject('iOS', missing);
      process.exit(1);
    }

    runReactNative('run-ios', forwardedArgs, appRoot);
  }

  if (platform === 'android') {
    const missing = validateAndroidProject(appRoot);
    if (missing.length > 0) {
      printMissingNativeProject('Android', missing);
      process.exit(1);
    }

    runReactNative('run-android', forwardedArgs, appRoot);
  }

  console.error('[flare-core-rn-app] expected platform: ios or android');
  process.exit(1);
}

if (require.main === module) {
  main();
}

module.exports = {
  main,
  validateAndroidProject,
  validateIosProject,
};
