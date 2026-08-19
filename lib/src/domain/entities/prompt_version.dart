class PromptVersion {
  const PromptVersion({
    required this.id,
    required this.promptId,
    required this.versionNumber,
    required this.title,
    required this.content,
    required this.tags,
    required this.createdAt,
    this.negativePrompt,
    this.changeNote,
  });

  final String id;
  final String promptId;
  final int versionNumber;
  final String title;
  final String content;
  final List<String> tags;
  final String? negativePrompt;
  final String? changeNote;
  final DateTime createdAt;
}
