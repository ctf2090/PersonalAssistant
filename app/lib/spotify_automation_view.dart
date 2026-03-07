import 'dart:io';

import 'package:flutter/material.dart';

import 'assistant_models.dart';
import 'spotify_auth_service.dart';
import 'spotify_automation_runner.dart';
import 'spotify_device_service.dart';
import 'spotify_settings.dart';
import 'spotify_settings_repository.dart';
import 'windows_schedule_service.dart';

class SpotifyAutomationView extends StatefulWidget {
  const SpotifyAutomationView({super.key, required this.workspace});

  final AssistantWorkspaceData workspace;

  @override
  State<SpotifyAutomationView> createState() => _SpotifyAutomationViewState();
}

class _SpotifyAutomationViewState extends State<SpotifyAutomationView> {
  final SpotifyAuthService _authService = SpotifyAuthService();
  final SpotifyDeviceService _deviceService = SpotifyDeviceService();
  final SpotifyAutomationRunner _automationRunner = SpotifyAutomationRunner();
  final WindowsScheduleService _scheduleService =
      const WindowsScheduleService();

  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _redirectPortController = TextEditingController();

  SpotifyAutomationSettings _settings = SpotifyAutomationSettings.empty();
  List<SpotifyDevice> _devices = const <SpotifyDevice>[];
  String? _statusMessage;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _clientIdController.dispose();
    _redirectPortController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final settings = await loadSpotifyAutomationSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _settings = settings;
      _clientIdController.text = settings.clientId;
      _redirectPortController.text = '${settings.redirectPort}';
    });
  }

  Future<void> _runBusyTask(Future<void> Function() action) async {
    if (_isBusy) {
      return;
    }
    setState(() {
      _isBusy = true;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() {
          _statusMessage = '$error';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  SpotifyAutomationSettings _draftSettings() {
    return _settings.copyWith(
      clientId: _clientIdController.text.trim(),
      redirectPort: int.tryParse(_redirectPortController.text.trim()) ?? 43821,
    );
  }

  Future<void> _saveSettingsOnly() async {
    await _runBusyTask(() async {
      final saved = await saveSpotifyAutomationSettings(_draftSettings());
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = saved;
        _statusMessage = 'Spotify settings saved locally.';
      });
    });
  }

  Future<void> _connectSpotify() async {
    await _runBusyTask(() async {
      final savedDraft = await saveSpotifyAutomationSettings(_draftSettings());
      final connected = await _authService.connect(savedDraft);
      final persisted = await saveSpotifyAutomationSettings(connected);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = persisted;
        _statusMessage = 'Spotify account connected.';
      });
    });
  }

  Future<void> _refreshDevices() async {
    await _runBusyTask(() async {
      var refreshed = await _authService.ensureValidSession(_draftSettings());
      refreshed = await saveSpotifyAutomationSettings(refreshed);
      final devices = await _deviceService.listDevices(refreshed.accessToken!);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = refreshed;
        _devices = devices;
        _statusMessage = 'Loaded ${devices.length} Spotify device(s).';
      });
    });
  }

  Future<void> _setDefaultDevice(SpotifyDevice device) async {
    await _runBusyTask(() async {
      final saved = await saveSpotifyAutomationSettings(
        _settings.copyWith(
          defaultDeviceName: device.name,
          defaultDeviceType: device.type,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = saved;
        _statusMessage = 'Default Spotify device set to ${device.label}.';
      });
    });
  }

  Future<void> _testRoutine(RoutineTask task) async {
    final action = task.spotifyAction;
    if (action == null) {
      return;
    }
    await _runBusyTask(() async {
      var saved = await saveSpotifyAutomationSettings(_draftSettings());
      saved = await _automationRunner.playRoutineAction(
        settings: saved,
        action: action,
      );
      saved = await saveSpotifyAutomationSettings(saved);
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = saved;
        _statusMessage = 'Triggered Spotify mode ${action.mode}.';
      });
    });
  }

  Future<void> _syncSchedules() async {
    await _runBusyTask(() async {
      final executablePath = Platform.resolvedExecutable;
      for (final routine in widget.workspace.snapshot.spotifyRoutines) {
        if (!_scheduleService.canScheduleRoutine(routine)) {
          continue;
        }
        await _scheduleService.upsertRoutineTask(
          routine: routine,
          executablePath: executablePath,
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Synced Win11 Spotify tasks using $executablePath.';
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spotifyRoutines = widget.workspace.snapshot.spotifyRoutines;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Text('Spotify automation', style: theme.textTheme.headlineSmall),
        const SizedBox(height: 6),
        Text(
          'Windows 11 scope: connect Spotify, bind the desktop device, test routine playback, then sync scheduled tasks.',
          style: theme.textTheme.bodyMedium,
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_statusMessage!, style: theme.textTheme.bodyLarge),
            ),
          ),
        ],
        const SizedBox(height: 16),
        _ConnectionCard(
          clientIdController: _clientIdController,
          redirectPortController: _redirectPortController,
          connectedUserDisplayName: _settings.connectedUserDisplayName,
          defaultDeviceName: _settings.defaultDeviceName,
          defaultDeviceType: _settings.defaultDeviceType,
          isBusy: _isBusy,
          onSave: _saveSettingsOnly,
          onConnect: _connectSpotify,
          onRefreshDevices: _refreshDevices,
        ),
        const SizedBox(height: 16),
        _ScheduleCard(isBusy: _isBusy, onSyncSchedules: _syncSchedules),
        const SizedBox(height: 16),
        _DevicesCard(
          devices: _devices,
          isBusy: _isBusy,
          onUseDefault: _setDefaultDevice,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Routine actions', style: theme.textTheme.headlineSmall),
                const SizedBox(height: 8),
                if (spotifyRoutines.isEmpty)
                  Text(
                    'No routines have Spotify automation enabled yet.',
                    style: theme.textTheme.bodyMedium,
                  )
                else
                  ...spotifyRoutines.map(
                    (task) => _RoutineSpotifyCard(
                      task: task,
                      onTestPressed: _isBusy ? null : () => _testRoutine(task),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.clientIdController,
    required this.redirectPortController,
    required this.connectedUserDisplayName,
    required this.defaultDeviceName,
    required this.defaultDeviceType,
    required this.isBusy,
    required this.onSave,
    required this.onConnect,
    required this.onRefreshDevices,
  });

  final TextEditingController clientIdController;
  final TextEditingController redirectPortController;
  final String? connectedUserDisplayName;
  final String? defaultDeviceName;
  final String? defaultDeviceType;
  final bool isBusy;
  final VoidCallback onSave;
  final VoidCallback onConnect;
  final VoidCallback onRefreshDevices;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final redirectPort = redirectPortController.text.trim().isEmpty
        ? '43821'
        : redirectPortController.text.trim();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Connection', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 12),
            TextField(
              controller: clientIdController,
              decoration: const InputDecoration(
                labelText: 'Spotify client ID',
                hintText: 'Paste the app client ID from Spotify Dashboard',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: redirectPortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Redirect port'),
            ),
            const SizedBox(height: 12),
            SelectableText(
              'Redirect URI: http://127.0.0.1:$redirectPort/spotify/callback',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: isBusy ? null : onSave,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save settings'),
                ),
                FilledButton.icon(
                  onPressed: isBusy ? null : onConnect,
                  icon: const Icon(Icons.link),
                  label: const Text('Connect Spotify'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onRefreshDevices,
                  icon: const Icon(Icons.speaker_group_outlined),
                  label: const Text('Refresh devices'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Connected user: ${connectedUserDisplayName ?? '-'}',
              style: theme.textTheme.bodyLarge,
            ),
            Text(
              'Default device: ${defaultDeviceName ?? '-'} (${defaultDeviceType ?? '-'})',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  const _ScheduleCard({required this.isBusy, required this.onSyncSchedules});

  final bool isBusy;
  final VoidCallback onSyncSchedules;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Win11 schedules', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Creates daily Scheduled Tasks for routines that have Spotify autoplay enabled and a fixed HH:mm time.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: isBusy ? null : onSyncSchedules,
              icon: const Icon(Icons.schedule_send_outlined),
              label: const Text('Sync Win11 tasks'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DevicesCard extends StatelessWidget {
  const _DevicesCard({
    required this.devices,
    required this.isBusy,
    required this.onUseDefault,
  });

  final List<SpotifyDevice> devices;
  final bool isBusy;
  final ValueChanged<SpotifyDevice> onUseDefault;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Devices', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            if (devices.isEmpty)
              Text(
                'No devices loaded yet. Use Refresh devices after Spotify is running on Windows.',
                style: theme.textTheme.bodyMedium,
              )
            else
              ...devices.map(
                (device) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(device.name),
                  subtitle: Text(
                    '${device.type} | active ${device.isActive ? 'yes' : 'no'} | restricted ${device.isRestricted ? 'yes' : 'no'}',
                  ),
                  trailing: OutlinedButton(
                    onPressed: isBusy ? null : () => onUseDefault(device),
                    child: const Text('Use default'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoutineSpotifyCard extends StatelessWidget {
  const _RoutineSpotifyCard({required this.task, required this.onTestPressed});

  final RoutineTask task;
  final VoidCallback? onTestPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final action = task.spotifyAction!;
    final playlist = action.candidatePlaylists.isEmpty
        ? null
        : action.candidatePlaylists.first;

    return Card(
      margin: const EdgeInsets.only(top: 12),
      elevation: 0,
      color: const Color(0xFFF8FAF8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFD8E2DC)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(task.title, style: theme.textTheme.titleMedium),
                ),
                FilledButton(
                  onPressed: onTestPressed,
                  child: const Text('Test play'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${task.time} | mode ${action.mode} | autoplay ${action.autoPlay ? 'on' : 'off'}',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Device ${action.preferredDeviceName} (${action.preferredDeviceType}) | volume ${action.volumePercent}%',
              style: theme.textTheme.bodyMedium,
            ),
            if (playlist != null) ...[
              const SizedBox(height: 4),
              Text(
                'Playlist ${playlist.label} | ${playlist.uri}',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
