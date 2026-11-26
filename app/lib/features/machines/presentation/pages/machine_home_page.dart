import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../../pairing/domain/entities/pairing_payload.dart';
import '../cubit/machine_cubit.dart';
import '../cubit/machine_state.dart';
import '../widgets/machine_drawer.dart';

class MachineHomePage extends StatelessWidget {
  const MachineHomePage({super.key});

  Future<void> _addMachine(BuildContext context) async {
    final raw = await context.push<String>('/pairing/scan');
    if (!context.mounted || raw == null) return;

    final PairingPayload payload;
    try {
      payload = PairingPayload.decode(raw);
    } on FormatException catch (error) {
      _showMessage(context, error.message);
      return;
    }

    final reviewedPayload = await context.push<PairingPayload>(
      '/pairing/review',
      extra: payload,
    );
    if (!context.mounted || reviewedPayload == null) return;

    final error = await context.read<MachineCubit>().addPairing(
      reviewedPayload,
    );
    if (!context.mounted || error == null) return;
    _showMessage(context, error);
  }

  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) => BlocBuilder<MachineCubit, MachineState>(
    builder: (context, state) {
      final theme = Theme.of(context);
      return Scaffold(
        drawer: MachineDrawer(
          state: state,
          onMachineSelected: (profileId) =>
              context.read<MachineCubit>().selectMachine(profileId),
          onAddMachine: () => _addMachine(context),
        ),
        appBar: AppBar(
          leading: Builder(
            builder: (context) => IconButton(
              tooltip: 'Abrir menu de máquinas',
              onPressed: Scaffold.of(context).openDrawer,
              icon: const Icon(Icons.menu),
            ),
          ),
          title: const Text('Relay'),
          actions: [
            if (state.selectedProfile case final profile?)
              Padding(
                padding: const EdgeInsets.only(right: 20),
                child: Center(
                  child: Text(
                    '${profile.host}:${profile.port}',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 880),
              child: _buildBody(context, state),
            ),
          ),
        ),
      );
    },
  );

  Widget _buildBody(BuildContext context, MachineState state) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.pageError != null) {
      return _MessagePanel(
        icon: Icons.error_outline,
        title: 'Falha ao abrir o Relay',
        description: state.pageError!,
        actionLabel: 'Tentar novamente',
        onAction: () => context.read<MachineCubit>().loadProfiles(),
      );
    }
    if (state.profiles.isEmpty) {
      return _MessagePanel(
        icon: Icons.qr_code_scanner,
        title: 'Adicione seu primeiro computador',
        description:
            'Leia o QR Code exibido pelo agente no computador para parear.',
        actionLabel: 'Ler QR Code',
        onAction: () => _addMachine(context),
      );
    }

    final selected = state.selectedProfile;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      children: [
        if (selected != null) ...[
          Text(selected.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '${selected.host}:${selected.port}  ·  ${selected.mac}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 18),
          _ConnectionCard(
            connection: state.connection,
            onRetry: () => context.read<MachineCubit>().reconnectSelected(),
          ),
        ],
        const SizedBox(height: 22),
        Text(
          'Pareamento e comunicação acontecem na rede local.',
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.connection, required this.onRetry});

  final AgentConnectionSnapshot connection;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = connection.status;
    final (label, icon, color) = switch (status) {
      AgentConnectionStatus.online => (
        'Conectado e autenticado',
        Icons.check_circle_outline,
        theme.colorScheme.primary,
      ),
      AgentConnectionStatus.connecting => (
        'Conectando ao agente…',
        Icons.sync,
        theme.colorScheme.secondary,
      ),
      AgentConnectionStatus.authenticating => (
        'Autenticando…',
        Icons.lock_outline,
        theme.colorScheme.secondary,
      ),
      AgentConnectionStatus.error => (
        'Não foi possível conectar',
        Icons.error_outline,
        theme.colorScheme.error,
      ),
      AgentConnectionStatus.disconnected => (
        'Desconectado',
        Icons.cloud_off_outlined,
        theme.colorScheme.onSurfaceVariant,
      ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(label, style: theme.textTheme.titleMedium),
                ),
                if (status == AgentConnectionStatus.connecting ||
                    status == AgentConnectionStatus.authenticating)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            if (connection.machineName != null) ...[
              const SizedBox(height: 12),
              Text('Agente: ${connection.machineName}'),
            ],
            if (connection.statusMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                connection.statusMessage!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: status == AgentConnectionStatus.error
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            if (status == AgentConnectionStatus.error ||
                status == AgentConnectionStatus.disconnected) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Conectar novamente'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 44, color: theme.colorScheme.primary),
              const SizedBox(height: 20),
              Text(
                title,
                style: theme.textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                description,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.qr_code_scanner),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
