import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';

// ── Shared scaffold ────────────────────────────────────────
Widget _authScaffold({required Widget child}) => Scaffold(
  backgroundColor: AppColors.primary,
  body: Column(children:[
    SizedBox(height: MediaQuery.of(GlobalKey<NavigatorState>().currentContext!).padding.top + 40),
    Center(child: SizedBox(height:64, child: Image.asset('assets/images/logo.png', fit: BoxFit.contain))),
    const SizedBox(height:8),
    Expanded(child:Container(
      decoration:const BoxDecoration(color:AppColors.bg,borderRadius:BorderRadius.vertical(top:Radius.circular(28))),
      child:child)),
  ]));

class _AuthBase extends StatelessWidget {
  final Widget child;
  const _AuthBase({required this.child});
  @override Widget build(BuildContext context) => Scaffold(
    body: Container(decoration: const BoxDecoration(gradient: AppGradients.hero),
      child: SafeArea(child:Column(children:[
        Padding(padding:const EdgeInsets.symmetric(vertical:28),child:Column(children:[
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: AppColors.primaryLight.withOpacity(0.4), blurRadius: 30, spreadRadius: 4)]),
            padding: const EdgeInsets.all(10),
            child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset('assets/images/logo.png', fit: BoxFit.contain)),
          ),
          const SizedBox(height:12),
          Text(AppConstants.appName,style:TS.h2.copyWith(color:Colors.white, letterSpacing: 0.5)),
        ])),
        Expanded(child:Container(
          decoration:const BoxDecoration(color:AppColors.bg,borderRadius:BorderRadius.vertical(top:Radius.circular(32))),
          child:SingleChildScrollView(padding:const EdgeInsets.all(D.xl),child:child))),
      ]))));
}

void _showErr(BuildContext ctx, String msg) =>
  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(msg),backgroundColor:AppColors.error));

String? _phoneVal(String? v) {
  if (v==null||v.trim().isEmpty) return S.required;
  final c=v.trim().replaceAll('+','');
  if(c.length<7||c.length>15) return S.invalidPhone;
  return null;
}

// ══════════════════════════════════════════════════════════
//  LOGIN
// ══════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override State<LoginScreen> createState() => _LoginScreenState();
}
class _LoginScreenState extends State<LoginScreen> {
  final _form=GlobalKey<FormState>(); final _phone=TextEditingController(); final _pass=TextEditingController();
  @override void dispose(){_phone.dispose();_pass.dispose();super.dispose();}
  @override Widget build(BuildContext context) => _AuthBase(child:BlocConsumer<AuthBloc,AuthState>(
    listener:(ctx,s){if(s is AuthAuthenticated){ctx.go(AppRoutes.home);return;}if(s is AuthError)_showErr(ctx,s.msg);},
    builder:(ctx,s){
      final loading=s is AuthLoading;
      return Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const SizedBox(height:D.sm),
        Text(S.login,style:TS.h1),const SizedBox(height:6),
        Text('أدخل بياناتك للدخول',style:TS.body.copyWith(color:AppColors.textSec)),const SizedBox(height:D.xl),
        AppField(label:S.phone,hint:S.phonePlch,ctrl:_phone,kb:TextInputType.phone,validator:_phoneVal,
          formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],action:TextInputAction.next,
          prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.phone_android_rounded,size:20))),
        const SizedBox(height:D.md),
        AppField(label:S.password,ctrl:_pass,obscure:true,action:TextInputAction.done,
          validator:(v)=>(v?.length??0)<6?S.invalidPass:null,
          prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.lock_outline_rounded,size:20))),
        const SizedBox(height:D.sm),
        Align(alignment:Alignment.centerLeft,child:TextButton(onPressed:()=>ctx.push(AppRoutes.forgot),child:Text(S.forgotPass,style:TS.body.copyWith(color:AppColors.primary)))),
        const SizedBox(height:D.lg),
        AppButton(label:S.login,isLoading:loading,onPressed:(){if(_form.currentState!.validate())ctx.read<AuthBloc>().add(AuthLoginEvent(_phone.text.trim(),_pass.text));}),
        const SizedBox(height:D.lg),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text(S.noAccount,style:TS.body.copyWith(color:AppColors.textSec)),const SizedBox(width:6),
          GestureDetector(onTap:()=>ctx.push(AppRoutes.register),child:Text(S.signupNow,style:TS.bodyM.copyWith(color:AppColors.primary))),
        ]),
      ]));
    }));
}

