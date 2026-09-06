import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'brand_logo.dart';

class NavLeaf {
  final String label;
  final IconData icon;
  final WidgetBuilder builder;
  const NavLeaf(this.label, this.icon, this.builder);
}

class NavGroup {
  final String label;
  final IconData icon;
  final List<NavLeaf> children;
  const NavGroup(this.label, this.icon, this.children);
}

/// Lets descendants drive the shell's sidebar selection -- the Dashboard's
/// KPI tiles use it so tapping a tile lands on exactly the screen the
/// sidebar would have opened, instead of pushing a second copy on top.
class AppShellNav extends InheritedWidget {
  final void Function(String group, String leaf) goTo;

  /// Whether a destination is actually in this shell. Destinations come
  /// and go with the signed-in user's departments (see main.dart), so a
  /// caller must ask before offering a tap that would lead nowhere.
  final bool Function(String group, String leaf) has;

  const AppShellNav({
    super.key,
    required this.goTo,
    required this.has,
    required super.child,
  });

  /// Deliberately does not register a dependency -- callers only invoke
  /// [goTo] from a tap handler, and the callback always dispatches to the
  /// live shell State.
  static AppShellNav? maybeOf(BuildContext context) =>
      context.getElementForInheritedWidgetOfExactType<AppShellNav>()?.widget
          as AppShellNav?;

  @override
  bool updateShouldNotify(AppShellNav oldWidget) => false;
}

/// App-wide shell: collapsible sidebar (spec sec 14/16) on the left,
/// selected screen on the right. Works as a persistent rail on wide
/// screens and a drawer on narrow ones.
class AppShell extends StatefulWidget {
  final String title;
  final List<NavGroup> groups;
  final int initialGroup;
  final int initialLeaf;
  final List<Widget> actions;

  const AppShell({
    super.key,
    required this.title,
    required this.groups,
    this.initialGroup = 0,
    this.initialLeaf = 0,
    this.actions = const [],
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _groupIndex = widget.initialGroup;
  late int _leafIndex = widget.initialLeaf;

  /// Selects a destination by its sidebar labels, e.g. ('Masters',
  /// 'Products'). Labels are what the Dashboard tiles carry, so nav
  /// targets stay readable at the call site.
  void _goTo(String group, String leaf) {
    final target = _find(group, leaf);
    if (target == null) {
      // Not an error any more: main.dart drops whole groups the signed-in
      // user has no permission for, so a Dashboard tile pointing at
      // Purchase is simply unreachable for a Sales-only user. Callers are
      // expected to check [_has] and not offer the tap at all -- this
      // guard keeps a missed check from crashing them.
      debugPrint('AppShell has no "$group / $leaf" destination');
      return;
    }
    setState(() {
      _groupIndex = target.$1;
      _leafIndex = target.$2;
    });
  }

  /// Whether this shell currently contains the destination -- false once
  /// the group was filtered out for lacking the department permission.
  bool _has(String group, String leaf) => _find(group, leaf) != null;

  (int, int)? _find(String group, String leaf) {
    for (int g = 0; g < widget.groups.length; g++) {
      if (widget.groups[g].label != group) continue;
      final children = widget.groups[g].children;
      for (int l = 0; l < children.length; l++) {
        if (children[l].label == leaf) return (g, l);
      }
    }
    return null;
  }

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: AppColors.surface,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _buildBrandHeader(context),
          const SizedBox(height: 12),
          for (int g = 0; g < widget.groups.length; g++)
            _buildGroup(context, g),
        ],
      ),
    );
  }

  Widget _buildBrandHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            child: const BrandLogo(height: 46),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kCompanyName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Operations ERP',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, int g) {
    final group = widget.groups[g];
    final color = AppColors.forModule(group.label);

    if (group.children.length == 1 &&
        group.children.first.label == group.label) {
      final selected = _groupIndex == g;
      return _navTile(
        context,
        color: color,
        icon: group.icon,
        label: group.label,
        selected: selected,
        onTap: () {
          setState(() {
            _groupIndex = g;
            _leafIndex = 0;
          });
          _closeDrawerIfAny(context);
        },
      );
    }
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(16, 2, 12, 2),
        leading: _iconChip(group.icon, color),
        title: Text(
          group.label,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColors.ink,
            fontSize: 14,
          ),
        ),
        iconColor: AppColors.muted,
        collapsedIconColor: AppColors.muted,
        initiallyExpanded: _groupIndex == g,
        childrenPadding: const EdgeInsets.only(bottom: 6),
        children: [
          for (int l = 0; l < group.children.length; l++)
            _navTile(
              context,
              color: color,
              icon: group.children[l].icon,
              label: group.children[l].label,
              selected: _groupIndex == g && _leafIndex == l,
              dense: true,
              onTap: () {
                setState(() {
                  _groupIndex = g;
                  _leafIndex = l;
                });
                _closeDrawerIfAny(context);
              },
            ),
        ],
      ),
    );
  }

  /// Sidebar row. Unselected rows stay neutral grey so the selected one
  /// -- tinted background, coloured icon and label -- is the only thing
  /// carrying the module colour at full strength.
  Widget _navTile(
    BuildContext context, {
    required Color color,
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool dense = false,
  }) {
    final fg = selected ? color : AppColors.slate;
    return Padding(
      padding: EdgeInsets.fromLTRB(dense ? 28 : 12, 2, 12, 2),
      child: Material(
        color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding:
                EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 9 : 11),
            child: Row(
              children: [
                if (selected)
                  Container(
                    width: 3,
                    height: 22,
                    margin: const EdgeInsets.only(right: 9),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  )
                else
                  const SizedBox(width: 12),
                Icon(icon, size: dense ? 17 : 19, color: fg),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: dense ? 13 : 14,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconChip(IconData icon, Color color) => Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: AppColors.tintedBox(color, radius: 8, border: false),
        child: Icon(icon, size: 18, color: color),
      );

  void _closeDrawerIfAny(BuildContext context) {
    final scaffold = Scaffold.maybeOf(context);
    if (scaffold != null && scaffold.isDrawerOpen) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentGroup = widget.groups[_groupIndex];
    final currentLeaf = currentGroup
        .children[_leafIndex < currentGroup.children.length ? _leafIndex : 0];

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;
      final body = AppShellNav(
        goTo: _goTo,
        has: _has,
        child: Builder(builder: (ctx) => currentLeaf.builder(ctx)),
      );

      if (isWide) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(width: 276, child: _buildSidebar(context)),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      title: currentLeaf.label,
                      color: AppColors.forModule(currentGroup.label),
                      actions: widget.actions,
                    ),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(
          title: Text(currentLeaf.label),
          backgroundColor: AppColors.surface,
          foregroundColor: AppColors.ink,
          actions: widget.actions,
        ),
        drawer: Drawer(child: _buildSidebar(context)),
        body: body,
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  final Color color;
  final List<Widget> actions;
  const _TopBar(
      {required this.title, required this.color, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: AppColors.tintedBox(color, radius: 8, border: false),
            child: Icon(Icons.layers_outlined, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink,
                      ),
                ),
                Text(
                  kCompanyName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
          ),
          IconTheme(
            data: const IconThemeData(color: AppColors.muted),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ],
      ),
    );
  }
}
