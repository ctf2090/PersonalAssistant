import 'dart:io';

import 'package:flutter/material.dart';

import 'assistant_models.dart';
import 'openai_playlist_service.dart';
import 'spotify_auth_service.dart';
import 'spotify_automation_runner.dart';
import 'spotify_device_service.dart';
import 'spotify_playback_service.dart';
import 'spotify_playlist_service.dart';
import 'spotify_settings.dart';
import 'spotify_settings_repository.dart';
import 'spotify_track_service.dart';
import 'windows_spotify_launcher_service.dart';
import 'windows_schedule_service.dart';

const String _defaultOpenAiPlaylistModel = 'gpt-4.1-mini';

class SpotifyAutomationView extends StatefulWidget {
  const SpotifyAutomationView({super.key, required this.workspace});

  final AssistantWorkspaceData workspace;

  @override
  State<SpotifyAutomationView> createState() => _SpotifyAutomationViewState();
}

class _SpotifyAutomationViewState extends State<SpotifyAutomationView> {
  final OpenAiPlaylistService _openAiPlaylistService = OpenAiPlaylistService();
  final SpotifyAuthService _authService = SpotifyAuthService();
  final SpotifyDeviceService _deviceService = SpotifyDeviceService();
  final SpotifyAutomationRunner _automationRunner = SpotifyAutomationRunner();
  final SpotifyPlaybackService _playbackService = SpotifyPlaybackService();
  final SpotifyPlaylistService _playlistService = SpotifyPlaylistService();
  final SpotifyTrackService _trackService = SpotifyTrackService();
  final WindowsSpotifyLauncherService _spotifyLauncher =
      const WindowsSpotifyLauncherService();
  final WindowsScheduleService _scheduleService =
      const WindowsScheduleService();

  final TextEditingController _clientIdController = TextEditingController();
  final TextEditingController _openAiApiKeyController = TextEditingController();
  final TextEditingController _openAiModelController = TextEditingController();
  final TextEditingController _playlistPromptController =
      TextEditingController();
  final TextEditingController _redirectPortController = TextEditingController();

