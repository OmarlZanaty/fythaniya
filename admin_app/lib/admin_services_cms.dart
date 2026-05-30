/// Admin Services CMS — three-level drill-down:
/// Level 1: Category grid (mirrors user home screen)
/// Level 2: Providers inside a category
/// Level 3: Sub-services inside a provider (with fee slider + mode toggle)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'admin_core.dart';
import 'admin_api.dart';

// ══════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════
void _ok(BuildContext ctx, String m) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(m), backgroundColor: AC.success));
void _err(BuildContext ctx, String m) =>
    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(m), backgroundColor: AC.error));

Color _hexColor(String? h) {
  var s = (h ?? '#3B82F6').replaceFirst('#', '');
  if (s.length == 6) s = 'FF$s';
  return Color(int.tryParse(s, radix: 16) ?? 0xFF3B82F6);
}

const _iconMap = <String, IconData>{
  'apps': Icons.apps_rounded,
  'smartphone': Icons.smartphone_rounded,
  'phone': Icons.phone_rounded,
  'bolt': Icons.bolt_rounded,
  'gas': Icons.local_fire_department_rounded,
  'water': Icons.water_drop_rounded,
  'wifi': Icons.wifi_rounded,
  'bank': Icons.account_balance_rounded,
  'business': Icons.business_rounded,
  'wallet': Icons.account_balance_wallet_rounded,
  'shield': Icons.shield_rounded,
  'gift': Icons.card_giftcard_rounded,
  'school': Icons.school_rounded,
  'medical': Icons.medical_services_rounded,
  'globe': Icons.public_rounded,
  'gov': Icons.account_balance_rounded,
  'insurance': Icons.health_and_safety_rounded,
  'transfer': Icons.swap_horiz_rounded,
  'instapay': Icons.flash_on_rounded,
  'receipt': Icons.receipt_long_rounded,
};
IconData _icon(String? k) => _iconMap[k] ?? Icons.apps_rounded;

// ══════════════════════════════════════════════════════════
//  LEVEL 1 — Category Grid (looks like user home screen)
// ══════════════════════════════════════════════════════════
class AdminServicesCmsScreen extends StatefulWidget {
  const AdminServicesCmsScreen({super.key});
  @override State<AdminServicesCmsScreen> createState() => _CmsState();
}

class _CmsState extends State<AdminServicesCmsScreen> {
  List<Map<String, dynamic>> _cats = [];
  bool _loading = true;
  bool _editMode = false;

  @override void initState() { super.initState(); _load(); }

