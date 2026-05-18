import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

// ════════════════════════════════════════════════════════
// REPO ADDITIONS (Phase 2)
// ════════════════════════════════════════════════════════
class PaymentNumber {
  final String id, type, number, label; final bool isActive;
  const PaymentNumber({required this.id, required this.type, required this.number, required this.label, this.isActive = true});
  factory PaymentNumber.fromJson(Map<String,dynamic> j) => PaymentNumber(
    id: j['id'] as String, type: j['type'] as String,
    number: j['number'] as String, label: j['label'] as String,
    isActive: (j['isActive'] as bool?) ?? true,
  );
}

class Phase2Repo {
  final _c = ApiClient.instance;

  Future<List<PaymentNumber>> getPaymentNumbers({String? type, String? serviceId}) async {
    final res = await _c.get('/payment-numbers', params: {
      if (type != null) 'type': type,
      if (serviceId != null) 'serviceId': serviceId,
    });
    return ((res['data'] as List<dynamic>?) ?? [])
      .map((e) => PaymentNumber.fromJson(e as Map<String,dynamic>))
      .toList();
  }

  Future<Map<String,dynamic>> createInstaPay({required String recipient, required double amount, String? note}) async {
    final res = await _c.post('/user/requests', body: {
      'type': 'INSTAPAY_DEPOSIT', 'amount': amount,
      'instapayId': recipient,
      if (note != null && note.isNotEmpty) 'paymentMethod': note,
    });
    return res['data'] as Map<String,dynamic>;
  }

  Future<Map<String,dynamic>> createBankTransfer({required String bankName, required String receiverName, required String bankAccount, required double amount}) async {
    final res = await _c.post('/user/requests', body: {
      'type': 'BANK_TRANSFER', 'amount': amount,
      'bankName': bankName, 'receiverName': receiverName, 'bankAccount': bankAccount,
    });
    return res['data'] as Map<String,dynamic>;
  }

  Future<Map<String,dynamic>> createSmartBilling({required String serviceProviderId, String? subServiceId, required String billingNumber, String? billingType}) async {
    final res = await _c.post('/user/requests', body: {
      'type': 'BILL_PAYMENT', 'amount': 0,
      'serviceProviderId': serviceProviderId,
      if (subServiceId != null) 'subServiceId': subServiceId,
      'billingNumber': billingNumber,
      if (billingType != null) 'billingType': billingType,
    });
    return res['data'] as Map<String,dynamic>;
  }

  Future<List<Map<String,dynamic>>> listMessages(String requestId) async {
    final res = await _c.get('/requests/$requestId/messages');
    return ((res['data'] as List<dynamic>?) ?? []).cast<Map<String,dynamic>>();
  }

  Future<Map<String,dynamic>> sendMessage(String requestId, String body) async {
    final res = await _c.post('/requests/$requestId/messages', body: {'body': body});
    return res['data'] as Map<String,dynamic>;
  }

  Future<Map<String,String>> getPublicSettings() async {
    final res = await _c.get('/settings/public');
    final d = (res['data'] as Map<String,dynamic>?) ?? {};
    return d.map((k, v) => MapEntry(k, v?.toString() ?? ''));
  }
}

