import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

// ══════════════════════════════════════════════════════════
//  RECHARGE SCREEN
// ══════════════════════════════════════════════════════════
class RechargeScreen extends StatefulWidget {
  const RechargeScreen({super.key});
  @override State<RechargeScreen> createState() => _RechargeScreenState();
}
class _RechargeScreenState extends State<RechargeScreen> {
  final _form = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _amount = TextEditingController();
  ServiceProviderModel? _provider;
  SubServiceModel? _sub;

  @override void initState() { super.initState(); context.read<RechargeBloc>().add(RechargeInitEvent()); }
  @override void dispose() { _phone.dispose(); _amount.dispose(); super.dispose(); }

  double get _fee => _sub!=null ? _sub!.feeFor(double.tryParse(_amount.text)??0) : 1.5;

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(title:const Text(S.recharge),backgroundColor:AppColors.primary,
      leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop())),
    body: BlocConsumer<RechargeBloc,RechargeState>(
      listener:(ctx,s){
        if(s is RechargeSuccess){
          showModalBottomSheet(context:ctx,isScrollControlled:true,builder:(_)=>SuccessSheet(
            title:S.successTitle,subtitle:S.successSub,
            ref:s.req.id.substring(0,8).toUpperCase(),onDone:(){Navigator.pop(ctx);ctx.pop();}));
        }
        if(s is RechargeError) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(s.msg),backgroundColor:AppColors.error));
      },
      builder:(ctx,s){
        if(s is RechargeLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
        final providers = s is RechargeLoaded ? s.providers : <ServiceProviderModel>[];
        final isSubmitting = s is RechargeSubmitting;
        return Form(key:_form,child:SingleChildScrollView(padding:const EdgeInsets.all(D.md),child:Column(children:[
          ProviderSelector(providers:providers,selected:_provider,onSelect:(p){setState((){_provider=p;_sub=p.subServices.isNotEmpty?p.subServices.first:null;});}),
          const SizedBox(height:D.md),
          if(_provider!=null&&_provider!.subServices.length>1)...[
            SubServiceSelector(subServices:_provider!.subServices,selected:_sub,onSelect:(s2)=>setState(()=>_sub=s2)),
            const SizedBox(height:D.md),
          ],
          AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('رقم الهاتف المراد شحنه',style:TS.cap),const SizedBox(height:D.sm),
            AppField(label:S.phone,hint:S.phonePlch,ctrl:_phone,kb:TextInputType.phone,
              formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
              validator:(v)=>(v?.isEmpty??true)?S.required:null,
              prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.phone_android_rounded,size:20))),
          ])),
          const SizedBox(height:D.md),
          AmountPicker(ctrl:_amount,quickAmounts:_sub?.quickAmounts.isNotEmpty==true?_sub!.quickAmounts:const[5,10,15,25,50,100],
            validator:(v){if(v==null||v.isEmpty)return S.required;final a=double.tryParse(v);if(a==null||a<5)return 'الحد الأدنى 5 ج.م';if(a>500)return 'الحد الأقصى 500 ج.م';return null;}),
          const SizedBox(height:D.md),
          if(_amount.text.isNotEmpty&&double.tryParse(_amount.text)!=null) AppCard(child:Column(children:[
            SummaryRow(label:'المبلغ',value:'${_amount.text} ${S.egp}'),
            SummaryRow(label:S.fee,value:'${_fee.toStringAsFixed(2)} ${S.egp}'),
            const Divider(height:20),
            SummaryRow(label:S.total,value:'${((double.tryParse(_amount.text)??0)+_fee).toStringAsFixed(2)} ${S.egp}',bold:true,valueColor:AppColors.primary),
          ])),
          const SizedBox(height:D.lg),
          AppButton(label:'شحن الآن',isLoading:isSubmitting,onPressed:(){
            if(!_form.currentState!.validate()||_provider==null)return;
            ctx.read<RechargeBloc>().add(RechargeSubmitEvent(
              providerId:_provider!.id,subServiceId:_sub?.id??'',
              phone:_phone.text.trim(),amount:double.parse(_amount.text)));
          }),
          const SizedBox(height:D.xxl),
        ])));
      }));
}

