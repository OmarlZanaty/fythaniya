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
    final saved = await showDialog<Map<String,String>>(
      context: context,
      builder: (_) => _PaymentNumberFormDialog(existing: existing),
    );
    if (saved == null) return;
    try {
      if (existing == null) {
        await AdminPaymentNumbersRepo().create(saved);
      } else {
        await AdminPaymentNumbersRepo().update(existing['id'] as String, saved);
      }
      await _load();
      if (mounted) _showOk(context, 'تم الحفظ');
    } catch (e) { if (mounted) _showErr(context, '$e'); }
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
    final result = await showDialog<Map<String,dynamic>>(
      context: context,
      builder: (_) => _AddBalanceDialog(userName: u['fullName']?.toString() ?? '—'),
    );
    if (result == null) return;
    final amt = result['amount'] as double;
    final note = result['note'] as String?;
    try {
      await AdminClientsRepo().addBalance(u['id'] as String, amt, note: note);
      await _search(_q.text.trim());
      if (mounted) _showOk(context, 'تم إضافة $amt ج.م');
    } catch (e) { if (mounted) _showErr(context, '$e'); }
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
//  HOME TILES (admin CMS for the user app's icon grid)
// ════════════════════════════════════════════════════════
const _kHomeTileIcons = <String, IconData>{
  'smartphone':    Icons.smartphone_rounded,
  'phone':         Icons.phone_rounded,
  'bolt':          Icons.bolt_rounded,
  'gas':           Icons.local_fire_department_rounded,
  'water':         Icons.water_drop_rounded,
  'wifi':          Icons.wifi_rounded,
  'instapay':      Icons.bolt_rounded,
  'bank':          Icons.account_balance_rounded,
  'business':      Icons.business_rounded,
  'wallet':        Icons.account_balance_wallet_rounded,
  'rewards':       Icons.stars_rounded,
  'notifications': Icons.notifications_rounded,
  'pay_later':     Icons.payments_rounded,
  'shield':        Icons.shield_rounded,
  'gift':          Icons.card_giftcard_rounded,
  'cart':          Icons.shopping_cart_rounded,
  'school':        Icons.school_rounded,
  'medical':       Icons.medical_services_rounded,
  'sports':        Icons.sports_esports_rounded,
  'travel':        Icons.flight_rounded,
  'globe':         Icons.public_rounded,
  'gov':           Icons.account_balance_rounded,
  'apps':          Icons.apps_rounded,
};
const _kHomeTileRoutes = <String, String>{
  'recharge':       'شحن رصيد',
  'bill_telecom':   'فاتورة تليفون',
  'bill_elec':      'كهرباء',
  'bill_gas':       'غاز',
  'bill_water':     'مياه',
  'bill_internet':  'إنترنت',
  'instapay':       'InstaPay',
  'bank_transfer':  'تحويل بنكي',
  'b2b':            'حساب شركات',
  'vodafone_cash':  'فودافون كاش (Pay-Later)',
  'pay_later':      'الدفع الآجل',
  'wallet':         'محفظتي',
  'rewards':        'مكافآت',
  'notifs':         'الإشعارات',
};
Color _hexToColor(String h) {
  var s = h.replaceFirst('#', '').trim();
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFF3B82F6);
}

