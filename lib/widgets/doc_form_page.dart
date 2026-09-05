import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Full-page scaffold for the sales documents (Inquiry, Quotation, Sales
/// Order). These forms carry a customer, dates, two addresses and a line
/// grid -- far too much for an AlertDialog, which clipped the item editor
/// on smaller windows and left no room on a phone. Pushing a route
/// instead gives the form the whole screen, a real back button and a
/// sticky Save bar, while keeping the same
/// `Future<T?> openXForm(...)` contract the list screens already await.
///
/// Pair it with [openDocFormPage] rather than pushing it by hand.
class DocFormPage extends StatelessWidget {
  final String title;

  /// Document number / customer line under the title, when there is one.
  final String? subtitle;
  final String saveLabel;

  /// Called on Save. Validate inside it and simply return without popping
  /// if something is missing -- see [showFormError].
  final VoidCallback onSave;
  final List<Widget> children;

  const DocFormPage({
    super.key,
    required this.title,
    this.subtitle,
    this.saveLabel = 'Save',
    required this.onSave,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Cancel',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            if (subtitle != null && subtitle!.isNotEmpty)
              Text(subtitle!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: children,
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.line)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.check),
                  label: Text(saveLabel),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A titled white card -- one per group of fields, so a long document
/// form reads as sections instead of one endless column.
class DocFormSection extends StatelessWidget {
  final String title;
  final String? hint;
  final List<Widget> children;

  const DocFormSection({super.key, required this.title, this.hint, required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.ink, fontSize: 15),
              ),
              if (hint != null) ...[
                const SizedBox(height: 4),
                Text(hint!, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
              ],
              const SizedBox(height: 14),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// Pushes a document form and resolves to whatever the form pops with
/// (null when the user backs out) -- a drop-in replacement for the
/// showDialog<T> these forms used to return.
Future<T?> openDocFormPage<T>(BuildContext context, WidgetBuilder builder) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute<T>(fullscreenDialog: true, builder: builder),
  );
}

/// Save-time validation message. Dialogs could get away with silently
/// ignoring the Save tap; on a full page the user needs to be told which
/// field is missing.
void showFormError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: AppColors.rose),
  );
}
