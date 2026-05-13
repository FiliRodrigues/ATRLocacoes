enum PendingActionStatus {
  pendingConfirmation,
  confirmed,
  executed,
  failed,
  cancelled,
}

class PendingAction {
  final String actionId;
  final String toolName;
  final String preview;
  final PendingActionStatus status;
  final bool hasDuplicates;

  const PendingAction({
    required this.actionId,
    required this.toolName,
    required this.preview,
    this.status = PendingActionStatus.pendingConfirmation,
    this.hasDuplicates = false,
  });

  bool get isDuplicate =>
      hasDuplicates ||
      preview.contains('DUPLICATA') ||
      preview.contains('duplicidade') ||
      preview.contains('similar(es)');

  PendingAction copyWith({
    String? actionId,
    String? toolName,
    String? preview,
    PendingActionStatus? status,
    bool? hasDuplicates,
  }) =>
      PendingAction(
        actionId: actionId ?? this.actionId,
        toolName: toolName ?? this.toolName,
        preview: preview ?? this.preview,
        status: status ?? this.status,
        hasDuplicates: hasDuplicates ?? this.hasDuplicates,
      );

  factory PendingAction.fromJson(Map<String, dynamic> json) => PendingAction(
    actionId: json['action_id'] as String,
    toolName: json['tool_name'] as String,
    preview: json['preview'] as String,
    hasDuplicates: json['has_duplicates'] as bool? ?? false,
  );

  Map<String, dynamic> toJson() => {
    'action_id': actionId,
    'tool_name': toolName,
    'preview': preview,
  };
}
