import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'admin_core.dart';
import 'admin_api.dart';

// Helpers reused from main.dart
void _showErr(BuildContext ctx, String msg) =>
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AC.error));
void _showOk(BuildContext ctx, String msg) =>
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg), backgroundColor: AC.success));

// Reusable copy-to-clipboard widget — places a small clipboard icon next to a value.
class CopyField extends StatelessWidget {
  final String label;
  final String value;
  final TextDirection? direction;
  const CopyField({super.key, required this.label, required this.value, this.direction});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Text('$label: ', style: AT.cap),
      Expanded(child: Text(value, style: AT.capM, textDirection: direction)),
      IconButton(
        padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, iconSize: 18,
        icon: const Icon(Icons.copy_rounded, color: AC.primary),
        tooltip: 'نسخ',
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: value));
          HapticFeedback.lightImpact();
          if (context.mounted) _showOk(context, 'تم النسخ');
        },
      ),
    ]),
  );
}

// ════════════════════════════════════════════════════════
//  PAYMENT NUMBERS SCREEN
// ════════════════════════════════════════════════════════
class PaymentNumbersScreen extends StatefulWidget { const PaymentNumbersScreen({super.key}); @override State<PaymentNumbersScreen> createState() => _PNState(); }
class _PNState extends State<PaymentNumbersScreen> {
  List<Map<String,dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await AdminPaymentNumbersRepo().list();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _showErr(context, '$e'); }
    }
  }

  Future<void> _showForm({Map<String,dynamic>? existing}) async {
    final number = TextEditingController(text: existing?['number']?.toString() ?? '');
    final label  = TextEditingController(text: existing?['label']?.toString() ?? '');
    String type  = (existing?['type'] as String?) ?? 'WALLET';
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(existing == null ? 'إضافة رقم دفع' : 'تعديل رقم دفع'),
      content: StatefulBuilder(builder: (ctx, set) => SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        DropdownButtonFormField<String>(
          value: type,
          decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
          items: const [
            DropdownMenuItem(value: 'WALLET',   child: Text('محفظة (Vodafone/Orange Cash)')),
            DropdownMenuItem(value: 'INSTAPAY', child: Text('InstaPay')),
            DropdownMenuItem(value: 'BANK',     child: Text('حساب بنكي')),
          ],
          onChanged: (v) => set(() => type = v ?? 'WALLET'),
        ),
        const SizedBox(height: 12),
        TextField(controller: label,  decoration: const InputDecoration(labelText: 'الاسم/الوصف', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: number, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'الرقم/الحساب', border: OutlineInputBorder())),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        TextButton(onPressed: () async {
          if (label.text.trim().isEmpty || number.text.trim().isEmpty) { _showErr(context, 'الاسم والرقم مطلوبان'); return; }
          Navigator.pop(context);
          try {
            if (existing == null) {
              await AdminPaymentNumbersRepo().create({'type': type, 'label': label.text.trim(), 'number': number.text.trim()});
            } else {
              await AdminPaymentNumbersRepo().update(existing['id'] as String, {'type': type, 'label': label.text.trim(), 'number': number.text.trim()});
            }
            _load();
            if (mounted) _showOk(context, 'تم الحفظ');
          } catch (e) { if (mounted) _showErr(context, '$e'); }
        }, child: const Text('حفظ')),
      ],
    )).then((_) { number.dispose(); label.dispose(); });
  }

  Future<void> _toggle(Map<String,dynamic> item) async {
    try {
      await AdminPaymentNumbersRepo().update(item['id'] as String, {'isActive': !(item['isActive'] as bool? ?? true)});
      _load();
    } catch (e) { if (mounted) _showErr(context, '$e'); }
  }

  Future<void> _delete(Map<String,dynamic> item) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('حذف'),
      content: Text('سيتم حذف "${item['label']}" نهائياً. متأكد؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: AC.error))),
      ],
    ));
    if (ok != true) return;
    try { await AdminPaymentNumbersRepo().delete(item['id'] as String); _load(); }
    catch (e) { if (mounted) _showErr(context, '$e'); }
  }

  Color _typeColor(String t) {
    if (t == 'WALLET') return AC.accent;
    if (t == 'INSTAPAY') return AC.primary;
    if (t == 'BANK') return AC.b2b;
    return AC.textMuted;
  }
  IconData _typeIcon(String t) {
    if (t == 'WALLET') return Icons.account_balance_wallet_rounded;
    if (t == 'INSTAPAY') return Icons.bolt_rounded;
    if (t == 'BANK') return Icons.account_balance_rounded;
    return Icons.payments_rounded;
  }
  String _typeLabel(String t) {
    if (t == 'WALLET') return 'محفظة';
    if (t == 'INSTAPAY') return 'InstaPay';
    if (t == 'BANK') return 'بنك';
    return t;
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: AC.bg,
    appBar: AppBar(title: const Text('أرقام الدفع'), backgroundColor: AC.primary, actions: [
      IconButton(icon: const Icon(Icons.add_rounded), onPressed: () => _showForm()),
    ]),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.primary))
      : RefreshIndicator(onRefresh: _load, color: AC.primary, child: _items.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('لا توجد أرقام بعد. اضغط + لإضافة رقم.'))])
          : ListView.builder(padding: const EdgeInsets.all(AD.md), itemCount: _items.length, itemBuilder: (_, i) {
              final it = _items[i];
              final type = it['type']?.toString() ?? 'WALLET';
              final active = (it['isActive'] as bool?) ?? true;
              return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
                leading: CircleAvatar(backgroundColor: _typeColor(type).withOpacity(0.12), child: Icon(_typeIcon(type), color: _typeColor(type))),
                title: Text(it['label']?.toString() ?? '—', style: AT.bodyM),
                subtitle: Text('${_typeLabel(type)} • ${it['number']}', style: AT.cap, textDirection: TextDirection.ltr),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Switch.adaptive(value: active, onChanged: (_) => _toggle(it), activeColor: AC.success),
                  IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: AC.primary), onPressed: () => _showForm(existing: it)),
                  IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AC.error), onPressed: () => _delete(it)),
                ]),
              ));
            })),
  );
}

