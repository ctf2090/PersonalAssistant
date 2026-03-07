import 'dart:convert';

import 'package:http/http.dart' as http;

class SpotifyResolvedTrack {
  const SpotifyResolvedTrack({
    required this.id,
    required this.uri,
    required this.name,
    required this.artistNames,
    required this.albumName,
  });

  final String id;
  final String uri;
  final String name;
  final List<String> artistNames;
  final String albumName;

  String get subtitle => '${artistNames.join(', ')} | $albumName';

  factory SpotifyResolvedTrack.fromJson(Map<String, dynamic> json) {
    final artists = json['artists'] as List<dynamic>? ?? const <dynamic>[];
    final album = json['album'];
    return SpotifyResolvedTrack(
      id: '${json['id'] ?? ''}',
      uri: '${json['uri'] ?? ''}',
      name: '${json['name'] ?? 'Unknown track'}',
      artistNames: artists
          .map((artist) => '${(artist as Map)['name'] ?? 'Unknown artist'}')
          .toList(),
      albumName: album is Map
          ? '${album['name'] ?? 'Unknown album'}'
          : 'Unknown album',
    );
  }
}

class SpotifyPlaylistCreationResult {
  const SpotifyPlaylistCreationResult({
    required this.id,
    required this.uri,
    required this.externalUrl,
    required this.name,
  });

  final String id;
  final String uri;
  final String externalUrl;
  final String name;

  factory SpotifyPlaylistCreationResult.fromJson(Map<String, dynamic> json) {
    final externalUrls = json['external_urls'];
    return SpotifyPlaylistCreationResult(
      id: '${json['id'] ?? ''}',
      uri: '${json['uri'] ?? ''}',
      externalUrl: externalUrls is Map
          ? '${externalUrls['spotify'] ?? ''}'
          : '',
      name: '${json['name'] ?? 'PA AI Playlist'}',
    );
  }
}

class SpotifyTrackService {
  SpotifyTrackService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<SpotifyResolvedTrack?> searchTopTrack({
    required String accessToken,
    required String title,
    required String artist,
  }) async {
    final exactTrack = await _search(
      accessToken: accessToken,
      query: artist.trim().isEmpty
          ? 'track:$title'
          : 'track:$title artist:$artist',
    );
    if (exactTrack != null) {
      return exactTrack;
    }
    return _search(
      accessToken: accessToken,
      query: artist.trim().isEmpty ? title : '$title $artist',
    );
  }

  Future<SpotifyPlaylistCreationResult> createPlaylist({
    required String accessToken,
    required String name,
    required String description,
    bool isPublic = false,
  }) async {
    final response = await _client.post(
      Uri.parse('https://api.spotify.com/v1/me/playlists'),
      headers: <String, String>{
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'name': name,
        'description': description,
        'public': isPublic,
      }),
    );
    if (response.statusCode != 201) {
      throw StateError(
        'Spotify create playlist failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : (decoded as Map).cast<String, dynamic>();
    return SpotifyPlaylistCreationResult.fromJson(payload);
  }

  Future<void> addTracksToPlaylist({
    required String accessToken,
    required String playlistId,
    required List<String> trackUris,
  }) async {
    for (var offset = 0; offset < trackUris.length; offset += 100) {
      final chunk = trackUris.skip(offset).take(100).toList();
      final response = await _client.post(
        Uri.parse('https://api.spotify.com/v1/playlists/$playlistId/items'),
        headers: <String, String>{
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{'uris': chunk}),
      );
      if (response.statusCode != 201) {
        throw StateError(
          'Spotify add tracks failed (${response.statusCode}): ${response.body}',
        );
      }
    }
  }

  Future<SpotifyResolvedTrack?> _search({
    required String accessToken,
    required String query,
  }) async {
    final response = await _client.get(
      Uri.https('api.spotify.com', '/v1/search', <String, String>{
        'q': query,
        'type': 'track',
        'limit': '1',
      }),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Spotify track search failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : (decoded as Map).cast<String, dynamic>();
    final tracks = payload['tracks'];
    final items = tracks is Map ? tracks['items'] as List<dynamic>? : null;
    if (items == null || items.isEmpty) {
      return null;
    }
    return SpotifyResolvedTrack.fromJson(
      (items.first as Map).cast<String, dynamic>(),
    );
  }
}
