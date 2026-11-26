import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../agent/domain/entities/agent_command.dart';
import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../../metrics/presentation/widgets/performance_overview.dart';
import '../../../media/presentation/pages/media_tab_page.dart';
import '../../../media/presentation/media_command_ui_state.dart';
import '../../../metrics/domain/entities/performance_sample.dart';
import '../../../pairing/domain/entities/pairing_payload.dart';
import '../../domain/entities/machine_profile.dart';
import '../cubit/command_execution_state.dart';
import '../cubit/machine_cubit.dart';
import '../cubit/machine_state.dart';
import '../cubit/wake_on_lan_execution_state.dart';
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

  Future<void> _requestPowerAction(BuildContext context, String action) async {
    final command = AgentCommand.create(
      type: AgentCommandType.power,
      action: action,
    );
    if (command.requiresConfirmation) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.warning_amber_outlined),
          title: Text(
            action == 'shutdown'
                ? 'Desligar computador?'
                : 'Reiniciar computador?',
          ),
          content: Text(
            action == 'shutdown'
                ? 'O computador será desligado e ficará offline. Salve o que estiver fazendo antes de continuar.'
                : 'O computador será reiniciado e ficará temporariamente offline. Salve o que estiver fazendo antes de continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text(action == 'shutdown' ? 'Desligar' : 'Reiniciar'),
            ),
          ],
        ),
      );
      if (!context.mounted || confirmed != true) return;
    }
    if (!context.mounted) return;
    await context.read<MachineCubit>().executeCommand(
      command,
      confirmed: command.requiresConfirmation,
    );
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
              constraints: const BoxConstraints(maxWidth: 1240),
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
    if (selected == null) {
      return const Center(child: Text('Selecione uma máquina.'));
    }
    return _MachineWorkspace(
      profile: selected,
      connection: state.connection,
      performanceHistory: state.performanceHistory,
      isHistoryLoading: state.isHistoryLoading,
      historyError: state.historyError,
      commandExecutions: state.commandExecutions,
      wakeOnLan: state.wakeOnLan,
      onRetry: () => context.read<MachineCubit>().reconnectSelected(),
      onWake: () => context.read<MachineCubit>().wakeSelectedMachine(),
      onPowerAction: (action) =>
          unawaited(_requestPowerAction(context, action)),
      onMediaCommand: (action, value) {
        final command = AgentCommand.create(
          type: AgentCommandType.media,
          action: action,
          value: value,
        );
        unawaited(context.read<MachineCubit>().executeCommand(command));
      },
    );
  }
}

class _MachineWorkspace extends StatefulWidget {
  const _MachineWorkspace({
    required this.profile,
    required this.connection,
    required this.performanceHistory,
    required this.isHistoryLoading,
    required this.historyError,
    required this.commandExecutions,
    required this.wakeOnLan,
    required this.onRetry,
    required this.onWake,
    required this.onPowerAction,
    required this.onMediaCommand,
  });

  final MachineProfile profile;
  final AgentConnectionSnapshot connection;
  final List<PerformanceSample> performanceHistory;
  final bool isHistoryLoading;
  final String? historyError;
  final Map<String, CommandExecutionState> commandExecutions;
  final WakeOnLanExecutionState wakeOnLan;
  final VoidCallback onRetry;
  final VoidCallback onWake;
  final ValueChanged<String> onPowerAction;
  final void Function(String action, double? value) onMediaCommand;

  @override
  State<_MachineWorkspace> createState() => _MachineWorkspaceState();
}

class _MachineWorkspaceState extends State<_MachineWorkspace> {
  final PageController _pageController = PageController();
  int _selectedPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _selectPage(int page) {
    setState(() => _selectedPage = page);
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = widget.connection.status == AgentConnectionStatus.online;

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.profile.host}:${widget.profile.port}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              _MachineStatusBadge(connection: widget.connection),
              if (!online) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Conectar novamente',
                  onPressed: widget.onRetry,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          _MachineTabs(selectedPage: _selectedPage, onSelected: _selectPage),
          const SizedBox(height: 8),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const PageScrollPhysics(),
              onPageChanged: (page) => setState(() => _selectedPage = page),
              children: [
                _OverviewTab(
                  connection: widget.connection,
                  profile: widget.profile,
                  performanceHistory: widget.performanceHistory,
                  isHistoryLoading: widget.isHistoryLoading,
                  historyError: widget.historyError,
                  commandExecutions: widget.commandExecutions,
                  wakeOnLan: widget.wakeOnLan,
                  onRetry: widget.onRetry,
                  onWake: widget.onWake,
                  onPowerAction: widget.onPowerAction,
                ),
                MediaTabPage(
                  machineId: widget.profile.id,
                  connection: widget.connection,
                  mediaState: widget.connection.latestMediaState,
                  executions: _mediaExecutions(widget.commandExecutions),
                  onCommand: widget.onMediaCommand,
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          _PageIndicator(selectedPage: _selectedPage, onSelected: _selectPage),
        ],
      ),
    );
  }
}

