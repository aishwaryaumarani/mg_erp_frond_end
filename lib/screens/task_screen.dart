import 'package:flutter/material.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../widgets/status_badge.dart';

/// Tasks & Reminders -- follow-up calls, payment reminders and to-do
/// checklists (backend/app/routers/tasks.py).
///
/// Reminders here are DATA, not delivery: nothing is pushed or emailed.
/// This screen polls the backend's reminder windows (/due-today,
/// /overdue, /upcoming) and surfaces them; that is the whole mechanism.
///
/// Payment reminders mostly arrive on their own -- posting a Sales or
/// Purchase Invoice with a due date books one automatically -- so this
/// screen is where they get worked, not usually where they are created.
class TaskScreen extends StatefulWidget {
  const TaskScreen({super.key});

  @override
  State<TaskScreen> createState() => _TaskScreenState();
}

/// Which reminder window the list is showing. Each maps to its own
/// backend endpoint rather than being filtered client-side, so "overdue"
/// always means what the server says it means.
enum _View { my, dueToday, overdue, upcoming, all }

class _TaskScreenState extends State<TaskScreen> {
  List<TaskModel> _tasks = [];
  List<Customer> _customers = [];
  List<Lead> _leads = [];
  List<AppUser> _users = [];
  Map<String, dynamic> _summary = {};
  bool _loading = true;
  String? _error;

  _View _view = _View.my;
  String? _typeFilter;
  bool _includeCompleted = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String get _path {
    switch (_view) {
      case _View.my:
        return '/api/tasks/my';
      case _View.dueToday:
        return '/api/tasks/due-today';
      case _View.overdue:
        return '/api/tasks/overdue';
      case _View.upcoming:
        return '/api/tasks/upcoming';
      case _View.all:
        return '/api/tasks/';
    }
  }

  Map<String, dynamic> get _query {
    switch (_view) {
      case _View.my:
        return {'include_completed': _includeCompleted ? 'true' : null, 'limit': 200};
      case _View.dueToday:
      case _View.overdue:
        return {};
      case _View.upcoming:
        return {'days': 30};
      case _View.all:
        return {
          'task_type': _typeFilter,
          'open_only': _includeCompleted ? null : 'true',
          'limit': 200,
        };
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        ApiService.instance.list(_path, query: _query),
        ApiService.instance.getOne('/api/tasks/summary'),
        ApiService.instance.list('/api/customers/'),
        ApiService.instance.list('/api/leads/'),
        // Assignment to someone else needs the company's user list, and
        // GET /api/users is company_admin-only (backend/app/routers/
        // users.py). Plain users just get tasks assigned to themselves.
        if (AuthService.instance.isCompanyAdmin) ApiService.instance.list('/api/users/'),
      ]);
      setState(() {
        _tasks = (results[0] as List).map((e) => TaskModel.fromJson(e as Map<String, dynamic>)).toList();
        _summary = results[1] as Map<String, dynamic>;
        _customers = (results[2] as List).map((e) => Customer.fromJson(e as Map<String, dynamic>)).toList();
        _leads = (results[3] as List).map((e) => Lead.fromJson(e as Map<String, dynamic>)).toList();
        _users = results.length > 4
            ? (results[4] as List).map((e) => AppUser.fromJson(e as Map<String, dynamic>)).toList()
            : [];
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
    );
  }

