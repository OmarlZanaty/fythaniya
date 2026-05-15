import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

// ══════════════════════════════════════════════════════════
//  PROFILE SCREEN
// ══════════════════════════════════════════════════════════
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override State<ProfileScreen> createState() => _ProfileState();
}
class _ProfileState extends State<ProfileScreen> {
  @override void initState(){super.initState();context.read<ProfileBloc>().add(ProfileLoadEvent());}
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.profileTitle),backgroundColor:AppColors.primary,
      leading:Navigator.canPop(context)?IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop()):null),
    body:BlocBuilder<ProfileBloc,ProfileState>(builder:(ctx,state){
      final user=state is ProfileLoaded?state.user:state is ProfileSaved?state.user:null;
      if(state is ProfileLoading) return const Center(child:CircularProgressIndicator(color:AppColors.primary));
      if(user==null) return AppErrorWidget(message:'خطأ في تحميل الملف',onRetry:()=>ctx.read<ProfileBloc>().add(ProfileLoadEvent()));
      return ListView(padding:const EdgeInsets.all(D.md),children:[
        // Avatar
        Center(child:Column(children:[
          Container(width:88,height:88,decoration:BoxDecoration(color:AppColors.primary,shape:BoxShape.circle,boxShadow:[BoxShadow(color:AppColors.primary.withValues(alpha: 0.3),blurRadius:20,spreadRadius:4)]),
            child:Center(child:Text(user.initials,style:TS.h1.copyWith(color:Colors.white,fontSize:28)))),
          const SizedBox(height:12),Text(user.fullName,style:TS.h2),const SizedBox(height:4),
          Text(user.phone,style:TS.body.copyWith(color:AppColors.textSec)),const SizedBox(height:8),
          Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:6),
            decoration:BoxDecoration(gradient:AppGradients.gold,borderRadius:BorderRadius.circular(20)),
            child:Text(user.tierAr,style:TS.capM.copyWith(color:Colors.white))),
        ])),
        const SizedBox(height:D.lg),
        Row(children:[
          _Stat(label:'الرصيد',value:'${user.walletBalance.toStringAsFixed(0)} ${S.egp}',color:AppColors.primary),
          const SizedBox(width:12),
          _Stat(label:S.myPoints,value:'${user.pointsBalance} ${S.pts}',color:AppColors.accent),
        ]),
        const SizedBox(height:D.lg),
        const _Label('الحساب'),
        _Item(icon:Icons.edit_rounded,label:S.editProfile,onTap:()=>ctx.push(AppRoutes.editProf)),
        _Item(icon:Icons.lock_outline_rounded,label:S.changePass2,onTap:()=>ctx.push(AppRoutes.changePass)),
        _Item(icon:Icons.notifications_outlined,label:S.notifTitle,onTap:()=>ctx.push(AppRoutes.notifs)),
        _Item(icon:Icons.stars_rounded,label:S.rewardsTitle,onTap:()=>ctx.push(AppRoutes.rewards),color:AppColors.accent),
        if(user.isB2B)_Item(icon:Icons.business_rounded,label:S.b2bTitle,onTap:()=>ctx.push(AppRoutes.b2bDash),color:AppColors.b2b),
        if(!user.isB2B)_Item(icon:Icons.business_rounded,label:'التقديم على حساب B2B',onTap:()=>ctx.push(AppRoutes.b2bApply),color:AppColors.b2b),
        const SizedBox(height:D.md),const _Label('الدعم والمعلومات'),
        _Item(icon:Icons.support_agent_rounded,label:S.support,onTap:()=>_showInfoSheet(ctx, S.support, 'تواصل معنا: support@fythaniya.com\nالهاتف: 19999')),
        _Item(icon:Icons.description_outlined,label:S.terms,onTap:()=>_showInfoSheet(ctx, S.terms, 'تطبق الشروط والأحكام الموضحة في الموقع الإلكتروني. باستخدامك للتطبيق فإنك توافق على هذه الشروط.')),
        _Item(icon:Icons.privacy_tip_outlined,label:S.privacy,onTap:()=>_showInfoSheet(ctx, S.privacy, 'نحن نحترم خصوصيتك. يتم تشفير بياناتك ولا يتم مشاركتها مع أي طرف ثالث بدون موافقتك.')),
        const _Item(icon:Icons.info_outline_rounded,label:S.appVersion,trailing:Text('2.0.0',style:TS.cap),onTap:null),
        const SizedBox(height:D.md),
        AppCard(color:AppColors.errorBg,child:ListTile(
          leading:const Icon(Icons.logout_rounded,color:AppColors.error),
          title:Text(S.logout,style:TS.bodyM.copyWith(color:AppColors.error)),
          onTap:()=>showDialog(context:ctx,builder:(_)=>AlertDialog(
            title:const Text('تأكيد الخروج'),content:const Text(S.logoutConfirm),
            actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text(S.cancel)),
              TextButton(onPressed:(){Navigator.pop(ctx);ctx.read<AuthBloc>().add(AuthLogoutEvent());},child:const Text(S.logout,style:TextStyle(color:AppColors.error))),
            ])))),
        const SizedBox(height:D.xxl),
      ]);
    }));
}
class _Stat extends StatelessWidget {
  final String label,value;final Color color;
  const _Stat({required this.label,required this.value,required this.color});
  @override Widget build(BuildContext context)=>Expanded(child:AppCard(child:Column(children:[Text(label,style:TS.cap),const SizedBox(height:4),Text(value,style:TS.bodyM.copyWith(color:color))])));
}
class _Label extends StatelessWidget {
  final String text;const _Label(this.text);
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:8,horizontal:4),child:Text(text.toUpperCase(),style:TS.cap.copyWith(color:AppColors.textMuted,letterSpacing:1.2,fontSize:10)));
}
class _Item extends StatelessWidget {
  final IconData icon;final String label;final VoidCallback? onTap;final Color? color;final Widget? trailing;
  const _Item({required this.icon,required this.label,this.onTap,this.color,this.trailing});
  @override Widget build(BuildContext context)=>Container(margin:const EdgeInsets.only(bottom:4),
    decoration:BoxDecoration(color:AppColors.card,borderRadius:BorderRadius.circular(14),border:Border.all(color:AppColors.border,width:0.8)),
    child:ListTile(leading:Icon(icon,color:color??AppColors.textSec,size:22),title:Text(label,style:TS.body),
      trailing:trailing??(onTap!=null?const Icon(Icons.arrow_forward_ios_rounded,size:14,color:AppColors.textMuted):null),onTap:onTap));
}

