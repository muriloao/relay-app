enum MediaCommandUiStatus { sending, accepted, failed }

class MediaCommandUiState {
  const MediaCommandUiState(this.status, {this.message});

  final MediaCommandUiStatus status;
  final String? message;
}
