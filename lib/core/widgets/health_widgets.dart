import 'package:flutter/material.dart';

import '../theme/health_theme.dart';

/// The pill-shaped primary CTA used across every screen in the design
/// (login, pet setup, quick setup, add debt/income). Disabled state matches
/// the prototype: flat gray fill, no shadow, 55% opacity.
class HealthPrimaryButton extends StatelessWidget {
  const HealthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !busy;
    final accent = Theme.of(context).colorScheme.primary;
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: enabled ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: accent,
            disabledBackgroundColor: HealthColors.textPrimary.withValues(alpha: .12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          child: busy
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                )
              : Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
        ),
      ),
    );
  }
}

/// A single-choice pill, used for Login/Cadastro, país, idioma and
/// sim/não style toggles.
class HealthChip extends StatelessWidget {
  const HealthChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.flex = 1,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int flex;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Expanded(
      flex: flex,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? accent : HealthColors.inputFill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? accent : HealthColors.border),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : HealthColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded white card with the design's default border/padding.
class HealthCard extends StatelessWidget {
  const HealthCard({super.key, required this.child, this.padding = const EdgeInsets.all(16)});

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: HealthColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: HealthColors.borderSoft),
      ),
      child: child,
    );
  }
}

/// Small uppercase label pill — used for provenance markers such as
/// "DADO", "CÁLCULO DETERMINÍSTICO" and "MENTOR · INTERPRETAÇÃO DE IA"
/// (PRD requirement: data, calculation and AI interpretation must be
/// visually distinguishable, never relying on color alone).
class ProvenanceBadge extends StatelessWidget {
  const ProvenanceBadge({super.key, required this.label, required this.color, required this.tint});

  final String label;
  final Color color;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: .35)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: .5, color: color),
      ),
    );
  }
}

/// Progress dots used at the bottom of onboarding screens.
class ProgressDots extends StatelessWidget {
  const ProgressDots({super.key, required this.total, required this.current});

  final int total;
  final int current;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(total, (index) {
        final active = index + 1 == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? accent : HealthColors.textPrimary.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(999),
          ),
        );
      }),
    );
  }
}
