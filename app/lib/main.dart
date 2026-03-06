import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

import 'assistant_models.dart';
import 'assistant_snapshot_loader.dart';

void main() {
  runApp(const PersonalAssistantApp());
}

class PersonalAssistantApp extends StatelessWidget {
  const PersonalAssistantApp({super.key, this.snapshotFuture});

  final Future<AssistantSnapshot>? snapshotFuture;

  @override
  Widget build(BuildContext context) {
    const canvas = Color(0xFFF6F1E8);
    const ink = Color(0xFF18342E);
    const sunrise = Color(0xFFE3A257);

    return MaterialApp(
      title: 'Personal Assistant',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: const ColorScheme.light(
          primary: ink,
          onPrimary: Colors.white,
          secondary: sunrise,
          onSecondary: Colors.white,
          surface: Colors.white,
          onSurface: ink,
        ),
        scaffoldBackgroundColor: canvas,
        cardTheme: const CardThemeData(
          color: Colors.white,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(28)),
          ),
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w700,
            color: ink,
            height: 1.05,
          ),
          headlineSmall: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: ink,
          ),
          titleMedium: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: ink, height: 1.4),
          bodyMedium: TextStyle(
            fontSize: 14,
            color: Color(0xFF49655E),
            height: 1.4,
          ),
        ),
      ),
      home: AssistantHomeLoader(snapshotFuture: snapshotFuture),
    );
  }
}

class AssistantHomeLoader extends StatefulWidget {
  const AssistantHomeLoader({super.key, this.snapshotFuture});

  final Future<AssistantSnapshot>? snapshotFuture;

  @override
  State<AssistantHomeLoader> createState() => _AssistantHomeLoaderState();
}

class _AssistantHomeLoaderState extends State<AssistantHomeLoader> {
  late final Future<AssistantSnapshot> _snapshotFuture;

  @override
  void initState() {
    super.initState();
    _snapshotFuture = widget.snapshotFuture ?? loadAssistantSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssistantSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return ErrorScaffold(message: '${snapshot.error}');
        }
        if (!snapshot.hasData) {
          return const LoadingScaffold();
        }
        return AssistantHomePage(snapshot: snapshot.data!);
      },
    );
  }
}

class AssistantHomePage extends StatefulWidget {
  const AssistantHomePage({super.key, required this.snapshot});

  final AssistantSnapshot snapshot;

  @override
  State<AssistantHomePage> createState() => _AssistantHomePageState();
}

class _AssistantHomePageState extends State<AssistantHomePage> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TodayView(snapshot: widget.snapshot),
      MedicationView(snapshot: widget.snapshot),
      RoutineView(snapshot: widget.snapshot),
    ];

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: KeyedSubtree(
            key: ValueKey(_selectedIndex),
            child: pages[_selectedIndex],
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.today_outlined),
            selectedIcon: Icon(Icons.today),
            label: 'Today',
          ),
          NavigationDestination(
            icon: Icon(Icons.medication_outlined),
            selectedIcon: Icon(Icons.medication),
            label: 'Supplements',
          ),
          NavigationDestination(
            icon: Icon(Icons.bedtime_outlined),
            selectedIcon: Icon(Icons.bedtime),
            label: 'Routine',
          ),
        ],
      ),
    );
  }
}

class TodayView extends StatelessWidget {
  const TodayView({super.key, required this.snapshot});

  final AssistantSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        HeaderCard(snapshot: snapshot),
        const SizedBox(height: 20),
        SummaryStrip(snapshot: snapshot),
        const SizedBox(height: 20),
        SectionTitle(
          title: 'Quick actions',
          subtitle: 'Use these for the most common responses.',
        ),
        const SizedBox(height: 12),
        const Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            ActionChipWidget(
              icon: Icons.check_circle_outline,
              label: 'Log morning stack',
            ),
            ActionChipWidget(icon: Icons.snooze, label: 'Delay 30B to 10:30'),
            ActionChipWidget(
              icon: Icons.nightlight_round,
              label: 'Start evening reset',
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionTitle(
          title: 'Today timeline',
          subtitle: 'Supplement and routine checkpoints in one flow.',
        ),
        const SizedBox(height: 12),
        ...snapshot.timeline.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TimelineTile(item: item),
          ),
        ),
      ],
    );
  }
}

class MedicationView extends StatelessWidget {
  const MedicationView({super.key, required this.snapshot});

