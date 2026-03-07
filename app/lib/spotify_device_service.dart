import 'dart:convert';

import 'package:http/http.dart' as http;

class SpotifyDevice {
  const SpotifyDevice({
    required this.id,
    required this.isActive,
    required this.isRestricted,
    required this.name,
    required this.type,
    required this.volumePercent,
    required this.supportsVolume,
  });

  final String? id;
  final bool isActive;
  final bool isRestricted;
  final String name;
  final String type;
  final int? volumePercent;
  final bool supportsVolume;

  factory SpotifyDevice.fromJson(Map<String, dynamic> json) {
    return SpotifyDevice(
      id: _nullableString(json['id']),
      isActive: json['is_active'] == true,
      isRestricted: json['is_restricted'] == true,
      name: '${json['name'] ?? 'Unnamed device'}',
      type: '${json['type'] ?? 'unknown'}',
      volumePercent: json['volume_percent'] is num
          ? (json['volume_percent'] as num).toInt()
          : null,
      supportsVolume: json['supports_volume'] != false,
    );
  }

  String get label => '$name ($type)';
}

class SpotifyDeviceService {
  SpotifyDeviceService({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<SpotifyDevice>> listDevices(String accessToken) async {
    final response = await _client.get(
      Uri.parse('https://api.spotify.com/v1/me/player/devices'),
      headers: <String, String>{'Authorization': 'Bearer $accessToken'},
    );
    if (response.statusCode != 200) {
      throw StateError(
        'Unable to load Spotify devices (${response.statusCode}).',
      );
    }
    final decoded = jsonDecode(response.body);
    final payload = decoded is Map<String, dynamic>
        ? decoded
        : (decoded as Map).cast<String, dynamic>();
    final devices = payload['devices'] as List<dynamic>? ?? const <dynamic>[];
    return devices
        .map(
          (item) =>
              SpotifyDevice.fromJson((item as Map).cast<String, dynamic>()),
        )
        .toList();
  }

  SpotifyDevice? resolvePreferredDevice({
    required List<SpotifyDevice> devices,
    String? preferredName,
    String? preferredType,
  }) {
    final normalizedName = preferredName?.trim().toLowerCase() ?? '';
    final normalizedType = preferredType?.trim().toLowerCase() ?? '';
    if (normalizedName.isNotEmpty) {
      for (final device in devices) {
        if (device.name.toLowerCase() != normalizedName) {
          continue;
        }
        if (normalizedType.isNotEmpty &&
            device.type.toLowerCase() != normalizedType) {
          continue;
        }
        return device;
      }
    }

    for (final device in devices) {
      if (device.isActive && !device.isRestricted && device.id != null) {
        return device;
      }
    }

    for (final device in devices) {
      if (!device.isRestricted && device.id != null) {
        return device;
      }
    }
    return null;
  }
}

String? _nullableString(Object? value) {
  final text = '${value ?? ''}'.trim();
  return text.isEmpty ? null : text;
}
