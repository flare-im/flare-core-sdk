import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart';
import 'package:flare_core_flutter_update_ui/flare_core_flutter_update_ui.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show FlareColors, FlareResourceOverlay, FlareStrings, FlareTheme;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const FlareStrings _strings = FlareStrings();

const Map<String, Object?> _release = {
  'releaseId': 'rel',
  'version': '2.4.0',
  'build': 20400,
  'notes': ['Scheduled messages'],
  'sizeBytes': 52428800,
  'mandatory': false,
  'recommended': false,
  'kind': 'package',
};

Map<String, Object?> _status(
  String state, {
  Map<String, Object?>? release = _release,
  String prompt = 'none',
  bool readOnly = false,
  String? blockReason,
  Map<String, Object?>? error,
  int? lastCheckedAt,
}) =>
    {
      'state': state,
      'current': {
        'version': '2.3.2',
        'build': 20302,
        'channel': 'stable',
        'distribution': 'direct',
      },
      'release': release,
      'progress': null,
      'prompt': prompt,
      'blockUi': false,
      'readOnly': readOnly,
      'blockReason': blockReason,
      'lastCheckedAt': lastCheckedAt,
      'error': error,
    };

void main() {
  late _FakeEngine engine;

  Future<FlareUpdateController> pumpApp(
    WidgetTester tester,
    Map<String, Object?> initial, {
    Widget page = const Text('page'),
  }) async {
    engine = _FakeEngine()..answers[FlareUpdateOperations.getState] = initial;
    addTearDown(engine.close);
    final controller = FlareUpdateController(
      engine: engine,
      installer: const _FakeInstaller(),
    )..install();
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      FlareUpdateScope(
        controller: controller,
        child: MaterialApp(
          home: Scaffold(body: FlareUpdatePromptHost(child: page)),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();
    return controller;
  }

  group('FlareUpdatePromptHost', () {
    testWidgets('opens the prompt the engine asks for and marks it once',
        (tester) async {
      await pumpApp(tester, _status('available', prompt: 'sheet'));

      expect(find.text(_strings.updatePromptTitleAvailable), findsOneWidget);
      expect(engine.paramsOf(FlareUpdateOperations.markPrompted), [
        {'build': 20400, 'form': 'sheet'},
      ]);

      engine.events.add(
        _status('available', prompt: 'sheet', lastCheckedAt: 1),
      );
      await tester.pumpAndSettle();
      expect(engine.count(FlareUpdateOperations.markPrompted), 1);
    });

    testWidgets('a badge and nothing at all are no prompt', (tester) async {
      await pumpApp(tester, _status('available', prompt: 'badge'));

      expect(find.text(_strings.updatePromptTitleAvailable), findsNothing);
      expect(engine.count(FlareUpdateOperations.markPrompted), 0);
    });

    testWidgets('later closes it when the engine stops asking', (tester) async {
      await pumpApp(tester, _status('available', prompt: 'sheet'));
      engine.answers[FlareUpdateOperations.defer] =
          _status('available', prompt: 'badge');

      await tester.tap(find.text(_strings.updatePromptLater));
      await tester.pumpAndSettle();

      expect(engine.count(FlareUpdateOperations.defer), 1);
      expect(find.text(_strings.updatePromptTitleAvailable), findsNothing);
    });

    testWidgets('a forced prompt can stand before the release arrives',
        (tester) async {
      await pumpApp(
        tester,
        _status('required', release: null, prompt: 'modal'),
      );

      expect(find.text(_strings.updatePromptTitleRequired), findsOneWidget);
      expect(find.textContaining('2.3.2'), findsOneWidget);
      expect(engine.paramsOf(FlareUpdateOperations.markPrompted), [
        {'form': 'modal'},
      ]);
      expect(find.text(_strings.updatePromptLater), findsNothing);
    });

    testWidgets('a blocked build says why, in the words of the release',
        (tester) async {
      await pumpApp(
        tester,
        _status(
          'required',
          release: null,
          prompt: 'modal',
          blockReason: 'This build is no longer supported',
        ),
      );

      expect(find.text('This build is no longer supported'), findsOneWidget);
    });

    testWidgets('continuing read only goes to the engine', (tester) async {
      await pumpApp(
        tester,
        _status('required', release: null, prompt: 'modal'),
      );
      engine.answers[FlareUpdateOperations.defer] =
          _status('required', release: null, readOnly: true);

      await tester.tap(find.text(_strings.updatePromptContinueReadOnly));
      await tester.pumpAndSettle();

      expect(engine.count(FlareUpdateOperations.defer), 1);
      expect(find.text(_strings.updatePromptTitleRequired), findsNothing);
    });

    testWidgets('the fallback shows only with a link', (tester) async {
      final fallback = _strings.updatePromptFallbackWebsite;
      await pumpApp(
        tester,
        _status(
          'failed',
          prompt: 'sheet',
          error: {
            'code': FlareUpdateErrorCodes.downloadFailed,
            'retryable': true,
          },
        ),
      );
      expect(find.text(fallback), findsNothing);

      engine.events.add(
        _status(
          'failed',
          prompt: 'sheet',
          error: {
            'code': FlareUpdateErrorCodes.downloadFailed,
            'retryable': true,
            'fallbackUrl': 'https://example.com/download',
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(fallback), findsOneWidget);
    });
  });

  group('FlareUpdateScope', () {
    testWidgets('a page outside any scope is writable and has no badge',
        (tester) async {
      late bool readOnly;
      late bool badge;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              readOnly = FlareUpdateScope.readOnlyOf(context);
              badge = FlareUpdateScope.badgeOf(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(readOnly, isFalse);
      expect(badge, isFalse);
    });

    testWidgets('only what a widget asked for rebuilds it', (tester) async {
      var builds = 0;
      await pumpApp(
        tester,
        _status('available', prompt: 'badge'),
        page: Builder(
          builder: (context) {
            builds += 1;
            return Text(
              FlareUpdateScope.readOnlyOf(context) ? 'read only' : 'writable',
            );
          },
        ),
      );
      expect(find.text('writable'), findsOneWidget);
      final settled = builds;

      engine.events.add(
        _status('available', prompt: 'badge', lastCheckedAt: 1),
      );
      await tester.pumpAndSettle();
      expect(builds, settled);

      engine.events.add(
        _status('available', prompt: 'badge', readOnly: true),
      );
      await tester.pumpAndSettle();
      expect(find.text('read only'), findsOneWidget);
    });
  });

  group('FlareUpdateResourceScope', () {
    const stringsPack = {
      'id': 'strings',
      'kind': 'strings',
      'packVersion': 3,
      'contentJson': '{"schema":"flare.resource.v1","kind":"strings",'
          '"locales":{"en":{"send":"Send it"}}}',
    };
    const tokensPack = {
      'id': 'tokens',
      'kind': 'tokens',
      'packVersion': 1,
      'contentJson': '{"schema":"flare.resource.v1","kind":"tokens",'
          '"colors":{"primary":"#112233"},"dark":{"primary":"#445566"}}',
    };
    const lightPrimary = Color(0xFF112233);
    const darkPrimary = Color(0xFF445566);

    Future<void> pumpScope(
      WidgetTester tester, {
      List<Map<String, Object?>> packs = const [stringsPack],
      Widget child = const _ProbedStrings(),
      bool install = true,
      FlareUpdateController? existing,
      ThemeData Function(Brightness, FlareColors)? materialTheme,
      ValueChanged<FlareResourceOverlay>? onOverlay,
      ThemeMode themeMode = ThemeMode.light,
    }) async {
      final controller =
          existing ?? _controllerFor(packs, (made) => engine = made);
      addTearDown(controller.dispose);
      if (install) controller.install();
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          darkTheme: ThemeData(brightness: Brightness.dark),
          themeMode: themeMode,
          home: FlareUpdateResourceScope(
            controller: controller,
            locale: 'en',
            materialTheme: materialTheme,
            onOverlay: onOverlay,
            child: child,
          ),
        ),
      );
    }

    testWidgets('the built-in strings render first, then the pack',
        (tester) async {
      await pumpScope(tester);
      expect(find.text(_strings.send), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Send it'), findsOneWidget);
      expect(engine.count(FlareUpdateOperations.getResources), 1);
    });

    testWidgets('waits for the engine to be up', (tester) async {
      final controller = _controllerFor(
        const [stringsPack],
        (made) => engine = made,
      );
      await pumpScope(tester, install: false, existing: controller);
      await tester.pumpAndSettle();
      expect(engine.count(FlareUpdateOperations.getResources), 0);

      controller.install();
      await tester.pumpAndSettle();
      expect(engine.count(FlareUpdateOperations.getResources), 1);
      expect(find.text('Send it'), findsOneWidget);
    });

    testWidgets('a forced prompt opens with the packs on it', (tester) async {
      const titlePack = {
        'id': 'title',
        'kind': 'strings',
        'packVersion': 1,
        'contentJson': '{"schema":"flare.resource.v1","kind":"strings",'
            '"locales":{"en":{"updatePromptTitleRequired":"Pack title"}}}',
      };
      final controller = _controllerFor(
        const [titlePack],
        (made) => engine = made,
      );
      engine.answers[FlareUpdateOperations.getState] =
          _status('required', prompt: 'modal');
      await pumpScope(
        tester,
        existing: controller,
        child: FlareUpdateScope(
          controller: controller,
          child: const FlareUpdatePromptHost(child: Text('page')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pack title'), findsOneWidget);
      expect(find.text(_strings.updatePromptTitleRequired), findsNothing);
    });

    testWidgets('a read that hangs does not hold a forced prompt back',
        (tester) async {
      final controller = _controllerFor(const [], (made) => engine = made);
      engine.answers[FlareUpdateOperations.getState] =
          _status('required', prompt: 'modal');
      engine.hanging.add(FlareUpdateOperations.getResources);
      await pumpScope(
        tester,
        existing: controller,
        child: FlareUpdateScope(
          controller: controller,
          child: const FlareUpdatePromptHost(child: Text('page')),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text(_strings.updatePromptTitleRequired), findsNothing);

      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text(_strings.updatePromptTitleRequired), findsOneWidget);
    });

    testWidgets('no packs leave the built-in strings', (tester) async {
      await pumpScope(tester, packs: const []);
      await tester.pumpAndSettle();
      expect(find.text(_strings.send), findsOneWidget);
    });

    testWidgets('a token pack reaches the theme', (tester) async {
      await pumpScope(
        tester,
        packs: const [tokensPack],
        child: const _ProbedPrimary(),
      );
      await tester.pumpAndSettle();
      expect(find.text('${lightPrimary.toARGB32()}'), findsOneWidget);
    });

    testWidgets('a token pack reaches the dark theme on its own colours',
        (tester) async {
      await pumpScope(
        tester,
        packs: const [tokensPack],
        child: const _ProbedPrimary(),
        themeMode: ThemeMode.dark,
      );
      await tester.pumpAndSettle();
      expect(find.text('${darkPrimary.toARGB32()}'), findsOneWidget);
    });

    testWidgets('a subtree on its own brightness follows it', (tester) async {
      await pumpScope(
        tester,
        packs: const [tokensPack],
        child: Column(
          children: [
            const _ProbedPrimary(),
            Theme(
              data: ThemeData(brightness: Brightness.dark),
              child: const _ProbedPrimary(),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('${lightPrimary.toARGB32()}'), findsOneWidget);
      expect(find.text('${darkPrimary.toARGB32()}'), findsOneWidget);
    });

    testWidgets('a pack for one mode leaves the other built in',
        (tester) async {
      const lightOnly = {
        'id': 'tokens',
        'kind': 'tokens',
        'packVersion': 1,
        'contentJson': '{"schema":"flare.resource.v1","kind":"tokens",'
            '"colors":{"primary":"#112233"}}',
      };
      await pumpScope(
        tester,
        packs: const [lightOnly],
        child: Theme(
          data: ThemeData(brightness: Brightness.dark),
          child: const _ProbedPrimary(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('${FlareColors.dark.primary.toARGB32()}'),
        findsOneWidget,
      );
    });

    testWidgets('no token pack leaves the colours unset', (tester) async {
      await pumpScope(tester);
      await tester.pumpAndSettle();
      final theme = FlareTheme.maybeOf(
        tester.element(find.byType(_ProbedStrings)),
      );
      expect(theme?.colors, isNull);
      expect(theme?.darkColors, isNull);
    });

    testWidgets('the Material theme is derived again from a token pack',
        (tester) async {
      final seen = <(Brightness, Color)>[];
      await pumpScope(
        tester,
        packs: const [tokensPack],
        child: const _ProbedCanvas(),
        materialTheme: (brightness, colors) {
          seen.add((brightness, colors.primary));
          return ThemeData(
            brightness: brightness,
            scaffoldBackgroundColor: colors.primary,
          );
        },
      );
      expect(seen, isEmpty, reason: 'built-in colours keep the theme above');

      await tester.pumpAndSettle();
      expect(find.text('${lightPrimary.toARGB32()}'), findsOneWidget);
      expect(seen, [(Brightness.light, lightPrimary)]);
    });

    testWidgets('the Material theme takes the colours of the mode on screen',
        (tester) async {
      await pumpScope(
        tester,
        packs: const [tokensPack],
        child: const _ProbedCanvas(),
        themeMode: ThemeMode.dark,
        materialTheme: (brightness, colors) => ThemeData(
          brightness: brightness,
          scaffoldBackgroundColor: colors.primary,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('${darkPrimary.toARGB32()}'), findsOneWidget);
    });

    testWidgets('a pack without tokens leaves the Material theme alone',
        (tester) async {
      var derived = 0;
      await pumpScope(
        tester,
        child: const _ProbedCanvas(),
        materialTheme: (brightness, colors) {
          derived += 1;
          return ThemeData(brightness: brightness);
        },
      );
      await tester.pumpAndSettle();
      expect(derived, 0);
    });

    testWidgets('a rebuild derives no new Material theme', (tester) async {
      var derived = 0;
      await pumpScope(
        tester,
        packs: const [tokensPack],
        child: const _ProbedCanvas(),
        materialTheme: (brightness, colors) {
          derived += 1;
          return ThemeData(brightness: brightness);
        },
      );
      await tester.pumpAndSettle();

      tester.state<State>(find.byType(FlareUpdateResourceScope))
          // ignore: invalid_use_of_protected_member
          .setState(() {});
      await tester.pump();

      expect(derived, 1);
    });

    testWidgets('the host hears of the overlay when it arrives',
        (tester) async {
      final heard = <FlareResourceOverlay>[];
      await pumpScope(tester, onOverlay: heard.add);
      await tester.pumpAndSettle();
      expect(heard, hasLength(1));
      expect(heard.single.isEmpty, isFalse);
    });

    testWidgets('no packs say nothing to the host', (tester) async {
      final heard = <FlareResourceOverlay>[];
      await pumpScope(tester, packs: const [], onOverlay: heard.add);
      await tester.pumpAndSettle();
      expect(heard, isEmpty);
    });

    testWidgets('the tree keeps its state when the overlay arrives',
        (tester) async {
      await pumpScope(tester, child: const _Counted());
      final before = tester.state<_CountedState>(find.byType(_Counted));

      await tester.pumpAndSettle();

      expect(tester.state<_CountedState>(find.byType(_Counted)), same(before));
    });

    testWidgets('a rebuild keeps the same strings', (tester) async {
      await pumpScope(tester);
      await tester.pumpAndSettle();
      final element = tester.element(find.byType(_ProbedStrings));
      final first = FlareStrings.of(element);

      tester.state<State>(find.byType(FlareUpdateResourceScope))
          // ignore: invalid_use_of_protected_member
          .setState(() {});
      await tester.pump();

      expect(FlareStrings.of(element), same(first));
    });
  });

  group('FlareUpdateVersionPanel', () {
    testWidgets('shows the running version and checks by hand', (tester) async {
      await pumpApp(
        tester,
        _status('upToDate', release: null),
        page: const SingleChildScrollView(child: FlareUpdateVersionPanel()),
      );

      expect(find.text('2.3.2'), findsOneWidget);
      expect(find.text('20302'), findsOneWidget);

      await tester.tap(find.text(_strings.versionPanelCheck));
      await tester.pumpAndSettle();

      expect(engine.paramsOf(FlareUpdateOperations.check), [
        {'manual': true},
      ]);
    });
  });
}

FlareUpdateController _controllerFor(
  List<Map<String, Object?>> packs,
  void Function(_FakeEngine engine) made,
) {
  final engine = _FakeEngine()
    ..answers[FlareUpdateOperations.getState] = _status('idle', release: null)
    ..answers[FlareUpdateOperations.getResources] = {'packs': packs};
  addTearDown(engine.close);
  made(engine);
  return FlareUpdateController(
    engine: engine,
    installer: const _FakeInstaller(),
  );
}

class _ProbedStrings extends StatelessWidget {
  const _ProbedStrings();

  @override
  Widget build(BuildContext context) => Text(FlareStrings.of(context).send);
}

class _ProbedPrimary extends StatelessWidget {
  const _ProbedPrimary();

  @override
  Widget build(BuildContext context) =>
      Text('${FlareColors.of(context).primary.toARGB32()}');
}

class _ProbedCanvas extends StatelessWidget {
  const _ProbedCanvas();

  @override
  Widget build(BuildContext context) =>
      Text('${Theme.of(context).scaffoldBackgroundColor.toARGB32()}');
}

class _Counted extends StatefulWidget {
  const _Counted();

  @override
  State<_Counted> createState() => _CountedState();
}

class _CountedState extends State<_Counted> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

final class _FakeEngine implements FlareUpdateEngine {
  final List<({String operation, Map<String, Object?> params})> calls = [];
  final Map<String, Map<String, Object?>> answers = {};
  final Set<String> hanging = {};
  final StreamController<Map<String, Object?>> events =
      StreamController<Map<String, Object?>>.broadcast();

  Future<void> close() => events.close();

  @override
  Future<Map<String, Object?>> dispatch(
    String operation, [
    Map<String, Object?> params = const {},
  ]) async {
    calls.add((operation: operation, params: params));
    if (hanging.contains(operation)) await Completer<void>().future;
    return answers[operation] ?? answers[FlareUpdateOperations.getState]!;
  }

  @override
  Stream<Map<String, Object?>> stateEvents() => events.stream;

  int count(String operation) =>
      calls.where((call) => call.operation == operation).length;

  List<Map<String, Object?>> paramsOf(String operation) => calls
      .where((call) => call.operation == operation)
      .map((call) => call.params)
      .toList();
}

final class _FakeInstaller implements FlareUpdateInstaller {
  const _FakeInstaller();

  @override
  Future<FlareUpdateInstallResult> execute(FlareUpdateInstallPlan plan) async =>
      const FlareUpdateInstallResult(FlareUpdateOutcome.completed);

  @override
  Future<bool> canPrompt(FlareUpdateRelease release) async => true;

  @override
  Stream<FlareUpdateHandoff> handoffs() =>
      const Stream<FlareUpdateHandoff>.empty();

  @override
  Future<FlareUpdateInstallResult> completeHandoff() async =>
      const FlareUpdateInstallResult(FlareUpdateOutcome.completed);
}
