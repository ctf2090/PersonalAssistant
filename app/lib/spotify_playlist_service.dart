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

  SpotifyPlaylistSummary copyWith({int? trackCount}) {
    return SpotifyPlaylistSummary(
      id: id,
      uri: uri,
      name: name,
      ownerName: ownerName,
      trackCount: trackCount ?? this.trackCount,
    );
  }

  factory SpotifyPlaylistSummary.fromJson(Map<String, dynamic> json) {
    final items = json['items'];
    final owner = json['owner'];
    return SpotifyPlaylistSummary(
      id: '${json['id'] ?? ''}',
      uri: '${json['uri'] ?? ''}',
      name: '${json['name'] ?? 'Untitled playlist'}',
      ownerName: owner is Map
          ? '${owner['display_name'] ?? owner['id'] ?? 'Unknown owner'}'
          : 'Unknown owner',
      trackCount: _readInt(items is Map ? items['total'] : null, fallback: 0),
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

    return _fillMissingTrackCounts(accessToken, playlists);
  }

  Future<List<SpotifyPlaylistSummary>> _fillMissingTrackCounts(
    String accessToken,
    List<SpotifyPlaylistSummary> playlists,
  ) async {
    final results = <SpotifyPlaylistSummary>[];
    for (final playlist in playlists) {
      if (playlist.trackCount > 0) {
        results.add(playlist);
        continue;
      }
      final count = await _fetchPlaylistTrackCount(accessToken, playlist.id);
      results.add(playlist.copyWith(trackCount: count));
    }
    return results;
  }

  Future<int> _fetchPlaylistTrackCount(
    String accessToken,
    String playlistId,
  ) async {
    final response = await _client.get(
      Uri.https(
        'api.spotify.com',
        '/v1/playlists/$playlistId',
        <String, String>{'fields': 'tracks.total'},
      ),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      return 0;
    }
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : (decoded as Map).cast<String, dynamic>();
    final tracks = payload['tracks'];
    return _readInt(tracks is Map ? tracks['total'] : null, fallback: 0);
  }
}

int _readInt(Object? value, {required int fallback}) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}
