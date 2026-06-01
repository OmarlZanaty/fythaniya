import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';
import 'package:fythaniya/presentation/screens/phase2/phase2_screens.dart' show showInsufficientBalanceModal, showInsufficientBalanceChoice;

class RechargeScreen extends StatefulWidget {
  // When set, the screen locks to this single provider and hides the picker —
  // so a tile like "شحن اورنج" shows ONLY Orange's products.
  final String? providerId;
  const RechargeScreen({super.key, this.providerId});
  @override State<RechargeScreen> createState() => _RechargeScreenState();
}
class _RechargeScreenState extends State<RechargeScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  ServiceProviderModel? _provider;
  SubServiceModel? _sub;
  bool _reqSubmitting = false; // for REQUEST-type products

  @override void initState() { super.initState(); context.read<RechargeBloc>().add(RechargeInitEvent()); }
  @override void dispose() { _phone.dispose(); _amount.dispose(); super.dispose(); }

  // Submit a REQUEST-type product → creates a pending bill the admin prices later.
  Future<void> _submitRequest() async {
    if (_provider == null || _sub == null) return;
    if (_phone.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.required), backgroundColor: AppColors.error)); return; }
    setState(() => _reqSubmitting = true);
    try {
      final r = await UserRepo().createRequest(
        serviceProviderId: _provider!.id, subServiceId: _sub!.id,
        type: 'BILL_PAYMENT', amount: 0, phoneNumber: _phone.text.trim());
      if (!mounted) return;
      await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => SuccessSheet(
        title: 'تم إرسال الطلب', subtitle: 'ستحدد الإدارة المبلغ ثم تدفعه من "طلباتي"',
        ref: r.id.substring(0,8).toUpperCase(), onDone: () { Navigator.pop(context); context.pop(); }));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _reqSubmitting = false); }
  }

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
        var providers = s is RechargeLoaded ? s.providers : <ServiceProviderModel>[];
        // Lock to a single provider when the tile specified one.
        if (widget.providerId != null) {
          providers = providers.where((p) => p.id == widget.providerId).toList();
          if (_provider == null && providers.isNotEmpty) {
            // auto-select after build to avoid setState-in-build
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _provider == null) {
                setState(() { _provider = providers.first; _sub = providers.first.subServices.isNotEmpty ? providers.first.subServices.first : null; });
              }
            });
          }
        }
        final isSubmitting = s is RechargeSubmitting;
        return Form(key: _form, child: SingleChildScrollView(padding: const EdgeInsets.all(D.md), child: Column(children: [
          // Hide the provider picker when locked to one provider.
          if (widget.providerId == null) ...[
            ProviderSelector(providers: providers, selected: _provider, onSelect: (p) { setState(() { _provider = p; _sub = p.subServices.isNotEmpty ? p.subServices.first : null; }); }),
            const SizedBox(height: D.md),
          ],
          if (_provider != null && _provider!.subServices.isNotEmpty) ...[
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
          // REQUEST = no amount; admin prices it later.
          if (_sub?.isRequest == true) ...[
            AppCard(child: Row(children: [
              const Icon(Icons.inbox_rounded, color: AppColors.warning),
              const SizedBox(width: 10),
              Expanded(child: Text('هذه الخدمة تُرسل كطلب. ستحدد الإدارة المبلغ ثم تدفعه من شاشة "طلباتي".',
                style: TS.cap.copyWith(color: AppColors.textSec))),
            ])),
          // Bundle = fixed price (no amount entry). Otherwise show amount picker.
          ] else if (_sub?.isBundle == true) ...[
            AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('سعر الباقة', style: TS.cap), const SizedBox(height: D.sm),
              Row(children: [
                const Icon(Icons.inventory_2_rounded, color: AppColors.primary),
                const SizedBox(width: 8),
                Text('${(_sub!.bundlePrice ?? 0).toStringAsFixed(2)} ${S.egp}', style: TS.h2.copyWith(color: AppColors.primary)),
              ]),
              if (_fee > 0) ...[ const Divider(height: 20),
                SummaryRow(label: S.fee, value: '${_sub!.feeFor(_sub!.bundlePrice ?? 0).toStringAsFixed(2)} ${S.egp}'),
                SummaryRow(label: S.total, value: '${_sub!.totalFor(_sub!.bundlePrice ?? 0).toStringAsFixed(2)} ${S.egp}', bold: true, valueColor: AppColors.primary),
              ],
            ])),
          ] else ...[
            AmountPicker(ctrl: _amount, quickAmounts: _sub?.quickAmounts.isNotEmpty == true ? _sub!.quickAmounts : const [5, 10, 15, 25, 50, 100],
              validator: (v) { if (v == null || v.isEmpty) return S.required; final a = double.tryParse(v); if (a == null || a < 5) return 'الحد الأدنى 5 ج.م'; if (a > 500) return 'الحد الأقصى 500 ج.م'; return null; }),
            const SizedBox(height: D.md),
            if (_amount.text.isNotEmpty && double.tryParse(_amount.text) != null) AppCard(child: Column(children: [
              SummaryRow(label: 'المبلغ', value: '${_amount.text} ${S.egp}'),
              SummaryRow(label: S.fee, value: '${_fee.toStringAsFixed(2)} ${S.egp}'),
              const Divider(height: 20),
              SummaryRow(label: S.total, value: '${((double.tryParse(_amount.text) ?? 0) + _fee).toStringAsFixed(2)} ${S.egp}', bold: true, valueColor: AppColors.primary),
            ])),
          ],
          const SizedBox(height: D.lg),
          // REQUEST products submit a bill request instead of an instant charge.
          if (_sub?.isRequest == true)
            AppButton(label: 'إرسال الطلب', icon: Icons.send_rounded, isLoading: _reqSubmitting, onPressed: _reqSubmitting ? null : _submitRequest)
          else
          AppButton(label: _sub?.isBundle == true ? 'اشترِ الباقة' : 'شحن الآن', isLoading: isSubmitting, onPressed: () async {
            final isBundle = _sub?.isBundle == true;
            // For bundles skip amount validation (price is fixed); still need phone.
            if (_provider == null) return;
            if (isBundle) {
              if (_phone.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text(S.required), backgroundColor: AppColors.error)); return; }
            } else if (!_form.currentState!.validate()) { return; }
            final amount = isBundle ? (_sub!.bundlePrice ?? 0) : double.parse(_amount.text);
            final total  = amount + (_sub?.feeFor(amount) ?? _fee);
            // Gate on wallet balance — offer pay-later (if eligible) or top-up.
            final hs = context.read<HomeBloc>().state;
            final user = hs is HomeLoaded ? hs.user : null;
            final balance = user?.walletBalance ?? 0.0;
            if (balance < total) {
              final choice = await showInsufficientBalanceChoice(context,
                current: balance, needed: total, payLaterEligible: user?.payLaterEligible ?? false);
              if (choice == 'recharge' && context.mounted) { context.push(AppRoutes.walletTopup); return; }
              if (choice == 'activate' && context.mounted) { context.push(AppRoutes.payLater); return; }
              if (choice == 'paylater' && context.mounted) {
                // Pay on credit: complete now, wallet goes negative.
                setState(() {});
                try {
                  await UserRepo().createRequest(
                    serviceProviderId: _provider!.id, subServiceId: _sub?.id,
                    type: 'MOBILE_RECHARGE', amount: amount, phoneNumber: _phone.text.trim(), usePayLater: true);
                  if (!context.mounted) return;
                  context.read<HomeBloc>().add(HomeRefreshEvent());
                  await showModalBottomSheet(context: context, isScrollControlled: true, builder: (_) => SuccessSheet(
                    title: 'تم الدفع بالآجل 🟠', subtitle: 'تم تنفيذ طلبك على الحساب. رصيدك أصبح بالسالب حتى السداد.',
                    onDone: () { Navigator.pop(context); context.pop(); }));
                } on ApiException catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
                }
              }
              return;
            }
            if (!context.mounted) return;
            ctx.read<RechargeBloc>().add(RechargeSubmitEvent(
              providerId: _provider!.id, subServiceId: _sub?.id ?? '',
              phone: _phone.text.trim(), amount: amount));
          }),
          const SizedBox(height: D.xxl),
        ])));
      }));
}
