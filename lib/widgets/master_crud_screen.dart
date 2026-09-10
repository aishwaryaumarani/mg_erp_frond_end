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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
        icon: Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: AppColors.tintedBox(AppColors.rose,
              radius: AppRadius.card, border: false),
          child: const Icon(Icons.delete_outline, color: AppColors.rose),
        ),
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
            _toolbar(),
            const Divider(),
            if (_error != null) _errorBanner(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _items.isEmpty
                      ? _EmptyState(
                          entityName: widget.entityName,
                          searching: _searchCtrl.text.isNotEmpty,
                          onCreate: _create,
                          onClearSearch: () {
                            _searchCtrl.clear();
                            _load();
                          },
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: EdgeInsets.zero,
                            itemCount: _items.length,
                            separatorBuilder: (_, __) => const Divider(),
                            itemBuilder: (context, i) => _row(_items[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  /// Search, record count and the create button. The count sits with the
  /// search box because after a query it is the answer to "how many
  /// matched", which is the first thing anyone looks for.
  Widget _toolbar() {
    return Container(
      color: AppColors.surfaceAlt,
      padding: const EdgeInsets.fromLTRB(18, 15, 18, 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final narrow = constraints.maxWidth < 620;
          final search = widget.searchable
              ? TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.entityName.toLowerCase()}s…',
                    prefixIcon: const Icon(Icons.search, size: 19),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    suffixIcon: _searchCtrl.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 17),
                            tooltip: 'Clear search',
                            onPressed: () {
                              _searchCtrl.clear();
                              _load();
                            },
                          ),
                  ),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: (_) => _load(),
                )
              : const SizedBox.shrink();

          final button = FilledButton.icon(
            onPressed: _create,
            icon: const Icon(Icons.add, size: 19),
            label: Text('New ${widget.entityName}'),
          );

          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.searchable) ...[search, const SizedBox(height: 12)],
                button,
              ],
            );
          }
          return Row(
            children: [
              if (widget.searchable) ...[
                Expanded(child: search),
                const SizedBox(width: 14),
              ],
              if (!_loading) ...[_countChip(), const SizedBox(width: 14)],
              button,
            ],
          );
        },
      ),
    );
  }

  Widget _countChip() {
    final n = _items.length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.chip),
        border: Border.all(color: AppColors.line),
      ),
      child: Text(
        n == 1 ? '1 record' : '$n records',
        style: const TextStyle(
          color: AppColors.slate,
          fontSize: 12,
          fontWeight: FontWeight.w700,
          fontFeatures: [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  Widget _errorBanner() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
        child: Container(
          padding: const EdgeInsets.all(13),
          decoration:
              AppColors.tintedBox(AppColors.rose, radius: AppRadius.field),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: AppColors.rose, size: 19),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(
                    color: AppColors.rose,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  /// A record row. Rows are separated by hairlines rather than floated as
  /// individual boxes -- a long master list reads as a register that way,
  /// and the eye can run down the titles without a border interrupting
  /// every line.
  Widget _row(T item) {
    final title = widget.titleOf(item);
    final grade = widget.gradeOf?.call(item);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _edit(item),
        hoverColor: AppColors.brandWash.withValues(alpha: 0.6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.brandWash,
                  borderRadius: BorderRadius.circular(AppRadius.chip),
                  border: Border.all(
                      color: AppColors.brand.withValues(alpha: 0.12)),
                ),
                child: Text(
                  title.isEmpty ? '?' : title.characters.first.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.brand,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 14.5,
                      ),
                    ),
                    if (widget.subtitleOf != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitleOf!(item),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (grade != null && grade.isNotEmpty) ...[
                GradeBadge(grade: grade),
                const SizedBox(width: 10),
              ],
              if (widget.statusOf != null) ...[
                StatusBadge(status: widget.statusOf!(item)),
                const SizedBox(width: 10),
              ],
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 19),
                color: AppColors.slate,
                onPressed: () => _edit(item),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 19),
                color: AppColors.rose,
                onPressed: () => _delete(item),
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String entityName;
  final bool searching;
  final VoidCallback onCreate;
  final VoidCallback onClearSearch;

  const _EmptyState({
    required this.entityName,
    required this.searching,
    required this.onCreate,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(color: AppColors.line),
              ),
              child: Icon(
                searching ? Icons.search_off_outlined : Icons.inbox_outlined,
                color: AppColors.faint,
                size: 26,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              searching ? 'No matches' : 'No ${entityName.toLowerCase()}s yet',
              style: AppText.serif(fontSize: 19),
            ),
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: Text(
                searching
                    ? 'Nothing here matches that search. Try a different term, or clear it to see everything.'
                    : 'Create the first record to start building this master list.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const SizedBox(height: 22),
            if (searching)
              OutlinedButton.icon(
                onPressed: onClearSearch,
                icon: const Icon(Icons.close, size: 18),
                label: const Text('Clear search'),
              )
            else
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add, size: 19),
                label: Text('New $entityName'),
              ),
          ],
        ),
      ),
    );
  }
}