class HomeTilesScreen extends StatefulWidget {
  const HomeTilesScreen({super.key});
  @override State<HomeTilesScreen> createState() => _HomeTilesState();
}
class _HomeTilesState extends State<HomeTilesScreen> {
  List<Map<String,dynamic>> _items = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final items = await AdminHomeTilesRepo().list();
      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) { if (mounted) { setState(() => _loading = false); _showErr(context, '$e'); } }
  }

  Future<void> _toggle(Map<String,dynamic> it) async {
    try {
      await AdminHomeTilesRepo().update(it['id'] as String, {'isActive': !(it['isActive'] as bool? ?? true)});
      await _load();
    } catch (e) { if (mounted) _showErr(context, '$e'); }
  }

  Future<void> _delete(Map<String,dynamic> it) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('حذف الأيقونة'),
      content: Text('سيتم حذف "${it['label']}" نهائياً. متأكد؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('حذف', style: TextStyle(color: AC.error))),
      ],
    ));
    if (ok != true) return;
    try { await AdminHomeTilesRepo().delete(it['id'] as String); await _load(); }
    catch (e) { if (mounted) _showErr(context, '$e'); }
  }

  Future<void> _showForm({Map<String,dynamic>? existing}) async {
    final saved = await showDialog<Map<String,dynamic>>(
      context: context,
      builder: (_) => _HomeTileFormDialog(existing: existing, nextOrder: _items.length),
    );
    if (saved == null) return;
    try {
      if (existing == null) {
        await AdminHomeTilesRepo().create(saved);
      } else {
        await AdminHomeTilesRepo().update(existing['id'] as String, saved);
      }
      await _load();
      if (mounted) _showOk(context, 'تم الحفظ');
    } catch (e) { if (mounted) _showErr(context, '$e'); }
  }

  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: AC.bg,
    appBar: AppBar(title: const Text('أيقونات الرئيسية'), backgroundColor: AC.primary, actions: [
      IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'إضافة', onPressed: () => _showForm()),
    ]),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.primary))
      : RefreshIndicator(color: AC.primary, onRefresh: _load, child: _items.isEmpty
          ? ListView(children: const [SizedBox(height: 120), Center(child: Padding(padding: EdgeInsets.all(24), child: Text('لا توجد أيقونات. اضغط + لإضافة أول أيقونة.\nإذا تركتها فارغة سيظهر للعملاء قائمة افتراضية.', textAlign: TextAlign.center)))])
          : ReorderableListView.builder(
              padding: const EdgeInsets.all(AD.md),
              itemCount: _items.length,
              onReorder: (oldI, newI) async {
                if (newI > oldI) newI -= 1;
                setState(() {
                  final it = _items.removeAt(oldI);
                  _items.insert(newI, it);
                });
                try {
                  final payload = <Map<String,dynamic>>[];
                  for (var i = 0; i < _items.length; i++) {
                    payload.add({'id': _items[i]['id'], 'order': i});
                  }
                  await AdminHomeTilesRepo().reorder(payload);
                } catch (e) { if (mounted) _showErr(context, '$e'); }
              },
              itemBuilder: (_, i) {
                final it = _items[i];
                final iconKey  = (it['iconKey']  as String?) ?? 'apps';
                final colorHex = (it['colorHex'] as String?) ?? '#3B82F6';
                final color    = _hexToColor(colorHex);
                final active   = (it['isActive'] as bool?) ?? true;
                return Card(key: ValueKey(it['id']), margin: const EdgeInsets.only(bottom: 10),
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: color.withOpacity(0.12),
                      child: Icon(_kHomeTileIcons[iconKey] ?? Icons.apps_rounded, color: color)),
                    title: Text(it['label']?.toString() ?? '—', style: AT.bodyM),
                    subtitle: Text('${_kHomeTileRoutes[it['route']] ?? it['route']} • ترتيب ${it['order'] ?? 0}', style: AT.cap),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch.adaptive(value: active, onChanged: (_) => _toggle(it), activeColor: AC.success),
                      IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: AC.primary), onPressed: () => _showForm(existing: it)),
                      IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AC.error), onPressed: () => _delete(it)),
                    ]),
                  ),
                );
              },
            )),
  );
}

class _HomeTileFormDialog extends StatefulWidget {
  final Map<String,dynamic>? existing;
  final int nextOrder;
  const _HomeTileFormDialog({this.existing, required this.nextOrder});
  @override State<_HomeTileFormDialog> createState() => _HomeTileFormDialogState();
}
class _HomeTileFormDialogState extends State<_HomeTileFormDialog> {
  late final TextEditingController _label;
  late final TextEditingController _color;
  late final TextEditingController _category;
  late final TextEditingController _badge;
  late String _route;
  late String _iconKey;
  late int    _order;
  bool _requiresPayLater = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _label    = TextEditingController(text: e?['label']?.toString() ?? '');
    _color    = TextEditingController(text: e?['colorHex']?.toString() ?? '#3B82F6');
    _category = TextEditingController(text: e?['category']?.toString() ?? '');
    _badge    = TextEditingController(text: e?['badge']?.toString() ?? '');
    _route    = (e?['route'] as String?) ?? 'recharge';
    _iconKey  = (e?['iconKey'] as String?) ?? 'apps';
    _order    = (e?['order'] as int?) ?? widget.nextOrder;
    _requiresPayLater = (e?['requiresPayLater'] as bool?) ?? false;
  }
  @override void dispose() { _label.dispose(); _color.dispose(); _category.dispose(); _badge.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: Text(widget.existing == null ? 'إضافة أيقونة' : 'تعديل أيقونة'),
    content: SizedBox(width: 360, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(controller: _label, decoration: const InputDecoration(labelText: 'الاسم الظاهر', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _route,
        decoration: const InputDecoration(labelText: 'الإجراء', border: OutlineInputBorder()),
        items: _kHomeTileRoutes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() => _route = v ?? 'recharge'),
      ),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _iconKey,
        decoration: const InputDecoration(labelText: 'الأيقونة', border: OutlineInputBorder()),
        items: _kHomeTileIcons.entries.map((e) => DropdownMenuItem(value: e.key,
          child: Row(children: [Icon(e.value, size: 18, color: AC.primary), const SizedBox(width: 8), Text(e.key)]))).toList(),
        onChanged: (v) => setState(() => _iconKey = v ?? 'apps'),
      ),
      const SizedBox(height: 12),
      TextField(controller: _color, textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'اللون (HEX) — مثال #3B82F6', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _category, textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'التصنيف (اختياري) — مثل ELECTRICITY', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _badge,
        decoration: const InputDecoration(labelText: 'شارة (اختياري) — مثل "جديد"', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      Row(children: [
        Expanded(child: Text('الترتيب: $_order', style: AT.cap)),
        IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: () => setState(() => _order = (_order - 1).clamp(0, 9999))),
        IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _order = (_order + 1).clamp(0, 9999))),
      ]),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('يتطلب الدفع الآجل'),
        subtitle: const Text('سيظهر للعميل معطّلاً حتى يتم تفعيل الدفع الآجل'),
        value: _requiresPayLater,
        onChanged: (v) => setState(() => _requiresPayLater = v),
      ),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        if (_label.text.trim().isEmpty) { _showErr(ctx, 'الاسم مطلوب'); return; }
        final color = _color.text.trim();
        if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(color)) { _showErr(ctx, 'صيغة اللون غير صحيحة'); return; }
        Navigator.pop(ctx, <String,dynamic>{
          'label': _label.text.trim(),
          'route': _route,
          'iconKey': _iconKey,
          'colorHex': color,
          'category': _category.text.trim().isEmpty ? null : _category.text.trim().toUpperCase(),
          'badge': _badge.text.trim().isEmpty ? null : _badge.text.trim(),
          'order': _order,
          'requiresPayLater': _requiresPayLater,
        });
      }, child: const Text('حفظ')),
    ],
  );
}

