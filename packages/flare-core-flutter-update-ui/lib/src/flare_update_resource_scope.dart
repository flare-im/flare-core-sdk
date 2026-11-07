import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as sdk;
import 'package:flare_im_ui/flare_im_ui.dart' as kit;
import 'package:flutter/material.dart';

/// Puts this run's resource packs over the Kit's built-in strings, colours and
/// emoji for [child]. The built-in resources render first and the overlay
/// replaces them when it arrives; when it cannot be read they simply stay, and
/// the controller's `onError` has the reason.
///
/// It goes once at the root, under the `FlareStringsScope` and any `FlareTheme`
/// it goes over, and above the navigator so that pushed routes get it too.
///
/// That is below `MaterialApp`, so a Material theme derived from Kit colours
/// stays on the built-in ones unless [materialTheme] derives it again here.
class FlareUpdateResourceScope extends StatefulWidget {
  const FlareUpdateResourceScope({
    super.key,
    required this.controller,
    required this.locale,
    this.materialTheme,
    this.onOverlay,
    required this.child,
  });

  final sdk.FlareUpdateController controller;

  /// The language of the strings above.
  final String locale;

  /// The app's Material theme on the given Kit colours. It runs only when a
  /// token pack changed them; otherwise the theme above stands.
  final ThemeData Function(Brightness brightness, kit.FlareColors colors)?
  materialTheme;

  /// Told when the overlay arrives, for what lives outside this subtree or
  /// reads no Kit scope: the app's own strings, copy formatted off the tree.
  final ValueChanged<kit.FlareResourceOverlay>? onOverlay;

  final Widget child;

  /// Whether the packs above [context] are read, or there is no scope to wait
  /// for. A route copies the Kit's scopes when it opens, so a prompt that opened
  /// before the packs would keep the built-in strings and colours to the end.
  static bool settledOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ResourcesSettled>()?.settled ??
      true;

  @override
  State<FlareUpdateResourceScope> createState() =>
      _FlareUpdateResourceScopeState();
}

class _ResourcesSettled extends InheritedWidget {
  const _ResourcesSettled({required this.settled, required super.child});

  final bool settled;

  @override
  bool updateShouldNotify(_ResourcesSettled oldWidget) =>
      settled != oldWidget.settled;
}

class _FlareUpdateResourceScopeState extends State<FlareUpdateResourceScope> {
  /// The packs are a local read; one that hangs must not hold a forced update
  /// back.
  static const Duration _settleLimit = Duration(seconds: 2);

  kit.FlareResourceOverlay _overlay = kit.FlareResourceOverlay.empty;
  bool _settled = false;
  Timer? _limit;

  // The scopes notify on identity, so a new object per build would rebuild the
  // whole app.
  ({kit.FlareStrings base, String locale, kit.FlareStrings result})? _strings;
  ({kit.FlareColors base, kit.FlareColors result})? _light;
  ({kit.FlareColors base, kit.FlareColors result})? _dark;
  ({kit.FlareColors colors, Brightness brightness, ThemeData result})?
  _material;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void didUpdateWidget(FlareUpdateResourceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, widget.controller)) unawaited(_load());
  }

  @override
  void dispose() {
    _limit?.cancel();
    super.dispose();
  }

  void _settle() {
    _limit?.cancel();
    if (mounted && !_settled) setState(() => _settled = true);
  }

  Future<void> _load() async {
    final controller = widget.controller;
    try {
      // `update.*` needs `init`, and the first status says the engine is up.
      if (controller.status == null) await controller.statuses.first;
    } on StateError {
      return; // Disposed before it came up.
    }
    if (!mounted) return;
    _limit?.cancel();
    _limit = Timer(_settleLimit, _settle);
    final packs = await controller.loadResources();
    if (!mounted || !identical(controller, widget.controller)) return;
    final overlay = packs.isEmpty
        ? kit.FlareResourceOverlay.empty
        : kit.FlareResourceOverlay(packs.map(_kitPack));
    if (overlay.isEmpty) {
      _settle();
      return;
    }
    _limit?.cancel();
    setState(() {
      _settled = true;
      _overlay = overlay;
      _strings = null;
      _light = null;
      _dark = null;
      _material = null;
    });
    widget.onOverlay?.call(overlay);
    try {
      await overlay.registerEmoji();
    } catch (error) {
      debugPrint('[update] resource emoji: ${error.runtimeType}');
    }
  }

  kit.FlareStrings _stringsOver(kit.FlareStrings base) {
    final cached = _strings;
    if (cached != null &&
        identical(cached.base, base) &&
        cached.locale == widget.locale) {
      return cached.result;
    }
    final result = _overlay.strings(base, locale: widget.locale);
    _strings = (base: base, locale: widget.locale, result: result);
    return result;
  }

  kit.FlareColors _lightOver(kit.FlareColors base) {
    final cached = _light;
    if (cached != null && identical(cached.base, base)) return cached.result;
    final result = _overlay.colors(base, dark: false);
    _light = (base: base, result: result);
    return result;
  }

  kit.FlareColors _darkOver(kit.FlareColors base) {
    final cached = _dark;
    if (cached != null && identical(cached.base, base)) return cached.result;
    final result = _overlay.colors(base, dark: true);
    _dark = (base: base, result: result);
    return result;
  }

  ThemeData _materialOver(Brightness brightness, kit.FlareColors colors) {
    final cached = _material;
    if (cached != null &&
        identical(cached.colors, colors) &&
        cached.brightness == brightness) {
      return cached.result;
    }
    final result = widget.materialTheme!(brightness, colors);
    _material = (colors: colors, brightness: brightness, result: result);
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final theme = kit.FlareTheme.maybeOf(context);
    final brand = theme?.brand ?? kit.FlareBrandTheme.violet;
    final mode = theme?.mode ?? kit.FlareThemeMode.system;
    final lightBase =
        theme?.colors ??
        kit.FlareColors.resolve(Brightness.light, brand: brand);
    final darkBase =
        theme?.darkColors ??
        theme?.colors ??
        kit.FlareColors.resolve(Brightness.dark, brand: brand);
    final light = _lightOver(lightBase);
    final dark = _darkOver(darkBase);
    final overlaid = !identical(light, lightBase) || !identical(dark, darkBase);

    var child = widget.child;
    if (widget.materialTheme != null) {
      final isDark = kit.flareThemeIsDark(
        mode,
        systemDark: kit.flareSystemDark(context),
      );
      child = Theme(
        data: overlaid
            ? _materialOver(
                isDark ? Brightness.dark : Brightness.light,
                isDark ? dark : light,
              )
            : Theme.of(context),
        child: child,
      );
    }
    // The scopes are always there: a tree that changed shape when the overlay
    // arrives would lose the navigator's state.
    return kit.FlareStringsScope(
      strings: _stringsOver(kit.FlareStringsScope.of(context)),
      child: kit.FlareTheme(
        brand: brand,
        mode: mode,
        // Both modes go down, so a subtree on a brightness of its own keeps
        // following it. Without a token pack colours stay as they were.
        colors: overlaid ? light : theme?.colors,
        darkColors: overlaid ? dark : theme?.darkColors,
        child: _ResourcesSettled(settled: _settled, child: child),
      ),
    );
  }
}

kit.FlareResourcePack _kitPack(sdk.FlareUpdateResourcePack pack) =>
    kit.FlareResourcePack(
      id: pack.id,
      kind: pack.kind,
      packVersion: pack.packVersion,
      contentJson: pack.contentJson,
    );
