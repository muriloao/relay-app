enum CommandExecutionStatus {
  awaitingConfirmation,
  sending,
  accepted,
  transitionUnconfirmed,
  failed,
}

class CommandExecutionState {
  const CommandExecutionState({
    required this.requestId,
    required this.status,
    this.message,
  });

  final String requestId;
  final CommandExecutionStatus status;
  final String? message;
}