// ════════════════════════════════════════════════════════
//  STATEFUL DIALOG WIDGETS (own their controllers → safe dispose)
// ════════════════════════════════════════════════════════
class _AddBalanceDialog extends StatefulWidget {
  final String userName;
  const _AddBalanceDialog({required this.userName});
  @override State<_AddBalanceDialog> createState() => _AddBalanceDialogState();
}
class _AddBalanceDialogState extends State<_AddBalanceDialog> {
  final _amount = TextEditingController();
  final _note   = TextEditingController();
  @override void dispose() { _amount.dispose(); _note.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: Text('إضافة رصيد — ${widget.userName}'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'المبلغ (ج.م)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _note, maxLines: 2,
        decoration: const InputDecoration(labelText: 'ملاحظة (اختياري)', border: OutlineInputBorder())),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        final amt = double.tryParse(_amount.text.trim());
        if (amt == null || amt <= 0) { _showErr(ctx, 'أدخل مبلغاً صحيحاً'); return; }
        final n = _note.text.trim();
        Navigator.pop(ctx, {'amount': amt, 'note': n.isEmpty ? null : n});
      }, child: const Text('إضافة')),
    ],
  );
}

class _PaymentNumberFormDialog extends StatefulWidget {
  final Map<String,dynamic>? existing;
  const _PaymentNumberFormDialog({this.existing});
  @override State<_PaymentNumberFormDialog> createState() => _PaymentNumberFormDialogState();
}
class _PaymentNumberFormDialogState extends State<_PaymentNumberFormDialog> {
  late final TextEditingController _number;
  late final TextEditingController _label;
  late String _type;
  @override
  void initState() {
    super.initState();
    _number = TextEditingController(text: widget.existing?['number']?.toString() ?? '');
    _label  = TextEditingController(text: widget.existing?['label']?.toString() ?? '');
    _type   = (widget.existing?['type'] as String?) ?? 'WALLET';
  }
  @override void dispose() { _number.dispose(); _label.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: Text(widget.existing == null ? 'إضافة رقم دفع' : 'تعديل رقم دفع'),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      DropdownButtonFormField<String>(
        value: _type,
        decoration: const InputDecoration(labelText: 'النوع', border: OutlineInputBorder()),
        items: const [
          DropdownMenuItem(value: 'WALLET',   child: Text('محفظة (Vodafone/Orange Cash)')),
          DropdownMenuItem(value: 'INSTAPAY', child: Text('InstaPay')),
          DropdownMenuItem(value: 'BANK',     child: Text('حساب بنكي')),
        ],
        onChanged: (v) => setState(() => _type = v ?? 'WALLET'),
      ),
      const SizedBox(height: 12),
      TextField(controller: _label,  decoration: const InputDecoration(labelText: 'الاسم/الوصف', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _number, keyboardType: TextInputType.phone, textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'الرقم/الحساب', border: OutlineInputBorder())),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        if (_label.text.trim().isEmpty || _number.text.trim().isEmpty) { _showErr(ctx, 'الاسم والرقم مطلوبان'); return; }
        Navigator.pop(ctx, <String,String>{'type': _type, 'label': _label.text.trim(), 'number': _number.text.trim()});
      }, child: const Text('حفظ')),
    ],
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