  // Default categories seeded on first run (mirrors the old enum values + icons/colors)
  static const _defaults = [
    {'key':'TELECOM',     'nameAr':'اتصالات',   'iconKey':'smartphone','colorHex':'#9333EA','sortOrder':0},
    {'key':'ELECTRICITY', 'nameAr':'كهرباء',    'iconKey':'bolt',      'colorHex':'#F59E0B','sortOrder':1},
    {'key':'GAS',         'nameAr':'غاز',       'iconKey':'gas',       'colorHex':'#EF4444','sortOrder':2},
    {'key':'WATER',       'nameAr':'مياه',      'iconKey':'water',     'colorHex':'#0EA5E9','sortOrder':3},
    {'key':'INTERNET',    'nameAr':'إنترنت',    'iconKey':'wifi',      'colorHex':'#10B981','sortOrder':4},
    {'key':'INSURANCE',   'nameAr':'تأمين',     'iconKey':'insurance', 'colorHex':'#6366F1','sortOrder':5},
    {'key':'GOVERNMENT',  'nameAr':'حكومي',     'iconKey':'gov',       'colorHex':'#64748B','sortOrder':6},
    {'key':'INSTAPAY',    'nameAr':'InstaPay',   'iconKey':'instapay',  'colorHex':'#3B82F6','sortOrder':7},
    {'key':'BANK',        'nameAr':'تحويل بنكي','iconKey':'bank',      'colorHex':'#7C3AED','sortOrder':8},
  ];

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      var cats = await AdminCategoriesRepo().list();
      // Auto-seed defaults on first run
      if (cats.isEmpty) {
        for (final d in _defaults) {
          try { await AdminCategoriesRepo().create(Map<String,dynamic>.from(d)); } catch (_) {}
        }
        cats = await AdminCategoriesRepo().list();
      }
      if (mounted) setState(() { _cats = cats; _loading = false; });
    } catch (e) { if (mounted) { setState(() => _loading = false); _err(context, '$e'); } }
  }

  Future<void> _addCategory() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => const _CatFormDialog());
    if (result == null) return;
    try { await AdminCategoriesRepo().create(result); _load(); _ok(context, '✅ تم إضافة التصنيف'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _editCategory(Map<String, dynamic> cat) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => _CatFormDialog(existing: cat));
    if (result == null) return;
    try { await AdminCategoriesRepo().update(cat['key'] as String, result); _load(); _ok(context, '✅ تم التعديل'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _deleteCategory(Map<String, dynamic> cat) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('حذف التصنيف'),
      content: Text('حذف "${cat['nameAr']}"؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('حذف', style: TextStyle(color: AC.error))),
      ],
    ));
    if (ok != true) return;
    try { await AdminCategoriesRepo().delete(cat['key'] as String); _load(); _ok(context, 'تم الحذف'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.bg,
    bottomNavigationBar: const AdminBottomNav(current: 'services'),
    appBar: AppBar(
      title: const Text('إدارة الخدمات'),
      backgroundColor: AC.primary,
      actions: [
        IconButton(
          icon: Icon(_editMode ? Icons.check_rounded : Icons.edit_rounded),
          tooltip: _editMode ? 'تم' : 'تعديل',
          onPressed: () => setState(() => _editMode = !_editMode),
        ),
        IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'تصنيف جديد', onPressed: _addCategory),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.primary))
      : _cats.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.apps_rounded, size: 72, color: AC.textMuted),
            const SizedBox(height: 16),
            const Text('لا توجد تصنيفات بعد', style: AT.body),
            const SizedBox(height: 12),
            ElevatedButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('إضافة تصنيف'), onPressed: _addCategory),
          ]))
        : RefreshIndicator(
            color: AC.primary, onRefresh: _load,
            child: Column(children: [
              if (_editMode)
                Container(color: AC.warningBg, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: AC.warning, size: 18),
                    const SizedBox(width: 8),
                    const Expanded(child: Text('وضع التعديل: اضغط مطولاً لإعادة الترتيب، اضغط لتعديل', style: AT.cap)),
                    TextButton(onPressed: () => setState(() => _editMode = false), child: const Text('إنهاء')),
                  ])),
              Expanded(child: _editMode
                ? ReorderableListView.builder(
                    padding: const EdgeInsets.all(AD.md),
                    itemCount: _cats.length,
                    onReorder: (old, nw) {
                      if (nw > old) nw -= 1;
                      setState(() { final it = _cats.removeAt(old); _cats.insert(nw, it); });
                      for (var i = 0; i < _cats.length; i++) {
                        AdminCategoriesRepo().update(_cats[i]['key'] as String, {'sortOrder': i}).catchError((_){});
                      }
                    },
                    itemBuilder: (_, i) {
                      final cat = _cats[i];
                      final color = _hexColor(cat['colorHex'] as String?);
                      return Card(key: ValueKey(cat['key']), margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CircleAvatar(backgroundColor: color.withOpacity(0.15),
                            child: Icon(_icon(cat['iconKey'] as String?), color: color)),
                          title: Text(cat['nameAr'] ?? '', style: AT.bodyM),
                          subtitle: Text('${cat['key']}  •  ${cat['colorHex']}', style: AT.cap, textDirection: TextDirection.ltr),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            IconButton(icon: const Icon(Icons.edit_rounded, size: 18, color: AC.primary), onPressed: () => _editCategory(cat)),
                            IconButton(icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AC.error), onPressed: () => _deleteCategory(cat)),
                            const Icon(Icons.drag_handle_rounded, color: AC.textMuted),
                          ]),
                        ));
                    })
                // Normal mode: grid like user home screen
                : GridView.builder(
                    padding: const EdgeInsets.all(AD.lg),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 16, childAspectRatio: 0.8),
                    itemCount: _cats.length,
                    itemBuilder: (_, i) {
                      final cat = _cats[i];
                      final color = _hexColor(cat['colorHex'] as String?);
                      final active = (cat['isActive'] as bool?) ?? true;
                      return GestureDetector(
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => CategoryProvidersScreen(category: cat))),
                        onLongPress: () => _editCategory(cat),
                        child: Opacity(opacity: active ? 1.0 : 0.4,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            Stack(children: [
                              Container(width: 58, height: 58,
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: color.withOpacity(0.25)),
                                  boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8, offset: const Offset(0,3))],
                                ),
                                child: Icon(_icon(cat['iconKey'] as String?), color: color, size: 28)),
                              // Edit badge in edit mode
                              Positioned(top: 0, left: 0, child: Container(width: 14, height: 14,
                                decoration: const BoxDecoration(color: AC.primary, shape: BoxShape.circle),
                                child: const Icon(Icons.edit_rounded, size: 9, color: Colors.white))),
                            ]),
                            const SizedBox(height: 6),
                            Text(cat['nameAr'] ?? '', style: AT.cap.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
                          ])),
                      );
                    },
                  )),
            ]),
          ),
  );
}

