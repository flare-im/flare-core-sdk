import 'package:flutter/foundation.dart';

/// 系统对本应用后台运行的态度（Android），用系统电池设置里的三档说法。
enum FlarePushBackgroundDelivery {
  /// 用户把本应用放出了电池优化。
  unrestricted('unrestricted'),

  /// 系统默认：后台运行由系统管理。
  optimized('optimized'),

  /// 用户在系统设置里限制了本应用的后台活动。
  restricted('restricted');

  const FlarePushBackgroundDelivery(this.wire);

  final String wire;

  /// 认不出的当作 [optimized]：系统默认，不提示也不吓人。
  static FlarePushBackgroundDelivery fromWire(Object? value) {
    for (final delivery in values) {
      if (delivery.wire == value) return delivery;
    }
    return optimized;
  }
}

/// 手机厂商（Android），按它判断有没有自启动管理页。
enum FlarePushVendor {
  huawei('huawei'),
  honor('honor'),
  xiaomi('xiaomi'),
  oppo('oppo'),
  vivo('vivo'),
  other('other');

  const FlarePushVendor(this.wire);

  final String wire;

  static FlarePushVendor fromWire(Object? value) {
    for (final vendor in values) {
      if (vendor.wire == value) return vendor;
    }
    return other;
  }
}

/// 后台限制在这台设备上的现状（Android），由原生模块读出，只做引导用。
@immutable
final class FlarePushBackgroundStatus {
  const FlarePushBackgroundStatus({
    required this.delivery,
    required this.ignoringBatteryOptimizations,
    required this.backgroundRestricted,
    required this.vendor,
    required this.hasAutoStartSettings,
  });

  /// 电池设置里的三档，由下面两项合成。
  final FlarePushBackgroundDelivery delivery;

  /// 应用已被用户放进电池优化白名单。
  final bool ignoringBatteryOptimizations;

  /// 用户在系统设置里限制了本应用的后台活动（Android 9 起）。
  final bool backgroundRestricted;

  final FlarePushVendor vendor;

  /// 厂商有自己的自启动管理页（华为、荣耀、小米、OPPO、vivo）：设置里值得多给一行入口。
  final bool hasAutoStartSettings;

  /// 不是对象时为 null。
  static FlarePushBackgroundStatus? fromWire(Object? value) {
    if (value is! Map) return null;
    final vendor = FlarePushVendor.fromWire(value['vendor']);
    final Object? autoStart = value['hasAutoStartSettings'];
    return FlarePushBackgroundStatus(
      delivery: FlarePushBackgroundDelivery.fromWire(value['delivery']),
      ignoringBatteryOptimizations: value['ignoringBatteryOptimizations'] == true,
      backgroundRestricted: value['backgroundRestricted'] == true,
      vendor: vendor,
      hasAutoStartSettings: autoStart is bool
          ? autoStart
          : vendor != FlarePushVendor.other,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FlarePushBackgroundStatus &&
      other.delivery == delivery &&
      other.ignoringBatteryOptimizations == ignoringBatteryOptimizations &&
      other.backgroundRestricted == backgroundRestricted &&
      other.vendor == vendor &&
      other.hasAutoStartSettings == hasAutoStartSettings;

  @override
  int get hashCode => Object.hash(
    delivery,
    ignoringBatteryOptimizations,
    backgroundRestricted,
    vendor,
    hasAutoStartSettings,
  );

  @override
  String toString() =>
      'FlarePushBackgroundStatus(delivery: ${delivery.wire}, '
      'vendor: ${vendor.wire}, autoStart: $hasAutoStartSettings)';
}
