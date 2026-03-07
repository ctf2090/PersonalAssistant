import 'dart:convert';

import 'package:flutter/material.dart';

const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

class AssistantSnapshot {
  const AssistantSnapshot({
    required this.nextDoseTime,
    required this.bedtimeTarget,
    required this.adherencePercent,
    required this.pendingCount,
    required this.focusWindow,
    required this.timeline,
    required this.doses,
    required this.sets,
    required this.routines,
  });

  final String nextDoseTime;
  final String bedtimeTarget;
  final int adherencePercent;
  final int pendingCount;
  final String focusWindow;
  final List<TimelineItem> timeline;
  final List<MedicationDose> doses;
  final List<SupplementSet> sets;
  final List<RoutineTask> routines;

  List<RoutineTask> get spotifyRoutines =>
      routines.where((task) => task.spotifyAction?.enabled ?? false).toList();

  factory AssistantSnapshot.sample() {
    return const AssistantSnapshot(
      nextDoseTime: '07:30',
      bedtimeTarget: '22:45',
      adherencePercent: 78,
      pendingCount: 4,
      focusWindow: '07:30-10:00',
      timeline: [
        TimelineItem(
          title: 'Morning core stack',
          note: 'Start with CMZD, methyl B-12 + folate, fish oil, and Q10.',
          time: '07:30',
          icon: Icons.medication,
          status: ItemStatus.dueSoon,
        ),
        TimelineItem(
          title: '30B probiotic window',
          note:
              'Keep the probiotic around 10:00 as the fixed morning follow-up.',
          time: '10:00',
          icon: Icons.biotech_outlined,
          status: ItemStatus.scheduled,
        ),
        TimelineItem(
          title: 'Meal-dependent support',
          note:
              'Use BPG, Lacto, or GlutenEase only when the meal requires them.',
          time: 'Flexible',
          icon: Icons.restaurant_outlined,
          status: ItemStatus.scheduled,
        ),
        TimelineItem(
          title: 'Evening wrap',
          note: 'Finish with GSH, diltiazem, and the after-dinner ASH slot.',
          time: '21:00',
          icon: Icons.nightlight_round,
          status: ItemStatus.pending,
        ),
      ],
      doses: [
        MedicationDose(
          name: '21st Century Calcium Magnesium Zinc + D3',
          dosage: '1 serving',
          instructions: 'Daily foundation supplement',
          time: '07:30',
          mealTiming: 'After breakfast',
          note: 'Code: CMZD | Part of bbcfq and anxiety core set',
          status: ItemStatus.dueSoon,
        ),
        MedicationDose(
          name: 'Jarrow Methyl B-12 + Methyl Folate',
          dosage: 'Extra strength',
          instructions: 'Mood and blood support',
          time: '07:30',
          mealTiming: 'After breakfast',
          note: 'Code: B612F | Part of bbcfq and anxiety core set',
          status: ItemStatus.dueSoon,
        ),
        MedicationDose(
          name: 'California Gold Nutrition Fish Oil',
          dosage: 'Omega-3',
          instructions: 'Daily health support',
          time: '07:30',
          mealTiming: 'Morning stack',
          note: 'Code: Fish Oil | Part of bbcfq',
          status: ItemStatus.dueSoon,
        ),
        MedicationDose(
          name: 'NOW CoQ10',
          dosage: '100 mg',
          instructions: 'Heart health support',
          time: '07:30',
          mealTiming: 'Morning stack',
          note: 'Code: Q10 | Part of bbcfq',
          status: ItemStatus.scheduled,
        ),
        MedicationDose(
          name: 'LactoBif Probiotics',
          dosage: '30 Billion CFU',
          instructions: 'Daily gut support',
          time: '10:00',
          mealTiming: 'Morning follow-up',
          note: 'Code: 30B | Fixed time from MDR',
          status: ItemStatus.scheduled,
        ),
        MedicationDose(
          name: 'Betaine HCl with Pepsin',
          dosage: 'As needed',
          instructions: 'Meal support when digestion is off',
          time: 'Flexible',
          mealTiming: 'After regular meals',
          note: 'Code: BPG | Only when needed',
          status: ItemStatus.pending,
        ),
        MedicationDose(
          name: 'L-Glutathione Reduced',
          dosage: '500 mg',
          instructions: 'Evening antioxidant support',
          time: '21:00',
          mealTiming: 'Evening',
          note: 'Code: GSH',
          status: ItemStatus.pending,
        ),
        MedicationDose(
          name: 'Ashwagandha',
          dosage: '450 mg',
          instructions: 'Anxiety core set support',
          time: 'After dinner',
          mealTiming: 'Dinner after meal',
          note: 'Code: ASH | Not recommended before sleep',
          status: ItemStatus.pending,
        ),
        MedicationDose(
          name: 'Diltiazem',
          dosage: '30 mg',
          instructions: 'Blood pressure support',
          time: 'Evening',
          mealTiming: 'Dinner or later evening',
          note: 'Prescription item from MDS',
          status: ItemStatus.pending,
        ),
      ],
      sets: [
        SupplementSet(
          name: 'bbcfq',
          note: 'The recurring base stack captured in MDS.',
          items: ['CMZD', 'B612F', 'Benf', 'Q10', 'Fish Oil'],
        ),
        SupplementSet(
          name: 'Anxiety core set',
          note: 'Current mood stability grouping from the source export.',
          items: ['ASH', 'CMZD', 'B612F'],
        ),
      ],
      routines: [
        RoutineTask(
          title: 'Morning supplement stack',
          time: '07:30',
          note: 'Take the breakfast stack and anchor the day with CMZD.',
          icon: Icons.wb_sunny_outlined,
          period: RoutinePeriod.day,
          status: ItemStatus.dueSoon,
          spotifyAction: SpotifyAction(
            enabled: true,
            autoPlay: true,
            mode: 'wake_gentle',
            preferredDeviceName: 'Win11 Spotify',
            preferredDeviceType: 'computer',
            volumePercent: 30,
            retryCount: 3,
            retryDelaySeconds: 15,
            candidatePlaylists: [
              SpotifyPlaylistCandidate(
                uri: 'spotify:playlist:37i9dQZF1DX3Ogo9pFvBkY',
                label: 'Gentle wake default',
                tags: ['wake', 'soft', 'morning'],
                priority: 100,
              ),
            ],
          ),
        ),
        RoutineTask(
          title: '30B probiotic checkpoint',
          time: '10:00',
          note: 'Keep this as the fixed morning follow-up item.',
          icon: Icons.schedule,
          period: RoutinePeriod.day,
          status: ItemStatus.scheduled,
        ),
        RoutineTask(
          title: 'Meal-triggered support',
          time: 'Flexible',
          note:
              'Use BPG, Lacto, or GlutenEase only when the meal needs support.',
          icon: Icons.restaurant_outlined,
          period: RoutinePeriod.day,
          status: ItemStatus.scheduled,
        ),
        RoutineTask(
          title: 'Fluticasone nasal care',
          time: 'Flexible',
          note: 'Keep the nasal routine available as part of the support flow.',
          icon: Icons.air,
          period: RoutinePeriod.day,
          status: ItemStatus.pending,
        ),
        RoutineTask(
          title: 'Dinner and evening support',
          time: 'After dinner',
          note:
              'Use the ASH slot after dinner and keep diltiazem in the evening plan.',
          icon: Icons.dinner_dining_outlined,
          period: RoutinePeriod.night,
          status: ItemStatus.pending,
        ),
        RoutineTask(
          title: 'Evening glutathione wrap',
          time: '21:00',
          note: 'Take GSH and start the lower-stimulation night path.',
          icon: Icons.bedtime_outlined,
          period: RoutinePeriod.night,
          status: ItemStatus.pending,
          spotifyAction: SpotifyAction(
            enabled: true,
            autoPlay: true,
            mode: 'sleep_wind_down',
            preferredDeviceName: 'Win11 Spotify',
            preferredDeviceType: 'computer',
            volumePercent: 20,
            retryCount: 3,
            retryDelaySeconds: 15,
            candidatePlaylists: [
              SpotifyPlaylistCandidate(
                uri: 'spotify:playlist:37i9dQZF1DWZd79rJ6a7lp',
                label: 'Sleep default',
                tags: ['sleep', 'calm', 'night'],
                priority: 100,
              ),
            ],
          ),
        ),
      ],
    );
  }

