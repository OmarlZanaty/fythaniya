import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() { _phone.dispose(); _amount.dispose(); _note.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final toPhone = _phone.text.trim();
    final amount = double.parse(_amount.text.trim());
    final note = _note.text.trim();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('تأكيد التحويل'),
        content: Text('سيتم تحويل ${amount.toStringAsFixed(2)} ${S.egp} إلى $toPhone. هل أنت متأكد؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text(S.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(S.confirm, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _loading = true);
    try {
      final res = await UserRepo().walletTransfer(toPhone: toPhone, amount: amount, note: note.isEmpty ? null : note);
      if (!mounted) return;
      context.read<WalletBloc>().add(WalletLoadEvent());
      context.read<HomeBloc>().add(HomeRefreshEvent());
      await showModalBottomSheet(
        context: context, isDismissible: false, enableDrag: false,
        builder: (_) => SuccessSheet(
          title: 'تم التحويل',
          subtitle: 'إلى ${res['recipientName'] ?? toPhone}\nالرصيد الجديد: ${(res['newBalance'] as double).toStringAsFixed(2)} ${S.egp}',
          onDone: () { Navigator.pop(context); context.pop(); },
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل التحويل: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('تحويل رصيد')),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(D.md),
          children: [
            AppCard(
              padding: const EdgeInsets.all(D.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('بيانات المستلم', style: TS.bodyM),
                const SizedBox(height: D.sm),
                AppField(
                  label: 'رقم هاتف المستلم',
                  hint: S.phonePlch,
                  ctrl: _phone,
                  kb: TextInputType.phone,
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'أدخل رقم الهاتف';
                    if (!RegExp(r'^[0-9+]{7,15}$').hasMatch(s)) return S.invalidPhone;
                    return null;
                  },
                ),
                const SizedBox(height: D.md),
                AppField(
                  label: 'المبلغ بالجنيه',
                  hint: 'مثال: 50',
                  ctrl: _amount,
                  kb: const TextInputType.numberWithOptions(decimal: true),
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'أدخل المبلغ';
                    final n = double.tryParse(s);
                    if (n == null) return 'مبلغ غير صحيح';
                    if (n < 5) return 'الحد الأدنى 5 ج.م';
                    return null;
                  },
                ),
                const SizedBox(height: D.md),
                AppField(
                  label: 'ملاحظة (اختياري)',
                  hint: 'سبب التحويل',
                  ctrl: _note,
                  maxLines: 2,
                ),
              ]),
            ),
            const SizedBox(height: D.md),
            AppCard(
              padding: const EdgeInsets.all(D.md),
              child: Row(children: [
                Icon(Icons.security_rounded, color: AppColors.info, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'تأكد من رقم المستلم — التحويلات نهائية ولا يمكن التراجع عنها.',
                  style: TS.cap.copyWith(color: AppColors.textSec),
                )),
              ]),
            ),
            const SizedBox(height: D.lg),
            AppButton(
              label: 'إرسال',
              icon: Icons.send_rounded,
              isLoading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