// ══════════════════════════════════════════════════════════
//  LEVEL 2 — Providers inside a category
// ══════════════════════════════════════════════════════════
class CategoryProvidersScreen extends StatefulWidget {
  final Map<String, dynamic> category;
  const CategoryProvidersScreen({super.key, required this.category});
  @override State<CategoryProvidersScreen> createState() => _ProvidersState();
}

class _ProvidersState extends State<CategoryProvidersScreen> {
  List<ServiceProvider> _providers = [];
  bool _loading = true;

  String get _catKey => widget.category['key'] as String;
  Color get _catColor => _hexColor(widget.category['colorHex'] as String?);

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await AdminServicesRepo().getProviders();
      if (mounted) setState(() {
        _providers = all.where((p) => p.category == _catKey).toList();
        _loading = false;
      });
    } catch (e) { if (mounted) { setState(() => _loading = false); _err(context, '$e'); } }
  }

  Future<void> _add() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => _ProviderFormDialog(categoryKey: _catKey));
    if (result == null) return;
    try { await AdminServicesRepo().createProvider(result); _load(); _ok(context, '✅ تم إضافة المزود'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _edit(ServiceProvider p) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => _ProviderFormDialog(existing: p, categoryKey: _catKey));
    if (result == null) return;
    try { await AdminServicesRepo().updateProvider(p.id, result); _load(); _ok(context, '✅ تم التعديل'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _delete(ServiceProvider p) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('حذف المزود'),
      content: Text('حذف "${p.displayName}" وكل خدماته؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('حذف', style: TextStyle(color: AC.error))),
      ],
    ));
    if (ok != true) return;
    try { await AdminServicesRepo().deleteProvider(p.id); _load(); _ok(context, 'تم الحذف'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _pickLogo(String id) async {
    final src = await showModalBottomSheet<ImageSource>(context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AC.primary), title: const Text('الكاميرا'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: AC.primary), title: const Text('المعرض'),  onTap: () => Navigator.pop(context, ImageSource.gallery)),
      ])));
    if (src == null) return;
    final file = await ImagePicker().pickImage(source: src, imageQuality: 80, maxWidth: 1200);
    if (file == null) return;
    try { await AdminServicesRepo().uploadProviderLogo(id, file.path); _load(); _ok(context, '✅ تم رفع الشعار'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.bg,
    appBar: AppBar(
      title: Text(widget.category['nameAr'] as String? ?? _catKey),
      backgroundColor: _catColor,
      actions: [
        IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'مزود جديد', onPressed: _add),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.primary))
      : RefreshIndicator(
          color: _catColor, onRefresh: _load,
          child: _providers.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.business_rounded, size: 64, color: _catColor.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text('لا يوجد مزودون في هذا التصنيف'),
                const SizedBox(height: 12),
                ElevatedButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('إضافة مزود'), onPressed: _add),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(AD.md),
                itemCount: _providers.length,
                itemBuilder: (_, i) {
                  final p = _providers[i];
                  return Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ProviderSubServicesScreen(provider: p, catColor: _catColor))),
                    leading: p.logoUrl != null && p.logoUrl!.isNotEmpty
                      ? ClipRRect(borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(imageUrl: p.logoUrl!, width: 44, height: 44, fit: BoxFit.cover,
                            errorWidget: (_,__,___) => CircleAvatar(backgroundColor: _catColor.withOpacity(0.15),
                              child: Icon(Icons.business_rounded, color: _catColor))))
                      : CircleAvatar(backgroundColor: _catColor.withOpacity(0.15),
                          child: Text(p.displayName.isNotEmpty ? p.displayName[0] : '?',
                            style: AT.bodyM.copyWith(color: _catColor))),
                    title: Text(p.displayName, style: AT.bodyM),
                    subtitle: Text('${p.subServices.length} خدمة فرعية • ${p.isActive ? "نشط" : "غير نشط"}', style: AT.cap),
                    trailing: PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AC.textSec),
                      onSelected: (v) {
                        if (v == 'edit')   _edit(p);
                        if (v == 'logo')   _pickLogo(p.id);
                        if (v == 'toggle') AdminServicesRepo().updateProvider(p.id, {'isActive': !p.isActive}).then((_) => _load());
                        if (v == 'delete') _delete(p);
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(value: 'edit',   child: ListTile(dense: true, leading: Icon(Icons.edit_rounded,           color: AC.primary), title: Text('تعديل'))),
                        const PopupMenuItem(value: 'logo',   child: ListTile(dense: true, leading: Icon(Icons.add_a_photo_rounded,     color: AC.primary), title: Text('شعار'))),
                        const PopupMenuItem(value: 'toggle', child: ListTile(dense: true, leading: Icon(Icons.visibility_rounded,      color: AC.info),    title: Text('تفعيل/إيقاف'))),
                        const PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline_rounded,  color: AC.error),   title: Text('حذف', style: TextStyle(color: AC.error)))),
                      ],
                    ),
                  ));
                }),
        ),
  );
}

