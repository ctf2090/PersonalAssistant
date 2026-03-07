import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'spotify_settings.dart';

const List<String> _spotifyScopes = <String>[
  'user-modify-playback-state',
  'user-read-playback-state',
  'user-read-currently-playing',
  'playlist-read-private',
  'playlist-read-collaborative',
  'playlist-modify-private',
  'playlist-modify-public',
];

class SpotifyAuthService {
  SpotifyAuthService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<SpotifyAutomationSettings> connect(
    SpotifyAutomationSettings settings,
  ) async {
    if (!settings.hasClientId) {
      throw StateError('Spotify client ID is required before connecting.');
    }

    final verifier = _createCodeVerifier();
    final challenge = _createCodeChallenge(verifier);
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      settings.redirectPort,
    );

    try {
      final callbackFuture = _waitForAuthorizationCode(server);
      final authUri =
          Uri.https('accounts.spotify.com', '/authorize', <String, String>{
            'client_id': settings.clientId,
            'response_type': 'code',
            'redirect_uri': settings.redirectUri,
            'code_challenge_method': 'S256',
            'code_challenge': challenge,
            'scope': _spotifyScopes.join(' '),
          });

      final launched = await launchUrl(
        authUri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        throw StateError('Could not open the Spotify authorization page.');
      }

      final code = await callbackFuture.timeout(
        const Duration(minutes: 5),
        onTimeout: () => throw TimeoutException(
          'Spotify login timed out before the callback returned.',
        ),
      );
      final tokenPayload = await _exchangeAuthorizationCode(
        clientId: settings.clientId,
        redirectUri: settings.redirectUri,
        codeVerifier: verifier,
        code: code,
      );
      final profileName = await _fetchCurrentUserLabel(
        tokenPayload.accessToken,
      );
      return settings.copyWith(
        accessToken: tokenPayload.accessToken,
        refreshToken: tokenPayload.refreshToken ?? settings.refreshToken,
        accessTokenExpiresAt: tokenPayload.expiresAt.toUtc().toIso8601String(),
        connectedUserDisplayName: profileName,
        lastConnectedAt: DateTime.now().toUtc().toIso8601String(),
      );
    } finally {
      await server.close(force: true);
    }
  }

  Future<SpotifyAutomationSettings> ensureValidSession(
    SpotifyAutomationSettings settings,
  ) async {
    if (settings.hasAccessToken && settings.accessTokenIsFresh) {
      return settings;
    }
    if (!settings.hasRefreshToken) {
      throw StateError('Spotify session is missing a refresh token.');
    }
    return refreshSession(settings);
  }

  Future<SpotifyAutomationSettings> refreshSession(
    SpotifyAutomationSettings settings,
  ) async {
    if (!settings.hasClientId || !settings.hasRefreshToken) {
      throw StateError('Spotify client ID and refresh token are required.');
    }
    final response = await _client.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'grant_type': 'refresh_token',
        'refresh_token': settings.refreshToken!,
        'client_id': settings.clientId,
      },
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Spotify token refresh failed (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return settings.copyWith(
      accessToken: '${decoded['access_token']}',
      refreshToken:
          _nullableString(decoded['refresh_token']) ?? settings.refreshToken,
      accessTokenExpiresAt: DateTime.now()
          .toUtc()
          .add(
            Duration(seconds: (decoded['expires_in'] as num?)?.toInt() ?? 3600),
          )
          .toIso8601String(),
      lastConnectedAt: DateTime.now().toUtc().toIso8601String(),
    );
  }

  Future<String> _waitForAuthorizationCode(HttpServer server) async {
    final request = await server.first;
    final query = request.uri.queryParameters;
    final code = query['code'];
    final error = query['error'];

    request.response.headers.contentType = ContentType.html;
    if (error != null) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(
        '<html><body><h2>Spotify login failed</h2><p>$error</p></body></html>',
      );
      await request.response.close();
      throw StateError('Spotify authorization failed: $error');
    }
    if (code == null || code.trim().isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      request.response.write(
        '<html><body><h2>Spotify login failed</h2><p>No code received.</p></body></html>',
      );
      await request.response.close();
      throw StateError('Spotify authorization callback did not return a code.');
    }

    request.response.statusCode = HttpStatus.ok;
    request.response.write(
      '<html><body><h2>Spotify connected</h2><p>You can return to PA.</p></body></html>',
    );
    await request.response.close();
    return code;
  }

  Future<_SpotifyTokenPayload> _exchangeAuthorizationCode({
    required String clientId,
    required String redirectUri,
    required String codeVerifier,
    required String code,
  }) async {
    final response = await _client.post(
      Uri.parse('https://accounts.spotify.com/api/token'),
      headers: <String, String>{
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: <String, String>{
        'grant_type': 'authorization_code',
        'code': code,
        'redirect_uri': redirectUri,
        'client_id': clientId,
        'code_verifier': codeVerifier,
      },
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Spotify token exchange failed (${response.statusCode}): ${response.body}',
      );
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    return _SpotifyTokenPayload.fromJson(decoded);
  }

  Future<String> _fetchCurrentUserLabel(String accessToken) async {
    final response = await _client.get(
      Uri.parse('https://api.spotify.com/v1/me'),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      return 'Connected Spotify user';
    }
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : (decoded as Map).cast<String, dynamic>();
    final displayName = _nullableString(payload['display_name']);
    return displayName ?? '${payload['id'] ?? 'Connected Spotify user'}';
  }
}

class _SpotifyTokenPayload {
  const _SpotifyTokenPayload({
    required this.accessToken,
    required this.expiresAt,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final DateTime expiresAt;

  factory _SpotifyTokenPayload.fromJson(Map<String, dynamic> json) {
    return _SpotifyTokenPayload(
      accessToken: '${json['access_token']}',
      refreshToken: _nullableString(json['refresh_token']),
      expiresAt: DateTime.now().add(
        Duration(seconds: (json['expires_in'] as num?)?.toInt() ?? 3600),
      ),
    );
  }
}

String _createCodeVerifier() {
  final random = Random.secure();
  final bytes = List<int>.generate(64, (_) => random.nextInt(256));
  return base64UrlEncode(bytes).replaceAll('=', '');
}

String _createCodeChallenge(String verifier) {
  final hash = sha256.convert(utf8.encode(verifier));
  return base64UrlEncode(hash.bytes).replaceAll('=', '');
}

String? _nullableString(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