  factory AssistantSnapshot.fromRecoveredData(
    Map<String, dynamic> mds,
    Map<String, dynamic> mdr,
  ) {
    final dashboard = _readMap(mdr['dashboard']);
    final timeline = _readList(
      mdr['timeline'],
    ).map((item) => TimelineItem.fromJson(_readMap(item))).toList();
    final doses = _readList(
      mds['items'],
    ).map((item) => MedicationDose.fromJson(_readMap(item))).toList();
    final sets = _readMap(mds['sets']).entries
        .map(
          (entry) => SupplementSet(
            name: entry.key,
            note: _setNote(entry.key),
            items: _readList(entry.value).map((item) => '$item').toList(),
          ),
        )
        .toList();
    final routines = _readList(
      mdr['routine'],
    ).map((item) => RoutineTask.fromJson(_readMap(item))).toList();

    return AssistantSnapshot(
      nextDoseTime: _stringOrFallback(dashboard['nextItemTime'], '07:30'),
      bedtimeTarget: _stringOrFallback(dashboard['bedtimeTarget'], '22:45'),
      adherencePercent: _intOrFallback(dashboard['adherencePercent'], 0),
      pendingCount: _intOrFallback(dashboard['pendingCount'], 0),
      focusWindow: _stringOrFallback(dashboard['focusWindow'], 'N/A'),
      timeline: timeline,
      doses: doses,
      sets: sets,
      routines: routines,
    );
  }
}

