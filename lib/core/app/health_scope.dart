import 'package:flutter/widgets.dart';

import '../../features/health/presentation/health_controller.dart';

/// Exposes the single app-wide [HealthController] instance to descendants.
/// The controller instance never changes for the app's lifetime, so
/// `updateShouldNotify` is effectively always false — the real reactivity
/// comes from `PetrimoniumHealthApp`'s `AnimatedBuilder`, which listens to
/// the controller directly and rebuilds the whole routed subtree on every
/// change.
class HealthScope extends InheritedWidget {
  const HealthScope({super.key, required this.controller, required super.child});

  final HealthController controller;

  static HealthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HealthScope>();
    assert(scope != null, 'HealthScope not found in context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(HealthScope oldWidget) => controller != oldWidget.controller;
}
