// User-side requests list + detail. The detail screen is what notification taps
// land on when the admin sets an amount on a bill payment — it shows the
// admin-set amount, payment numbers to transfer to, and an upload-proof flow.
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/screens/phase2/phase2_screens.dart' show PaymentNumbersBlock;
import 'package:intl/intl.dart' as intl;

// ════════════════════════════════════════════════════════
//  MY REQUESTS — list view (filterable by status)
// ════════════════════════════════════════════════════════
class UserRequestsScreen extends StatefulWidget {
  const UserRequestsScreen({super.key});
  @override State<UserRequestsScreen> createState() => _UserRequestsState();
}
class _UserRequestsState extends State<UserRequestsScreen> {
  static const _filters = [
    ('الكل', null),
    ('بانتظار السداد', 'AWAITING_PAYMENT'),
    ('قيد المراجعة', 'PENDING'),
    ('جارٍ', 'IN_PROGRESS'),
    ('مكتمل', 'COMPLETED'),
    ('فشل', 'FAILED'),
  ];
  String? _filter;
  bool _loading = true;
  List<RequestModel> _items = [];

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await UserRepo().getRequests(status: _filter);
      if (mounted) setState(() { _items = r.data; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: const Text('طلباتي'),
      leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded),
        onPressed: () => Navigator.of(context).canPop() ? context.pop() : context.go(AppRoutes.home)),
    ),
    body: Column(children: [
      SizedBox(height: 52, child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: D.md, vertical: 10),
        children: _filters.map((f) {
          final selected = _filter == f.$2;
          return Padding(padding: const EdgeInsets.only(left: 8), child: FilterChip(
            label: Text(f.$1, style: TS.cap.copyWith(
              color: selected ? AppColors.primary : AppColors.textSec,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            )),
            selected: selected,
            onSelected: (_) { setState(() => _filter = f.$2); _load(); },
            selectedColor: AppColors.infoBg,
            checkmarkColor: AppColors.primary,
            side: BorderSide(color: selected ? AppColors.primary : AppColors.border),
            backgroundColor: AppColors.surface,
          ));
        }).toList(),
      )),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : RefreshIndicator(color: AppColors.primary, onRefresh: _load, child: _items.isEmpty
            ? ListView(children: const [SizedBox(height: 120), Center(child: Text('لا توجد طلبات بعد'))])
            : ListView.builder(
                padding: const EdgeInsets.all(D.md),
                itemCount: _items.length,
                itemBuilder: (_, i) => _RequestTile(req: _items[i]),
              ))),
    ]),
  );
}

class _RequestTile extends StatelessWidget {
  final RequestModel req;
  const _RequestTile({required this.req});
  @override
  Widget build(BuildContext context) {
    final c = _statusColor(req.status);
    final shownAmount = req.adminSetAmount ?? req.totalAmount;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: () => context.push('${AppRoutes.requestDetail}/${req.id}'),
        leading: CircleAvatar(backgroundColor: c.withOpacity(0.12), child: Icon(_typeIcon(req.type), color: c)),
        title: Text(kTypeNames[req.type] ?? req.type, style: TS.bodyM),
        subtitle: Text(
          '${shownAmount.toStringAsFixed(2)} ${S.egp}'
          ' • ${intl.DateFormat('yyyy/MM/dd HH:mm').format(req.createdAt)}',
          style: TS.cap,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(_statusLabel(req.status), style: TS.cap.copyWith(color: c, fontWeight: FontWeight.w600)),
        ),
      ),
    );
  }
}

IconData _typeIcon(String t) {
  switch (t) {
    case 'MOBILE_RECHARGE':       return Icons.smartphone_rounded;
    case 'BILL_PAYMENT':          return Icons.receipt_long_rounded;
    case 'INTERNET_RECHARGE':     return Icons.wifi_rounded;
    case 'WALLET_TOPUP':          return Icons.account_balance_wallet_rounded;
    case 'INSTAPAY_DEPOSIT':      return Icons.bolt_rounded;
    case 'BANK_TRANSFER':         return Icons.account_balance_rounded;
    case 'PAY_LATER_ACTIVATION':  return Icons.credit_card_rounded;
    case 'VODAFONE_CASH_DEPOSIT': return Icons.account_balance_wallet_rounded;
    default:                      return Icons.payments_rounded;
  }
}
Color _statusColor(String s) {
  switch (s) {
    case 'COMPLETED': return AppColors.success;
    case 'AWAITING_PAYMENT': return AppColors.warning;
    case 'PAID':      return AppColors.info;
    case 'PENDING':   return AppColors.warning;
    case 'IN_PROGRESS': return AppColors.info;
    case 'FAILED':    return AppColors.error;
    case 'REJECTED':  return AppColors.error;
    case 'REFUNDED':  return AppColors.info;
    default:          return AppColors.textMuted;
  }
}
String _statusLabel(String s) => {
  'PENDING': 'قيد المراجعة',
  'AWAITING_PAYMENT': 'بانتظار السداد',
  'PAID': 'مدفوعة',
  'ASSIGNED': 'تم التعيين',
  'IN_PROGRESS': 'جارٍ',
  'COMPLETED': 'مكتمل',
  'FAILED': 'فشل',
  'REJECTED': 'مرفوض',
  'REFUNDED': 'مسترد',
  'ESCALATED': 'مُصعَّد',
}[s] ?? s;

