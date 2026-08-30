import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'status_badge.dart';
import '../theme/app_theme.dart';

/// Generic list + search + create/edit/delete screen shared by every
/// Phase-1 master (Categories, Brands, Units, Taxes, Customers,
/// Suppliers, ...). Each concrete screen just supplies (de)serializers
/// and a form dialog builder -- see screens/*.dart for usage.
class MasterCrudScreen<T> extends StatefulWidget {
  final String resourcePath; // e.g. '/api/categories/'
  final String entityName; // e.g. 'Category'
  final T Function(Map<String, dynamic>) fromJson;
  final Map<String, dynamic> Function(T) toJson;
  final int? Function(T) idOf;
  final String Function(T) titleOf;
  final String Function(T)? subtitleOf;
  final String Function(T)? statusOf;
  final Future<T?> Function(BuildContext context, T? existing) openForm;
  final bool searchable;

  const MasterCrudScreen({
    super.key,
    required this.resourcePath,
    required this.entityName,
    required this.fromJson,
    required this.toJson,
    required this.idOf,
    required this.titleOf,
    this.subtitleOf,
    this.statusOf,
    required this.openForm,
    this.searchable = true,
  });

  @override
  State<MasterCrudScreen<T>> createState() => _MasterCrudScreenState<T>();
}

class _MasterCrudScreenState<T> extends State<MasterCrudScreen<T>> {
  final _searchCtrl = TextEditingController();
  List<T> _items = [];
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
      final query = _searchCtrl.text.isEmpty ? null : {'q': _searchCtrl.text};
      final raw = await ApiService.instance.list(widget.resourcePath, query: query);
      setState(() {
        _items = raw.map((e) => widget.fromJson(e as Map<String, dynamic>)).toList();
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
    final result = await widget.openForm(context, null);
    if (result == null) return;
    try {
      await ApiService.instance.create(widget.resourcePath, widget.toJson(result));
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(T item) async {
    final result = await widget.openForm(context, item);
    if (result == null) return;
    final id = widget.idOf(item);
    try {
      await ApiService.instance.update('${widget.resourcePath}$id', widget.toJson(result));
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(T item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete ${widget.entityName}?'),
        content: Text('Delete "${widget.titleOf(item)}"? This can be undone by re-adding it; historical transactions are preserved.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.rose),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final id = widget.idOf(item);
    try {
      await ApiService.instance.delete('${widget.resourcePath}$id');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(e is ApiException ? e.message : e.toString()),
        backgroundColor: AppColors.rose,
      ),
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
              if (widget.searchable)
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.entityName.toLowerCase()}s...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.brand),
                      isDense: true,
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _create,
                icon: const Icon(Icons.add),
                label: Text('New ${widget.entityName}'),
              ),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: AppColors.tintedBox(AppColors.rose),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppColors.rose, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(color: AppColors.rose))),
                ],
              ),
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? Center(
                      child: Text('No ${widget.entityName.toLowerCase()}s yet.',
                          style: Theme.of(context).textTheme.bodyLarge),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          // Row accent rotates through the palette so a
                          // long list of otherwise identical rows is
                          // still easy to keep your place in.
                          final accent = AppColors.accentAt(i);
                          final title = widget.titleOf(item);
                          return Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: accent.withOpacity(0.20)),
                            ),
                            child: ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            leading: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: AppColors.tintedBox(accent, radius: 10, border: false),
                              child: Text(
                                title.isEmpty ? '?' : title.characters.first.toUpperCase(),
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                            title: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: widget.subtitleOf != null
                                ? Text(
                                    widget.subtitleOf!(item),
                                    style: const TextStyle(color: AppColors.slate),
                                  )
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.statusOf != null) ...[
                                  StatusBadge(status: widget.statusOf!(item)),
                                  const SizedBox(width: 12),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppColors.brand),
                                  onPressed: () => _edit(item),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: AppColors.rose),
                                  onPressed: () => _delete(item),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
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
