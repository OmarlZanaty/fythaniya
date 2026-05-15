import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';

// ── App Button ─────────────────────────────────────────────
class AppButton extends StatelessWidget {
  final String label; final VoidCallback? onPressed;
  final bool isLoading, isOutlined; final IconData? icon;
  final Color? color; final double? height;
  const AppButton({super.key,required this.label,this.onPressed,this.isLoading=false,this.isOutlined=false,this.icon,this.color,this.height});

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2.5,color:Colors.white))
        : Row(mainAxisAlignment:MainAxisAlignment.center,mainAxisSize:MainAxisSize.min,children:[
            if(icon!=null)...[Icon(icon,size:18,color:Colors.white),const SizedBox(width:8)],
            Text(label,style:TS.btn),
          ]);
    if(isOutlined) return SizedBox(height:height??D.btnH,width:double.infinity,child:OutlinedButton(onPressed:isLoading?null:onPressed,child:child));
    return SizedBox(height:height??D.btnH,width:double.infinity,
      child:ElevatedButton(onPressed:isLoading?null:onPressed,
        style:ElevatedButton.styleFrom(backgroundColor:color??AppColors.primary),child:child));
  }
}

// ── App Text Field ──────────────────────────────────────────
class AppField extends StatefulWidget {
  final String label; final String? hint; final TextEditingController? ctrl;
  final bool obscure; final TextInputType? kb; final String? Function(String?)? validator;
  final Widget? prefix; final List<TextInputFormatter>? formatters;
  final TextInputAction? action; final ValueChanged<String>? onChange;
  final bool readOnly; final VoidCallback? onTap; final int? maxLines;
  const AppField({super.key,required this.label,this.hint,this.ctrl,this.obscure=false,this.kb,this.validator,this.prefix,this.formatters,this.action,this.onChange,this.readOnly=false,this.onTap,this.maxLines=1});
  @override State<AppField> createState() => _AppFieldState();
}
class _AppFieldState extends State<AppField> {
  late bool _obs; @override void initState() { super.initState(); _obs=widget.obscure; }
  @override Widget build(BuildContext context) => TextFormField(
    controller:widget.ctrl, obscureText:_obs, keyboardType:widget.kb,
    validator:widget.validator, inputFormatters:widget.formatters,
    textInputAction:widget.action, onChanged:widget.onChange,
    readOnly:widget.readOnly, onTap:widget.onTap, maxLines:widget.maxLines,
    textAlign:TextAlign.right, textDirection:TextDirection.rtl,
    style:TS.body.copyWith(color:AppColors.text),
    decoration:InputDecoration(labelText:widget.label, hintText:widget.hint, prefixIcon:widget.prefix,
      suffixIcon:widget.obscure?IconButton(icon:Icon(_obs?Icons.visibility_off_outlined:Icons.visibility_outlined,size:20,color:AppColors.textMuted),onPressed:()=>setState(()=>_obs=!_obs)):null));
}

// ── App Card ───────────────────────────────────────────────
class AppCard extends StatelessWidget {
  final Widget child; final EdgeInsetsGeometry? padding; final VoidCallback? onTap;
  final Color? color; final bool highlighted; final double? radius;
  const AppCard({super.key,required this.child,this.padding,this.onTap,this.color,this.highlighted=false,this.radius});
  @override
  Widget build(BuildContext context) => GestureDetector(onTap:onTap,child:Container(
    padding:padding??const EdgeInsets.all(D.md),
    decoration:BoxDecoration(
      color:color??AppColors.card,
      borderRadius:BorderRadius.circular(radius??D.cardR),
      border:Border.all(color:highlighted?AppColors.primary:AppColors.border,width:highlighted?1.5:0.8),
      boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.04),blurRadius:8,offset:const Offset(0,2))]),
    child:child));
}

// ── Section Header ─────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title; final String? action; final VoidCallback? onAction;
  const SectionHeader({super.key,required this.title,this.action,this.onAction});
  @override Widget build(BuildContext context) => Padding(padding:const EdgeInsets.symmetric(horizontal:D.md),
    child:Row(children:[
      Container(width:3,height:16,decoration:BoxDecoration(color:AppColors.primary,borderRadius:BorderRadius.circular(2))),
      const SizedBox(width:8),
      Expanded(child:Text(title,style:TS.h3)),
      if(action!=null)GestureDetector(onTap:onAction,child:Container(
        padding:const EdgeInsets.symmetric(horizontal:12,vertical:4),
        decoration:BoxDecoration(color:AppColors.infoBg,borderRadius:BorderRadius.circular(20)),
        child:Text(action!,style:TS.cap.copyWith(color:AppColors.primary,fontWeight:FontWeight.w600)))),
    ]));
}

