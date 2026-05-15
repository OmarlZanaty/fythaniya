import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
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
  static const _quick = [50, 100, 200, 500, 1000];

  @override
  void dispose() { _amount.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final amount = double.parse(_amount.text.trim());
    setState(() => _loading = true);
    try {
      final newBalance = await UserRepo().walletTopup(amount);
      if (!mounted) return;
      context.read<WalletBloc>().add(WalletLoadEvent());
      context.read<HomeBloc>().add(HomeRefreshEvent());
      await showModalBottomSheet(
        context: context, isDismissible: false, enableDrag: false,
        builder: (_) => SuccessSheet(
          title: 'تم شحن المحفظة',
          subtitle: 'الرصيد الجديد: ${newBalance.toStringAsFixed(2)} ${S.egp}',
          onDone: () { Navigator.pop(context); context.pop(); },
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('فشل الشحن: $e'), backgroundColor: AppColors.error));
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
            AppCard(
              padding: const EdgeInsets.all(D.md),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('المبلغ', style: TS.bodyM),
                const SizedBox(height: D.sm),
                AppField(
                  label: 'المبلغ بالجنيه',
                  hint: 'مثال: 100',
                  ctrl: _amount,
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
              ]),
            ),
            const SizedBox(height: D.md),
            AppCard(
              padding: const EdgeInsets.all(D.md),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: AppColors.info, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(
                  'الشحن فوري — سيتم إضافة المبلغ إلى محفظتك مباشرة.',
                  style: TS.cap.copyWith(color: AppColors.textSec),
                )),
              ]),
            ),
            const SizedBox(height: D.lg),
            AppButton(
              label: 'شحن الآن',
              icon: Icons.add_rounded,
              isLoading: _loading,
              onPressed: _loading ? null : _submit,
            ),
          ],
        ),
      ),
    ),
  );
}
