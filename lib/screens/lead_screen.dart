import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../widgets/grade_field.dart';
import '../widgets/status_badge.dart';

const _leadStatuses = ['New', 'Contacted', 'Qualified', 'Converted', 'Lost'];
const _leadSources = ['Website', 'Referral', 'Cold Call', 'Advertisement', 'Exhibition', 'Other'];

/// Lead management -- the front door of the Sales flow (spec: Lead ->
/// Customer -> Inquiry -> Quotation -> Sales Order). A Lead lives here
/// until it's qualified enough to become a real Customer; "Convert to
/// Customer" creates the Customer record and marks the Lead Converted so
/// it's never converted twice.
class LeadScreen extends StatefulWidget {
  const LeadScreen({super.key});

  @override
  State<LeadScreen> createState() => _LeadScreenState();
}

class _LeadScreenState extends State<LeadScreen> {
  final _searchCtrl = TextEditingController();
  List<Lead> _leads = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    GradeOptions.ensureLoaded();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchCtrl.text.isEmpty ? null : {'q': _searchCtrl.text};
      final raw = await ApiService.instance.list('/api/leads/', query: query);
      setState(() {
        _leads = raw.map((e) => Lead.fromJson(e as Map<String, dynamic>)).toList();
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
    final result = await _openForm(context, null);
    if (result == null) return;
    try {
      await ApiService.instance.create('/api/leads/', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(Lead lead) async {
    final result = await _openForm(context, lead);
    if (result == null) return;
    try {
      await ApiService.instance.update('/api/leads/${lead.id}', result.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(Lead lead) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Lead?'),
        content: Text('Delete "${lead.name}"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.instance.delete('/api/leads/${lead.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  /// Creates a Customer from this Lead's details and marks the Lead
  /// Converted, via the backend's dedicated
  /// POST /api/leads/{id}/convert-to-customer endpoint (backend/app/
  /// routers/leads.py) -- it owns customer-code numbering and the lead's
  /// converted_customer_id/status update in one transaction, so nothing
  /// else needs to be written back from here.
  Future<void> _convertToCustomer(Lead lead) async {
    if (lead.status == 'Converted') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This lead has already been converted.')),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Convert to Customer?'),
        content: Text('Create a Customer record from "${lead.name}" and mark this lead Converted?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Convert')),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final customerJson = await ApiService.instance.create('/api/leads/${lead.id}/convert-to-customer', {});
      _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Converted to Customer "${customerJson['name'] ?? lead.name}".')),
      );
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
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search leads...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: const Text('New Lead'),
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
              : _leads.isEmpty
                  ? Center(child: Text('No leads yet.', style: Theme.of(context).textTheme.bodyLarge))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _leads.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final lead = _leads[i];
                          return ListTile(
                            title: Text('${lead.name}  (${lead.leadCode})'),
                            subtitle: Text([
                              if (lead.companyName != null && lead.companyName!.isNotEmpty) lead.companyName,
                              if (lead.phone != null && lead.phone!.isNotEmpty) lead.phone,
                              if (lead.source != null && lead.source!.isNotEmpty) 'Source: ${lead.source}',
                            ].whereType<String>().join(' • ')),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (lead.grade != null && lead.grade!.isNotEmpty) ...[
                                  GradeBadge(grade: lead.grade!),
                                  const SizedBox(width: 8),
                                ],
                                StatusBadge(status: lead.status),
                                const SizedBox(width: 8),
                                if (lead.status != 'Converted')
                                  OutlinedButton.icon(
                                    onPressed: () => _convertToCustomer(lead),
                                    icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
                                    label: const Text('Convert'),
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _edit(lead),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(lead),
                                  tooltip: 'Delete',
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

Future<Lead?> _openForm(BuildContext context, Lead? existing) {
  final code = TextEditingController(text: existing?.leadCode ?? '');
  // Left blank on create -> backend assigns LEAD-0001 style codes itself
  // (backend/app/core/numbering.py next_doc_no), same as Inquiry/Quotation/
  // Sales Order numbers.
  final name = TextEditingController(text: existing?.name ?? '');
  final company = TextEditingController(text: existing?.companyName ?? '');
  final phone = TextEditingController(text: existing?.phone ?? '');
  final email = TextEditingController(text: existing?.email ?? '');
  final notes = TextEditingController(text: existing?.notes ?? '');
  String source = existing?.source ?? _leadSources.first;
  String status = existing?.status ?? 'New';
  String? grade = existing?.grade;

  return showDialog<Lead>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Lead' : 'Edit Lead'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Row(children: [
                Expanded(child: TextField(controller: code, decoration: const InputDecoration(labelText: 'Lead Code', hintText: 'Auto-generated if left blank'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: name, decoration: const InputDecoration(labelText: 'Lead Name'))),
              ]),
              const SizedBox(height: 12),
              TextField(controller: company, decoration: const InputDecoration(labelText: 'Company Name')),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone'))),
                const SizedBox(width: 12),
                Expanded(child: TextField(controller: email, decoration: const InputDecoration(labelText: 'Email'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: source,
                    decoration: const InputDecoration(labelText: 'Source'),
                    items: _leadSources.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => source = v ?? _leadSources.first),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: _leadStatuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (v) => setState(() => status = v ?? 'New'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              GradeDropdown(value: grade, onChanged: (v) => setState(() => grade = v)),
              const SizedBox(height: 12),
              TextField(controller: notes, decoration: const InputDecoration(labelText: 'Notes'), maxLines: 2),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (name.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                Lead(
                  id: existing?.id,
                  leadCode: code.text.trim().isEmpty ? null : code.text.trim(),
                  name: name.text.trim(),
                  companyName: company.text.trim().isEmpty ? null : company.text.trim(),
                  phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
                  email: email.text.trim().isEmpty ? null : email.text.trim(),
                  source: source,
                  status: status,
                  grade: grade,
                  notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
                  convertedCustomerId: existing?.convertedCustomerId,
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
    }),
  );
}