// ════════════════════════════════════════════════════════
// REUSABLE — Payment numbers display (tap to copy)
// ════════════════════════════════════════════════════════
class PaymentNumbersBlock extends StatefulWidget {
  // Pass a type ('WALLET' | 'INSTAPAY' | 'BANK') to filter, or leave null to
  // show every active payment number (each row shows its type icon + label so
  // the user can pick the channel they want).
  final String? type;
  const PaymentNumbersBlock({super.key, this.type});
  @override State<PaymentNumbersBlock> createState() => _PNBState();
}
class _PNBState extends State<PaymentNumbersBlock> {
  List<PaymentNumber> _items = [];
  bool _loading = true;
  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { final r = await Phase2Repo().getPaymentNumbers(type: widget.type); if (mounted) setState(() { _items = r; _loading = false; }); }
    catch (e) { if (mounted) setState(() => _loading = false); }
  }
  @override Widget build(BuildContext context) {
    if (_loading) return const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
    if (_items.isEmpty) return Padding(padding: const EdgeInsets.all(12), child: Text('لا توجد أرقام دفع متاحة، يرجى التواصل مع الدعم', style: TS.cap.copyWith(color: AppColors.textMuted)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: _items.map((it) => GestureDetector(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: it.number));
        HapticFeedback.lightImpact();
        if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم النسخ'), duration: Duration(seconds: 1)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Row(children: [
          Icon(_iconFor(it.type), color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(it.label, style: TS.bodyM),
            const SizedBox(height: 2),
            Text(it.number, style: TS.body.copyWith(color: AppColors.primary, letterSpacing: 0.5), textDirection: TextDirection.ltr),
          ])),
          const Icon(Icons.copy_rounded, color: AppColors.primary, size: 18),
        ]),
      ),
    )).toList());
  }

  IconData _iconFor(String t) {
    if (t == 'WALLET') return Icons.account_balance_wallet_rounded;
    if (t == 'INSTAPAY') return Icons.bolt_rounded;
    if (t == 'BANK') return Icons.account_balance_rounded;
    return Icons.payments_rounded;
  }
}

// ════════════════════════════════════════════════════════
// INSUFFICIENT BALANCE MODAL
// ════════════════════════════════════════════════════════
Future<bool> showInsufficientBalanceModal(BuildContext context, {required double current, required double needed}) async {
  final shortfall = needed - current;
  final result = await showModalBottomSheet<bool>(
    context: context, isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(left: D.lg, right: D.lg, top: D.lg, bottom: MediaQuery.of(context).viewInsets.bottom + D.lg),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 64, height: 64, decoration: const BoxDecoration(color: AppColors.errorBg, shape: BoxShape.circle),
          child: const Icon(Icons.warning_amber_rounded, color: AppColors.error, size: 40)),
        const SizedBox(height: D.md),
        Text('الرصيد غير كافٍ', style: TS.h2, textAlign: TextAlign.center),
        const SizedBox(height: D.sm),
        Text('رصيدك الحالي: ${current.toStringAsFixed(2)} ${S.egp}', style: TS.body.copyWith(color: AppColors.textSec)),
        Text('المبلغ المطلوب: ${needed.toStringAsFixed(2)} ${S.egp}', style: TS.body.copyWith(color: AppColors.textSec)),
        Text('النقص: ${shortfall.toStringAsFixed(2)} ${S.egp}', style: TS.bodyM.copyWith(color: AppColors.error)),
        const SizedBox(height: D.lg),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          icon: const Icon(Icons.add_circle_rounded), label: const Text('شحن المحفظة الآن'),
          onPressed: () => Navigator.pop(_, true),
        )),
        const SizedBox(height: D.sm),
        SizedBox(width: double.infinity, child: TextButton(onPressed: () => Navigator.pop(_, false), child: const Text('إلغاء'))),
      ]),
    ),
  );
  return result == true;
}

// ════════════════════════════════════════════════════════
// INSTAPAY DEPOSIT
// ════════════════════════════════════════════════════════
class InstaPayScreen extends StatefulWidget { const InstaPayScreen({super.key}); @override State<InstaPayScreen> createState() => _IPState(); }
class _IPState extends State<InstaPayScreen> {
  final _form = GlobalKey<FormState>();
  final _recipient = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  bool _loading = false;

