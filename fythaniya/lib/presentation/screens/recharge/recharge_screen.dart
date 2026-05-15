import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});
  @override State<RechargeScreen> createState() => _RechargeScreenState();
}
class _RechargeScreenState extends State<RechargeScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  ServiceProviderModel? _provider;
  SubServiceModel? _sub;

  @override void initState() { super.initState(); context.read<RechargeBloc>().add(RechargeInitEvent()); }
  @override void dispose() { _phone.dispose(); _amount.dispose(); super.dispose(); }

  double get _fee => _sub != null ? _sub!.feeFor(double.tryParse(_amount.text) ?? 0) : 1.5;

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text(S.recharge), backgroundColor: AppColors.primary,
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => context.pop())),
    body: BlocConsumer<RechargeBloc, RechargeState>(
      listener: (ctx, s) {
        if (s is RechargeSuccess) {
          showModalBottomSheet(context: ctx, isScrollControlled: true, builder: (_) => SuccessSheet(
            title: S.successTitle, subtitle: S.successSub,
            ref: s.req.id.substring(0, 8).toUpperCase(), onDone: () { Navigator.pop(ctx); ctx.pop(); }));
        }
        if (s is RechargeError) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(s.msg), backgroundColor: AppColors.error));
      },
      builder: (ctx, s) {
        if (s is RechargeLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
        final providers = s is RechargeLoaded ? s.providers : <ServiceProviderModel>[];
        final isSubmitting = s is RechargeSubmitting;
        return Form(key: _form, child: SingleChildScrollView(padding: const EdgeInsets.all(D.md), child: Column(children: [
          ProviderSelector(providers: providers, selected: _provider, onSelect: (p) { setState(() { _provider = p; _sub = p.subServices.isNotEmpty ? p.subServices.first : null; }); }),
          const SizedBox(height: D.md),
          if (_provider != null && _provider!.subServices.length > 1) ...[
            SubServiceSelector(subServices: _provider!.subServices, selected: _sub, onSelect: (s2) => setState(() => _sub = s2)),
            const SizedBox(height: D.md),
          ],
          AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('رقم الهاتف المراد شحنه', style: TS.cap), const SizedBox(height: D.sm),
            AppField(label: S.phone, hint: S.phonePlch, ctrl: _phone, kb: TextInputType.phone,
              formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
              validator: (v) => (v?.isEmpty ?? true) ? S.required : null,
              prefix: const Padding(padding: EdgeInsets.all(14), child: Icon(Icons.phone_android_rounded, size: 20))),
          ])),
          const SizedBox(height: D.md),
          AmountPicker(ctrl: _amount, quickAmounts: _sub?.quickAmounts.isNotEmpty == true ? _sub!.quickAmounts : const [5, 10, 15, 25, 50, 100],
            validator: (v) { if (v == null || v.isEmpty) return S.required; final a = double.tryParse(v); if (a == null || a < 5) return 'الحد الأدنى 5 ج.م'; if (a > 500) return 'الحد الأقصى 500 ج.م'; return null; }),
          const SizedBox(height: D.md),
          if (_amount.text.isNotEmpty && double.tryParse(_amount.text) != null) AppCard(child: Column(children: [
            SummaryRow(label: 'المبلغ', value: '${_amount.text} ${S.egp}'),
            SummaryRow(label: S.fee, value: '${_fee.toStringAsFixed(2)} ${S.egp}'),
            const Divider(height: 20),
            SummaryRow(label: S.total, value: '${((double.tryParse(_amount.text) ?? 0) + _fee).toStringAsFixed(2)} ${S.egp}', bold: true, valueColor: AppColors.primary),
          ])),
          const SizedBox(height: D.lg),
          AppButton(label: 'شحن الآن', isLoading: isSubmitting, onPressed: () {
            if (!_form.currentState!.validate() || _provider == null) return;
            ctx.read<RechargeBloc>().add(RechargeSubmitEvent(
              providerId: _provider!.id, subServiceId: _sub?.id ?? '',
              phone: _phone.text.trim(), amount: double.parse(_amount.text)));
          }),
          const SizedBox(height: D.xxl),
        ])));
      }));
}
