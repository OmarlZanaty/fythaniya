import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:intl/intl.dart' as intl;
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

// ══════════════════════════════════════════════════════════
//  B2B APPLY SCREEN
// ══════════════════════════════════════════════════════════
class B2BApplyScreen extends StatefulWidget {
  const B2BApplyScreen({super.key});
  @override State<B2BApplyScreen> createState() => _B2BApplyState();
}
class _B2BApplyState extends State<B2BApplyScreen> {
  final _form = GlobalKey<FormState>();
  final _company = TextEditingController();
  final _tax     = TextEditingController();
  final _reg     = TextEditingController();
  final _cname   = TextEditingController();
  final _cphone  = TextEditingController();
  final _limit   = TextEditingController();

  @override void dispose() { for(final c in[_company,_tax,_reg,_cname,_cphone,_limit]) c.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title:const Text(S.b2bApply),backgroundColor:AppColors.primary,
      leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop())),
    body: BlocConsumer<B2BBloc,B2BState>(
      listener:(ctx,s){
        if(s is B2BApplied){
          showDialog(context:ctx,builder:(_)=>AlertDialog(
            title:const Text('تم تقديم الطلب 🎉'),
            content:const Text('تم تقديم طلب حساب B2B. سيتم الرد خلال 24 ساعة.'),
            actions:[TextButton(onPressed:(){Navigator.pop(ctx);ctx.go(AppRoutes.home);},child:const Text('تم'))],
          ));
        }
        if(s is B2BError) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(s.msg),backgroundColor:AppColors.error));
      },
      builder:(ctx,s){
        final loading = s is B2BApplying;
        return SingleChildScrollView(padding:const EdgeInsets.all(D.md),child:Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          // Info banner
          Container(padding:const EdgeInsets.all(D.md),margin:const EdgeInsets.only(bottom:D.md),
            decoration:BoxDecoration(gradient:AppGradients.b2b,borderRadius:BorderRadius.circular(D.r16)),
            child:Row(children:[
              const Icon(Icons.business_rounded,color:Colors.white,size:32),const SizedBox(width:D.md),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('حساب الأعمال B2B',style:TS.bodyM.copyWith(color:Colors.white)),
                Text('احصل على حد ائتماني وادفع لاحقاً',style:TS.cap.copyWith(color:Colors.white70)),
              ])),
            ])),

          // Section: company info
          _Section('معلومات الشركة'),
          AppField(label:S.companyName,ctrl:_company,validator:(v)=>(v?.trim().isEmpty??true)?S.required:null,
            prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.business_rounded,size:20))),
          const SizedBox(height:D.md),
          AppField(label:S.taxId,ctrl:_tax,kb:TextInputType.number,validator:(v)=>(v?.trim().isEmpty??true)?S.required:null,
            prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.badge_rounded,size:20))),
          const SizedBox(height:D.md),
          AppField(label:'السجل التجاري (اختياري)',ctrl:_reg,
            prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.file_present_rounded,size:20))),
          const SizedBox(height:D.lg),

          _Section('جهة الاتصال'),
          AppField(label:S.contactName,ctrl:_cname,validator:(v)=>(v?.trim().isEmpty??true)?S.required:null,
            prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.person_outline_rounded,size:20))),
          const SizedBox(height:D.md),
          AppField(label:S.contactPhone,ctrl:_cphone,kb:TextInputType.phone,
            formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
            validator:(v)=>(v?.trim().isEmpty??true)?S.required:null,
            prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.phone_android_rounded,size:20))),
          const SizedBox(height:D.lg),

          _Section('الحد الائتماني المطلوب'),
          AppField(label:S.requestedLim,hint:'مثال: 10000',ctrl:_limit,kb:const TextInputType.numberWithOptions(decimal:true),
            formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
            validator:(v){if(v==null||v.trim().isEmpty)return S.required;final a=double.tryParse(v);if(a==null||a<100)return 'الحد الأدنى 100 ج.م';return null;},
            prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.credit_card_rounded,size:20))),
          const SizedBox(height:D.sm),
          Text('* يخضع الحد الائتماني للموافقة من قبل الإدارة',style:TS.cap.copyWith(color:AppColors.textMuted)),
          const SizedBox(height:D.xl),

          AppButton(label:'تقديم الطلب',isLoading:loading,icon:Icons.send_rounded,
            onPressed:(){
              if(!_form.currentState!.validate())return;
              ctx.read<B2BBloc>().add(B2BApplyEvent(
                companyName:_company.text.trim(), taxId:_tax.text.trim(),
                commercialReg:_reg.text.trim().isEmpty?null:_reg.text.trim(),
                contactName:_cname.text.trim(), contactPhone:_cphone.text.trim(),
                requestedLimit:double.parse(_limit.text)));
            }),
          const SizedBox(height:D.xxl),
        ])));
      }));
}

