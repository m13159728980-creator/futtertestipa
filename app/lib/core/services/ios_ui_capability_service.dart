import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum IosInterfaceLevel { material, cupertino, liquidGlass }

class IosUiCapabilities {
  const IosUiCapabilities({required this.level, this.majorVersion});

  final IosInterfaceLevel level;
  final int? majorVersion;

  bool get isIos => level != IosInterfaceLevel.material;
  bool get supportsLiquidGlass => level == IosInterfaceLevel.liquidGlass;
}

final iosUiCapabilitiesProvider = FutureProvider<IosUiCapabilities>((ref) {
  return const IosUiCapabilityService().load();
});

class IosUiCapabilityService {
  const IosUiCapabilityService({
    TargetPlatform? platform,
    MethodChannel? channel,
  }) : _platform = platform,
       _channel = channel ?? const MethodChannel('app/ios_ui');

  final TargetPlatform? _platform;
  final MethodChannel _channel;

  Future<IosUiCapabilities> load() async {
    if ((_platform ?? defaultTargetPlatform) != TargetPlatform.iOS) {
      return const IosUiCapabilities(level: IosInterfaceLevel.material);
    }
    final majorVersion = await _iosMajorVersion();
    return IosUiCapabilities(
      majorVersion: majorVersion,
      level: majorVersion >= 26
          ? IosInterfaceLevel.liquidGlass
          : IosInterfaceLevel.cupertino,
    );
  }

  Future<int> _iosMajorVersion() async {
    try {
      final version = await _channel.invokeMethod<int>('majorVersion');
      return version ?? 0;
    } catch (_) {
      return 0;
    }
  }
}
