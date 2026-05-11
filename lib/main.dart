import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

const appName = 'CAVACIUTI MELEARD MARIE-THERES';
const companyName = 'CAVACIUTI MELEARD MARIE-THERESE';
const supportEmail = 'support@cavaciuti-meleard.fr';
const recordStoreKey = 'operation_records_v1';
const compactModeKey = 'compact_cards_v1';
const screenshotMode = bool.fromEnvironment('SCREENSHOT_MODE');

const brandNavy = Color(0xFF071B2C);
const brandTeal = Color(0xFF0B6D84);
const brandGold = Color(0xFFC18B2D);
const brandMist = Color(0xFFEAF3F1);
const brandInk = Color(0xFF13242B);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = OperationsStore(screenshotMode: screenshotMode);
  await store.load();
  runApp(OperationsApp(store: store));
}

class OperationsApp extends StatelessWidget {
  const OperationsApp({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(seedColor: brandTeal);
    final scheme = baseScheme.copyWith(
      primary: brandTeal,
      onPrimary: Colors.white,
      secondary: brandGold,
      onSecondary: brandNavy,
      surface: const Color(0xFFF7FAF9),
      onSurface: brandInk,
    );

    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF4F7F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: brandNavy,
          foregroundColor: Colors.white,
          centerTitle: false,
        ),
        chipTheme: ChipThemeData(
          selectedColor: brandTeal.withValues(alpha: 0.16),
          checkmarkColor: brandTeal,
          side: BorderSide(color: brandTeal.withValues(alpha: 0.18)),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: brandTeal.withValues(alpha: 0.22)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: Colors.white,
          indicatorColor: brandTeal.withValues(alpha: 0.14),
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ),
      ),
      home: OperationsShell(store: store),
    );
  }
}

class OperationsStore extends ChangeNotifier {
  OperationsStore({
    required this.screenshotMode,
    List<OperationRecord>? initialRecords,
  }) : _records = initialRecords ?? const [];

  final bool screenshotMode;
  List<OperationRecord> _records;
  SharedPreferences? _prefs;
  bool _compactCards = false;

  List<OperationRecord> get records => List.unmodifiable(_records);
  bool get compactCards => _compactCards;

  Future<void> load() async {
    if (screenshotMode) {
      _records = screenshotRecords;
      _compactCards = false;
      notifyListeners();
      return;
    }

    _prefs = await SharedPreferences.getInstance();
    _compactCards = _prefs?.getBool(compactModeKey) ?? false;
    final encoded = _prefs?.getString(recordStoreKey);
    if (encoded == null || encoded.isEmpty) {
      _records = [];
      notifyListeners();
      return;
    }

    final decoded = jsonDecode(encoded);
    if (decoded is List) {
      _records = [
        for (final item in decoded)
          if (item is Map<String, dynamic>)
            OperationRecord.fromJson(item)
          else if (item is Map)
            OperationRecord.fromJson(Map<String, dynamic>.from(item)),
      ];
    }
    notifyListeners();
  }

  Future<void> addRecord(OperationRecord record) async {
    _records = [record, ..._records];
    notifyListeners();
    await _persist();
  }

  Future<void> updateRecord(OperationRecord updated) async {
    _records = [
      for (final record in _records)
        if (record.id == updated.id) updated else record,
    ];
    notifyListeners();
    await _persist();
  }

  Future<void> clearRecords() async {
    _records = [];
    notifyListeners();
    await _persist();
  }

  Future<void> setCompactCards(bool value) async {
    _compactCards = value;
    notifyListeners();
    if (!screenshotMode) {
      await _prefs?.setBool(compactModeKey, value);
    }
  }

  Future<void> _persist() async {
    if (screenshotMode) {
      return;
    }
    final prefs = _prefs ??= await SharedPreferences.getInstance();
    final encoded = jsonEncode(
      _records.map((record) => record.toJson()).toList(),
    );
    await prefs.setString(recordStoreKey, encoded);
  }
}

enum RecordKind { reservation, incident, lead, workOrder }

enum OperationStatus { open, scheduled, inProgress, complete }

extension RecordKindLabels on RecordKind {
  String get label {
    switch (this) {
      case RecordKind.reservation:
        return 'Reservation';
      case RecordKind.incident:
        return 'Incident';
      case RecordKind.lead:
        return 'Lead';
      case RecordKind.workOrder:
        return 'Work order';
    }
  }

