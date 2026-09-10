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

/// App-wide shell: navy sidebar (spec sec 14/16) on the left, selected
/// screen on the right. Works as a persistent rail on wide screens and a
/// drawer on narrow ones.
///
/// The rail is dark on purpose: it holds the navigation still and lets the
/// working area stay a clean, paper-white sheet, which is what makes a
/// data-dense ERP readable for a whole shift.
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.brandDark, AppColors.brandDarker],
        ),
      ),
      child: Column(
        children: [
          _buildBrandHeader(context),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 20),
              children: [
                for (int g = 0; g < widget.groups.length; g++)
                  _buildGroup(context, g),
              ],
            ),
          ),
          _buildSidebarFooter(context),
        ],
      ),
    );
  }

  /// The wordmark block. The logo sits on its own white plate because the
  /// uploaded company logo is drawn for paper -- dark ink on white -- and
  /// would disappear straight onto the navy.
  Widget _buildBrandHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.navLine)),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            padding: const EdgeInsets.all(5),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(AppRadius.field),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const BrandLogo(height: 36),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kCompanyName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Container(width: 14, height: 1.5, color: AppColors.gold),
                    const SizedBox(width: 7),
                    const Text(
                      'OPERATIONS ERP',
                      style: TextStyle(
                        color: AppColors.goldLight,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebarFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.navLine)),
      ),
      child: Text(
        'Product · Sales · Purchase · Accounts',
        style: TextStyle(
          color: AppColors.navMuted.withValues(alpha: 0.75),
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }

  Widget _buildGroup(BuildContext context, int g) {
    final group = widget.groups[g];

    // A single-leaf group whose leaf repeats its own name (Dashboard,
    // Settings, Team) renders flat -- an expander around one row would be
    // a click that buys nothing.
    if (group.children.length == 1 &&
        group.children.first.label == group.label) {
      return _navTile(
        context,
        icon: group.icon,
        label: group.label,
        selected: _groupIndex == g,
        onTap: () {
          setState(() {
            _groupIndex = g;
            _leafIndex = 0;
          });
          _closeDrawerIfAny(context);
        },
      );
    }

    final open = _groupIndex == g;
    return Theme(
      data: Theme.of(context).copyWith(
        dividerColor: Colors.transparent,
        hoverColor: Colors.white.withValues(alpha: 0.04),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.fromLTRB(18, 0, 14, 0),
        minTileHeight: 46,
        leading: _iconChip(group.icon, open),
        title: Text(
          group.label,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: open ? Colors.white : AppColors.navText,
            fontSize: 13.5,
            letterSpacing: 0.1,
          ),
        ),
        iconColor: AppColors.goldLight,
        collapsedIconColor: AppColors.navMuted,
        initiallyExpanded: open,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        children: [
          for (int l = 0; l < group.children.length; l++)
            _navTile(
              context,
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

  /// Sidebar row. Unselected rows are quiet blue-grey on the navy; the
  /// selected one gets a gold edge marker, a lightened ground and white
  /// text, so exactly one row in the rail ever reads as "here".
  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
    bool dense = false,
  }) {
    final fg = selected ? Colors.white : AppColors.navText;
    return Padding(
      padding: EdgeInsets.fromLTRB(dense ? 20 : 12, 1.5, 12, 1.5),
      child: Material(
        color: selected
            ? Colors.white.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.field),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.field),
          hoverColor: Colors.white.withValues(alpha: 0.06),
          splashColor: Colors.white.withValues(alpha: 0.05),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, dense ? 9 : 11, 10, dense ? 9 : 11),
            child: Row(
              children: [
                // The gold marker is the only place the accent appears in
                // the rail, so the eye finds the current screen instantly.
                Container(
                  width: 3,
                  height: dense ? 16 : 18,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.gold : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                ),
                Icon(
                  icon,
                  size: dense ? 17 : 19,
                  color: selected ? AppColors.goldLight : AppColors.navMuted,
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: fg,
                      fontSize: dense ? 12.8 : 13.5,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                      letterSpacing: 0.05,
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

  Widget _iconChip(IconData icon, bool open) => Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: open ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(AppRadius.chip),
        ),
        child: Icon(
          icon,
          size: 17,
          color: open ? AppColors.goldLight : AppColors.navMuted,
        ),
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
              SizedBox(width: 268, child: _buildSidebar(context)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _TopBar(
                      group: currentGroup.label,
                      title: currentLeaf.label,
                      icon: currentLeaf.icon,
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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(currentLeaf.label, style: AppText.serif(fontSize: 17)),
              Text(
                currentGroup.label.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.9,
                ),
              ),
            ],
          ),
          actions: widget.actions,
        ),
        drawer: Drawer(
          width: 286,
          child: _buildSidebar(context),
        ),
        body: body,
      );
    });
  }
}

/// The working-area header: a breadcrumb over the screen title on the
/// left, the signed-in user on the right. It repeats the module name so
/// the page still says where it is once the rail scrolls out of mind.
class _TopBar extends StatelessWidget {
  final String group;
  final String title;
  final IconData icon;
  final Color color;
  final List<Widget> actions;

  const _TopBar({
    required this.group,
    required this.title,
    required this.icon,
    required this.color,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 74,
      padding: const EdgeInsets.symmetric(horizontal: 28),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.line)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: AppColors.tintedBox(color, radius: AppRadius.field),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        group.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: color,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                    if (group != title) ...[
                      const SizedBox(width: 6),
                      const Text(
                        '/',
                        style: TextStyle(
                          color: AppColors.faint,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          title.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.faint,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.serif(fontSize: 20),
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