// ══════════════════════════════════════════════════════════
//  REGISTER
// ══════════════════════════════════════════════════════════
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override State<RegisterScreen> createState() => _RegisterScreenState();
}
class _RegisterScreenState extends State<RegisterScreen> {
  final _form=GlobalKey<FormState>(); final _name=TextEditingController(); final _phone=TextEditingController(); final _pass=TextEditingController(); final _conf=TextEditingController();
  @override void dispose(){_name.dispose();_phone.dispose();_pass.dispose();_conf.dispose();super.dispose();}
  @override Widget build(BuildContext context) => _AuthBase(child:BlocConsumer<AuthBloc,AuthState>(
    listener:(ctx,s){if(s is AuthAuthenticated){ctx.go(AppRoutes.home);return;}if(s is AuthError)_showErr(ctx,s.msg);},
    builder:(ctx,s){
      final loading=s is AuthLoading;
      return Form(key:_form,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        IconButton(onPressed:()=>ctx.pop(),icon:const Icon(Icons.arrow_back_ios_new_rounded,size:20),padding:EdgeInsets.zero),
        const SizedBox(height:D.sm),Text(S.register,style:TS.h1),const SizedBox(height:6),
        Text('أنشئ حسابك وابدأ فوراً',style:TS.body.copyWith(color:AppColors.textSec)),const SizedBox(height:D.xl),
        AppField(label:S.fullName,ctrl:_name,action:TextInputAction.next,validator:(v)=>(v?.trim().isEmpty??true)?S.required:null,
          prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.person_outline_rounded,size:20))),
        const SizedBox(height:D.md),
        AppField(label:S.phone,hint:S.phonePlch,ctrl:_phone,kb:TextInputType.phone,action:TextInputAction.next,validator:_phoneVal,
          formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
          prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.phone_android_rounded,size:20))),
        const SizedBox(height:D.md),
        AppField(label:S.password,ctrl:_pass,obscure:true,action:TextInputAction.next,validator:(v)=>(v?.length??0)<6?S.invalidPass:null,
          prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.lock_outline_rounded,size:20))),
        const SizedBox(height:D.md),
        AppField(label:S.confirmPass,ctrl:_conf,obscure:true,action:TextInputAction.done,validator:(v)=>v!=_pass.text?S.passMismatch:null,
          prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.lock_outline_rounded,size:20))),
        const SizedBox(height:D.xl),
        AppButton(label:'إنشاء الحساب',isLoading:loading,onPressed:(){if(_form.currentState!.validate())ctx.read<AuthBloc>().add(AuthRegisterEvent(_phone.text.trim(),_name.text.trim(),_pass.text));}),
        const SizedBox(height:D.lg),
        Row(mainAxisAlignment:MainAxisAlignment.center,children:[
          Text(S.hasAccount,style:TS.body.copyWith(color:AppColors.textSec)),const SizedBox(width:6),
          GestureDetector(onTap:()=>ctx.pop(),child:Text(S.loginNow,style:TS.bodyM.copyWith(color:AppColors.primary))),
        ]),
      ]));
    }));
}

// ══════════════════════════════════════════════════════════
//  FORGOT PASSWORD
// ══════════════════════════════════════════════════════════
class ForgotScreen extends StatefulWidget {
  const ForgotScreen({super.key});
  @override State<ForgotScreen> createState() => _ForgotScreenState();
}
class _ForgotScreenState extends State<ForgotScreen> {
  final _form=GlobalKey<FormState>(); final _phone=TextEditingController();
  @override void dispose(){_phone.dispose();super.dispose();}
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor:AppColors.bg,
    appBar:AppBar(title:const Text('استعادة كلمة المرور'),backgroundColor:AppColors.primary),
    body:BlocConsumer<AuthBloc,AuthState>(
      listener:(ctx,s){
        if(s is AuthOtpSent){ ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('تم إرسال رمز التحقق'))); ctx.pop(); return; }
        if(s is AuthError)_showErr(ctx,s.msg);
      },
      builder:(ctx,s){
        final loading=s is AuthLoading;
        return Padding(padding:const EdgeInsets.all(D.xl),child:Form(key:_form,child:Column(children:[
          const SizedBox(height:D.lg),
          AppField(label:S.phone,hint:S.phonePlch,ctrl:_phone,kb:TextInputType.phone,validator:_phoneVal,
            formatters:[FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
            prefix:const Padding(padding:EdgeInsets.all(14),child:Icon(Icons.phone_android_rounded,size:20))),
          const SizedBox(height:D.xl),
          AppButton(label:S.cont,isLoading:loading,onPressed:(){if(_form.currentState!.validate())ctx.read<AuthBloc>().add(AuthForgotEvent(_phone.text.trim()));}),
        ])));
      }));
}
