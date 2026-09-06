import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mini_erp/widgets/brand_logo.dart';

void main() {
  testWidgets('the logo asset decodes and paints in the app', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(
      home: Builder(builder: (c) {
        ctx = c;
        return const Scaffold(body: Center(child: BrandLogo(height: 46)));
      }),
    ));
    // Throws if the asset is missing from the bundle or cannot be decoded.
    await precacheImage(const AssetImage(kLogoAsset), ctx);
    await t.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    final image = t.widget<Image>(find.byType(Image));
    expect((image.image as AssetImage).assetName, 'assets/images/mg_logo.png');
  });
}
