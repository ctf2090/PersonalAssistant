import 'dart:convert';
import 'dart:io';

import 'assistant_models.dart';

Future<AssistantSnapshot> loadAssistantSnapshot() async {
  final mds = jsonDecode(await _readDataFile('MDS.json')) as Map<String, dynamic>;
  final mdr = jsonDecode(await _readDataFile('MDR.json')) as Map<String, dynamic>;
  return AssistantSnapshot.fromRecoveredData(mds, mdr);
}

Future<String> _readDataFile(String fileName) async {
  final file = _findDataFile(fileName);
  return file.readAsString();
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