class _Section extends StatelessWidget {
  final String title; const _Section(this.title);
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:D.sm,top:D.sm),
    child:Text(title,style:TS.h3.copyWith(color:AppColors.primary)));
}

// ══════════════════════════════════════════════════════════
//  B2B DASHBOARD
// ══════════════════════════════════════════════════════════
class B2BDashboardScreen extends StatefulWidget {
  const B2BDashboardScreen({super.key});
  @override State<B2BDashboardScreen> createState() => _B2BDashState();
}
class _B2BDashState extends State<B2BDashboardScreen> {
  @override void initState(){super.initState();context.read<B2BBloc>().add(B2BLoadEvent());}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.b2bDash),backgroundColor:AppColors.primary,
      leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop()),
      actions:[IconButton(icon:const Icon(Icons.refresh_rounded),onPressed:()=>context.read<B2BBloc>().add(B2BLoadEvent()))]),
    body:BlocBuilder<B2BBloc,B2BState>(builder:(ctx,s){
      if(s is B2BLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
      if(s is B2BNoAccount) return EmptyState(title:'لا يوجد حساب B2B',subtitle:'قدّم طلبك للحصول على حساب B2B',icon:Icons.business_outlined,action:S.b2bApply,onAction:()=>ctx.push(AppRoutes.b2bApply));
      if(s is B2BError) return AppErrorWidget(message:s.msg,onRetry:()=>ctx.read<B2BBloc>().add(B2BLoadEvent()));
      if(s is B2BLoaded){
        final acc=s.account;
        return ListView(padding:const EdgeInsets.all(D.md),children:[
          // Status card
          B2BStatusCard(account:acc),
          const SizedBox(height:D.lg),

          // Pending approval notice
          if(acc.isPending)Container(padding:const EdgeInsets.all(D.md),
            decoration:BoxDecoration(color:AppColors.warningBg,borderRadius:BorderRadius.circular(D.r12),border:Border.all(color:AppColors.warning.withOpacity(0.3))),
            child:Row(children:[const Icon(Icons.access_time_rounded,color:AppColors.warning,size:22),const SizedBox(width:12),
              Expanded(child:Text('طلبك قيد المراجعة. سيتم الرد خلال 24 ساعة.',style:TS.body.copyWith(color:AppColors.warning)))])),

          if(acc.isRejected)Container(padding:const EdgeInsets.all(D.md),
            decoration:BoxDecoration(color:AppColors.errorBg,borderRadius:BorderRadius.circular(D.r12)),
            child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[const Icon(Icons.cancel_rounded,color:AppColors.error,size:22),const SizedBox(width:12),Text('تم رفض الطلب',style:TS.bodyM.copyWith(color:AppColors.error))]),
              if(acc.rejectionReason!=null)Padding(padding:const EdgeInsets.only(top:8),child:Text('السبب: ${acc.rejectionReason}',style:TS.cap.copyWith(color:AppColors.error))),
            ])),

          if(acc.isActive)...[
            const SizedBox(height:D.md),
            // Quick actions
            Row(children:[
              Expanded(child:_B2BAction(icon:Icons.add_card_rounded,label:'طلب جديد',color:AppColors.primary,onTap:()=>ctx.push(AppRoutes.b2bRequest))),
              const SizedBox(width:12),
              Expanded(child:_B2BAction(icon:Icons.receipt_long_rounded,label:'الفواتير',color:AppColors.b2b,onTap:()=>ctx.push(AppRoutes.b2bInvoices))),
              const SizedBox(width:12),
              Expanded(child:_B2BAction(icon:Icons.analytics_rounded,label:'التقارير',color:AppColors.accent,onTap:()=>ctx.push(AppRoutes.b2bInvoices))),
            ]),
            const SizedBox(height:D.lg),

            // Stats
            AppCard(child:Column(children:[
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('إجمالي الائتمان',style:TS.cap),Text('${acc.creditLimit.toStringAsFixed(0)} ${S.egp}',style:TS.bodyM.copyWith(color:AppColors.b2b))]),
              const SizedBox(height:8),
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('المستخدم',style:TS.cap),Text('${acc.usedCredit.toStringAsFixed(0)} ${S.egp}',style:TS.bodyM.copyWith(color:AppColors.error))]),
              const SizedBox(height:8),
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('المتاح',style:TS.cap),Text('${acc.availableCredit.toStringAsFixed(0)} ${S.egp}',style:TS.bodyM.copyWith(color:AppColors.success))]),
              const SizedBox(height:12),
              LinearPercentIndicator(percent:acc.usagePercent,lineHeight:8,backgroundColor:AppColors.surfaceAlt,progressColor:acc.usagePercent>0.8?AppColors.error:AppColors.primary,barRadius:const Radius.circular(4),padding:EdgeInsets.zero),
            ])),
            const SizedBox(height:D.lg),

            // Recent invoices
            SectionHeader(title:'آخر الفواتير',action:'عرض الكل',onAction:()=>ctx.push(AppRoutes.b2bInvoices)),
            const SizedBox(height:D.md),
            if(acc.b2bPayLaters.isEmpty)EmptyState(title:'لا توجد فواتير',icon:Icons.receipt_outlined)
            else...acc.b2bPayLaters.take(5).map((pl)=>_InvoiceTile(pl:pl)),
          ],
          const SizedBox(height:D.xxl),
        ]);
      }
      return const SizedBox.shrink();
    }));
}

