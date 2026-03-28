import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/transaction_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';
import 'dashboard_screen.dart';
import 'transactions_screen.dart';
import 'add_transaction_sheet.dart';

final _tabProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerWidget {
  const HomeShell({super.key});

  static const _screens = [DashboardScreen(), TransactionsScreen()];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tab = ref.watch(_tabProvider);
    final isLoading = ref.watch(isLoadingProvider);

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: context.appBg,
        body: IndexedStack(index: tab, children: _screens),
        bottomNavigationBar: _BottomNav(tab: tab),
        floatingActionButton: tab == 1
            ? FloatingActionButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddTransactionSheet(),
                ),
                backgroundColor: context.appAccent,
                child: const Icon(Icons.add_rounded, color: Colors.white),
              )
            : null,
      ),
    );
  }
}

class _BottomNav extends ConsumerWidget {
  final int tab;
  const _BottomNav({required this.tab});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border: Border(
            top: BorderSide(color: context.appBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _NavItem(
                icon: Icons.dashboard_rounded,
                label: 'Dashboard',
                selected: tab == 0,
                onTap: () => ref.read(_tabProvider.notifier).state = 0,
              ),
              _NavItem(
                icon: Icons.receipt_long_rounded,
                label: 'Transactions',
                selected: tab == 1,
                onTap: () => ref.read(_tabProvider.notifier).state = 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.appAccent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent.withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? accent : context.appTextMuted,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: GoogleFonts.dmSans(
                color: selected ? accent : context.appTextMuted,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}