  IconData get icon {
    switch (this) {
      case RecordKind.reservation:
        return Icons.event_available_outlined;
      case RecordKind.incident:
        return Icons.report_problem_outlined;
      case RecordKind.lead:
        return Icons.person_search_outlined;
      case RecordKind.workOrder:
        return Icons.task_alt_outlined;
    }
  }

  Color get color {
    switch (this) {
      case RecordKind.reservation:
        return brandTeal;
      case RecordKind.incident:
        return const Color(0xFFB64A2A);
      case RecordKind.lead:
        return brandGold;
      case RecordKind.workOrder:
        return const Color(0xFF3B6C46);
    }
  }
}

extension OperationStatusLabels on OperationStatus {
  String get label {
    switch (this) {
      case OperationStatus.open:
        return 'Open';
      case OperationStatus.scheduled:
        return 'Scheduled';
      case OperationStatus.inProgress:
        return 'In progress';
      case OperationStatus.complete:
        return 'Complete';
    }
  }

  OperationStatus get next {
    switch (this) {
      case OperationStatus.open:
        return OperationStatus.scheduled;
      case OperationStatus.scheduled:
        return OperationStatus.inProgress;
      case OperationStatus.inProgress:
        return OperationStatus.complete;
      case OperationStatus.complete:
        return OperationStatus.complete;
    }
  }
}

class OperationRecord {
  const OperationRecord({
    required this.id,
    required this.title,
    required this.owner,
    required this.notes,
    required this.kind,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.dueAt,
  });

  final String id;
  final String title;
  final String owner;
  final String notes;
  final RecordKind kind;
  final OperationStatus status;
  final int priority;
  final DateTime createdAt;
  final DateTime dueAt;

  OperationRecord copyWith({
    String? title,
    String? owner,
    String? notes,
    RecordKind? kind,
    OperationStatus? status,
    int? priority,
    DateTime? dueAt,
  }) {
    return OperationRecord(
      id: id,
      title: title ?? this.title,
      owner: owner ?? this.owner,
      notes: notes ?? this.notes,
      kind: kind ?? this.kind,
      status: status ?? this.status,
      priority: priority ?? this.priority,
      createdAt: createdAt,
      dueAt: dueAt ?? this.dueAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'owner': owner,
      'notes': notes,
      'kind': kind.name,
      'status': status.name,
      'priority': priority,
      'createdAt': createdAt.toIso8601String(),
      'dueAt': dueAt.toIso8601String(),
    };
  }