// ── Status Badge ───────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String status; final bool small;
  const StatusBadge({super.key,required this.status,this.small=false});
  @override Widget build(BuildContext context) {
    Color bg,fg; String label;
    switch(status) {
      case 'SUCCESS':case 'COMPLETED':  bg=AppColors.successBg;fg=AppColors.success;label='مكتمل';break;
      case 'PENDING':case 'IN_PROGRESS':case 'ASSIGNED': bg=AppColors.warningBg;fg=AppColors.warning;label='جارٍ';break;
      case 'FAILED':  bg=AppColors.errorBg;fg=AppColors.error;label='فشل';break;
      case 'REFUNDED':bg=AppColors.infoBg;fg=AppColors.info;label='مسترد';break;
      case 'ACTIVE':  bg=AppColors.successBg;fg=AppColors.success;label='نشط';break;
      case 'OVERDUE': bg=AppColors.errorBg;fg=AppColors.error;label='متأخرة';break;
      case 'SETTLED': bg=AppColors.infoBg;fg=AppColors.info;label='مسددة';break;
      case 'PENDING_APPROVAL':bg=AppColors.warningBg;fg=AppColors.warning;label='قيد المراجعة';break;
      case 'REJECTED':bg=AppColors.errorBg;fg=AppColors.error;label='مرفوض';break;
      default: bg=AppColors.surfaceAlt;fg=AppColors.textSec;label=kStatusNames[status]??status;
    }
    return Container(
      padding:EdgeInsets.symmetric(horizontal:small?8:12,vertical:small?3:5),
      decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(20)),
      child:Text(label,style:TS.cap.copyWith(color:fg,fontWeight:FontWeight.w700,fontSize:small?10:11)));
  }
}

// ── Category Icon ──────────────────────────────────────────
class CategoryIcon extends StatelessWidget {
  final String category; final double size;
  const CategoryIcon({super.key,required this.category,this.size=22});
  @override Widget build(BuildContext context) {
    final (icon,color)=_resolve(category);
    return Container(width:48,height:48,
      decoration:BoxDecoration(color:color.withOpacity(0.1),borderRadius:BorderRadius.circular(12),border:Border.all(color:color.withOpacity(0.2))),
      child:Icon(icon,color:color,size:size));
  }
  (IconData,Color) _resolve(String c){switch(c){case 'TELECOM':return(Icons.smartphone_rounded,AppColors.telecom);case 'ELECTRICITY':return(Icons.bolt_rounded,AppColors.electricity);case 'GAS':return(Icons.local_fire_department_rounded,AppColors.gas);case 'WATER':return(Icons.water_drop_rounded,AppColors.water);case 'INTERNET':return(Icons.wifi_rounded,AppColors.internet);case 'INSURANCE':return(Icons.shield_rounded,AppColors.insurance);case 'GOVERNMENT':return(Icons.account_balance_rounded,AppColors.government);default:return(Icons.receipt_long_rounded,AppColors.textMuted);}}
}

// ── Transaction Tile ───────────────────────────────────────
class TxTile extends StatelessWidget {
  final TransactionModel tx; final VoidCallback? onTap;
  const TxTile({super.key,required this.tx,this.onTap});
  @override Widget build(BuildContext context) {
    final cat=tx.request?.serviceProvider?.category??'TELECOM';
    final amtClr=tx.isSuccess?AppColors.success:tx.isFailed?AppColors.error:AppColors.warning;
    return GestureDetector(onTap:onTap,child:Container(
      padding:const EdgeInsets.symmetric(horizontal:D.md,vertical:14),
      decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:AppColors.divider,width:0.8))),
      child:Row(children:[
        CategoryIcon(category:cat),
        const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(tx.request?.subService?.nameAr??kTypeNames[tx.request?.type??'']??'معاملة',style:TS.bodyM,maxLines:1,overflow:TextOverflow.ellipsis),
          const SizedBox(height:2),
          Text(_ago(tx.createdAt),style:TS.cap),
        ])),
        Column(crossAxisAlignment:CrossAxisAlignment.end,children:[
          Text('${tx.amount.toStringAsFixed(0)} ${S.egp}',style:TS.bodyM.copyWith(color:amtClr)),
          const SizedBox(height:2),
          StatusBadge(status:tx.status,small:true),
        ]),
      ])));
  }
  String _ago(DateTime dt){final d=DateTime.now().difference(dt);if(d.inMinutes<60)return'منذ ${d.inMinutes} دق';if(d.inHours<24)return'منذ ${d.inHours} ساعة';if(d.inDays==1)return'أمس';return'${dt.day}/${dt.month}/${dt.year}';}
}