  final AssistantSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const SectionTitle(
          title: 'Supplement schedule',
          subtitle: 'Normalized from your MDS/MDR exports for local-first use.',
        ),
        const SizedBox(height: 16),
        ...snapshot.doses.map(
          (dose) => Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: MedicationCard(dose: dose),
          ),
        ),
        const SizedBox(height: 8),
        SupplementSetsCard(sets: snapshot.sets),
        const SizedBox(height: 8),
        const Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Data source note',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                SizedBox(height: 8),
                Text(
                  'The current seed data is normalized from data/MDS.json and data/MDR.json because the raw exports contain broken JSON strings and encoding loss.',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class RoutineView extends StatelessWidget {
  const RoutineView({super.key, required this.snapshot});

  final AssistantSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final dayTasks = snapshot.routines
        .where((task) => task.period == RoutinePeriod.day)
        .toList();
    final nightTasks = snapshot.routines
        .where((task) => task.period == RoutinePeriod.night)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const SectionTitle(
          title: 'Day / night routine',
          subtitle:
              'Your current supplement rhythm and support tasks in one place.',
        ),
        const SizedBox(height: 16),
        RoutineBlock(
          title: 'Day rhythm',
          accent: const Color(0xFFE3A257),
          tasks: dayTasks,
        ),
        const SizedBox(height: 16),
        RoutineBlock(
          title: 'Night rhythm',
          accent: const Color(0xFF395D52),
          tasks: nightTasks,
        ),
      ],
    );
  }
}

class HeaderCard extends StatelessWidget {
  const HeaderCard({super.key, required this.snapshot});

  final AssistantSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(32)),
        gradient: LinearGradient(
          colors: [Color(0xFF23463E), Color(0xFF55796E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Assistant',
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFFEFF6F3),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Stay on track with supplements and daily rhythm.',
            style: theme.textTheme.headlineLarge?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 14),
          Text(
            'Next item at ${snapshot.nextDoseTime} | bedtime target ${snapshot.bedtimeTarget}',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFD9E8E2),
            ),
          ),
        ],
      ),
    );
  }
}

class SummaryStrip extends StatelessWidget {
  const SummaryStrip({super.key, required this.snapshot});

  final AssistantSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SummaryCard(
            label: 'Adherence',
            value: '${snapshot.adherencePercent}%',
            detail: 'weekly',
            accent: const Color(0xFF395D52),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryCard(
            label: 'Pending',
            value: '${snapshot.pendingCount}',
            detail: 'items',
            accent: const Color(0xFFE3A257),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SummaryCard(
            label: 'Focus block',
            value: snapshot.focusWindow,
            detail: 'today',
            accent: const Color(0xFF8FA68E),
          ),
        ),
      ],
    );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
  });

  final String label;
  final String value;
  final String detail;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(height: 18),
            Text(value, style: theme.textTheme.headlineSmall),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(detail, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class ActionChipWidget extends StatelessWidget {
  const ActionChipWidget({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 18, color: const Color(0xFF23463E)),
      label: Text(label),
      backgroundColor: Colors.white,
      side: const BorderSide(color: Color(0xFFD5DDD8)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
    );
  }
}

class TimelineTile extends StatelessWidget {
  const TimelineTile({super.key, required this.item});

  final TimelineItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: item.status.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(item.icon, color: item.status.color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.title,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Text(item.time, style: theme.textTheme.bodyMedium),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(item.note, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 10),
                  StatusPill(
                    label: item.status.label,
                    color: item.status.color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MedicationCard extends StatelessWidget {
  const MedicationCard({super.key, required this.dose});

  final MedicationDose dose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(dose.name, style: theme.textTheme.headlineSmall),
                ),
                StatusPill(label: dose.status.label, color: dose.status.color),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '${dose.dosage} | ${dose.instructions}',
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                MetadataPill(icon: Icons.schedule, label: dose.time),
                MetadataPill(icon: Icons.restaurant, label: dose.mealTiming),
                MetadataPill(icon: Icons.notes, label: dose.note),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoutineBlock extends StatelessWidget {
  const RoutineBlock({
    super.key,
    required this.title,
    required this.accent,
    required this.tasks,
  });

  final String title;
  final Color accent;
  final List<RoutineTask> tasks;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(title, style: theme.textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 16),
          ...tasks.map(
            (task) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(task.icon, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(task.title, style: theme.textTheme.titleMedium),
                        const SizedBox(height: 3),
                        Text(
                          '${task.time} | ${task.note}',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: task.status.label,
                    color: task.status.color,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(subtitle, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
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
            Flexible(
              child: Text(label, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }
}

class LoadingScaffold extends StatelessWidget {
  const LoadingScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

class ErrorScaffold extends StatelessWidget {
  const ErrorScaffold({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unable to load PA data', style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 12),
                  Text(
                    'Check the root data directory and ensure MDS.json and MDR.json are valid UTF-8 JSON files.',
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 12),
                  Text(message, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SupplementSetsCard extends StatelessWidget {
  const SupplementSetsCard({super.key, required this.sets});

  final List<SupplementSet> sets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Supplement sets', style: theme.textTheme.headlineSmall),
            const SizedBox(height: 8),
            Text(
              'Grouped directly from your source list so the app can show the recurring stacks.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ...sets.map(
              (set) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(set.name, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(set.note, style: theme.textTheme.bodyMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final item in set.items)
                          MetadataPill(icon: Icons.auto_awesome, label: item),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

@Preview(name: 'AssistantHomePage')
Widget previewAssistantHomePage() {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AssistantHomePage(snapshot: AssistantSnapshot.sample()),
  );
}
