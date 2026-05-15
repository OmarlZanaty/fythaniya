import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';
import 'package:intl/intl.dart' as intl;

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<RewardsBloc>().add(RewardsLoadEvent());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: const Text(S.rewardsTitle),
      leading: Navigator.of(context).canPop()
          ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context))
          : null,
    ),
    body: BlocConsumer<RewardsBloc, RewardsState>(
      listener: (ctx, state) {
        if (state is RewardsRedeemed) {
          _showRedeemed(state.code);
          ctx.read<RewardsBloc>().add(RewardsLoadEvent());
        } else if (state is RewardsError) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.msg), backgroundColor: AppColors.error));
        }
      },
      builder: (ctx, state) {
        if (state is RewardsLoading) return _RewardsShimmer();
        if (state is RewardsError) return AppErrorWidget(message: state.msg, onRetry: () => ctx.read<RewardsBloc>().add(RewardsLoadEvent()));
        if (state is RewardsLoaded || state is RewardsRedeeming) {
          final s = state is RewardsLoaded ? state : (ctx.read<RewardsBloc>().state as RewardsLoaded);
          final isRedeeming = state is RewardsRedeeming;
          return _RewardsContent(summary: (s as RewardsLoaded).summary, vouchers: s.vouchers, isRedeeming: isRedeeming);
        }
        return const SizedBox.shrink();
      },
    ),
  );

  void _showRedeemed(String code) => showDialog(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: BoxDecoration(gradient: AppGradients.gold, shape: BoxShape.circle),
          child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 32)),
        const SizedBox(height: D.md),
        const Text('تم استبدال القسيمة!', style: TS.h2, textAlign: TextAlign.center),
        const SizedBox(height: D.sm),
        Text('كود الخصم:', style: TS.cap),
        const SizedBox(height: D.sm),
        Container(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(12)),
          child: Text(code, style: TS.h2.copyWith(color: AppColors.primary, letterSpacing: 3))),
        const SizedBox(height: D.lg),
        AppButton(label: S.done, onPressed: () => Navigator.pop(context)),
      ]),
    ),
  );
}

class _RewardsContent extends StatelessWidget {
  final RewardsSummary summary;
  final List<VoucherModel> vouchers;
  final bool isRedeeming;
  const _RewardsContent({required this.summary, required this.vouchers, required this.isRedeeming});

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    color: AppColors.primary,
    onRefresh: () async => context.read<RewardsBloc>().add(RewardsLoadEvent()),
    child: ListView(padding: const EdgeInsets.all(D.md), children: [
      // Points hero card
      Container(
        padding: const EdgeInsets.all(D.lg),
        decoration: BoxDecoration(gradient: AppGradients.gold, borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 6))]),
        child: Column(children: [
          const Icon(Icons.stars_rounded, color: Colors.white, size: 36),
          const SizedBox(height: D.sm),
          Text(S.myPoints, style: TS.cap.copyWith(color: Colors.white70)),
          const SizedBox(height: D.xs),
          Text('${summary.pointsBalance}', style: TS.amount.copyWith(color: Colors.white, fontSize: 42)),
          Text(S.pts, style: TS.bodyM.copyWith(color: Colors.white70)),
          const SizedBox(height: D.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
            child: Text(_tierAr(summary.tier), style: TS.bodyM.copyWith(color: Colors.white)),
          ),
        ]),
      ),
      const SizedBox(height: D.lg),

      // Tier progress
      AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('التقدم نحو المستوى التالي', style: TS.bodyM),
          if (summary.nextTierPoints > 0)
            Text('${summary.nextTierPoints} ${S.pts} ${S.nextTier}', style: TS.cap.copyWith(color: AppColors.textMuted)),
        ]),
        const SizedBox(height: D.md),
        if (summary.nextTierPoints == 0)
          Text('🎉 وصلت إلى أعلى مستوى — ذهبي!', style: TS.bodyM.copyWith(color: AppColors.accent))
        else
          LinearPercentIndicator(
            lineHeight: 12, percent: summary.progress.clamp(0.0, 1.0),
            backgroundColor: AppColors.divider, progressColor: AppColors.accent,
            barRadius: const Radius.circular(8), padding: EdgeInsets.zero,
          ),
        const SizedBox(height: D.md),
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
          _TierChip('برونزي', summary.pointsBalance >= 0, Colors.brown),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
          _TierChip('فضي', summary.pointsBalance >= 500, Colors.grey),
          const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
          _TierChip('ذهبي', summary.pointsBalance >= 2000, AppColors.accent),
        ]),
      ])),
      const SizedBox(height: D.lg),

      // Vouchers
      SectionHeader(title: S.vouchers),
      const SizedBox(height: D.md),
      if (vouchers.isEmpty)
        EmptyState(icon: Icons.card_giftcard_outlined, title: S.noVouchers, subtitle: 'اجمع نقاطاً للحصول على قسائم')
      else
        ...vouchers.map((v) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _VoucherCard(voucher: v, isRedeeming: isRedeeming))),

      // Points history
      if (summary.history.isNotEmpty) ...[
        const SizedBox(height: D.lg),
        SectionHeader(title: 'سجل النقاط'),
        const SizedBox(height: D.md),
        ...summary.history.map((h) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _HistoryTile(h: h))),
      ],
      const SizedBox(height: D.xxl),
    ]),
  );

  String _tierAr(String tier) {
    switch (tier.toLowerCase()) {
      case 'gold': return 'ذهبي 🏆';
      case 'silver': return 'فضي 🥈';
      default: return 'برونزي 🥉';
    }
  }
}