// ── Shimmer ────────────────────────────────────────────────
class Shimmer extends StatefulWidget {
  final double width,height; final double radius;
  const Shimmer({super.key,required this.width,required this.height,this.radius=8});
  @override State<Shimmer> createState()=>_ShimmerState();
}
class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _c; late Animation<double> _a;
  @override void initState(){super.initState();_c=AnimationController(vsync:this,duration:const Duration(milliseconds:1400))..repeat();_a=Tween<double>(begin:-2,end:2).animate(CurvedAnimation(parent:_c,curve:Curves.easeInOut));}
  @override void dispose(){_c.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:_a,builder:(_,__)=>Container(width:widget.width,height:widget.height,decoration:BoxDecoration(borderRadius:BorderRadius.circular(widget.radius),gradient:LinearGradient(begin:Alignment(_a.value-1,0),end:Alignment(_a.value+1,0),colors:const[AppColors.surfaceAlt,Color(0xFFCBECFD),AppColors.surfaceAlt]))));
}

// ── Empty State ────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final String title; final String? subtitle; final IconData icon; final String? action; final VoidCallback? onAction;
  const EmptyState({super.key,required this.title,this.subtitle,this.icon=Icons.inbox_outlined,this.action,this.onAction});
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(D.xl),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:80,height:80,decoration:BoxDecoration(color:AppColors.surfaceAlt,shape:BoxShape.circle,border:Border.all(color:AppColors.border)),child:Icon(icon,size:36,color:AppColors.textMuted)),
    const SizedBox(height:D.lg),Text(title,style:TS.h3,textAlign:TextAlign.center),
    if(subtitle!=null)...[const SizedBox(height:D.sm),Text(subtitle!,style:TS.body.copyWith(color:AppColors.textSec),textAlign:TextAlign.center)],
    if(action!=null)...[const SizedBox(height:D.lg),SizedBox(width:180,child:AppButton(label:action!,onPressed:onAction,isOutlined:true))],
  ])));
}

// ── App Error ──────────────────────────────────────────────
class AppErrorWidget extends StatelessWidget {
  final String message; final VoidCallback? onRetry;
  const AppErrorWidget({super.key,required this.message,this.onRetry});
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(D.xl),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:64,height:64,decoration:const BoxDecoration(color:AppColors.errorBg,shape:BoxShape.circle),child:const Icon(Icons.error_outline_rounded,color:AppColors.error,size:32)),
    const SizedBox(height:D.md),Text(message,style:TS.body.copyWith(color:AppColors.textSec),textAlign:TextAlign.center),
    if(onRetry!=null)...[const SizedBox(height:D.lg),SizedBox(width:160,child:AppButton(label:S.retry,onPressed:onRetry))],
  ])));
}

// ── Amount Picker ──────────────────────────────────────────
class AmountPicker extends StatelessWidget {
  final TextEditingController ctrl; final String? Function(String?)? validator;
  final List<int> quickAmounts;
  const AmountPicker({super.key,required this.ctrl,this.validator,this.quickAmounts=const[10,20,50,100,200,500]});
  @override Widget build(BuildContext context)=>AppCard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text(S.amount,style:TS.cap),const SizedBox(height:D.sm),
    TextFormField(controller:ctrl,keyboardType:const TextInputType.numberWithOptions(decimal:true),validator:validator,
      inputFormatters:[FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))],textAlign:TextAlign.right,
      style:TS.body.copyWith(color:AppColors.text),
      decoration:InputDecoration(labelText:'أدخل المبلغ',prefixIcon:Padding(padding:const EdgeInsets.all(14),child:Text(S.egp,style:TS.bodyM.copyWith(color:AppColors.primary))))),
    const SizedBox(height:D.md),Text(S.quickAmounts,style:TS.cap),const SizedBox(height:D.sm),
    Wrap(spacing:8,runSpacing:8,children:quickAmounts.map((a)=>GestureDetector(
      onTap:()=>ctrl.text=a.toString(),
      child:Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:8),
        decoration:BoxDecoration(color:AppColors.surfaceAlt,borderRadius:BorderRadius.circular(20),border:Border.all(color:AppColors.border)),
        child:Text('$a ${S.egp}',style:TS.cap.copyWith(color:AppColors.primary,fontWeight:FontWeight.w600))))).toList()),
  ]));
}

