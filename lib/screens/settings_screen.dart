import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/document_pdf.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_logo.dart';
import '../widgets/doc_form_page.dart';

/// Company settings -- the letterhead every screen and every printed
/// document reads from.
///
/// These used to be hardcoded: the company name in the PDF builder, the
/// logo as a bundled asset. Both are now stored against the company, so a
/// changed GSTIN or a new logo is an edit here rather than a release.
/// Only a company admin can save; everyone else sees the details read-only.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _fields = <String, TextEditingController>{};
  bool _loading = true;
  bool _saving = false;
  bool _canEdit = false;
  bool _hasLogo = false;
  String? _error;

  // Document numbering: one row per document type, with its prefix and
  // zero padding.
  List<Map<String, dynamic>> _numbering = [];

  // GST integration. Credentials are write-only: the server tells us
  // which are set, never what they are.
  Map<String, dynamic> _gst = {};
  final _gstFields = <String, TextEditingController>{};
  bool _gstEnabled = false;
  String _gstEnv = 'sandbox';
  String _gstProvider = 'mock';
  String? _gstHealth;
  bool _gstTesting = false;
  final _prefixCtrls = <String, TextEditingController>{};
  final _widthCtrls = <String, TextEditingController>{};
  final _separators = <String, String>{};
  final _useFy = <String, bool>{};

  // Label, key, and how many lines the box gets.
  static const _identity = [
    ('Company name (as shown in the app)', 'name', 1),
    ('Legal name (as printed on documents)', 'legal_name', 1),
    ('GSTIN', 'gstin', 1),
    ('PAN', 'pan', 1),
  ];
  static const _address = [
    ('Address', 'address', 2),
    ('City', 'city', 1),
    ('State', 'state', 1),
    ('PIN code', 'pincode', 1),
  ];
  static const _contact = [
    ('Phone', 'phone', 1),
    ('Email', 'email', 1),
    ('Website', 'website', 1),
  ];
  static const _bank = [
    ('Bank name', 'bank_name', 1),
    ('Account number', 'bank_account_no', 1),
    ('IFSC', 'bank_ifsc', 1),
    ('Branch', 'bank_branch', 1),
  ];
  static const _terms = [
    ('Invoice terms', 'invoice_terms', 3),
    ('Declaration', 'declaration', 3),
  ];

  List<(String, String, int)> get _all =>
      [..._identity, ..._address, ..._contact, ..._bank, ..._terms];

  @override
  void initState() {
    super.initState();
    for (final field in _all) {
      _fields[field.$2] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in [..._fields.values, ..._prefixCtrls.values, ..._widthCtrls.values,
                     ..._gstFields.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.getOne('/api/settings/company'),
        ApiService.instance.list('/api/settings/numbering'),
        ApiService.instance.getOne('/api/gst/config'),
      ]);
      final data = results[0] as Map<String, dynamic>;
      _numbering = (results[1] as List<dynamic>)
          .map((e) => (e as Map).cast<String, dynamic>())
          .toList();
      _gst = results[2] as Map<String, dynamic>;
      _gstEnabled = _gst['enabled'] == true;
      _gstEnv = '${_gst['environment'] ?? 'sandbox'}';
      _gstProvider = '${_gst['provider'] ?? 'mock'}';
      for (final key in ['gstin', 'base_url', 'username', 'password', 'client_id',
                         'client_secret', 'api_key']) {
        _gstFields[key] ??= TextEditingController();
      }
      // Only the GSTIN and URL come back; secrets never do.
      _gstFields['gstin']!.text = '${_gst['gstin'] ?? ''}';
      _gstFields['base_url']!.text = '${_gst['base_url'] ?? ''}';
      for (final row in _numbering) {
        final key = '${row['doc_type']}';
        _prefixCtrls[key] = TextEditingController(text: '${row['prefix']}');
        _widthCtrls[key] = TextEditingController(text: '${row['width']}');
        _separators[key] = '${row['separator'] ?? '-'}';
        _useFy[key] = row['use_financial_year'] == true;
      }
      for (final entry in _fields.entries) {
        entry.value.text = '${data[entry.key] ?? ''}';
      }
      setState(() {
        _hasLogo = data['has_logo'] == true;
        _canEdit = AuthService.instance.isCompanyAdmin || AuthService.instance.isSuperAdmin;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e is ApiException ? e.message : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_fields['name']!.text.trim().isEmpty) {
      showFormError(context, 'The company needs a name.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ApiService.instance.update('/api/settings/company', {
        for (final entry in _fields.entries)
          entry.key: entry.value.text.trim().isEmpty ? null : entry.value.text.trim(),
      });
      // The name and logo are shown app-wide and printed on documents,
      // so drop both caches.
      BrandLogo.invalidate();
      invalidateCompanyProfile();
      if (!mounted) return;
      setState(() => _saving = false);
      await _saveNumbering();
      await _saveGst();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Company details and numbering saved.')),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  /// Saved with the rest of Settings, so one Save button covers the page.
  Future<void> _saveNumbering() async {
    if (_numbering.isEmpty) return;
    await ApiService.instance.update('/api/settings/numbering', {
      'rows': [
        for (final row in _numbering)
          {
            'doc_type': row['doc_type'],
            'prefix': _prefixCtrls['${row['doc_type']}']!.text.trim(),
            'width': int.tryParse(_widthCtrls['${row['doc_type']}']!.text.trim()) ?? 4,
            'separator': _separators['${row['doc_type']}'] ?? '-',
            'use_financial_year': _useFy['${row['doc_type']}'] ?? false,
          },
      ],
    });
  }

  /// Saved with the rest of the page. A credential box left empty keeps
  /// whatever is stored -- the UI never round-trips a secret it was not
  /// shown.
  Future<void> _saveGst() async {
    String? changed(String key) {
      final text = _gstFields[key]?.text.trim() ?? '';
      return text.isEmpty ? null : text;
    }

    final data = await ApiService.instance.update('/api/gst/config', {
      'enabled': _gstEnabled,
      'environment': _gstEnv,
      'provider': _gstProvider,
      'gstin': changed('gstin'),
      'base_url': changed('base_url'),
      'username': changed('username'),
      'password': changed('password'),
      'client_id': changed('client_id'),
      'client_secret': changed('client_secret'),
      'api_key': changed('api_key'),
    });
    if (!mounted) return;
    setState(() {
      _gst = data;
      // Clear the secret boxes so they are never left on screen.
      for (final key in ['username', 'password', 'client_id', 'client_secret', 'api_key']) {
        _gstFields[key]?.clear();
      }
    });
  }

  Future<void> _testGstConnection() async {
    setState(() {
      _gstTesting = true;
      _gstHealth = null;
    });
    try {
      final health = await ApiService.instance.getOne('/api/gst/health');
      if (!mounted) return;
      setState(() {
        _gstHealth = health['status'] == 'connected'
            ? 'Connected to ${health['provider']} (${health['environment']}) as ${health['gstin']}'
            : 'Not connected: ${health['message'] ?? health['status']}';
        _gstTesting = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _gstHealth = e is ApiException ? e.message : e.toString();
        _gstTesting = false;
      });
    }
  }

  Future<void> _uploadLogo() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Choose a logo',
      type: FileType.custom,
      allowedExtensions: ['png', 'jpg', 'jpeg'],
    );
    if (file == null) return;
    final Uint8List bytes = await file.readAsBytes();
    setState(() => _saving = true);
    try {
      await ApiService.instance
          .uploadFile('/api/settings/company/logo', bytes, file.name);
      BrandLogo.invalidate();
      invalidateCompanyProfile();
      if (!mounted) return;
      setState(() {
        _hasLogo = true;
        _saving = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Logo updated — it now appears on screens and PDFs.')),
      );
    } catch (e) {
      setState(() => _saving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  Future<void> _removeLogo() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove the logo?'),
        content: const Text('Documents will print with the company name only until a new one is uploaded.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.instance.delete('/api/settings/company/logo');
      BrandLogo.invalidate();
      if (!mounted) return;
      setState(() => _hasLogo = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e is ApiException ? e.message : e.toString()),
          backgroundColor: AppColors.rose,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.error_outline, color: AppColors.rose, size: 32),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.rose)),
            const SizedBox(height: 12),
            FilledButton(onPressed: _load, child: const Text('Try again')),
          ]),
        ),
      );
    }

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Company Settings',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800, color: AppColors.ink)),
                ),
                if (_canEdit)
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: const Icon(Icons.check),
                    label: const Text('Save changes'),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              _canEdit
                  ? 'These appear on every screen and on every document the software prints.'
                  : 'Read-only: ask a company admin to change these.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            _logoSection(),
            _section('Identity', _identity),
            _section('Address', _address),
            _section('Contact', _contact),
            _section('Bank details', _bank,
                hint: 'Printed on invoices so customers know where to pay.'),
            _section('Standing text', _terms,
                hint: 'Terms and the declaration printed at the foot of documents.'),
            _numberingSection(),
            _gstSection(),
          ],
        ),
      ),
    );
  }

  Widget _logoSection() => DocFormSection(
        title: 'Logo',
        hint: 'Shown in the sidebar, on the dashboard and at the top of every PDF. '
            'PNG or JPEG, under 2 MB. A square-ish mark with little white space works best.',
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 120,
                height: 120,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.page,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.line),
                ),
                // Keyed on the logo state so replacing it repaints here.
                child: _hasLogo
                    ? BrandLogo(key: ValueKey(_hasLogo), height: 100)
                    : const Text('No logo', style: TextStyle(color: AppColors.muted)),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_canEdit) ...[
                      FilledButton.icon(
                        onPressed: _saving ? null : _uploadLogo,
                        icon: const Icon(Icons.upload_outlined),
                        label: Text(_hasLogo ? 'Replace logo' : 'Upload logo'),
                      ),
                      const SizedBox(height: 10),
                      if (_hasLogo)
                        OutlinedButton.icon(
                          onPressed: _saving ? null : _removeLogo,
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Remove'),
                          style: OutlinedButton.styleFrom(foregroundColor: AppColors.rose),
                        ),
                    ] else
                      const Text('Only a company admin can change the logo.',
                          style: TextStyle(color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
        ],
      );

  Widget _gstSection() {
    final providers = ((_gst['available_providers'] as List<dynamic>?) ?? ['mock'])
        .map((e) => '$e')
        .toList();
    return DocFormSection(
      title: 'GST · e-invoice & e-way bill',
      hint: 'Credentials are stored encrypted and are never shown again. '
          'Sandbox files nothing with the government — use it until the numbers look right.',
      children: [
        SwitchListTile(
          value: _gstEnabled,
          onChanged: _canEdit ? (v) => setState(() => _gstEnabled = v) : null,
          title: const Text('GST integration enabled'),
          subtitle: const Text('Adds Generate E-Invoice / E-Way Bill to sales invoices'),
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _gstEnv,
              decoration: const InputDecoration(labelText: 'Environment'),
              items: const [
                DropdownMenuItem(value: 'sandbox', child: Text('Sandbox (test)')),
                DropdownMenuItem(value: 'production', child: Text('Production (live filing)')),
              ],
              onChanged: _canEdit ? (v) => setState(() => _gstEnv = v ?? 'sandbox') : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: providers.contains(_gstProvider) ? _gstProvider : providers.first,
              decoration: const InputDecoration(labelText: 'Provider'),
              items: [
                for (final p in providers)
                  DropdownMenuItem(
                    value: p,
                    child: Text(p == 'mock' ? 'Mock (offline test)' : p),
                  ),
              ],
              onChanged: _canEdit ? (v) => setState(() => _gstProvider = v ?? 'mock') : null,
            ),
          ),
        ]),
        if (_gstEnv == 'production' && _gstProvider == 'mock')
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'The mock provider never files anything. Production needs a real GSP adapter — '
              'see docs/gst-integration.md.',
              style: TextStyle(color: AppColors.amber, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _gstFields['gstin'],
              readOnly: !_canEdit,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'GSTIN used for filing',
                hintText: '27XXXXXXXXXXXZX',
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: TextField(
              controller: _gstFields['base_url'],
              readOnly: !_canEdit,
              decoration: const InputDecoration(labelText: "Provider API URL"),
            ),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _secretField('username', 'API username')),
          const SizedBox(width: 12),
          Expanded(child: _secretField('password', 'API password')),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: _secretField('client_id', 'Client ID')),
          const SizedBox(width: 12),
          Expanded(child: _secretField('client_secret', 'Client secret')),
        ]),
        const SizedBox(height: 12),
        _secretField('api_key', 'Subscription / API key'),
        const SizedBox(height: 14),
        Row(children: [
          OutlinedButton.icon(
            onPressed: _gstTesting ? null : _testGstConnection,
            icon: _gstTesting
                ? const SizedBox(
                    width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering, size: 18),
            label: const Text('Test connection'),
          ),
          const SizedBox(width: 12),
          if (_gstHealth != null)
            Expanded(
              child: Text(
                _gstHealth!,
                style: TextStyle(
                  color: _gstHealth!.startsWith('Connected') ? AppColors.green : AppColors.rose,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ),
        ]),
      ],
    );
  }

  /// A credential box: shows whether one is stored, never what it is.
  Widget _secretField(String key, String label) => TextField(
        controller: _gstFields[key],
        readOnly: !_canEdit,
        obscureText: true,
        decoration: InputDecoration(
          labelText: label,
          hintText: _gst['has_$key'] == true ? 'Stored — type to replace' : 'Not set',
          suffixIcon: _gst['has_$key'] == true
              ? const Icon(Icons.lock_outline, size: 18, color: AppColors.green)
              : null,
        ),
      );

  Widget _numberingSection() => DocFormSection(
        title: 'Document numbering',
        hint: 'How each document type is numbered. Tick the year to stamp the '
            'financial year in and restart the count each April — MG/SI/2026-27/001. '
            'Documents already issued keep their numbers; only the next one uses a '
            'new prefix, and numbering steps over anything already taken.',
        children: [
          for (final row in _numbering)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  SizedBox(
                    width: 200,
                    child: Text('${row['label']}',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                  ),
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _prefixCtrls['${row['doc_type']}'],
                      readOnly: !_canEdit,
                      decoration: const InputDecoration(labelText: 'Prefix', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 78,
                    child: DropdownButtonFormField<String>(
                      value: _separators['${row['doc_type']}'] ?? '-',
                      isDense: true,
                      decoration: const InputDecoration(labelText: 'Sep', isDense: true),
                      items: const [
                        DropdownMenuItem(value: '-', child: Text('-')),
                        DropdownMenuItem(value: '/', child: Text('/')),
                        DropdownMenuItem(value: '_', child: Text('_')),
                      ],
                      onChanged: _canEdit
                          ? (v) => setState(() => _separators['${row['doc_type']}'] = v ?? '-')
                          : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 86,
                    child: TextField(
                      controller: _widthCtrls['${row['doc_type']}'],
                      readOnly: !_canEdit,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Digits', isDense: true),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Stamp the financial year in and restart each year',
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Checkbox(
                        value: _useFy['${row['doc_type']}'] ?? false,
                        visualDensity: VisualDensity.compact,
                        onChanged: _canEdit
                            ? (v) => setState(() => _useFy['${row['doc_type']}'] = v ?? false)
                            : null,
                      ),
                      const Text('Year', style: TextStyle(color: AppColors.muted, fontSize: 12)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  // What the next number will look like, as you type.
                  Expanded(
                    child: Text(
                      _exampleFor(row),
                      style: const TextStyle(
                          color: AppColors.muted, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );

  String _exampleFor(Map<String, dynamic> row) {
    final key = '${row['doc_type']}';
    final prefix = _prefixCtrls[key]?.text.trim().toUpperCase() ?? '';
    final width = int.tryParse(_widthCtrls[key]?.text.trim() ?? '') ?? 4;
    final separator = _separators[key] ?? '-';
    if (prefix.isEmpty) return 'set a prefix';
    // Same shape the server builds, so what you see is what gets issued.
    final year = _useFy[key] == true ? '${_financialYear()}$separator' : '';
    return '$prefix$separator$year${'1'.padLeft(width.clamp(1, 10), '0')}';
  }

  /// April-to-March by default, matching the server's own calculation.
  String _financialYear() {
    final now = DateTime.now();
    final first = now.month >= 4 ? now.year : now.year - 1;
    return '$first-${(first + 1).toString().substring(2)}';
  }

  Widget _section(String title, List<(String, String, int)> fields, {String? hint}) =>
      DocFormSection(
        title: title,
        hint: hint,
        children: [
          for (final field in fields)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextField(
                controller: _fields[field.$2],
                readOnly: !_canEdit,
                maxLines: field.$3,
                decoration: InputDecoration(
                  labelText: field.$1,
                  fillColor: _canEdit ? AppColors.surface : AppColors.page,
                ),
              ),
            ),
        ],
      );
}
