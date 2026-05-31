/// Admin Services CMS — mirrors user home screen exactly:
/// Level 1: Same grid as user home (home tiles from /admin/home-tiles)
///          Tap tile → Level 2. Long-press → edit tile appearance.
/// Level 2: Providers inside that service category
/// Level 3: Sub-services of a provider (fee slider + AMOUNT/REQUEST toggle)
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

// Renders a tile's custom image if it has one, else its icon — used in grid + list.
Widget _tileVisual(Map<String, dynamic> tile, Color color, double size) {
  final img = tile['imageUrl'] as String?;
  if (img != null && img.isNotEmpty) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.28),
      child: CachedNetworkImage(
        imageUrl: img, width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: size, height: size, color: color.withOpacity(0.1)),
        errorWidget: (_, __, ___) => Container(width: size, height: size, color: color.withOpacity(0.12),
          child: Icon(_icon(tile['iconKey'] as String?), color: color, size: size * 0.5)),
      ),
    );
  }
  return Container(width: size, height: size,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(size * 0.28),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Icon(_icon(tile['iconKey'] as String?), color: color, size: size * 0.48));
}

// ══════════════════════════════════════════════════════════
//  LEVEL 1 — Category Grid (looks like user home screen)
// ══════════════════════════════════════════════════════════
class AdminServicesCmsScreen extends StatefulWidget {
  const AdminServicesCmsScreen({super.key});
  @override State<AdminServicesCmsScreen> createState() => _CmsState();
}

class _CmsState extends State<AdminServicesCmsScreen> {
  // Level 1 now shows the SAME home tiles as the user home screen (from /admin/home-tiles).
  List<Map<String, dynamic>> _tiles = [];
  List<ServiceProvider> _providers = []; // for the tile→provider picker + drill-down
  bool _loading = true;
  bool _editMode = false;

