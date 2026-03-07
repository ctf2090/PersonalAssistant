import 'dart:convert';

import 'package:http/http.dart' as http;

class OpenAiPlaylistTrackCandidate {
  const OpenAiPlaylistTrackCandidate({
    required this.title,
    required this.artist,
    required this.reason,
  });

  final String title;
  final String artist;
  final String reason;

  factory OpenAiPlaylistTrackCandidate.fromJson(Map<String, dynamic> json) {
    return OpenAiPlaylistTrackCandidate(
      title: '${json['title'] ?? ''}'.trim(),
      artist: '${json['artist'] ?? ''}'.trim(),
      reason: '${json['reason'] ?? ''}'.trim(),
    );
  }
}

class OpenAiPlaylistPlan {
  const OpenAiPlaylistPlan({
    required this.title,
    required this.description,
    required this.moodTags,
    required this.tracks,
  });

  final String title;
  final String description;
  final List<String> moodTags;
  final List<OpenAiPlaylistTrackCandidate> tracks;

  factory OpenAiPlaylistPlan.fromJson(Map<String, dynamic> json) {
    final rawTracks = json['tracks'] as List<dynamic>? ?? const <dynamic>[];
    final rawMoodTags =
        json['mood_tags'] as List<dynamic>? ?? const <dynamic>[];
    return OpenAiPlaylistPlan(
      title: '${json['title'] ?? 'PA AI Playlist'}'.trim(),
      description: '${json['description'] ?? ''}'.trim(),
      moodTags: rawMoodTags.map((item) => '$item').toList(),
      tracks: rawTracks
          .map(
            (item) => OpenAiPlaylistTrackCandidate.fromJson(
              (item as Map).cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class OpenAiPlaylistService {
  OpenAiPlaylistService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<OpenAiPlaylistPlan> generatePlaylistPlan({
    required String apiKey,
    required String model,
    required String prompt,
    required int targetTrackCount,
  }) async {
    final response = await _client.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: <String, String>{
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(<String, dynamic>{
        'model': model,
        'response_format': <String, dynamic>{
          'type': 'json_schema',
          'json_schema': <String, dynamic>{
            'name': 'playlist_plan',
            'strict': true,
            'schema': <String, dynamic>{
              'type': 'object',
              'additionalProperties': false,
              'properties': <String, dynamic>{
                'title': <String, dynamic>{'type': 'string'},
                'description': <String, dynamic>{'type': 'string'},
                'mood_tags': <String, dynamic>{
                  'type': 'array',
                  'items': <String, dynamic>{'type': 'string'},
                },
                'tracks': <String, dynamic>{
                  'type': 'array',
                  'items': <String, dynamic>{
                    'type': 'object',
                    'additionalProperties': false,
                    'properties': <String, dynamic>{
                      'title': <String, dynamic>{'type': 'string'},
                      'artist': <String, dynamic>{'type': 'string'},
                      'reason': <String, dynamic>{'type': 'string'},
                    },
                    'required': <String>['title', 'artist', 'reason'],
                  },
                },
              },
              'required': <String>[
                'title',
                'description',
                'mood_tags',
                'tracks',
              ],
            },
          },
        },
        'messages': <Map<String, String>>[
          <String, String>{
            'role': 'system',
            'content':
                'You design Spotify playlists. Produce a concise playlist plan with real, well-known, searchable songs only. Avoid made-up tracks. Prefer globally available studio versions unless the user asks otherwise.',
          },
          <String, String>{
            'role': 'user',
            'content':
                'Create a Spotify playlist plan for this request: "$prompt". Return exactly $targetTrackCount tracks. Mix familiarity and fit, but keep all tracks easy to search on Spotify.',
          },
        ],
      }),
    );
    if (response.statusCode != 200) {
      throw StateError(
        'OpenAI playlist generation failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : (decoded as Map).cast<String, dynamic>();
    final choices = payload['choices'] as List<dynamic>? ?? const <dynamic>[];
    if (choices.isEmpty) {
      throw StateError('OpenAI did not return any completion choices.');
    }
    final message = (choices.first as Map).cast<String, dynamic>()['message'];
    if (message is! Map) {
      throw StateError('OpenAI returned an unexpected message payload.');
    }
    final content = message['content'];
    if (content is! String || content.trim().isEmpty) {
      throw StateError('OpenAI returned an empty playlist plan.');
    }
    final planJson = jsonDecode(content);
    final planPayload = planJson is Map<String, dynamic>
        ? planJson
        : (planJson as Map).cast<String, dynamic>();
    return OpenAiPlaylistPlan.fromJson(planPayload);
  }
}