  factory OperationRecord.fromJson(Map<String, dynamic> json) {
    return OperationRecord(
      id:
          json['id'] as String? ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      title: json['title'] as String? ?? 'Untitled record',
      owner: json['owner'] as String? ?? 'Unassigned',
      notes: json['notes'] as String? ?? '',
      kind: RecordKind.values.byName(
        json['kind'] as String? ?? RecordKind.workOrder.name,
      ),
      status: OperationStatus.values.byName(
        json['status'] as String? ?? OperationStatus.open.name,
      ),
      priority: json['priority'] as int? ?? 3,
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.now(),
      dueAt:
          DateTime.tryParse(json['dueAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

final screenshotRecords = <OperationRecord>[
  OperationRecord(
    id: 'reservation-suite',
    title: 'Confirm VIP suite reservation',
    owner: 'Marie operations',
    notes:
        'Validate arrival time, room readiness, and evening service notes before 17:00.',
    kind: RecordKind.reservation,
    status: OperationStatus.scheduled,
    priority: 5,
    createdAt: DateTime(2026, 5, 11, 8, 15),
    dueAt: DateTime(2026, 5, 11, 17),
  ),
  OperationRecord(
    id: 'incident-lobby',
    title: 'Lobby access reader fault',
    owner: 'Facilities desk',
    notes:
        'Badge reader is intermittent. Keep manual check-in active until replacement is complete.',
    kind: RecordKind.incident,
    status: OperationStatus.inProgress,
    priority: 4,
    createdAt: DateTime(2026, 5, 11, 9),
    dueAt: DateTime(2026, 5, 11, 14),
  ),
  OperationRecord(
    id: 'lead-catering',
    title: 'Corporate catering lead',
    owner: 'Sales desk',
    notes:
        'Prepare weekday menu options and call back with two package choices.',
    kind: RecordKind.lead,
    status: OperationStatus.open,
    priority: 3,
    createdAt: DateTime(2026, 5, 10, 15),
    dueAt: DateTime(2026, 5, 12, 11),
  ),
  OperationRecord(
    id: 'order-kitchen',
    title: 'Kitchen extractor service',
    owner: 'Maintenance',
    notes:
        'Technician booked. Confirm access, isolate the zone, and log completion notes.',
    kind: RecordKind.workOrder,
    status: OperationStatus.scheduled,
    priority: 4,
    createdAt: DateTime(2026, 5, 9, 13),
    dueAt: DateTime(2026, 5, 13, 10),
  ),
  OperationRecord(
    id: 'reservation-workshop',
    title: 'Workshop room reset',
    owner: 'Front office',
    notes: 'Reset seating to boardroom format and confirm projector readiness.',
    kind: RecordKind.reservation,
    status: OperationStatus.complete,
    priority: 2,
    createdAt: DateTime(2026, 5, 8, 16),
    dueAt: DateTime(2026, 5, 10, 18),
  ),
  OperationRecord(
    id: 'lead-renewal',
    title: 'Renewal discussion with local partner',
    owner: 'Management',
    notes: 'Review previous service notes, proposed terms, and follow-up date.',
    kind: RecordKind.lead,
    status: OperationStatus.inProgress,
    priority: 5,
    createdAt: DateTime(2026, 5, 7, 11),
    dueAt: DateTime(2026, 5, 14, 9),
  ),
];

class OperationsShell extends StatefulWidget {
  const OperationsShell({super.key, required this.store});

  final OperationsStore store;

  @override
  State<OperationsShell> createState() => _OperationsShellState();
}

class _OperationsShellState extends State<OperationsShell> {
  int _index = 0;

  static const _titles = ['Today', 'Workboard', 'Pipeline', 'Privacy'];

  void _openNewRecord() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RecordFormScreen(store: widget.store)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(store: widget.store),
      WorkboardScreen(store: widget.store),
      PipelineScreen(store: widget.store),
      SettingsScreen(store: widget.store),
    ];

    return AnimatedBuilder(
      animation: widget.store,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              _titles[_index],
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            actions: [
              IconButton(
                key: const Key('appBarNewRecord'),
                tooltip: 'New record',
                onPressed: _openNewRecord,
                icon: const Icon(Icons.add_task_outlined),
              ),
            ],
          ),
          body: IndexedStack(index: _index, children: screens),
          floatingActionButton: _index == 3
              ? null
              : FloatingActionButton.extended(
                  key: const Key('newRecordButton'),
                  onPressed: _openNewRecord,
                  icon: const Icon(Icons.add),
                  label: const Text('New'),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (value) => setState(() => _index = value),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.view_kanban_outlined),
                selectedIcon: Icon(Icons.view_kanban),
                label: 'Work',
              ),
              NavigationDestination(
                icon: Icon(Icons.leaderboard_outlined),
                selectedIcon: Icon(Icons.leaderboard),
                label: 'Pipeline',
              ),
              NavigationDestination(
                icon: Icon(Icons.privacy_tip_outlined),
                selectedIcon: Icon(Icons.privacy_tip),
                label: 'Privacy',
              ),
            ],
          ),
        );
      },
    );
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    final records = store.records;
    final openCount = records
        .where((record) => record.status != OperationStatus.complete)
        .length;
    final dueToday = records
        .where((record) => isSameDay(record.dueAt, DateTime.now()))
        .length;
    final incidents = records
        .where((record) => record.kind == RecordKind.incident)
        .length;
    final leads = records
        .where((record) => record.kind == RecordKind.lead)
        .length;
    final focused =
        records
            .where((record) => record.status != OperationStatus.complete)
            .toList()
          ..sort((a, b) => b.priority.compareTo(a.priority));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
      children: [
        const HeroSummaryCard(),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 680 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              childAspectRatio: constraints.maxWidth > 680 ? 1.55 : 1.35,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                MetricCard(
                  label: 'Active items',
                  value: '$openCount',
                  icon: Icons.bolt_outlined,
                ),
                MetricCard(
                  label: 'Due today',
                  value: '$dueToday',
                  icon: Icons.today_outlined,
                ),
                MetricCard(
                  label: 'Incidents',
                  value: '$incidents',
                  icon: Icons.warning_amber,
                ),
                MetricCard(
                  label: 'Leads',
                  value: '$leads',
                  icon: Icons.trending_up,
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        SectionHeader(
          title: 'Priority queue',
          action: '${focused.length} active',
        ),
        const SizedBox(height: 10),
        if (focused.isEmpty)
          const EmptyState(
            icon: Icons.task_alt,
            title: 'No active work',
            body: 'Create a record to start tracking daily operations locally.',
          )
        else
          for (final record in focused.take(4))
            RecordListTile(
              record: record,
              compact: store.compactCards,
              onTap: () => openRecordDetail(context, store, record),
            ),
      ],
    );
  }
}