Map<String, MediaCommandUiState> _mediaExecutions(
  Map<String, CommandExecutionState> executions,
) {
  const actions = [
    'play_pause',
    'previous',
    'next',
    'set_volume',
    'toggle_mute',
  ];
  final mapped = <String, MediaCommandUiState>{};
  for (final action in actions) {
    final execution = executions['media:$action'];
    if (execution == null) continue;
    final status = switch (execution.status) {
      CommandExecutionStatus.sending => MediaCommandUiStatus.sending,
      CommandExecutionStatus.accepted => MediaCommandUiStatus.accepted,
      CommandExecutionStatus.failed => MediaCommandUiStatus.failed,
      _ => null,
    };
    if (status != null) {
      mapped[action] = MediaCommandUiState(status, message: execution.message);
    }
  }
  return mapped;
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab({
    required this.connection,
    required this.profile,
    required this.performanceHistory,
    required this.isHistoryLoading,
    required this.historyError,
    required this.commandExecutions,
    required this.wakeOnLan,
    required this.onRetry,
    required this.onWake,
    required this.onPowerAction,
  });

  final AgentConnectionSnapshot connection;
  final MachineProfile profile;
  final List<PerformanceSample> performanceHistory;
  final bool isHistoryLoading;
  final String? historyError;
  final Map<String, CommandExecutionState> commandExecutions;
  final WakeOnLanExecutionState wakeOnLan;
  final VoidCallback onRetry;
  final VoidCallback onWake;
  final ValueChanged<String> onPowerAction;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(0, 18, 0, 22),
    children: [
      if (connection.status != AgentConnectionStatus.online) ...[
        _ConnectionCard(connection: connection, onRetry: onRetry),
        const SizedBox(height: 22),
      ],
      PerformanceOverview(
        connection: connection,
        history: performanceHistory,
        isHistoryLoading: isHistoryLoading,
        historyError: historyError,
      ),
      const SizedBox(height: 28),
      _EnergyControlsSection(
        connection: connection,
        profile: profile,
        executions: commandExecutions,
        wakeOnLan: wakeOnLan,
        onWake: onWake,
        onPowerAction: onPowerAction,
      ),
      const SizedBox(height: 20),
      Text(
        'Pareamento e comunicação acontecem na rede local.',
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
    ],
  );
}

class _MachineStatusBadge extends StatelessWidget {
  const _MachineStatusBadge({required this.connection});

