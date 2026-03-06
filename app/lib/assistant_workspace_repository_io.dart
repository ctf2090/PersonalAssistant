import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:path_provider/path_provider.dart';

import 'assistant_models.dart';

const XTypeGroup _jsonTypeGroup = XTypeGroup(
  label: 'JSON',
  extensions: <String>['json'],
);

Future<AssistantWorkspaceData> loadAssistantWorkspaceData() async {
  final mdsFile = _findDataFile(AssistantDocumentType.mds.fileName);
  final mdrFile = _findDataFile(AssistantDocumentType.mdr.fileName);

  return AssistantWorkspaceData.fromJsonTexts(
    mdsJson: await mdsFile.readAsString(),
    mdrJson: await mdrFile.readAsString(),
    mdsPath: mdsFile.path,
    mdrPath: mdrFile.path,
  );
}

Future<AssistantWorkspaceData> saveAssistantWorkspaceData({
  required String mdsJson,
  required String mdrJson,
}) async {
  final workspace = AssistantWorkspaceData.fromJsonTexts(
    mdsJson: mdsJson,
    mdrJson: mdrJson,
    mdsPath: _findDataFile(AssistantDocumentType.mds.fileName).path,
    mdrPath: _findDataFile(AssistantDocumentType.mdr.fileName).path,
  );

  await File(workspace.mdsPath!).writeAsString('${workspace.mdsJson}\n');
  await File(workspace.mdrPath!).writeAsString('${workspace.mdrJson}\n');
  return workspace;
}

Future<String?> importAssistantDocument(AssistantDocumentType type) async {
  final initialDirectory = await _resolveInitialDirectory();
  final file = await openFile(
    acceptedTypeGroups: const <XTypeGroup>[_jsonTypeGroup],
    initialDirectory: initialDirectory,
    confirmButtonText: 'Import ${type.label}',
  );
  return file?.readAsString();
}

Future<void> exportAssistantDocument({
  required AssistantDocumentType type,
  required String content,
}) async {
  final initialDirectory = await _resolveInitialDirectory();
  final location = await getSaveLocation(
    acceptedTypeGroups: const <XTypeGroup>[_jsonTypeGroup],
    initialDirectory: initialDirectory,
    suggestedName: type.fileName,
    confirmButtonText: 'Export ${type.label}',
  );
  if (location == null) {
    return;
  }
  await File(location.path).writeAsString('$content\n');
}

Future<String?> _resolveInitialDirectory() async {
  final downloads = await getDownloadsDirectory();
  return downloads?.path;
}

File _findDataFile(String fileName) {
  for (final start in _searchRoots()) {
    Directory current = start.absolute;
    while (true) {
      final candidate = File(
        '${current.path}${Platform.pathSeparator}data${Platform.pathSeparator}$fileName',
      );
      if (candidate.existsSync()) {
        return candidate;
      }
      if (current.parent.path == current.path) {
        break;
      }
      current = current.parent;
    }
  }

  throw FileSystemException(
    'Could not find data file in this workspace.',
    fileName,
  );
}

List<Directory> _searchRoots() {
  final roots = <Directory>[Directory.current];
  final executable = File(Platform.resolvedExecutable);
  roots.add(executable.parent);
  return roots;
}
