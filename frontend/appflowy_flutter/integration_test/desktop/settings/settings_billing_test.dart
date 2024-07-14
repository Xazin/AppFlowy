import 'dart:io';
import 'dart:ui';

import 'package:appflowy/generated/locale_keys.g.dart';
import 'package:appflowy/startup/entry_point.dart';
import 'package:appflowy/startup/startup.dart';
import 'package:appflowy/user/application/auth/auth_service.dart';
import 'package:appflowy_backend/protobuf/flowy-error/errors.pb.dart';
import 'package:appflowy_backend/protobuf/flowy-user/protobuf.dart';
import 'package:appflowy_result/src/result.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:fixnum/fixnum.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import '../../shared/auth_operation.dart';
import '../../shared/base.dart';
import '../../shared/expectation.dart';
import '../../shared/settings.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Settings Billing', () {
    testWidgets('Local auth cannot see plan+billing', (tester) async {
      await tester.initializeAppFlowy();
      await tester.tapSignInAsGuest();
      await tester.expectToSeeHomePageWithGetStartedPage();

      await tester.openSettings();
      await tester.pumpAndSettle();

      // We check that another settings page is present to ensure
      // it's not a fluke
      expect(
        find.text(
          LocaleKeys.settings_workspacePage_menuLabel.tr(),
          skipOffstage: false,
        ),
        findsOneWidget,
      );

      expect(
        find.text(
          LocaleKeys.settings_planPage_menuLabel.tr(),
          skipOffstage: false,
        ),
        findsNothing,
      );

      expect(
        find.text(
          LocaleKeys.settings_billingPage_menuLabel.tr(),
          skipOffstage: false,
        ),
        findsNothing,
      );
    });

    testWidgets('Cloud auth can see plan+billing', (tester) async {
      await tester._initializeAppFlowyForBilling();

      await tester.pumpAndSettle(const Duration(seconds: 10));

      await tester.expectToSeeHomePageWithGetStartedPage();
    });
  });
}

/// In the current [AppFlowyCloudMockAuthService] we don't actually Mock
/// the call to eg. `getUser`, and in a case where we aren't actually able to
/// make the call, we should mock it.
///
class _AppFlowyCloudMockAuthService implements AuthService {
  @override
  Future<FlowyResult<UserProfilePB, FlowyError>> getUser() async {
    return FlowyResult.success(
      UserProfilePB(
        id: Int64(1),
        email: 'mock@appflowy.io',
        name: 'Mock User',
        token: 'mock-token',
        authenticator: AuthenticatorPB.AppFlowyCloud,
      ),
    );
  }

  @override
  Future<FlowyResult<UserProfilePB, FlowyError>> signInWithEmailPassword({
    required String email,
    required String password,
    Map<String, String> params = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FlowyResult<void, FlowyError>> signInWithMagicLink({
    required String email,
    Map<String, String> params = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<void> signOut() {
    throw UnimplementedError();
  }

  @override
  Future<FlowyResult<UserProfilePB, FlowyError>> signUp({
    required String name,
    required String email,
    required String password,
    Map<String, String> params = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FlowyResult<UserProfilePB, FlowyError>> signUpAsGuest({
    Map<String, String> params = const {},
  }) {
    throw UnimplementedError();
  }

  @override
  Future<FlowyResult<UserProfilePB, FlowyError>> signUpWithOAuth({
    required String platform,
    Map<String, String> params = const {},
  }) {
    throw UnimplementedError();
  }
}

extension AppFlowyTestBase on WidgetTester {
  Future<FlowyTestContext> _initializeAppFlowyForBilling({
    Size windowSize = const Size(1600, 1200),
  }) async {
    if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      // Set the window size
      await binding.setSurfaceSize(windowSize);
    }

    mockHotKeyManagerHandlers();
    final applicationDataDirectory = await mockApplicationDataStorage();

    await FlowyRunner.run(
      AppFlowyApplication(),
      IntegrationMode.integrationTest,
      didInitGetItCallback: () => Future(
        () async {
          getIt.unregister<AuthService>();
          getIt.registerFactory<AuthService>(
            () => _AppFlowyCloudMockAuthService(),
          );
        },
      ),
    );

    return FlowyTestContext(
      applicationDataDirectory: applicationDataDirectory,
    );
  }
}
