// splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override State<SplashScreen> createState() => _SplashScreenState();
}
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _fade, _scale;
  @override void initState() {
    super.initState();
    _c = AnimationController(vsync:this, duration:const Duration(milliseconds:1200));
    _fade  = CurvedAnimation(parent:_c, curve:Curves.easeOut);
    _scale = Tween<double>(begin:0.7, end:1.0).animate(CurvedAnimation(parent:_c, curve:Curves.easeOutBack));
    _c.forward();
    Future.delayed(const Duration(milliseconds:2000), () { if(mounted) context.read<AuthBloc>().add(AuthCheckEvent()); });
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => BlocListener<AuthBloc,AuthState>(
    listener: (ctx, state) async {
      if (state is AuthAuthenticated) { ctx.go(AppRoutes.home); return; }
      if (state is AuthUnauthenticated) {
        final p = await SharedPreferences.getInstance();
        if (!mounted) return;
        ctx.go(p.getBool(AppConstants.onboardKey)==true ? AppRoutes.login : AppRoutes.onboard);
      }
    },
    child: Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(child: FadeTransition(opacity:_fade, child:ScaleTransition(scale:_scale,child:Column(mainAxisSize:MainAxisSize.min,children:[
        Container(width:90,height:90,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(24),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.2),blurRadius:24,spreadRadius:4)]),
          child:Icon(Icons.bolt_rounded,color:AppColors.primary,size:52)),
        const SizedBox(height:24),
        Text(AppConstants.appName,style:TS.amount.copyWith(color:Colors.white,fontSize:36)),
        const SizedBox(height:8),Text(AppConstants.appTagline,style:TS.body.copyWith(color:Colors.white70)),
        const SizedBox(height:48),
        CircularProgressIndicator(strokeWidth:2,color:Colors.white.withOpacity(0.6)),
      ]))))));
}