class _B2BAction extends StatelessWidget {
  final IconData icon;final String label;final Color color;final VoidCallback onTap;
  const _B2BAction({required this.icon,required this.label,required this.color,required this.onTap});
  @override Widget build(BuildContext context)=>GestureDetector(onTap:onTap,child:AppCard(padding:const EdgeInsets.symmetric(vertical:16),child:Column(children:[
    Container(width:44,height:44,decoration:BoxDecoration(color:color.withOpacity(0.1),shape:BoxShape.circle),child:Icon(icon,color:color,size:24)),
    const SizedBox(height:8),Text(label,style:TS.cap.copyWith(fontWeight:FontWeight.w600),textAlign:TextAlign.center),
  ])));
}

class _InvoiceTile extends StatelessWidget {
  final B2BPayLaterModel pl;
  const _InvoiceTile({required this.pl});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:8),child:AppCard(child:Row(children:[
    Container(width:44,height:44,decoration:BoxDecoration(color:pl.isOverdue?AppColors.errorBg:AppColors.infoBg,borderRadius:BorderRadius.circular(10)),
      child:Icon(pl.isOverdue?Icons.warning_rounded:Icons.receipt_rounded,color:pl.isOverdue?AppColors.error:AppColors.b2b,size:22)),
    const SizedBox(width:12),
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(pl.invoiceNo,style:TS.bodyM),
      Text('الاستحقاق: ${pl.dueDate.day}/${pl.dueDate.month}/${pl.dueDate.year}',style:TS.cap),
    ])),
    Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
      Text('${pl.amount.toStringAsFixed(0)} ${S.egp}',style:TS.bodyM.copyWith(color:pl.isOverdue?AppColors.error:AppColors.text)),
      const SizedBox(height:4),StatusBadge(status:pl.status,small:true),
    ]),
  ])));
}

// ══════════════════════════════════════════════════════════
//  B2B REQUEST SCREEN
// ══════════════════════════════════════════════════════════
class B2BRequestScreen extends StatefulWidget {
  const B2BRequestScreen({super.key});
  @override State<B2BRequestScreen> createState() => _B2BRequestState();
}
class _B2BRequestState extends State<B2BRequestScreen> {
  final _form = GlobalKey<FormState>();
  final _account = TextEditingController();
  final _amount  = TextEditingController();
  ServiceProviderModel? _provider;
  SubServiceModel? _sub;

  @override void dispose() { _account.dispose(); _amount.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text('طلب Pay Later'),backgroundColor:AppColors.primary,
      leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop())),
    body:BlocConsumer<B2BBloc,B2BState>(
      listener:(ctx,s){
        if(s is B2BRequestDone){showModalBottomSheet(context:ctx,isScrollControlled:true,builder:(_)=>SuccessSheet(title:'تم تقديم الطلب!',subtitle:'سيتم تنفيذ طلب Pay Later خلال دقائق',ref:null,onDone:(){Navigator.pop(ctx);ctx.pop();}));}
        if(s is B2BError) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(s.msg),backgroundColor:AppColors.error));
      },
      builder:(ctx,s){
        return FutureBuilder<List<ServiceProviderModel>>(
          future: Future.value([]),
          builder:(_,__){
            return Form(key:_form,child:SingleChildScrollView(padding:const EdgeInsets.all(D.md),child:Column(children:[
              Container(padding:const EdgeInsets.all(D.md),margin:const EdgeInsets.only(bottom:D.md),
                decoration:BoxDecoration(color:AppColors.infoBg,borderRadius:BorderRadius.circular(D.r12),border:Border.all(color:AppColors.border)),
                child:Row(children:[const Icon(Icons.info_outline_rounded,color:AppColors.primary,size:20),const SizedBox(width:10),
                  Expanded(child:Text('سيتم خصم المبلغ من حد الائتمان وإضافة فاتورة للسداد لاحقاً',style:TS.cap.copyWith(color:AppColors.primary)))])),
              AppField(label:'رقم الحساب / الهاتف',ctrl:_account,validator:(v)=>(v?.isEmpty??true)?S.required:null,
                prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.numbers_rounded,size:20))),
              const SizedBox(height:D.md),
              AmountPicker(ctrl:_amount,quickAmounts:const[100,200,500,1000,2000,5000],
                validator:(v){if(v==null||v.isEmpty)return S.required;final a=double.tryParse(v);if(a==null||a<100)return 'الحد الأدنى 100 ج.م';return null;}),
              const SizedBox(height:D.lg),
              AppButton(label:'تأكيد الطلب',isLoading:s is B2BSubmitting,
                onPressed:(){
                  if(!_form.currentState!.validate())return;
                  ctx.read<B2BBloc>().add(B2BRequestEvent(
                    providerId:'',accountNumber:_account.text.trim(),
                    amount:double.parse(_amount.text)));
                }),
              const SizedBox(height:D.xxl),
            ])));
          });
      }));
}

