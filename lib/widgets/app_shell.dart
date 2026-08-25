import 'package:flutter/material.dart';

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

  const AppShell({
    super.key,
    required this.title,
    required this.groups,
    this.initialGroup = 0,
    this.initialLeaf = 0,
  });

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  late int _groupIndex = widget.initialGroup;
  late int _leafIndex = widget.initialLeaf;

  Widget _buildSidebar(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          Container(
            height: 64,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Text(
              'Mini ERP',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(height: 1),
          for (int g = 0; g < widget.groups.length; g++)
            _buildGroup(context, g),
        ],
      ),
    );
  }

  Widget _buildGroup(BuildContext context, int g) {
    final group = widget.groups[g];
    if (group.children.length == 1 && group.children.first.label == group.label) {
      // Single-leaf "group" (e.g. Dashboard) renders as a flat item.
      final selected = _groupIndex == g;
      return ListTile(
        leading: Icon(group.icon),
        title: Text(group.label),
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
      leading: Icon(group.icon),
      title: Text(group.label),
      initiallyExpanded: _groupIndex == g,
      children: [
        for (int l = 0; l < group.children.length; l++)
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: ListTile(
              dense: true,
              leading: Icon(group.children[l].icon, size: 18),
              title: Text(group.children[l].label),
              selected: _groupIndex == g && _leafIndex == l,
              onTap: () {
                setState(() {
                  _groupIndex = g;
                  _leafIndex = l;
                });
                _closeDrawerIfAny(context);
              },
            ),
          ),
      ],
    );
  }

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
                    _TopBar(title: currentLeaf.label),
                    Expanded(child: body),
                  ],
                ),
              ),
            ],
          ),
        );
      }

      return Scaffold(
        appBar: AppBar(title: Text(currentLeaf.label)),
        drawer: Drawer(child: _buildSidebar(context)),
        body: body,
      );
    });
  }
}

class _TopBar extends StatelessWidget {
  final String title;
  const _TopBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}