class AssistantWorkspaceData {
  const AssistantWorkspaceData({
    required this.snapshot,
    required this.mdsJson,
    required this.mdrJson,
    this.mdsPath,
    this.mdrPath,
  });

  final AssistantSnapshot snapshot;
  final String mdsJson;
  final String mdrJson;
  final String? mdsPath;
  final String? mdrPath;

  factory AssistantWorkspaceData.sample() {
    return AssistantWorkspaceData(
      snapshot: AssistantSnapshot.sample(),
      mdsJson: formatJsonSource(_sampleMdsJson),
      mdrJson: formatJsonSource(_sampleMdrJson),
    );
  }

  factory AssistantWorkspaceData.fromJsonTexts({
    required String mdsJson,
    required String mdrJson,
    String? mdsPath,
    String? mdrPath,
  }) {
    final mds = decodeJsonObject(mdsJson, label: 'MDS');
    final mdr = decodeJsonObject(mdrJson, label: 'MDR');
    return AssistantWorkspaceData(
      snapshot: AssistantSnapshot.fromRecoveredData(mds, mdr),
      mdsJson: formatJsonObject(mds),
      mdrJson: formatJsonObject(mdr),
      mdsPath: mdsPath,
      mdrPath: mdrPath,
    );
  }

  AssistantWorkspaceData copyWith({
    AssistantSnapshot? snapshot,
    String? mdsJson,
    String? mdrJson,
    String? mdsPath,
    String? mdrPath,
  }) {
    return AssistantWorkspaceData(
      snapshot: snapshot ?? this.snapshot,
      mdsJson: mdsJson ?? this.mdsJson,
      mdrJson: mdrJson ?? this.mdrJson,
      mdsPath: mdsPath ?? this.mdsPath,
      mdrPath: mdrPath ?? this.mdrPath,
    );
  }
}

enum AssistantDocumentType {
  mds('MDS', 'MDS.json'),
  mdr('MDR', 'MDR.json');

  const AssistantDocumentType(this.label, this.fileName);

  final String label;
  final String fileName;
}

class TimelineItem {
  const TimelineItem({
    required this.title,
    required this.note,
    required this.time,
    required this.icon,
    required this.status,
  });

  final String title;
  final String note;
  final String time;
  final IconData icon;
  final ItemStatus status;

  factory TimelineItem.fromJson(Map<String, dynamic> json) {
    return TimelineItem(
      title: _stringOrFallback(json['title'], 'Untitled timeline item'),
      note: _stringOrFallback(json['note'], ''),
      time: _stringOrFallback(json['time'], 'Flexible'),
      icon: _iconFromName(json['icon']),
      status: _statusFromName(json['status']),
    );
  }
}

