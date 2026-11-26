enum WakeOnLanStatus { idle, sending, sent, failed }

class WakeOnLanExecutionState {
  const WakeOnLanExecutionState({
    this.status = WakeOnLanStatus.idle,
    this.message,
  });

  final WakeOnLanStatus status;
  final String? message;
}
