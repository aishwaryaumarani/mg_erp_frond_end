import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

/// The MG Chemicals and Fertilisers logo, in one place so the app and the
/// printed documents always show the same mark.
///
/// [assetPath] is also read directly (as bytes) by the PDF builder --
/// see services/document_pdf.dart.
const String kLogoAsset = 'assets/images/mg_logo.png';

/// Company name as it appears beside/below the mark.
const String kCompanyName = 'MG Chemicals and Fertilisers';

class BrandLogo extends StatelessWidget {
  final double height;
  const BrandLogo({super.key, this.height = 44});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      kLogoAsset,
      height: height,
      fit: BoxFit.contain,
      // The wordmark is part of the image, so a failed load must not leave
      // an exception box in the middle of the dashboard.
      errorBuilder: (context, error, stack) => SizedBox(height: height),
    );
  }
}

/// Logo bytes for embedding in a PDF. Returns null if the asset can't be
/// read, so a document still prints (without the mark) rather than failing.
Future<Uint8List?> loadLogoBytes() async {
  try {
    final data = await rootBundle.load(kLogoAsset);
    return data.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
