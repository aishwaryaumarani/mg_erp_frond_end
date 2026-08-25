import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'status_badge.dart';

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
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
              if (widget.searchable)
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search ${widget.entityName.toLowerCase()}s...',
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
                label: Text('New ${widget.entityName}'),
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
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final item = _items[i];
                          return ListTile(
                            title: Text(widget.titleOf(item)),
                            subtitle: widget.subtitleOf != null
                                ? Text(widget.subtitleOf!(item))
                                : null,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.statusOf != null) ...[
                                  StatusBadge(status: widget.statusOf!(item)),
                                  const SizedBox(width: 12),
                                ],
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _edit(item),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => _delete(item),
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
