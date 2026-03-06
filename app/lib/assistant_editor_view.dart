import 'package:flutter/material.dart';

import 'assistant_models.dart';
import 'assistant_workspace_repository.dart';

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
  AssistantDocumentType _selectedDocument = AssistantDocumentType.mds;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _mdsController = TextEditingController(text: widget.workspace.mdsJson);
    _mdrController = TextEditingController(text: widget.workspace.mdrJson);
  }

  @override
  void didUpdateWidget(covariant AssistantEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.workspace.mdsJson != widget.workspace.mdsJson) {
      _mdsController.text = widget.workspace.mdsJson;
    }
    if (oldWidget.workspace.mdrJson != widget.workspace.mdrJson) {
      _mdrController.text = widget.workspace.mdrJson;
    }
  }

  @override
  void dispose() {
    _mdsController.dispose();
    _mdrController.dispose();
    super.dispose();
  }

  TextEditingController get _currentController {
    return _selectedDocument == AssistantDocumentType.mds
        ? _mdsController
        : _mdrController;
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final workspace = widget.workspace;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data editor', style: theme.textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            'Edit the raw MDS and MDR JSON directly, then save back to the root data folder or import and export JSON files.',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              MetadataPill(
                icon: Icons.folder_outlined,
                label: 'MDS: ${workspace.mdsPath ?? 'Preview mode'}',
              ),
              MetadataPill(
                icon: Icons.folder_outlined,
                label: 'MDR: ${workspace.mdrPath ?? 'Preview mode'}',
              ),
            ],
          ),
          const SizedBox(height: 16),
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
                child: TextField(
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MetadataPill extends StatelessWidget {
  const MetadataPill({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
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
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }
}
