import 'dart:convert';

const JsonEncoder _spotifySettingsEncoder = JsonEncoder.withIndent('  ');

class SpotifyAutomationSettings {
  const SpotifyAutomationSettings({
    required this.clientId,
    required this.redirectPort,
    this.accessToken,
    this.refreshToken,
    this.accessTokenExpiresAt,
    this.connectedUserDisplayName,
    this.defaultDeviceName,
    this.defaultDeviceType,
    this.lastConnectedAt,
  });

  final String clientId;
  final int redirectPort;
  final String? accessToken;
  final String? refreshToken;
  final String? accessTokenExpiresAt;
  final String? connectedUserDisplayName;
  final String? defaultDeviceName;
  final String? defaultDeviceType;
  final String? lastConnectedAt;

  factory SpotifyAutomationSettings.empty() {
    return const SpotifyAutomationSettings(clientId: '', redirectPort: 43821);
  }

  factory SpotifyAutomationSettings.fromJson(Map<String, dynamic> json) {
    return SpotifyAutomationSettings(
      clientId: '${json['clientId'] ?? ''}',
      redirectPort: _intOrFallback(json['redirectPort'], 43821),
      accessToken: _nullableString(json['accessToken']),
      refreshToken: _nullableString(json['refreshToken']),
      accessTokenExpiresAt: _nullableString(json['accessTokenExpiresAt']),
      connectedUserDisplayName: _nullableString(
        json['connectedUserDisplayName'],
      ),
      defaultDeviceName: _nullableString(json['defaultDeviceName']),
      defaultDeviceType: _nullableString(json['defaultDeviceType']),
      lastConnectedAt: _nullableString(json['lastConnectedAt']),
    );
  }

  String get redirectUri => 'http://127.0.0.1:$redirectPort/spotify/callback';

  bool get hasClientId => clientId.trim().isNotEmpty;

  bool get hasRefreshToken => refreshToken?.trim().isNotEmpty ?? false;

  bool get hasAccessToken => accessToken?.trim().isNotEmpty ?? false;

  DateTime? get accessTokenExpiry =>
      DateTime.tryParse(accessTokenExpiresAt ?? '');

  bool get accessTokenIsFresh {
    final expiry = accessTokenExpiry;
    if (expiry == null) {
      return false;
    }
    return expiry.isAfter(
      DateTime.now().toUtc().add(const Duration(minutes: 1)),
    );
  }

  SpotifyAutomationSettings copyWith({
    String? clientId,
    int? redirectPort,
    String? accessToken,
    bool clearAccessToken = false,
    String? refreshToken,
    bool clearRefreshToken = false,
    String? accessTokenExpiresAt,
    bool clearAccessTokenExpiresAt = false,
    String? connectedUserDisplayName,
    bool clearConnectedUserDisplayName = false,
    String? defaultDeviceName,
    bool clearDefaultDeviceName = false,
    String? defaultDeviceType,
    bool clearDefaultDeviceType = false,
    String? lastConnectedAt,
    bool clearLastConnectedAt = false,
  }) {
    return SpotifyAutomationSettings(
      clientId: clientId ?? this.clientId,
      redirectPort: redirectPort ?? this.redirectPort,
      accessToken: clearAccessToken ? null : accessToken ?? this.accessToken,
      refreshToken: clearRefreshToken
          ? null
          : refreshToken ?? this.refreshToken,
      accessTokenExpiresAt: clearAccessTokenExpiresAt
          ? null
          : accessTokenExpiresAt ?? this.accessTokenExpiresAt,
      connectedUserDisplayName: clearConnectedUserDisplayName
          ? null
          : connectedUserDisplayName ?? this.connectedUserDisplayName,
      defaultDeviceName: clearDefaultDeviceName
          ? null
          : defaultDeviceName ?? this.defaultDeviceName,
      defaultDeviceType: clearDefaultDeviceType
          ? null
          : defaultDeviceType ?? this.defaultDeviceType,
      lastConnectedAt: clearLastConnectedAt
          ? null
          : lastConnectedAt ?? this.lastConnectedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'clientId': clientId,
      'redirectPort': redirectPort,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      'accessTokenExpiresAt': accessTokenExpiresAt,
      'connectedUserDisplayName': connectedUserDisplayName,
      'defaultDeviceName': defaultDeviceName,
      'defaultDeviceType': defaultDeviceType,
      'lastConnectedAt': lastConnectedAt,
    };
  }

  String toPrettyJson() {
    return _spotifySettingsEncoder.convert(toJson());
  }
}

String? _nullableString(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}

int _intOrFallback(Object? value, int fallback) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse('${value ?? ''}') ?? fallback;
}
