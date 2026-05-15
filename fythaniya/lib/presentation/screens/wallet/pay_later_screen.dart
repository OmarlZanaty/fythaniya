import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

class PayLaterScreen extends StatefulWidget {
  const PayLaterScreen({super.key});
  @override State<PayLaterScreen> createState() => _PayLaterScreenState();
}

class _PayLaterScreenState extends State<PayLaterScreen> {
  bool _loading = false;

  Future<void> _requestActivation() async {
    setState(() => _loading = true);
    try {
      await UserRepo().requestPayLaterActivation();
      if (!mounted) return;
      context.read<HomeBloc>().add(HomeRefreshEvent());
      await showModalBottomSheet(
        context: context, isDismissible: false, enableDrag: false,
        builder: (_) => SuccessSheet(
          title: '⏳ تم إرسال الطلب',
          subtitle: 'سيتم مراجعة طلب تفعيل خدمة الدفع الآجل خلال 24 ساعة.',
          onDone: () { Navigator.pop(context); context.pop(); },
        ),
      );
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title: const Text('الدفع الآجل')),
    body: BlocBuilder<HomeBloc, HomeState>(builder: (ctx, state) {
      if (state is! HomeLoaded) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
      final u = state.user;
      return SafeArea(child: ListView(padding: const EdgeInsets.all(D.md), children: [
        AppCard(padding: const EdgeInsets.all(D.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 72, height: 72, decoration: BoxDecoration(
            color: u.payLaterEligible ? AppColors.successBg : (u.payLaterPending ? AppColors.infoBg : AppColors.surfaceAlt),
            borderRadius: BorderRadius.circular(20),
          ), child: Icon(
            u.payLaterEligible ? Icons.check_circle_rounded : (u.payLaterPending ? Icons.hourglass_top_rounded : Icons.payments_rounded),
            color: u.payLaterEligible ? AppColors.success : (u.payLaterPending ? AppColors.info : AppColors.primary), size: 40,
          )),
          const SizedBox(height: D.md),
          Text(
            u.payLaterEligible ? 'الدفع الآجل مفعّل' : (u.payLaterPending ? 'طلب التفعيل قيد المراجعة' : 'خدمة الدفع الآجل غير مفعّلة'),
            style: TS.h3,
          ),
          const SizedBox(height: D.sm),
          Text(
            u.payLaterEligible
              ? 'يمكنك استخدام خدمة الدفع الآجل عند تقديم أي طلب.'
              : (u.payLaterPending
                  ? 'سيتم إعلامك بقبول طلب التفعيل خلال 24 ساعة.'
                  : 'فعّل خدمة الدفع الآجل لتسديد فواتيرك لاحقاً والاستفادة من خدمات إضافية مثل فودافون كاش.'),
            style: TS.body.copyWith(color: AppColors.textSec),
          ),
          const SizedBox(height: D.md),
          if (!u.payLaterEligible && !u.payLaterPending) AppButton(
            label: 'طلب تفعيل الدفع الآجل', icon: Icons.send_rounded,
            isLoading: _loading, onPressed: _loading ? null : _requestActivation,
          ),
        ])),
        const SizedBox(height: D.md),
        AppCard(padding: const EdgeInsets.all(D.md), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('المزايا', style: TS.bodyM),
          const SizedBox(height: D.sm),
          ...['ادفع فواتيرك لاحقاً بدون رصيد', 'الوصول إلى خدمة فودافون كاش', 'حد ائتماني حسب نشاطك']
              .map((b) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: [
                Icon(Icons.check_rounded, color: AppColors.success, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(b, style: TS.body)),
              ]))),
        ])),
      ]));
    }),
  );
}
