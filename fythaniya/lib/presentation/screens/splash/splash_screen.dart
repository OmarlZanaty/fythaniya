// splash/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/biometric/biometric_service.dart';
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
      if (state is AuthAuthenticated) {
        // Biometric gate: if the user has opted in AND the device supports it, require a
        // successful biometric scan before entering the app. Cancel/fail = sign out.
        final svc = BiometricService.instance;
        if (await svc.isEnabled() && await svc.canUseBiometrics()) {
          final ok = await svc.authenticate();
          if (!ok) {
            if (!mounted) return;
            ctx.read<AuthBloc>().add(AuthLogoutEvent());
            return;
          }
        }
        if (!mounted) return;
        ctx.go(AppRoutes.home);
        return;
      }
      if (state is AuthUnauthenticated) {
        final p = await SharedPreferences.getInstance();
        if (!mounted) return;
        ctx.go(p.getBool(AppConstants.onboardKey)==true ? AppRoutes.login : AppRoutes.onboard);
      }
    },
    child: Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppGradients.hero),
        child: Center(child: FadeTransition(opacity:_fade, child:ScaleTransition(scale:_scale,child:Column(mainAxisSize:MainAxisSize.min,children:[
          Container(width:140,height:140,decoration:BoxDecoration(
            color:Colors.white,borderRadius:BorderRadius.circular(32),
            boxShadow:[
              BoxShadow(color:AppColors.primaryLight.withOpacity(0.35),blurRadius:40,spreadRadius:6),
              BoxShadow(color:Colors.black.withOpacity(0.25),blurRadius:24,offset: const Offset(0,8)),
            ],
          ), padding: const EdgeInsets.all(16),
            child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/images/logo.png', fit: BoxFit.contain))),
          const SizedBox(height:28),
          Text(AppConstants.appName,style:TS.amount.copyWith(color:Colors.white,fontSize:38,letterSpacing:0.5)),
          const SizedBox(height:8),Text(AppConstants.appTagline,style:TS.body.copyWith(color:Colors.white.withOpacity(0.85))),
          const SizedBox(height:56),
          CircularProgressIndicator(strokeWidth:2.5,color:Colors.white.withOpacity(0.7)),
        ]))))),
      ));
}
