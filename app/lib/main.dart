import 'package:material_ui/material_ui.dart';

import 'app/relay_app.dart';
import 'core/di/injection.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await configureDependencies();
  runApp(const RelayApp());
}
