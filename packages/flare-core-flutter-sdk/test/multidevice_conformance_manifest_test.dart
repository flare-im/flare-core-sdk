import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  test('multi-device conformance manifest covers Web and Flutter', () {
    final file = File(
      '../../examples/multidevice_conformance.json',
    );
    expect(file.existsSync(), isTrue);

    final manifest =
        jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    expect(manifest['schema'], 'flare.im.examples.multidevice.conformance.v1');
    expect(manifest['clients'], ['web', 'flutter']);

    final scenarios = (manifest['scenarios'] as List<Object?>)
        .map((item) => item as Map<String, Object?>)
        .toList(growable: false);
    final ids = scenarios
        .map((scenario) => scenario['id'])
        .toList(growable: false);
    expect(ids, [
      'message_fanout',
      'read_state_roaming',
      'draft_roaming',
      'device_kick',
      'typing_device_attribution',
    ]);

    for (final scenario in scenarios) {
      expect((scenario['title'] as String).trim(), isNotEmpty);
      expect((scenario['requires'] as List<Object?>), isNotEmpty);
      expect((scenario['steps'] as List<Object?>).length, greaterThan(1));
      expect((scenario['webEntrypoints'] as List<Object?>), isNotEmpty);
      expect((scenario['flutterEntrypoints'] as List<Object?>), isNotEmpty);
      expect((scenario['observables'] as List<Object?>), isNotEmpty);
    }
  });
}
