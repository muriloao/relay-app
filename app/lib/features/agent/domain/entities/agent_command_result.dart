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
      transitionUnconfirmed = false,
      failure = null,
      message = null;

  const AgentCommandResult.transitionUnconfirmed({
    required this.requestId,
    required this.message,
  }) : accepted = false,
       transitionUnconfirmed = true,
       failure = null;

  const AgentCommandResult.rejected({
    required this.requestId,
    required this.failure,
    this.message,
  }) : accepted = false,
       transitionUnconfirmed = false;

  final String requestId;
  final bool accepted;
  final bool transitionUnconfirmed;
  final AgentCommandFailure? failure;
  final String? message;
}