class HeroSummaryCard extends StatelessWidget {
  const HeroSummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: brandNavy,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: brandNavy.withValues(alpha: 0.14),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'docs/featured.png',
              fit: BoxFit.cover,
              opacity: const AlwaysStoppedAnimation(0.32),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: const EdgeInsets.all(6),
                      child: Image.asset('docs/icon.png'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        appName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  'Daily operations cockpit',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Coordinate reservations, incidents, leads, and work orders from one local workspace.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.86),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: brandTeal, size: 26),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: brandNavy,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: brandInk.withValues(alpha: 0.68),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkboardScreen extends StatefulWidget {
  const WorkboardScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  State<WorkboardScreen> createState() => _WorkboardScreenState();
}

class _WorkboardScreenState extends State<WorkboardScreen> {
  RecordKind? _filter;

  @override
  Widget build(BuildContext context) {
    final records =
        widget.store.records
            .where((record) => _filter == null || record.kind == _filter)
            .toList()
          ..sort((a, b) => a.dueAt.compareTo(b.dueAt));

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('All'),
              selected: _filter == null,
              onSelected: (_) => setState(() => _filter = null),
            ),
            for (final kind in RecordKind.values)
              ChoiceChip(
                avatar: Icon(kind.icon, size: 18),
                label: Text(kind.label),
                selected: _filter == kind,
                onSelected: (_) => setState(() => _filter = kind),
              ),
          ],
        ),
        const SizedBox(height: 16),
        SectionHeader(
          title: 'Operational records',
          action: '${records.length} shown',
        ),
        const SizedBox(height: 10),
        if (records.isEmpty)
          const EmptyState(
            icon: Icons.inbox_outlined,
            title: 'No records yet',
            body:
                'Add a reservation, incident, lead, or work order to build the board.',
          )
        else
          for (final record in records)
            RecordListTile(
              record: record,
              compact: widget.store.compactCards,
              onTap: () => openRecordDetail(context, widget.store, record),
            ),
      ],
    );
  }
}

class PipelineScreen extends StatelessWidget {
  const PipelineScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    final records = store.records;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 96),
      children: [
        SectionHeader(
          title: 'Status lanes',
          action: '${records.length} records',
        ),
        const SizedBox(height: 10),
        for (final status in OperationStatus.values)
          StatusLane(
            status: status,
            records: records
                .where((record) => record.status == status)
                .toList(),
            store: store,
          ),
        const SizedBox(height: 14),
        SectionHeader(title: 'Lead and order focus', action: 'Local only'),
        const SizedBox(height: 10),
        FocusPanel(records: records),
      ],
    );
  }
}

class StatusLane extends StatelessWidget {
  const StatusLane({
    super.key,
    required this.status,
    required this.records,
    required this.store,
  });

  final OperationStatus status;
  final List<OperationRecord> records;
  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    final accent = status == OperationStatus.complete
        ? const Color(0xFF3B6C46)
        : brandTeal;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    status.label,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text('${records.length}'),
              ],
            ),
            const SizedBox(height: 10),
            if (records.isEmpty)
              Text(
                'No items in this lane.',
                style: TextStyle(color: brandInk.withValues(alpha: 0.62)),
              )
            else
              for (final record in records.take(2))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    backgroundColor: record.kind.color.withValues(alpha: 0.14),
                    foregroundColor: record.kind.color,
                    child: Icon(record.kind.icon),
                  ),
                  title: Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${record.kind.label} - due ${formatDate(record.dueAt)}',
                  ),
                  onTap: () => openRecordDetail(context, store, record),
                ),
          ],
        ),
      ),
    );
  }
}

class FocusPanel extends StatelessWidget {
  const FocusPanel({super.key, required this.records});

  final List<OperationRecord> records;

