import 'dart:typed_data';

enum MediaStatus { ok, noMedia, unavailable, error, unknown }

enum MediaPlayback { playing, paused, noMedia, unavailable, unknown }

class MediaState {
  const MediaState({
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
    this.artworkData,
    this.error,
  });

  final MediaStatus status;
  final MediaPlayback playback;
  final String? player;
  final String? title;
  final String? artist;

  /// Master system volume from 0 to 100, independent of player volume.
  final int? volume;
  final bool? muted;
  final int positionMs;
  final int durationMs;
  final String? artworkId;
  final String? artworkMimeType;
  final Uint8List? artworkData;
  final String? error;

  MediaState copyWith({
    int? positionMs,
    int? durationMs,
    String? artworkId,
    String? artworkMimeType,
    Uint8List? artworkData,
    bool clearArtwork = false,
  }) => MediaState(
    status: status,
    playback: playback,
    player: player,
    title: title,
    artist: artist,
    volume: volume,
    muted: muted,
    positionMs: positionMs ?? this.positionMs,
    durationMs: durationMs ?? this.durationMs,
    artworkId: clearArtwork ? null : artworkId ?? this.artworkId,
    artworkMimeType: clearArtwork
        ? null
        : artworkMimeType ?? this.artworkMimeType,
    artworkData: clearArtwork ? null : artworkData ?? this.artworkData,
    error: error,
  );

  bool get hasActiveSession =>
      playback == MediaPlayback.playing || playback == MediaPlayback.paused;
}
