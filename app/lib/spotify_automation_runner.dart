import 'dart:io';

import 'assistant_models.dart';
import 'assistant_workspace_repository.dart';
import 'spotify_auth_service.dart';
import 'spotify_device_service.dart';
import 'spotify_playback_service.dart';
import 'spotify_settings.dart';
import 'spotify_settings_repository.dart';

class SpotifyAutomationRunner {
  SpotifyAutomationRunner({
    SpotifyAuthService? authService,
    SpotifyDeviceService? deviceService,
    SpotifyPlaybackService? playbackService,
  }) : _authService = authService ?? SpotifyAuthService(),
       _deviceService = deviceService ?? SpotifyDeviceService(),
       _playbackService = playbackService ?? SpotifyPlaybackService();

  final SpotifyAuthService _authService;
  final SpotifyDeviceService _deviceService;
  final SpotifyPlaybackService _playbackService;

  Future<SpotifyAutomationSettings> playRoutineAction({
    required SpotifyAutomationSettings settings,
    required SpotifyAction action,
  }) async {
    var refreshedSettings = await _authService.ensureValidSession(settings);
    final attempts = action.retryCount < 1 ? 1 : action.retryCount;
    Object? lastError;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      try {
        final devices = await _deviceService.listDevices(
          refreshedSettings.accessToken!,
        );
        final targetDevice = _deviceService.resolvePreferredDevice(
          devices: devices,
          preferredName: action.preferredDeviceName.isNotEmpty
              ? action.preferredDeviceName
              : refreshedSettings.defaultDeviceName,
          preferredType: action.preferredDeviceType.isNotEmpty
              ? action.preferredDeviceType
              : refreshedSettings.defaultDeviceType,
        );
        if (targetDevice == null) {
          throw StateError('No controllable Spotify device was available.');
        }

        await _playbackService.playRoutineAction(
          accessToken: refreshedSettings.accessToken!,
          action: action,
          targetDevice: targetDevice,
        );
        return refreshedSettings.copyWith(
          defaultDeviceName: targetDevice.name,
          defaultDeviceType: targetDevice.type,
        );
      } catch (error) {
        lastError = error;
        if (attempt == attempts) {
          break;
        }
        await Future<void>.delayed(Duration(seconds: action.retryDelaySeconds));
        refreshedSettings = await _authService.ensureValidSession(
          refreshedSettings,
        );
      }
    }
    throw lastError ??
        StateError('Spotify autoplay failed without an explicit error.');
  }
}

Future<bool> tryRunSpotifyAutomationCommand(List<String> args) async {
  final mode = _extractSpotifyActionMode(args);
  if (mode == null) {
    return false;
  }

  try {
    final workspace = await loadAssistantWorkspaceData();
    final targetTask = _findRoutineByMode(
      workspace.snapshot.spotifyRoutines,
      mode,
    );
    if (targetTask == null || targetTask.spotifyAction == null) {
      throw StateError('Could not find a Spotify routine for mode "$mode".');
    }

    var settings = await loadSpotifyAutomationSettings();
    final runner = SpotifyAutomationRunner();
    settings = await runner.playRoutineAction(
      settings: settings,
      action: targetTask.spotifyAction!,
    );
    await saveSpotifyAutomationSettings(settings);
    stdout.writeln('Spotify action "$mode" completed.');
    return true;
  } catch (error) {
    stderr.writeln('Spotify action failed: $error');
    rethrow;
  }
}

String? _extractSpotifyActionMode(List<String> args) {
  for (var index = 0; index < args.length; index++) {
    final arg = args[index];
    if (arg.startsWith('--run-spotify-action=')) {
      return arg.substring('--run-spotify-action='.length).trim();
    }
    if (arg == '--run-spotify-action' && index + 1 < args.length) {
      return args[index + 1].trim();
    }
  }
  return null;
}

RoutineTask? _findRoutineByMode(List<RoutineTask> routines, String mode) {
  for (final routine in routines) {
    if (routine.spotifyAction?.mode == mode) {
      return routine;
    }
  }
  return null;
}
