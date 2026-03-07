import 'dart:io';

class WindowsSpotifyLauncherService {
  const WindowsSpotifyLauncherService();

  Future<bool> isSpotifyRunning() async {
    final result = await Process.run('tasklist', <String>[
      '/FI',
      'IMAGENAME eq Spotify.exe',
    ]);
    if (result.exitCode != 0) {
      return false;
    }
    final output = '${result.stdout}'.toLowerCase();
    return output.contains('spotify.exe');
  }

  Future<void> ensureStarted() async {
    if (await isSpotifyRunning()) {
      return;
    }
    if (await _launchViaProtocol()) {
      return;
    }
    if (await _launchViaKnownPaths()) {
      return;
    }
    throw StateError('Could not start Spotify on Windows 11.');
  }

  Future<bool> _launchViaProtocol() async {
    final result = await Process.run('cmd', <String>[
      '/c',
      'start',
      '',
      'spotify:',
    ]);
    return result.exitCode == 0;
  }

  Future<bool> _launchViaKnownPaths() async {
    for (final path in _candidatePaths()) {
      final file = File(path);
      if (!file.existsSync()) {
        continue;
      }
      try {
        await Process.start(path, const <String>[]);
        return true;
      } catch (_) {
        continue;
      }
    }
    return false;
  }

  List<String> _candidatePaths() {
    final appData = Platform.environment['APPDATA'];
    final localAppData = Platform.environment['LOCALAPPDATA'];
    final programFiles = Platform.environment['ProgramFiles'];
    final programFilesX86 = Platform.environment['ProgramFiles(x86)'];

    return <String>[
      if (appData != null) '$appData\\Spotify\\Spotify.exe',
      if (localAppData != null)
        '$localAppData\\Microsoft\\WindowsApps\\Spotify.exe',
      if (programFiles != null) '$programFiles\\Spotify\\Spotify.exe',
      if (programFilesX86 != null) '$programFilesX86\\Spotify\\Spotify.exe',
    ];
  }
}