  @override
  Widget build(BuildContext context) {
    final leadCount = records
        .where((record) => record.kind == RecordKind.lead)
        .length;
    final orderCount = records
        .where((record) => record.kind == RecordKind.workOrder)
        .length;
    final highPriority = records.where((record) => record.priority >= 4).length;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: brandNavy,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Commercial and service follow-through',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FocusStat(value: '$leadCount', label: 'Leads'),
                ),
                Expanded(
                  child: FocusStat(value: '$orderCount', label: 'Orders'),
                ),
                Expanded(
                  child: FocusStat(value: '$highPriority', label: 'Priority'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FocusStat extends StatelessWidget {
  const FocusStat({super.key, required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            color: brandGold,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
      children: [
        Card(
          margin: EdgeInsets.zero,
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                Image.asset('docs/icon.png', width: 58, height: 58),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      SizedBox(height: 4),
                      Text(companyName),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        SwitchListTile(
          value: store.compactCards,
          onChanged: store.setCompactCards,
          title: const Text('Compact record cards'),
          subtitle: const Text('Save preference locally on this device.'),
          secondary: const Icon(Icons.compress_outlined),
        ),
        const SizedBox(height: 10),
        const InfoPanel(
          icon: Icons.lock_outline,
          title: 'Local storage only',
          body:
              'Records and preferences stay on this device. The app has no account sign-in, cloud sync, analytics, advertising, or external service connection.',
        ),
        const SizedBox(height: 10),
        InfoPanel(
          icon: Icons.support_agent_outlined,
          title: 'Support contact',
          body: '$companyName\n$supportEmail',
        ),
        const SizedBox(height: 10),
        FilledButton.tonalIcon(
          onPressed: store.records.isEmpty
              ? null
              : () => confirmClear(context, store),
          icon: const Icon(Icons.delete_outline),
          label: const Text('Clear local records'),
        ),
      ],
    );
  }
}

class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: brandMist,
          foregroundColor: brandTeal,
          child: Icon(icon),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(body),
      ),
    );
  }
}

class RecordListTile extends StatelessWidget {
  const RecordListTile({
    super.key,
    required this.record,
    required this.compact,
    required this.onTap,
  });

  final OperationRecord record;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: record.kind.color.withValues(alpha: 0.14),
                foregroundColor: record.kind.color,
                child: Icon(record.kind.icon),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                        const SizedBox(width: 8),
                        StatusChip(status: record.status),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${record.kind.label} - ${record.owner}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: brandInk.withValues(alpha: 0.68)),
                    ),
                    if (!compact) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.flag_outlined, size: 16, color: brandGold),
                          const SizedBox(width: 4),
                          Text('Priority ${record.priority}'),
                          const SizedBox(width: 12),
                          Icon(Icons.schedule, size: 16, color: brandTeal),
                          const SizedBox(width: 4),
                          Text('Due ${formatDate(record.dueAt)}'),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final OperationStatus status;

  @override
  Widget build(BuildContext context) {
    final done = status == OperationStatus.complete;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: done ? const Color(0xFFE7F3EA) : brandMist,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          color: done ? const Color(0xFF2D6338) : brandTeal,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class RecordDetailScreen extends StatelessWidget {
  const RecordDetailScreen({
    super.key,
    required this.store,
    required this.recordId,
  });

  final OperationsStore store;
  final String recordId;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final record = store.records.firstWhere((item) => item.id == recordId);
        final completed = record.status == OperationStatus.complete;

        return Scaffold(
          appBar: AppBar(title: const Text('Record detail')),
          body: ListView(
            padding: const EdgeInsets.all(18),
            children: [
              Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: record.kind.color.withValues(
                              alpha: 0.14,
                            ),
                            foregroundColor: record.kind.color,
                            child: Icon(record.kind.icon),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              record.kind.label,
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          StatusChip(status: record.status),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        record.title,
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: brandNavy,
                            ),
                      ),
                      const SizedBox(height: 10),
                      Text(record.notes),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              DetailGrid(record: record),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: completed
                    ? null
                    : () => store.updateRecord(
                        record.copyWith(status: record.status.next),
                      ),
                icon: const Icon(Icons.arrow_forward),
                label: Text(
                  completed
                      ? 'Complete'
                      : 'Move to ${record.status.next.label}',
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DetailGrid extends StatelessWidget {
  const DetailGrid({super.key, required this.record});

  final OperationRecord record;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.45,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        DetailTile(
          label: 'Owner',
          value: record.owner,
          icon: Icons.person_outline,
        ),
        DetailTile(
          label: 'Due',
          value: formatDate(record.dueAt),
          icon: Icons.event_outlined,
        ),
        DetailTile(
          label: 'Priority',
          value: '${record.priority}/5',
          icon: Icons.flag_outlined,
        ),
        DetailTile(
          label: 'Created',
          value: formatDate(record.createdAt),
          icon: Icons.history,
        ),
      ],
    );
  }
}

class DetailTile extends StatelessWidget {
  const DetailTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: brandTeal),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(color: brandInk.withValues(alpha: 0.62)),
                ),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RecordFormScreen extends StatefulWidget {
  const RecordFormScreen({super.key, required this.store});

  final OperationsStore store;

  @override
  State<RecordFormScreen> createState() => _RecordFormScreenState();
}

