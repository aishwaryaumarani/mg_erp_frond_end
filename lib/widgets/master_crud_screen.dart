import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'grade_field.dart';
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
  /// Optional customer-grade pill shown before the status badge; return
  /// null for records that carry no grade (see widgets/grade_field.dart).
  final String? Function(T)? gradeOf;
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
    this.gradeOf,
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
    // Only the grade-carrying masters (Customer) need the server's list.
    if (widget.gradeOf != null) GradeOptions.ensureLoaded();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final query = _searchCtrl.text.isEmpty ? null : {'q': _searchCtrl.text};
      final raw =
          await ApiService.instance.list(widget.resourcePath, query: query);
      setState(() {
        _items =
            raw.map((e) => widget.fromJson(e as Map<String, dynamic>)).toList();
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
      await ApiService.instance
          .create(widget.resourcePath, widget.toJson(result));
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
      await ApiService.instance
          .update('${widget.resourcePath}$id', widget.toJson(result));
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
        content: Text(
            'Delete "${widget.titleOf(item)}"? This can be undone by re-adding it; historical transactions are preserved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(18),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final narrow = constraints.maxWidth < 620;
                  final search = widget.searchable
                      ? TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText:
                                'Search ${widget.entityName.toLowerCase()}s...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _load(),
                        )
                      : const SizedBox.shrink();
                  final button = FilledButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add),
                    label: Text('New ${widget.entityName}'),
                  );
                  if (narrow) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.searchable) search,
                        if (widget.searchable) const SizedBox(height: 12),
                        button,
                      ],
                    );
                  }
                  return Row(
                    children: [
                      if (widget.searchable) Expanded(child: search),
                      if (widget.searchable) const SizedBox(width: 12),
                      button,
                    ],
                  );
                },
              ),
            ),
            const Divider(height: 1),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: AppColors.tintedBox(AppColors.rose, radius: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.rose, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                          child: Text(_error!,
                              style: const TextStyle(color: AppColors.rose))),
                    ],
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _EmptyState(
                          entityName: widget.entityName, onCreate: _create)
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.all(18),
                            itemCount: _items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final item = _items[i];
                              final accent = AppColors.accentAt(i);
                              final title = widget.titleOf(item);
                              return Container(
                                decoration: BoxDecoration(
                                  color: AppColors.surface,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.line),
                                ),
                                child: ListTile(
                                  minVerticalPadding: 14,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 6),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8)),
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: AppColors.tintedBox(accent,
                                        radius: 8, border: false),
                                    child: Text(
                                      title.isEmpty
                                          ? '?'
                                          : title.characters.first
                                              .toUpperCase(),
                                      style: TextStyle(
                                        color: accent,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: AppColors.ink,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  subtitle: widget.subtitleOf != null
                                      ? Padding(
                                          padding:
                                              const EdgeInsets.only(top: 4),
                                          child: Text(
                                            widget.subtitleOf!(item),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                color: AppColors.muted),
                                          ),
                                        )
                                      : null,
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (widget.gradeOf?.call(item)
                                              ?.isNotEmpty ??
                                          false) ...[
                                        GradeBadge(
                                            grade: widget.gradeOf!(item)!),
                                        const SizedBox(width: 8),
                                      ],
                                      if (widget.statusOf != null) ...[
                                        StatusBadge(
                                            status: widget.statusOf!(item)),
                                        const SizedBox(width: 8),
                                      ],
                                      IconButton(
                                        icon: const Icon(Icons.edit_outlined),
                                        color: AppColors.brand,
                                        onPressed: () => _edit(item),
                                        tooltip: 'Edit',
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline),
                                        color: AppColors.rose,
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
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String entityName;
  final VoidCallback onCreate;

  const _EmptyState({required this.entityName, required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: AppColors.tintedBox(AppColors.brand,
                  radius: 8, border: false),
              child: const Icon(Icons.inbox_outlined, color: AppColors.brand),
            ),
            const SizedBox(height: 14),
            Text(
              'No ${entityName.toLowerCase()}s yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.ink,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Create the first record to start building this master list.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: Text('New $entityName'),
            ),
          ],
        ),
      ),
    );
  }
}
