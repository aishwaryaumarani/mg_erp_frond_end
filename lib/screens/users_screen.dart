import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/status_badge.dart';

const _roleOptions = ['user', 'company_admin'];

/// Company Admin's own staff management (backend/app/routers/users.py) --
/// company_id is always taken from the caller's token server-side, never
/// sent from here. Not built on MasterCrudScreen (widgets/
/// master_crud_screen.dart) since there's no edit endpoint, only
/// create/list/deactivate.
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = [];
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
      final raw = await ApiService.instance.list('/api/users/');
      setState(() {
        _users = raw.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String role = 'user';

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('New User'),
          content: SizedBox(
            width: 400,
            child: Form(
              key: formKey,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: emailCtrl,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: passwordCtrl,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: _roleOptions
                      .map((r) => DropdownMenuItem(value: r, child: Text(r == 'user' ? 'User' : 'Company Admin')))
                      .toList(),
                  onChanged: (v) => setState(() => role = v ?? 'user'),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Create'),
            ),
          ],
        );
      }),
    );
    if (created != true) return;

    try {
      await ApiService.instance.create('/api/users/', {
        'full_name': nameCtrl.text.trim(),
        'email': emailCtrl.text.trim(),
        'password': passwordCtrl.text,
        'role': role,
      });
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _deactivate(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suspend User?'),
        content: Text('Suspend "${user.fullName}"? They will no longer be able to sign in.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Suspend'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.delete('/api/users/${user.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Text('Your company\'s users', style: Theme.of(context).textTheme.titleMedium),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New User'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _users.isEmpty
                  ? const Center(child: Text('No users yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _users.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final u = _users[i];
                          return ListTile(
                            title: Text(u.fullName),
                            subtitle: Text('${u.email} · ${u.role == 'company_admin' ? 'Company Admin' : 'User'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: u.status),
                                const SizedBox(width: 12),
                                IconButton(
                                  icon: const Icon(Icons.block_outlined),
                                  tooltip: 'Suspend',
                                  onPressed: u.status == 'Active' ? () => _deactivate(u) : null,
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
