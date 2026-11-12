import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:split_ex/app/auth/providers/auth_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/dashboard_provider.dart';
import 'package:split_ex/modules/notifications/providers/notification_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/room_provider.dart';
import 'package:split_ex/modules/room/presentation/providers/expense_provider.dart';
import 'package:split_ex/modules/room/presentation/screens/settlement/settlement_screen.dart';
import 'package:split_ex/modules/room/presentation/screens/settlement/upi_id_dialog.dart';
import 'package:split_ex/modules/room/domain/policies/balance_service.dart';
import 'package:split_ex/modules/notifications/services/notification_helper.dart';
import 'package:split_ex/app/auth/providers/session_provider.dart';
import 'package:split_ex/app/auth/providers/user_profiles_provider.dart';
import 'package:split_ex/shared/ui/design_system/design_system.dart';
import 'package:split_ex/shared/ui/design_system/app_colors.dart';
import 'package:split_ex/shared/ui/widgets/app_header.dart';

const _kIndigo = Color(0xFF6366F1);

class DashboardScreen extends ConsumerStatefulWidget {
  final String roomId;
  const DashboardScreen({super.key, required this.roomId});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _upiDialogShown = false;

  void _checkUpiId() {
    if (_upiDialogShown) return;
    final profile = ref.read(userProfileProvider).valueOrNull;
    if (profile != null && !profile.hasUpiId) {
      _upiDialogShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => UpiIdDialog(
          userId: ref.read(currentUserIdProvider),
          allowSkip: true,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = ref.watch(currentUserBalanceProvider(widget.roomId));
    final userDebts = ref.watch(currentUserDebtsProvider(widget.roomId));
    final allDebts = ref.watch(
      monthPairDebtsProvider(
        MonthBalanceKey(
          roomId: widget.roomId,
          month: ref.watch(currentMonthProvider),
        ),
      ),
    );
    final userId = ref.watch(currentUserIdProvider);
    final roomAsync = ref.watch(roomStreamProvider(widget.roomId));

    WidgetsBinding.instance.addPostFrameCallback((_) => _checkUpiId());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: GradientBody(
        child: roomAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (room) {
            if (room == null) return const Center(child: Text('Room not found'));
            final members = room.historicalMemberIds;
            final membersAsync = ref.watch(userProfilesByIdsProvider(members));

            return membersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (memberList) {
                final nameMap = <String, String>{};
                for (final m in memberList) nameMap[m.uid] = m.name;
                nameMap.putIfAbsent(userId, () => 'You');
                final cs = Theme.of(context).colorScheme;
                final isDark = Theme.of(context).brightness == Brightness.dark;

                return ListView(
                  padding: const EdgeInsets.fromLTRB(AppSpacing.base, AppSpacing.base, AppSpacing.base, 100),
                  children: [
                    _BalanceSummaryCard(balance: balance),
                    const SizedBox(height: AppSpacing.lg),
                    AppSectionHeader(title: 'Room Members (${room.memberIds.length})'),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: room.memberIds.map((id) {
                        final name = nameMap[id] ?? id;
                        final isAdminMember = room.isAdmin(id);
                        final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
                        final color = isAdminMember ? _kIndigo : cs.primary;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? .10 : .06),
                            borderRadius: BorderRadius.circular(AppRadius.xxl),
                            border: Border.all(color: color.withValues(alpha: .15)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 11,
                                backgroundColor: color.withValues(alpha: .12),
                                child: Text(initial, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Text(
                                isAdminMember ? '$name · Admin' : name,
                                style: AppTextStyles.label(context),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    if (userDebts.isNotEmpty) ...[
                      AppSectionHeader(title: 'Your Settlements'),
                      const SizedBox(height: AppSpacing.sm),
                      ...userDebts.map((d) => _DebtTile(
                        debt: d, currentUserId: userId, nameMap: nameMap, roomId: widget.roomId,
                      )),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                    AppSectionHeader(title: 'All Settlements'),
                    const SizedBox(height: AppSpacing.sm),
                    if (allDebts.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                        decoration: BoxDecoration(
                          color: AppColors.success(context).withValues(alpha: isDark ? .08 : .05),
                          borderRadius: BorderRadius.circular(AppRadius.lg),
                          border: Border.all(color: AppColors.success(context).withValues(alpha: .15)),
                        ),
                        child: Center(
                          child: Text('All settled up! 🎉', style: AppTextStyles.bodySmall(context)),
                        ),
                      )
                    else
                      ...allDebts.map((d) => _DebtTile(
                        debt: d, currentUserId: userId, nameMap: nameMap, roomId: widget.roomId,
                      )),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BalanceSummaryCard extends StatelessWidget {
  final double balance;
  const _BalanceSummaryCard({required this.balance});

  @override
  Widget build(BuildContext context) {
    final isPositive = balance > 0.01;
    final isNegative = balance < -0.01;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final color = isPositive
        ? AppColors.success(context)
        : isNegative
        ? AppColors.error(context)
        : cs.primary;
    final label = isPositive ? 'You are owed' : isNegative ? 'You owe' : 'All settled up!';
    final icon = isPositive
        ? Icons.arrow_downward_rounded
        : isNegative
        ? Icons.arrow_upward_rounded
        : Icons.check_circle_rounded;
    final displayAmount = balance.abs();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [color.withValues(alpha: 0.35), color.withValues(alpha: 0.20)]
              : [color.withValues(alpha: 0.15), color.withValues(alpha: 0.06)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.lg),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.25 : 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 26),
          ),
          const SizedBox(width: AppSpacing.base),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.bodySmall(context)),
                const SizedBox(height: AppSpacing.xs),
                if (isPositive || isNegative)
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: displayAmount),
                    duration: const Duration(milliseconds: 600),
                    builder: (_, v, __) => Text(
                      '₹${v.toStringAsFixed(2)}',
                      style: AppTextStyles.stat(context).copyWith(color: color, fontSize: 26),
                    ),
                  )
                else
                  Text('Great job! 🎉', style: AppTextStyles.statSmall(context).copyWith(color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DebtTile extends ConsumerWidget {
  final Debt debt;
  final String currentUserId;
  final Map<String, String> nameMap;
  final String roomId;

  const _DebtTile({
    required this.debt,
    required this.currentUserId,
    required this.nameMap,
    required this.roomId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fromName = debt.from == currentUserId ? 'You' : (nameMap[debt.from] ?? debt.from);
    final toName   = debt.to == currentUserId   ? 'You' : (nameMap[debt.to]   ?? debt.to);
    final canRemind = debt.to   == currentUserId;
    final canSettle = debt.from == currentUserId;
    final color = canSettle ? AppColors.error(context) : AppColors.success(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: AppFinanceTile(
        icon: Icons.swap_horiz_rounded,
        color: color,
        title: '$fromName → $toName',
        subtitle: canSettle ? 'Tap to settle up' : 'Awaiting your confirmation',
        value: '₹${debt.amount.toStringAsFixed(2)}',
        action: canRemind
            ? IconButton(
                icon: Icon(Icons.notifications_active_rounded, size: 18, color: color),
                tooltip: 'Send Reminder',
                onPressed: () {
                  final helper = NotificationHelper(ref.read(notificationServiceProvider));
                  helper.sendReminder(
                    roomId: roomId,
                    fromName: nameMap[currentUserId] ?? 'You',
                    targetUserId: debt.from,
                    amount: debt.amount,
                  );
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Reminder sent!')),
                  );
                },
              )
            : null,
        onTap: canSettle
            ? () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettlementScreen(roomId: roomId, debt: debt, nameMap: nameMap),
                ),
              )
            : null,
      ),
    );
  }
}
