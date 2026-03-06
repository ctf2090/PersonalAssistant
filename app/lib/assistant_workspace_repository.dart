import 'assistant_models.dart';
import 'assistant_workspace_repository_stub.dart'
    if (dart.library.io) 'assistant_workspace_repository_io.dart' as repository;

Future<AssistantWorkspaceData> loadAssistantWorkspaceData() {
  return repository.loadAssistantWorkspaceData();
}

Future<AssistantWorkspaceData> saveAssistantWorkspaceData({
  required String mdsJson,
  required String mdrJson,
}) {
  return repository.saveAssistantWorkspaceData(
    mdsJson: mdsJson,
    mdrJson: mdrJson,
  );
}

Future<AssistantWorkspaceData> reloadAssistantWorkspaceData() {
  return repository.loadAssistantWorkspaceData();
}

Future<String?> importAssistantDocument(AssistantDocumentType type) {
  return repository.importAssistantDocument(type);
}

Future<void> exportAssistantDocument({
  required AssistantDocumentType type,
  required String content,
}) {
  return repository.exportAssistantDocument(type: type, content: content);
}
