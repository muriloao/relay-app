import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../agent/domain/entities/agent_command.dart';
import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../../metrics/presentation/widgets/performance_overview.dart';
import '../../../pairing/domain/entities/pairing_payload.dart';
import '../cubit/command_execution_state.dart';
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
          const SizedBox(height: 28),
          PerformanceOverview(
            connection: state.connection,
            history: state.performanceHistory,
            isHistoryLoading: state.isHistoryLoading,
            historyError: state.historyError,
          ),
          const SizedBox(height: 28),
          _EnergyControlsSection(
            connection: state.connection,
            execution: state.commandExecutions['power:lock'],
            onLock: () => context.read<MachineCubit>().executeCommand(
              AgentCommand.create(type: AgentCommandType.power, action: 'lock'),
            ),
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

class _EnergyControlsSection extends StatelessWidget {
  const _EnergyControlsSection({
    required this.connection,
    required this.execution,
    required this.onLock,
  });

  final AgentConnectionSnapshot connection;
  final CommandExecutionState? execution;
  final VoidCallback onLock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = connection.status == AgentConnectionStatus.online;
    final supported = connection.capabilities.contains('power');
    final sending = execution?.status == CommandExecutionStatus.sending;
    final canLock = online && supported && !sending;

    final statusText = switch (execution?.status) {
      CommandExecutionStatus.sending => 'Enviando solicitação…',
      CommandExecutionStatus.accepted =>
        'O agente aceitou o pedido de bloqueio.',
      CommandExecutionStatus.failed => execution?.message,
      CommandExecutionStatus.awaitingConfirmation =>
        'Este comando requer confirmação.',
      null => null,
    };

    final availabilityText = !online
        ? 'Conecte-se à máquina para bloquear a tela.'
        : !supported
        ? 'O agente conectado não oferece comandos de energia.'
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Controle de energia',
                style: theme.textTheme.titleMedium,
              ),
            ),
            Text(
              'Ações no computador',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;
            final columns = compact ? 2 : 5;
            final spacing = compact ? 10.0 : 14.0;
            final tileWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;
            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                _EnergyActionTile(
                  width: tileWidth,
                  height: compact ? 96 : 115,
                  enabled: canLock,
                  busy: sending,
                  icon: Icons.lock_outline,
                  label: sending ? 'Enviando…' : 'Bloquear',
                  onPressed: onLock,
                ),
              ],
            );
          },
        ),
        if (statusText != null || availabilityText != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (sending)
                Padding(
                  padding: const EdgeInsets.only(top: 2, right: 8),
                  child: SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              else if (execution?.status == CommandExecutionStatus.accepted)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.verified_outlined,
                    size: 15,
                    color: theme.colorScheme.primary,
                  ),
                )
              else if (execution?.status == CommandExecutionStatus.failed)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.error_outline,
                    size: 15,
                    color: theme.colorScheme.error,
                  ),
                ),
              Expanded(
                child: Text(
                  statusText ?? availabilityText!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: execution?.status == CommandExecutionStatus.failed
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _EnergyActionTile extends StatelessWidget {
  const _EnergyActionTile({
    required this.width,
    required this.height,
    required this.enabled,
    required this.busy,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final double width;
  final double height;
  final bool enabled;
  final bool busy;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const tileForeground = Color(0xFFE6E6E7);
    const iconForeground = Color(0xFF858990);

    return SizedBox(
      width: width,
      height: height,
      child: Material(
        color: const Color(0xFF151515),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: const BorderSide(color: Color(0xFF2D2D2F)),
        ),
        clipBehavior: Clip.antiAlias,
        child: Opacity(
          opacity: enabled ? 1 : .55,
          child: InkWell(
            onTap: enabled && !busy ? onPressed : null,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (busy)
                  const SizedBox(
                    width: 23,
                    height: 23,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.6,
                      color: iconForeground,
                    ),
                  )
                else
                  Icon(icon, size: 24, color: iconForeground),
                const SizedBox(height: 14),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: tileForeground,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
