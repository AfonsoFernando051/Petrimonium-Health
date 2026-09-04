import 'package:flutter/widgets.dart';

import '../../features/health/presentation/health_controller.dart';

/// Exposes the single app-wide [HealthController] instance to descendants.
///
/// The controller is mutable state behind an immutable widget: the instance
/// is the same for the app's lifetime while everything readers care about —
/// `stage`, `tab`, the loaded data — changes underneath it. So this notifies
/// unconditionally. `PetrimoniumHealthApp`'s `AnimatedBuilder` only rebuilds
/// this widget; it is `updateShouldNotify` that actually re-runs the screens
/// reading the controller.
///
/// Comparing controller instances instead (they are always equal, so nothing
/// is ever notified) left the app on its splash screen forever: the routed
/// child is a `const` widget, and a parent rebuilding with an identical child
/// instance does not rebuild it, so `stage` was read exactly once — while it
/// was still `AppStage.loading`.
class HealthScope extends InheritedWidget {
  const HealthScope({super.key, required this.controller, required super.child});

  final HealthController controller;

  static HealthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<HealthScope>();
    assert(scope != null, 'HealthScope not found in context');
    return scope!.controller;
  }

  @override
  bool updateShouldNotify(HealthScope oldWidget) => true;
}