  Future<void> _createTask() async {
    final draft = await openTaskForm(context, null, _customers, _leads, _users);
    if (draft == null) return;
    try {
      await ApiService.instance.create('/api/tasks/', draft.toJson(includeChecklist: true));
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _createFollowUp() async {
    final body = await _openFollowUpForm(context, _customers, _leads, _users);
    if (body == null) return;
    try {
      await ApiService.instance.create('/api/tasks/follow-ups', body);
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _edit(TaskModel t) async {
    final draft = await openTaskForm(context, t, _customers, _leads, _users);
    if (draft == null) return;
    try {
      await ApiService.instance.update('/api/tasks/${t.id}', draft.toJson());
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _complete(TaskModel t) async {
    final body = await _openCompleteDialog(context, t);
    if (body == null) return;
    try {
      final res = await ApiService.instance.create('/api/tasks/${t.id}/complete', body);
      await _load();
      if (!mounted) return;
      final next = res['next_task'];
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(next == null
            ? 'Task completed.'
            : 'Task completed — next follow-up booked for ${next['due_date']}.')),
      );
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _setStatus(TaskModel t, String status) async {
    try {
      await ApiService.instance.patch('/api/tasks/${t.id}/status', {'status': status});
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _delete(TaskModel t) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('Delete "${t.title}"?'),
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
      await ApiService.instance.delete('/api/tasks/${t.id}');
      _load();
    } catch (e) {
      _showError(e);
    }
  }

  Future<void> _openDetail(TaskModel t) async {
    await showDialog(
      context: context,
      builder: (ctx) => _TaskDetailDialog(task: t, onChanged: _load),
    );
  }

  static Color priorityColor(String priority) {
    switch (priority) {
      case 'Urgent':
        return AppColors.rose;
      case 'High':
        return AppColors.orange;
      case 'Low':
        return AppColors.slate;
      default:
        return AppColors.brand;
    }
  }

  static IconData typeIcon(String type) {
    switch (type) {
      case 'Follow-up':
        return Icons.follow_the_signs_outlined;
      case 'Payment Reminder':
        return Icons.payments_outlined;
      case 'Call':
        return Icons.phone_outlined;
      case 'Meeting':
        return Icons.groups_outlined;
      default:
        return Icons.checklist_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Text('Tasks & Reminders', style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _createFollowUp,
                icon: const Icon(Icons.follow_the_signs_outlined, size: 18),
                label: const Text('Take Follow-up'),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: _createTask,
                icon: const Icon(Icons.add),
                label: const Text('New Task'),
              ),
            ]),
            const SizedBox(height: 14),
            Wrap(spacing: 10, runSpacing: 10, children: [
              _chip('Open', _summary['open_tasks'], AppColors.brand),
              _chip('Due today', _summary['due_today'], AppColors.amber),
              _chip('Overdue', _summary['overdue'], AppColors.rose),
              _chip('Follow-ups', _summary['open_follow_ups'], AppColors.violet),
              _chip('Payment reminders', _summary['open_payment_reminders'], AppColors.green),
              _chip('Mine', _summary['my_open_tasks'], AppColors.teal),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: SegmentedButton<_View>(
                  segments: const [
                    ButtonSegment(value: _View.my, label: Text('My Tasks'), icon: Icon(Icons.person_outline)),
                    ButtonSegment(value: _View.dueToday, label: Text('Due Today'), icon: Icon(Icons.today_outlined)),
                    ButtonSegment(value: _View.overdue, label: Text('Overdue'), icon: Icon(Icons.warning_amber_outlined)),
                    ButtonSegment(value: _View.upcoming, label: Text('Upcoming'), icon: Icon(Icons.event_outlined)),
                    ButtonSegment(value: _View.all, label: Text('All'), icon: Icon(Icons.list_alt_outlined)),
                  ],
                  selected: {_view},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) {
                    setState(() => _view = s.first);
                    _load();
                  },
                ),
              ),
            ]),
            if (_view == _View.all || _view == _View.my) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (_view == _View.all)
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _typeFilter,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Type', isDense: true),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('All types')),
                        for (final t in kTaskTypes) DropdownMenuItem<String?>(value: t, child: Text(t)),
                      ],
                      onChanged: (v) {
                        setState(() => _typeFilter = v);
                        _load();
                      },
                    ),
                  ),
                if (_view == _View.all) const SizedBox(width: 12),
                Expanded(
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('Show completed', style: TextStyle(fontSize: 13)),
                    value: _includeCompleted,
                    onChanged: (v) {
                      setState(() => _includeCompleted = v);
                      _load();
                    },
                  ),
                ),
              ]),
            ],
          ]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(_error!, style: const TextStyle(color: Colors.red)),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _tasks.isEmpty
                  ? Center(child: Text(_emptyMessage()))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: _tasks.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) => _taskTile(_tasks[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  String _emptyMessage() {
    switch (_view) {
      case _View.my:
        return 'Nothing assigned to you. Enjoy the quiet.';
      case _View.dueToday:
        return 'Nothing due today.';
      case _View.overdue:
        return 'Nothing overdue — all caught up.';
      case _View.upcoming:
        return 'Nothing scheduled in the next 30 days.';
      case _View.all:
        return 'No tasks yet. Create one, or take a follow-up on a customer.';
    }
  }

  Widget _chip(String label, dynamic value, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: AppColors.tintedBox(color, radius: 20),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${value ?? 0}', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(color: color, fontSize: 12)),
        ]),
      );

  Widget _taskTile(TaskModel t) {
    final color = t.isOverdue ? AppColors.rose : priorityColor(t.priority);
    final subtitleParts = <String>[
      if (t.dueDate != null) '${t.isOverdue ? 'Overdue — due' : 'Due'} ${t.dueDate}' else 'No due date',
      if (t.partyName != null) t.partyName!,
      if (t.assignedToName != null) t.assignedToName!,
      if (t.checklistTotal > 0) '${t.checklistDone}/${t.checklistTotal} done',
    ];

    return ListTile(
      onTap: () => _openDetail(t),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: AppColors.tintedBox(color, radius: 10, border: false),
        child: Icon(typeIcon(t.taskType), color: color, size: 20),
      ),
      title: Row(children: [
        Flexible(
          child: Text(
            t.title,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              decoration: t.status == 'Completed' ? TextDecoration.lineThrough : null,
              color: t.status == 'Completed' ? AppColors.slate : null,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: AppColors.tintedBox(priorityColor(t.priority), radius: 12),
          child: Text(t.priority,
              style: TextStyle(color: priorityColor(t.priority), fontSize: 10, fontWeight: FontWeight.w600)),
        ),
      ]),
      subtitle: Text(
        '${t.taskNo ?? ''} • ${t.taskType} • ${subtitleParts.join(' • ')}'
        '${t.description != null && t.description!.isNotEmpty ? '\n${t.description}' : ''}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      isThreeLine: t.description != null && t.description!.isNotEmpty,
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        StatusBadge(status: t.status),
        const SizedBox(width: 4),
        if (t.isOpen)
          IconButton(
            icon: const Icon(Icons.check_circle_outline),
            tooltip: 'Complete',
            onPressed: () => _complete(t),
          ),
        PopupMenuButton<String>(
          tooltip: 'More',
          onSelected: (v) {
            switch (v) {
              case 'edit':
                _edit(t);
              case 'start':
                _setStatus(t, 'In Progress');
              case 'reopen':
                _setStatus(t, 'Pending');
              case 'cancel':
                _setStatus(t, 'Cancelled');
              case 'delete':
                _delete(t);
            }
          },
          itemBuilder: (ctx) => [
            if (t.isOpen) const PopupMenuItem(value: 'edit', child: Text('Edit')),
            if (t.status == 'Pending') const PopupMenuItem(value: 'start', child: Text('Mark In Progress')),
            if (!t.isOpen) const PopupMenuItem(value: 'reopen', child: Text('Reopen')),
            if (t.isOpen) const PopupMenuItem(value: 'cancel', child: Text('Cancel task')),
            const PopupMenuItem(value: 'delete', child: Text('Delete')),
          ],
        ),
      ]),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail dialog -- description, outcome, and the live checklist. Checklist
// edits hit the backend immediately (one row per tick) rather than being
// batched into a save, so a half-finished checklist is never lost.
// ---------------------------------------------------------------------------

class _TaskDetailDialog extends StatefulWidget {
  final TaskModel task;
  final VoidCallback onChanged;
  const _TaskDetailDialog({required this.task, required this.onChanged});

  @override
  State<_TaskDetailDialog> createState() => _TaskDetailDialogState();
}

class _TaskDetailDialogState extends State<_TaskDetailDialog> {
  late TaskModel _task = widget.task;
  final _newItemCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _newItemCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final json = await ApiService.instance.getOne('/api/tasks/${_task.id}');
    if (!mounted) return;
    setState(() => _task = TaskModel.fromJson(json));
    widget.onChanged();
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e is ApiException ? e.message : e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = _task;
    return AlertDialog(
      title: Row(children: [
        Icon(_TaskScreenState.typeIcon(t.taskType), color: _TaskScreenState.priorityColor(t.priority)),
        const SizedBox(width: 10),
        Expanded(child: Text(t.title)),
      ]),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(spacing: 8, runSpacing: 8, children: [
              StatusBadge(status: t.status),
              _pill(t.taskType, AppColors.violet),
              _pill(t.priority, _TaskScreenState.priorityColor(t.priority)),
              if (t.dueDate != null)
                _pill('Due ${t.dueDate}', t.isOverdue ? AppColors.rose : AppColors.slate),
              if (t.reminderDate != null && t.reminderDate != t.dueDate)
                _pill('Remind ${t.reminderDate}', AppColors.amber),
            ]),
            const SizedBox(height: 14),
            if (t.taskNo != null)
              Text(t.taskNo!, style: const TextStyle(color: AppColors.slate, fontSize: 12)),
            if (t.partyName != null)
              Text('For: ${t.partyName}', style: const TextStyle(color: AppColors.slate, fontSize: 12)),
            if (t.assignedToName != null)
              Text('Assigned to: ${t.assignedToName}', style: const TextStyle(color: AppColors.slate, fontSize: 12)),
            if (t.referenceType != null)
              Text('Linked to: ${t.referenceType}${t.referenceId != null ? ' #${t.referenceId}' : ''}',
                  style: const TextStyle(color: AppColors.slate, fontSize: 12)),
            if (t.description != null && t.description!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Description', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Text(t.description!),
            ],
            if (t.outcome != null && t.outcome!.isNotEmpty) ...[
              const SizedBox(height: 14),
              Text('Outcome', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 4),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: AppColors.tintedBox(AppColors.green),
                child: Text(t.outcome!, style: const TextStyle(color: AppColors.green)),
              ),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Text('Checklist', style: Theme.of(context).textTheme.titleSmall),
              const Spacer(),
              if (t.checklistTotal > 0)
                Text('${t.checklistDone} of ${t.checklistTotal} done',
                    style: const TextStyle(color: AppColors.slate, fontSize: 12)),
            ]),
            if (t.checklistTotal > 0) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: t.checklistDone / t.checklistTotal,
                backgroundColor: AppColors.slate.withValues(alpha: 0.15),
              ),
            ],
            for (final item in t.checklist)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: item.isDone,
                onChanged: _busy
                    ? null
                    : (v) => _run(() => ApiService.instance
                        .patch('/api/tasks/${t.id}/checklist/${item.id}', {'is_done': v ?? false})
                        .then((_) {})),
                title: Text(
                  item.title,
                  style: TextStyle(
                    decoration: item.isDone ? TextDecoration.lineThrough : null,
                    color: item.isDone ? AppColors.slate : null,
                  ),
                ),
                secondary: IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  tooltip: 'Remove',
                  onPressed: _busy
                      ? null
                      : () => _run(() =>
                          ApiService.instance.delete('/api/tasks/${t.id}/checklist/${item.id}')),
                ),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _newItemCtrl,
                  decoration: const InputDecoration(labelText: 'Add a checklist item', isDense: true),
                  onSubmitted: (_) => _addItem(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Add',
                onPressed: _busy ? null : _addItem,
              ),
            ]),
          ]),
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    );
  }

  void _addItem() {
    final title = _newItemCtrl.text.trim();
    if (title.isEmpty) return;
    _newItemCtrl.clear();
    _run(() => ApiService.instance
        .create('/api/tasks/${_task.id}/checklist', {'title': title}).then((_) {}));
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: AppColors.tintedBox(color, radius: 20),
        child: Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}