  @override void dispose() { _recipient.dispose(); _amount.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final amount = double.parse(_amount.text.trim());
    final user = (context.read<HomeBloc>().state is HomeLoaded) ? (context.read<HomeBloc>().state as HomeLoaded).user : null;
    final balance = user?.walletBalance ?? 0;
    if (balance < amount) {
      final go = await showInsufficientBalanceModal(context, current: balance, needed: amount);
      if (go && mounted) context.push(AppRoutes.walletTopup);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await Phase2Repo().createInstaPay(recipient: _recipient.text.trim(), amount: amount, note: _note.text.trim().isEmpty ? null : _note.text.trim());
      if (!mounted) return;
      context.read<HomeBloc>().add(HomeRefreshEvent());
      await showModalBottomSheet(context: context, isDismissible: false, enableDrag: false,
        builder: (_) => SuccessSheet(
          title: r['status'] == 'COMPLETED' ? 'تم التحويل تلقائياً' : 'تم إرسال الطلب',
          subtitle: r['status'] == 'COMPLETED'
            ? 'تم خصم ${amount.toStringAsFixed(2)} ${S.egp} وتنفيذ التحويل عبر InstaPay'
            : 'سيتم تنفيذ التحويل بعد المراجعة',
          onDone: () { Navigator.pop(context); context.pop(); },
        ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('تحويل InstaPay')),
    body: SafeArea(child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(D.md), children: [
      AppCard(padding: const EdgeInsets.all(D.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('بيانات التحويل', style: TS.bodyM), const SizedBox(height: D.sm),
        AppField(label: 'InstaPay ID أو رقم الهاتف', ctrl: _recipient, kb: TextInputType.text,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل بيانات المستلم' : null),
        const SizedBox(height: D.sm),
        AppField(label: 'المبلغ (ج.م)', ctrl: _amount, kb: const TextInputType.numberWithOptions(decimal: true),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          validator: (v) {
            final n = double.tryParse((v ?? '').trim()); if (n == null || n < 1) return 'أدخل مبلغاً صحيحاً'; if (n > 50000) return 'الحد الأقصى 50000'; return null;
          }),
        const SizedBox(height: D.sm),
        AppField(label: 'ملاحظة (اختياري)', ctrl: _note, maxLines: 2),
      ])),
      const SizedBox(height: D.md),
      AppCard(padding: const EdgeInsets.all(D.md), child: Row(children: [
        Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18), const SizedBox(width: 8),
        Expanded(child: Text('إذا كان رصيد محفظتك كافياً، سيتم الخصم وتنفيذ التحويل تلقائياً. وإلا سيتم تحويل طلبك للمراجعة.', style: TS.cap.copyWith(color: AppColors.textSec))),
      ])),
      const SizedBox(height: D.lg),
      AppButton(label: 'إرسال التحويل', icon: Icons.send_rounded, isLoading: _loading, onPressed: _loading ? null : _submit),
    ]))),
  );
}

// ════════════════════════════════════════════════════════
// BANK TRANSFER
// ════════════════════════════════════════════════════════
class BankTransferScreen extends StatefulWidget { const BankTransferScreen({super.key}); @override State<BankTransferScreen> createState() => _BTState(); }
class _BTState extends State<BankTransferScreen> {
  final _form = GlobalKey<FormState>();
  final _bank = TextEditingController();
  final _receiver = TextEditingController();
  final _account = TextEditingController();
  final _amount = TextEditingController();
  bool _loading = false;
  static const _banks = ['البنك الأهلي المصري', 'بنك مصر', 'CIB', 'بنك QNB', 'بنك الإسكندرية', 'البنك العربي الإفريقي', 'بنك HSBC', 'بنك فيصل', 'أخرى'];

