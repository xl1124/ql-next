import "package:flutter_test/flutter_test.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:shared_preferences/shared_preferences.dart";

import "package:qinglong_flutter/app.dart";

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});
  });

  testWidgets("shows the login screen when no token is stored", (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const QingLongApp());
    await tester.pumpAndSettle();

    expect(find.text("QL-Next"), findsOneWidget);
    expect(find.text("青龙面板管理工具"), findsOneWidget);
    expect(find.text("服务器地址"), findsOneWidget);
  });
}
