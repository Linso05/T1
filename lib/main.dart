import 'package:flutter/cupertino.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'platform/aliyun_update.dart';
import 'state/app_services.dart';
import 'ui/gate/permission_page.dart';
import 'ui/gate/privacy_page.dart';
import 'ui/shell/app_shell.dart';
import 'ui/splash/splash_page.dart';
import 'ui/theme.dart';

final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  AliyunUpdate.init(rootNavigatorKey);
  runApp(
    ProviderScope(
      overrides: [appServicesProvider.overrideWithValue(services)],
      child: const T1App(),
    ),
  );
}

class T1App extends StatelessWidget {
  const T1App({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      title: 'T1',
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      theme: buildT1CupertinoTheme(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(
        child: PrivacyGate(
          child: PermissionGate(child: AppShell()),
        ),
      ),
    );
  }
}
