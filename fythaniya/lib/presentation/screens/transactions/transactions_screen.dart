import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';
import 'package:intl/intl.dart' as intl;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _scroll = ScrollController();
  String? _filter;

  static const _filters = [
    ('الكل', null), ('مكتمل', 'SUCCESS'), ('جارٍ', 'PENDING'),
    ('فشل', 'FAILED'), ('مسترد', 'REFUNDED'),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  void _load() => context.read<TxBloc>().add(TxLoadEvent(status: _filter));

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 200) {
      context.read<TxBloc>().add(TxMoreEvent());
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: const Text(S.txTitle),
      leading: Navigator.of(context).canPop()
          ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context))
          : null,
    ),
    body: Column(children: [
      SizedBox(
        height: 52,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: D.md, vertical: 10),
          scrollDirection: Axis.horizontal,
          children: _filters.map((f) {
            final selected = _filter == f.$2;
            return Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(f.$1),
                selected: selected,
                onSelected: (_) {
                  setState(() => _filter = f.$2);
                  context.read<TxBloc>().add(TxFilterEvent(f.$2));
                },
                selectedColor: AppColors.infoBg,
                labelStyle: TS.cap.copyWith(
                  color: selected ? AppColors.primary : AppColors.textSec,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
                checkmarkColor: AppColors.primary,
                side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
                backgroundColor: AppColors.surface,
              ),
            );
          }).toList(),
        ),
      ),
      Expanded(child: BlocBuilder<TxBloc, TxState>(builder: (ctx, state) {
        if (state is TxLoading) return _TxShimmer();
        if (state is TxError) return AppErrorWidget(message: state.msg, onRetry: _load);
        if (state is TxLoaded) {
          if (state.items.isEmpty) return EmptyState(icon: Icons.receipt_long_outlined, title: S.noTx, subtitle: 'لم تقم بأي معاملات بعد');
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async => _load(),
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(D.md, 0, D.md, D.xxl),
              itemCount: state.items.length + (state.hasMore ? 1 : 0),
              itemBuilder: (_, i) {
                if (i >= state.items.length) return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
                return Padding(padding: const EdgeInsets.only(bottom: 10), child: _TxCard(tx: state.items[i]));
              },
            ),
          );
        }
        return const SizedBox.shrink();
      })),
    ]),
  );
}

class _TxCard extends StatelessWidget {
  final TransactionModel tx;
  const _TxCard({required this.tx});

  @override
  Widget build(BuildContext context) {
    final req = tx.request;
    final type = req?.type ?? '';
    final title = kTypeNames[type] ?? (req?.serviceProvider?.displayName ?? 'معاملة');
    final target = req?.displayTarget ?? '';
    final dt = intl.DateFormat('dd/MM/yyyy hh:mm a').format(tx.createdAt);

    return AppCard(
      padding: const EdgeInsets.all(D.md),
      child: Row(children: [
        Container(width: 48, height: 48,
          decoration: BoxDecoration(color: _color(type).withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
          child: Icon(_icon(type), color: _color(type), size: 22)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TS.bodyM, maxLines: 1, overflow: TextOverflow.ellipsis),
          if (target.isNotEmpty) ...[const SizedBox(height: 2), Text(target, style: TS.cap.copyWith(color: AppColors.textMuted))],
          const SizedBox(height: 4),
          Text(dt, style: TS.cap.copyWith(color: AppColors.textMuted, fontSize: 11)),
        ])),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('-${tx.totalAmount.toStringAsFixed(2)} ${S.egp}', style: TS.bodyM.copyWith(color: AppColors.error, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          StatusBadge(status: tx.isSuccess ? 'COMPLETED' : tx.status, small: true),
        ]),
      ]),
    );
  }

  IconData _icon(String t) {
    switch (t) {
      case 'MOBILE_RECHARGE': return Icons.smartphone_rounded;
      case 'BILL_PAYMENT': return Icons.receipt_rounded;
      case 'INTERNET_RECHARGE': return Icons.wifi_rounded;
      case 'B2B_PAY_LATER': return Icons.business_rounded;
      default: return Icons.payment_rounded;
    }
  }

  Color _color(String t) {
    switch (t) {
      case 'MOBILE_RECHARGE': return AppColors.telecom;
      case 'BILL_PAYMENT': return AppColors.electricity;
      case 'INTERNET_RECHARGE': return AppColors.internet;
      case 'B2B_PAY_LATER': return AppColors.b2b;
      default: return AppColors.primary;
    }
  }
}

class _TxShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(D.md),
    itemCount: 8,
    separatorBuilder: (_, __) => const SizedBox(height: 10),
    itemBuilder: (_, __) => Row(children: [
      Shimmer(width: 48, height: 48, radius: 12), const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Shimmer(width: 140, height: 14, radius: 4), const SizedBox(height: 6), Shimmer(width: 90, height: 12, radius: 4),
      ])),
      const SizedBox(width: 8), Shimmer(width: 70, height: 14, radius: 4),
    ]),
  );
}