// ══════════════════════════════════════════════════════════
//  B2B INVOICES SCREEN
// ══════════════════════════════════════════════════════════
class B2BInvoicesScreen extends StatefulWidget {
  const B2BInvoicesScreen({super.key});
  @override State<B2BInvoicesScreen> createState() => _B2BInvoicesState();
}
class _B2BInvoicesState extends State<B2BInvoicesScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState(){super.initState();_tab=TabController(length:3,vsync:this);context.read<B2BBloc>().add(const B2BLoadInvoicesEvent());}
  @override void dispose(){_tab.dispose();super.dispose();}

  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.invoices),backgroundColor:AppColors.primary,
      leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop()),
      bottom:TabBar(controller:_tab,labelColor:Colors.white,unselectedLabelColor:Colors.white70,indicatorColor:Colors.white,
        tabs:const[Tab(text:'الكل'),Tab(text:'نشطة'),Tab(text:'متأخرة')])),
    body:BlocBuilder<B2BBloc,B2BState>(builder:(ctx,s){
      if(s is B2BLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
      if(s is B2BError) return AppErrorWidget(message:s.msg,onRetry:()=>ctx.read<B2BBloc>().add(const B2BLoadInvoicesEvent()));
      if(s is B2BInvoicesLoaded){
        return TabBarView(controller:_tab,children:[
          _InvoiceList(items:s.invoices,onSettle:(id)=>ctx.read<B2BBloc>().add(B2BSettleEvent(id))),
          _InvoiceList(items:s.invoices.where((p)=>p.status=='ACTIVE').toList(),onSettle:(id)=>ctx.read<B2BBloc>().add(B2BSettleEvent(id))),
          _InvoiceList(items:s.invoices.where((p)=>p.isOverdue).toList(),onSettle:(id)=>ctx.read<B2BBloc>().add(B2BSettleEvent(id))),
        ]);
      }
      return const Center(child:CircularProgressIndicator(color:AppColors.primary));
    }));
}

class _InvoiceList extends StatelessWidget {
  final List<B2BPayLaterModel> items;
  final void Function(String) onSettle;
  const _InvoiceList({required this.items,required this.onSettle});
  @override Widget build(BuildContext context){
    if(items.isEmpty) return EmptyState(title:'لا توجد فواتير',icon:Icons.receipt_outlined);
    return ListView.builder(padding:const EdgeInsets.all(D.md),itemCount:items.length,itemBuilder:(_,i){
      final pl=items[i];
      return Padding(padding:const EdgeInsets.only(bottom:12),child:AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[
          Expanded(child:Text(pl.invoiceNo,style:TS.bodyM)),
          StatusBadge(status:pl.status),
        ]),
        const Divider(height:16),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('المبلغ:',style:TS.cap),Text('${pl.amount.toStringAsFixed(2)} ${S.egp}',style:TS.bodyM)]),
        const SizedBox(height:4),
        Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(S.dueDate+':',style:TS.cap),Text('${pl.dueDate.day}/${pl.dueDate.month}/${pl.dueDate.year}',style:TS.cap.copyWith(color:pl.isOverdue?AppColors.error:AppColors.textSec))]),
        if(!pl.isSettled)...[
          const SizedBox(height:D.md),
          SizedBox(width:double.infinity,child:OutlinedButton(
            onPressed:()=>showDialog(context:context,builder:(_)=>AlertDialog(
              title:const Text('تأكيد السداد'),content:Text('هل تريد تسجيل سداد الفاتورة ${pl.invoiceNo}؟'),
              actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text(S.cancel)),TextButton(onPressed:(){Navigator.pop(context);onSettle(pl.id);},child:Text(S.confirm,style:const TextStyle(color:AppColors.success)))])),
            style:OutlinedButton.styleFrom(foregroundColor:AppColors.success,side:const BorderSide(color:AppColors.success)),
            child:const Text('تسجيل السداد'))),
        ],
      ])));
    });
  }
}