// ════════════════════════════════════════════════════════
//  CLIENT SEARCH + ADD BALANCE
// ════════════════════════════════════════════════════════
class ClientSearchScreen extends StatefulWidget { const ClientSearchScreen({super.key}); @override State<ClientSearchScreen> createState() => _CSState(); }
class _CSState extends State<ClientSearchScreen> {
  final _q = TextEditingController();
  List<Map<String,dynamic>> _items = [];
  bool _loading = false;
  Timer? _debounce;

  @override void initState() { super.initState(); _search(''); }
  @override void dispose() { _q.dispose(); _debounce?.cancel(); super.dispose(); }

  Future<void> _search(String s) async {
    setState(() => _loading = true);
    try {
      final r = await AdminClientsRepo().search(search: s);
      if (mounted) setState(() { _items = r.data; _loading = false; });
    } catch (e) {
      if (mounted) { setState(() => _loading = false); _showErr(context, '$e'); }
    }
  }

  Future<void> _showAddBalance(Map<String,dynamic> u) async {
    final amount = TextEditingController(); final note = TextEditingController();
    await showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('إضافة رصيد — ${u['fullName']}'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'المبلغ (ج.م)', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        TextField(controller: note, maxLines: 2,
          decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder())),
      ])),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        TextButton(onPressed: () async {
          final amt = double.tryParse(amount.text.trim());
          if (amt == null || amt <= 0) { _showErr(context, 'أدخل مبلغاً صحيحاً'); return; }
          Navigator.pop(context);
          try {
            await AdminClientsRepo().addBalance(u['id'] as String, amt, note: note.text.trim().isEmpty ? null : note.text.trim());
            _search(_q.text.trim());
            if (mounted) _showOk(context, 'تم إضافة $amt ج.م');
          } catch (e) { if (mounted) _showErr(context, '$e'); }
        }, child: const Text('إضافة')),
      ],
    )).then((_) { amount.dispose(); note.dispose(); });
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: AC.bg,
    appBar: AppBar(title: const Text('بحث العملاء'), backgroundColor: AC.primary),
    body: Column(children: [
      Padding(padding: const EdgeInsets.all(AD.md), child: TextField(
        controller: _q, textDirection: TextDirection.rtl,
        decoration: InputDecoration(hintText: 'بحث بالاسم أو رقم الهاتف...', prefixIcon: const Icon(Icons.search_rounded),
          filled: true, fillColor: AC.surface, border: OutlineInputBorder(borderRadius: BorderRadius.circular(AD.r12))),
        onChanged: (v) {
          _debounce?.cancel();
          _debounce = Timer(const Duration(milliseconds: 350), () => _search(v.trim()));
        },
      )),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.primary))
        : _items.isEmpty ? const Center(child: Text('لا نتائج'))
        : ListView.builder(padding: const EdgeInsets.all(AD.md), itemCount: _items.length, itemBuilder: (_, i) {
            final u = _items[i];
            final bal = double.tryParse((u['walletBalance'] ?? '0').toString()) ?? 0;
            final name = u['fullName']?.toString() ?? '—';
            return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
              leading: CircleAvatar(backgroundColor: AC.infoBg,
                child: Text(name.isNotEmpty ? name.substring(0, 1) : '?', style: AT.bodyM.copyWith(color: AC.primary))),
              title: Text(name, style: AT.bodyM),
              subtitle: Text('${u['phone']} • رصيد: ${bal.toStringAsFixed(2)} ج.م', style: AT.cap),
              trailing: IconButton(icon: const Icon(Icons.add_circle_rounded, color: AC.success),
                tooltip: 'إضافة رصيد', onPressed: () => _showAddBalance(u)),
            ));
          })),
    ]),
  );
}

