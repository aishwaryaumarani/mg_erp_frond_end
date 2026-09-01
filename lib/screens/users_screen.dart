import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/status_badge.dart';

const _roleOptions = ['user', 'company_admin'];

/// Company Admin's own staff management (backend/app/routers/users.py) --
/// company_id is always taken from the caller's token server-side, never
/// sent from here. Not built on MasterCrudScreen (widgets/
/// master_crud_screen.dart) since there's no edit endpoint, only
/// create/list/deactivate and the department permissions below.
///
/// Departments ("modules") are what a user is allowed to open: tick Sales
/// and they get the Sales sidebar group and the Sales endpoints, nothing
/// else. The catalogue comes from GET /api/users/modules rather than a
/// list hard-coded here, so this screen can never offer a permission the
/// backend does not enforce (backend/app/core/permissions.py).
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  List<AppUser> _users = [];
  List<AppModule> _modules = [];
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
      final rawModules = await ApiService.instance.list('/api/users/modules');
      setState(() {
        _users = raw.map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList();
        _modules = rawModules.map((e) => AppModule.fromJson(e as Map<String, dynamic>)).toList();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  /// Tick-boxes shared by the create dialog and the edit-permissions
  /// dialog, so both always offer exactly the same departments.
  Widget _modulePicker(Set<String> selected, void Function(void Function()) rebuild) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final m in _modules)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: Text(m.label),
            value: selected.contains(m.key),
            onChanged: (checked) => rebuild(() {
              if (checked == true) {
                selected.add(m.key);
              } else {
                selected.remove(m.key);
              }
            }),
          ),
      ],
    );
  }

  Future<void> _create() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String role = 'user';
    final selected = <String>{};

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('New User'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
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
                        .map((r) => DropdownMenuItem(
                            value: r, child: Text(r == 'user' ? 'User' : 'Company Admin')))
                        .toList(),
                    onChanged: (v) => setState(() => role = v ?? 'user'),
                  ),
                  const SizedBox(height: 16),
                  // A company_admin is never department-gated (the backend
                  // ignores modules for that role), so offering the boxes
                  // would promise a restriction that won't apply.
                  if (role == 'company_admin')
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Company Admins have access to every department.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  else ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Departments', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'They will only see the ones you tick.',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                    _modulePicker(selected, setState),
                  ],
                ]),
              ),
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
        'modules': selected.toList(),
      });
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Renames a user and/or resets their password (PATCH /api/users/{id}).
  /// The password field is left blank by default and only sent when the
  /// admin actually types one, so renaming somebody never resets their
  /// login by accident. Email is not editable -- it is the login
  /// identifier, and changing it here would lock the user out.
  Future<void> _edit(AppUser user) async {
    final nameCtrl = TextEditingController(text: user.fullName);
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit User'),
        content: SizedBox(
          width: 400,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordCtrl,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  helperText: 'Leave blank to keep the current password',
                ),
                obscureText: true,
                validator: (v) =>
                    (v != null && v.isNotEmpty && v.length < 6) ? 'At least 6 characters' : null,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${user.email} cannot be changed here.',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    try {
      await ApiService.instance.patch('/api/users/${user.id}', {
        'full_name': nameCtrl.text.trim(),
        // Omitted entirely when blank -- the backend leaves the existing
        // hash alone rather than hashing an empty string.
        if (passwordCtrl.text.isNotEmpty) 'password': passwordCtrl.text,
      });
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Replaces a user's departments wholesale -- the backend's
  /// PUT /api/users/{id}/permissions takes the full ticked set, so
  /// unticking everything revokes everything. Takes effect on that user's
  /// next request; their app picks the new menu up from /api/auth/me
  /// without needing to sign out and back in.
  Future<void> _editPermissions(AppUser user) async {
    final selected = user.modules.toSet();

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: Text('Departments - ${user.fullName}'),
          content: SizedBox(
            width: 400,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Only the ticked departments appear in their menu.',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                _modulePicker(selected, setState),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        );
      }),
    );
    if (saved != true) return;

    try {
      await ApiService.instance.update(
        '/api/users/${user.id}/permissions',
        {'modules': selected.toList()},
      );
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
      SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
    );
  }

  /// "Sales, Tasks" rather than "sales, tasks" -- labels come from the
  /// backend catalogue so a department reads the same here as it does in
  /// the sidebar.
  String _departmentsLine(AppUser user) {
    if (user.role == 'company_admin') return 'All departments';
    if (user.modules.isEmpty) return 'No departments yet';
    return _modules.where((m) => user.modules.contains(m.key)).map((m) => m.label).join(', ');
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
                child:
                    Text('Your company\'s users', style: Theme.of(context).textTheme.titleMedium),
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
                          final isAdmin = u.role == 'company_admin';
                          return ListTile(
                            title: Text(u.fullName),
                            subtitle: Text(
                              '${u.email} · ${isAdmin ? 'Company Admin' : 'User'}\n${_departmentsLine(u)}',
                            ),
                            isThreeLine: true,
                            // A menu rather than a row of icon buttons:
                            // three actions plus the badge does not fit
                            // beside a name on a phone.
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: u.status),
                                PopupMenuButton<String>(
                                  tooltip: 'Actions',
                                  onSelected: (action) {
                                    switch (action) {
                                      case 'edit':
                                        _edit(u);
                                      case 'departments':
                                        _editPermissions(u);
                                      case 'suspend':
                                        _deactivate(u);
                                    }
                                  },
                                  itemBuilder: (ctx) => [
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.edit_outlined),
                                        title: Text('Edit name / password'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'departments',
                                      // Company Admins are never gated, so
                                      // there is nothing to tick for them.
                                      enabled: !isAdmin,
                                      child: const ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.tune_outlined),
                                        title: Text('Departments'),
                                      ),
                                    ),
                                    PopupMenuItem(
                                      value: 'suspend',
                                      enabled: u.status == 'Active',
                                      child: const ListTile(
                                        dense: true,
                                        contentPadding: EdgeInsets.zero,
                                        leading: Icon(Icons.block_outlined),
                                        title: Text('Suspend'),
                                      ),
                                    ),
                                  ],
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