  @override void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tiles = await AdminHomeTilesRepo().list();
      final providers = await AdminServicesRepo().getProviders();
      if (mounted) setState(() { _tiles = tiles; _providers = providers; _loading = false; });
    } catch (e) { if (mounted) { setState(() => _loading = false); _err(context, '$e'); } }
  }

  Future<void> _addTile() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => _TileFormDialog(nextOrder: _tiles.length, providers: _providers));
    if (result == null) return;
    try { await AdminHomeTilesRepo().create(result); _load(); _ok(context, '✅ تم إضافة الأيقونة'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _editTile(Map<String, dynamic> tile) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context, builder: (_) => _TileFormDialog(existing: tile, nextOrder: _tiles.length, providers: _providers));
    if (result == null) return;
    try { await AdminHomeTilesRepo().update(tile['id'] as String, result); _load(); _ok(context, '✅ تم التعديل'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _deleteTile(Map<String, dynamic> tile) async {
    final ok = await showDialog<bool>(context: context, builder: (_) => AlertDialog(
      title: const Text('حذف الأيقونة'),
      content: Text('حذف "${tile['label']}"؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(context, true),  child: const Text('حذف', style: TextStyle(color: AC.error))),
      ],
    ));
    if (ok != true) return;
    try { await AdminHomeTilesRepo().delete(tile['id'] as String); _load(); _ok(context, 'تم الحذف'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  // Upload a custom image for a tile (overrides its icon).
  Future<void> _pickTileImage(Map<String, dynamic> tile) async {
    final src = await showModalBottomSheet<ImageSource>(context: context,
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AC.primary), title: const Text('الكاميرا'), onTap: () => Navigator.pop(context, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: AC.primary), title: const Text('المعرض'),  onTap: () => Navigator.pop(context, ImageSource.gallery)),
        if (tile['imageUrl'] != null)
          ListTile(leading: const Icon(Icons.delete_outline_rounded, color: AC.error), title: const Text('إزالة الصورة'), onTap: () => Navigator.pop(context, null)),
      ])));
    // Distinguish "remove" from "cancel": remove returns null after the sheet had a delete tile.
    // We re-check below by passing through a sentinel; simplest: handle remove separately.
    if (src == null) return;
    final file = await ImagePicker().pickImage(source: src, imageQuality: 85, maxWidth: 600);
    if (file == null) return;
    try { await AdminHomeTilesRepo().uploadImage(tile['id'] as String, file.path); _load(); _ok(context, '✅ تم رفع الصورة'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  Future<void> _removeTileImage(Map<String, dynamic> tile) async {
    try { await AdminHomeTilesRepo().update(tile['id'] as String, {'imageUrl': ''}); _load(); _ok(context, 'تم إزالة الصورة'); }
    catch (e) { if (mounted) _err(context, '$e'); }
  }

  // Maps a tile route → the provider category the USER APP loads for that route,
  // so the admin drill-down shows EXACTLY the same providers the user sees.
  static const _routeCategory = {
    'recharge': 'TELECOM', 'bill_telecom': 'TELECOM', 'vodafone_cash': 'TELECOM',
    'bill_elec': 'ELECTRICITY', 'bill_gas': 'GAS', 'bill_water': 'WATER',
    'bill_internet': 'INTERNET', 'instapay': 'INSTAPAY', 'bank_transfer': 'BANK',
  };

  // Tap a tile → manage the providers/sub-services the user sees inside it.
  void _openTile(Map<String, dynamic> tile) {
    // If the tile is linked to a specific provider, open that provider's products directly.
    final pid = tile['providerId'] as String?;
    if (pid != null && pid.isNotEmpty) {
      final prov = _providers.where((p) => p.id == pid).firstOrNull;
      if (prov != null) {
        Navigator.push(context, MaterialPageRoute(builder: (_) =>
          ProviderSubServicesScreen(provider: prov, catColor: _hexColor(tile['colorHex'] as String?))));
        return;
      }
    }
    final route = tile['route'] as String?;
    // For known routes, use the SAME category the user app loads (route-based).
    // This ignores any free-text category accidentally stored on the tile.
    var cat = _routeCategory[route];
    // Only fall back to the tile's explicit category if route isn't a known one
    // AND the stored category looks like a real key (UPPERCASE / ascii).
    if (cat == null) {
      final raw = (tile['category'] as String?)?.trim();
      if (raw != null && raw.isNotEmpty && RegExp(r'^[A-Z0-9_]+$').hasMatch(raw)) cat = raw;
    }
    if (cat == null || cat.isEmpty) {
      // No provider category (wallet/rewards/notifs…) — only appearance editable.
      _editTile(tile);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryProvidersScreen(
      category: {'key': cat, 'nameAr': tile['label'], 'colorHex': tile['colorHex'], 'iconKey': tile['iconKey']},
    )));
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
        IconButton(icon: const Icon(Icons.add_rounded), tooltip: 'أيقونة جديدة', onPressed: _addTile),
        IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
      ],
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.primary))
      : _tiles.isEmpty
        ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.apps_rounded, size: 72, color: AC.textMuted),
            const SizedBox(height: 16),
            const Text('لا توجد أيقونات بعد', style: AT.body),
            const SizedBox(height: 12),
            ElevatedButton.icon(icon: const Icon(Icons.add_rounded), label: const Text('إضافة أيقونة'), onPressed: _addTile),
          ]))
        : RefreshIndicator(
            color: AC.primary, onRefresh: _load,
            child: Column(children: [
              Container(color: _editMode ? AC.warningBg : AC.infoBg, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: _editMode ? AC.warning : AC.info, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    _editMode ? 'وضع التعديل: اسحب لإعادة الترتيب، عدّل أو احذف' : 'اضغط على أيقونة لإدارة مزوديها وخدماتها',
                    style: AT.cap)),
                ])),
              Expanded(child: _editMode
                ? ReorderableListView.builder(
                    padding: const EdgeInsets.all(AD.md),
                    itemCount: _tiles.length,
                    onReorder: (old, nw) async {
                      if (nw > old) nw -= 1;
                      setState(() { final it = _tiles.removeAt(old); _tiles.insert(nw, it); });
                      final payload = <Map<String,dynamic>>[];
                      for (var i = 0; i < _tiles.length; i++) {
                        payload.add({'id': _tiles[i]['id'], 'order': i});
                      }
                      try { await AdminHomeTilesRepo().reorder(payload); } catch (_) {}
                    },
                    itemBuilder: (_, i) {
                      final t = _tiles[i];
                      final color = _hexColor(t['colorHex'] as String?);
                      final active = (t['isActive'] as bool?) ?? true;
                      return Card(key: ValueKey(t['id']), margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: _tileVisual(t, color, 44),
                          title: Text(t['label'] ?? '', style: AT.bodyM),
                          subtitle: Text('${t['category'] ?? t['route'] ?? ''}', style: AT.cap, textDirection: TextDirection.ltr),
                          trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                            PopupMenuButton<String>(
                              icon: const Icon(Icons.more_vert_rounded, color: AC.textSec),
                              onSelected: (v) {
                                if (v == 'image')   _pickTileImage(t);
                                if (v == 'remove')  _removeTileImage(t);
                                if (v == 'edit')    _editTile(t);
                                if (v == 'delete')  _deleteTile(t);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(value: 'image',  child: ListTile(dense: true, leading: Icon(Icons.image_rounded, color: AC.accent), title: Text('رفع صورة'))),
                                if (t['imageUrl'] != null)
                                  const PopupMenuItem(value: 'remove', child: ListTile(dense: true, leading: Icon(Icons.hide_image_rounded, color: AC.textMuted), title: Text('إزالة الصورة'))),
                                const PopupMenuItem(value: 'edit',   child: ListTile(dense: true, leading: Icon(Icons.edit_rounded, color: AC.primary), title: Text('تعديل'))),
                                const PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline_rounded, color: AC.error), title: Text('حذف', style: TextStyle(color: AC.error)))),
                              ],
                            ),
                            const Icon(Icons.drag_handle_rounded, color: AC.textMuted),
                          ]),
                        ));
                    })
                // Normal mode: grid identical to user home screen
                : GridView.builder(
                    padding: const EdgeInsets.all(AD.lg),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4, crossAxisSpacing: 12, mainAxisSpacing: 16, childAspectRatio: 0.8),
                    itemCount: _tiles.length,
                    itemBuilder: (_, i) {
                      final t = _tiles[i];
                      final color = _hexColor(t['colorHex'] as String?);
                      final active = (t['isActive'] as bool?) ?? true;
                      return GestureDetector(
                        onTap: () => _openTile(t),
                        onLongPress: () => _editTile(t),
                        child: Opacity(opacity: active ? 1.0 : 0.4,
                          child: Column(mainAxisSize: MainAxisSize.min, children: [
                            _tileVisual(t, color, 58),
                            const SizedBox(height: 6),
                            Text(t['label'] ?? '', style: AT.cap.copyWith(fontSize: 10, fontWeight: FontWeight.w600),
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
// Home-tile editor: label, icon, color, route, category, requiresPayLater.
class _TileFormDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  final int nextOrder;
  final List<ServiceProvider> providers;
  const _TileFormDialog({this.existing, required this.nextOrder, this.providers = const []});
  @override State<_TileFormDialog> createState() => _TileFormDialogState();
}
class _TileFormDialogState extends State<_TileFormDialog> {
  final _label = TextEditingController();
  final _color = TextEditingController(text: '#3B82F6');
  String _iconKey = 'apps';
  String _route   = 'recharge';
  String? _providerId; // when set, tile opens ONLY this provider's products
  bool _requiresPayLater = false;
  static const _icons = ['apps','smartphone','phone','bolt','gas','water','wifi','bank','business','wallet','shield','gift','school','medical','globe','gov','insurance','transfer','instapay','receipt'];
  static const _routes = {
    'recharge':'شحن رصيد','bill_telecom':'فاتورة تليفون','bill_elec':'كهرباء','bill_gas':'غاز',
    'bill_water':'مياه','bill_internet':'إنترنت','smart_billing':'فاتورة ذكية (طلب)',
    'instapay':'InstaPay','bank_transfer':'تحويل بنكي','b2b':'شركات','vodafone_cash':'فودافون كاش',
    'pay_later':'الدفع الآجل','wallet':'المحفظة','rewards':'المكافآت','my_requests':'طلباتي','notifs':'الإشعارات',
  };
  @override void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      _label.text = e['label']?.toString() ?? '';
      _color.text = e['colorHex']?.toString() ?? '#3B82F6';
      _iconKey = e['iconKey']?.toString() ?? 'apps';
      _route   = _routes.containsKey(e['route']) ? e['route'] as String : 'recharge';
      _providerId = e['providerId'] as String?;
      _requiresPayLater = (e['requiresPayLater'] as bool?) ?? false;
    }
  }
  @override void dispose() { _label.dispose(); _color.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) {
    // Ensure the stored providerId still exists in the list, else null it for the dropdown.
    final validPid = widget.providers.any((p) => p.id == _providerId) ? _providerId : null;
    return AlertDialog(
    title: Text(widget.existing == null ? 'أيقونة جديدة' : 'تعديل الأيقونة'),
    content: SizedBox(width: 360, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _label, decoration: const InputDecoration(labelText: 'الاسم الظاهر *', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _iconKey,
        decoration: const InputDecoration(labelText: 'الأيقونة', border: OutlineInputBorder()),
        isExpanded: true,
        items: _icons.map((k) => DropdownMenuItem(value: k, child: Row(children: [
          Icon(_icon(k), size: 18, color: AC.primary), const SizedBox(width: 8), Text(k),
        ]))).toList(),
        onChanged: (v) => setState(() => _iconKey = v ?? _iconKey),
      ),
      const SizedBox(height: 10),
      TextField(controller: _color, textDirection: TextDirection.ltr,
        decoration: const InputDecoration(labelText: 'اللون HEX (#3B82F6)', border: OutlineInputBorder())),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        value: _route,
        decoration: const InputDecoration(labelText: 'الإجراء عند الضغط', border: OutlineInputBorder()),
        isExpanded: true,
        items: _routes.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
        onChanged: (v) => setState(() => _route = v ?? _route),
      ),
      const SizedBox(height: 10),
      // Link to a specific provider → tile shows ONLY that provider's products.
      DropdownButtonFormField<String?>(
        value: validPid,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'المزود المرتبط (اختياري)', border: OutlineInputBorder(),
          helperText: 'اختر مزوداً لعرض منتجاته فقط — اتركه فارغاً لعرض كل المزودين'),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('— كل المزودين —')),
          ...widget.providers.map((p) => DropdownMenuItem<String?>(value: p.id, child: Text('${p.displayName} (${p.category})'))),
        ],
        onChanged: (v) => setState(() => _providerId = v),
      ),
      const SizedBox(height: 6),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('يتطلب الدفع الآجل', style: AT.body),
        value: _requiresPayLater,
        onChanged: (v) => setState(() => _requiresPayLater = v),
        activeColor: AC.primary,
      ),
    ]))),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        if (_label.text.trim().isEmpty) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الاسم مطلوب'), backgroundColor: AC.error)); return; }
        if (!RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(_color.text.trim())) { ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('صيغة اللون غير صحيحة'), backgroundColor: AC.error)); return; }
        // Derive category from the linked provider (so user-app filtering still works).
        final prov = widget.providers.where((p) => p.id == _providerId).firstOrNull;
        Navigator.pop(ctx, <String,dynamic>{
          'label': _label.text.trim(),
          'iconKey': _iconKey,
          'colorHex': _color.text.trim(),
          'route': _route,
          'category': prov?.category,
          'providerId': _providerId,
          'requiresPayLater': _requiresPayLater,
          if (widget.existing == null) 'order': widget.nextOrder,
        });
      }, child: const Text('حفظ')),
    ],
  );
  }
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