// ---------------------------------------------------------------------------
// Forms
// ---------------------------------------------------------------------------

/// Full task form. Public so other screens (e.g. a customer detail) could
/// book a task without duplicating this dialog.
Future<TaskModel?> openTaskForm(
  BuildContext context,
  TaskModel? existing,
  List<Customer> customers,
  List<Lead> leads,
  List<AppUser> users,
) {
  final titleCtrl = TextEditingController(text: existing?.title ?? '');
  final descCtrl = TextEditingController(text: existing?.description ?? '');
  final dueCtrl = TextEditingController(text: existing?.dueDate ?? '');
  final remindCtrl = TextEditingController(text: existing?.reminderDate ?? '');
  String taskType = existing?.taskType ?? 'To-do';
  String priority = existing?.priority ?? 'Medium';
  int? customerId = existing?.customerId;
  int? leadId = existing?.leadId;
  int? assignedToId = existing?.assignedToId;
  final checklist = <TaskChecklistItem>[];
  final newItemCtrl = TextEditingController();

  return showDialog<TaskModel>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: Text(existing == null ? 'New Task' : 'Edit Task'),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                controller: titleCtrl,
                decoration: const InputDecoration(labelText: 'Title'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'What needs doing, and anything the person should know first',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: taskType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: [for (final t in kTaskTypes) DropdownMenuItem(value: t, child: Text(t))],
                    onChanged: (v) => setState(() => taskType = v ?? 'To-do'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: priority,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: [for (final p in kTaskPriorities) DropdownMenuItem(value: p, child: Text(p))],
                    onChanged: (v) => setState(() => priority = v ?? 'Medium'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: _DateField(
                    controller: dueCtrl,
                    label: 'Due date',
                    onPicked: () => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DateField(
                    controller: remindCtrl,
                    label: 'Remind on',
                    helper: 'Defaults to the due date',
                    onPicked: () => setState(() {}),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              // A task belongs to at most one party -- picking a customer
              // clears any lead and vice versa, mirroring the backend's
              // one-party rule for follow-ups.
              DropdownButtonFormField<int?>(
                value: customerId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Customer (optional)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None')),
                  for (final c in customers) DropdownMenuItem<int?>(value: c.id, child: Text(c.name)),
                ],
                onChanged: (v) => setState(() {
                  customerId = v;
                  if (v != null) leadId = null;
                }),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int?>(
                value: leadId,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Lead (optional)'),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('None')),
                  for (final l in leads) DropdownMenuItem<int?>(value: l.id, child: Text(l.name)),
                ],
                onChanged: (v) => setState(() {
                  leadId = v;
                  if (v != null) customerId = null;
                }),
              ),
              if (users.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: assignedToId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Assign to',
                    helperText: 'Leave empty to keep it yourself',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Me')),
                    for (final u in users) DropdownMenuItem<int?>(value: u.id, child: Text(u.fullName)),
                  ],
                  onChanged: (v) => setState(() => assignedToId = v),
                ),
              ],
              // Checklist is create-only -- on an existing task it is
              // edited live in the detail dialog instead (TaskUpdate has
              // no checklist field).
              if (existing == null) ...[
                const SizedBox(height: 16),
                Row(children: [
                  Text('Checklist', style: Theme.of(ctx).textTheme.titleSmall),
                  const Spacer(),
                ]),
                for (int i = 0; i < checklist.length; i++)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.check_box_outline_blank, size: 20),
                    title: Text(checklist[i].title),
                    trailing: IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => setState(() => checklist.removeAt(i)),
                    ),
                  ),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: newItemCtrl,
                      decoration: const InputDecoration(labelText: 'Add an item', isDense: true),
                      onSubmitted: (v) {
                        if (v.trim().isEmpty) return;
                        setState(() {
                          checklist.add(TaskChecklistItem(title: v.trim(), position: checklist.length));
                          newItemCtrl.clear();
                        });
                      },
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () {
                      final v = newItemCtrl.text.trim();
                      if (v.isEmpty) return;
                      setState(() {
                        checklist.add(TaskChecklistItem(title: v, position: checklist.length));
                        newItemCtrl.clear();
                      });
                    },
                  ),
                ]),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(
                ctx,
                TaskModel(
                  id: existing?.id,
                  title: titleCtrl.text.trim(),
                  description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                  taskType: taskType,
                  priority: priority,
                  status: existing?.status ?? 'Pending',
                  dueDate: dueCtrl.text.trim().isEmpty ? null : dueCtrl.text.trim(),
                  reminderDate: remindCtrl.text.trim().isEmpty ? null : remindCtrl.text.trim(),
                  assignedToId: assignedToId,
                  customerId: customerId,
                  leadId: leadId,
                  referenceType: existing?.referenceType,
                  referenceId: existing?.referenceId,
                  checklist: checklist,
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

/// "Take a follow-up with this customer/lead". Returns the raw
/// FollowUpCreate body -- the backend fills in the title, the assignee
/// and the document link, so there is less to ask for here than in the
/// full task form.
Future<Map<String, dynamic>?> _openFollowUpForm(
  BuildContext context,
  List<Customer> customers,
  List<Lead> leads,
  List<AppUser> users,
) {
  String party = 'customer'; // customer | lead
  int? customerId;
  int? leadId;
  String taskType = 'Follow-up';
  String priority = 'Medium';
  int? assignedToId;
  final descCtrl = TextEditingController();
  final dueCtrl = TextEditingController(
    text: DateTime.now().add(const Duration(days: 1)).toIso8601String().substring(0, 10),
  );

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: const Text('Take Follow-up'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'customer', label: Text('Customer'), icon: Icon(Icons.people_outline)),
                  ButtonSegment(value: 'lead', label: Text('Lead'), icon: Icon(Icons.person_search_outlined)),
                ],
                selected: {party},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  party = s.first;
                  // Exactly one of customer/lead may be set -- the
                  // backend rejects both or neither.
                  customerId = null;
                  leadId = null;
                }),
              ),
              const SizedBox(height: 14),
              if (party == 'customer')
                DropdownButtonFormField<int?>(
                  value: customerId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Customer'),
                  items: [
                    for (final c in customers)
                      DropdownMenuItem<int?>(value: c.id, child: Text('${c.name} (${c.customerCode})')),
                  ],
                  onChanged: (v) => setState(() => customerId = v),
                )
              else
                DropdownButtonFormField<int?>(
                  value: leadId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Lead'),
                  items: [
                    for (final l in leads) DropdownMenuItem<int?>(value: l.id, child: Text(l.name)),
                  ],
                  onChanged: (v) => setState(() => leadId = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(
                  labelText: 'What is this follow-up about?',
                  hintText: 'e.g. Ask about the pending PO, confirm delivery date',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: taskType,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'How'),
                    items: const [
                      DropdownMenuItem(value: 'Follow-up', child: Text('Follow-up')),
                      DropdownMenuItem(value: 'Call', child: Text('Call')),
                      DropdownMenuItem(value: 'Meeting', child: Text('Meeting')),
                    ],
                    onChanged: (v) => setState(() => taskType = v ?? 'Follow-up'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: priority,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: [for (final p in kTaskPriorities) DropdownMenuItem(value: p, child: Text(p))],
                    onChanged: (v) => setState(() => priority = v ?? 'Medium'),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              _DateField(controller: dueCtrl, label: 'Follow up on', onPicked: () => setState(() {})),
              if (users.isNotEmpty) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<int?>(
                  value: assignedToId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Assign to'),
                  items: [
                    const DropdownMenuItem<int?>(value: null, child: Text('Me')),
                    for (final u in users) DropdownMenuItem<int?>(value: u.id, child: Text(u.fullName)),
                  ],
                  onChanged: (v) => setState(() => assignedToId = v),
                ),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (party == 'customer' && customerId == null) return;
              if (party == 'lead' && leadId == null) return;
              Navigator.pop(ctx, {
                'customer_id': customerId,
                'lead_id': leadId,
                'description': descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                'task_type': taskType,
                'priority': priority,
                'due_date': dueCtrl.text.trim().isEmpty ? null : dueCtrl.text.trim(),
                'assigned_to_id': assignedToId,
              });
            },
            child: const Text('Book Follow-up'),
          ),
        ],
      );
    }),
  );
}

