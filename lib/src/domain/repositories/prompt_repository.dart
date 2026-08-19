import '../entities/prompt.dart';
import '../entities/prompt_version.dart';

abstract interface class PromptRepository {
  Future<Prompt?> getById(String id);

  Future<List<Prompt>> list({
    Set<String>? tags,
    bool includeArchived = false,
  });

  Future<void> save(Prompt prompt);

  Future<void> archive(String id);

  Future<void> delete(String id);

  Future<PromptVersion> createVersion({
    required String promptId,
    required String content,
    String? negativePrompt,
    String? changeNote,
  });

  Future<List<PromptVersion>> listVersions(String promptId);

  Future<void> rollbackToVersion({
    required String promptId,
    required String versionId,
  });

  Future<String> exportJson();

  Future<void> importJson(String json);
}
