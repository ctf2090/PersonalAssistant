import 'assistant_models.dart';
import 'assistant_workspace_repository.dart';

Future<AssistantSnapshot> loadAssistantSnapshot() async {
  final workspace = await loadAssistantWorkspaceData();
  return workspace.snapshot;
}
