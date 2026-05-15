import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';
import 'package:intl/intl.dart' as intl;

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  @override
  void initState() {
    super.initState();
    context.read<WalletBloc>().add(WalletLoadEvent());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: const Text(S.walletTitle),
      leading: Navigator.of(context).canPop()
          ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context))
          : null,
    ),
    body: BlocBuilder<WalletBloc, WalletState>(builder: (ctx, state) {
      if (state is WalletLoading) return _WalletShimmer();
      if (state is WalletError) return AppErrorWidget(message: state.msg, onRetry: () => ctx.read<WalletBloc>().add(WalletLoadEvent()));
      if (state is WalletLoaded) return _WalletContent(state: state);
      return const SizedBox.shrink();
    }),
  );
}

class _WalletContent extends StatelessWidget {
  final WalletLoaded state;
  const _WalletContent({required this.state});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.primary,
    onRefresh: () async => context.read<WalletBloc>().add(WalletLoadEvent()),
    child: CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Column(children: [
        const SizedBox(height: D.md),
        // Wallet hero card
        WalletCard(
          balance: state.user.walletBalance,
          points: state.user.pointsBalance,
          tierAr: state.user.tierAr,
        ),
        const SizedBox(height: D.lg),

        // Quick actions
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: D.md),
          child: Row(children: [
            _QuickAction(icon: Icons.add_rounded, label: 'شحن', color: AppColors.primary, onTap: () => context.push(AppRoutes.walletTopup)),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.send_rounded, label: 'إرسال', color: AppColors.internet, onTap: () => context.push(AppRoutes.walletTransfer)),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.history_rounded, label: 'السجل', color: AppColors.telecom, onTap: () => context.push(AppRoutes.txList)),
            const SizedBox(width: 12),
            _QuickAction(icon: Icons.stars_rounded, label: 'مكافآت', color: AppColors.accent, onTap: () => context.push(AppRoutes.rewards)),
          ]),
        ),

        const SizedBox(height: D.lg),

        // Spending chart
        if (state.spending.isNotEmpty) ...[
          SectionHeader(title: S.spending),
          const SizedBox(height: D.md),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: D.md),
            child: AppCard(
              padding: const EdgeInsets.all(D.md),
              child: Column(children: [
                _SpendingChart(spending: state.spending),
                const SizedBox(height: D.md),
                ..._spendingLegend(state.spending),
              ]),
            ),
          ),
          const SizedBox(height: D.lg),
        ],

        // Recent transactions
        SectionHeader(title: S.recentTx, action: S.seeAll, onAction: () => context.push(AppRoutes.txList)),
        const SizedBox(height: D.md),
        if (state.txs.isEmpty)
          EmptyState(icon: Icons.receipt_long_outlined, title: S.noTxYet, subtitle: 'لا توجد معاملات حتى الآن')
        else
          ...state.txs.map((tx) => Padding(
            padding: const EdgeInsets.fromLTRB(D.md, 0, D.md, 10),
            child: _MiniTxTile(tx: tx),
          )),
        const SizedBox(height: D.xxl),
      ])),
    ]),
  );

  List<Widget> _spendingLegend(List<SpendingRecord> spending) {
    final cats = <String, double>{};
    for (final s in spending) {
      cats[s.category] = (cats[s.category] ?? 0) + s.amount;
    }
    final total = cats.values.fold(0.0, (a, b) => a + b);
    return cats.entries.map((e) {
      final pct = total > 0 ? (e.value / total * 100).toStringAsFixed(0) : '0';
      final color = _catColor(e.key);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(kCategoryNames[e.key] ?? e.key, style: TS.cap),
          const Spacer(),
          Text('$pct%', style: TS.cap.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: 8),
          Text('${e.value.toStringAsFixed(0)} ${S.egp}', style: TS.capM.copyWith(color: AppColors.text)),
        ]),
      );
    }).toList();
  }

  Color _catColor(String cat) {
    switch (cat) {
      case 'TELECOM': return AppColors.telecom;
      case 'ELECTRICITY': return AppColors.electricity;
      case 'GAS': return AppColors.gas;
      case 'WATER': return AppColors.water;
      case 'INTERNET': return AppColors.internet;
      default: return AppColors.primary;
    }
  }
}

class _SpendingChart extends StatelessWidget {
  final List<SpendingRecord> spending;
  const _SpendingChart({required this.spending});

  @override
  Widget build(BuildContext context) {
    final cats = <String, double>{};
    for (final s in spending) {
      cats[s.category] = (cats[s.category] ?? 0) + s.amount;
    }
    final total = cats.values.fold(0.0, (a, b) => a + b);

    final colors = [AppColors.telecom, AppColors.electricity, AppColors.gas, AppColors.water, AppColors.internet, AppColors.primary];
    final entries = cats.entries.toList();

    return SizedBox(
      height: 160,
      child: Row(children: [
        Expanded(
          child: PieChart(PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 45,
            sections: entries.asMap().entries.map((entry) {
              final i = entry.key;
              final cat = entry.value;
              final pct = total > 0 ? cat.value / total * 100 : 0;
              return PieChartSectionData(
                value: cat.value,
                title: '${pct.toStringAsFixed(0)}%',
                color: colors[i % colors.length],
                radius: 50,
                titleStyle: const TextStyle(fontFamily: 'Cairo', fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
              );
            }).toList(),
          )),
        ),
        const SizedBox(width: D.md),
        Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('الإجمالي', style: TS.cap),
          Text('${total.toStringAsFixed(0)}', style: TS.h2),
          Text(S.egp, style: TS.cap.copyWith(color: AppColors.textMuted)),
        ]),
      ]),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(child: GestureDetector(onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: D.md),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withOpacity(0.2))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 6),
        Text(label, style: TS.cap.copyWith(color: color, fontWeight: FontWeight.w600, fontSize: 11)),
      ]),
    )));
}

class _MiniTxTile extends StatelessWidget {
  final TransactionModel tx;
  const _MiniTxTile({required this.tx});

  @override
  Widget build(BuildContext context) {
    final type = tx.request?.type ?? '';
    final title = kTypeNames[type] ?? (tx.request?.serviceProvider?.displayName ?? 'معاملة');
    final dt = intl.DateFormat('dd/MM').format(tx.createdAt);
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: D.md, vertical: 10),
      child: Row(children: [
        Text(dt, style: TS.cap.copyWith(color: AppColors.textMuted, fontSize: 11)),
        const SizedBox(width: 12),
        Expanded(child: Text(title, style: TS.body, maxLines: 1, overflow: TextOverflow.ellipsis)),
        Text('-${tx.totalAmount.toStringAsFixed(2)} ${S.egp}', style: TS.bodyM.copyWith(color: AppColors.error)),
      ]),
    );
  }
}

class _WalletShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(D.md), children: [
    const SizedBox(height: 8),
    Shimmer(width: double.infinity, height: 130, radius: 20),
    const SizedBox(height: 20),
    Row(children: List.generate(4, (_) => Expanded(child: Padding(padding: const EdgeInsets.only(left: 10), child: Shimmer(width: double.infinity, height: 70, radius: 14))))),
    const SizedBox(height: 20),
    Shimmer(width: 100, height: 18, radius: 4), const SizedBox(height: 14),
    Shimmer(width: double.infinity, height: 200, radius: 16),
    const SizedBox(height: 20),
    Shimmer(width: 100, height: 18, radius: 4), const SizedBox(height: 14),
    ...List.generate(4, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Shimmer(width: double.infinity, height: 48, radius: 10))),
  ]);
}