class _RecordFormScreenState extends State<RecordFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _owner = TextEditingController();
  final _notes = TextEditingController();
  RecordKind _kind = RecordKind.reservation;
  OperationStatus _status = OperationStatus.open;
  int _priority = 3;
  int _dueDays = 1;

  @override
  void dispose() {
    _title.dispose();
    _owner.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final now = DateTime.now();
    final record = OperationRecord(
      id: now.microsecondsSinceEpoch.toString(),
      title: _title.text.trim(),
      owner: _owner.text.trim(),
      notes: _notes.text.trim().isEmpty
          ? 'No extra notes added.'
          : _notes.text.trim(),
      kind: _kind,
      status: _status,
      priority: _priority,
      createdAt: now,
      dueAt: now.add(Duration(days: _dueDays)),
    );

    await widget.store.addRecord(record);
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New record')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(18),
          children: [
            TextFormField(
              key: const Key('titleField'),
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.edit_outlined),
              ),
              textInputAction: TextInputAction.next,
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('ownerField'),
              controller: _owner,
              decoration: const InputDecoration(
                labelText: 'Owner',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
              validator: requiredText,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RecordKind>(
              initialValue: _kind,
              decoration: const InputDecoration(
                labelText: 'Type',
                prefixIcon: Icon(Icons.category_outlined),
              ),
              items: [
                for (final kind in RecordKind.values)
                  DropdownMenuItem(value: kind, child: Text(kind.label)),
              ],
              onChanged: (value) => setState(() => _kind = value ?? _kind),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<OperationStatus>(
              initialValue: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                prefixIcon: Icon(Icons.linear_scale),
              ),
              items: [
                for (final status in OperationStatus.values)
                  DropdownMenuItem(value: status, child: Text(status.label)),
              ],
              onChanged: (value) => setState(() => _status = value ?? _status),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _dueDays,
              decoration: const InputDecoration(
                labelText: 'Due window',
                prefixIcon: Icon(Icons.event_outlined),
              ),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Today')),
                DropdownMenuItem(value: 1, child: Text('Tomorrow')),
                DropdownMenuItem(value: 3, child: Text('In 3 days')),
                DropdownMenuItem(value: 7, child: Text('In 1 week')),
              ],
              onChanged: (value) =>
                  setState(() => _dueDays = value ?? _dueDays),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notes',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
              minLines: 3,
              maxLines: 5,
            ),
            const SizedBox(height: 18),
            Card(
              elevation: 0,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Priority $_priority',
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    Slider(
                      value: _priority.toDouble(),
                      min: 1,
                      max: 5,
                      divisions: 4,
                      label: 'Priority $_priority',
                      onChanged: (value) =>
                          setState(() => _priority = value.round()),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const Key('saveRecordButton'),
              onPressed: _save,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Save record'),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, required this.action});

  final String title;
  final String action;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: brandNavy,
            ),
          ),
        ),
        Text(
          action,
          style: TextStyle(color: brandTeal, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(icon, size: 42, color: brandTeal),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: TextStyle(color: brandInk.withValues(alpha: 0.68)),
            ),
          ],
        ),
      ),
    );
  }
}

String? requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Required';
  }
  return null;
}

void openRecordDetail(
  BuildContext context,
  OperationsStore store,
  OperationRecord record,
) {
  Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => RecordDetailScreen(store: store, recordId: record.id),
    ),
  );
}

Future<void> confirmClear(BuildContext context, OperationsStore store) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Clear records?'),
      content: const Text(
        'This removes locally saved operational records from this device.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Clear'),
        ),
      ],
    ),
  );

  if (confirmed == true) {
    await store.clearRecords();
  }
}

bool isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String formatDate(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[date.month - 1]} ${date.day}';
}
