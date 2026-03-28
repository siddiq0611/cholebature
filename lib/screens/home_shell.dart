import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/future_transaction_provider.dart';
import '../providers/security_provider.dart';
import '../providers/transaction_provider.dart';
import '../services/security_service.dart';
import '../theme/app_theme.dart';
import '../widgets/loading_overlay.dart';
import 'add_transaction_sheet.dart';
import 'borrow_lend_screen.dart';
import 'dashboard_screen.dart';
import 'future_transactions_screen.dart';
import 'lock_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

final _tabProvider = StateProvider<int>((ref) => 0);

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLockOnStart();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkLockOnStart() async {
    final settings = await SecurityService.loadSettings();
    if (settings.enabled && mounted) {
      ref.read(appLockedProvider.notifier).state = true;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed && _pausedAt != null) {
      final settings = await SecurityService.loadSettings();
      if (!settings.enabled) return;
      final elapsed =
          DateTime.now().difference(_pausedAt!).inSeconds;
      if (elapsed >= settings.autoLockSeconds && mounted) {
        ref.read(appLockedProvider.notifier).state = true;
      }
    }
  }

  static const _screens = [
    DashboardScreen(),
    TransactionsScreen(),
    FutureTransactionsScreen(),
    BorrowLendScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final tab = ref.watch(_tabProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final isLocked = ref.watch(appLockedProvider);
    final overdueCount = ref.watch(overdueCountProvider);

    if (isLocked) {
      return const LockScreen();
    }

    return LoadingOverlay(
      isLoading: isLoading,
      child: Scaffold(
        backgroundColor: context.appBg,
        body: IndexedStack(index: tab, children: _screens),
        bottomNavigationBar: _BottomNav(
            tab: tab, overdueCount: overdueCount),
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
  final int overdueCount;
  const _BottomNav({required this.tab, required this.overdueCount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = [
      const _NavItemData(Icons.dashboard_rounded, 'Dashboard', 0),
      const _NavItemData(Icons.receipt_long_rounded, 'Transactions', 1),
      const _NavItemData(Icons.schedule_rounded, 'Scheduled', 2,
          badge: 0),
      const _NavItemData(Icons.handshake_rounded, 'Borrow/Lend', 3),
      const _NavItemData(Icons.settings_rounded, 'Settings', 4),
    ];

    return Container(
      decoration: BoxDecoration(
        color: context.appSurface,
        border:
            Border(top: BorderSide(color: context.appBorder, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items
                .map((item) => _NavItem(
                      data: item,
                      selected: tab == item.index,
                      onTap: () => ref
                          .read(_tabProvider.notifier)
                          .state = item.index,
                    ))
                .toList(),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  final IconData icon;
  final String label;
  final int index;
  final int badge;
  const _NavItemData(this.icon, this.label, this.index, {this.badge = 0});
}

class _NavItem extends StatelessWidget {
  final _NavItemData data;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem(
      {required this.data, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = context.appAccent;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(data.icon,
                    color: selected ? accent : context.appTextMuted,
                    size: 22),
                const SizedBox(height: 3),
                Text(
                  data.label,
                  style: GoogleFonts.dmSans(
                    color: selected ? accent : context.appTextMuted,
                    fontSize: 10,
                    fontWeight: selected
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
            if (data.badge > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: context.appExpense,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      data.badge > 9 ? '9+' : '${data.badge}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}