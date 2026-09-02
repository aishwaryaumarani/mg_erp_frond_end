import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// Sign-in screen shown whenever AuthService.instance.isLoggedIn is false
/// (see main.dart). Accounts are provisioned top-down -- Super Admin
/// creates a Company (which creates that company's first admin login,
/// see backend/app/routers/companies.py), and a Company Admin creates
/// plain User logins (backend/app/routers/users.py) -- so there's no
/// self-registration here, only sign-in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _loading = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService.instance
          .login(_emailCtrl.text.trim(), _passwordCtrl.text);
      // AuthService notifies listeners on success; main.dart's
      // AnimatedBuilder swaps this screen out automatically.
    } catch (e) {
      setState(() => _error = e is ApiException ? e.message : e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: AppColors.page,
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 960),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.line),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.ink.withValues(alpha: 0.06),
                      blurRadius: 24,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 760;
                    final form = _LoginForm(
                      formKey: _formKey,
                      emailCtrl: _emailCtrl,
                      passwordCtrl: _passwordCtrl,
                      obscurePassword: _obscurePassword,
                      loading: _loading,
                      error: _error,
                      onTogglePassword: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      onSubmit: _submit,
                    );
                    return wide
                        ? Row(
                            children: [
                              const Expanded(child: _BrandPanel()),
                              Container(
                                  width: 1, height: 460, color: AppColors.line),
                              Expanded(child: form),
                            ],
                          )
                        : Column(children: [
                            const _BrandPanel(),
                            const Divider(height: 1),
                            form
                          ]);
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.brand,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: AppColors.brand.withValues(alpha: 0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: const Icon(Icons.science_outlined,
                size: 30, color: Colors.white),
          ),
          const SizedBox(height: 28),
          Text(
            'MG Chemicals',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            'Product, sales, purchase, inventory and accounting operations in one controlled workspace.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.muted,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 28),
          const Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _FeatureChip(
                  icon: Icons.verified_user_outlined, label: 'Role based'),
              _FeatureChip(
                  icon: Icons.inventory_2_outlined, label: 'Inventory ready'),
              _FeatureChip(
                  icon: Icons.receipt_long_outlined, label: 'Document flow'),
            ],
          ),
        ],
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.page,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.brand),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscurePassword;
  final bool loading;
  final String? error;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  const _LoginForm({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscurePassword,
    required this.loading,
    required this.error,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(36),
      child: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Sign in',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.ink,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Use your company account to continue.',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.mail_outline),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your email' : null,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: passwordCtrl,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(
                    obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  tooltip: obscurePassword ? 'Show password' : 'Hide password',
                  onPressed: onTogglePassword,
                ),
              ),
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Enter your password' : null,
              onFieldSubmitted: (_) => onSubmit(),
            ),
            if (error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: AppColors.tintedBox(AppColors.rose, radius: 8),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        color: AppColors.rose, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        error!,
                        style: const TextStyle(color: AppColors.rose),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: loading ? null : onSubmit,
              icon: loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.login_outlined),
              label: Text(loading ? 'Signing in' : 'Sign In'),
            ),
          ],
        ),
      ),
    );
  }
}
