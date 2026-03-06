import 'assistant_snapshot_loader_stub.dart'
    if (dart.library.io) 'assistant_snapshot_loader_io.dart' as loader;

import 'assistant_models.dart';

Future<AssistantSnapshot> loadAssistantSnapshot() {
  return loader.loadAssistantSnapshot();
}