/// Complete dialog -- records what happened and, optionally, books the
/// next follow-up in the same call, since a follow-up usually ends by
/// agreeing when to talk again.
Future<Map<String, dynamic>?> _openCompleteDialog(BuildContext context, TaskModel task) {
  final outcomeCtrl = TextEditingController();
  final nextDateCtrl = TextEditingController();
  final nextDescCtrl = TextEditingController();
  bool bookNext = false;

  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (ctx) => StatefulBuilder(builder: (ctx, setState) {
      return AlertDialog(
        title: const Text('Complete Task'),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(task.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              TextField(
                controller: outcomeCtrl,
                decoration: const InputDecoration(
                  labelText: 'What happened?',
                  hintText: 'e.g. Spoke to Ravi, will confirm on Friday',
                ),
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: bookNext,
                title: const Text('Book the next follow-up'),
                onChanged: (v) => setState(() {
                  bookNext = v ?? false;
                  if (bookNext && nextDateCtrl.text.isEmpty) {
                    nextDateCtrl.text =
                        DateTime.now().add(const Duration(days: 7)).toIso8601String().substring(0, 10);
                  }
                }),
              ),
              if (bookNext) ...[
                _DateField(controller: nextDateCtrl, label: 'Next follow-up on', onPicked: () => setState(() {})),
                const SizedBox(height: 12),
                TextField(
                  controller: nextDescCtrl,
                  decoration: const InputDecoration(labelText: 'What to cover next time'),
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                ),
              ],
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, {
              'outcome': outcomeCtrl.text.trim().isEmpty ? null : outcomeCtrl.text.trim(),
              'next_follow_up_date':
                  bookNext && nextDateCtrl.text.trim().isNotEmpty ? nextDateCtrl.text.trim() : null,
              'next_follow_up_description':
                  bookNext && nextDescCtrl.text.trim().isNotEmpty ? nextDescCtrl.text.trim() : null,
            }),
            child: const Text('Complete'),
          ),
        ],
      );
    }),
  );
}

/// Date field with a picker. Every other screen in this app types dates
/// as YYYY-MM-DD text; tasks are picked far more often than typed, so
/// this keeps the same string format but offers a calendar.
class _DateField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helper;
  final VoidCallback onPicked;

  const _DateField({
    required this.controller,
    required this.label,
    required this.onPicked,
    this.helper,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        suffixIcon: Row(mainAxisSize: MainAxisSize.min, children: [
          if (controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear, size: 18),
              tooltip: 'Clear',
              onPressed: () {
                controller.clear();
                onPicked();
              },
            ),
          const Icon(Icons.calendar_today_outlined, size: 18),
          const SizedBox(width: 8),
        ]),
      ),
      onTap: () async {
        final initial = DateTime.tryParse(controller.text) ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: DateTime.now().subtract(const Duration(days: 365)),
          lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
        );
        if (picked == null) return;
        controller.text = picked.toIso8601String().substring(0, 10);
        onPicked();
      },
    );
  }
}
