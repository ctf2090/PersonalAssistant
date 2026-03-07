import 'spotify_settings.dart';

Future<SpotifyAutomationSettings> loadSpotifyAutomationSettings() async {
  return SpotifyAutomationSettings.empty();
}

Future<SpotifyAutomationSettings> saveSpotifyAutomationSettings(
  SpotifyAutomationSettings settings,
) async {
  return settings;
}