// ══════════════════════════════════════════════════════════
//  LEVEL 3 — Sub-services inside a provider
// ══════════════════════════════════════════════════════════
class ProviderSubServicesScreen extends StatefulWidget {
  final ServiceProvider provider;
  final Color catColor;
  const ProviderSubServicesScreen({super.key, required this.provider, required this.catColor});
  @override State<ProviderSubServicesScreen> createState() => _SubsState();
}

class _SubsState extends State<ProviderSubServicesScreen> {
  List<SubService> _subs = [];
  bool _loading = true;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await AdminServicesRepo().getProviders();
      final p = all.firstWhere((x) => x.id == widget.provider.id, orElse: () => widget.provider);
      if (mounted) setState(() { _subs = p.subServices; _loading = false; });
    } catch (e) { if (mounted) { setState(() => _loading = false); _err(context, '$e'); } }
  }

  Future<void> _add() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => _SubFormDialog(category: widget.provider.category));
    if (result == null) return;
    try {
      await AdminServicesRepo().createSubService(widget.provider.id, result);
      _load(); _ok(context, '✅ تم إضافة الخدمة');
    } catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _edit(SubService sub) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => _SubFormDialog(existing: sub, category: sub.category));
    if (result == null) return;
    try { await AdminServicesRepo().updateSubService(sub.id, result); _load(); _ok(context, '✅ تم التعديل'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _delete(SubService sub) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('حذف الخدمة'),
      content: Text('حذف "${sub.nameAr}"؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('حذف', style: TextStyle(color: AC.error))),
      ],
    ));
    if (ok != true) return;
    try { await AdminServicesRepo().deleteSubService(sub.id); _load(); _ok(context, 'تم الحذف'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _pickImage(String subId) async {
    final src = await showModalBottomSheet<ImageSource>(context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AC.primary), title: const Text('الكاميرا'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: AC.primary), title: const Text('المعرض'),  onTap: () => Navigator.pop(context, ImageSource.gallery)),
      ])));
    if (src == null) return;
    final file = await ImagePicker().pickImage(source: src, imageQuality: 80, maxWidth: 1200);
    if (file == null) return;
    try { await AdminServicesRepo().uploadSubServiceImage(subId, file.path); _load(); _ok(context, '✅ تم رفع الصورة'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AC.bg,
    appBar: AppBar(
      title: Text(widget.provider.displayName),
      backgroundColor: widget.catColor,
      actions: [
        IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'خدمة جديدة', onPressed: _add),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.primary))
      : RefreshIndicator(
          color: widget.catColor, onRefresh: _load,
          child: _subs.isEmpty
            ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.miscellaneous_services_rounded, size: 64, color: widget.catColor.withOpacity(0.4)),
                const SizedBox(height: 16),
                const Text('لا توجد خدمات فرعية'),
                const SizedBox(height: 12),
                ElevatedButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('إضافة خدمة'), onPressed: _add),
              ]))
            : ListView.builder(
                padding: const EdgeInsets.all(AD.md),
                itemCount: _subs.length,
                itemBuilder: (_, i) {
                  final sub = _subs[i];
                  final isRequest = sub.serviceMode == 'REQUEST';
                  return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Header row
                      Row(children: [
                        if (sub.imageUrl != null && sub.imageUrl!.isNotEmpty)
                          ClipRRect(borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(imageUrl: sub.imageUrl!, width: 40, height: 40, fit: BoxFit.cover))
                        else
                          Container(width: 40, height: 40,
                            decoration: BoxDecoration(color: widget.catColor.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                            child: Icon(Icons.miscellaneous_services_rounded, color: widget.catColor, size: 22)),
                        const SizedBox(width: 10),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(sub.nameAr, style: AT.bodyM),
                          Text(sub.name, style: AT.cap.copyWith(color: AC.textMuted)),
                        ])),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert_rounded, color: AC.textSec),
                          onSelected: (v) {
                            if (v == 'edit')   _edit(sub);
                            if (v == 'image')  _pickImage(sub.id);
                            if (v == 'delete') _delete(sub);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'edit',   child: ListTile(dense: true, leading: Icon(Icons.edit_rounded,          color: AC.primary), title: Text('تعديل'))),
                            PopupMenuItem(value: 'image',  child: ListTile(dense: true, leading: Icon(Icons.add_a_photo_outlined,  color: AC.primary), title: Text('صورة'))),
                            PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline_rounded,color: AC.error),   title: Text('حذف', style: TextStyle(color: AC.error)))),
                          ],
                        ),
                      ]),
                      const SizedBox(height: 10),
                      const Divider(height: 1),
                      const SizedBox(height: 10),
                      // Fee row
                      Row(children: [
                        Expanded(child: _FeeChip('ثابتة', '${sub.fixedFee.toStringAsFixed(2)} ج.م', widget.catColor)),
                        const SizedBox(width: 8),
                        Expanded(child: _FeeChip('نسبة', '${(sub.percentageFee * 100).toStringAsFixed(2)}%', widget.catColor)),
                      ]),
                      const SizedBox(height: 10),
                      // Mode badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: isRequest ? AC.warningBg : AC.successBg,
                          borderRadius: BorderRadius.circular(20)),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isRequest ? Icons.inbox_rounded : Icons.payments_rounded,
                            size: 14, color: isRequest ? AC.warning : AC.success),
                          const SizedBox(width: 5),
                          Text(isRequest ? 'يرسل طلب → الإدارة تحدد المبلغ' : 'يطلب مبلغ من المستخدم',
                            style: AT.cap.copyWith(color: isRequest ? AC.warning : AC.success, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ]),
                  ));
                }),
        ),
  );
}