  SpotifyAutomationSettings _settings = SpotifyAutomationSettings.empty();
  List<SpotifyDevice> _devices = const <SpotifyDevice>[];
  List<SpotifyPlaylistSummary> _playlists = const <SpotifyPlaylistSummary>[];
  OpenAiPlaylistPlan? _generatedPlan;
  List<_ResolvedGeneratedTrack> _resolvedGeneratedTracks =
      const <_ResolvedGeneratedTrack>[];
  List<OpenAiPlaylistTrackCandidate> _unresolvedGeneratedTracks =
      const <OpenAiPlaylistTrackCandidate>[];
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
    _openAiApiKeyController.dispose();
    _openAiModelController.dispose();
    _playlistPromptController.dispose();
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
      _openAiApiKeyController.text = settings.openAiApiKey ?? '';
      _openAiModelController.text =
          settings.openAiModel ?? _defaultOpenAiPlaylistModel;
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
      openAiApiKey: _openAiApiKeyController.text.trim(),
      openAiModel: _resolvedOpenAiModel,
      redirectPort: int.tryParse(_redirectPortController.text.trim()) ?? 43821,
    );
  }

  String get _resolvedOpenAiModel {
    final value = _openAiModelController.text.trim();
    return value.isEmpty ? _defaultOpenAiPlaylistModel : value;
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

  Future<void> _refreshPlaylists() async {
    await _runBusyTask(() async {
      var refreshed = await _authService.ensureValidSession(_draftSettings());
      refreshed = await saveSpotifyAutomationSettings(refreshed);
      final playlists = await _playlistService.listCurrentUserPlaylists(
        refreshed.accessToken!,
      );
      var updatedSettings = refreshed;
      if (playlists.isNotEmpty &&
          (refreshed.defaultPlaylistUri ?? '').trim().isEmpty) {
        final first = playlists.first;
        updatedSettings = refreshed.copyWith(
          defaultPlaylistUri: first.uri,
          defaultPlaylistLabel: first.name,
        );
        updatedSettings = await saveSpotifyAutomationSettings(updatedSettings);
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = updatedSettings;
        _playlists = playlists;
        _statusMessage = 'Loaded ${playlists.length} Spotify playlist(s).';
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

  Future<void> _setDefaultPlaylist(String playlistUri) async {
    await _runBusyTask(() async {
      SpotifyPlaylistSummary? selected;
      for (final playlist in _playlists) {
        if (playlist.uri == playlistUri) {
          selected = playlist;
          break;
        }
      }
      if (selected == null) {
        throw StateError('Selected Spotify playlist was not found.');
      }
      final saved = await saveSpotifyAutomationSettings(
        _settings.copyWith(
          defaultPlaylistUri: selected.uri,
          defaultPlaylistLabel: selected.name,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = saved;
        _statusMessage = 'Default playlist set to ${selected!.name}.';
      });
    });
  }

  Future<void> _generateAiPlaylistPreview() async {
    await _runBusyTask(() async {
      var saved = await saveSpotifyAutomationSettings(_draftSettings());
      final apiKey = (saved.openAiApiKey ?? '').trim();
      final prompt = _playlistPromptController.text.trim();
      if (apiKey.isEmpty) {
        throw StateError('OpenAI API key is required before generating.');
      }
      if (prompt.isEmpty) {
        throw StateError('Playlist prompt is required before generating.');
      }
      saved = await _authService.ensureValidSession(saved);
      final plan = await _openAiPlaylistService.generatePlaylistPlan(
        apiKey: apiKey,
        model: saved.openAiModel ?? _defaultOpenAiPlaylistModel,
        prompt: prompt,
        targetTrackCount: 12,
      );
      final resolved = <_ResolvedGeneratedTrack>[];
      final unresolved = <OpenAiPlaylistTrackCandidate>[];
      for (final candidate in plan.tracks) {
        final track = await _trackService.searchTopTrack(
          accessToken: saved.accessToken!,
          title: candidate.title,
          artist: candidate.artist,
        );
        if (track == null) {
          unresolved.add(candidate);
          continue;
        }
        resolved.add(
          _ResolvedGeneratedTrack(candidate: candidate, track: track),
        );
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = saved;
        _generatedPlan = plan;
        _resolvedGeneratedTracks = resolved;
        _unresolvedGeneratedTracks = unresolved;
        _statusMessage =
            'Generated "${plan.title}" with ${resolved.length} matched Spotify track(s).';
      });
    });
  }

  Future<void> _createSpotifyAiPlaylist() async {
    await _runBusyTask(() async {
      final plan = _generatedPlan;
      if (plan == null) {
        throw StateError('Generate an AI playlist preview first.');
      }
      if (_resolvedGeneratedTracks.isEmpty) {
        throw StateError('No matched Spotify tracks are available to save.');
      }
      var saved = await saveSpotifyAutomationSettings(_draftSettings());
      saved = await _authService.ensureValidSession(saved);
      final created = await _trackService.createPlaylist(
        accessToken: saved.accessToken!,
        name: plan.title,
        description: _buildAiPlaylistDescription(plan),
      );
      await _trackService.addTracksToPlaylist(
        accessToken: saved.accessToken!,
        playlistId: created.id,
        trackUris: _resolvedGeneratedTracks
            .map((item) => item.track.uri)
            .toList(),
      );
      saved = await saveSpotifyAutomationSettings(
        saved.copyWith(
          defaultPlaylistUri: created.uri,
          defaultPlaylistLabel: created.name,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = saved;
        _playlists = <SpotifyPlaylistSummary>[
          SpotifyPlaylistSummary(
            id: created.id,
            uri: created.uri,
            name: created.name,
            ownerName: saved.connectedUserDisplayName ?? 'You',
            trackCount: _resolvedGeneratedTracks.length,
          ),
          ..._playlists.where((playlist) => playlist.id != created.id),
        ];
        _statusMessage =
            'Created Spotify playlist "${created.name}" with ${_resolvedGeneratedTracks.length} track(s).';
      });
    });
  }

  String _buildAiPlaylistDescription(OpenAiPlaylistPlan plan) {
    final tags = plan.moodTags.isEmpty
        ? ''
        : ' Tags: ${plan.moodTags.join(', ')}.';
    final description = plan.description.trim();
    return 'Generated by PA AI. $description$tags'.trim();
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

  Future<void> _testDefaultPlaylist() async {
    await _runBusyTask(() async {
      var saved = await saveSpotifyAutomationSettings(_draftSettings());
      final playlistUri = (saved.defaultPlaylistUri ?? '').trim();
      if (playlistUri.isEmpty) {
        throw StateError('Default playlist URI is required before testing.');
      }
      saved = await _authService.ensureValidSession(saved);
      final targetDevice = await _resolveDefaultPlaybackDevice(saved);
      if (targetDevice == null) {
        throw StateError('No controllable Spotify device was available.');
      }
      final action = SpotifyAction(
        enabled: true,
        autoPlay: true,
        mode: 'default_test',
        preferredDeviceName: saved.defaultDeviceName ?? targetDevice.name,
        preferredDeviceType: saved.defaultDeviceType ?? targetDevice.type,
        volumePercent: 30,
        retryCount: 1,
        retryDelaySeconds: 0,
        candidatePlaylists: [
          SpotifyPlaylistCandidate(
            uri: playlistUri,
            label: (saved.defaultPlaylistLabel ?? '').trim().isEmpty
                ? 'Default playlist'
                : saved.defaultPlaylistLabel!,
            tags: const ['test'],
            priority: 100,
          ),
        ],
      );
      await _playbackService.playRoutineAction(
        accessToken: saved.accessToken!,
        action: action,
        targetDevice: targetDevice,
      );
      saved = await saveSpotifyAutomationSettings(
        saved.copyWith(
          defaultDeviceName: targetDevice.name,
          defaultDeviceType: targetDevice.type,
        ),
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = saved;
        _statusMessage = 'Triggered default playlist test playback.';
      });
    });
  }

  Future<SpotifyDevice?> _resolveDefaultPlaybackDevice(
    SpotifyAutomationSettings settings,
  ) async {
    var devices = await _deviceService.listDevices(settings.accessToken!);
    var targetDevice = _deviceService.resolvePreferredDevice(
      devices: devices,
      preferredName: settings.defaultDeviceName,
      preferredType: settings.defaultDeviceType,
    );
    if (targetDevice != null) {
      return targetDevice;
    }

    await _spotifyLauncher.ensureStarted();

    for (var attempt = 0; attempt < 5; attempt++) {
      await Future<void>.delayed(const Duration(seconds: 2));
      devices = await _deviceService.listDevices(settings.accessToken!);
      targetDevice = _deviceService.resolvePreferredDevice(
        devices: devices,
        preferredName: settings.defaultDeviceName,
        preferredType: settings.defaultDeviceType,
      );
      if (targetDevice != null) {
        return targetDevice;
      }
    }
    return null;
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
          openAiApiKeyController: _openAiApiKeyController,
          openAiModelController: _openAiModelController,
          redirectPortController: _redirectPortController,
          connectedUserDisplayName: _settings.connectedUserDisplayName,
          defaultDeviceName: _settings.defaultDeviceName,
          defaultDeviceType: _settings.defaultDeviceType,
          playlists: _playlists,
          selectedPlaylistUri: _resolveSelectedPlaylistUri(),
          selectedPlaylistLabel: _settings.defaultPlaylistLabel,
          isBusy: _isBusy,
          onSave: _saveSettingsOnly,
          onConnect: _connectSpotify,
          onRefreshDevices: _refreshDevices,
          onRefreshPlaylists: _refreshPlaylists,
          onSelectPlaylist: _setDefaultPlaylist,
          onTestDefaultPlaylist: _testDefaultPlaylist,
        ),
        const SizedBox(height: 16),
        _AiPlaylistCard(
          promptController: _playlistPromptController,
          generatedPlan: _generatedPlan,
          resolvedTracks: _resolvedGeneratedTracks,
          unresolvedTracks: _unresolvedGeneratedTracks,
          isBusy: _isBusy,
          onGenerate: _generateAiPlaylistPreview,
          onCreatePlaylist: _createSpotifyAiPlaylist,
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

  String? _resolveSelectedPlaylistUri() {
    final current = (_settings.defaultPlaylistUri ?? '').trim();
    if (current.isEmpty) {
      return null;
    }
    for (final playlist in _playlists) {
      if (playlist.uri == current) {
        return current;
      }
    }
    return null;
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({
    required this.clientIdController,
    required this.openAiApiKeyController,
    required this.openAiModelController,
    required this.redirectPortController,
    required this.connectedUserDisplayName,
    required this.defaultDeviceName,
    required this.defaultDeviceType,
    required this.playlists,
    required this.selectedPlaylistUri,
    required this.selectedPlaylistLabel,
    required this.isBusy,
    required this.onSave,
    required this.onConnect,
    required this.onRefreshDevices,
    required this.onRefreshPlaylists,
    required this.onSelectPlaylist,
    required this.onTestDefaultPlaylist,
  });

  final TextEditingController clientIdController;
  final TextEditingController openAiApiKeyController;
  final TextEditingController openAiModelController;
  final TextEditingController redirectPortController;
  final String? connectedUserDisplayName;
  final String? defaultDeviceName;
  final String? defaultDeviceType;
  final List<SpotifyPlaylistSummary> playlists;
  final String? selectedPlaylistUri;
  final String? selectedPlaylistLabel;
  final bool isBusy;
  final VoidCallback onSave;
  final VoidCallback onConnect;
  final VoidCallback onRefreshDevices;
  final VoidCallback onRefreshPlaylists;
  final ValueChanged<String> onSelectPlaylist;
  final VoidCallback onTestDefaultPlaylist;

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
              controller: openAiApiKeyController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'OpenAI API key',
                hintText: 'sk-...',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: openAiModelController,
              decoration: const InputDecoration(
                labelText: 'OpenAI model',
                hintText: _defaultOpenAiPlaylistModel,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: redirectPortController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Redirect port'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: selectedPlaylistUri,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Default test playlist',
              ),
              hint: const Text('Refresh playlists, then choose one'),
              items: [
                for (final playlist in playlists)
                  DropdownMenuItem(
                    value: playlist.uri,
                    child: Text(
                      '${playlist.name} (${playlist.trackCount})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: isBusy
                  ? null
                  : (value) {
                      if (value == null) {
                        return;
                      }
                      onSelectPlaylist(value);
                    },
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
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onRefreshPlaylists,
                  icon: const Icon(Icons.queue_music_outlined),
                  label: const Text('Refresh playlists'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy ? null : onTestDefaultPlaylist,
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Test default playlist'),
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
            Text(
              'Default playlist: ${selectedPlaylistLabel ?? '-'}',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _AiPlaylistCard extends StatelessWidget {
  const _AiPlaylistCard({
    required this.promptController,
    required this.generatedPlan,
    required this.resolvedTracks,
    required this.unresolvedTracks,
    required this.isBusy,
    required this.onGenerate,
    required this.onCreatePlaylist,
  });

  final TextEditingController promptController;
  final OpenAiPlaylistPlan? generatedPlan;
  final List<_ResolvedGeneratedTrack> resolvedTracks;
  final List<OpenAiPlaylistTrackCandidate> unresolvedTracks;
  final bool isBusy;
  final VoidCallback onGenerate;
  final VoidCallback onCreatePlaylist;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI playlist', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Describe the playlist you want. PA will ask OpenAI for candidate songs, resolve them on Spotify, then let you save the result as a playlist.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: promptController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Playlist prompt',
                hintText:
                    'Example: soft morning wake-up songs, warm female vocals, gentle indie pop, not too sad.',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: isBusy ? null : onGenerate,
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Generate preview'),
                ),
                OutlinedButton.icon(
                  onPressed: isBusy || resolvedTracks.isEmpty
                      ? null
                      : onCreatePlaylist,
                  icon: const Icon(Icons.playlist_add),
                  label: const Text('Create Spotify playlist'),
                ),
              ],
            ),
            if (generatedPlan != null) ...[
              const SizedBox(height: 16),
              Text(generatedPlan!.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text(
                generatedPlan!.description,
                style: theme.textTheme.bodyMedium,
              ),
              if (generatedPlan!.moodTags.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in generatedPlan!.moodTags)
                      Chip(label: Text(tag)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'Matched tracks (${resolvedTracks.length})',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (resolvedTracks.isEmpty)
                Text(
                  'No Spotify tracks matched yet.',
                  style: theme.textTheme.bodyMedium,
                )
              else
                ...resolvedTracks.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(item.track.name),
                    subtitle: Text(
                      '${item.track.subtitle}\nAI: ${item.candidate.reason}',
                    ),
                    isThreeLine: true,
                  ),
                ),
              if (unresolvedTracks.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Unmatched AI suggestions (${unresolvedTracks.length})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...unresolvedTracks.map(
                  (item) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('${item.title} - ${item.artist}'),
                    subtitle: Text(item.reason),
                  ),
                ),
              ],
            ],
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
              'Device ${action.preferredDeviceName} (${action.preferredDeviceType}) | keep current volume',
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

class _ResolvedGeneratedTrack {
  const _ResolvedGeneratedTrack({required this.candidate, required this.track});

  final OpenAiPlaylistTrackCandidate candidate;
  final SpotifyResolvedTrack track;
}
