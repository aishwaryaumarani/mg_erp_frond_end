import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

/// "Who am I signed in as?" -- name, email, role, company, and the
/// departments this login may open, plus a self-service password change.
///
/// Everything shown here comes from GET /api/auth/me on open rather than
/// from the cached session, so a role or permission an admin changed
/// while the user was signed in shows up truthfully instead of showing a
/// stale copy of what they had at login.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  /// Opened from the profile menu in the app bar (see main.dart).
  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => const ProfileScreen()),
      );

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _me;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await ApiService.instance.getOne('/api/auth/me');
      if (!mounted) return;
      setState(() {
        _me = me;
        _loading = false;
      });
      // Keep the cached session honest with what the server just said.
      await AuthService.instance.refreshPermissions();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _changePassword() async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (changed != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password changed.')),
    );
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out?'),
        content: const Text('You will need your email and password to sign back in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Stay signed in')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sign out')),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.instance.logout();
    // The shell rebuilds to the login screen on its own; closing this
    // page first stops it sitting over the top of it.
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    return Scaffold(
      appBar: AppBar(title: const Text('My Profile')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: AppColors.tintedBox(AppColors.amber),
                        child: Text(
                          'Showing your saved session -- the server could not be reached ($_error)',
                          style: const TextStyle(color: AppColors.amber, fontSize: 12),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _identityCard(auth),
                    const SizedBox(height: 16),
                    _detailsCard(auth),
                    const SizedBox(height: 16),
                    _accessCard(auth),
                    const SizedBox(height: 20),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _changePassword,
                          icon: const Icon(Icons.lock_outline, size: 18),
                          label: const Text('Change password'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _signOut,
                          icon: const Icon(Icons.logout, size: 18),
                          label: const Text('Sign out'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.rose),
                        ),
                      ),
                    ]),
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _identityCard(AuthService auth) {
    final name = '${_me?['full_name'] ?? auth.fullName ?? '--'}';
    final email = '${_me?['email'] ?? auth.email ?? '--'}';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(children: [
        const ProfileAvatar(size: 62, fontSize: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink)),
            const SizedBox(height: 2),
            Text(email, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 6, children: [
              _chip(auth.roleLabel, AppColors.brand),
              if (_me?['status'] != null)
                _chip('${_me!['status']}',
                    _me!['status'] == 'Active' ? AppColors.green : AppColors.rose),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _detailsCard(AuthService auth) => _card('Account', [
        _row('Company', '${_me?['company_name'] ?? (auth.companyId == null ? 'All companies' : 'Company #${auth.companyId}')}'),
        _row('User ID', '${_me?['id'] ?? '--'}'),
        _row('Signed up', '${_me?['created_at'] ?? '--'}'.replaceFirst('T', ' ').split('.').first),
      ]);

  /// The departments this login may open. Menu shaping only -- every
  /// endpoint re-checks server-side, so this list explains the sidebar
  /// rather than granting anything.
  Widget _accessCard(AuthService auth) {
    final modules = ((_me?['modules'] as List<dynamic>?)?.cast<String>()) ?? auth.modules;
    return _card('Departments you can open', [
      if (auth.isSuperAdmin || auth.isCompanyAdmin)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Admins are not department-gated -- everything is available.',
              style: TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
      if (modules.isEmpty)
        const Text('No departments granted yet. Ask your admin.',
            style: TextStyle(color: AppColors.muted, fontSize: 12))
      else
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final m in modules) _chip(_moduleLabel(m), AppColors.forModule(_moduleLabel(m))),
        ]),
    ]);
  }

  static String _moduleLabel(String module) =>
      module.isEmpty ? module : module[0].toUpperCase() + module.substring(1);

  Widget _card(String title, List<Widget> children) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 15)),
          const SizedBox(height: 12),
          ...children,
        ]),
      );

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
      );

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: AppColors.tintedBox(color, radius: 20),
        child: Text(text,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

/// The signed-in user's initials in a coloured circle. Used in the app
/// bar and on the profile page so the same mark identifies them in both.
class ProfileAvatar extends StatelessWidget {
  final double size;
  final double fontSize;
  const ProfileAvatar({super.key, this.size = 34, this.fontSize = 13});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService.instance;
    // Same initials always get the same colour -- a stable mark is easier
    // to recognise than one that changes between screens.
    final colour = AppColors.accentAt(auth.initials.codeUnits.fold(0, (a, b) => a + b));
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: colour, shape: BoxShape.circle),
      child: Text(
        auth.initials,
        style: TextStyle(
            color: Colors.white, fontWeight: FontWeight.w800, fontSize: fontSize),
      ),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_next.text != _confirm.text) {
      setState(() => _error = 'The two new passwords do not match');
      return;
    }
    if (_next.text.length < 8) {
      setState(() => _error = 'Use at least 8 characters');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ApiService.instance.create('/api/auth/change-password', {
        'current_password': _current.text,
        'new_password': _next.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change password'),
      content: SizedBox(
        width: 400,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: _current,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Current password'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _next,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'New password',
              helperText: 'At least 8 characters',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirm,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Repeat new password'),
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.rose, fontSize: 12)),
          ],
        ]),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Saving…' : 'Change password'),
        ),
      ],
    );
  }
}
