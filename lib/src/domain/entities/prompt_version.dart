class PromptVersion {
  const PromptVersion({
    required this.id,
    required this.promptId,
    required this.versionNumber,
    required this.content,
    required this.createdAt,
    this.negativePrompt,
    this.changeNote,
  });

  final String id;
  final String promptId;
  final int versionNumber;
  final String content;
  final String? negativePrompt;
  final String? changeNote;
  final DateTime createdAt;
}
