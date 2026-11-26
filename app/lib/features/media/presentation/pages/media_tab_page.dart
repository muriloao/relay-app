import 'package:material_ui/material_ui.dart';

import '../../../agent/domain/entities/agent_connection_snapshot.dart';
import '../../domain/entities/media_state.dart';
import '../media_command_ui_state.dart';

class MediaTabPage extends StatefulWidget {
  const MediaTabPage({
    required this.machineId,
    required this.connection,
    required this.mediaState,
    required this.executions,
    required this.onCommand,
    super.key,
  });

  final String machineId;
  final AgentConnectionSnapshot connection;
  final MediaState? mediaState;
  final Map<String, MediaCommandUiState> executions;
  final void Function(String action, double? value) onCommand;

  @override
  State<MediaTabPage> createState() => _MediaTabPageState();
}

class _MediaTabPageState extends State<MediaTabPage> {
  double? _volumeDraft;
  double? _positionDraft;
  String? _lastCommandAction;

  @override
  void didUpdateWidget(covariant MediaTabPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.machineId != widget.machineId) {
      _volumeDraft = null;
      _positionDraft = null;
      _lastCommandAction = null;
    } else if (oldWidget.mediaState?.title != widget.mediaState?.title ||
        oldWidget.mediaState?.player != widget.mediaState?.player) {
      _positionDraft = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final media = widget.mediaState;
    final online = widget.connection.status == AgentConnectionStatus.online;
    final mediaAvailable = online && widget.connection.supportsMedia;
    final sessionAvailable =
        mediaAvailable && (media?.hasActiveSession ?? false);
    final audioAvailable =
        mediaAvailable &&
        media != null &&
        (media.status == MediaStatus.ok ||
            media.status == MediaStatus.noMedia) &&
        media.volume != null;
    final volume = _volumeDraft ?? media?.volume?.toDouble() ?? 0;
    final feedback = _commandFeedback;

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 680;
        final coverSize = wide
            ? constraints.maxHeight.clamp(220.0, 330.0).toDouble()
            : constraints.maxWidth.clamp(180.0, 260.0).toDouble();
        final cover = _AlbumArt(media: media, size: coverSize);
        final controls = _buildControls(
          context,
          media: media,
          online: online,
          sessionAvailable: sessionAvailable,
          audioAvailable: audioAvailable,
          volume: volume,
          feedback: feedback,
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 12),
          child: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    cover,
                    const SizedBox(width: 32),
                    Expanded(child: controls),
                  ],
                )
              : Column(children: [cover, const SizedBox(height: 26), controls]),
        );
      },
    );
  }

  Widget _buildControls(
    BuildContext context, {
    required MediaState? media,
    required bool online,
    required bool sessionAvailable,
    required bool audioAvailable,
    required double volume,
    required _CommandFeedback? feedback,
  }) {
    final theme = Theme.of(context);
    final isPlaying = media?.playback == MediaPlayback.playing;
    final playbackLabel = switch (media?.playback) {
      MediaPlayback.playing => 'Reproduzindo agora',
      MediaPlayback.paused => 'Pausado',
      MediaPlayback.noMedia => 'Nenhuma mídia ativa',
      MediaPlayback.unavailable => 'Mídia indisponível',
      MediaPlayback.unknown || null => 'Aguardando estado de mídia',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.music_note, size: 18, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              media?.player ?? 'Mídia do computador',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                playbackLabel,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          _trackTitle(media),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        if (media?.artist != null) ...[
          const SizedBox(height: 6),
          Text(
            media!.artist!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if ((media?.durationMs ?? 0) > 0) ...[
          const SizedBox(height: 18),
          _buildProgress(media!, sessionAvailable),
        ],
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              tooltip: 'Faixa anterior',
              onPressed: sessionAvailable && !_isSending('previous')
                  ? () => _send('previous')
                  : null,
              icon: const Icon(Icons.skip_previous_rounded, size: 30),
            ),
            const SizedBox(width: 22),
            SizedBox(
              width: 62,
              height: 62,
              child: FilledButton(
                onPressed: sessionAvailable && !_isSending('play_pause')
                    ? () => _send('play_pause')
                    : null,
                style: FilledButton.styleFrom(
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                ),
                child: _isSending('play_pause')
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        size: 32,
                      ),
              ),
            ),
            const SizedBox(width: 22),
            IconButton(
              tooltip: 'Próxima faixa',
              onPressed: sessionAvailable && !_isSending('next')
                  ? () => _send('next')
                  : null,
              icon: const Icon(Icons.skip_next_rounded, size: 30),
            ),
          ],
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            IconButton(
              tooltip: media?.muted == true ? 'Ativar som' : 'Silenciar',
              onPressed: audioAvailable && !_isSending('toggle_mute')
                  ? () => _send('toggle_mute')
                  : null,
              icon: Icon(
                media?.muted == true
                    ? Icons.volume_off_outlined
                    : Icons.volume_up_outlined,
              ),
            ),
            Expanded(
              child: Slider(
                value: volume.clamp(0, 100).toDouble(),
                min: 0,
                max: 100,
                onChanged: audioAvailable && !_isSending('set_volume')
                    ? (value) => setState(() => _volumeDraft = value)
                    : null,
                onChangeEnd: audioAvailable && !_isSending('set_volume')
                    ? (value) {
                        setState(() => _volumeDraft = null);
                        _send('set_volume', value);
                      }
                    : null,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '${volume.round()}%',
                textAlign: TextAlign.end,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        if (!online || !widget.connection.supportsMedia) ...[
          const SizedBox(height: 12),
          Text(
            online
                ? 'O agente conectado não oferece controles de mídia.'
                : 'Conecte-se ao agente para controlar a mídia.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else if (media?.status == MediaStatus.unavailable ||
            media?.status == MediaStatus.error) ...[
          const SizedBox(height: 12),
          Text(
            media?.error ?? 'O agente não conseguiu consultar a mídia.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ] else if (media?.status == MediaStatus.noMedia ||
            media?.playback == MediaPlayback.noMedia) ...[
          const SizedBox(height: 12),
          Text(
            'Os controles de faixa serão ativados quando houver uma sessão de mídia.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ] else if (media == null ||
            media.status == MediaStatus.unknown ||
            media.playback == MediaPlayback.unknown) ...[
          const SizedBox(height: 12),
          Text(
            'Aguardando uma atualização válida do estado de mídia.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        if (feedback != null) ...[
          const SizedBox(height: 10),
          Text(
            feedback.message,
            style: theme.textTheme.bodySmall?.copyWith(
              color: feedback.failed
                  ? theme.colorScheme.error
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            Icon(
              Icons.computer_outlined,
              size: 16,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                audioAvailable ? 'Áudio master do sistema' : 'Saída de áudio',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Text(
              'Mídia da máquina ativa',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _trackTitle(MediaState? media) {
    if (media?.title case final title?) return title;
    return switch (media?.playback) {
      MediaPlayback.noMedia => 'Nada está tocando',
      MediaPlayback.unavailable => 'Mídia indisponível',
      _ => 'Nenhuma faixa selecionada',
    };
  }

  Widget _buildProgress(MediaState media, bool enabled) {
    final theme = Theme.of(context);
    final duration = media.durationMs.toDouble();
    final position = (_positionDraft ?? media.positionMs.toDouble())
        .clamp(0, duration)
        .toDouble();
    return Column(
      children: [
        Slider(
          value: position,
          min: 0,
          max: duration,
          onChanged: enabled
              ? (value) => setState(() => _positionDraft = value)
              : null,
          onChangeEnd: enabled
              ? (value) {
                  setState(() => _positionDraft = null);
                  _send('seek', value);
                }
              : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatTime(position.round()),
                style: theme.textTheme.labelSmall,
              ),
              Text(
                _formatTime(media.durationMs),
                style: theme.textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatTime(int milliseconds) {
    final seconds = milliseconds ~/ 1000;
    final minutes = seconds ~/ 60;
    final remainder = seconds % 60;
    return '$minutes:${remainder.toString().padLeft(2, '0')}';
  }

  bool _isSending(String action) =>
      widget.executions[action]?.status == MediaCommandUiStatus.sending;

  _CommandFeedback? get _commandFeedback {
    final action = _lastCommandAction;
    if (action == null) return null;
    final execution = widget.executions[action];
    return switch (execution?.status) {
      MediaCommandUiStatus.sending => const _CommandFeedback(
        'Enviando comando ao agente…',
      ),
      MediaCommandUiStatus.accepted => const _CommandFeedback(
        'Comando aceito pelo agente.',
      ),
      MediaCommandUiStatus.failed => _CommandFeedback(
        execution?.message ?? 'O agente não conseguiu executar o comando.',
        failed: true,
      ),
      _ => null,
    };
  }

  void _send(String action, [double? value]) {
    setState(() => _lastCommandAction = action);
    widget.onCommand(action, value);
  }
}

class _AlbumArt extends StatelessWidget {
  const _AlbumArt({required this.media, required this.size});

  final MediaState? media;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final artwork = media?.artworkData;
    return SizedBox.square(
      dimension: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: artwork != null
            ? Image.memory(
                artwork,
                key: ValueKey(media?.artworkId),
                fit: BoxFit.cover,
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => _fallback(theme),
              )
            : _fallback(theme),
      ),
    );
  }

  Widget _fallback(ThemeData theme) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF263B34), Color(0xFF101714), Color(0xFF20242A)],
      ),
      border: Border.all(color: const Color(0xFF303638)),
    ),
    child: SizedBox.expand(
      child: Center(
        child: Icon(
          Icons.graphic_eq_rounded,
          size: size * .32,
          color: theme.colorScheme.primary.withValues(alpha: .8),
        ),
      ),
    ),
  );
}

class _CommandFeedback {
  const _CommandFeedback(this.message, {this.failed = false});

  final String message;
  final bool failed;
}