// ══════════════════════════════════════════════════════════
//  BILL SCREEN
// ══════════════════════════════════════════════════════════
class BillScreen extends StatefulWidget {
  final String category;
  const BillScreen({super.key,required this.category});
  @override State<BillScreen> createState() => _BillScreenState();
}
class _BillScreenState extends State<BillScreen> {
  final _form=GlobalKey<FormState>(); final _account=TextEditingController(); final _amount=TextEditingController();
  ServiceProviderModel? _provider; SubServiceModel? _sub;

  @override void initState() { super.initState(); context.read<BillBloc>().add(BillLoadEvent(widget.category)); }
  @override void dispose() { _account.dispose(); _amount.dispose(); super.dispose(); }

  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:Text(kCategoryNames[widget.category]??widget.category),backgroundColor:AppColors.primary,
      leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop())),
    body:BlocConsumer<BillBloc,BillState>(
      listener:(ctx,s){
        if(s is BillSuccess){showModalBottomSheet(context:ctx,isScrollControlled:true,builder:(_)=>SuccessSheet(title:'تم تقديم طلب الدفع!',subtitle:S.successSub,ref:s.req.id.substring(0,8).toUpperCase(),onDone:(){Navigator.pop(ctx);ctx.pop();}));}
        if(s is BillError) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(s.msg),backgroundColor:AppColors.error));
      },
      builder:(ctx,s){
        if(s is BillLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
        final providers=s is BillLoaded?s.providers:<ServiceProviderModel>[];
        final isSubmitting=s is BillSubmitting;
        return Form(key:_form,child:SingleChildScrollView(padding:const EdgeInsets.all(D.md),child:Column(children:[
          ProviderSelector(providers:providers,selected:_provider,onSelect:(p){setState((){_provider=p;_sub=p.subServices.isNotEmpty?p.subServices.first:null;});}),
          const SizedBox(height:D.md),
          if(_provider!=null&&_provider!.subServices.length>1)...[
            SubServiceSelector(subServices:_provider!.subServices,selected:_sub,onSelect:(s2)=>setState(()=>_sub=s2)),
            const SizedBox(height:D.md),
          ],
          AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(S.accountNum,style:TS.cap),const SizedBox(height:D.sm),
            AppField(label:S.accountNum,ctrl:_account,kb:TextInputType.number,validator:(v)=>(v?.isEmpty??true)?S.required:null,
              prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.numbers_rounded,size:20))),
          ])),
          const SizedBox(height:D.md),
          AmountPicker(ctrl:_amount,quickAmounts:_sub?.quickAmounts.isNotEmpty==true?_sub!.quickAmounts:const[50,100,200,500,1000],
            validator:(v){if(v==null||v.isEmpty)return S.required;final a=double.tryParse(v);if(a==null||a<10)return 'الحد الأدنى 10 ج.م';return null;}),
          const SizedBox(height:D.lg),
          AppButton(label:'دفع الفاتورة',isLoading:isSubmitting,onPressed:(){
            if(!_form.currentState!.validate()||_provider==null)return;
            ctx.read<BillBloc>().add(BillSubmitEvent(providerId:_provider!.id,subServiceId:_sub?.id??'',accountNumber:_account.text.trim(),amount:double.parse(_amount.text)));
          }),
          const SizedBox(height:D.xxl),
        ])));
      }));
}

// ══════════════════════════════════════════════════════════
//  TRANSACTIONS SCREEN
// ══════════════════════════════════════════════════════════
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});
  @override State<TransactionsScreen> createState() => _TxState();
}
class _TxState extends State<TransactionsScreen> {
  String? _filter;
  final _filters  = [null,'SUCCESS','PENDING','FAILED','REFUNDED'];
  final _labels   = [S.all,S.completed,S.pending,S.failed,'مسترد'];