// ══════════════════════════════════════════════════════════
//  DIALOGS
// ══════════════════════════════════════════════════════════
class _CatFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _CatFormDialog({this.existing});
  @override State<_CatFormDialog> createState() => _CatFormDialogState();
}
class _CatFormDialogState extends State<_CatFormDialog> {
  final _key    = TextEditingController();
  final _nameAr = TextEditingController();
  final _color  = TextEditingController(text: '#3B82F6');
  String _iconKey = 'apps';
  static const _icons = ['apps','smartphone','phone','bolt','gas','water','wifi','bank','business','wallet','shield','gift','school','medical','globe','gov','insurance','transfer','instapay','receipt'];
  @override void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) { _key.text = e['key']?.toString() ?? ''; _nameAr.text = e['nameAr']?.toString() ?? ''; _color.text = e['colorHex']?.toString() ?? '#3B82F6'; _iconKey = e['iconKey']?.toString() ?? 'apps'; }
  }
  @override void dispose() { _key.dispose(); _nameAr.dispose(); _color.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: Text(widget.existing == null ? 'تصنيف جديد' : 'تعديل التصنيف'),
    content: SizedBox(width: 340, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      if (widget.existing == null) ...[
        TextField(controller: _key, textDirection: TextDirection.ltr,
          decoration: const InputDecoration(labelText: 'المفتاح بالأحرف الكبيرة (TELECOM)', border: OutlineInputBorder())),
        const SizedBox(height: 10),
      ],
      TextField(controller: _nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _iconKey,
        decoration: const InputDecoration(labelText: 'الأيقونة', border: OutlineInputBorder()),
        items: _icons.map((k) => DropdownMenuItem(value: k, child: Row(children: [
          Icon(_icon(k), size: 18, color: AC.primary), const SizedBox(width: 8), Text(k),
        ]))).toList(),
        onChanged: (v) => setState(() => _iconKey = v ?? _iconKey),
      ),
      const SizedBox(height: 10),
      TextField(controller: _color, textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'اللون HEX (مثال: #3B82F6)', border: OutlineInputBorder())),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        final k = widget.existing != null ? widget.existing!['key'] as String : _key.text.trim().toUpperCase();
        if (k.isEmpty || _nameAr.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('المفتاح والاسم مطلوبان'), backgroundColor: AC.error)); return; }
        if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(_color.text.trim())) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('صيغة اللون غير صحيحة'), backgroundColor: AC.error)); return; }
        Navigator.pop(ctx, <String,dynamic>{'key': k, 'nameAr': _nameAr.text.trim(), 'iconKey': _iconKey, 'colorHex': _color.text.trim()});
      }, child: const Text('حفظ')),
    ],
  );
}

