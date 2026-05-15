import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

class TopUpScreen extends StatefulWidget {
  const TopUpScreen({super.key});
  @override State<TopUpScreen> createState() => _TopUpScreenState();
}

class _TopUpScreenState extends State<TopUpScreen> {
  final _amount = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;
  File? _proof;
  String _paymentMethod = 'BANK_TRANSFER';
  static const _quick = [50, 100, 200, 500, 1000];
  static const _methods = {
    'BANK_TRANSFER': 'تحويل بنكي',
    'VODAFONE_CASH': 'فودافون كاش',
    'INSTAPAY': 'إنستا باي',
  };

  @override
  void dispose() { _amount.dispose(); super.dispose(); }

  Future<void> _pickProof({required ImageSource source}) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 78, maxWidth: 1600);
    if (file != null && mounted) setState(() => _proof = File(file.path));
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_proof == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى رفع صورة إثبات التحويل'), backgroundColor: AppColors.error));
      return;
    }
    final amount = double.parse(_amount.text.trim());
    setState(() => _loading = true);
    try {
      final requestId = await UserRepo().walletTopupRequest(amount: amount, paymentMethod: _paymentMethod);
      await UserRepo().uploadProof(requestId, _proof!.path);
      if (!mounted) return;
      context.read<HomeBloc>().add(HomeRefreshEvent());
      await showModalBottomSheet(
        context: context, isDismissible: false, enableDrag: false,
        builder: (_) => SuccessSheet(
          title: '⏳ تم إرسال الطلب',
          subtitle: 'سيتم مراجعة إثبات الدفع وإضافة المبلغ بعد التحقق.\nالمبلغ: ${amount.toStringAsFixed(2)} ${S.egp}',
          onDone: () { Navigator.pop(context); context.pop(); },
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الطلب: $e'), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('شحن المحفظة')),
    body: SafeArea(
      child: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(D.md),
          children: [
            AppCard(padding: const EdgeInsets.all(D.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('المبلغ', style: TS.bodyM),
              const SizedBox(height: D.sm),
              AppField(
                label: 'المبلغ بالجنيه', hint: 'مثال: 100', ctrl: _amount,
                kb: const TextInputType.numberWithOptions(decimal: true),
                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
                validator: (v) {
                  final s = (v ?? '').trim();
                  if (s.isEmpty) return 'أدخل المبلغ';
                  final n = double.tryParse(s);
                  if (n == null) return 'مبلغ غير صحيح';
                  if (n < 10) return 'الحد الأدنى 10 ج.م';
                  if (n > 10000) return 'الحد الأقصى 10000 ج.م';
                  return null;
                },
              ),
              const SizedBox(height: D.md),
              Wrap(spacing: 8, runSpacing: 8, children: _quick.map((a) => ActionChip(
                label: Text('$a ${S.egp}', style: TS.cap),
                onPressed: () => setState(() => _amount.text = a.toString()),
                backgroundColor: AppColors.surface,
                side: BorderSide(color: AppColors.border),
              )).toList()),
            ])),

            const SizedBox(height: D.md),
            AppCard(padding: const EdgeInsets.all(D.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('طريقة الدفع', style: TS.bodyM),
              const SizedBox(height: D.sm),
              DropdownButtonFormField<String>(
                value: _paymentMethod,
                items: _methods.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value, style: TS.body))).toList(),
                onChanged: (v) => setState(() => _paymentMethod = v ?? 'BANK_TRANSFER'),
                decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true),
              ),
              const SizedBox(height: D.md),
              const Divider(),
              const SizedBox(height: D.sm),
              Text('إثبات الدفع *', style: TS.bodyM),
              Text('صورة من فاتورة التحويل / لقطة شاشة', style: TS.cap.copyWith(color: AppColors.textMuted)),
              const SizedBox(height: D.sm),
              if (_proof != null) ...[
                ClipRRect(borderRadius: BorderRadius.circular(D.r12), child: Image.file(_proof!, height: 180, fit: BoxFit.cover, width: double.infinity)),
                const SizedBox(height: D.sm),
              ],
              Row(children: [
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.camera_alt_rounded, size: 18),
                  label: Text(_proof == null ? 'التقاط' : 'إعادة الالتقاط'),
                  onPressed: () => _pickProof(source: ImageSource.camera),
                )),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_rounded, size: 18),
                  label: Text(_proof == null ? 'من المعرض' : 'تغيير'),
                  onPressed: () => _pickProof(source: ImageSource.gallery),
                )),
              ]),
            ])),

            const SizedBox(height: D.md),
            AppCard(padding: const EdgeInsets.all(D.md), child: Row(children: [
              Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(
                'يتم مراجعة طلب الشحن والتحقق من إثبات الدفع خلال 60 دقيقة. سيتم إضافة المبلغ إلى محفظتك بعد التحقق.',
                style: TS.cap.copyWith(color: AppColors.textSec),
              )),
            ])),
            const SizedBox(height: D.lg),
            AppButton(label: 'إرسال طلب الشحن', icon: Icons.send_rounded, isLoading: _loading, onPressed: _loading ? null : _submit),
          ],
        ),
      ),
    ),
  );
}