class MedicationDose {
  const MedicationDose({
    required this.name,
    required this.dosage,
    required this.instructions,
    required this.time,
    required this.mealTiming,
    required this.note,
    required this.status,
  });

  final String name;
  final String dosage;
  final String instructions;
  final String time;
  final String mealTiming;
  final String note;
  final ItemStatus status;

  factory MedicationDose.fromJson(Map<String, dynamic> json) {
    return MedicationDose(
      name: _stringOrFallback(json['name'], 'Unnamed supplement'),
      dosage: _deriveDosage(json),
      instructions: _stringOrFallback(json['category'], 'Support item'),
      time: _stringOrFallback(json['time'], 'Flexible'),
      mealTiming: _stringOrFallback(json['mealTiming'], 'Flexible'),
      note: _stringOrFallback(
        json['details'],
        'Code: ${json['code'] ?? 'N/A'}',
      ),
      status: _statusFromName(json['status']),
    );
  }
}

class SupplementSet {
  const SupplementSet({
    required this.name,
    required this.note,
    required this.items,
  });

  final String name;
  final String note;
  final List<String> items;
}

class RoutineTask {
  const RoutineTask({
    required this.title,
    required this.time,
    required this.note,
    required this.icon,
    required this.period,
    required this.status,
    this.spotifyAction,
  });

  final String title;
  final String time;
  final String note;
  final IconData icon;
  final RoutinePeriod period;
  final ItemStatus status;
  final SpotifyAction? spotifyAction;

  factory RoutineTask.fromJson(Map<String, dynamic> json) {
    final spotifyActionJson = _readOptionalMap(json['spotifyAction']);
    return RoutineTask(
      title: _stringOrFallback(json['title'], 'Untitled routine'),
      time: _stringOrFallback(json['time'], 'Flexible'),
      note: _stringOrFallback(json['note'], ''),
      icon: _iconFromName(json['icon']),
      period: _periodFromName(json['period']),
      status: _statusFromName(json['status']),
      spotifyAction: spotifyActionJson == null
          ? null
          : SpotifyAction.fromJson(spotifyActionJson),
    );
  }
}

class SpotifyAction {
  const SpotifyAction({
    required this.enabled,
    required this.autoPlay,
    required this.mode,
    required this.preferredDeviceName,
    required this.preferredDeviceType,
    required this.volumePercent,
    required this.retryCount,
    required this.retryDelaySeconds,
    this.startMode = SpotifyStartMode.resumeOrPlay,
    this.candidatePlaylists = const <SpotifyPlaylistCandidate>[],
  });

  final bool enabled;
  final bool autoPlay;
  final String mode;
  final String preferredDeviceName;
  final String preferredDeviceType;
  final int volumePercent;
  final int retryCount;
  final int retryDelaySeconds;
  final SpotifyStartMode startMode;
  final List<SpotifyPlaylistCandidate> candidatePlaylists;

  String get primaryPlaylistUri =>
      candidatePlaylists.isEmpty ? '' : candidatePlaylists.first.uri;

  factory SpotifyAction.fromJson(Map<String, dynamic> json) {
    final playlists = _readList(
      json['candidatePlaylists'],
    ).map((item) => SpotifyPlaylistCandidate.fromJson(_readMap(item))).toList();
    final legacyUri = _stringOrFallback(json['playlistUri'], '');
    if (playlists.isEmpty && legacyUri.isNotEmpty) {
      playlists.add(
        SpotifyPlaylistCandidate(
          uri: legacyUri,
          label: _stringOrFallback(json['playlistLabel'], 'Primary playlist'),
          tags: const <String>[],
          priority: 100,
        ),
      );
    }

    return SpotifyAction(
      enabled: _boolOrFallback(json['enabled'], true),
      autoPlay: _boolOrFallback(json['autoPlay'], true),
      mode: _stringOrFallback(json['mode'], 'custom'),
      preferredDeviceName: _stringOrFallback(json['preferredDeviceName'], ''),
      preferredDeviceType: _stringOrFallback(json['preferredDeviceType'], ''),
      volumePercent: _intOrFallback(json['volumePercent'], 25),
      retryCount: _intOrFallback(json['retryCount'], 3),
      retryDelaySeconds: _intOrFallback(json['retryDelaySeconds'], 15),
      startMode: _spotifyStartModeFromName(json['startMode']),
      candidatePlaylists: playlists,
    );
  }
}

