enum AgentCommandFailure {
  confirmationRequired,
  connectionRequired,
  capabilityUnavailable,
  invalidCommand,
  timeout,
  transport,
  agentRejected,
}

class AgentCommandResult {
  const AgentCommandResult.accepted({required this.requestId})
    : accepted = true,
      failure = null,
      message = null;

  const AgentCommandResult.rejected({
    required this.requestId,
    required this.failure,
    this.message,
  }) : accepted = false;

  final String requestId;
  final bool accepted;
  final AgentCommandFailure? failure;
  final String? message;
}
