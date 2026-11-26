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
    this.positionMs = 0,
    this.durationMs = 0,
    this.artworkId,
    this.artworkMimeType,
    this.error,
  });

  final MediaStatus status;
  final MediaPlayback playback;
  final String? player;
  final String? title;
  final String? artist;
  final int? volume;
  final bool? muted;
  final int positionMs;
  final int durationMs;
  final String? artworkId;
  final String? artworkMimeType;
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
    final position = _nonNegativeInt(payload['position_ms']);
    final duration = _nonNegativeInt(payload['duration_ms']);

    return AgentMediaStateModel(
      status: status,
      playback: playback,
      player: _optionalString(payload['player']),
      title: _optionalString(payload['title']),
      artist: _optionalString(payload['artist']),
      volume: volume,
      muted: rawMuted is bool ? rawMuted : null,
      positionMs: position,
      durationMs: duration,
      artworkId: _optionalString(payload['artwork_id']),
      artworkMimeType: _optionalString(payload['artwork_mime_type']),
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
    positionMs: positionMs,
    durationMs: durationMs,
    artworkId: artworkId,
    artworkMimeType: artworkMimeType,
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

  static int _nonNegativeInt(Object? value) =>
      value is num && value.isFinite && value >= 0 ? value.round() : 0;
}
