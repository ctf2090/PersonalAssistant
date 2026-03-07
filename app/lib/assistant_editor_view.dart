import 'dart:convert';

import 'package:flutter/material.dart';

import 'assistant_models.dart';
import 'assistant_workspace_repository.dart';

enum AssistantEditorMode { form, raw }

class AssistantEditorView extends StatefulWidget {
  const AssistantEditorView({
    super.key,
    required this.workspace,
    required this.onWorkspaceChanged,
  });

  final AssistantWorkspaceData workspace;
  final ValueChanged<AssistantWorkspaceData> onWorkspaceChanged;

  @override
  State<AssistantEditorView> createState() => _AssistantEditorViewState();
}

class _AssistantEditorViewState extends State<AssistantEditorView> {
  late final TextEditingController _mdsController;
  late final TextEditingController _mdrController;
  late Map<String, dynamic> _mdsDraft;
  late Map<String, dynamic> _mdrDraft;
  AssistantDocumentType _selectedDocument = AssistantDocumentType.mds;
  AssistantEditorMode _editorMode = AssistantEditorMode.form;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _mdsController = TextEditingController(text: widget.workspace.mdsJson);
    _mdrController = TextEditingController(text: widget.workspace.mdrJson);
    _mdsDraft = _decodeDraft(widget.workspace.mdsJson, 'MDS');
    _mdrDraft = _decodeDraft(widget.workspace.mdrJson, 'MDR');
  }

  @override
  void didUpdateWidget(covariant AssistantEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.mdsJson != widget.workspace.mdsJson) {
      _mdsController.text = widget.workspace.mdsJson;
      _mdsDraft = _decodeDraft(widget.workspace.mdsJson, 'MDS');
    }
    if (oldWidget.workspace.mdrJson != widget.workspace.mdrJson) {
      _mdrController.text = widget.workspace.mdrJson;
      _mdrDraft = _decodeDraft(widget.workspace.mdrJson, 'MDR');
    }
  }

  @override
  void dispose() {
    _mdsController.dispose();
    _mdrController.dispose();
    super.dispose();
  }

  TextEditingController get _currentController =>
      _selectedDocument == AssistantDocumentType.mds
      ? _mdsController
      : _mdrController;

  String? get _currentPath => _selectedDocument == AssistantDocumentType.mds
      ? widget.workspace.mdsPath
      : widget.workspace.mdrPath;

  Map<String, dynamic> _decodeDraft(String source, String label) {
    return jsonDecode(jsonEncode(decodeJsonObject(source, label: label)))
        as Map<String, dynamic>;
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
        _showMessage('$error');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _syncRawFromDraft(AssistantDocumentType documentType) {
    final draft = documentType == AssistantDocumentType.mds
        ? _mdsDraft
        : _mdrDraft;
    final formatted = formatJsonObject(draft);
    final controller = documentType == AssistantDocumentType.mds
        ? _mdsController
        : _mdrController;
    controller
      ..text = formatted
      ..selection = TextSelection.collapsed(offset: formatted.length);
  }

  void _replaceDraft(
    AssistantDocumentType documentType,
    Map<String, dynamic> draft,
  ) {
    setState(() {
      if (documentType == AssistantDocumentType.mds) {
        _mdsDraft = draft;
      } else {
        _mdrDraft = draft;
      }
      _syncRawFromDraft(documentType);
    });
  }

  Future<void> _switchEditorMode(AssistantEditorMode mode) async {
    if (mode == _editorMode) {
      return;
    }
    if (mode == AssistantEditorMode.form) {
      try {
        final parsed = _decodeDraft(
          _currentController.text,
          _selectedDocument.label,
        );
        setState(() {
          if (_selectedDocument == AssistantDocumentType.mds) {
            _mdsDraft = parsed;
          } else {
            _mdrDraft = parsed;
          }
          _editorMode = mode;
        });
      } catch (error) {
        _showMessage('$error');
      }
      return;
    }
    setState(() {
      _editorMode = mode;
    });
  }

  void _validateCurrent() {
    try {
      decodeJsonObject(_currentController.text, label: _selectedDocument.label);
      _showMessage('${_selectedDocument.label} JSON is valid.');
    } catch (error) {
      _showMessage('$error');
    }
  }

  void _formatCurrent() {
    try {
      final formatted = formatJsonSource(_currentController.text);
      _currentController
        ..text = formatted
        ..selection = TextSelection.collapsed(offset: formatted.length);
      if (_selectedDocument == AssistantDocumentType.mds) {
        _mdsDraft = _decodeDraft(formatted, 'MDS');
      } else {
        _mdrDraft = _decodeDraft(formatted, 'MDR');
      }
      _showMessage('${_selectedDocument.label} JSON formatted.');
    } catch (error) {
      _showMessage('$error');
    }
  }

  Future<void> _saveAll() async {
    await _runBusyTask(() async {
      final workspace = await saveAssistantWorkspaceData(
        mdsJson: _mdsController.text,
        mdrJson: _mdrController.text,
      );
      if (!mounted) {
        return;
      }
      widget.onWorkspaceChanged(workspace);
      _showMessage('Saved MDS and MDR to the root data folder.');
    });
  }

  Future<void> _reloadFromDisk() async {
    await _runBusyTask(() async {
      final workspace = await reloadAssistantWorkspaceData();
      if (!mounted) {
        return;
      }
      widget.onWorkspaceChanged(workspace);
      _showMessage('Reloaded MDS and MDR from disk.');
    });
  }

  Future<void> _importCurrent() async {
    await _runBusyTask(() async {
      final imported = await importAssistantDocument(_selectedDocument);
      if (!mounted || imported == null) {
        return;
      }
      final formatted = formatJsonSource(imported);
      _currentController
        ..text = formatted
        ..selection = TextSelection.collapsed(offset: formatted.length);
      setState(() {
        if (_selectedDocument == AssistantDocumentType.mds) {
          _mdsDraft = _decodeDraft(formatted, 'MDS');
        } else {
          _mdrDraft = _decodeDraft(formatted, 'MDR');
        }
      });
      _showMessage(
        'Imported ${_selectedDocument.label} into the editor. Save All to persist it.',
      );
    });
  }

  Future<void> _exportCurrent() async {
    await _runBusyTask(() async {
      final formatted = formatJsonSource(_currentController.text);
      await exportAssistantDocument(
        type: _selectedDocument,
        content: formatted,
      );
      if (!mounted) {
        return;
      }
      _showMessage('Exported ${_selectedDocument.label} JSON.');
    });
  }

  List<Map<String, dynamic>> _listOfMaps(
    Map<String, dynamic> parent,
    String key,
  ) {
    final list = parent[key] as List<dynamic>? ?? const <dynamic>[];
    return list.map((item) => (item as Map).cast<String, dynamic>()).toList();
  }

  Map<String, dynamic> _mapValue(Map<String, dynamic> parent, String key) {
    final value = parent[key];
    if (value is Map<String, dynamic>) {
      return value;
    }
    if (value is Map) {
      return value.cast<String, dynamic>();
    }
    return <String, dynamic>{};
  }

  List<String> _stringList(Object? value) {
    final list = value as List<dynamic>? ?? const <dynamic>[];
    return list.map((item) => '$item').toList();
  }

  List<String> _splitCommaValues(String source) {
    return source
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Future<Map<String, dynamic>?> _openObjectEditor({
    required String title,
    required List<_EditorFieldSpec> fields,
    required Map<String, dynamic> initialValue,
  }) {
    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _ObjectEditorDialog(
        title: title,
        fields: fields,
        initialValue: initialValue,
      ),
    );
  }

  Widget _buildFormEditor() {
    return _selectedDocument == AssistantDocumentType.mds
        ? _buildMdsForm()
        : _buildMdrForm();
  }

  Future<void> _editMeta(AssistantDocumentType type) async {
    final draft = Map<String, dynamic>.from(
      type == AssistantDocumentType.mds ? _mdsDraft : _mdrDraft,
    );
    final meta = Map<String, dynamic>.from(_mapValue(draft, 'meta'));
    final updated = await _openObjectEditor(
      title: 'Edit ${type.label} metadata',
      fields: const [
        _EditorFieldSpec('name', 'Short name'),
        _EditorFieldSpec('fullName', 'Full name'),
        _EditorFieldSpec('source', 'Source'),
        _EditorFieldSpec('updatedAt', 'Updated at'),
        _EditorFieldSpec('recoveryNote', 'Recovery note', maxLines: 4),
      ],
      initialValue: meta,
    );
    if (updated == null) {
      return;
    }
    draft['meta'] = updated;
    _replaceDraft(type, draft);
  }

  Future<void> _editMdsItem([int? index]) async {
    final items = _listOfMaps(_mdsDraft, 'items');
    final initial = index == null
        ? <String, dynamic>{
            'code': '',
            'name': '',
            'productCode': '',
            'category': '',
            'time': '',
            'mealTiming': '',
            'details': '',
            'status': 'scheduled',
          }
        : Map<String, dynamic>.from(items[index]);
    final updated = await _openObjectEditor(
      title: index == null ? 'Add supplement' : 'Edit supplement',
      fields: const [
        _EditorFieldSpec('code', 'Code'),
        _EditorFieldSpec('name', 'Name'),
        _EditorFieldSpec('productCode', 'Product code'),
        _EditorFieldSpec('category', 'Category'),
        _EditorFieldSpec('time', 'Time'),
        _EditorFieldSpec('mealTiming', 'Meal timing'),
        _EditorFieldSpec('status', 'Status', options: _statusNames),
        _EditorFieldSpec('details', 'Details', maxLines: 4),
      ],
      initialValue: initial,
    );
    if (updated == null) {
      return;
    }
    updated['productCode'] = _nullableValue(updated['productCode']);
    updated['time'] = _nullableValue(updated['time']);
    updated['details'] = _nullableValue(updated['details']);
    if (index == null) {
      items.add(updated);
    } else {
      items[index] = updated;
    }
    final draft = Map<String, dynamic>.from(_mdsDraft);
    draft['items'] = items;
    _replaceDraft(AssistantDocumentType.mds, draft);
  }

  void _deleteMdsItem(int index) {
    final items = _listOfMaps(_mdsDraft, 'items');
    items.removeAt(index);
    final draft = Map<String, dynamic>.from(_mdsDraft);
    draft['items'] = items;
    _replaceDraft(AssistantDocumentType.mds, draft);
  }

  Future<void> _editMdsSet([String? existingName]) async {
    final sets = Map<String, dynamic>.from(_mapValue(_mdsDraft, 'sets'));
    final initialItems = existingName == null
        ? ''
        : _stringList(sets[existingName]).join(', ');
    final updated = await _openObjectEditor(
      title: existingName == null
          ? 'Add supplement set'
          : 'Edit supplement set',
      fields: const [
        _EditorFieldSpec('name', 'Set name'),
        _EditorFieldSpec('items', 'Items (comma separated)', maxLines: 3),
      ],
      initialValue: <String, dynamic>{
        'name': existingName ?? '',
        'items': initialItems,
      },
    );
    if (updated == null) {
      return;
    }
    final oldName = existingName?.trim();
    final newName = '${updated['name'] ?? ''}'.trim();
    if (newName.isEmpty) {
      _showMessage('Set name cannot be empty.');
      return;
    }
    final items = _splitCommaValues('${updated['items'] ?? ''}');
    if (oldName != null && oldName != newName) {
      sets.remove(oldName);
    }
    sets[newName] = items;
    final draft = Map<String, dynamic>.from(_mdsDraft);
    draft['sets'] = sets;
    _replaceDraft(AssistantDocumentType.mds, draft);
  }

  void _deleteMdsSet(String name) {
    final sets = Map<String, dynamic>.from(_mapValue(_mdsDraft, 'sets'));
    sets.remove(name);
    final draft = Map<String, dynamic>.from(_mdsDraft);
    draft['sets'] = sets;
    _replaceDraft(AssistantDocumentType.mds, draft);
  }

  Future<void> _editMdrDashboard() async {
    final draft = Map<String, dynamic>.from(_mdrDraft);
    final dashboard = Map<String, dynamic>.from(_mapValue(draft, 'dashboard'));
    final updated = await _openObjectEditor(
      title: 'Edit dashboard',
      fields: const [
        _EditorFieldSpec('nextItemTime', 'Next item time'),
        _EditorFieldSpec('bedtimeTarget', 'Bedtime target'),
        _EditorFieldSpec(
          'adherencePercent',
          'Adherence percent',
          kind: _EditorFieldKind.number,
        ),
        _EditorFieldSpec(
          'pendingCount',
          'Pending count',
          kind: _EditorFieldKind.number,
        ),
        _EditorFieldSpec('focusWindow', 'Focus window'),
      ],
      initialValue: dashboard,
    );
    if (updated == null) {
      return;
    }
    draft['dashboard'] = updated;
    _replaceDraft(AssistantDocumentType.mdr, draft);
  }

  Future<void> _editMdrTimeline([int? index]) async {
    final timeline = _listOfMaps(_mdrDraft, 'timeline');
    final initial = index == null
        ? <String, dynamic>{
            'title': '',
            'note': '',
            'time': '',
            'icon': 'event_note',
            'status': 'scheduled',
          }
        : Map<String, dynamic>.from(timeline[index]);
    final updated = await _openObjectEditor(
      title: index == null ? 'Add timeline item' : 'Edit timeline item',
      fields: const [
        _EditorFieldSpec('title', 'Title'),
        _EditorFieldSpec('time', 'Time'),
        _EditorFieldSpec('icon', 'Icon', options: _iconNames),
        _EditorFieldSpec('status', 'Status', options: _statusNames),
        _EditorFieldSpec('note', 'Note', maxLines: 4),
      ],
      initialValue: initial,
    );
    if (updated == null) {
      return;
    }
    if (index == null) {
      timeline.add(updated);
    } else {
      timeline[index] = updated;
    }
    final draft = Map<String, dynamic>.from(_mdrDraft);
    draft['timeline'] = timeline;
    _replaceDraft(AssistantDocumentType.mdr, draft);
  }

  void _deleteMdrTimeline(int index) {
    final timeline = _listOfMaps(_mdrDraft, 'timeline');
    timeline.removeAt(index);
    final draft = Map<String, dynamic>.from(_mdrDraft);
    draft['timeline'] = timeline;
    _replaceDraft(AssistantDocumentType.mdr, draft);
  }

  Future<void> _editMdrRoutine([int? index]) async {
    final routine = _listOfMaps(_mdrDraft, 'routine');
    final spotifyAction = index == null
        ? const <String, dynamic>{}
        : _mapValue(routine[index], 'spotifyAction');
    final firstPlaylist = _firstSpotifyPlaylist(spotifyAction);
    final initial = index == null
        ? <String, dynamic>{
            'title': '',
            'time': '',
            'period': 'day',
            'icon': 'event_note',
            'status': 'scheduled',
            'note': '',
            'relatedCodes': '',
            'spotifyEnabled': 'false',
            'spotifyAutoPlay': 'true',
            'spotifyMode': '',
            'spotifyPreferredDeviceName': '',
            'spotifyPreferredDeviceType': 'computer',
            'spotifyVolumePercent': 25,
            'spotifyRetryCount': 3,
            'spotifyRetryDelaySeconds': 15,
            'spotifyStartMode': 'resumeOrPlay',
            'spotifyPlaylistUri': '',
            'spotifyPlaylistLabel': '',
            'spotifyPlaylistTags': '',
            'spotifyPlaylistPriority': 100,
          }
        : <String, dynamic>{
            ...routine[index],
            'relatedCodes': _stringList(
              routine[index]['relatedCodes'],
            ).join(', '),
            'spotifyEnabled': '${spotifyAction['enabled'] ?? false}',
            'spotifyAutoPlay': '${spotifyAction['autoPlay'] ?? true}',
            'spotifyMode': '${spotifyAction['mode'] ?? ''}',
            'spotifyPreferredDeviceName':
                '${spotifyAction['preferredDeviceName'] ?? ''}',
            'spotifyPreferredDeviceType':
                '${spotifyAction['preferredDeviceType'] ?? 'computer'}',
            'spotifyVolumePercent': spotifyAction['volumePercent'] ?? 25,
            'spotifyRetryCount': spotifyAction['retryCount'] ?? 3,
            'spotifyRetryDelaySeconds':
                spotifyAction['retryDelaySeconds'] ?? 15,
            'spotifyStartMode':
                '${spotifyAction['startMode'] ?? 'resumeOrPlay'}',
            'spotifyPlaylistUri': '${firstPlaylist['uri'] ?? ''}',
            'spotifyPlaylistLabel': '${firstPlaylist['label'] ?? ''}',
            'spotifyPlaylistTags': _stringList(
              firstPlaylist['tags'],
            ).join(', '),
            'spotifyPlaylistPriority': firstPlaylist['priority'] ?? 100,
          };
    final updated = await _openObjectEditor(
      title: index == null ? 'Add routine item' : 'Edit routine item',
      fields: const [
        _EditorFieldSpec('title', 'Title'),
        _EditorFieldSpec('time', 'Time'),
        _EditorFieldSpec('period', 'Period', options: _periodNames),
        _EditorFieldSpec('icon', 'Icon', options: _iconNames),
        _EditorFieldSpec('status', 'Status', options: _statusNames),
        _EditorFieldSpec(
          'relatedCodes',
          'Related codes (comma separated)',
          maxLines: 2,
        ),
        _EditorFieldSpec('note', 'Note', maxLines: 4),
        _EditorFieldSpec(
          'spotifyEnabled',
          'Spotify enabled',
          options: _booleanNames,
        ),
        _EditorFieldSpec(
          'spotifyAutoPlay',
          'Spotify autoplay',
          options: _booleanNames,
        ),
        _EditorFieldSpec('spotifyMode', 'Spotify mode'),
        _EditorFieldSpec('spotifyPreferredDeviceName', 'Spotify device name'),
        _EditorFieldSpec(
          'spotifyPreferredDeviceType',
          'Spotify device type',
          options: _spotifyDeviceTypeNames,
        ),
        _EditorFieldSpec(
          'spotifyVolumePercent',
          'Spotify volume percent',
          kind: _EditorFieldKind.number,
        ),
        _EditorFieldSpec(
          'spotifyRetryCount',
          'Spotify retry count',
          kind: _EditorFieldKind.number,
        ),
        _EditorFieldSpec(
          'spotifyRetryDelaySeconds',
          'Spotify retry delay seconds',
          kind: _EditorFieldKind.number,
        ),
        _EditorFieldSpec(
          'spotifyStartMode',
          'Spotify start mode',
          options: _spotifyStartModeNames,
        ),
        _EditorFieldSpec('spotifyPlaylistUri', 'Spotify playlist URI'),
        _EditorFieldSpec('spotifyPlaylistLabel', 'Spotify playlist label'),
        _EditorFieldSpec(
          'spotifyPlaylistTags',
          'Spotify playlist tags (comma separated)',
          maxLines: 2,
        ),
        _EditorFieldSpec(
          'spotifyPlaylistPriority',
          'Spotify playlist priority',
          kind: _EditorFieldKind.number,
        ),
      ],
      initialValue: initial,
    );
    if (updated == null) {
      return;
    }
    updated['time'] = _nullableValue(updated['time']);
    updated['relatedCodes'] = _splitCommaValues(
      '${updated['relatedCodes'] ?? ''}',
    );
    updated['spotifyAction'] = _buildSpotifyActionPayload(updated);
    for (final key in _spotifyRoutineFieldKeys) {
      updated.remove(key);
    }
    if (index == null) {
      routine.add(updated);
    } else {
      routine[index] = updated;
    }
    final draft = Map<String, dynamic>.from(_mdrDraft);
    draft['routine'] = routine;
    _replaceDraft(AssistantDocumentType.mdr, draft);
  }

  void _deleteMdrRoutine(int index) {
    final routine = _listOfMaps(_mdrDraft, 'routine');
    routine.removeAt(index);
    final draft = Map<String, dynamic>.from(_mdrDraft);
    draft['routine'] = routine;
    _replaceDraft(AssistantDocumentType.mdr, draft);
  }

  Future<void> _editMdrFormula([int? index]) async {
    final formulas = _listOfMaps(_mdrDraft, 'recipesOrFormulas');
    final initial = index == null
        ? <String, dynamic>{'name': '', 'formula': ''}
        : Map<String, dynamic>.from(formulas[index]);
    final updated = await _openObjectEditor(
      title: index == null ? 'Add formula' : 'Edit formula',
      fields: const [
        _EditorFieldSpec('name', 'Name'),
        _EditorFieldSpec('formula', 'Formula', maxLines: 5),
      ],
      initialValue: initial,
    );
    if (updated == null) {
      return;
    }
    if (index == null) {
      formulas.add(updated);
    } else {
      formulas[index] = updated;
    }
    final draft = Map<String, dynamic>.from(_mdrDraft);
    draft['recipesOrFormulas'] = formulas;
    _replaceDraft(AssistantDocumentType.mdr, draft);
  }

  void _deleteMdrFormula(int index) {
    final formulas = _listOfMaps(_mdrDraft, 'recipesOrFormulas');
    formulas.removeAt(index);
    final draft = Map<String, dynamic>.from(_mdrDraft);
    draft['recipesOrFormulas'] = formulas;
    _replaceDraft(AssistantDocumentType.mdr, draft);
  }

  Object? _nullableValue(Object? value) {
    final text = '$value'.trim();
    return text.isEmpty ? null : text;
  }

  Map<String, dynamic> _firstSpotifyPlaylist(
    Map<String, dynamic> spotifyAction,
  ) {
    final candidates = _listOfMaps(spotifyAction, 'candidatePlaylists');
    return candidates.isEmpty ? const <String, dynamic>{} : candidates.first;
  }

  Map<String, dynamic>? _buildSpotifyActionPayload(Map<String, dynamic> draft) {
    final enabled = '${draft['spotifyEnabled'] ?? 'false'}' == 'true';
    final autoPlay = '${draft['spotifyAutoPlay'] ?? 'true'}' == 'true';
    final mode = '${draft['spotifyMode'] ?? ''}'.trim();
    final preferredDeviceName = '${draft['spotifyPreferredDeviceName'] ?? ''}'
        .trim();
    final preferredDeviceType =
        '${draft['spotifyPreferredDeviceType'] ?? 'computer'}'.trim();
    final playlistUri = '${draft['spotifyPlaylistUri'] ?? ''}'.trim();
    final playlistLabel = '${draft['spotifyPlaylistLabel'] ?? ''}'.trim();
    final playlistTags = _splitCommaValues(
      '${draft['spotifyPlaylistTags'] ?? ''}',
    );
    final volumePercent = draft['spotifyVolumePercent'] as int? ?? 25;
    final retryCount = draft['spotifyRetryCount'] as int? ?? 3;
    final retryDelaySeconds = draft['spotifyRetryDelaySeconds'] as int? ?? 15;
    final playlistPriority = draft['spotifyPlaylistPriority'] as int? ?? 100;
    final startMode = '${draft['spotifyStartMode'] ?? 'resumeOrPlay'}';

    if (!enabled &&
        mode.isEmpty &&
        preferredDeviceName.isEmpty &&
        playlistUri.isEmpty) {
      return null;
    }

    final candidatePlaylists = playlistUri.isEmpty
        ? const <Map<String, dynamic>>[]
        : <Map<String, dynamic>>[
            <String, dynamic>{
              'uri': playlistUri,
              'label': playlistLabel.isEmpty
                  ? 'Primary playlist'
                  : playlistLabel,
              'tags': playlistTags,
              'priority': playlistPriority,
            },
          ];

    return <String, dynamic>{
      'enabled': enabled,
      'autoPlay': autoPlay,
      'mode': mode,
      'preferredDeviceName': preferredDeviceName,
      'preferredDeviceType': preferredDeviceType,
      'volumePercent': volumePercent,
      'retryCount': retryCount,
      'retryDelaySeconds': retryDelaySeconds,
      'startMode': startMode,
      'candidatePlaylists': candidatePlaylists,
    };
  }

  List<String> _spotifySummaryLines(Map<String, dynamic> routineItem) {
    final spotifyAction = _mapValue(routineItem, 'spotifyAction');
    if (spotifyAction.isEmpty) {
      return const <String>[];
    }
    final firstPlaylist = _firstSpotifyPlaylist(spotifyAction);
    final lines = <String>[
      'Spotify ${spotifyAction['enabled'] == true ? 'enabled' : 'disabled'} | autoplay ${spotifyAction['autoPlay'] == true ? 'on' : 'off'} | mode ${spotifyAction['mode'] ?? 'custom'}',
      'Device ${spotifyAction['preferredDeviceName'] ?? '-'} | type ${spotifyAction['preferredDeviceType'] ?? '-'} | volume ${spotifyAction['volumePercent'] ?? '-'}%',
    ];
    if ('${firstPlaylist['uri'] ?? ''}'.trim().isNotEmpty) {
      lines.add(
        'Playlist ${firstPlaylist['label'] ?? 'Primary playlist'} | ${firstPlaylist['uri']}',
      );
    }
    return lines;
  }

  Widget _buildMdsForm() {
    final meta = _mapValue(_mdsDraft, 'meta');
    final items = _listOfMaps(_mdsDraft, 'items');
    final sets = _mapValue(_mdsDraft, 'sets');

    return ListView(
      children: [
        _SectionCard(
          title: 'Metadata',
          subtitle: 'Document-level fields for MDS.',
          onEdit: () => _editMeta(AssistantDocumentType.mds),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine(label: 'Short name', value: '${meta['name'] ?? ''}'),
              _InfoLine(label: 'Full name', value: '${meta['fullName'] ?? ''}'),
              _InfoLine(label: 'Source', value: '${meta['source'] ?? ''}'),
              _InfoLine(
                label: 'Updated at',
                value: '${meta['updatedAt'] ?? ''}',
              ),
              _InfoLine(
                label: 'Recovery note',
                value: '${meta['recoveryNote'] ?? ''}',
                multiline: true,
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Supplements',
          subtitle: '${items.length} items in MDS.',
          addLabel: 'Add supplement',
          onAdd: _editMdsItem,
          child: Column(
            children: [
              for (var index = 0; index < items.length; index++)
                _ObjectCard(
                  title:
                      '${items[index]['code'] ?? 'No code'} | ${items[index]['name'] ?? 'Unnamed'}',
                  subtitle:
                      '${items[index]['time'] ?? 'Flexible'} | ${items[index]['status'] ?? 'pending'}',
                  lines: [
                    '${items[index]['category'] ?? ''}',
                    '${items[index]['mealTiming'] ?? ''}',
                    '${items[index]['details'] ?? ''}',
                  ],
                  onEdit: () => _editMdsItem(index),
                  onDelete: () => _deleteMdsItem(index),
                ),
              if (items.isEmpty)
                const _EmptyState(message: 'No supplement items yet.'),
            ],
          ),
        ),
        _SectionCard(
          title: 'Sets',
          subtitle: '${sets.length} supplement groups.',
          addLabel: 'Add set',
          onAdd: _editMdsSet,
          child: Column(
            children: [
              for (final entry in sets.entries)
                _ObjectCard(
                  title: entry.key,
                  subtitle:
                      '${_stringList(entry.value).length} linked supplement codes',
                  chips: _stringList(entry.value),
                  onEdit: () => _editMdsSet(entry.key),
                  onDelete: () => _deleteMdsSet(entry.key),
                ),
              if (sets.isEmpty)
                const _EmptyState(message: 'No supplement sets yet.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMdrForm() {
    final meta = _mapValue(_mdrDraft, 'meta');
    final dashboard = _mapValue(_mdrDraft, 'dashboard');
    final timeline = _listOfMaps(_mdrDraft, 'timeline');
    final routine = _listOfMaps(_mdrDraft, 'routine');
    final formulas = _listOfMaps(_mdrDraft, 'recipesOrFormulas');

    return ListView(
      children: [
        _SectionCard(
          title: 'Metadata',
          subtitle: 'Document-level fields for MDR.',
          onEdit: () => _editMeta(AssistantDocumentType.mdr),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine(label: 'Short name', value: '${meta['name'] ?? ''}'),
              _InfoLine(label: 'Full name', value: '${meta['fullName'] ?? ''}'),
              _InfoLine(label: 'Source', value: '${meta['source'] ?? ''}'),
              _InfoLine(
                label: 'Updated at',
                value: '${meta['updatedAt'] ?? ''}',
              ),
              _InfoLine(
                label: 'Recovery note',
                value: '${meta['recoveryNote'] ?? ''}',
                multiline: true,
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Dashboard',
          subtitle: 'Top-level dashboard metrics used on the home view.',
          onEdit: _editMdrDashboard,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoLine(
                label: 'Next item time',
                value: '${dashboard['nextItemTime'] ?? ''}',
              ),
              _InfoLine(
                label: 'Bedtime target',
                value: '${dashboard['bedtimeTarget'] ?? ''}',
              ),
              _InfoLine(
                label: 'Adherence percent',
                value: '${dashboard['adherencePercent'] ?? ''}',
              ),
              _InfoLine(
                label: 'Pending count',
                value: '${dashboard['pendingCount'] ?? ''}',
              ),
              _InfoLine(
                label: 'Focus window',
                value: '${dashboard['focusWindow'] ?? ''}',
              ),
            ],
          ),
        ),
        _SectionCard(
          title: 'Timeline',
          subtitle: '${timeline.length} timeline items.',
          addLabel: 'Add timeline item',
          onAdd: _editMdrTimeline,
          child: Column(
            children: [
              for (var index = 0; index < timeline.length; index++)
                _ObjectCard(
                  title: '${timeline[index]['title'] ?? 'Untitled'}',
                  subtitle:
                      '${timeline[index]['time'] ?? 'Flexible'} | ${timeline[index]['icon'] ?? 'event_note'} | ${timeline[index]['status'] ?? 'pending'}',
                  lines: ['${timeline[index]['note'] ?? ''}'],
                  onEdit: () => _editMdrTimeline(index),
                  onDelete: () => _deleteMdrTimeline(index),
                ),
              if (timeline.isEmpty)
                const _EmptyState(message: 'No timeline items yet.'),
            ],
          ),
        ),
        _SectionCard(
          title: 'Routine',
          subtitle: '${routine.length} routine items.',
          addLabel: 'Add routine item',
          onAdd: _editMdrRoutine,
          child: Column(
            children: [
              for (var index = 0; index < routine.length; index++)
                _ObjectCard(
                  title: '${routine[index]['title'] ?? 'Untitled'}',
                  subtitle:
                      '${routine[index]['time'] ?? 'Flexible'} | ${routine[index]['period'] ?? 'day'} | ${routine[index]['status'] ?? 'pending'}',
                  lines: [
                    '${routine[index]['note'] ?? ''}',
                    ..._spotifySummaryLines(routine[index]),
                  ],
                  chips: _stringList(routine[index]['relatedCodes']),
                  onEdit: () => _editMdrRoutine(index),
                  onDelete: () => _deleteMdrRoutine(index),
                ),
              if (routine.isEmpty)
                const _EmptyState(message: 'No routine items yet.'),
            ],
          ),
        ),
        _SectionCard(
          title: 'Recipes / formulas',
          subtitle: '${formulas.length} saved entries.',
          addLabel: 'Add formula',
          onAdd: _editMdrFormula,
          child: Column(
            children: [
              for (var index = 0; index < formulas.length; index++)
                _ObjectCard(
                  title: '${formulas[index]['name'] ?? 'Untitled'}',
                  lines: ['${formulas[index]['formula'] ?? ''}'],
                  onEdit: () => _editMdrFormula(index),
                  onDelete: () => _deleteMdrFormula(index),
                ),
              if (formulas.isEmpty)
                const _EmptyState(message: 'No formulas yet.'),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRawMode = _editorMode == AssistantEditorMode.raw;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data editor', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Use form mode for structured editing and raw mode for full JSON access. Save writes both MDS and MDR back to the root data folder.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              MetadataPill(
                icon: Icons.description_outlined,
                label:
                    '${_selectedDocument.fileName} | ${_currentPath ?? 'Preview mode'}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SegmentedButton<AssistantDocumentType>(
                segments: const [
                  ButtonSegment(
                    value: AssistantDocumentType.mds,
                    label: Text('MDS.json'),
                  ),
                  ButtonSegment(
                    value: AssistantDocumentType.mdr,
                    label: Text('MDR.json'),
                  ),
                ],
                selected: <AssistantDocumentType>{_selectedDocument},
                onSelectionChanged: (selection) {
                  setState(() {
                    _selectedDocument = selection.first;
                  });
                },
              ),
              SegmentedButton<AssistantEditorMode>(
                segments: const [
                  ButtonSegment(
                    value: AssistantEditorMode.form,
                    label: Text('Form mode'),
                  ),
                  ButtonSegment(
                    value: AssistantEditorMode.raw,
                    label: Text('Raw mode'),
                  ),
                ],
                selected: <AssistantEditorMode>{_editorMode},
                onSelectionChanged: (selection) {
                  _switchEditorMode(selection.first);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _isBusy ? null : _saveAll,
                icon: const Icon(Icons.save_outlined),
                label: const Text('Save All'),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _reloadFromDisk,
                icon: const Icon(Icons.refresh),
                label: const Text('Reload'),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _validateCurrent,
                icon: const Icon(Icons.rule_folder_outlined),
                label: const Text('Validate'),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _formatCurrent,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('Format'),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _importCurrent,
                icon: const Icon(Icons.file_open_outlined),
                label: Text('Import ${_selectedDocument.label}'),
              ),
              OutlinedButton.icon(
                onPressed: _isBusy ? null : _exportCurrent,
                icon: const Icon(Icons.download_outlined),
                label: Text('Export ${_selectedDocument.label}'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: isRawMode
                    ? TextField(
                        controller: _currentController,
                        expands: true,
                        maxLines: null,
                        minLines: null,
                        textAlignVertical: TextAlignVertical.top,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          hintText: 'Raw ${_selectedDocument.fileName} JSON',
                          hintStyle: theme.textTheme.bodyMedium,
                        ),
                        style: const TextStyle(
                          fontFamily: 'Courier New',
                          fontSize: 13,
                          height: 1.4,
                        ),
                      )
                    : _buildFormEditor(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

const List<String> _statusNames = [
  'completed',
  'dueSoon',
  'scheduled',
  'pending',
];

const List<String> _periodNames = ['day', 'night'];

const List<String> _booleanNames = ['true', 'false'];

const List<String> _spotifyDeviceTypeNames = [
  'computer',
  'speaker',
  'smartphone',
  'tablet',
  'tv',
  'audio_dongle',
  'unknown',
];

const List<String> _spotifyStartModeNames = ['resumeOrPlay', 'startFresh'];

const List<String> _iconNames = [
  'medication',
  'biotech_outlined',
  'restaurant_outlined',
  'nightlight_round',
  'wb_sunny_outlined',
  'schedule',
  'inventory_2_outlined',
  'help_outline',
  'air',
  'dinner_dining_outlined',
  'bedtime_outlined',
  'event_note',
];

const Set<String> _spotifyRoutineFieldKeys = <String>{
  'spotifyEnabled',
  'spotifyAutoPlay',
  'spotifyMode',
  'spotifyPreferredDeviceName',
  'spotifyPreferredDeviceType',
  'spotifyVolumePercent',
  'spotifyRetryCount',
  'spotifyRetryDelaySeconds',
  'spotifyStartMode',
  'spotifyPlaylistUri',
  'spotifyPlaylistLabel',
  'spotifyPlaylistTags',
  'spotifyPlaylistPriority',
};

enum _EditorFieldKind { text, number }

class _EditorFieldSpec {
  const _EditorFieldSpec(
    this.key,
    this.label, {
    this.kind = _EditorFieldKind.text,
    this.maxLines = 1,
    this.options,
  });

  final String key;
  final String label;
  final _EditorFieldKind kind;
  final int maxLines;
  final List<String>? options;
}

class _ObjectEditorDialog extends StatefulWidget {
  const _ObjectEditorDialog({
    required this.title,
    required this.fields,
    required this.initialValue,
  });

  final String title;
  final List<_EditorFieldSpec> fields;
  final Map<String, dynamic> initialValue;

  @override
  State<_ObjectEditorDialog> createState() => _ObjectEditorDialogState();
}

class _ObjectEditorDialogState extends State<_ObjectEditorDialog> {
  late final Map<String, TextEditingController> _controllers;
  late final Map<String, String> _dropdownValues;

  @override
  void initState() {
    super.initState();
    _controllers = {
      for (final field in widget.fields)
        if (field.options == null)
          field.key: TextEditingController(
            text: '${widget.initialValue[field.key] ?? ''}',
          ),
    };
    _dropdownValues = {
      for (final field in widget.fields)
        if (field.options != null) field.key: _initialDropdownValue(field),
    };
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _initialDropdownValue(_EditorFieldSpec field) {
    final raw = '${widget.initialValue[field.key] ?? ''}';
    if (field.options!.contains(raw)) {
      return raw;
    }
    return field.options!.first;
  }

  Object _readFieldValue(_EditorFieldSpec field) {
    if (field.options != null) {
      return _dropdownValues[field.key] ?? field.options!.first;
    }
    final text = _controllers[field.key]!.text.trim();
    if (field.kind == _EditorFieldKind.number) {
      return int.tryParse(text) ?? 0;
    }
    return text;
  }

  void _submit() {
    final result = <String, dynamic>{
      for (final field in widget.fields) field.key: _readFieldValue(field),
    };
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final field in widget.fields) ...[
                if (field.options != null)
                  DropdownButtonFormField<String>(
                    initialValue: _dropdownValues[field.key],
                    decoration: InputDecoration(labelText: field.label),
                    items: [
                      for (final option in field.options!)
                        DropdownMenuItem(value: option, child: Text(option)),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _dropdownValues[field.key] = value;
                      });
                    },
                  )
                else
                  TextField(
                    controller: _controllers[field.key],
                    maxLines: field.maxLines,
                    keyboardType: field.kind == _EditorFieldKind.number
                        ? TextInputType.number
                        : TextInputType.multiline,
                    decoration: InputDecoration(labelText: field.label),
                  ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
    this.onEdit,
    this.onAdd,
    this.addLabel,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? onEdit;
  final VoidCallback? onAdd;
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF8),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFD8E2DC)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: theme.textTheme.titleLarge),
                        const SizedBox(height: 4),
                        Text(subtitle, style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
                  if (onEdit != null)
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit section',
                    ),
                  if (onAdd != null)
                    FilledButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: Text(addLabel ?? 'Add'),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ObjectCard extends StatelessWidget {
  const _ObjectCard({
    required this.title,
    this.subtitle,
    this.lines = const <String>[],
    this.chips = const <String>[],
    this.onEdit,
    this.onDelete,
  });

  final String title;
  final String? subtitle;
  final List<String> lines;
  final List<String> chips;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFE0E7E2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium),
                      if (subtitle != null && subtitle!.trim().isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(subtitle!, style: theme.textTheme.bodySmall),
                      ],
                    ],
                  ),
                ),
                if (onEdit != null)
                  IconButton(
                    onPressed: onEdit,
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit item',
                  ),
                if (onDelete != null)
                  IconButton(
                    onPressed: onDelete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete item',
                  ),
              ],
            ),
            for (final line in lines)
              if (line.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(line),
              ],
            if (chips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final chip in chips)
                    MetadataPill(icon: Icons.label_outline, label: chip),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
    this.multiline = false,
  });

  final String label;
  final String value;
  final bool multiline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelLarge),
          const SizedBox(height: 2),
          Text(
            value.trim().isEmpty ? '-' : value,
            maxLines: multiline ? null : 2,
            overflow: multiline ? TextOverflow.visible : TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF2F5F3),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(message),
    );
  }
}

class MetadataPill extends StatelessWidget {
  const MetadataPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: const Color(0xFFF2F5F3),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: const Color(0xFF395D52)),
            const SizedBox(width: 6),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
    );
  }
}