class _ProviderFormDialog extends StatefulWidget {
  final ServiceProvider? existing;
  final String categoryKey;
  const _ProviderFormDialog({this.existing, required this.categoryKey});
  @override State<_ProviderFormDialog> createState() => _ProviderFormDialogState();
}
class _ProviderFormDialogState extends State<_ProviderFormDialog> {
  final _display = TextEditingController();
  final _name    = TextEditingController();
  @override void initState() {
    super.initState();
    _display.text = widget.existing?.displayName ?? '';
    _name.text    = widget.existing?.name ?? '';
  }
  @override void dispose() { _display.dispose(); _name.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: Text(widget.existing == null ? 'مزود جديد' : 'تعديل المزود'),
    content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _display, decoration: const InputDecoration(labelText: 'الاسم المعروض *', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: _name, decoration: const InputDecoration(labelText: 'الاسم الداخلي (بالإنجليزية)', border: OutlineInputBorder())),
      const SizedBox(height: 8),
      Text('التصنيف: ${widget.categoryKey}', style: AT.cap.copyWith(color: AC.textMuted)),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        if (_display.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الاسم المعروض مطلوب'), backgroundColor: AC.error)); return; }
        Navigator.pop(ctx, <String,dynamic>{
          'displayName': _display.text.trim(),
          'name': _name.text.trim().isEmpty ? _display.text.trim() : _name.text.trim(),
          'category': widget.categoryKey,
          'isActive': true,
        });
      }, child: const Text('حفظ')),
    ],
  );
}

class _SubFormDialog extends StatefulWidget {
  final SubService? existing;
  final String category;
  const _SubFormDialog({this.existing, required this.category});
  @override State<_SubFormDialog> createState() => _SubFormDialogState();
}
class _SubFormDialogState extends State<_SubFormDialog> {
  final _nameAr = TextEditingController();
  final _name   = TextEditingController();
  final _fixed  = TextEditingController(text: '0');
  double _pct = 0;        // 0..30 → 0%..30%
  String _mode = 'AMOUNT'; // AMOUNT | REQUEST

