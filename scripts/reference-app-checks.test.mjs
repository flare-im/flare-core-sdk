import { test } from 'node:test';
import assert from 'node:assert/strict';
import { checkPublicApi, checkDuplicateUi, checkStyleOwnership } from './reference-app-checks.mjs';

test('public API gate reads import/export nodes, including lazy imports', () => {
  assert.deepEqual(checkPublicApi('view.ts', 'import { FlareComposer } from "@flare-im/vue-ui/components"'), []);
  assert.equal(checkPublicApi('view.vue', '<script setup>const x = import("@flare-im/vue-ui/src/private.vue")</script>').length, 1);
  assert.equal(checkPublicApi('view.dart', "export 'package:flare_im_ui/src/components/hidden.dart';").length, 1);
});
test('relocation into shared composition cannot conceal a duplicate', () => {
  assert.equal(checkDuplicateUi('../flare-core-examples/shared/view.vue', '<template><n-modal /></template>').length, 1);
  assert.equal(checkDuplicateUi('view.swift', 'struct HeaderIconButton: View {}').length, 1);
  assert.equal(checkDuplicateUi('view.kt', 'object FlareType {}').length, 1);
  assert.equal(checkDuplicateUi('view.vue', '<template><NModal /></template>').length, 1);
  assert.deepEqual(checkDuplicateUi('SdkLab.vue', '<template><n-button /></template>'), []);
});
test('public selector and local native palette overrides fail', () => {
  assert.equal(checkStyleOwnership('view.vue', '<style scoped>.x :deep(.flare-composer) { color:red !important }</style>').length, 2);
  assert.equal(checkStyleOwnership('view.dart', 'final c = Color(0xff112233);').length, 1);
  assert.deepEqual(checkStyleOwnership('root.css', 'html, body { height: 100%; }'), []);
});
