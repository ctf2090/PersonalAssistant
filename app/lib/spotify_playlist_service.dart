import 'dart:convert';

import 'package:http/http.dart' as http;

class SpotifyPlaylistSummary {
  const SpotifyPlaylistSummary({
    required this.id,
    required this.uri,
    required this.name,
    required this.ownerName,
    required this.trackCount,
  });

  final String id;
  final String uri;
  final String name;
  final String ownerName;
  final int trackCount;

  String get label => '$name · $ownerName';

  factory SpotifyPlaylistSummary.fromJson(Map<String, dynamic> json) {
    final tracks = json['tracks'];
    final owner = json['owner'];
    return SpotifyPlaylistSummary(
      id: '${json['id'] ?? ''}',
      uri: '${json['uri'] ?? ''}',
      name: '${json['name'] ?? 'Untitled playlist'}',
      ownerName: owner is Map
          ? '${owner['display_name'] ?? owner['id'] ?? 'Unknown owner'}'
          : 'Unknown owner',
      trackCount: tracks is Map && tracks['total'] is num
          ? (tracks['total'] as num).toInt()
          : 0,
    );
  }
}

class SpotifyPlaylistService {
  SpotifyPlaylistService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<SpotifyPlaylistSummary>> listCurrentUserPlaylists(
    String accessToken,
  ) async {
    final playlists = <SpotifyPlaylistSummary>[];
    Uri? nextUri = Uri.https(
      'api.spotify.com',
      '/v1/me/playlists',
      <String, String>{'limit': '50'},
    );

    while (nextUri != null) {
      final response = await _client.get(
        nextUri,
        headers: <String, String>{'Authorization': 'Bearer $accessToken'},
      );
      if (response.statusCode != 200) {
        throw StateError(
          'Unable to load Spotify playlists (${response.statusCode}). Reconnect Spotify if scopes changed.',
        );
      }
      final decoded = jsonDecode(response.body);
      final payload = decoded is Map<String, dynamic>
          ? decoded
          : (decoded as Map).cast<String, dynamic>();
      final items = payload['items'] as List<dynamic>? ?? const <dynamic>[];
      playlists.addAll(
        items.map(
          (item) => SpotifyPlaylistSummary.fromJson(
            (item as Map).cast<String, dynamic>(),
          ),
        ),
      );
      final nextValue = payload['next'];
      nextUri = nextValue is String && nextValue.trim().isNotEmpty
          ? Uri.parse(nextValue)
          : null;
    }

    return playlists;
  }
}