  final AgentConnectionSnapshot connection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = connection.status == AgentConnectionStatus.online;
    final connecting =
        connection.status == AgentConnectionStatus.connecting ||
        connection.status == AgentConnectionStatus.authenticating;
    final label = online
        ? 'Online'
        : connecting
        ? 'Conectando'
        : 'Offline';
    final color = online
        ? theme.colorScheme.primary
        : connection.status == AgentConnectionStatus.error
        ? theme.colorScheme.error
        : theme.colorScheme.onSurfaceVariant;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .1),
        border: Border.all(color: color.withValues(alpha: .25)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (connecting) ...[
            SizedBox(
              width: 10,
              height: 10,
              child: CircularProgressIndicator(strokeWidth: 1.5, color: color),
            ),
            const SizedBox(width: 7),
          ] else ...[
            Icon(Icons.circle, size: 7, color: color),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}

class _MachineTabs extends StatelessWidget {
  const _MachineTabs({required this.selectedPage, required this.onSelected});

  final int selectedPage;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final theme = Theme.of(context);
      const items = [
        (Icons.tune_rounded, 'Visão geral', '01'),
        (Icons.headphones_rounded, 'Mídia', '02'),
      ];

      return Row(
        children: [
          for (var index = 0; index < items.length; index++)
            _MachineTab(
              icon: items[index].$1,
              label: items[index].$2,
              number: items[index].$3,
              selected: selectedPage == index,
              onPressed: () => onSelected(index),
            ),
          if (constraints.maxWidth >= 520) ...[
            const Spacer(),
            Text(
              'Deslize para trocar de aba',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _MachineTab extends StatelessWidget {
  const _MachineTab({
    required this.icon,
    required this.label,
    required this.number,
    required this.selected,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final String number;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected
        ? theme.colorScheme.onSurface
        : theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.only(right: 22),
      child: InkWell(
        onTap: onPressed,
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? theme.colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
              const SizedBox(width: 12),
              Text(
                number,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageIndicator extends StatelessWidget {
  const _PageIndicator({required this.selectedPage, required this.onSelected});

  final int selectedPage;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: 'Visão geral',
          onPressed: selectedPage == 0 ? null : () => onSelected(0),
          icon: const Icon(Icons.chevron_left),
          visualDensity: VisualDensity.compact,
        ),
        for (var index = 0; index < 2; index++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: selectedPage == index ? 18 : 7,
              height: 7,
              decoration: BoxDecoration(
                color: selectedPage == index
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Mídia',
          onPressed: selectedPage == 1 ? null : () => onSelected(1),
          icon: const Icon(Icons.chevron_right),
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }
}

class _EnergyControlsSection extends StatelessWidget {
  const _EnergyControlsSection({
    required this.connection,
    required this.profile,
    required this.executions,
    required this.wakeOnLan,
    required this.onWake,
    required this.onPowerAction,
  });

  final AgentConnectionSnapshot connection;
  final MachineProfile? profile;
  final Map<String, CommandExecutionState> executions;
  final WakeOnLanExecutionState wakeOnLan;
  final VoidCallback onWake;
  final ValueChanged<String> onPowerAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final online = connection.status == AgentConnectionStatus.online;

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
              children: _powerActions
                  .map((action) {
                    final execution = executions['power:${action.id}'];
                    final supported = connection.supportsPowerAction(action.id);
                    final wake = action.id == 'wake';
                    final wakeSupported =
                        RegExp(r'^(?:[0-9a-fA-F]{2}:){5}[0-9a-fA-F]{2}$')
                            .hasMatch(profile?.mac ?? '') &&
                        !kIsWeb;
                    final sending = wake
                        ? wakeOnLan.status == WakeOnLanStatus.sending
                        : execution?.status == CommandExecutionStatus.sending;
                    return _EnergyActionItem(
                      width: tileWidth,
                      height: compact ? 96 : 115,
                      action: action,
                      online: online,
                      supported: wake ? wakeSupported : supported,
                      enabled: wake
                          ? !online && wakeSupported
                          : online && supported,
                      busy: sending,
                      execution: execution,
                      wakeOnLan: wake ? wakeOnLan : null,
                      onPressed: wake ? onWake : () => onPowerAction(action.id),
                    );
                  })
                  .toList(growable: false),
            );
          },
        ),
        if (!online) ...[
          const SizedBox(height: 12),
          Text(
            'As demais ações de energia exigem conexão com a máquina.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

class _EnergyActionItem extends StatelessWidget {
  const _EnergyActionItem({
    required this.width,
    required this.height,
    required this.action,
    required this.online,
    required this.supported,
    required this.enabled,
    required this.busy,
    required this.execution,
    this.wakeOnLan,
    required this.onPressed,
  });

  final double width;
  final double height;
  final _PowerAction action;
  final bool online;
  final bool supported;
  final bool enabled;
  final bool busy;
  final CommandExecutionState? execution;
  final WakeOnLanExecutionState? wakeOnLan;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = wakeOnLan == null
        ? switch (execution?.status) {
            CommandExecutionStatus.accepted => 'Aceito pelo agente.',
            CommandExecutionStatus.transitionUnconfirmed =>
              'Transição não confirmada. Verifique a máquina.',
            CommandExecutionStatus.failed => execution?.message,
            _ => null,
          }
        : switch (wakeOnLan!.status) {
            WakeOnLanStatus.sent => wakeOnLan!.message,
            WakeOnLanStatus.failed => wakeOnLan!.message,
            _ => null,
          };
    final statusColor =
        execution?.status == CommandExecutionStatus.failed ||
            wakeOnLan?.status == WakeOnLanStatus.failed
        ? theme.colorScheme.error
        : execution?.status == CommandExecutionStatus.transitionUnconfirmed
        ? theme.colorScheme.secondary
        : theme.colorScheme.onSurfaceVariant;

    return SizedBox(
      width: width,
      child: Column(
        children: [
          _EnergyActionTile(
            width: width,
            height: height,
            enabled: enabled,
            busy: busy,
            icon: action.icon,
            label: busy ? 'Enviando…' : action.label,
            subtitle: action.subtitle,
            onPressed: onPressed,
          ),
          if (status != null) ...[
            const SizedBox(height: 8),
            Text(
              status,
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(color: statusColor),
            ),
          ] else if ((action.id == 'wake' && !supported) ||
              (online && !supported)) ...[
            const SizedBox(height: 8),
            Text(
              action.id == 'wake'
                  ? kIsWeb
                        ? 'Wake-on-LAN está disponível apenas no app instalado'
                        : 'Endereço MAC inválido no cadastro'
                  : 'Indisponível neste agente',
              textAlign: TextAlign.center,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PowerAction {
  const _PowerAction(this.id, this.label, this.icon, {this.subtitle});

  final String id;
  final String label;
  final IconData icon;
  final String? subtitle;
}

const _powerActions = [
  _PowerAction(
    'wake',
    'Ligar',
    Icons.power_settings_new_outlined,
    subtitle: 'Wake-on-LAN',
  ),
  _PowerAction('shutdown', 'Desligar', Icons.power_settings_new_outlined),
  _PowerAction('lock', 'Bloquear', Icons.lock_outline),
  _PowerAction('restart', 'Reiniciar', Icons.restart_alt),
];

class _EnergyActionTile extends StatelessWidget {
  const _EnergyActionTile({
    required this.width,
    required this.height,
    required this.enabled,
    required this.busy,
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onPressed,
  });

  final double width;
  final double height;
  final bool enabled;
  final bool busy;
  final IconData icon;
  final String label;
  final String? subtitle;
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
                if (subtitle case final subtitle?) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
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
