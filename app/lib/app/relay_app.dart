import 'package:material_ui/material_ui.dart';
import 'package:go_router/go_router.dart';

import '../core/di/service_locator.dart';
import 'theme/relay_theme.dart';

class RelayApp extends StatelessWidget {
  const RelayApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
    title: 'Relay',
    debugShowCheckedModeBanner: false,
    theme: relayDarkTheme,
    routerConfig: getIt<GoRouter>(),
  );
}
