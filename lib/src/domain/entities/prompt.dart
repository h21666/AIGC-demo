class Prompt {
  const Prompt({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.negativePrompt,
    this.description,
    this.tags = const [],
    this.currentVersionId,
    this.isArchived = false,
  });

  final String id;
  final String title;
  final String content;
  final String? negativePrompt;
  final String? description;
  final List<String> tags;
  final String? currentVersionId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isArchived;
}