// ════════════════════════════════════════════════════════
//  REQUEST DETAIL — handles AWAITING_PAYMENT pay-and-upload flow
// ════════════════════════════════════════════════════════
class UserRequestDetailScreen extends StatefulWidget {
  final String requestId;
  const UserRequestDetailScreen({super.key, required this.requestId});
  @override State<UserRequestDetailScreen> createState() => _UserRequestDetailState();
}
class _UserRequestDetailState extends State<UserRequestDetailScreen> {
  RequestModel? _req;
  bool _loading = true;
  bool _uploading = false;
  File? _proof;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await UserRepo().getRequest(widget.requestId);
      if (mounted) setState(() { _req = r; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _showErr('فشل تحميل الطلب: $e'); }
    }
  }

  void _showErr(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: AppColors.error));
  void _showOk(String m) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(m), backgroundColor: AppColors.success));

  Future<void> _pickProof(ImageSource src) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: src, imageQuality: 78, maxWidth: 1600);
    if (file != null && mounted) setState(() => _proof = File(file.path));
  }

  Future<void> _uploadProof() async {
    if (_proof == null) { _showErr('يرجى اختيار صورة الإثبات أولاً'); return; }
    setState(() => _uploading = true);
    try {
      await UserRepo().uploadProof(widget.requestId, _proof!.path);
      if (!mounted) return;
      _showOk('تم رفع الإثبات بنجاح — سيراجعه المسؤول');
      await _load();
    } catch (e) {
      if (mounted) _showErr('فشل رفع الإثبات: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('تفاصيل الطلب'),
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).canPop() ? context.pop() : context.go(AppRoutes.myRequests)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          if (_req != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'محادثة الدعم',
              onPressed: () => context.push('${AppRoutes.requestChat}/${_req!.id}'),
            ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _req == null ? const Center(child: Text('الطلب غير موجود'))
        : _buildBody(_req!),
    );
  }

  Widget _buildBody(RequestModel r) {
    final c = _statusColor(r.status);
    final shownAmount = r.adminSetAmount ?? r.totalAmount;
    return ListView(padding: const EdgeInsets.all(D.md), children: [
      // Status banner
      Container(
        padding: const EdgeInsets.all(D.md),
        decoration: BoxDecoration(color: c.withOpacity(0.10), borderRadius: BorderRadius.circular(D.r16),
          border: Border.all(color: c.withOpacity(0.3))),
        child: Row(children: [
          Icon(_typeIcon(r.type), color: c, size: 28), const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(kTypeNames[r.type] ?? r.type, style: TS.bodyM.copyWith(color: c)),
            const SizedBox(height: 2),
            Text(_statusLabel(r.status), style: TS.cap.copyWith(color: c, fontWeight: FontWeight.w600)),
          ])),
          Text('${shownAmount.toStringAsFixed(2)} ${S.egp}', style: TS.h3.copyWith(color: c)),
        ]),
      ),
      const SizedBox(height: D.md),

      // AWAITING_PAYMENT — show admin-set amount + payment numbers + upload-proof CTA
      if (r.isAwaitingPayment) _buildAwaitingPaymentBlock(r),

      // Generic details
      const SizedBox(height: D.md),
      Container(
        padding: const EdgeInsets.all(D.md),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(D.r16),
          border: Border.all(color: AppColors.border)),
        child: Column(children: [
          _detailRow('رقم الطلب', '#${r.id.substring(0, 8).toUpperCase()}'),
          _detailRow('التاريخ', intl.DateFormat('yyyy/MM/dd HH:mm').format(r.createdAt)),
          if (r.serviceProvider != null) _detailRow('المزوّد', r.serviceProvider!.displayName),
          if (r.subService != null)      _detailRow('الخدمة', r.subService!.nameAr),
          if (r.billingNumber != null)   _detailRow('رقم الفاتورة', r.billingNumber!, ltr: true),
          if (r.accountNumber != null)   _detailRow('رقم الحساب', r.accountNumber!, ltr: true),
          if (r.phoneNumber   != null)   _detailRow('رقم الهاتف', r.phoneNumber!,   ltr: true),
          if (r.fee > 0) _detailRow('رسوم الخدمة', '${r.fee.toStringAsFixed(2)} ${S.egp}'),
          _detailRow('الإجمالي', '${shownAmount.toStringAsFixed(2)} ${S.egp}', bold: true),
        ]),
      ),

      // Existing proof image (if any)
      if (r.proofImageUrl != null) ...[
        const SizedBox(height: D.md),
        Text('إثبات الدفع المرفوع', style: TS.bodyM),
        const SizedBox(height: D.sm),
        ClipRRect(borderRadius: BorderRadius.circular(D.r12),
          child: CachedNetworkImage(imageUrl: r.proofImageUrl!,
            height: 220, width: double.infinity, fit: BoxFit.cover,
            errorWidget: (_,__,___) => Container(height: 220, color: AppColors.errorBg,
              child: const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.error))))),
      ],

      if (r.adminNote != null && r.adminNote!.isNotEmpty) ...[
        const SizedBox(height: D.md),
        Container(padding: const EdgeInsets.all(D.md),
          decoration: BoxDecoration(color: AppColors.infoBg, borderRadius: BorderRadius.circular(D.r12)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.message_rounded, color: AppColors.info, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(r.adminNote!, style: TS.body)),
          ])),
      ],
      const SizedBox(height: D.xxl),
    ]);
  }

  Widget _buildAwaitingPaymentBlock(RequestModel r) {
    return Container(
      padding: const EdgeInsets.all(D.md),
      decoration: BoxDecoration(color: AppColors.warning.withOpacity(0.08),
        borderRadius: BorderRadius.circular(D.r16),
        border: Border.all(color: AppColors.warning.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.credit_score_rounded, color: AppColors.warning),
          const SizedBox(width: 8),
          Text('قيمة الفاتورة من الإدارة', style: TS.bodyM.copyWith(color: AppColors.warning)),
        ]),
        const SizedBox(height: D.sm),
        Text('${(r.adminSetAmount ?? r.totalAmount).toStringAsFixed(2)} ${S.egp}',
          style: TS.h1.copyWith(color: AppColors.warning, fontSize: 28)),
        const SizedBox(height: D.sm),
        Text('قم بتحويل المبلغ إلى أحد الأرقام التالية ثم ارفع إثبات الدفع — '
             'سيتم تأكيد الفاتورة بعد المراجعة.', style: TS.cap.copyWith(color: AppColors.textSec)),
        const SizedBox(height: D.md),

        // Admin-managed payment numbers (all types so user can pick the channel)
        const PaymentNumbersBlock(),

        const Divider(height: D.lg),
        Text('رفع إثبات الدفع', style: TS.bodyM),
        const SizedBox(height: D.sm),
        if (_proof != null) ...[
          ClipRRect(borderRadius: BorderRadius.circular(D.r12),
            child: Image.file(_proof!, height: 180, width: double.infinity, fit: BoxFit.cover)),
          const SizedBox(height: D.sm),
        ],
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.camera_alt_rounded, size: 18),
            label: Text(_proof == null ? 'التقاط' : 'إعادة الالتقاط'),
            onPressed: _uploading ? null : () => _pickProof(ImageSource.camera),
          )),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(
            icon: const Icon(Icons.photo_library_rounded, size: 18),
            label: Text(_proof == null ? 'من المعرض' : 'تغيير'),
            onPressed: _uploading ? null : () => _pickProof(ImageSource.gallery),
          )),
        ]),
        const SizedBox(height: D.md),
        SizedBox(width: double.infinity, child: ElevatedButton.icon(
          icon: _uploading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.cloud_upload_rounded),
          label: Text(_uploading ? 'جارٍ الرفع...' : 'رفع الإثبات'),
          onPressed: (_uploading || _proof == null) ? null : _uploadProof,
        )),
      ]),
    );
  }

  Widget _detailRow(String label, String value, {bool bold = false, bool ltr = false}) =>
    Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      Text('$label: ', style: TS.cap.copyWith(color: AppColors.textMuted)),
      Expanded(child: Text(value, style: bold ? TS.bodyM.copyWith(color: AppColors.primary) : TS.body,
        textDirection: ltr ? TextDirection.ltr : null,
        textAlign: ltr ? TextAlign.left : TextAlign.right)),
    ]));
}