class SpotifyPlaylistCandidate {
  const SpotifyPlaylistCandidate({
    required this.uri,
    required this.label,
    required this.tags,
    required this.priority,
  });

  final String uri;
  final String label;
  final List<String> tags;
  final int priority;

  factory SpotifyPlaylistCandidate.fromJson(Map<String, dynamic> json) {
    return SpotifyPlaylistCandidate(
      uri: _stringOrFallback(json['uri'], ''),
      label: _stringOrFallback(json['label'], 'Playlist'),
      tags: _readList(json['tags']).map((item) => '$item').toList(),
      priority: _intOrFallback(json['priority'], 100),
    );
  }
}

enum SpotifyStartMode { resumeOrPlay, startFresh }

enum RoutinePeriod { day, night }

enum ItemStatus {
  completed('Done', Color(0xFF395D52)),
  dueSoon('Due soon', Color(0xFFE0872C)),
  scheduled('Planned', Color(0xFF66877D)),
  pending('Pending', Color(0xFF7C5C2A));

  const ItemStatus(this.label, this.color);

  final String label;
  final Color color;
}

Map<String, dynamic> _readMap(Object? value) {
  return (value as Map).cast<String, dynamic>();
}

Map<String, dynamic>? _readOptionalMap(Object? value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.cast<String, dynamic>();
  }
  return null;
}

List<dynamic> _readList(Object? value) {
  return (value as List<dynamic>? ?? const <dynamic>[]);
}

String _stringOrFallback(Object? value, String fallback) {
  final text = value?.toString().trim();
  return text == null || text.isEmpty ? fallback : text;
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

bool _boolOrFallback(Object? value, bool fallback) {
  if (value is bool) {
    return value;
  }
  final text = '${value ?? ''}'.trim().toLowerCase();
  if (text == 'true') {
    return true;
  }
  if (text == 'false') {
    return false;
  }
  return fallback;
}

String _deriveDosage(Map<String, dynamic> json) {
  final name = _stringOrFallback(json['name'], '');
  final details = _stringOrFallback(json['details'], '');
  final category = _stringOrFallback(json['category'], 'Supplement');

  if (name.contains('100 mg')) {
    return '100 mg';
  }
  if (name.contains('150')) {
    return '150 mg';
  }
  if (details.contains('200 mg')) {
    return '200 mg';
  }
  if (details.contains('500 mg')) {
    return '500 mg';
  }
  if (name.contains('450 mg')) {
    return '450 mg';
  }
  if (name.contains('30 Billion')) {
    return '30 Billion CFU';
  }
  if (name.contains('30 mg')) {
    return '30 mg';
  }
  if (name.contains('Omega-3')) {
    return 'Omega-3';
  }
  if (name.contains('Extra Strength')) {
    return 'Extra strength';
  }
  if (category.contains('support')) {
    return 'Support item';
  }
  return '1 serving';
}

String _setNote(String name) {
  switch (name) {
    case 'bbcfq':
      return 'The recurring base stack captured in MDS.';
    case 'anxietyCoreSet':
      return 'Current mood stability grouping from the source export.';
    default:
      return 'Recovered supplement grouping.';
  }
}

ItemStatus _statusFromName(Object? value) {
  switch ('$value') {
    case 'completed':
      return ItemStatus.completed;
    case 'dueSoon':
      return ItemStatus.dueSoon;
    case 'scheduled':
      return ItemStatus.scheduled;
    default:
      return ItemStatus.pending;
  }
}

RoutinePeriod _periodFromName(Object? value) {
  return '$value' == 'night' ? RoutinePeriod.night : RoutinePeriod.day;
}

SpotifyStartMode _spotifyStartModeFromName(Object? value) {
  return '$value' == 'startFresh'
      ? SpotifyStartMode.startFresh
      : SpotifyStartMode.resumeOrPlay;
}

IconData _iconFromName(Object? value) {
  switch ('$value') {
    case 'medication':
      return Icons.medication;
    case 'biotech_outlined':
      return Icons.biotech_outlined;
    case 'restaurant_outlined':
      return Icons.restaurant_outlined;
    case 'nightlight_round':
      return Icons.nightlight_round;
    case 'wb_sunny_outlined':
      return Icons.wb_sunny_outlined;
    case 'schedule':
      return Icons.schedule;
    case 'inventory_2_outlined':
      return Icons.inventory_2_outlined;
    case 'help_outline':
      return Icons.help_outline;
    case 'air':
      return Icons.air;
    case 'dinner_dining_outlined':
      return Icons.dinner_dining_outlined;
    case 'bedtime_outlined':
      return Icons.bedtime_outlined;
    default:
      return Icons.event_note;
  }
}

Map<String, dynamic> decodeJsonObject(String source, {required String label}) {
  try {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.cast<String, dynamic>();
    }
    throw const FormatException('JSON root must be an object.');
  } on FormatException catch (error) {
    throw FormatException('$label JSON is invalid: ${error.message}');
  }
}