  @override void initState() { super.initState(); context.read<TxBloc>().add(TxLoadEvent(status:_filter)); }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.txTitle),backgroundColor:AppColors.primary,
      leading:Navigator.canPop(context)?IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop()):null),
    body:Column(children:[
      SizedBox(height:52,child:ListView.builder(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:D.md,vertical:8),
        itemCount:_filters.length,itemBuilder:(_,i){
          final act=_filter==_filters[i];
          return Padding(padding:const EdgeInsets.only(right:8),child:FilterChip(
            label:Text(_labels[i]),selected:act,onSelected:(_){setState(()=>_filter=_filters[i]);context.read<TxBloc>().add(TxFilterEvent(_filter));},
            backgroundColor:AppColors.surfaceAlt,selectedColor:AppColors.infoBg,
            labelStyle:TS.cap.copyWith(color:act?AppColors.primary:AppColors.textSec),
            side:BorderSide(color:act?AppColors.primary:AppColors.border),showCheckmark:false));
        })),
      const Divider(height:1),
      Expanded(child:BlocBuilder<TxBloc,TxState>(builder:(ctx,s){
        if(s is TxLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
        if(s is TxError) return AppErrorWidget(message:s.msg,onRetry:()=>ctx.read<TxBloc>().add(TxLoadEvent(status:_filter)));
        if(s is TxLoaded){
          if(s.items.isEmpty) return EmptyState(title:S.noTx,subtitle:'لم تقم بأي معاملات بعد',icon:Icons.receipt_long_outlined);
          return NotificationListener<ScrollNotification>(
            onNotification:(n){if(n is ScrollEndNotification&&n.metrics.pixels>=n.metrics.maxScrollExtent-200)ctx.read<TxBloc>().add(TxMoreEvent());return false;},
            child:ListView.builder(itemCount:s.items.length+(s.hasMore?1:0),itemBuilder:(_,i){
              if(i==s.items.length) return const Padding(padding:EdgeInsets.all(16),child:Center(child:CircularProgressIndicator(color:AppColors.primary)));
              return TxTile(tx:s.items[i]);
            }));
        }
        return const SizedBox.shrink();
      })),
    ]));
}

// ══════════════════════════════════════════════════════════
//  NOTIFICATIONS SCREEN
// ══════════════════════════════════════════════════════════
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotifState();
}
class _NotifState extends State<NotificationsScreen> {
  @override void initState(){super.initState();context.read<NotifBloc>().add(NotifLoadEvent());}
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.notifTitle),backgroundColor:AppColors.primary,
      leading:Navigator.canPop(context)?IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop()):null,
      actions:[TextButton(onPressed:()=>context.read<NotifBloc>().add(NotifMarkAllEvent()),child:Text(S.markAllRead,style:TS.cap.copyWith(color:Colors.white70)))]),
    body:BlocBuilder<NotifBloc,NotifState>(builder:(ctx,s){
      if(s is NotifLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
      if(s is NotifError) return AppErrorWidget(message:s.msg,onRetry:()=>ctx.read<NotifBloc>().add(NotifLoadEvent()));
      if(s is NotifLoaded){
        if(s.items.isEmpty) return EmptyState(title:S.noNotif,subtitle:'ستظهر هنا إشعاراتك الجديدة',icon:Icons.notifications_outlined);
        return ListView.builder(padding:const EdgeInsets.all(D.md),itemCount:s.items.length,itemBuilder:(_,i){
          final n=s.items[i];
          return Container(margin:const EdgeInsets.only(bottom:8),
            decoration:BoxDecoration(color:n.isRead?AppColors.card:AppColors.infoBg,borderRadius:BorderRadius.circular(D.r12),
              border:Border.all(color:n.isRead?AppColors.border:AppColors.primary.withOpacity(0.3))),
            child:ListTile(
              leading:Container(width:44,height:44,decoration:BoxDecoration(color:_notifColor(n.priority).withOpacity(0.1),shape:BoxShape.circle),
                child:Icon(_notifIcon(n.priority),color:_notifColor(n.priority),size:22)),
              title:Text(n.title,style:TS.bodyM),
              subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                const SizedBox(height:2),Text(n.body,style:TS.cap,maxLines:2,overflow:TextOverflow.ellipsis),
                const SizedBox(height:4),Text(_ago(n.createdAt),style:TS.cap.copyWith(color:AppColors.textMuted,fontSize:10)),
              ]),
              trailing:!n.isRead?Container(width:8,height:8,decoration:const BoxDecoration(color:AppColors.primary,shape:BoxShape.circle)):null,
              onTap:(){context.read<NotifBloc>().add(NotifMarkAllEvent());}));
        });
      }
      return const SizedBox.shrink();
    }));
  Color _notifColor(String p){switch(p){case 'CRITICAL':return AppColors.error;case 'HIGH':return AppColors.warning;default:return AppColors.primary;}}
  IconData _notifIcon(String p){switch(p){case 'CRITICAL':return Icons.error_rounded;case 'HIGH':return Icons.warning_rounded;default:return Icons.notifications_rounded;}}
  String _ago(DateTime dt){final d=DateTime.now().difference(dt);if(d.inMinutes<60)return'منذ ${d.inMinutes} دق';if(d.inHours<24)return'منذ ${d.inHours} ساعة';return'${dt.day}/${dt.month}';}
}

