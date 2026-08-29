import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/status_badge.dart';

/// Super Admin's onboarding screen -- "sell the ERP to a company" (backend/
/// app/routers/companies.py: POST /api/companies creates the Company, its
/// first company_admin login, and that company's Chart of Accounts in one
/// call). Not built on MasterCrudScreen (widgets/master_crud_screen.dart)
/// because create and "edit" have different shapes here: create takes the
/// admin's name/email/password, while the only post-creation action is an
/// Active/Suspended toggle (there's no company edit/delete endpoint).
class CompaniesScreen extends StatefulWidget {
  const CompaniesScreen({super.key});

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  List<CompanyModel> _companies = [];
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
      final raw = await ApiService.instance.list('/api/companies/');
      setState(() {
        _companies = raw.map((e) => CompanyModel.fromJson(e as Map<String, dynamic>)).toList();
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
    final adminNameCtrl = TextEditingController();
    final adminEmailCtrl = TextEditingController();
    final adminPasswordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Company'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Company Name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              const Divider(),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text('First admin login for this company', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: adminNameCtrl,
                decoration: const InputDecoration(labelText: 'Admin Full Name'),
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: adminEmailCtrl,
                decoration: const InputDecoration(labelText: 'Admin Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: adminPasswordCtrl,
                decoration: const InputDecoration(labelText: 'Admin Password'),
                obscureText: true,
                validator: (v) => (v == null || v.length < 6) ? 'At least 6 characters' : null,
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
      ),
    );
    if (created != true) return;

    try {
      await ApiService.instance.create('/api/companies/', {
        'company_name': nameCtrl.text.trim(),
        'admin_full_name': adminNameCtrl.text.trim(),
        'admin_email': adminEmailCtrl.text.trim(),
        'admin_password': adminPasswordCtrl.text,
      });
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _toggleStatus(CompanyModel company) async {
    final newStatus = company.status == 'Active' ? 'Suspended' : 'Active';
    try {
      await ApiService.instance.patch('/api/companies/${company.id}', {'status': newStatus});
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
                child: Text('Companies you have onboarded', style: Theme.of(context).textTheme.titleMedium),
              ),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New Company'),
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
              : _companies.isEmpty
                  ? const Center(child: Text('No companies yet.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _companies.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final c = _companies[i];
                          return ListTile(
                            title: Text(c.name),
                            subtitle: Text('Onboarded ${c.createdAt.split('T').first}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                StatusBadge(status: c.status),
                                const SizedBox(width: 12),
                                Switch(
                                  value: c.status == 'Active',
                                  onChanged: (_) => _toggleStatus(c),
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