// ════════════════════════════════════════════════════════
//  ADMIN SETTINGS SCREEN
// ════════════════════════════════════════════════════════
class AdminSettingsScreen extends StatefulWidget { const AdminSettingsScreen({super.key}); @override State<AdminSettingsScreen> createState() => _SetState(); }
class _SetState extends State<AdminSettingsScreen> {
  final _appName = TextEditingController();
  final _greeting = TextEditingController();
  final _supportPhone = TextEditingController();
  final _brandColor = TextEditingController();
  final _announcement = TextEditingController();
  final _maintMsg = TextEditingController();
  bool _maintMode = false;
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() {
    _appName.dispose(); _greeting.dispose(); _supportPhone.dispose();
    _brandColor.dispose(); _announcement.dispose(); _maintMsg.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await AdminSettingsRepo().list();
      final m = <String,String>{};
      for (final it in items) {
        final k = it['key']?.toString() ?? '';
        final v = it['value']?.toString() ?? '';
        m[k] = v;
      }
      _appName.text      = m['app.name']               ?? 'فى ثانية';
      _greeting.text     = m['app.greeting']           ?? 'مرحباً، {name}!';
      _supportPhone.text = m['app.supportPhone']       ?? '';
      _brandColor.text   = m['app.brandColor']         ?? '#1E40AF';
      _announcement.text = m['app.announcement']       ?? '';
      _maintMode = (m['app.maintenance'] ?? 'false') == 'true';
      _maintMsg.text     = m['app.maintenanceMessage'] ?? 'النظام في وضع الصيانة، حاول لاحقاً';
      if (mounted) setState(() => _loading = false);
    } catch (e) { if (mounted) { setState(() => _loading = false); _showErr(context, '$e'); } }
  }

  Future<void> _save() async {
    try {
      await AdminSettingsRepo().updateBulk({
        'app.name':               _appName.text.trim(),
        'app.greeting':           _greeting.text.trim(),
        'app.supportPhone':       _supportPhone.text.trim(),
        'app.brandColor':         _brandColor.text.trim(),
        'app.announcement':       _announcement.text.trim(),
        'app.maintenance':        _maintMode ? 'true' : 'false',
        'app.maintenanceMessage': _maintMsg.text.trim(),
      });
      if (mounted) _showOk(context, 'تم حفظ الإعدادات');
    } catch (e) { if (mounted) _showErr(context, '$e'); }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: AC.bg,
    appBar: AppBar(title: const Text('إعدادات التطبيق'), backgroundColor: AC.primary),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.primary))
      : ListView(padding: const EdgeInsets.all(AD.md), children: [
          Card(child: Padding(padding: const EdgeInsets.all(AD.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الهوية والشكل', style: AT.h3),
            const SizedBox(height: AD.sm),
            TextField(controller: _appName, decoration: const InputDecoration(labelText: 'اسم التطبيق', border: OutlineInputBorder())),
            const SizedBox(height: AD.sm),
            TextField(controller: _brandColor, textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'اللون الأساسي (HEX)', border: OutlineInputBorder())),
            const SizedBox(height: AD.sm),
            TextField(controller: _greeting, decoration: const InputDecoration(labelText: 'رسالة الترحيب (استخدم {name})', border: OutlineInputBorder())),
            const SizedBox(height: AD.sm),
            TextField(controller: _supportPhone, textDirection: TextDirection.ltr,
              decoration: const InputDecoration(labelText: 'رقم الدعم/الواتساب', border: OutlineInputBorder())),
          ]))),
          const SizedBox(height: AD.md),
          Card(child: Padding(padding: const EdgeInsets.all(AD.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('إعلان الصفحة الرئيسية', style: AT.h3),
            const SizedBox(height: AD.sm),
            TextField(controller: _announcement, maxLines: 2,
              decoration: const InputDecoration(labelText: 'نص الإعلان (اتركه فارغاً للإخفاء)', border: OutlineInputBorder())),
          ]))),
          const SizedBox(height: AD.md),
          Card(child: Padding(padding: const EdgeInsets.all(AD.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('وضع الصيانة', style: AT.h3),
            const SizedBox(height: AD.sm),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('تفعيل وضع الصيانة'),
              subtitle: const Text('سيظهر للعملاء أن التطبيق غير متاح'),
              value: _maintMode, onChanged: (v) => setState(() => _maintMode = v), activeColor: AC.warning,
            ),
            const SizedBox(height: AD.sm),
            TextField(controller: _maintMsg, maxLines: 2,
              decoration: const InputDecoration(labelText: 'رسالة الصيانة', border: OutlineInputBorder())),
          ]))),
          const SizedBox(height: AD.lg),
          SizedBox(width: double.infinity, height: AD.btnH, child: ElevatedButton.icon(
            icon: const Icon(Icons.save_rounded), label: const Text('حفظ'), onPressed: _save,
          )),
        ]),
  );
}