// ── Success Sheet ──────────────────────────────────────────
class SuccessSheet extends StatelessWidget {
  final String title,subtitle; final String? ref; final VoidCallback onDone;
  const SuccessSheet({super.key,required this.title,required this.subtitle,this.ref,required this.onDone});
  @override Widget build(BuildContext context)=>Padding(
    padding:EdgeInsets.only(left:D.xl,right:D.xl,top:D.lg,bottom:MediaQuery.of(context).viewInsets.bottom+D.xl),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      Container(width:80,height:80,decoration:const BoxDecoration(color:AppColors.successBg,shape:BoxShape.circle),child:const Icon(Icons.check_circle_rounded,color:AppColors.success,size:48)),
      const SizedBox(height:D.lg),Text(title,style:TS.h2,textAlign:TextAlign.center),
      const SizedBox(height:D.sm),Text(subtitle,style:TS.body.copyWith(color:AppColors.textSec),textAlign:TextAlign.center),
      if(ref!=null)...[const SizedBox(height:D.md),AppCard(color:AppColors.surfaceAlt,child:Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text('المرجع: ',style:TS.cap),Text(ref!,style:TS.bodyM.copyWith(color:AppColors.primary))])),],
      const SizedBox(height:D.xl),AppButton(label:S.done,onPressed:onDone),
    ]));
}

// ── Provider Selector ──────────────────────────────────────
class ProviderSelector extends StatelessWidget {
  final List<ServiceProviderModel> providers;
  final ServiceProviderModel? selected;
  final ValueChanged<ServiceProviderModel> onSelect;
  const ProviderSelector({super.key,required this.providers,this.selected,required this.onSelect});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Padding(padding:const EdgeInsets.only(bottom:D.sm),child:Text(S.selectProv,style:TS.cap)),
    SizedBox(height:90,child:ListView.builder(scrollDirection:Axis.horizontal,itemCount:providers.length,itemBuilder:(_,i){
      final p=providers[i];final isSel=selected?.id==p.id;
      return GestureDetector(onTap:()=>onSelect(p),child:AnimatedContainer(duration:const Duration(milliseconds:180),
        width:80,margin:const EdgeInsets.only(right:10),
        decoration:BoxDecoration(color:isSel?AppColors.infoBg:AppColors.card,borderRadius:BorderRadius.circular(D.r12),border:Border.all(color:isSel?AppColors.primary:AppColors.border,width:isSel?1.5:1)),
        child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          CategoryIcon(category:p.category,size:18),const SizedBox(height:6),
          Text(p.displayName,style:TS.cap.copyWith(color:isSel?AppColors.primary:AppColors.textSec),textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis),
        ])));
    })),
  ]);
}

// ── Sub Service Selector ───────────────────────────────────
class SubServiceSelector extends StatelessWidget {
  final List<SubServiceModel> subServices;
  final SubServiceModel? selected;
  final ValueChanged<SubServiceModel> onSelect;
  const SubServiceSelector({super.key,required this.subServices,this.selected,required this.onSelect});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('نوع الخدمة',style:TS.cap),const SizedBox(height:D.sm),
    SingleChildScrollView(scrollDirection:Axis.horizontal,child:Row(children:subServices.map((s){
      final isSel=selected?.id==s.id;
      return GestureDetector(onTap:()=>onSelect(s),child:AnimatedContainer(duration:const Duration(milliseconds:150),
        margin:const EdgeInsets.only(left:8),padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),
        decoration:BoxDecoration(color:isSel?AppColors.primary:AppColors.card,borderRadius:BorderRadius.circular(20),border:Border.all(color:isSel?AppColors.primary:AppColors.border)),
        child:Text(s.nameAr,style:TS.cap.copyWith(color:isSel?Colors.white:AppColors.textSec,fontWeight:FontWeight.w600))));
    }).toList())),
  ]);
}

// ── Summary Row ────────────────────────────────────────────
class SummaryRow extends StatelessWidget {
  final String label,value; final Color? valueColor; final bool bold;
  const SummaryRow({super.key,required this.label,required this.value,this.valueColor,this.bold=false});
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
      Text(label,style:TS.body.copyWith(color:AppColors.textSec)),
      Text(value,style:bold?TS.h3.copyWith(color:valueColor??AppColors.text):TS.bodyM.copyWith(color:valueColor??AppColors.text)),
    ]));
}