  @override void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _nameAr.text = e.nameAr;
      _name.text   = e.name;
      _fixed.text  = e.fixedFee.toStringAsFixed(2);
      _pct         = (e.percentageFee * 100).clamp(0, 30).toDouble();
      _mode        = e.serviceMode;
    }
  }
  @override void dispose() { _nameAr.dispose(); _name.dispose(); _fixed.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: Text(widget.existing == null ? 'خدمة فرعية جديدة' : 'تعديل الخدمة'),
    content: SizedBox(width: 360, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      TextField(controller: _nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية *', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      TextField(controller: _name,   decoration: const InputDecoration(labelText: 'الاسم بالإنجليزية', border: OutlineInputBorder())),
      const SizedBox(height: 14),
      // Fixed fee
      TextField(controller: _fixed, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
        decoration: const InputDecoration(labelText: 'رسوم ثابتة (ج.م)', border: OutlineInputBorder(), suffixText: 'ج.م')),
      const SizedBox(height: 14),
      // Percentage slider
      Row(children: [
        const Icon(Icons.percent_rounded, size: 18, color: AC.primary),
        const SizedBox(width: 6),
        Text('نسبة العمولة: ', style: AT.cap),
        Text('${_pct.toStringAsFixed(2)}%', style: AT.bodyM.copyWith(color: AC.primary, fontWeight: FontWeight.w700)),
      ]),
      Slider(value: _pct, min: 0, max: 30, divisions: 300, activeColor: AC.primary,
        label: '${_pct.toStringAsFixed(2)}%',
        onChanged: (v) => setState(() => _pct = v)),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: const [
        Text('0%', style: AT.cap), Text('5%', style: AT.cap), Text('10%', style: AT.cap), Text('30%', style: AT.cap),
      ]),
      const SizedBox(height: 14),
      const Divider(),
      // Service mode
      Text('نوع الخدمة', style: AT.bodyM),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(child: _ModeCard(
          selected: _mode == 'AMOUNT',
          icon: Icons.payments_rounded,
          title: 'يطلب مبلغ',
          subtitle: 'المستخدم يدخل المبلغ ويُخصم فوراً',
          color: AC.success,
          onTap: () => setState(() => _mode = 'AMOUNT'),
        )),
        const SizedBox(width: 8),
        Expanded(child: _ModeCard(
          selected: _mode == 'REQUEST',
          icon: Icons.inbox_rounded,
          title: 'يرسل طلب',
          subtitle: 'الإدارة تحدد المبلغ بعد الاستلام',
          color: AC.warning,
          onTap: () => setState(() => _mode = 'REQUEST'),
        )),
      ]),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      ElevatedButton(onPressed: () {
        if (_nameAr.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الاسم بالعربية مطلوب'), backgroundColor: AC.error)); return; }
        Navigator.pop(ctx, <String,dynamic>{
          'nameAr': _nameAr.text.trim(),
          'name':   _name.text.trim().isEmpty ? _nameAr.text.trim() : _name.text.trim(),
          'category': widget.category,
          'fixedFee':      double.tryParse(_fixed.text.trim()) ?? 0,
          'percentageFee': _pct / 100,
          'serviceMode':   _mode,
        });
      }, child: const Text('حفظ')),
    ],
  );
}

// Mode selector card
class _ModeCard extends StatelessWidget {
  final bool selected; final IconData icon; final String title, subtitle; final Color color; final VoidCallback onTap;
  const _ModeCard({required this.selected, required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});
  @override Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: selected ? color.withOpacity(0.1) : AC.surface,
        borderRadius: BorderRadius.circular(AD.r12),
        border: Border.all(color: selected ? color : AC.borderLight, width: selected ? 2 : 1),
      ),
      child: Column(children: [
        Icon(icon, color: selected ? color : AC.textMuted, size: 24),
        const SizedBox(height: 4),
        Text(title, style: AT.cap.copyWith(color: selected ? color : AC.text, fontWeight: selected ? FontWeight.w700 : FontWeight.w400), textAlign: TextAlign.center),
        const SizedBox(height: 2),
        Text(subtitle, style: AT.cap.copyWith(color: AC.textMuted, fontSize: 9), textAlign: TextAlign.center),
      ]),
    ),
  );
}

// Fee chip
class _FeeChip extends StatelessWidget {
  final String label, value; final Color color;
  const _FeeChip(this.label, this.value, this.color);
  @override Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(10), border: Border.all(color: color.withOpacity(0.2))),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text('$label: ', style: AT.cap.copyWith(color: AC.textMuted)),
      Text(value, style: AT.cap.copyWith(color: color, fontWeight: FontWeight.w700)),
    ]),
  );
}
