import 'dart:io';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:test/test.dart';

void main() {
  final library = Platform.environment['FLARE_PLUGIN_TEST_FFI_LIBRARY'];
  final gateway = Platform.environment['FLARE_PLUGIN_TEST_HTTP_URL'];
  test('actual Dart native preparation and plugin dispatch', () async {
    final directory =
        await Directory.systemTemp.createTemp('flare-plugin-dart-');
    final client = FlareCoreSdk.createClient(libraryPath: library!);
    try {
      await client.init({
        'dataUrl': directory.uri.toString(),
        'tenantId': '201',
        'access': {
          'trustMode': 'development',
          'developmentEndpoints': {'coreApiUrl': gateway!},
        },
      });
      await client.prepare({'userId': 'u1'});
      final message = <String, Object?>{
        'pluginId': 'example.poll',
        'contributionId': 'example.poll.card',
        'schemaVersion': 1,
        'summary': 'Poll history',
        'payload': {
          'pollId': 'poll-1',
          'question': 'Question',
          'tenantId': 'forged'
        }
      };
      for (final platform in [
        'web',
        'tauri',
        'android',
        'ios',
        'flutter',
        'harmonyos'
      ]) {
        final view = await client.capabilities.presentPluginMessage(
            PluginUiEvaluationRequest(payload: {
          'message': message,
          'platform': platform,
          'locale': 'en-US'
        }));
        expect(view['available'], isTrue);
        expect(view['title'], 'Poll');
        final result = await client.capabilities
            .invokePluginAction(PluginUiEvaluationRequest(payload: {
          'message': message,
          'platform': platform,
          'actionId': 'vote',
          'conversationId': 'conversation-1',
          'userGesture': true,
          'nativeAllowlist': <String>[]
        }));
        expect(result['kind'], 'operation');
      }
      final command=PluginCommandRequest(payload:{'slot':'example.create','command':{'commandId':'stable-dart-command','capabilityId':'example.poll.vote','conversationId':'conversation-1','payload':{'pollId':'poll-1'}}});
      await client.capabilities.preparePluginCommand(command);
      final submit=PluginCommandRequest(payload:{'slot':'example.create','commandId':'stable-dart-command'});
      await expectLater(client.capabilities.acknowledgePluginCommand(submit),throwsA(isA<FlareSdkException>()));
      final completed=await client.capabilities.submitPluginCommand(submit);
      expect((completed['response'] as Map)['success'],isTrue);
      expect(await client.capabilities.submitPluginCommand(submit),completed);
      await client.capabilities.acknowledgePluginCommand(submit);
      await client.capabilities.preparePluginCommand(PluginCommandRequest(payload:{'slot':'observe','command':{'commandId':'observed-dart','capabilityId':'example.poll.vote','reconciliationCapabilityId':'example.poll.lookup','conversationId':'conversation-1','payload':{'commandId':'observed-dart','pollId':'poll-1'}}}));
      final lookup=PluginCommandRequest(payload:{'slot':'observe','commandId':'observed-dart'});
      final observation=await client.capabilities.reconcilePluginCommand(lookup);
      expect(observation['outcome'],'committed');
      expect((await client.capabilities.submitPluginCommand(lookup))['response'],(observation['record'] as Map)['response']);
      await client.capabilities.acknowledgePluginCommand(lookup);

      expect(await client.capabilities.pendingPluginCommand(PluginCommandRequest(payload:{'slot':'example.create'})),{'record':null});
      await client.logout();
      await expectLater(client.capabilities.pendingPluginCommand(PluginCommandRequest(payload:{'slot':'example.create'})),throwsA(isA<FlareSdkException>()));
      await expectLater(
          client.capabilities.presentPluginMessage(PluginUiEvaluationRequest(
              payload: {'message': message, 'platform': 'flutter'})),
          throwsA(isA<FlareSdkException>()));
    } finally {
      await client.uninit();
      await client.dispose();
      await directory.delete(recursive: true);
    }
  },
      skip: library == null || gateway == null
          ? 'requires an explicitly built native library and owned HTTP fixture'
          : false);
}
