import 'dart:convert';

import 'package:http/http.dart' as http;

import 'assistant_models.dart';
import 'spotify_device_service.dart';

class SpotifyPlaybackService {
  SpotifyPlaybackService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<void> playRoutineAction({
    required String accessToken,
    required SpotifyAction action,
    required SpotifyDevice targetDevice,
  }) async {
    final deviceId = targetDevice.id;
    if (deviceId == null || deviceId.trim().isEmpty) {
      throw StateError('Spotify target device does not expose a device ID.');
    }
    if (targetDevice.isRestricted) {
      throw StateError(
        'Spotify target device is restricted and cannot be controlled.',
      );
    }

    await _transferPlayback(accessToken: accessToken, deviceId: deviceId);

    await Future<void>.delayed(const Duration(milliseconds: 350));
    await _startPlayback(
      accessToken: accessToken,
      deviceId: deviceId,
      playlistUri: action.primaryPlaylistUri,
    );
  }

  Future<void> _transferPlayback({
    required String accessToken,
    required String deviceId,
  }) async {
    final response = await _client.put(
      Uri.parse('https://api.spotify.com/v1/me/player'),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'device_ids': <String>[deviceId],
        'play': false,
      }),
    );
    if (response.statusCode != 204) {
      throw StateError(
        'Spotify transfer playback failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<void> _startPlayback({
    required String accessToken,
    required String deviceId,
    required String playlistUri,
  }) async {
    final body = playlistUri.trim().isEmpty
        ? null
        : jsonEncode(<String, dynamic>{'context_uri': playlistUri});
    final response = await _client.put(
      Uri.https('api.spotify.com', '/v1/me/player/play', <String, String>{
        'device_id': deviceId,
      }),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: body,
    );
    if (response.statusCode != 204) {
      throw StateError(
        'Spotify start playback failed (${response.statusCode}): ${response.body}',
      );
    }
  }
}
