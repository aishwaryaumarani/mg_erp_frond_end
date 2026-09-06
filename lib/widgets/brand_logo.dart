import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

import '../services/api_service.dart';

/// The company logo, shown in the sidebar, on the dashboard and at the top
/// of every printed document.
///
/// It is fetched from the company's settings so it can be changed from the
/// Settings screen without rebuilding the app. The bundled image is the
/// fallback for a company that has not uploaded one, and for the moment
/// before the fetch returns -- so a screen never flashes empty.
const String kLogoAsset = 'assets/images/mg_logo.png';

/// Fallback name, used only until the company profile loads.
const String kCompanyName = 'MG Chemicals and Fertilisers';

class BrandLogo extends StatefulWidget {
  final double height;
  const BrandLogo({super.key, this.height = 44});

  /// Session-wide cache of the uploaded logo: fetched once, reused by every
  /// screen and by the PDF builder.
  static Uint8List? _cached;
  static bool _fetched = false;

  /// Called after the logo is changed or removed so the next read refetches.
  static void invalidate() {
    _cached = null;
    _fetched = false;
  }

  /// Logo bytes for embedding in a PDF: the uploaded one if there is one,
  /// otherwise the bundled asset. Null only if neither can be read, in
  /// which case documents print without a mark rather than failing.
  static Future<Uint8List?> bytes() async {
    if (!_fetched) {
      _fetched = true;
      try {
        _cached = await ApiService.instance.getBytes('/api/settings/company/logo');
      } catch (_) {
        _cached = null; // no logo uploaded, or offline
      }
    }
    if (_cached != null) return _cached;
    try {
      final data = await rootBundle.load(kLogoAsset);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  @override
  State<BrandLogo> createState() => _BrandLogoState();
}

class _BrandLogoState extends State<BrandLogo> {
  Uint8List? _logo;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bytes = await BrandLogo.bytes();
    if (mounted) setState(() => _logo = bytes);
  }

  @override
  Widget build(BuildContext context) {
    if (_logo != null) {
      return Image.memory(
        _logo!,
        height: widget.height,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stack) => SizedBox(height: widget.height),
      );
    }
    return Image.asset(
      kLogoAsset,
      height: widget.height,
      fit: BoxFit.contain,
      // A failed load must not leave an exception box mid-screen.
      errorBuilder: (context, error, stack) => SizedBox(height: widget.height),
    );
  }
}

/// Kept for the PDF builder, which wants bytes rather than a widget.
Future<Uint8List?> loadLogoBytes() => BrandLogo.bytes();
