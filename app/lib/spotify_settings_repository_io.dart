import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import 'spotify_settings.dart';

const String _spotifySettingsFileName = 'spotify_settings.json';

Future<SpotifyAutomationSettings> loadSpotifyAutomationSettings() async {
  final file = await _resolveSpotifySettingsFile();
  if (!file.existsSync()) {
    return SpotifyAutomationSettings.empty();
  }
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is Map<String, dynamic>) {
    return SpotifyAutomationSettings.fromJson(decoded);
  }
  if (decoded is Map) {
    return SpotifyAutomationSettings.fromJson(decoded.cast<String, dynamic>());
  }
  throw const FormatException('Spotify settings JSON root must be an object.');
}

Future<SpotifyAutomationSettings> saveSpotifyAutomationSettings(
  SpotifyAutomationSettings settings,
) async {
  final file = await _resolveSpotifySettingsFile();
  await file.writeAsString('${settings.toPrettyJson()}\n');
  return settings;
}

Future<File> _resolveSpotifySettingsFile() async {
  final appSupportDirectory = await getApplicationSupportDirectory();
  if (!appSupportDirectory.existsSync()) {
    await appSupportDirectory.create(recursive: true);
  }
  return File(
    '${appSupportDirectory.path}${Platform.pathSeparator}$_spotifySettingsFileName',
  );
}