  @override void dispose() { _bank.dispose(); _receiver.dispose(); _account.dispose(); _amount.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final amount = double.parse(_amount.text.trim());
    final user = (context.read<HomeBloc>().state is HomeLoaded) ? (context.read<HomeBloc>().state as HomeLoaded).user : null;
    final balance = user?.walletBalance ?? 0;
    if (balance < amount) {
      final go = await showInsufficientBalanceModal(context, current: balance, needed: amount);
      if (go && mounted) context.push(AppRoutes.walletTopup);
      return;
    }
    setState(() => _loading = true);
    try {
      final r = await Phase2Repo().createBankTransfer(
        bankName: _bank.text.trim(), receiverName: _receiver.text.trim(),
        bankAccount: _account.text.trim(), amount: amount);
      if (!mounted) return;
      context.read<HomeBloc>().add(HomeRefreshEvent());
      await showModalBottomSheet(context: context, isDismissible: false, enableDrag: false,
        builder: (_) => SuccessSheet(
          title: r['status'] == 'COMPLETED' ? 'تم التحويل' : 'تم إرسال طلب التحويل',
          subtitle: r['status'] == 'COMPLETED'
            ? 'تم خصم ${amount.toStringAsFixed(2)} ${S.egp} وتنفيذ التحويل'
            : 'سيتم تنفيذ التحويل البنكي بعد المراجعة',
          onDone: () { Navigator.pop(context); context.pop(); },
        ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('تحويل بنكي')),
    body: SafeArea(child: Form(key: _form, child: ListView(padding: const EdgeInsets.all(D.md), children: [
      AppCard(padding: const EdgeInsets.all(D.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('بيانات التحويل البنكي', style: TS.bodyM), const SizedBox(height: D.sm),
        // Bank picker (simple Autocomplete-like with dropdown)
        Autocomplete<String>(
          optionsBuilder: (text) => _banks.where((b) => b.toLowerCase().contains(text.text.trim().toLowerCase())),
          fieldViewBuilder: (ctx, ctrl, focus, _) {
            _bank.text = ctrl.text;
            return TextFormField(controller: ctrl, focusNode: focus, textDirection: TextDirection.rtl,
              decoration: const InputDecoration(labelText: 'اسم البنك', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم البنك' : null,
              onChanged: (v) => _bank.text = v.trim());
          },
        ),
        const SizedBox(height: D.sm),
        AppField(label: 'اسم المستلم', ctrl: _receiver,
          validator: (v) => (v == null || v.trim().isEmpty) ? 'أدخل اسم المستلم' : null),
        const SizedBox(height: D.sm),
        AppField(label: 'رقم الحساب البنكي / IBAN', ctrl: _account, kb: TextInputType.text,
          validator: (v) => (v == null || v.trim().length < 6) ? 'رقم الحساب غير صحيح' : null),
        const SizedBox(height: D.sm),
        AppField(label: 'المبلغ (ج.م)', ctrl: _amount, kb: const TextInputType.numberWithOptions(decimal: true),
          formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
          validator: (v) {
            final n = double.tryParse((v ?? '').trim()); if (n == null || n < 1) return 'أدخل مبلغاً صحيحاً'; if (n > 100000) return 'الحد الأقصى 100000'; return null;
          }),
      ])),
      const SizedBox(height: D.lg),
      AppButton(label: 'إرسال طلب التحويل', icon: Icons.send_rounded, isLoading: _loading, onPressed: _loading ? null : _submit),
    ]))),
  );
}

// ════════════════════════════════════════════════════════
// SMART BILLING (admin will set the amount)
// ════════════════════════════════════════════════════════
class SmartBillingScreen extends StatefulWidget {
  final String category; // TELECOM | ELECTRICITY | GAS | WATER | INTERNET
  const SmartBillingScreen({super.key, required this.category});
  @override State<SmartBillingScreen> createState() => _SBState();
}
class _SBState extends State<SmartBillingScreen> {
  final _billing = TextEditingController();
  bool _loading = false;
  ServiceProviderModel? _provider;
  SubServiceModel? _sub;

  @override void dispose() { _billing.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_provider == null) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('اختر المزود'))); return; }
    if (_billing.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل رقم الفاتورة'))); return; }
    setState(() => _loading = true);
    try {
      await Phase2Repo().createSmartBilling(
        serviceProviderId: _provider!.id, subServiceId: _sub?.id,
        billingNumber: _billing.text.trim(), billingType: widget.category);
      if (!mounted) return;
      context.read<HomeBloc>().add(HomeRefreshEvent());
      await showModalBottomSheet(context: context, isDismissible: false, enableDrag: false,
        builder: (_) => SuccessSheet(
          title: 'تم إرسال طلب الفاتورة',
          subtitle: 'سيقوم الفريق بالاستعلام عن قيمة الفاتورة وإعلامك بها. ثم يمكنك السداد من رصيدك أو رفع إثبات دفع.',
          onDone: () { Navigator.pop(context); context.pop(); },
        ));
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('استعلام وسداد فاتورة')),
    body: BlocBuilder<HomeBloc, HomeState>(builder: (ctx, state) {
      if (state is! HomeLoaded) return const Center(child: CircularProgressIndicator());
      final providers = (state.categories[widget.category] ?? []);
      if (_provider != null && !providers.any((p) => p.id == _provider!.id)) _provider = null;
      return SafeArea(child: ListView(padding: const EdgeInsets.all(D.md), children: [
        AppCard(padding: const EdgeInsets.all(D.md), child: ProviderSelector(
          providers: providers, selected: _provider, onSelect: (p) => setState(() { _provider = p; _sub = null; }),
        )),
        if (_provider != null && _provider!.subServices.isNotEmpty) ...[
          const SizedBox(height: D.md),
          AppCard(padding: const EdgeInsets.all(D.md), child: SubServiceSelector(
            subServices: _provider!.subServices, selected: _sub, onSelect: (s) => setState(() => _sub = s),
          )),
        ],
        const SizedBox(height: D.md),
        AppCard(padding: const EdgeInsets.all(D.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('رقم الفاتورة / الحساب', style: TS.bodyM), const SizedBox(height: D.sm),
          AppField(label: 'الرقم', ctrl: _billing, kb: TextInputType.text),
        ])),
        const SizedBox(height: D.md),
        AppCard(padding: const EdgeInsets.all(D.md), child: Row(children: [
          Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(
            'أرسل رقم الفاتورة فقط — سنخبرك بالقيمة. إذا كان رصيد محفظتك يكفي سيتم الخصم تلقائياً، وإلا سيُطلب منك السداد ورفع إيصال.',
            style: TS.cap.copyWith(color: AppColors.textSec),
          )),
        ])),
        const SizedBox(height: D.lg),
        AppButton(label: 'إرسال', icon: Icons.send_rounded, isLoading: _loading, onPressed: _loading ? null : _submit),
      ]));
    }),
  );
}

