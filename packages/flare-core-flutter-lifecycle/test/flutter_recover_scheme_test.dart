import 'dart:io';

import 'package:flare_core_flutter_lifecycle/flare_core_flutter_lifecycle.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Stands in for `reg` and `xdg-mime`: no test runs either.
final class _FakeCommands {
  _FakeCommands(this.answer);

  /// What a command prints; the executable comes first in [call].
  final String Function(List<String> call) answer;
  final calls = <List<String>>[];

  Future<String> call(String executable, List<String> arguments) async {
    final call = [executable, ...arguments];
    calls.add(call);
    return answer(call);
  }
}

void main() {
  group('flutterLaunchLink', () {
    test('finds the link among the arguments, as it came', () {
      expect(
        flutterLaunchLink(const ['--flag', 'flare-recover://v1?p=a&k=b&s=c']),
        'flare-recover://v1?p=a&k=b&s=c',
      );
      expect(
        flutterLaunchLink(const ['FLARE-RECOVER://v1?p=a']),
        'FLARE-RECOVER://v1?p=a',
      );
    });

    test('takes the first of several', () {
      expect(
        flutterLaunchLink(const [
          'flare-recover://v1?p=a',
          'flare-recover://v1?p=b',
        ]),
        'flare-recover://v1?p=a',
      );
    });

    test('leaves every other argument alone', () {
      expect(flutterLaunchLink(const []), isNull);
      expect(flutterLaunchLink(const ['']), isNull);
      expect(flutterLaunchLink(const ['flare-recover:v1']), isNull);
      expect(flutterLaunchLink(const ['https://example.com/v1?p=a']), isNull);
      expect(
        flutterLaunchLink(const ['--link=flare-recover://v1?p=a']),
        isNull,
      );
    });
  });

  group('Windows', () {
    const executable = r'C:\Program Files\Flare\flare.exe';
    const reg = r'D:\Win\System32\reg.exe';
    const key = r'HKCU\Software\Classes\flare-recover';
    const open = r'"C:\Program Files\Flare\flare.exe" "%1"';

    String declared(String command, {bool urlProtocol = true}) => [
          r'HKEY_CURRENT_USER\Software\Classes\flare-recover',
          '    (Default)    REG_SZ    URL:Flare IM',
          if (urlProtocol) '    URL Protocol    REG_SZ    ',
          '',
          r'HKEY_CURRENT_USER\Software\Classes\flare-recover\shell\open\command',
          '    (Default)    REG_SZ    $command',
          '',
        ].join('\r\n');

    Future<void> register(_FakeCommands commands) =>
        registerFlutterRecoverScheme(
          desktopId: 'com.flare.test.recover',
          appName: 'Flare IM',
          platform: TargetPlatform.windows,
          release: true,
          executable: executable,
          environment: const {'SystemRoot': r'D:\Win'},
          run: commands.call,
        );

    /// The registry as the commands leave it: empty until the open command is
    /// written, unless [before] says otherwise.
    _FakeCommands registry({String before = ''}) {
      var current = before;
      return _FakeCommands((call) {
        if (call[1] == 'query') return current;
        if (call[2].endsWith('command')) current = declared(open);
        return '';
      });
    }

    test('writes the scheme under the user, the open command last', () async {
      final commands = registry();

      await register(commands);

      expect(commands.calls, [
        [reg, 'query', key, '/s'],
        [reg, 'add', key, '/ve', '/d', 'URL:Flare IM', '/f'],
        [reg, 'add', key, '/v', 'URL Protocol', '/d', '', '/f'],
        [reg, 'add', '$key\\shell\\open\\command', '/ve', '/d', open, '/f'],
        [reg, 'query', key, '/s'],
      ]);
    });

    test('finds reg in the default folder when the variable is missing',
        () async {
      final commands = registry(before: declared(open));

      await registerFlutterRecoverScheme(
        desktopId: 'com.flare.test.recover',
        appName: 'Flare IM',
        platform: TargetPlatform.windows,
        release: true,
        executable: executable,
        environment: const {},
        run: commands.call,
      );

      expect(commands.calls.single.first, r'C:\Windows\System32\reg.exe');
    });

    test('already registered at this path writes nothing', () async {
      final commands = registry(before: declared(open));

      await register(commands);

      expect(commands.calls, [
        [reg, 'query', key, '/s'],
      ]);
    });

    test('a moved executable writes the scheme again', () async {
      final commands = registry(before: declared(r'"C:\Old\flare.exe" "%1"'));

      await register(commands);

      expect(commands.calls.where((call) => call[1] == 'add'), hasLength(3));
    });

    test('a registration cut short is written again', () async {
      final commands = registry(before: declared(open, urlProtocol: false));

      await register(commands);

      expect(commands.calls.where((call) => call[1] == 'add'), hasLength(3));
    });

    test('a write that does not take only logs', () async {
      final commands = _FakeCommands((_) => '');

      await expectLater(register(commands), completes);

      expect(commands.calls, hasLength(5));
    });

    test('a command that cannot start only logs', () async {
      final commands = _FakeCommands(
        (_) => throw const ProcessException('reg', [], 'not found', 2),
      );

      await expectLater(register(commands), completes);

      expect(commands.calls, hasLength(1));
    });
  });

  group('Linux', () {
    const desktopId = 'com.flare.test.recover';
    const executable = '/opt/flare/flare';
    const mime = 'x-scheme-handler/flare-recover';
    const query = ['xdg-mime', 'query', 'default', mime];
    const makeDefault = ['xdg-mime', 'default', '$desktopId.desktop', mime];
    const entry = '[Desktop Entry]\n'
        'Type=Application\n'
        'Name=Flare IM\n'
        'Exec="/opt/flare/flare" %u\n'
        'Terminal=false\n'
        'NoDisplay=true\n'
        'MimeType=x-scheme-handler/flare-recover;\n';

    late Directory home;

    setUp(() async {
      home = await Directory.systemTemp.createTemp('flare_recover_scheme');
    });

    tearDown(() => home.delete(recursive: true));

    File entryFile([String? dataHome]) => File(
          '${dataHome ?? '${home.path}/.local/share'}'
          '/applications/$desktopId.desktop',
        );

    Future<void> register(
      _FakeCommands commands, {
      String path = executable,
      Map<String, String>? environment,
    }) =>
        registerFlutterRecoverScheme(
          desktopId: desktopId,
          appName: 'Flare IM',
          platform: TargetPlatform.linux,
          release: true,
          executable: path,
          environment: environment ?? {'HOME': home.path},
          run: commands.call,
        );

    /// `xdg-mime` as it behaves: the query prints what `default` last set.
    _FakeCommands xdgMime({String before = ''}) {
      var current = before;
      return _FakeCommands((call) {
        if (call[1] == 'default') current = call[2];
        return call[1] == 'query' ? '$current\n' : '';
      });
    }

    test('writes the user entry and makes it the default', () async {
      final commands = xdgMime();

      await register(commands);

      expect(await entryFile().readAsString(), entry);
      expect(commands.calls, [query, makeDefault, query]);
    });

    test('writes where XDG_DATA_HOME says', () async {
      final dataHome = '${home.path}/data';

      await register(
        xdgMime(),
        environment: {'HOME': home.path, 'XDG_DATA_HOME': dataHome},
      );

      expect(await entryFile(dataHome).exists(), isTrue);
      expect(await entryFile().exists(), isFalse);
    });

    test('a relative XDG_DATA_HOME is ignored', () async {
      await register(
        xdgMime(),
        environment: {'HOME': home.path, 'XDG_DATA_HOME': 'data'},
      );

      expect(await entryFile().exists(), isTrue);
    });

    test('already registered at this path writes nothing', () async {
      await register(xdgMime());
      final file = entryFile();
      final written = DateTime(2020);
      await file.setLastModified(written);
      final commands = xdgMime(before: '$desktopId.desktop');

      await register(commands);

      expect(commands.calls, [query]);
      expect(await file.lastModified(), written);
    });

    test('a moved executable rewrites the entry', () async {
      await register(xdgMime());
      final commands = xdgMime(before: '$desktopId.desktop');

      await register(commands, path: '/usr/lib/flare/flare');

      expect(
        await entryFile().readAsString(),
        contains('Exec="/usr/lib/flare/flare" %u\n'),
      );
      expect(commands.calls, [query]);
    });

    test('a scheme another app took is taken back, the entry untouched',
        () async {
      await register(xdgMime());
      final file = entryFile();
      final written = DateTime(2020);
      await file.setLastModified(written);
      final commands = xdgMime(before: 'other.desktop');

      await register(commands);

      expect(commands.calls, [query, makeDefault, query]);
      expect(await file.lastModified(), written);
    });

    test('escapes a path for Exec', () async {
      await register(xdgMime(), path: r'/opt/a b/$c"d%e\f`g');

      expect(
        await entryFile().readAsString(),
        contains(r'Exec="/opt/a b/\\$c\\"d%%e\\\\f\\`g" %u' '\n'),
      );
    });

    test('no xdg-mime still leaves the entry, and only logs', () async {
      final commands = _FakeCommands(
        (_) => throw const ProcessException('xdg-mime', [], 'not found', 2),
      );

      await expectLater(register(commands), completes);

      expect(await entryFile().readAsString(), entry);
    });

    test('a default that does not take only logs', () async {
      final commands = _FakeCommands((_) => 'other.desktop\n');

      await expectLater(register(commands), completes);

      expect(commands.calls, [query, makeDefault, query]);
    });

    test('no home directory runs nothing, and only logs', () async {
      final commands = xdgMime();

      await expectLater(
        register(commands, environment: const {}),
        completes,
      );

      expect(commands.calls, isEmpty);
    });
  });

  group('runs nothing', () {
    Future<List<List<String>>> callsOf({
      required TargetPlatform platform,
      required bool release,
    }) async {
      final commands = _FakeCommands((_) => '');
      await registerFlutterRecoverScheme(
        desktopId: 'com.flare.test.recover',
        appName: 'Flare IM',
        platform: platform,
        release: release,
        executable: '/opt/flare/flare',
        environment: const {},
        run: commands.call,
      );
      return commands.calls;
    }

    test('outside a release build', () async {
      for (final platform in [TargetPlatform.windows, TargetPlatform.linux]) {
        expect(await callsOf(platform: platform, release: false), isEmpty);
      }
    });

    test('on the platforms that declare the scheme in the bundle', () async {
      for (final platform in [
        TargetPlatform.macOS,
        TargetPlatform.iOS,
        TargetPlatform.android,
      ]) {
        expect(await callsOf(platform: platform, release: true), isEmpty);
      }
    });
  });
}
