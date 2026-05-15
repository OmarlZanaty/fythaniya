import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

class BillScreen extends StatefulWidget {
  final String category;
  const BillScreen({super.key, required this.category});
  @override State<BillScreen> createState() => _BillScreenState();
}

class _BillScreenState extends State<BillScreen> {
  ServiceProviderModel? _provider;
  SubServiceModel? _subService;
  double? _amount;
  final _accountCtrl = TextEditingController();
  final _customCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    context.read<BillBloc>().add(BillLoadEvent(widget.category));
  }

  @override
  void dispose() { _accountCtrl.dispose(); _customCtrl.dispose(); super.dispose(); }

  void _selectProvider(ServiceProviderModel p) => setState(() {
    _provider = p;
    _subService = p.subServices.isNotEmpty ? p.subServices.first : null;
    _amount = null;
    _customCtrl.clear();
  });

  void _selectSubService(SubServiceModel s) => setState(() {
    _subService = s;
    _amount = null;
    _customCtrl.clear();
  });

  void _selectAmount(int a) => setState(() {
    _amount = a.toDouble();
    _customCtrl.text = a.toString();
  });

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_provider == null) { _showError('اختر مزود الخدمة'); return; }
    if (_amount == null || _amount! <= 0) { _showError('أدخل المبلغ'); return; }
    context.read<BillBloc>().add(BillSubmitEvent(
      providerId: _provider!.id,
      subServiceId: _subService?.id ?? '',
      accountNumber: _accountCtrl.text.trim(),
      amount: _amount!,
    ));
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) => BlocListener<BillBloc, BillState>(
    listener: (ctx, state) {
      if (state is BillSuccess) {
        _showSuccessSheet(state.req);
      } else if (state is BillError) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(state.msg), backgroundColor: AppColors.error));
      }
    },
    child: Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(kCategoryNames[widget.category] ?? 'فاتورة'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context)),
      ),
      body: BlocBuilder<BillBloc, BillState>(builder: (ctx, state) {
        if (state is BillLoading) return const Center(child: CircularProgressIndicator());
        if (state is BillError && state is! BillLoaded) {
          return AppErrorWidget(message: state.msg, onRetry: () => ctx.read<BillBloc>().add(BillLoadEvent(widget.category)));
        }
        if (state is BillLoaded || state is BillSubmitting || state is BillSuccess) {
          final providers = state is BillLoaded ? state.providers : (ctx.read<BillBloc>().state is BillLoaded ? (ctx.read<BillBloc>().state as BillLoaded).providers : <ServiceProviderModel>[]);
          final isSubmitting = state is BillSubmitting;
          return _buildForm(ctx, providers, isSubmitting);
        }
        return const SizedBox.shrink();
      }),
    ),
  );

  Widget _buildForm(BuildContext ctx, List<ServiceProviderModel> providers, bool isSubmitting) {
    final sub = _subService;
    final fee = sub != null && _amount != null ? sub.feeFor(_amount!) : 0.0;
    final total = (_amount ?? 0) + fee;

    return Form(
      key: _formKey,
      child: ListView(padding: const EdgeInsets.all(D.md), children: [
        // Provider selector
        SectionHeader(title: S.selectProv),
        const SizedBox(height: D.md),
        SizedBox(
          height: 80,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: providers.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final p = providers[i];
              final sel = _provider?.id == p.id;
              return GestureDetector(
                onTap: () => _selectProvider(p),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.infoBg : AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border, width: sel ? 1.5 : 0.8),
                  ),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(_catIcon(p.category), color: sel ? AppColors.primary : AppColors.textMuted, size: 26),
                    const SizedBox(height: 6),
                    Text(p.displayName, style: TS.cap.copyWith(color: sel ? AppColors.primary : AppColors.text, fontWeight: sel ? FontWeight.w600 : FontWeight.w400), maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
                  ]),
                ),
              );
            },
          ),
        ),

        // Sub-service tabs
        if (_provider != null && _provider!.subServices.length > 1) ...[
          const SizedBox(height: D.md),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _provider!.subServices.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = _provider!.subServices[i];
                final sel = _subService?.id == s.id;
                return GestureDetector(
                  onTap: () => _selectSubService(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                    ),
                    child: Text(s.nameAr, style: TS.cap.copyWith(color: sel ? Colors.white : AppColors.text, fontWeight: FontWeight.w600)),
                  ),
                );
              },
            ),
          ),
        ],

        // Account number
        if (_provider != null) ...[
          const SizedBox(height: D.lg),
          AppField(
            label: _accountLabel(),
            hint: _accountHint(),
            ctrl: _accountCtrl,
            kb: TextInputType.number,
            formatters: [FilteringTextInputFormatter.digitsOnly],
            validator: (v) => (v == null || v.trim().isEmpty) ? S.required : null,
          ),
          const SizedBox(height: D.sm),
          Row(mainAxisAlignment: MainAxisAlignment.end, children: [
            Text('حفظ الرقم', style: TS.cap),
            const SizedBox(width: 6),
            Switch.adaptive(value: _saved, onChanged: (v) => setState(() => _saved = v), activeColor: AppColors.primary),
          ]),

          // Quick amounts
          if (sub != null && sub.quickAmounts.isNotEmpty) ...[
            const SizedBox(height: D.md),
            SectionHeader(title: S.quickAmounts),
            const SizedBox(height: D.md),
            Wrap(spacing: 8, runSpacing: 8, children: sub.quickAmounts.map((a) {
              final sel = _amount == a.toDouble();
              return GestureDetector(
                onTap: () => _selectAmount(a),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: sel ? AppColors.primary : AppColors.border),
                  ),
                  child: Text('$a ${S.egp}', style: TS.capM.copyWith(color: sel ? Colors.white : AppColors.text)),
                ),
              );
            }).toList()),
          ],

          // Custom amount
          const SizedBox(height: D.md),
          if (sub != null) Text(
            'أو أدخل قيمة (${sub.minAmount?.toStringAsFixed(0) ?? '0'} - ${sub.maxAmount?.toStringAsFixed(0) ?? '∞'} ${S.egp})',
            style: TS.cap.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: D.sm),
          AppField(
            label: S.amount,
            hint: '0.00',
            ctrl: _customCtrl,
            kb: const TextInputType.numberWithOptions(decimal: true),
            formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            onChange: (v) {
              final d = double.tryParse(v);
              setState(() => _amount = d);
            },
            validator: (v) {
              final d = double.tryParse(v ?? '');
              if (d == null || d <= 0) return 'أدخل مبلغاً صحيحاً';
              if (sub?.minAmount != null && d < sub!.minAmount!) return 'الحد الأدنى ${sub.minAmount!.toStringAsFixed(0)} ${S.egp}';
              if (sub?.maxAmount != null && d > sub!.maxAmount!) return 'الحد الأقصى ${sub.maxAmount!.toStringAsFixed(0)} ${S.egp}';
              return null;
            },
          ),

          // Summary
          if (_amount != null && _amount! > 0) ...[
            const SizedBox(height: D.lg),
            AppCard(child: Column(children: [
              _SumRow(label: S.amount, value: '${_amount!.toStringAsFixed(2)} ${S.egp}'),
              const Divider(height: D.md),
              _SumRow(label: S.fee, value: '${fee.toStringAsFixed(2)} ${S.egp}'),
              const Divider(height: D.md),
              _SumRow(label: S.total, value: '${total.toStringAsFixed(2)} ${S.egp}', bold: true, color: AppColors.primary),
            ])),
          ],

          const SizedBox(height: D.lg),
          AppButton(label: S.confirm, isLoading: isSubmitting, onPressed: isSubmitting ? null : _submit),
          const SizedBox(height: D.xxl),
        ],
      ]),
    );
  }

  String _accountLabel() {
    switch (widget.category) {
      case 'TELECOM': return 'رقم الهاتف';
      default: return S.accountNum;
    }
  }

  String _accountHint() {
    switch (widget.category) {
      case 'TELECOM': return '01XXXXXXXXX';
      default: return '000000000';
    }
  }

  IconData _catIcon(String cat) {
    switch (cat) {
      case 'TELECOM': return Icons.smartphone_rounded;
      case 'ELECTRICITY': return Icons.bolt_rounded;
      case 'GAS': return Icons.local_fire_department_rounded;
      case 'WATER': return Icons.water_drop_rounded;
      case 'INTERNET': return Icons.wifi_rounded;
      default: return Icons.payment_rounded;
    }
  }

  void _showSuccessSheet(RequestModel req) => showModalBottomSheet(
    context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => Container(
      padding: EdgeInsets.fromLTRB(D.lg, D.lg, D.lg, MediaQuery.of(context).viewInsets.bottom + D.lg),
      decoration: const BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.divider, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: D.lg),
        Container(width: 72, height: 72, decoration: BoxDecoration(gradient: AppGradients.success, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.white, size: 36)),
        const SizedBox(height: D.md),
        Text(S.successTitle, style: TS.h2, textAlign: TextAlign.center),
        const SizedBox(height: D.sm),
        Text(S.successSub, style: TS.cap, textAlign: TextAlign.center),
        const SizedBox(height: D.md),
        Text('رقم الطلب: ${req.id.substring(0, 8).toUpperCase()}', style: TS.capM.copyWith(color: AppColors.textMuted)),
        const SizedBox(height: D.lg),
        AppButton(label: S.done, onPressed: () { Navigator.pop(context); Navigator.pop(context); }),
      ]),
    ),
  );
}

class _SumRow extends StatelessWidget {
  final String label, value; final bool bold; final Color? color;
  const _SumRow({required this.label, required this.value, this.bold = false, this.color});
  @override Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
    Text(label, style: TS.body.copyWith(color: AppColors.textSec)),
    Text(value, style: bold ? TS.h3.copyWith(color: color ?? AppColors.text) : TS.bodyM),
  ]);
}