// ── Wallet Card ────────────────────────────────────────────
class WalletCard extends StatelessWidget {
  final double balance; final int points; final String tierAr; final VoidCallback? onTopUp;
  const WalletCard({super.key,required this.balance,required this.points,required this.tierAr,this.onTopUp});
  @override Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.symmetric(horizontal:D.md),padding:const EdgeInsets.all(D.lg),
    decoration:BoxDecoration(gradient:AppGradients.wallet,borderRadius:BorderRadius.circular(20),
      boxShadow:[BoxShadow(color:AppColors.primary.withOpacity(0.3),blurRadius:20,offset:const Offset(0,6))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
        Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(S.walletBal,style:TS.cap.copyWith(color:Colors.white70)),const SizedBox(height:4),
          Row(crossAxisAlignment:CrossAxisAlignment.end,children:[
            Text(balance.toStringAsFixed(2),style:TS.amount.copyWith(color:Colors.white)),
            const SizedBox(width:6),Padding(padding:const EdgeInsets.only(bottom:4),child:Text(S.egp,style:TS.h3.copyWith(color:Colors.white70))),
          ]),
        ]),
        Container(padding:const EdgeInsets.symmetric(horizontal:14,vertical:6),
          decoration:BoxDecoration(gradient:AppGradients.gold,borderRadius:BorderRadius.circular(20)),
          child:Text(tierAr,style:TS.capM.copyWith(color:Colors.white))),
      ]),
      const SizedBox(height:D.md),
      Row(children:[
        const Icon(Icons.stars_rounded,color:Colors.white70,size:18),const SizedBox(width:6),
        Text('$points ${S.pts}',style:TS.bodyM.copyWith(color:Colors.white70)),const Spacer(),
        if(onTopUp!=null)GestureDetector(onTap:onTopUp,child:Container(
          padding:const EdgeInsets.symmetric(horizontal:14,vertical:7),
          decoration:BoxDecoration(color:Colors.white.withOpacity(0.2),borderRadius:BorderRadius.circular(20)),
          child:Row(children:[const Icon(Icons.add_rounded,color:Colors.white,size:16),const SizedBox(width:4),Text(S.topUp,style:TS.cap.copyWith(color:Colors.white,fontWeight:FontWeight.w600))]))),
      ]),
    ]));
}

// ── B2B Status Card ────────────────────────────────────────
class B2BStatusCard extends StatelessWidget {
  final B2BAccountModel account;
  const B2BStatusCard({super.key,required this.account});
  @override Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.symmetric(horizontal:D.md),padding:const EdgeInsets.all(D.lg),
    decoration:BoxDecoration(gradient:AppGradients.b2b,borderRadius:BorderRadius.circular(20),
      boxShadow:[BoxShadow(color:AppColors.b2b.withOpacity(0.3),blurRadius:20,offset:const Offset(0,6))]),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[
        const Icon(Icons.business_rounded,color:Colors.white,size:24),const SizedBox(width:12),
        Expanded(child:Text(account.companyName,style:TS.h3.copyWith(color:Colors.white),maxLines:1,overflow:TextOverflow.ellipsis)),
        StatusBadge(status:account.payLaterStatus),
      ]),
      const SizedBox(height:D.md),
      Row(children:[
        Expanded(child:_CreditStat(label:'الحد الائتماني',value:'${account.creditLimit.toStringAsFixed(0)} ${S.egp}')),
        const SizedBox(width:12),
        Expanded(child:_CreditStat(label:'المتاح',value:'${account.availableCredit.toStringAsFixed(0)} ${S.egp}',highlight:true)),
      ]),
      const SizedBox(height:D.md),
      ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(
        value:account.usagePercent,
        backgroundColor:Colors.white.withOpacity(0.2),
        valueColor:AlwaysStoppedAnimation(account.usagePercent>0.8?Colors.orange:Colors.white),
        minHeight:6)),
      const SizedBox(height:4),
      Text('${(account.usagePercent*100).toStringAsFixed(0)}% مستخدم',style:TS.cap.copyWith(color:Colors.white70)),
    ]));
}
class _CreditStat extends StatelessWidget {
  final String label,value; final bool highlight;
  const _CreditStat({required this.label,required this.value,this.highlight=false});
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(12),
    decoration:BoxDecoration(color:Colors.white.withOpacity(0.15),borderRadius:BorderRadius.circular(12)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(label,style:TS.cap.copyWith(color:Colors.white70)),const SizedBox(height:4),
      Text(value,style:TS.bodyM.copyWith(color:highlight?AppColors.accentLight:Colors.white)),
    ]));
}
