import 'dart:io';

import 'package:flutter/foundation.dart';

const String _scheme = 'flare-recover';

/// Custom URL schemes this host declares. Core Recovery is always included.
///
/// Share one configuration between registration and opened-link delivery. This
/// only selects OS input; the receiving SDK validates the unchanged raw URL.
final class FlutterLinkSchemes {
  const FlutterLinkSchemes({this.additionalSchemes = const []});

  final List<String> additionalSchemes;

  List<String> get values {
    final result = <String>[_scheme];
    for (final raw in additionalSchemes) {
      final scheme = raw.toLowerCase();
      if (!RegExp(r'^[a-z][a-z0-9+.-]*$').hasMatch(scheme) ||
          scheme == 'http' ||
          scheme == 'https') {
        throw ArgumentError.value(
            raw, 'additionalSchemes', 'custom scheme required');
      }
      if (!result.contains(scheme)) result.add(scheme);
    }
    return List.unmodifiable(result);
  }
}

/// Runs a command and gives what it printed; throws when it cannot start.
///
/// There is no exit code: a registration is read back to see that it took.
typedef RecoverSchemeCommand = Future<String> Function(
  String executable,
  List<String> arguments,
);

/// The recovery link among `main`'s arguments; null when there is none.
///
/// Windows and Linux start the app with the link as an argument. The rest of
/// the arguments are not read, so what a crafted link adds to the command line
/// goes nowhere. The core verifies the link.
String? flutterLaunchLink(
  List<String> arguments, {
  FlutterLinkSchemes schemes = const FlutterLinkSchemes(),
}) {
  final configured = schemes.values;
  for (final argument in arguments) {
    if (configured
        .any((scheme) => argument.toLowerCase().startsWith('$scheme://')))
      return argument;
  }
  return null;
}

/// Makes this executable the current user's handler of [schemes] on
/// Windows and Linux. Release builds only: a debug build would take the scheme
/// away from the installed app. Other platforms declare it in the app bundle.
///
/// Call it at startup without waiting for it. Only what is out of date is
/// written, nothing outside the user's own settings, and a failure is logged:
/// the app starts either way.
///
/// [desktopId] names the Linux desktop entry. Keep it apart from the app's own
/// id: the entry stays out of the menus, and a user-level entry hides an
/// installed one of the same name. [appName] is what the system shows for the
/// handler.
Future<void> registerFlutterRecoverScheme({
  required String desktopId,
  required String appName,
  TargetPlatform? platform,
  bool release = kReleaseMode,
  String? executable,
  Map<String, String>? environment,
  RecoverSchemeCommand run = _runCommand,
  FlutterLinkSchemes schemes = const FlutterLinkSchemes(),
}) async {
  // Validate the entire declaration before any registry, file or command effect.
  final configured = schemes.values;
  if (kIsWeb || !release) return;
  final target = platform ?? defaultTargetPlatform;
  if (target != TargetPlatform.windows && target != TargetPlatform.linux) {
    return;
  }
  try {
    final path = executable ?? Platform.resolvedExecutable;
    final variables = environment ?? Platform.environment;
    if (target == TargetPlatform.windows) {
      for (final scheme in configured) {
        await _registerWindows(scheme, appName, path, variables, run);
      }
    } else {
      await _registerLinux(
          configured, desktopId, appName, path, variables, run);
    }
  } catch (error) {
    _log('$error');
  }
}

/// The open command goes in last, and the read covers the whole key: a
/// registration cut short reads as out of date and is written again.
Future<void> _registerWindows(
  String scheme,
  String appName,
  String executable,
  Map<String, String> environment,
  RecoverSchemeCommand run,
) async {
  // By full path: Windows looks in the working directory for a bare name, and
  // a link can start the app in any folder, Downloads for one.
  final reg = '${environment['SystemRoot'] ?? r'C:\Windows'}'
      r'\System32\reg.exe';
  final windowsKey = 'HKCU\\Software\\Classes\\$scheme';
  final open = '"$executable" "%1"';

  Future<bool> registered() async {
    final declared = await run(reg, ['query', windowsKey, '/s']);
    return declared.contains('URL Protocol') && declared.contains(open);
  }

  if (await registered()) return;
  await run(reg, ['add', windowsKey, '/ve', '/d', 'URL:$appName', '/f']);
  await run(reg, ['add', windowsKey, '/v', 'URL Protocol', '/d', '', '/f']);
  await run(reg, [
    'add',
    '$windowsKey\\shell\\open\\command',
    '/ve',
    '/d',
    open,
    '/f',
  ]);
  if (!await registered()) _log('the registry did not take it');
}

Future<void> _registerLinux(
  List<String> schemes,
  String desktopId,
  String appName,
  String executable,
  Map<String, String> environment,
  RecoverSchemeCommand run,
) async {
  final desktopFile = '$desktopId.desktop';
  final file = File('${_linuxDataHome(environment)}/applications/$desktopFile');
  final entry = _linuxDesktopEntry(schemes, appName, executable);
  if (!await file.exists() || await file.readAsString() != entry) {
    await file.create(recursive: true);
    await file.writeAsString(entry, flush: true);
  }

  for (final scheme in schemes) {
    final mimeType = 'x-scheme-handler/$scheme';
    Future<bool> isDefault() async {
      final current = await run('xdg-mime', ['query', 'default', mimeType]);
      return current.trim() == desktopFile;
    }

    if (await isDefault()) continue;
    await run('xdg-mime', ['default', desktopFile, mimeType]);
    if (!await isDefault()) _log('xdg-mime did not take it');
  }
}

/// Where the desktop looks for a user's entries; a relative `XDG_DATA_HOME` is
/// to be ignored.
String _linuxDataHome(Map<String, String> environment) {
  final configured = environment['XDG_DATA_HOME'];
  if (configured != null && configured.startsWith('/')) return configured;
  final home = environment['HOME'];
  if (home == null || home.isEmpty) throw StateError('no home directory');
  return '$home/.local/share';
}

String _linuxDesktopEntry(
        List<String> schemes, String appName, String executable) =>
    '''
[Desktop Entry]
Type=Application
Name=$appName
Exec=${_linuxExecWord(executable)} %u
Terminal=false
NoDisplay=true
MimeType=${schemes.map((scheme) => 'x-scheme-handler/$scheme;').join()}
''';

/// [path] as a word of `Exec`: quoted, then escaped again for being a string
/// value, with `%` kept from reading as a field code.
String _linuxExecWord(String path) {
  final quoted = path.replaceAllMapped(
    RegExp(r'["`$\\]'),
    (match) => '\\${match[0]}',
  );
  return '"${quoted.replaceAll(r'\', r'\\').replaceAll('%', '%%')}"';
}

/// Detached: `reg` is a console program and the app has no console, so Windows
/// would otherwise open a window for it at every start. A detached process has
/// no exit code, which is why callers read the outcome back.
Future<String> _runCommand(String executable, List<String> arguments) async {
  final process = await Process.start(
    executable,
    arguments,
    mode: ProcessStartMode.detachedWithStdio,
  );
  final errors = process.stderr.drain<void>();
  final output = await process.stdout.transform(systemEncoding.decoder).join();
  await errors;
  return output;
}

void _log(String reason) =>
    debugPrint('[recover-scheme] not registered: $reason');