class _TierChip extends StatelessWidget {
  final String label; final bool active; final Color color;
  const _TierChip(this.label, this.active, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: active ? color.withOpacity(0.15) : AppColors.surfaceAlt,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: active ? color : AppColors.border),
    ),
    child: Text(label, style: TS.cap.copyWith(color: active ? color : AppColors.textMuted, fontWeight: active ? FontWeight.w600 : FontWeight.w400)),
  );
}

class _VoucherCard extends StatelessWidget {
  final VoucherModel voucher; final bool isRedeeming;
  const _VoucherCard({required this.voucher, required this.isRedeeming});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(D.md),
    highlighted: voucher.canRedeem,
    child: Row(children: [
      Container(width: 56, height: 56,
        decoration: BoxDecoration(gradient: AppGradients.gold, borderRadius: BorderRadius.circular(14)),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text('${voucher.discountPercent.toStringAsFixed(0)}%', style: TS.bodyM.copyWith(color: Colors.white, fontSize: 16)),
          Text('خصم', style: TS.cap.copyWith(color: Colors.white70, fontSize: 10)),
        ])),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(voucher.code, style: TS.bodyM),
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.stars_rounded, size: 14, color: AppColors.accent),
          const SizedBox(width: 4),
          Text(voucher.pointsCost == 0 ? 'مجاني' : '${voucher.pointsCost} ${S.pts}', style: TS.cap.copyWith(color: AppColors.textMuted)),
        ]),
        if (voucher.validUntil != null) ...[
          const SizedBox(height: 4),
          Text('صالح حتى: ${intl.DateFormat('dd/MM/yyyy').format(voucher.validUntil!)}', style: TS.cap.copyWith(color: AppColors.textMuted, fontSize: 11)),
        ],
      ])),
      TextButton(
        onPressed: voucher.canRedeem && !isRedeeming ? () => context.read<RewardsBloc>().add(RewardsRedeemEvent(voucher.id)) : null,
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        child: isRedeeming ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Text(S.redeemPts, style: TS.capM.copyWith(color: voucher.canRedeem ? AppColors.primary : AppColors.textMuted)),
      ),
    ]),
  );
}

class _HistoryTile extends StatelessWidget {
  final RewardHistory h;
  const _HistoryTile({required this.h});

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.symmetric(horizontal: D.md, vertical: 10),
    child: Row(children: [
      Container(width: 36, height: 36, decoration: BoxDecoration(
        color: h.isEarned ? AppColors.successBg : AppColors.errorBg,
        shape: BoxShape.circle),
        child: Icon(h.isEarned ? Icons.add_rounded : Icons.remove_rounded, color: h.isEarned ? AppColors.success : AppColors.error, size: 18)),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(h.reason, style: TS.body, maxLines: 1, overflow: TextOverflow.ellipsis),
        Text(intl.DateFormat('dd/MM/yyyy').format(h.createdAt), style: TS.cap.copyWith(color: AppColors.textMuted, fontSize: 11)),
      ])),
      Text('${h.isEarned ? '+' : '-'}${h.points} ${S.pts}',
        style: TS.bodyM.copyWith(color: h.isEarned ? AppColors.success : AppColors.error, fontWeight: FontWeight.w700)),
    ]),
  );
}

class _RewardsShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(D.md), children: [
    Shimmer(width: double.infinity, height: 200, radius: 20), const SizedBox(height: 20),
    Shimmer(width: double.infinity, height: 100, radius: 16), const SizedBox(height: 20),
    Shimmer(width: 80, height: 18, radius: 4), const SizedBox(height: 14),
    ...List.generate(3, (_) => Padding(padding: const EdgeInsets.only(bottom: 10), child: Shimmer(width: double.infinity, height: 80, radius: 14))),
  ]);
}
