import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';

import '../services/document_pdf.dart';
import '../theme/app_theme.dart';

/// Shows the document PDF *inside* the app.
///
/// Calling Printing.layoutPdf straight from a button fails silently in
/// two common setups: on web it opens a new browser tab, which a popup
/// blocker swallows without a word, and PdfPreview's own print button
/// only reports failures to the console. So the pages are rendered here,
/// and Print/Download are our own buttons that surface what went wrong.
class PdfPreviewPage extends StatelessWidget {
  final DocumentView doc;
  const PdfPreviewPage({super.key, required this.doc});

  static Future<void> open(BuildContext context, DocumentView doc) {
    return Navigator.of(context).push(
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => PdfPreviewPage(doc: doc)),
    );
  }

  String get _fileName =>
      '${doc.docType}-${doc.docNo}'.replaceAll(RegExp(r'[^A-Za-z0-9\-_]'), '-');

  /// The printing plugin registers itself when the app starts. Adding the
  /// package to a session that is already running leaves the channel
  /// unimplemented until that session is fully restarted -- hot restart
  /// is not enough -- so say so instead of showing a raw exception.
  String _message(Object error) {
    if (error is MissingPluginException) {
      return 'Printing is not available in this session. Fully stop the app '
          '(q in the flutter terminal) and run it again -- a hot restart will not do it.';
    }
    return '$error';
  }

  // The messenger is captured before the await, so reporting a failure
  // never reaches back through a BuildContext across an async gap.
  void _report(ScaffoldMessengerState messenger, Object error) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(_message(error)),
        backgroundColor: AppColors.rose,
        duration: const Duration(seconds: 8),
      ),
    );
  }

  Future<void> _print(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await Printing.layoutPdf(onLayout: (_) => buildDocumentPdf(doc), name: _fileName);
    } catch (e) {
      _report(messenger, e);
    }
  }

  Future<void> _share(BuildContext context) => downloadDocumentPdf(context, doc);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.page,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(doc.docNo, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text('${doc.docType} · PDF',
                style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined),
            tooltip: kIsWeb ? 'Download' : 'Save / share',
            onPressed: () => _share(context),
          ),
          IconButton(
            icon: const Icon(Icons.print_outlined),
            tooltip: 'Print',
            onPressed: () => _print(context),
          ),
          const SizedBox(width: 8),
        ],
        shape: const Border(bottom: BorderSide(color: AppColors.line)),
      ),
      // Our own actions above replace PdfPreview's, whose failures go to
      // the console only.
      body: PdfPreview(
        build: (format) => buildDocumentPdf(doc),
        pdfFileName: '$_fileName.pdf',
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        allowPrinting: false,
        allowSharing: false,
        onError: (context, error) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: AppColors.rose, size: 32),
              const SizedBox(height: 12),
              const Text('Could not render this PDF',
                  style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.ink)),
              const SizedBox(height: 8),
              Text(_message(error),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hands the viewer the PDF as a file: a browser download on web, the
/// save/share sheet elsewhere. Any failure is shown on screen rather than
/// left in the console, which is how the earlier silent failures hid.
Future<void> downloadDocumentPdf(BuildContext context, DocumentView doc) async {
  final messenger = ScaffoldMessenger.of(context);
  final fileName =
      '${doc.docType}-${doc.docNo}'.replaceAll(RegExp(r'[^A-Za-z0-9\-_]'), '-');
  try {
    await Printing.sharePdf(bytes: await buildDocumentPdf(doc), filename: '$fileName.pdf');
  } catch (e) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(e is MissingPluginException
            ? 'Downloading is not available in this session. Fully stop the app '
                '(q in the flutter terminal) and run it again -- a hot restart will not do it.'
            : '$e'),
        backgroundColor: AppColors.rose,
        duration: const Duration(seconds: 8),
      ),
    );
  }
}
