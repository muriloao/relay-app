import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../domain/entities/machine_profile.dart';
import '../cubit/machine_state.dart';

class MachineDrawer extends StatelessWidget {
  const MachineDrawer({
    required this.state,
    required this.onMachineSelected,
    required this.onAddMachine,
    super.key,
  });

  final MachineState state;
  final ValueChanged<String> onMachineSelected;
  final VoidCallback onAddMachine;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = math.min(MediaQuery.sizeOf(context).width * .94, 430.0);

    return Drawer(
      width: width,
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.link, color: theme.colorScheme.primary, size: 27),
                  const SizedBox(width: 12),
                  Text(
                    'Relay.',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: 'Fechar menu',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 48),
              Text(
                'Suas máquinas',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Na sua rede, ao seu alcance.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 28),
              const Divider(height: 1),
              const SizedBox(height: 24),
              Expanded(
                child: state.profiles.isEmpty
                    ? Center(
                        child: Text(
                          'Nenhuma máquina cadastrada.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: state.profiles.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final profile = state.profiles[index];
                          final selected =
                              profile.id == state.selectedMachineId;
                          return _MachineDrawerItem(
                            profile: profile,
                            selected: selected,
                            connection: selected ? state.connection : null,
                            onTap: () {
                              Navigator.of(context).pop();
                              onMachineSelected(profile.id);
                            },
                          );
                        },
                      ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onAddMachine();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Adicionar máquina'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Center(
                child: Text(
                  'Conexões apenas na rede local',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MachineDrawerItem extends StatelessWidget {
  const _MachineDrawerItem({
    required this.profile,
    required this.selected,
    required this.connection,
    required this.onTap,
  });

  final MachineProfile profile;
  final bool selected;
  final AgentConnectionSnapshot? connection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = _statusPresentation(theme, connection);

    return Material(
      color: selected ? theme.colorScheme.surface : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(
          color: selected ? theme.colorScheme.outline : Colors.transparent,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          child: Row(
            children: [
              const Icon(Icons.desktop_windows_outlined, size: 23),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 5),
                    Text(
                      profile.host,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontFamily: 'monospace',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _ConnectionBadge(label: status.label, color: status.color),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check, color: theme.colorScheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }

  ({String label, Color color}) _statusPresentation(
    ThemeData theme,
    AgentConnectionSnapshot? connection,
  ) {
    if (connection == null) {
      return (
        label: 'Toque para conectar',
        color: theme.colorScheme.onSurfaceVariant,
      );
    }

    return switch (connection.status) {
      AgentConnectionStatus.online => (
        label: 'Online',
        color: theme.colorScheme.primary,
      ),
      AgentConnectionStatus.connecting => (
        label: 'Conectando',
        color: theme.colorScheme.secondary,
      ),
      AgentConnectionStatus.authenticating => (
        label: 'Autenticando',
        color: theme.colorScheme.secondary,
      ),
      AgentConnectionStatus.error => (
        label: 'Falha na conexão',
        color: theme.colorScheme.error,
      ),
      AgentConnectionStatus.disconnected => (
        label: 'Desconectado',
        color: theme.colorScheme.onSurfaceVariant,
      ),
    };
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      border: Border.all(color: color.withValues(alpha: .18)),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color),
        ),
      ],
    ),
  );
}
