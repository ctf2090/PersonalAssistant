import 'spotify_settings.dart';
import 'spotify_settings_repository_stub.dart'
    if (dart.library.io) 'spotify_settings_repository_io.dart'
    as repository;

Future<SpotifyAutomationSettings> loadSpotifyAutomationSettings() {
  return repository.loadSpotifyAutomationSettings();
}

Future<SpotifyAutomationSettings> saveSpotifyAutomationSettings(
  SpotifyAutomationSettings settings,
) {
  return repository.saveSpotifyAutomationSettings(settings);
}