String formatJsonSource(String source) {
  return formatJsonObject(jsonDecode(source) as Object);
}

String formatJsonObject(Object jsonObject) {
  return _prettyJsonEncoder.convert(jsonObject);
}

const String _sampleMdsJson = r'''
{
  "meta": {
    "name": "MDS",
    "fullName": "My Daily Supplements",
    "source": "Recovered from the local export on 2026-03-06",
    "updatedAt": "2026-03-06T15:20:00+08:00",
    "recoveryNote": "This file was normalized from a corrupted export. Unrecoverable strings were replaced with explicit English descriptions."
  },
  "items": [
    {
      "code": "Benf",
      "name": "Doctor's Best Benfotiamine 150 with BenfoPure",
      "productCode": "DRB-00129",
      "category": "Wernicke-Korsakoff Syndrome (WKS) support",
      "time": "07:30",
      "mealTiming": "Morning stack",
      "details": "Included in the bbcfq stack.",
      "status": "scheduled"
    }
  ],
  "sets": {
    "bbcfq": [
      "CMZD",
      "B612F",
      "Benf",
      "Q10",
      "Fish Oil"
    ],
    "anxietyCoreSet": [
      "ASH",
      "CMZD",
      "B612F"
    ]
  }
}
''';

const String _sampleMdrJson = r'''
{
  "meta": {
    "name": "MDR",
    "fullName": "My Daily Routine",
    "source": "Recovered from the local export on 2026-03-06",
    "updatedAt": "2026-03-06T15:20:00+08:00",
    "recoveryNote": "This file was normalized from a corrupted export. One truncated routine line and one formula note remain placeholders."
  },
  "dashboard": {
    "nextItemTime": "07:30",
    "bedtimeTarget": "22:45",
    "adherencePercent": 78,
    "pendingCount": 4,
    "focusWindow": "07:30-10:00"
  },
  "timeline": [
    {
      "title": "Morning core stack",
      "note": "Start with CMZD, methyl B-12 + folate, fish oil, and Q10.",
      "time": "07:30",
      "icon": "medication",
      "status": "dueSoon"
    }
  ],
  "routine": [
    {
      "title": "Morning supplement stack",
      "time": "07:30",
      "period": "day",
      "icon": "wb_sunny_outlined",
      "status": "dueSoon",
      "note": "Take the breakfast stack and anchor the day with CMZD.",
      "spotifyAction": {
        "enabled": true,
        "autoPlay": true,
        "mode": "wake_gentle",
        "preferredDeviceName": "Win11 Spotify",
        "preferredDeviceType": "computer",
        "volumePercent": 30,
        "retryCount": 3,
        "retryDelaySeconds": 15,
        "startMode": "resumeOrPlay",
        "candidatePlaylists": [
          {
            "uri": "spotify:playlist:37i9dQZF1DX3Ogo9pFvBkY",
            "label": "Gentle wake default",
            "tags": [
              "wake",
              "soft",
              "morning"
            ],
            "priority": 100
          }
        ]
      },
      "relatedCodes": [
        "CMZD"
      ]
    }
  ],
  "recipesOrFormulas": [
    {
      "name": "Formula note needs manual recovery",
      "formula": "The original formula text was corrupted in the source export. Replace this placeholder from the original source if it becomes available."
    }
  ]
}
''';
