import 'dart:io';

import 'assistant_models.dart';

class WindowsScheduleService {
  const WindowsScheduleService();

  String buildTaskName(String mode) => 'PA\\Spotify\\$mode';

  bool canScheduleRoutine(RoutineTask routine) {
    final action = routine.spotifyAction;
    return action != null &&
        action.enabled &&
        action.autoPlay &&
        _normalizeDailyTime(routine.time) != null;
  }

  Future<void> upsertRoutineTask({
    required RoutineTask routine,
    required String executablePath,
  }) async {
    final action = routine.spotifyAction;
    if (action == null || !action.enabled || !action.autoPlay) {
      throw StateError(
        'Routine does not have an enabled Spotify autoplay action.',
      );
    }
    final startTime = _normalizeDailyTime(routine.time);
    if (startTime == null) {
      throw StateError(
        'Routine time "${routine.time}" is not a schedulable HH:mm value.',
      );
    }

    final result = await Process.run('schtasks', <String>[
      '/Create',
      '/SC',
      'DAILY',
      '/TN',
      buildTaskName(action.mode),
      '/ST',
      startTime,
      '/TR',
      _buildTaskCommand(executablePath, action.mode),
      '/F',
    ]);
    if (result.exitCode != 0) {
      throw ProcessException(
        'schtasks',
        const <String>[],
        '${result.stdout}\n${result.stderr}'.trim(),
        result.exitCode,
      );
    }
  }

  Future<void> deleteRoutineTask(String mode) async {
    final result = await Process.run('schtasks', <String>[
      '/Delete',
      '/TN',
      buildTaskName(mode),
      '/F',
    ]);
    final combinedOutput = '${result.stdout}\n${result.stderr}'.toLowerCase();
    if (result.exitCode != 0 && !combinedOutput.contains('cannot find')) {
      throw ProcessException(
        'schtasks',
        const <String>[],
        '${result.stdout}\n${result.stderr}'.trim(),
        result.exitCode,
      );
    }
  }

  String _buildTaskCommand(String executablePath, String mode) {
    return '"$executablePath" --run-spotify-action=$mode';
  }

  String? _normalizeDailyTime(String rawTime) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(rawTime.trim());
    if (match == null) {
      return null;
    }
    final hour = int.tryParse(match.group(1)!);
    final minute = int.tryParse(match.group(2)!);
    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}
