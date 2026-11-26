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
  final String? error;

  bool get hasActiveSession =>
      playback == MediaPlayback.playing || playback == MediaPlayback.paused;
}