// ══════════════════════════════════════════════════════════
//  WALLET SCREEN
// ══════════════════════════════════════════════════════════
class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});
  @override State<WalletScreen> createState() => _WalletState();
}
class _WalletState extends State<WalletScreen> {
  @override void initState(){super.initState();context.read<WalletBloc>().add(WalletLoadEvent());}
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.walletTitle),backgroundColor:AppColors.primary,
      leading:Navigator.canPop(context)?IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop()):null),
    body:BlocBuilder<WalletBloc,WalletState>(builder:(ctx,s){
      if(s is WalletLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
      if(s is WalletError) return AppErrorWidget(message:s.msg,onRetry:()=>ctx.read<WalletBloc>().add(WalletLoadEvent()));
      if(s is WalletLoaded){
        return ListView(padding:const EdgeInsets.all(D.md),children:[
          WalletCard(balance:s.user.walletBalance,points:s.user.pointsBalance,tierAr:s.user.tierAr),
          const SizedBox(height:D.lg),
          Row(children:[
            Expanded(child:_QAct(icon:Icons.add_rounded,label:S.topUp,color:AppColors.success,onTap:(){})),
            const SizedBox(width:12),
            Expanded(child:_QAct(icon:Icons.send_rounded,label:'إرسال',color:AppColors.primary,onTap:(){})),
            const SizedBox(width:12),
            Expanded(child:_QAct(icon:Icons.history_rounded,label:'السجل',color:AppColors.info,onTap:()=>context.push(AppRoutes.txList))),
          ]),
          const SizedBox(height:D.lg),
          if(s.spending.isNotEmpty)...[
            SectionHeader(title:S.spending),const SizedBox(height:D.md),
            AppCard(child:Column(children:s.spending.take(5).map((sp)=>Padding(padding:const EdgeInsets.symmetric(vertical:8),
              child:Row(children:[CategoryIcon(category:sp.category,size:18),const SizedBox(width:12),
                Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(kCategoryNames[sp.category]??sp.category,style:TS.bodyM),Text('${sp.count} معاملة',style:TS.cap)])),
                Text('${sp.amount.toStringAsFixed(0)} ${S.egp}',style:TS.bodyM.copyWith(color:AppColors.accent)),
              ]))).toList())),
            const SizedBox(height:D.lg),
          ],
          SectionHeader(title:S.recentTx),const SizedBox(height:D.md),
          ...s.txs.take(5).map((tx)=>TxTile(tx:tx)),
          const SizedBox(height:D.xxl),
        ]);
      }
      return const SizedBox.shrink();
    }));
}
class _QAct extends StatelessWidget {
  final IconData icon;final String label;final Color color;final VoidCallback onTap;
  const _QAct({required this.icon,required this.label,required this.color,required this.onTap});
  @override Widget build(BuildContext context)=>GestureDetector(onTap:onTap,child:AppCard(padding:const EdgeInsets.symmetric(vertical:16),child:Column(children:[
    Container(width:44,height:44,decoration:BoxDecoration(color:color.withOpacity(0.1),shape:BoxShape.circle),child:Icon(icon,color:color,size:22)),
    const SizedBox(height:8),Text(label,style:TS.cap),
  ])));
}