// ════════════════════════════════════════════════════════
//  REQUEST CHAT THREAD (admin side)
// ════════════════════════════════════════════════════════
class RequestChatScreen extends StatefulWidget {
  final String requestId;
  const RequestChatScreen({super.key, required this.requestId});
  @override State<RequestChatScreen> createState() => _ChatState();
}
class _ChatState extends State<RequestChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  List<Map<String,dynamic>> _msgs = [];
  bool _loading = true; bool _sending = false;

  @override void initState() { super.initState(); _load(); }
  @override void dispose() { _input.dispose(); _scroll.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final msgs = await AdminMessagesRepo().list(widget.requestId);
      if (mounted) setState(() { _msgs = msgs; _loading = false; });
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    } catch (e) { if (mounted) { setState(() => _loading = false); _showErr(context, '$e'); } }
  }

  Future<void> _send() async {
    final body = _input.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      final m = await AdminMessagesRepo().send(widget.requestId, body);
      _input.clear();
      if (mounted) setState(() { _msgs = [..._msgs, m]; _sending = false; });
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scroll.hasClients) _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
      });
    } catch (e) { if (mounted) { setState(() => _sending = false); _showErr(context, '$e'); } }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: AC.bg,
    appBar: AppBar(title: Text('محادثة #${widget.requestId.substring(0, 8)}'), backgroundColor: AC.primary, actions: [
      IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
    ]),
    body: Column(children: [
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator(color: AC.primary))
        : _msgs.isEmpty ? const Center(child: Text('لا توجد رسائل بعد'))
        : ListView.builder(controller: _scroll, padding: const EdgeInsets.all(AD.md), itemCount: _msgs.length, itemBuilder: (_, i) {
            final m = _msgs[i];
            final isAdmin = m['adminId'] != null;
            final sender = isAdmin
              ? (m['admin']?['fullName']?.toString() ?? 'المسؤول')
              : (m['user']?['fullName']?.toString() ?? 'العميل');
            return Align(
              alignment: isAdmin ? Alignment.centerLeft : Alignment.centerRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                constraints: const BoxConstraints(maxWidth: 280),
                decoration: BoxDecoration(
                  color: isAdmin ? AC.primary : AC.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isAdmin ? AC.primary : AC.borderLight),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(sender, style: AT.cap.copyWith(color: isAdmin ? Colors.white70 : AC.textMuted, fontSize: 10)),
                  const SizedBox(height: 2),
                  Text(m['body']?.toString() ?? '', style: AT.body.copyWith(color: isAdmin ? Colors.white : AC.text)),
                ]),
              ),
            );
          })),
      SafeArea(top: false, child: Container(padding: const EdgeInsets.all(8), decoration: const BoxDecoration(color: AC.surface, border: Border(top: BorderSide(color: AC.borderLight))),
        child: Row(children: [
          Expanded(child: TextField(controller: _input, textDirection: TextDirection.rtl, maxLines: 3, minLines: 1,
            decoration: const InputDecoration(hintText: 'اكتب رسالة...', border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)))),
          const SizedBox(width: 8),
          IconButton(icon: Icon(_sending ? Icons.hourglass_top_rounded : Icons.send_rounded, color: AC.primary), onPressed: _sending ? null : _send),
        ]),
      )),
    ]),
  );
}
