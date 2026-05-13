import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override State<OnboardingScreen> createState() => _OnboardingScreenState();
}
class _OnboardingScreenState extends State<OnboardingScreen> {
  final _ctrl = PageController();
  int _cur = 0;
  static const _pages = [
    _P('ادفع كل شيء في ثانية','شحن رصيد، دفع فواتير الكهرباء والغاز والمياه والإنترنت بضغطة واحدة',Icons.bolt_rounded,AppColors.primary),
    _P('حساب الأعمال B2B','سجّل شركتك واحصل على حد ائتماني واستخدم Pay Later لتنفيذ طلباتك',Icons.business_rounded,AppColors.b2b),
    _P('اكسب نقاط واستردها','نقاط مكافآت مع كل معاملة. استبدلها بخصومات وقسائم حصرية',Icons.stars_rounded,AppColors.accent),
  ];
  Future<void> _next() async {
    if (_cur<_pages.length-1) { _ctrl.nextPage(duration:const Duration(milliseconds:350),curve:Curves.easeInOut); }
    else { final p=await SharedPreferences.getInstance(); await p.setBool(AppConstants.onboardKey,true); if(mounted) context.go(AppRoutes.login); }
  }
  @override void dispose() { _ctrl.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: SafeArea(child:Column(children:[
      Align(alignment:Alignment.topRight,child:TextButton(onPressed:_next,child:Text('تخطي',style:TS.body.copyWith(color:AppColors.textSec)))),
      Expanded(child:PageView.builder(controller:_ctrl,onPageChanged:(i)=>setState(()=>_cur=i),itemCount:_pages.length,itemBuilder:(_,i){
        final p=_pages[i];
        return Padding(padding:const EdgeInsets.all(D.xl),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
          Container(width:120,height:120,decoration:BoxDecoration(color:p.color.withOpacity(0.1),shape:BoxShape.circle,border:Border.all(color:p.color.withOpacity(0.2),width:2)),child:Icon(p.icon,size:60,color:p.color)),
          const SizedBox(height:40),Text(p.title,style:TS.h1,textAlign:TextAlign.center),
          const SizedBox(height:16),Text(p.subtitle,style:TS.body.copyWith(color:AppColors.textSec,height:1.8),textAlign:TextAlign.center),
        ]));
      })),
      Padding(padding:const EdgeInsets.all(D.xl),child:Column(children:[
        Row(mainAxisAlignment:MainAxisAlignment.center,children:List.generate(_pages.length,(i)=>AnimatedContainer(duration:const Duration(milliseconds:250),margin:const EdgeInsets.symmetric(horizontal:4),width:_cur==i?24:8,height:8,decoration:BoxDecoration(color:_cur==i?AppColors.primary:AppColors.border,borderRadius:BorderRadius.circular(4))))),
        const SizedBox(height:28),
        SizedBox(width:double.infinity,height:D.btnH,child:ElevatedButton(onPressed:_next,child:Text(_cur==_pages.length-1?'ابدأ الآن':S.cont,style:TS.btn))),
      ])),
    ])));
}
class _P { final String title,subtitle; final IconData icon; final Color color; const _P(this.title,this.subtitle,this.icon,this.color); }
