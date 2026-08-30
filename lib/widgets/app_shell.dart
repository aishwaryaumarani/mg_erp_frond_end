import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

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

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Colors.white,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildBrandHeader(context),
          const SizedBox(height: 8),
          for (int g = 0; g < widget.groups.length; g++)
            _buildGroup(context, g),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// Gradient masthead at the top of the sidebar -- the one place the
  /// brand blue runs full-bleed, so the coloured module icons below it
  /// read as a palette rather than as noise.
  Widget _buildBrandHeader(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brand, AppColors.indigo],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.science_outlined, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            'MG Chemicals',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, int g) {
    final group = widget.groups[g];
    // Each module owns a colour (AppColors.forModule) that tints its
    // icon chip and its selected rows, so the sidebar stays scannable
    // once every phase's nav items are present.
    final color = AppColors.forModule(group.label);

    if (group.children.length == 1 && group.children.first.label == group.label) {
      // Single-leaf "group" (e.g. Dashboard) renders as a flat item.
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
    return ExpansionTile(
      leading: _iconChip(group.icon, color),
      title: Text(
        group.label,
        style: TextStyle(fontWeight: FontWeight.w600, color: color),
      ),
      iconColor: color,
      collapsedIconColor: color.withOpacity(0.6),
      initiallyExpanded: _groupIndex == g,
      childrenPadding: const EdgeInsets.only(bottom: 4),
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
      padding: EdgeInsets.only(left: dense ? 20 : 8, right: 8, bottom: 2),
      child: Material(
        color: selected ? color.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: dense ? 9 : 12),
            child: Row(
              children: [
                Icon(icon, size: dense ? 18 : 20, color: fg),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: dense ? 13 : 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
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
        padding: const EdgeInsets.all(7),
        decoration: AppColors.tintedBox(color, radius: 9, border: false),
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
    final currentLeaf = currentGroup.children[
        _leafIndex < currentGroup.children.length ? _leafIndex : 0];

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth >= 900;
      final body = Builder(builder: (ctx) => currentLeaf.builder(ctx));

      if (isWide) {
        return Scaffold(
          body: Row(
            children: [
              SizedBox(width: 260, child: _buildSidebar(context)),
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
          backgroundColor: AppColors.forModule(currentGroup.label),
          foregroundColor: Colors.white,
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
  const _TopBar({required this.title, required this.color, this.actions = const []});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        // Faint wash of the active module's colour, so the header keeps
        // matching the sidebar selection as you move between modules.
        gradient: LinearGradient(
          colors: [color.withOpacity(0.10), Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        border: Border(bottom: BorderSide(color: color.withOpacity(0.25))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
            ),
          ),
          IconTheme(
            data: IconThemeData(color: color),
            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
          ),
        ],
      ),
    );
  }
}