// ══════════════════════════════════════════════════════════
//  EDIT PROFILE
// ══════════════════════════════════════════════════════════
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override State<EditProfileScreen> createState() => _EditProfileState();
}
class _EditProfileState extends State<EditProfileScreen> {
  final _form=GlobalKey<FormState>(); final _name=TextEditingController(); final _email=TextEditingController();
  bool _init=false;
  void _prefill(ProfileState s){if(_init)return;final u=s is ProfileLoaded?s.user:s is ProfileSaved?s.user:null;if(u==null)return;_name.text=u.fullName;_email.text=u.email??'';_init=true;}
  @override void initState(){super.initState();if(context.read<ProfileBloc>().state is!ProfileLoaded)context.read<ProfileBloc>().add(ProfileLoadEvent());}
  @override void dispose(){_name.dispose();_email.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.editProfile),backgroundColor:AppColors.primary,leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop())),
    body:BlocConsumer<ProfileBloc,ProfileState>(
      listener:(ctx,s){_prefill(s);if(s is ProfileSaved){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('تم الحفظ')));ctx.pop();}if(s is ProfileError)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(s.msg),backgroundColor:AppColors.error));},
      builder:(ctx,s){_prefill(s);final saving=s is ProfileSaving;
        return SingleChildScrollView(padding:const EdgeInsets.all(D.xl),child:Form(key:_form,child:Column(children:[
          AppField(label:S.fullName,ctrl:_name,validator:(v)=>(v?.trim().isEmpty??true)?S.required:null,prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.person_outline_rounded,size:20))),
          const SizedBox(height:D.md),
          AppField(label:S.email,ctrl:_email,kb:TextInputType.emailAddress,prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.email_outlined,size:20))),
          const SizedBox(height:D.xl),
          AppButton(label:S.save,isLoading:saving,onPressed:(){if(_form.currentState!.validate())ctx.read<ProfileBloc>().add(ProfileUpdateEvent(_name.text.trim(),_email.text.trim().isEmpty?null:_email.text.trim()));})
        ])));
      }));
}

// ══════════════════════════════════════════════════════════
//  CHANGE PASSWORD
// ══════════════════════════════════════════════════════════
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override State<ChangePasswordScreen> createState()=>_ChangePassState();
}
class _ChangePassState extends State<ChangePasswordScreen> {
  final _form=GlobalKey<FormState>(); final _cur=TextEditingController(); final _nw=TextEditingController(); final _conf=TextEditingController();
  @override void dispose(){_cur.dispose();_nw.dispose();_conf.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text(S.changePass2),backgroundColor:AppColors.primary,leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>context.pop())),
    body:BlocConsumer<ProfileBloc,ProfileState>(
      listener:(ctx,s){if(s is ProfileSaved){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('تم تغيير كلمة المرور')));ctx.pop();}if(s is ProfileError)ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(s.msg),backgroundColor:AppColors.error));},
      builder:(ctx,s)=>SingleChildScrollView(padding:const EdgeInsets.all(D.xl),child:Form(key:_form,child:Column(children:[
        AppField(label:S.currentPass,ctrl:_cur,obscure:true,validator:(v)=>(v?.isEmpty??true)?S.required:null,prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.lock_outline_rounded,size:20))),
        const SizedBox(height:D.md),
        AppField(label:S.newPassword,ctrl:_nw,obscure:true,validator:(v)=>(v?.length??0)<6?S.invalidPass:null,prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.lock_reset_rounded,size:20))),
        const SizedBox(height:D.md),
        AppField(label:S.confirmPass,ctrl:_conf,obscure:true,validator:(v)=>v!=_nw.text?S.passMismatch:null,prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.lock_outline_rounded,size:20))),
        const SizedBox(height:D.xl),
        AppButton(label:S.save,isLoading:s is ProfileSaving,onPressed:(){if(_form.currentState!.validate())ctx.read<ProfileBloc>().add(ProfileChangePassEvent(_cur.text,_nw.text));})
      ])))));
}

void _showInfoSheet(BuildContext ctx, String title, String body) {
  showModalBottomSheet(
    context: ctx,
    isScrollControlled: true,
    builder: (_) => Padding(
      padding: EdgeInsets.only(left: D.lg, right: D.lg, top: D.lg, bottom: MediaQuery.of(ctx).viewInsets.bottom + D.lg),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TS.h3),
        const SizedBox(height: D.md),
        Text(body, style: TS.body, textAlign: TextAlign.right),
        const SizedBox(height: D.lg),
        AppButton(label: S.done, onPressed: () => Navigator.pop(ctx)),
      ]),
    ),
  );
}
