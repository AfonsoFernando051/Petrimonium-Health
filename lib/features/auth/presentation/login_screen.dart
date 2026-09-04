import 'package:flutter/material.dart';

import '../../../core/app/health_scope.dart';
import '../../../core/theme/health_theme.dart';
import '../../../core/widgets/health_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../health/presentation/health_controller.dart';

/// Login/cadastro screen — `Petrimonium Health.dc.html`'s `screenIsLogin`.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _formError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit(HealthController controller) async {
    final l10n = AppLocalizations.of(context);
    setState(() => _formError = null);
    try {
      if (controller.authMode == AuthMode.signup) {
        await controller.register(
          _nameController.text.trim(),
          _emailController.text.trim(),
          _passwordController.text,
        );
      } else {
        await controller.login(_emailController.text.trim(), _passwordController.text);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _formError = l10n.authFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = HealthScope.of(context);
    final l10n = AppLocalizations.of(context);
    final isSignup = controller.authMode == AuthMode.signup;
    final busy = controller.busy;

    return Scaffold(
      backgroundColor: HealthColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: Image.asset('assets/pets/fox.png', width: 72, height: 72, fit: BoxFit.contain),
                ),
                const SizedBox(height: 12),
                Text(
                  'PETRIMONIUM HEALTH',
                  style: TextStyle(
                    fontSize: 17,
                    letterSpacing: 2.5,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(l10n.healthTagline, style: const TextStyle(fontSize: 12, color: HealthColors.textMuted)),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: HealthColors.textPrimary.withValues(alpha: .05),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      HealthChip(
                        label: l10n.loginToggleLogin,
                        selected: !isSignup,
                        onTap: () => controller.setAuthMode(AuthMode.login),
                      ),
                      const SizedBox(width: 6),
                      HealthChip(
                        label: l10n.loginToggleSignup,
                        selected: isSignup,
                        onTap: () => controller.setAuthMode(AuthMode.signup),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (isSignup) ...[
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(hintText: l10n.name),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(hintText: l10n.email),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(hintText: l10n.password),
                ),
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: HealthColors.inputFill,
                    border: Border.all(color: HealthColors.border),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isSignup ? l10n.loginNoteSignup : l10n.loginNoteLogin,
                    style: const TextStyle(fontSize: 12, color: HealthColors.textSecondary, height: 1.4),
                  ),
                ),
                if (_formError != null) ...[
                  const SizedBox(height: 10),
                  Text(_formError!, style: const TextStyle(color: HealthColors.negative, fontSize: 12.5)),
                ],
                const SizedBox(height: 14),
                HealthPrimaryButton(
                  label: isSignup ? l10n.loginCtaSignup : l10n.login,
                  busy: busy,
                  onPressed: () => _submit(controller),
                ),
                if (!isSignup) ...[
                  const SizedBox(height: 10),
                  Text(
                    l10n.forgotPassword,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12.5, color: HealthColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
