import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../core/di/service_locator.dart';
import '../features/machines/presentation/cubit/machine_cubit.dart';
import '../features/machines/presentation/pages/machine_home_page.dart';
import '../features/pairing/domain/entities/pairing_payload.dart';
import '../features/pairing/presentation/pages/pairing_review_page.dart';
import '../features/pairing/presentation/pages/qr_scanner_page.dart';

GoRouter createAppRouter() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      name: 'machines',
      builder: (context, state) => BlocProvider(
        create: (_) => getIt<MachineCubit>()..loadProfiles(),
        child: const MachineHomePage(),
      ),
    ),
    GoRoute(
      path: '/pairing/scan',
      name: 'pairing-scan',
      builder: (context, state) => const QrScannerPage(),
    ),
    GoRoute(
      path: '/pairing/review',
      name: 'pairing-review',
      builder: (context, state) {
        final payload = state.extra;
        if (payload is! PairingPayload) {
          return const PairingReviewPageError();
        }
        return PairingReviewPage(payload: payload);
      },
    ),
  ],
);

class PairingReviewPageError extends StatelessWidget {
  const PairingReviewPageError({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Text('Dados de pareamento não foram informados.')),
  );
}