// ════════════════════════════════════════════════════════
// REQUEST CHAT (user side)
// ════════════════════════════════════════════════════════
class UserRequestChatScreen extends StatefulWidget {
  final String requestId;
  const UserRequestChatScreen({super.key, required this.requestId});
  @override State<UserRequestChatScreen> createState() => _UCState();
}
class _UCState extends State<UserRequestChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String,dynamic>> _msgs = [];
  bool _loading = true; bool _sending = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _input.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final msgs = await Phase2Repo().listMessages(widget.requestId);
      if (mounted) setState(() { _msgs = msgs; _loading = false; });
      Future.delayed(const Duration(milliseconds: 100), () { if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); });
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await Phase2Repo().sendMessage(widget.requestId, body);
      _input.clear();
      if (mounted) setState(() { _msgs = [..._msgs, m]; _sending = false; });
      Future.delayed(const Duration(milliseconds: 50), () { if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent); });
    } catch (_) { if (mounted) setState(() => _sending = false); }
  }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: Text('محادثة #${widget.requestId.substring(0, 8)}'), actions: [
      IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
    ]),
    body: Column(children: [
      Expanded(child: _loading ? const Center(child: CircularProgressIndicator())
        : _msgs.isEmpty ? const Center(child: Text('لا توجد رسائل بعد. اكتب رسالة لبدء المحادثة.'))
        : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(D.md), itemCount: _msgs.length, itemBuilder: (_, i) {
            final m = _msgs[i];
            final isUser = m['userId'] != null;
            return Align(
              alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: isUser ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isUser ? AppColors.primary : AppColors.borderLight),
                ),
                child: Text(m['body']?.toString() ?? '', style: TS.body.copyWith(color: isUser ? Colors.white : AppColors.text)),
              ),
            );
          })),
      SafeArea(top: false, child: Container(
        padding: const EdgeInsets.all(8),
        decoration: const BoxDecoration(color: AppColors.surface, border: Border(top: BorderSide(color: AppColors.borderLight))),
        child: Row(children: [
          Expanded(child: TextField(controller: _input, textDirection: TextDirection.rtl, maxLines: 3, minLines: 1,
            decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder(), isDense: true,
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
          const SizedBox(width: 8),
          IconButton(icon: Icon(_sending ? Icons.hourglass_top_rounded : Icons.send_rounded, color: AppColors.primary),
            onPressed: _sending ? null : _send),
        ]),
      )),
    ]),
  );
}
