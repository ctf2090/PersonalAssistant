import 'package:flutter/material.dart';
import 'package:flutter/widget_previews.dart';

void main() {
  runApp(const PersonalAssistantApp());
}

class PersonalAssistantApp extends StatelessWidget {
  const PersonalAssistantApp({super.key});

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
      home: const AssistantHomePage(),
    );
  }
}

class AssistantHomePage extends StatefulWidget {
  const AssistantHomePage({super.key});

  @override
  State<AssistantHomePage> createState() => _AssistantHomePageState();
}

class _AssistantHomePageState extends State<AssistantHomePage> {
  int _selectedIndex = 0;
  final AssistantSnapshot _snapshot = AssistantSnapshot.sample();

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      TodayView(snapshot: _snapshot),
      MedicationView(snapshot: _snapshot),
      RoutineView(snapshot: _snapshot),
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
          note: 'Keep the probiotic around 10:00 as the fixed morning follow-up.',
          time: '10:00',
          icon: Icons.biotech_outlined,
          status: ItemStatus.scheduled,
        ),
        TimelineItem(
          title: 'Meal-dependent support',
          note: 'Use BPG, Lacto, or GlutenEase only when the meal requires them.',
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
          mealTiming: 'Morning stack',
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
          note: 'Use BPG, Lacto, or GlutenEase only when the meal needs support.',
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
          note: 'Use the ASH slot after dinner and keep diltiazem in the evening plan.',
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
        ),
      ],
    );
  }
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
  });

  final String title;
  final String time;
  final String note;
  final IconData icon;
  final RoutinePeriod period;
  final ItemStatus status;
}

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

@Preview(name: 'AssistantHomePage')
Widget previewAssistantHomePage() {
  return const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: AssistantHomePage(),
  );
}
