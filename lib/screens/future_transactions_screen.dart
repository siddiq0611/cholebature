import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/future_transaction_model.dart';
import '../models/transaction_model.dart';
import '../providers/future_transaction_provider.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/category_icon.dart';
import 'add_future_transaction_sheet.dart';

class FutureTransactionsScreen extends ConsumerWidget {
  const FutureTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ftAsync = ref.watch(futureTransactionProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: context.appBg,
            floating: true,
            snap: true,
            title: Text(
              'Scheduled',
              style: GoogleFonts.dmSans(
                color: context.appTextPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => AddFutureTransactionSheet(),
                ),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  margin: const EdgeInsets.only(right: 16),
                  decoration: BoxDecoration(
                    color: context.appAccent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_rounded,
                          color: Colors.white, size: 18),
                      const Gap(4),
                      Text(
                        'Schedule',
                        style: GoogleFonts.dmSans(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          ftAsync.when(
            loading: () => SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                  color: context.appAccent,
                  strokeCap: StrokeCap.round,
                ),
              ),
            ),
            error: (e, _) => SliverFillRemaining(
              child: Center(
                child: Text('Error: $e',
                    style: TextStyle(color: context.appExpense)),
              ),
            ),
            data: (list) {
              if (list.isEmpty) {
                return SliverFillRemaining(
                  child: _EmptyState(),
                );
              }

              final overdue =
                  list.where((ft) => ft.isOverdue).toList();
              final dueToday =
                  list.where((ft) => ft.isDueToday && !ft.isOverdue).toList();
              final upcoming = list
                  .where((ft) => !ft.isOverdue && !ft.isDueToday)
                  .toList();

              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (overdue.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Overdue',
                          color: context.appExpense,
                          count: overdue.length),
                      const Gap(8),
                      ...overdue.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FutureTransactionTile(
                                ft: e.value,
                                index: e.key,
                              ),
                            ),
                          ),
                      const Gap(8),
                    ],
                    if (dueToday.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Due Today',
                          color: context.appBorrowed,
                          count: dueToday.length),
                      const Gap(8),
                      ...dueToday.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FutureTransactionTile(
                                ft: e.value,
                                index: e.key,
                              ),
                            ),
                          ),
                      const Gap(8),
                    ],
                    if (upcoming.isNotEmpty) ...[
                      _SectionHeader(
                          label: 'Upcoming',
                          color: context.appTextSecondary,
                          count: upcoming.length),
                      const Gap(8),
                      ...upcoming.asMap().entries.map(
                            (e) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: FutureTransactionTile(
                                ft: e.value,
                                index: e.key,
                              ),
                            ),
                          ),
                    ],
                  ]),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final int count;

  const _SectionHeader(
      {required this.label, required this.color, required this.count});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const Gap(8),
        Text(
          label,
          style: GoogleFonts.dmSans(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
          ),
        ),
        const Gap(6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '$count',
            style: GoogleFonts.dmSans(
                color: color, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class FutureTransactionTile extends ConsumerWidget {
  final FutureTransaction ft;
  final int index;

  const FutureTransactionTile(
      {super.key, required this.ft, required this.index});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = categoryInfoMap[ft.category]!;
    final notifier = ref.read(futureTransactionProvider.notifier);

    Color statusColor;
    String statusLabel;
    if (ft.isOverdue) {
      statusColor = context.appExpense;
      statusLabel = 'Overdue';
    } else if (ft.isDueToday) {
      statusColor = context.appBorrowed;
      statusLabel = 'Due Today';
    } else if (ft.status == FutureStatus.paused) {
      statusColor = context.appTextMuted;
      statusLabel = 'Paused';
    } else {
      statusColor = context.appAccent;
      statusLabel = 'Upcoming';
    }

    final isIncome = ft.type == TransactionType.income;
    final amountColor =
        isIncome ? context.appIncome : context.appExpense;
    final amountPrefix = isIncome ? '+' : '-';

    return GestureDetector(
      onTap: () => _showOptions(context, ref, notifier),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: context.appSurfaceElevated,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ft.isOverdue
                ? context.appExpense.withValues(alpha: 0.4)
                : ft.isDueToday
                    ? context.appBorrowed.withValues(alpha: 0.4)
                    : context.appBorder,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(
                    category: ft.category, size: 42, iconSize: 18),
                const Gap(12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ft.title.isNotEmpty ? ft.title : info.label,
                        style: GoogleFonts.dmSans(
                          color: context.appTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const Gap(2),
                      Row(
                        children: [
                          Icon(Icons.calendar_today_rounded,
                              size: 11, color: context.appTextMuted),
                          const Gap(4),
                          Text(
                            formatDate(ft.nextDue),
                            style: GoogleFonts.dmSans(
                                color: context.appTextMuted, fontSize: 11),
                          ),
                          const Gap(8),
                          Icon(Icons.repeat_rounded,
                              size: 11, color: context.appTextMuted),
                          const Gap(4),
                          Text(
                            ft.recurrenceLabel,
                            style: GoogleFonts.dmSans(
                                color: context.appTextMuted, fontSize: 11),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$amountPrefix₹${ft.amount.toStringAsFixed(0)}',
                      style: GoogleFonts.dmSans(
                        color: amountColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap(4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        statusLabel,
                        style: GoogleFonts.dmSans(
                          color: statusColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (ft.reminderOffsets.isNotEmpty) ...[
              const Gap(10),
              Row(
                children: [
                  Icon(Icons.notifications_rounded,
                      size: 12, color: context.appTextMuted),
                  const Gap(4),
                  Text(
                    _remindersLabel(ft.reminderOffsets),
                    style: GoogleFonts.dmSans(
                        color: context.appTextMuted, fontSize: 11),
                  ),
                ],
              ),
            ],
            // Action buttons for overdue/due today
            if (ft.isOverdue || ft.isDueToday) ...[
              const Gap(10),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: 'Mark Done',
                      icon: Icons.check_circle_rounded,
                      color: context.appIncome,
                      onTap: () => _markDone(context, notifier),
                    ),
                  ),
                  const Gap(8),
                  Expanded(
                    child: _ActionButton(
                      label: 'Skip',
                      icon: Icons.skip_next_rounded,
                      color: context.appTextSecondary,
                      onTap: () => notifier.skipCycle(ft),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(duration: 300.ms, delay: (index * 40).ms)
        .slideX(begin: -0.04, end: 0, duration: 300.ms, delay: (index * 40).ms);
  }

  String _remindersLabel(List<int> offsets) {
    if (offsets.isEmpty) return 'No reminders';
    final labels = offsets.map((o) {
      if (o == 0) return 'At due time';
      if (o < 60) return '${o}m before';
      if (o < 1440) return '${o ~/ 60}h before';
      return '${o ~/ 1440}d before';
    });
    return labels.join(' · ');
  }

  Future<void> _markDone(
      BuildContext context, FutureTransactionNotifier notifier) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: ft.nextDue.subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      helpText: 'Select transaction date',
    );
    await notifier.markDone(ft, recordDate: picked ?? DateTime.now());
  }

  void _showOptions(BuildContext context, WidgetRef ref,
      FutureTransactionNotifier notifier) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _OptionsSheet(ft: ft, notifier: notifier),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 14),
            const Gap(5),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OptionsSheet extends ConsumerWidget {
  final FutureTransaction ft;
  final FutureTransactionNotifier notifier;

  const _OptionsSheet({required this.ft, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isPaused = ft.status == FutureStatus.paused;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const Gap(16),
          Text(
            ft.title.isNotEmpty ? ft.title : 'Scheduled Transaction',
            style: GoogleFonts.dmSans(
              color: context.appTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Gap(16),
          _OptionTile(
            icon: Icons.check_circle_rounded,
            label: 'Mark as Done',
            color: context.appIncome,
            onTap: () async {
              Navigator.pop(context);
              final picked = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate:
                    ft.nextDue.subtract(const Duration(days: 30)),
                lastDate: DateTime.now().add(const Duration(days: 1)),
              );
              await notifier.markDone(ft,
                  recordDate: picked ?? DateTime.now());
            },
          ),
          _OptionTile(
            icon: Icons.skip_next_rounded,
            label: 'Skip This Cycle',
            color: context.appBorrowed,
            onTap: () {
              Navigator.pop(context);
              notifier.skipCycle(ft);
            },
          ),
          _OptionTile(
            icon: isPaused
                ? Icons.play_circle_rounded
                : Icons.pause_circle_rounded,
            label: isPaused ? 'Resume' : 'Pause',
            color: context.appAccent,
            onTap: () {
              Navigator.pop(context);
              if (isPaused) {
                notifier.resume(ft);
              } else {
                notifier.pause(ft);
              }
            },
          ),
          _OptionTile(
            icon: Icons.edit_rounded,
            label: 'Edit',
            color: context.appTextSecondary,
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => AddFutureTransactionSheet(existing: ft),
              );
            },
          ),
          _OptionTile(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: context.appExpense,
            onTap: () {
              Navigator.pop(context);
              notifier.delete(ft.id);
            },
          ),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: GoogleFonts.dmSans(
          color: context.appTextPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule_rounded,
              size: 60, color: context.appTextMuted),
          const Gap(16),
          Text(
            'No scheduled transactions',
            style: GoogleFonts.dmSans(
              color: context.appTextSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Gap(6),
          Text(
            'Tap Schedule to add recurring or future transactions',
            style: GoogleFonts.dmSans(
              color: context.appTextMuted,
              fontSize: 13,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}