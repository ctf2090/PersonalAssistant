import 'assistant_models.dart';

Future<AssistantWorkspaceData> loadAssistantWorkspaceData() async {
  return AssistantWorkspaceData.sample();
}

Future<AssistantWorkspaceData> saveAssistantWorkspaceData({
  required String mdsJson,
  required String mdrJson,
}) async {
  return AssistantWorkspaceData.fromJsonTexts(mdsJson: mdsJson, mdrJson: mdrJson);
}

Future<String?> importAssistantDocument(AssistantDocumentType type) async {
  return null;
}

Future<void> exportAssistantDocument({
  required AssistantDocumentType type,
  required String content,
}) async {}