// ══════════════════════════════════════════════════════════
//  REWARDS SCREEN
// ══════════════════════════════════════════════════════════
class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key});
  @override State<RewardsScreen> createState() => _RewardsState();
}
class _RewardsState extends State<RewardsScreen> {
  @override void initState(){super.initState();context.read<RewardsBloc>().add(RewardsLoadEvent());}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.rewardsTitle),backgroundColor:AppColors.primary,
      leading:Navigator.canPop(context)?IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop()):null),
    body:BlocConsumer<RewardsBloc,RewardsState>(
      listener:(ctx,s){
        if(s is RewardsRedeemed){showDialog(context:ctx,builder:(_)=>AlertDialog(title:const Text('تم الاستبدال 🎉'),content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('كود القسيمة:'),const SizedBox(height:12),Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:AppColors.surfaceAlt,borderRadius:BorderRadius.circular(12)),child:Text(s.code,style:TS.bodyM.copyWith(color:AppColors.accent,letterSpacing:2)))]),actions:[TextButton(onPressed:(){Navigator.pop(ctx);ctx.read<RewardsBloc>().add(RewardsLoadEvent());},child:const Text('تم'))]));}
        if(s is RewardsError) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(s.msg),backgroundColor:AppColors.error));
      },
      builder:(ctx,s){
        if(s is RewardsLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
        if(s is RewardsError) return AppErrorWidget(message:s.msg,onRetry:()=>ctx.read<RewardsBloc>().add(RewardsLoadEvent()));
        if(s is RewardsLoaded){
          final sm=s.summary;
          return ListView(padding:const EdgeInsets.all(D.md),children:[
            Container(padding:const EdgeInsets.all(D.lg),decoration:BoxDecoration(gradient:AppGradients.gold,borderRadius:BorderRadius.circular(20),boxShadow:[BoxShadow(color:AppColors.accent.withOpacity(0.3),blurRadius:20,offset:const Offset(0,6))]),
              child:Column(children:[
                const Icon(Icons.stars_rounded,color:Colors.white,size:48),const SizedBox(height:8),
                Text('${sm.pointsBalance}',style:TS.amount.copyWith(color:Colors.white,fontSize:48)),
                Text(S.myPoints,style:TS.body.copyWith(color:Colors.white70)),const SizedBox(height:16),
                Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),decoration:BoxDecoration(color:Colors.white.withOpacity(0.2),borderRadius:BorderRadius.circular(20)),
                  child:Text(sm.tier=='Gold'?S.gold:sm.tier=='Silver'?S.silver:S.bronze,style:TS.bodyM.copyWith(color:Colors.white))),
              ])),
            const SizedBox(height:D.md),
            if(sm.nextTierPoints>0)AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text(S.nextTier,style:TS.cap),Text('${sm.nextTierPoints} ${S.pts}',style:TS.cap.copyWith(color:AppColors.accent))]),
              const SizedBox(height:12),
              LinearPercentIndicator(percent:sm.progress.clamp(0.0,1.0),lineHeight:10,backgroundColor:AppColors.surfaceAlt,progressColor:AppColors.accent,barRadius:const Radius.circular(5),padding:EdgeInsets.zero),
            ])),
            const SizedBox(height:D.lg),
            SectionHeader(title:S.vouchers),const SizedBox(height:D.md),
            if(s.vouchers.isEmpty)EmptyState(title:S.noVouchers,subtitle:'اكسب المزيد من النقاط',icon:Icons.card_giftcard_outlined)
            else...s.vouchers.map((v)=>Padding(padding:const EdgeInsets.only(bottom:12),child:AppCard(highlighted:v.canRedeem,child:Row(children:[
              Container(width:52,height:52,decoration:BoxDecoration(gradient:AppGradients.gold,borderRadius:BorderRadius.circular(14)),child:Center(child:Text('${v.discountPercent.toInt()}%',style:TS.h3.copyWith(color:Colors.white)))),
              const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(v.code,style:TS.bodyM.copyWith(color:AppColors.accent)),Text('${v.pointsCost} ${S.pts}',style:TS.cap)])),
              ElevatedButton(onPressed:v.canRedeem?()=>ctx.read<RewardsBloc>().add(RewardsRedeemEvent(v.id)):null,
                style:ElevatedButton.styleFrom(minimumSize:Size.zero,padding:const EdgeInsets.symmetric(horizontal:16,vertical:10)),
                child:Text(S.redeemPts,style:TS.cap.copyWith(color:Colors.white))),
            ])))),
            const SizedBox(height:D.lg),
            SectionHeader(title:'سجل النقاط'),const SizedBox(height:D.md),
            ...sm.history.map((h)=>Padding(padding:const EdgeInsets.only(bottom:8),child:AppCard(padding:const EdgeInsets.symmetric(horizontal:D.md,vertical:12),child:Row(children:[
              Container(width:36,height:36,decoration:BoxDecoration(color:h.isEarned?AppColors.successBg:AppColors.errorBg,shape:BoxShape.circle),child:Icon(h.isEarned?Icons.add_rounded:Icons.remove_rounded,color:h.isEarned?AppColors.success:AppColors.error,size:20)),
              const SizedBox(width:12),Expanded(child:Text(h.reason,style:TS.body)),
              Text('${h.isEarned?'+':''}${h.points} ${S.pts}',style:TS.bodyM.copyWith(color:h.isEarned?AppColors.success:AppColors.error)),
            ])))),
            const SizedBox(height:D.xxl),
          ]);
        }
        return const SizedBox.shrink();
      }));
}
