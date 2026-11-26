import '../../../media/domain/entities/media_state.dart';

class AgentMediaStateModel {
  const AgentMediaStateModel({
    required this.status,
    required this.playback,
    this.player,
    this.title,
    this.artist,
    this.volume,
    this.muted,
    this.error,
  });

  final MediaStatus status;
  final MediaPlayback playback;
  final String? player;
  final String? title;
  final String? artist;
  final int? volume;
  final bool? muted;
  final String? error;

  factory AgentMediaStateModel.fromJson(
    Map<String, dynamic>? payload, {
    Object? envelopeStatus,
  }) {
    if (payload == null) {
      return const AgentMediaStateModel(
        status: MediaStatus.unknown,
        playback: MediaPlayback.unknown,
        error: 'Payload de mídia inválido recebido do agente.',
      );
    }

    final payloadStatus = payload['status'];
    final status = _mediaStatus(
      payloadStatus is String
          ? payloadStatus
          : envelopeStatus is String
          ? envelopeStatus
          : null,
    );
    final rawPlayback = payload['playback'];
    final playback = _mediaPlayback(rawPlayback is String ? rawPlayback : null);
    final rawVolume = payload['volume'];
    final volume =
        rawVolume is num &&
            rawVolume.isFinite &&
            rawVolume >= 0 &&
            rawVolume <= 100
        ? rawVolume.round()
        : null;
    final rawMuted = payload['muted'];

    return AgentMediaStateModel(
      status: status,
      playback: playback,
      player: _optionalString(payload['player']),
      title: _optionalString(payload['title']),
      artist: _optionalString(payload['artist']),
      volume: volume,
      muted: rawMuted is bool ? rawMuted : null,
      error: _optionalString(payload['error']),
    );
  }

  MediaState toEntity() => MediaState(
    status: status,
    playback: playback,
    player: player,
    title: title,
    artist: artist,
    volume: volume,
    muted: muted,
    error: error,
  );

  static MediaStatus _mediaStatus(String? value) => switch (value) {
    'ok' => MediaStatus.ok,
    'no_media' => MediaStatus.noMedia,
    'unavailable' => MediaStatus.unavailable,
    'error' => MediaStatus.error,
    _ => MediaStatus.unknown,
  };

  static MediaPlayback _mediaPlayback(String? value) => switch (value) {
    'playing' => MediaPlayback.playing,
    'paused' => MediaPlayback.paused,
    'no_media' => MediaPlayback.noMedia,
    'unavailable' => MediaPlayback.unavailable,
    _ => MediaPlayback.unknown,
  };

  static String? _optionalString(Object? value) {
    if (value is! String) return null;
    final normalized = value.trim();
    return normalized.isEmpty ? null : normalized;
  }
}
