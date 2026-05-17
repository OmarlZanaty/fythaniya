import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:badges/badges.dart' as badges;
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'admin_core.dart';
import 'admin_api.dart';
import 'admin_notification_service.dart';
import 'admin_biometric_service.dart';
import 'admin_blocs.dart';
import 'admin_phase2_screens.dart';

// ════════════════════════════════════════════════════════
//  MAIN
// ════════════════════════════════════════════════════════
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.light));
  AdminApiClient.instance.init();
  await AdminNotificationService.instance.init();
  runApp(const AdminApp());
}

class AdminApp extends StatefulWidget {
  const AdminApp({super.key});
  @override State<AdminApp> createState() => _AdminAppState();
}
class _AdminAppState extends State<AdminApp> {
  late final AdminAuthBloc _auth;
  late final _AuthNotifier _notifier;
  late final GoRouter _router;

  @override void initState(){
    super.initState();
    _auth=AdminAuthBloc();
    _notifier=_AuthNotifier(_auth);
    _router=GoRouter(
      initialLocation:AdminRoutes.login,
      refreshListenable:_notifier,
      redirect:(ctx,state){
        final s=_auth.state; final loc=state.uri.path;
        if(s is AdminAuthLoggedIn&&loc==AdminRoutes.login) return AdminRoutes.dashboard;
        if(s is AdminAuthLoggedOut&&loc!=AdminRoutes.login) return AdminRoutes.login;
        return null;
      },
      routes:[
        GoRoute(path:AdminRoutes.login,    builder:(_,__)=>const LoginScreen()),
        GoRoute(path:AdminRoutes.dashboard,builder:(_,__)=>const AdminShell(child:DashboardScreen())),
        GoRoute(path:AdminRoutes.requests, builder:(_,__)=>const AdminShell(child:RequestsScreen())),
        GoRoute(path:'/requests/:id',      builder:(_,s)=>AdminShell(child:RequestDetailScreen(id:s.pathParameters['id']!))),
        GoRoute(path:AdminRoutes.services, builder:(_,__)=>const AdminShell(child:ServicesScreen())),
        GoRoute(path:AdminRoutes.b2b,      builder:(_,__)=>const AdminShell(child:B2BScreen())),
        GoRoute(path:'/b2b/:id',           builder:(_,s)=>AdminShell(child:B2BDetailScreen(id:s.pathParameters['id']!))),
        GoRoute(path:AdminRoutes.users,    builder:(_,__)=>const AdminShell(child:UsersScreen())),
        GoRoute(path:AdminRoutes.notifs,   builder:(_,__)=>const AdminShell(child:AdminNotifsScreen())),
        GoRoute(path:AdminRoutes.settings, builder:(_,__)=>const AdminShell(child:SettingsScreen())),
        GoRoute(path:AdminRoutes.reports,  builder:(_,__)=>const AdminShell(child:ReportsScreen())),
        GoRoute(path:AdminRoutes.paymentNumbers, builder:(_,__)=>const AdminShell(child:PaymentNumbersScreen())),
        GoRoute(path:AdminRoutes.clients,        builder:(_,__)=>const AdminShell(child:ClientSearchScreen())),
        GoRoute(path:AdminRoutes.appSettings,    builder:(_,__)=>const AdminShell(child:AdminSettingsScreen())),
        GoRoute(path:AdminRoutes.homeTiles,      builder:(_,__)=>const AdminShell(child:HomeTilesScreen())),
        GoRoute(path:'/requests/:id/chat',       builder:(_,s)=>AdminShell(child:RequestChatScreen(requestId:s.pathParameters['id']!))),
      ]);
  }
  @override void dispose(){_auth.close();_notifier.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>MultiBlocProvider(
    providers:[
      BlocProvider<AdminAuthBloc>.value(value:_auth),
      BlocProvider<DashBloc>(create:(_)=>DashBloc()),
      BlocProvider<ReqBloc>(create:(_)=>ReqBloc()),
      BlocProvider<AdminB2BBloc>(create:(_)=>AdminB2BBloc()),
      BlocProvider<AdminNotifBloc>(create:(_)=>AdminNotifBloc()),
      BlocProvider<AdminServicesBloc>(create:(_)=>AdminServicesBloc()),
    ],
    child:MaterialApp.router(
      title:'فى ثانية — إدارة',debugShowCheckedModeBanner:false,
      theme:adminTheme,routerConfig:_router,
      locale:const Locale('ar','EG'),
      supportedLocales:const[Locale('ar','EG'),Locale('en','US')],
      localizationsDelegates:const[GlobalMaterialLocalizations.delegate,GlobalWidgetsLocalizations.delegate,GlobalCupertinoLocalizations.delegate],
      builder:(ctx,child)=>Directionality(textDirection:TextDirection.rtl,child:child!)));
}
class _AuthNotifier extends ChangeNotifier { _AuthNotifier(AdminAuthBloc b){_s=b.stream.listen((_)=>notifyListeners());} late final dynamic _s; @override void dispose(){_s.cancel();super.dispose();} }

// ════════════════════════════════════════════════════════
//  ADMIN SHELL (with drawer)
// ════════════════════════════════════════════════════════
class AdminShell extends StatelessWidget {
  final Widget child;
  const AdminShell({super.key,required this.child});
  @override Widget build(BuildContext context)=>child;
}

// ════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ════════════════════════════════════════════════════════
class ACard extends StatelessWidget {
  final Widget child;final EdgeInsetsGeometry?padding;final VoidCallback?onTap;final Color?color;final bool highlighted;
  const ACard({super.key,required this.child,this.padding,this.onTap,this.color,this.highlighted=false});
  @override Widget build(BuildContext ctx)=>GestureDetector(onTap:onTap,child:Container(padding:padding??const EdgeInsets.all(AD.md),decoration:BoxDecoration(color:color??AC.surface,borderRadius:BorderRadius.circular(AD.r16),border:Border.all(color:highlighted?AC.primary:AC.border,width:highlighted?1.5:0.8),boxShadow:[BoxShadow(color:Colors.black.withOpacity(0.03),blurRadius:6,offset:const Offset(0,2))]),child:child));
}

class StatusBadge extends StatelessWidget {
  final String status;final bool small;
  const StatusBadge({super.key,required this.status,this.small=false});
  @override Widget build(BuildContext ctx){
    Color bg,fg;String label;
    switch(status){
      case 'COMPLETED':case 'SUCCESS':bg=AC.successBg;fg=AC.success;label='مكتمل';break;
      case 'PENDING':bg=AC.warningBg;fg=AC.warning;label='انتظار';break;
      case 'ASSIGNED':bg=AC.infoBg;fg=AC.info;label='معيّن';break;
      case 'IN_PROGRESS':bg=const Color(0xFFEDE9FE);fg=AC.critical;label='جارٍ';break;
      case 'FAILED':bg=AC.errorBg;fg=AC.error;label='فشل';break;
      case 'REFUNDED':bg=AC.infoBg;fg=AC.info;label='مسترد';break;
      case 'ESCALATED':bg=AC.criticalBg;fg=AC.critical;label='مصعّد';break;
      case 'ACTIVE':bg=AC.successBg;fg=AC.success;label='نشط';break;
      case 'OVERDUE':bg=AC.errorBg;fg=AC.error;label='متأخرة';break;
      case 'SETTLED':bg=AC.infoBg;fg=AC.info;label='مسددة';break;
      case 'PENDING_APPROVAL':bg=AC.warningBg;fg=AC.warning;label='قيد المراجعة';break;
      case 'REJECTED':bg=AC.errorBg;fg=AC.error;label='مرفوض';break;
      default:bg=AC.surfaceAlt;fg=AC.textSec;label=status;
    }
    return Container(padding:EdgeInsets.symmetric(horizontal:small?8:12,vertical:small?3:5),decoration:BoxDecoration(color:bg,borderRadius:BorderRadius.circular(20)),child:Text(label,style:AT.cap.copyWith(color:fg,fontWeight:FontWeight.w700,fontSize:small?10:11)));
  }
}

/// Bottom navigation shared across the main admin screens.
class AdminBottomNav extends StatelessWidget {
  final String current; // 'dashboard' | 'requests' | 'b2b' | 'services' | 'reports'
  const AdminBottomNav({super.key, required this.current});
  static const _items = [
    ('dashboard', Icons.dashboard_rounded,     'الرئيسية', AdminRoutes.dashboard),
    ('requests',  Icons.queue_rounded,         'الطلبات',  AdminRoutes.requests),
    ('b2b',       Icons.business_rounded,      'شركات',   AdminRoutes.b2b),
    ('services',  Icons.tune_rounded,          'الخدمات',  AdminRoutes.services),
    ('reports',   Icons.assessment_rounded,    'التقارير', AdminRoutes.reports),
  ];
  @override
  Widget build(BuildContext context) => BottomNavigationBar(
    type: BottomNavigationBarType.fixed,
    selectedItemColor: AC.primary, unselectedItemColor: AC.textMuted,
    backgroundColor: AC.surface, elevation: 8,
    currentIndex: _items.indexWhere((it) => it.$1 == current).clamp(0, _items.length - 1),
    onTap: (i) {
      final target = _items[i].$4;
      if (_items[i].$1 == current) return;
      context.go(target);
    },
    items: _items.map((it) => BottomNavigationBarItem(icon: Icon(it.$2), label: it.$3)).toList(),
  );
}

class StatCard extends StatelessWidget {
  final String label;final String value;final IconData icon;final Color color;final String?subtitle;final VoidCallback? onTap;
  const StatCard({super.key,required this.label,required this.value,required this.icon,required this.color,this.subtitle,this.onTap});
  @override Widget build(BuildContext ctx) {
    final card = ACard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Container(width:40,height:40,decoration:BoxDecoration(color:color.withOpacity(0.1),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:color,size:22)),const Spacer(),if(subtitle!=null)Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:color.withOpacity(0.1),borderRadius:BorderRadius.circular(20)),child:Text(subtitle!,style:AT.cap.copyWith(color:color,fontWeight:FontWeight.w600)))],),
      const SizedBox(height:AD.sm),
      Text(value,style:AT.num.copyWith(color:color)),
      Text(label,style:AT.cap),
    ]));
    if (onTap == null) return card;
    return Material(color: Colors.transparent, child: InkWell(borderRadius: BorderRadius.circular(AD.r12), onTap: onTap, child: card));
  }
}

void _showErr(BuildContext ctx,String msg)=>ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(msg),backgroundColor:AC.error));
void _showOk(BuildContext ctx,String msg)=>ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(msg),backgroundColor:AC.success));

// ════════════════════════════════════════════════════════
//  LOGIN SCREEN
// ════════════════════════════════════════════════════════
class LoginScreen extends StatefulWidget { const LoginScreen({super.key}); @override State<LoginScreen> createState()=>_LoginState(); }
class _LoginState extends State<LoginScreen> {
  final _form=GlobalKey<FormState>();final _email=TextEditingController();final _pass=TextEditingController();
  @override void dispose(){_email.dispose();_pass.dispose();super.dispose();}
  @override Widget build(BuildContext ctx)=>Scaffold(body:Container(decoration:const BoxDecoration(gradient:AG.hero),child:SafeArea(child:Column(children:[
    const SizedBox(height:60),
    Container(width:120,height:120,decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(28),boxShadow:[BoxShadow(color:AC.light.withOpacity(0.4),blurRadius:36,spreadRadius:4),BoxShadow(color:Colors.black.withOpacity(0.25),blurRadius:20,offset:const Offset(0,8))]),padding: const EdgeInsets.all(14), child: ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset('assets/images/logo.png', fit: BoxFit.contain))),
    const SizedBox(height:16),Text('فى ثانية',style:AT.h1.copyWith(color:Colors.white,fontSize:28,letterSpacing:0.5)),
    Text('لوحة الإدارة',style:AT.cap.copyWith(color:Colors.white.withOpacity(0.85))),
    const SizedBox(height:48),
    Expanded(child:Container(decoration:const BoxDecoration(color:AC.bg,borderRadius:BorderRadius.vertical(top:Radius.circular(28))),child:BlocConsumer<AdminAuthBloc,AdminAuthState>(
      listener:(ctx,s) async {
        if (s is AdminAuthLoggedIn) {
          // Biometric gate: if the admin opted in AND the device supports it, require a
          // successful scan before entering the dashboard. Failure = sign out.
          final svc = AdminBiometricService.instance;
          if (await svc.isEnabled() && await svc.canUseBiometrics()) {
            final ok = await svc.authenticate();
            if (!ok) {
              if (!ctx.mounted) return;
              ctx.read<AdminAuthBloc>().add(AdminLogoutEvent());
              return;
            }
          }
          if (!ctx.mounted) return;
          AdminSocketService.instance.connect();
          ctx.go(AdminRoutes.dashboard);
        }
        if (s is AdminAuthError) _showErr(ctx, s.msg);
      },
      builder:(ctx,s)=>SingleChildScrollView(padding:const EdgeInsets.all(AD.xl),child:Form(key:_form,child:Column(children:[
        const SizedBox(height:AD.lg),Text('تسجيل الدخول',style:AT.h2),const SizedBox(height:AD.xl),
        TextFormField(controller:_email,keyboardType:TextInputType.emailAddress,textDirection:TextDirection.ltr,validator:(v)=>(v?.isEmpty??true)?'البريد مطلوب':null,decoration:const InputDecoration(labelText:'البريد الإلكتروني',prefixIcon:Icon(Icons.email_outlined))),
        const SizedBox(height:AD.md),
        TextFormField(controller:_pass,obscureText:true,validator:(v)=>(v?.isEmpty??true)?'كلمة المرور مطلوبة':null,decoration:const InputDecoration(labelText:'كلمة المرور',prefixIcon:Icon(Icons.lock_outline_rounded))),
        const SizedBox(height:AD.xl),
        SizedBox(width:double.infinity,height:AD.btnH,child:ElevatedButton(onPressed:s is AdminAuthLoading?null:(){if(_form.currentState!.validate())ctx.read<AdminAuthBloc>().add(AdminLoginEvent(_email.text.trim(),_pass.text));},child:s is AdminAuthLoading?const SizedBox(width:22,height:22,child:CircularProgressIndicator(strokeWidth:2.5,color:Colors.white)):const Text('دخول',style:AT.btn))),
      ]))))),
    )]))));
}

// ════════════════════════════════════════════════════════
//  DASHBOARD
// ════════════════════════════════════════════════════════
class DashboardScreen extends StatefulWidget { const DashboardScreen({super.key}); @override State<DashboardScreen> createState()=>_DashState(); }
class _DashState extends State<DashboardScreen> {
  late final VoidCallback _newReqListener; late final VoidCallback _slaListener;
  @override void initState(){super.initState();context.read<DashBloc>().add(DashLoadEvent());_listenSocket();}
  void _listenSocket(){
    _newReqListener = (){final r=AdminSocketService.instance.newRequest.value;if(r!=null&&mounted){setState((){});context.read<DashBloc>().add(DashLoadEvent());}};
    _slaListener = (){if(mounted){ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('⚠️ تجاوز SLA — تدخل فوري مطلوب'),backgroundColor:AC.error));}};
    AdminSocketService.instance.newRequest.addListener(_newReqListener);
    AdminSocketService.instance.slaBreach.addListener(_slaListener);
  }
  @override void dispose(){
    AdminSocketService.instance.newRequest.removeListener(_newReqListener);
    AdminSocketService.instance.slaBreach.removeListener(_slaListener);
    super.dispose();
  }
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:AC.bg,
    bottomNavigationBar: const AdminBottomNav(current: 'dashboard'),
    appBar:AppBar(title:const Text('لوحة التحكم'),backgroundColor:AC.primary,actions:[
      BlocBuilder<AdminNotifBloc,AdminNotifState>(builder:(ctx,s){final unread=s is AdminNotifLoaded?s.unread:0;return badges.Badge(badgeContent:Text('$unread',style:const TextStyle(color:Colors.white,fontSize:10)),showBadge:unread>0,child:IconButton(icon:const Icon(Icons.notifications_outlined),onPressed:()=>ctx.push(AdminRoutes.notifs)));})]),
    drawer:const AdminDrawer(),
    body:BlocBuilder<DashBloc,DashState>(builder:(ctx,s){
      if(s is DashLoading) return const Center(child:CircularProgressIndicator(color:AC.primary));
      if(s is DashError) return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Text(s.msg),ElevatedButton(onPressed:()=>ctx.read<DashBloc>().add(DashLoadEvent()),child:const Text('إعادة المحاولة'))]));
      if(s is DashLoaded){
        final st=s.stats;
        return RefreshIndicator(color:AC.primary,onRefresh:()async=>ctx.read<DashBloc>().add(DashLoadEvent()),
          child:ListView(padding:const EdgeInsets.all(AD.md),children:[
            // SLA Alert
            if(st.slaBreach>0)Container(margin:const EdgeInsets.only(bottom:AD.md),padding:const EdgeInsets.all(AD.md),
              decoration:BoxDecoration(color:AC.errorBg,borderRadius:BorderRadius.circular(AD.r12),border:Border.all(color:AC.error.withOpacity(0.3))),
              child:Row(children:[const Icon(Icons.warning_rounded,color:AC.error,size:22),const SizedBox(width:12),Expanded(child:Text('${st.slaBreach} طلب تجاوز حد SLA — تدخل فوري مطلوب',style:AT.bodyM.copyWith(color:AC.error))),
                TextButton(onPressed:()=>ctx.push(AdminRoutes.requests),child:const Text('عرض'))],)),

            // Stats grid
            GridView.count(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisCount:2,crossAxisSpacing:12,mainAxisSpacing:12,childAspectRatio:1.4,children:[
              StatCard(label:'طلبات منتظرة',value:'${st.pending}',icon:Icons.pending_actions_rounded,color:AC.warning,subtitle:st.pending>0?'عاجل':null, onTap: ()=>ctx.push(AdminRoutes.requests)),
              StatCard(label:'جارٍ تنفيذها',value:'${st.inProgress}',icon:Icons.autorenew_rounded,color:AC.info, onTap: ()=>ctx.push(AdminRoutes.requests)),
              StatCard(label:'مكتملة اليوم',value:'${st.completedToday}',icon:Icons.check_circle_rounded,color:AC.success, onTap: ()=>ctx.push(AdminRoutes.requests)),
              StatCard(label:'فشلت اليوم',value:'${st.failedToday}',icon:Icons.cancel_rounded,color:AC.error, onTap: ()=>ctx.push(AdminRoutes.requests)),
              StatCard(label:'إجمالي المستخدمين',value:'${st.totalUsers}',icon:Icons.people_rounded,color:AC.primary,subtitle:'+${st.newUsersToday} اليوم', onTap: ()=>ctx.push(AdminRoutes.users)),
              StatCard(label:'إيرادات',value:'${st.totalRevenue.toStringAsFixed(0)} ج.م',icon:Icons.monetization_on_rounded,color:AC.accent, onTap: ()=>ctx.push(AdminRoutes.reports)),
            ]),
            const SizedBox(height:AD.md),

            // B2B summary
            if(st.b2bPending>0||st.b2bOverdue>0)ACard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Row(children:[const Icon(Icons.business_rounded,color:AC.b2b,size:22),const SizedBox(width:8),Text('شركات',style:AT.h3.copyWith(color:AC.b2b)),const Spacer(),TextButton(onPressed:()=>ctx.push(AdminRoutes.b2b),child:const Text('عرض الكل'))]),
              const Divider(height:16),
              Row(children:[
                Expanded(child:_B2BStat(label:'طلبات معلقة',value:'${st.b2bPending}',color:AC.warning)),
                const SizedBox(width:12),
                Expanded(child:_B2BStat(label:'فواتير متأخرة',value:'${st.b2bOverdue}',color:AC.error)),
              ]),
            ])),
            const SizedBox(height:AD.md),

            // Quick actions
            Row(children:[
              Expanded(child:_QuickAction(icon:Icons.queue_rounded,label:'طابور الطلبات',color:AC.primary,onTap:()=>ctx.push(AdminRoutes.requests))),
              const SizedBox(width:12),
              Expanded(child:_QuickAction(icon:Icons.business_rounded,label:'الشركات',color:AC.b2b,onTap:()=>ctx.push(AdminRoutes.b2b))),
              const SizedBox(width:12),
              Expanded(child:_QuickAction(icon:Icons.tune_rounded,label:'الخدمات',color:AC.accent,onTap:()=>ctx.push(AdminRoutes.services))),
            ]),
            const SizedBox(height:AD.xxl),
          ]));
      }
      return const SizedBox.shrink();
    }));
}
class _B2BStat extends StatelessWidget { final String label,value;final Color color; const _B2BStat({required this.label,required this.value,required this.color}); @override Widget build(BuildContext ctx)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(value,style:AT.h1.copyWith(color:color,fontSize:28)),Text(label,style:AT.cap)]);}
class _QuickAction extends StatelessWidget { final IconData icon;final String label;final Color color;final VoidCallback onTap; const _QuickAction({required this.icon,required this.label,required this.color,required this.onTap}); @override Widget build(BuildContext ctx)=>GestureDetector(onTap:onTap,child:ACard(padding:const EdgeInsets.symmetric(vertical:16),child:Column(children:[Container(width:44,height:44,decoration:BoxDecoration(color:color.withOpacity(0.1),shape:BoxShape.circle),child:Icon(icon,color:color,size:24)),const SizedBox(height:8),Text(label,style:AT.cap.copyWith(fontWeight:FontWeight.w600),textAlign:TextAlign.center)])));}

// ════════════════════════════════════════════════════════
//  ADMIN DRAWER
// ════════════════════════════════════════════════════════
class AdminDrawer extends StatelessWidget {
  const AdminDrawer({super.key});
  @override Widget build(BuildContext ctx)=>Drawer(child:Column(children:[
    Container(width:double.infinity,padding:const EdgeInsets.fromLTRB(20,50,20,20),color:AC.primary,child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(height:42, child: Image.asset('assets/images/logo.png', fit: BoxFit.contain, color: Colors.white)),const SizedBox(height:8),Text('فى ثانية',style:AT.h2.copyWith(color:Colors.white)),Text('لوحة الإدارة',style:AT.cap.copyWith(color:Colors.white70))])),
    Expanded(child:ListView(padding:EdgeInsets.zero,children:[
      _DItem(Icons.dashboard_rounded,'لوحة التحكم',AdminRoutes.dashboard),
      _DItem(Icons.queue_rounded,'طابور الطلبات',AdminRoutes.requests,badge:null),
      _DItem(Icons.business_rounded,'شركات',AdminRoutes.b2b),
      _DItem(Icons.tune_rounded,'الخدمات',AdminRoutes.services),
      _DItem(Icons.people_rounded,'المستخدمون',AdminRoutes.users),
      _DItem(Icons.notifications_rounded,'الإشعارات',AdminRoutes.notifs),
      _DItem(Icons.assessment_rounded,'التقارير',AdminRoutes.reports),
      _DItem(Icons.payments_rounded,'أرقام الدفع',AdminRoutes.paymentNumbers),
      _DItem(Icons.search_rounded,'بحث العملاء',AdminRoutes.clients),
      _DItem(Icons.apps_rounded,'أيقونات الرئيسية',AdminRoutes.homeTiles),
      _DItem(Icons.tune_rounded,'إعدادات التطبيق',AdminRoutes.appSettings),
      const Divider(),
      _DItem(Icons.settings_rounded,'الإعدادات',AdminRoutes.settings),
      ListTile(leading:const Icon(Icons.logout_rounded,color:AC.error),title:Text('تسجيل الخروج',style:AT.body.copyWith(color:AC.error)),onTap:()=>ctx.read<AdminAuthBloc>().add(AdminLogoutEvent())),
    ])),
  ]));
}
class _DItem extends StatelessWidget { final IconData i;final String l,r;final int?badge; const _DItem(this.i,this.l,this.r,{this.badge}); @override Widget build(BuildContext ctx)=>ListTile(leading:Icon(i,color:AC.primary,size:22),title:Text(l,style:AT.body),trailing:badge!=null&&badge!>0?Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:3),decoration:BoxDecoration(color:AC.error,borderRadius:BorderRadius.circular(12)),child:Text('$badge',style:AT.cap.copyWith(color:Colors.white))):null,onTap:()=>ctx.go(r));}

// ════════════════════════════════════════════════════════
//  REQUESTS SCREEN
// ════════════════════════════════════════════════════════
class RequestsScreen extends StatefulWidget { const RequestsScreen({super.key}); @override State<RequestsScreen> createState()=>_ReqScreenState(); }
class _ReqScreenState extends State<RequestsScreen> {
  String? _status,_type;
  final _search=TextEditingController();
  late final VoidCallback _newReqListener;
  @override void initState(){super.initState();context.read<ReqBloc>().add(ReqLoadEvent());_initSocket();}
  @override void dispose(){
    AdminSocketService.instance.newRequest.removeListener(_newReqListener);
    _search.dispose();
    super.dispose();
  }
  void _initSocket(){
    _newReqListener = (){final r=AdminSocketService.instance.newRequest.value;if(r!=null&&mounted)context.read<ReqBloc>().add(ReqNewEvent(r));};
    AdminSocketService.instance.newRequest.addListener(_newReqListener);
  }
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:AC.bg,
    bottomNavigationBar: const AdminBottomNav(current: 'requests'),
    appBar:AppBar(title:const Text('طابور الطلبات'),backgroundColor:AC.primary,actions:[IconButton(icon:const Icon(Icons.refresh_rounded),onPressed:()=>ctx.read<ReqBloc>().add(ReqRefreshEvent()))]),
    drawer:const AdminDrawer(),
    body:Column(children:[
      // Search
      Padding(padding:const EdgeInsets.all(AD.md),child:TextField(controller:_search,textDirection:TextDirection.rtl,decoration:InputDecoration(hintText:'بحث...',prefixIcon:const Icon(Icons.search_rounded),suffixIcon:_search.text.isNotEmpty?IconButton(icon:const Icon(Icons.clear),onPressed:(){_search.clear();ctx.read<ReqBloc>().add(ReqLoadEvent(status:_status,type:_type));})  :null,border:OutlineInputBorder(borderRadius:BorderRadius.circular(AD.r12)),filled:true,fillColor:AC.surface),onSubmitted:(v)=>ctx.read<ReqBloc>().add(ReqLoadEvent(status:_status,type:_type,search:v.trim())))),
      // Filter chips
      SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:AD.md,vertical:6),children:[
        _FC(label:'الكل',active:_status==null,onTap:(){setState(()=>_status=null);ctx.read<ReqBloc>().add(ReqLoadEvent(type:_type));}),
        _FC(label:'انتظار',active:_status=='PENDING',onTap:(){setState(()=>_status='PENDING');ctx.read<ReqBloc>().add(ReqLoadEvent(status:'PENDING',type:_type));}),
        _FC(label:'جارٍ',active:_status=='IN_PROGRESS',onTap:(){setState(()=>_status='IN_PROGRESS');ctx.read<ReqBloc>().add(ReqLoadEvent(status:'IN_PROGRESS',type:_type));}),
        _FC(label:'مكتمل',active:_status=='COMPLETED',onTap:(){setState(()=>_status='COMPLETED');ctx.read<ReqBloc>().add(ReqLoadEvent(status:'COMPLETED',type:_type));}),
        _FC(label:'فشل',active:_status=='FAILED',onTap:(){setState(()=>_status='FAILED');ctx.read<ReqBloc>().add(ReqLoadEvent(status:'FAILED',type:_type));}),
        _FC(label:'مصعّد',active:_status=='ESCALATED',onTap:(){setState(()=>_status='ESCALATED');ctx.read<ReqBloc>().add(ReqLoadEvent(status:'ESCALATED',type:_type));}),
      ])),
      const Divider(height:1),
      Expanded(child:BlocBuilder<ReqBloc,ReqState>(builder:(ctx,s){
        if(s is ReqLoading) return const Center(child:CircularProgressIndicator(color:AC.primary));
        if(s is ReqError) return Center(child:Text(s.msg));
        final items=s is ReqLoaded?s.items:s is ReqProcessing?s.items:[];
        if(items.isEmpty) return const Center(child:Text('لا توجد طلبات'));
        return NotificationListener<ScrollNotification>(
          onNotification:(n){if(n is ScrollEndNotification&&n.metrics.pixels>=n.metrics.maxScrollExtent-200)ctx.read<ReqBloc>().add(ReqMoreEvent());return false;},
          child:ListView.builder(padding:const EdgeInsets.all(AD.md),itemCount:items.length,itemBuilder:(_,i)=>_RequestTile(req:items[i] as RequestItem,onTap:()=>ctx.push('/requests/${(items[i] as RequestItem).id}'))));
      })),
    ]));
}
class _FC extends StatelessWidget { final String label;final bool active;final VoidCallback onTap; const _FC({required this.label,required this.active,required this.onTap}); @override Widget build(BuildContext ctx)=>Padding(padding:const EdgeInsets.only(right:8),child:FilterChip(label:Text(label),selected:active,onSelected:(_)=>onTap(),backgroundColor:AC.surfaceAlt,selectedColor:AC.infoBg,labelStyle:AT.cap.copyWith(color:active?AC.primary:AC.textSec),side:BorderSide(color:active?AC.primary:AC.border),showCheckmark:false));}

class _RequestTile extends StatelessWidget {
  final RequestItem req;final VoidCallback onTap;
  const _RequestTile({required this.req,required this.onTap});
  @override Widget build(BuildContext ctx){
    final typeNames={'MOBILE_RECHARGE':'شحن رصيد','BILL_PAYMENT':'دفع فاتورة','INTERNET_RECHARGE':'شحن إنترنت','B2B_PAY_LATER':'دفع آجل شركات','TRANSFER':'تحويل','WALLET_TOPUP':'شحن محفظة','PAY_LATER_ACTIVATION':'تفعيل دفع آجل','VODAFONE_CASH_DEPOSIT':'فودافون كاش'};
    return GestureDetector(onTap:onTap,child:Container(margin:const EdgeInsets.only(bottom:8),decoration:BoxDecoration(color:req.slaBreached?AC.errorBg:AC.surface,borderRadius:BorderRadius.circular(AD.r12),border:Border.all(color:req.slaBreached?AC.error.withOpacity(0.3):AC.border)),
      child:ListTile(
        leading:Container(width:44,height:44,decoration:BoxDecoration(color:req.isPending?AC.warningBg:req.isCompleted?AC.successBg:AC.errorBg,borderRadius:BorderRadius.circular(10)),child:Icon(req.isPending?Icons.pending_rounded:req.isCompleted?Icons.check_circle_rounded:Icons.cancel_rounded,color:req.isPending?AC.warning:req.isCompleted?AC.success:AC.error,size:22)),
        title:Row(children:[Text(typeNames[req.type]??req.type,style:AT.bodyM),const Spacer(),Text('${req.totalAmount.toStringAsFixed(0)} ج.م',style:AT.bodyM.copyWith(color:AC.primary))]),
        subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${req.userPhone} — ${req.target}',style:AT.cap),
          Row(children:[StatusBadge(status:req.status,small:true),if(req.slaBreached)...[const SizedBox(width:6),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:2),decoration:BoxDecoration(color:AC.errorBg,borderRadius:BorderRadius.circular(10)),child:Text('SLA!',style:AT.cap.copyWith(color:AC.error,fontWeight:FontWeight.w700)))]]),
        ]),
        trailing:const Icon(Icons.arrow_forward_ios_rounded,size:14,color:AC.textMuted))));
  }
}

// ════════════════════════════════════════════════════════
//  REQUEST DETAIL SCREEN
// ════════════════════════════════════════════════════════
class RequestDetailScreen extends StatefulWidget { final String id; const RequestDetailScreen({super.key,required this.id}); @override State<RequestDetailScreen> createState()=>_ReqDetailState(); }
class _ReqDetailState extends State<RequestDetailScreen> {
  RequestItem? _req; bool _loading=true;
  final _ref=TextEditingController(); final _reason=TextEditingController(); final _note=TextEditingController();

  @override void initState(){super.initState();_load();}
  @override void dispose(){_ref.dispose();_reason.dispose();_note.dispose();super.dispose();}

  Future<void> _load()async{
    try{
      final r=await AdminRequestsRepo().getRequest(widget.id);
      if(!mounted)return;
      setState((){_req=r;_loading=false;});
    } catch(e){
      print('[ReqDetail._load] $e');
      if(!mounted)return;
      setState((){_loading=false;});
    }
  }

  Future<void> _showSetAmount(BuildContext ctx) async {
    final v = await showDialog<double>(
      context: ctx,
      builder: (_) => _SetAmountDialog(initial: _req!.amount.toStringAsFixed(2)),
    );
    if (v == null) return;
    try {
      final r = await AdminRequestsRepo().setAmount(widget.id, v);
      if (mounted) _showOk(ctx, r['autoDeducted'] == true ? 'تم خصم المبلغ تلقائياً' : 'بانتظار سداد العميل');
      await _load();
    } catch (e) { if (mounted) _showErr(ctx, '$e'); }
  }

  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:AC.bg,
    appBar:AppBar(title:Text('طلب #${widget.id.substring(0,8)}'),backgroundColor:AC.primary,leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>ctx.pop()),
      actions:[
        IconButton(icon: const Icon(Icons.chat_bubble_outline_rounded), tooltip: 'محادثة العميل', onPressed: () => ctx.push('/requests/${widget.id}/chat')),
        IconButton(icon:const Icon(Icons.refresh_rounded),onPressed:_load),
      ]),
    body:_loading?const Center(child:CircularProgressIndicator(color:AC.primary)):_req==null?const Center(child:Text('حدث خطأ')):
    BlocListener<ReqBloc,ReqState>(
      listener:(ctx,s){if(s is ReqError)_showErr(ctx,s.msg);else if(s is! ReqLoading&&s is! ReqProcessing){_showOk(ctx,'تم');_load();}},
      child:ListView(padding:const EdgeInsets.all(AD.md),children:[
        // Header
        ACard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Text(_req!.type,style:AT.h3),const Spacer(),StatusBadge(status:_req!.status)]),
          const Divider(height:16),
          _Row('المبلغ','${_req!.amount.toStringAsFixed(2)} ج.م'),
          _Row('الرسوم','${_req!.fee.toStringAsFixed(2)} ج.م'),
          _Row('الإجمالي','${_req!.totalAmount.toStringAsFixed(2)} ج.م'),
          // Copyable fields — phone, account, billing, bank
          if (_req!.userPhone.isNotEmpty) CopyField(label: 'هاتف العميل', value: _req!.userPhone, direction: TextDirection.ltr),
          if (_req!.accountNumber != null && _req!.accountNumber!.isNotEmpty)
            CopyField(label: 'رقم الحساب', value: _req!.accountNumber!, direction: TextDirection.ltr),
          if (_req!.phoneNumber != null && _req!.phoneNumber!.isNotEmpty)
            CopyField(label: 'رقم الهاتف', value: _req!.phoneNumber!, direction: TextDirection.ltr),
          if (_req!.billingNumber != null && _req!.billingNumber!.isNotEmpty)
            CopyField(label: 'رقم الفاتورة', value: _req!.billingNumber!, direction: TextDirection.ltr),
          if (_req!.bankAccount != null && _req!.bankAccount!.isNotEmpty)
            CopyField(label: 'رقم الحساب البنكي', value: _req!.bankAccount!, direction: TextDirection.ltr),
          if (_req!.bankName != null && _req!.bankName!.isNotEmpty) _Row('البنك', _req!.bankName!),
          if (_req!.receiverName != null && _req!.receiverName!.isNotEmpty) _Row('المستلم', _req!.receiverName!),
          if (_req!.instapayId != null && _req!.instapayId!.isNotEmpty)
            CopyField(label: 'InstaPay ID', value: _req!.instapayId!, direction: TextDirection.ltr),
          _Row('المستخدم', _req!.userName),
          _Row('المزود',_req!.providerName),
          _Row('تاريخ الطلب','${_req!.createdAt.day}/${_req!.createdAt.month}/${_req!.createdAt.year} ${_req!.createdAt.hour}:${_req!.createdAt.minute.toString().padLeft(2,'0')}'),
          if(_req!.slaDeadline!=null)_Row('SLA','${_req!.slaDeadline!.hour}:${_req!.slaDeadline!.minute.toString().padLeft(2,'0')}',valueColor:_req!.slaBreached?AC.error:AC.success),
          if(_req!.adminNote!=null)_Row('ملاحظة المشرف',_req!.adminNote!),
          if(_req!.externalRef!=null)_Row('المرجع الخارجي',_req!.externalRef!),
        ])),
        const SizedBox(height:AD.md),

        // Payment-proof image (if uploaded)
        if(_req!.proofImageUrl != null) ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Icon(Icons.receipt_long_rounded, color: AC.primary, size: 20), const SizedBox(width: 8), Text('إثبات الدفع', style: AT.h3)]),
          const SizedBox(height: AD.sm),
          GestureDetector(
            onTap: () => showDialog(context: ctx, builder: (_) => Dialog(child: InteractiveViewer(child: Image.network(_req!.proofImageUrl!)))),
            child: ClipRRect(borderRadius: BorderRadius.circular(AD.r12), child: Image.network(_req!.proofImageUrl!, height: 220, fit: BoxFit.cover, width: double.infinity)),
          ),
          const SizedBox(height: AD.xs),
          Text('اضغط على الصورة للتكبير', style: AT.cap.copyWith(color: AC.textMuted)),
        ])),
        if(_req!.proofImageUrl != null) const SizedBox(height:AD.md),

        // Set-amount card (BILL_PAYMENT only, pending, no amount yet)
        if(_req!.isPending && _req!.type == 'BILL_PAYMENT' && _req!.amount == 0) ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [const Icon(Icons.attach_money_rounded, color: AC.warning), const SizedBox(width: 8), Text('تحديد مبلغ الفاتورة', style: AT.h3.copyWith(color: AC.warning))]),
          const SizedBox(height: AD.sm),
          Text('بعد البحث عن قيمة الفاتورة، حدد المبلغ وسيتم خصمه تلقائياً إن كان رصيد العميل كافياً، وإلا سيُطلب منه السداد ورفع إثبات.', style: AT.cap),
          const SizedBox(height: AD.md),
          SizedBox(width: double.infinity, height: AD.btnH, child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AC.warning),
            icon: const Icon(Icons.attach_money_rounded),
            label: const Text('تحديد المبلغ', style: AT.btn),
            onPressed: () => _showSetAmount(ctx),
          )),
        ])),
        if(_req!.isPending && _req!.type == 'BILL_PAYMENT' && _req!.amount == 0) const SizedBox(height: AD.sm),

        // Actions (only if pending) — approve + reject only
        if(_req!.isPending)...[
          // Approve / Complete
          ACard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(_req!.type == 'WALLET_TOPUP' ? 'الموافقة وإضافة المبلغ للمحفظة ✅'
              : _req!.type == 'PAY_LATER_ACTIVATION' ? 'الموافقة على تفعيل الدفع الآجل ✅'
              : 'تنفيذ الطلب ✅', style:AT.h3.copyWith(color:AC.success)),const SizedBox(height:AD.sm),
            TextField(controller:_ref,textDirection:TextDirection.ltr,decoration:const InputDecoration(labelText:'رقم المرجع الخارجي (اختياري)',border:OutlineInputBorder())),
            const SizedBox(height:AD.sm),
            TextField(controller:_note,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'ملاحظة (اختياري)',border:OutlineInputBorder())),
            const SizedBox(height:AD.md),
            SizedBox(width:double.infinity,height:AD.btnH,child:ElevatedButton.icon(onPressed:()=>showDialog(context:ctx,builder:(_)=>AlertDialog(title:const Text('تأكيد الموافقة'),content:Text('هل تريد الموافقة على الطلب ${widget.id.substring(0,8)}؟'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),TextButton(onPressed:(){Navigator.pop(ctx);ctx.read<ReqBloc>().add(ReqCompleteEvent(widget.id,ref:_ref.text.trim().isEmpty?null:_ref.text.trim(),note:_note.text.trim().isEmpty?null:_note.text.trim()));},child:const Text('تأكيد'))])),icon:const Icon(Icons.check_circle_rounded),label:const Text('موافقة',style:AT.btn),style:ElevatedButton.styleFrom(backgroundColor:AC.success))),
          ])),
          const SizedBox(height:AD.sm),

          // Reject / Fail
          ACard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text('رفض الطلب ❌',style:AT.h3.copyWith(color:AC.error)),const SizedBox(height:AD.sm),
            TextField(controller:_reason,textDirection:TextDirection.rtl,decoration:const InputDecoration(labelText:'سبب الرفض *',border:OutlineInputBorder())),
            const SizedBox(height:AD.md),
            SizedBox(width:double.infinity,height:AD.btnH,child:ElevatedButton.icon(onPressed:(){if(_reason.text.trim().isEmpty){_showErr(ctx,'يجب إدخال سبب الرفض');return;}showDialog(context:ctx,builder:(_)=>AlertDialog(title:const Text('تأكيد الرفض'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),TextButton(onPressed:(){Navigator.pop(ctx);ctx.read<ReqBloc>().add(ReqFailEvent(widget.id,_reason.text.trim()));},child:Text('رفض',style:TextStyle(color:AC.error)))]));}  ,icon:const Icon(Icons.cancel_rounded),label:const Text('رفض',style:AT.btn),style:ElevatedButton.styleFrom(backgroundColor:AC.error))),
          ])),
        ],
        const SizedBox(height:AD.xxl),
      ])));
}
class _Row extends StatelessWidget { final String l,v;final Color?valueColor; const _Row(this.l,this.v,{this.valueColor}); @override Widget build(BuildContext ctx)=>Padding(padding:const EdgeInsets.symmetric(vertical:5),child:Row(children:[Text('$l:',style:AT.cap),const SizedBox(width:8),Expanded(child:Text(v,style:AT.capM.copyWith(color:valueColor??AC.text),textAlign:TextAlign.left))]));}

// ════════════════════════════════════════════════════════
//  B2B SCREEN
// ════════════════════════════════════════════════════════
class B2BScreen extends StatefulWidget { const B2BScreen({super.key}); @override State<B2BScreen> createState()=>_B2BScreenState(); }
class _B2BScreenState extends State<B2BScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override void initState(){super.initState();_tab=TabController(length:2,vsync:this);context.read<AdminB2BBloc>().add(AdminB2BLoadApplicationsEvent());}
  @override void dispose(){_tab.dispose();super.dispose();}
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:AC.bg,
    bottomNavigationBar: const AdminBottomNav(current: 'b2b'),
    appBar:AppBar(title:const Text('شركات'),backgroundColor:AC.primary,
      bottom:TabBar(controller:_tab,labelColor:Colors.white,unselectedLabelColor:Colors.white70,indicatorColor:Colors.white,
        onTap:(i){if(i==0)ctx.read<AdminB2BBloc>().add(AdminB2BLoadApplicationsEvent());else ctx.read<AdminB2BBloc>().add(AdminB2BLoadAccountsEvent());},
        tabs:const[Tab(text:'طلبات معلقة'),Tab(text:'الحسابات النشطة')])),
    drawer:const AdminDrawer(),
    body:TabBarView(controller:_tab,children:[
      _B2BApplicationsList(),
      _B2BAccountsList(),
    ]));
}

class _B2BApplicationsList extends StatelessWidget {
  @override Widget build(BuildContext ctx)=>BlocConsumer<AdminB2BBloc,AdminB2BState>(
    listener:(ctx,s){if(s is AdminB2BActionDone)_showOk(ctx,'تم');if(s is AdminB2BError)_showErr(ctx,s.msg);},
    builder:(ctx,s){
      if(s is AdminB2BLoading) return const Center(child:CircularProgressIndicator(color:AC.primary));
      if(s is AdminB2BApplicationsLoaded){
        if(s.applications.isEmpty) return const Center(child:Text('لا توجد طلبات معلقة'));
        return ListView.builder(padding:const EdgeInsets.all(AD.md),itemCount:s.applications.length,itemBuilder:(_,i){
          final a=s.applications[i];
          final _limit=TextEditingController();
          final _reason=TextEditingController();
          return ACard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Icon(Icons.business_rounded,color:AC.b2b,size:20),const SizedBox(width:8),Expanded(child:Text(a.companyName,style:AT.bodyM)),StatusBadge(status:a.payLaterStatus)]),
            const SizedBox(height:AD.sm),
            Text('رقم ضريبي: ${a.taxId}',style:AT.cap),
            if(a.user!=null)Text('المستخدم: ${a.user!['phone']}',style:AT.cap),
            const Divider(height:16),
            TextField(controller:_limit,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الحد الائتماني (ج.م)',border:OutlineInputBorder(),isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:12,vertical:10))),
            const SizedBox(height:AD.sm),
            Row(children:[
              Expanded(child:ElevatedButton.icon(onPressed:(){final lim=double.tryParse(_limit.text.trim());if(lim==null||lim<=0){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('أدخل حد ائتماني صحيح')));return;}showDialog(context:ctx,builder:(_)=>AlertDialog(title:const Text('تأكيد الموافقة'),content:Text('الحد الائتماني: $lim ج.م'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),TextButton(onPressed:(){Navigator.pop(ctx);ctx.read<AdminB2BBloc>().add(AdminB2BApproveEvent(a.id,lim));},child:const Text('موافقة'))]));},icon:const Icon(Icons.check_rounded,size:18),label:const Text('موافقة'),style:ElevatedButton.styleFrom(backgroundColor:AC.success,minimumSize:const Size(0,36)))),
              const SizedBox(width:8),
              Expanded(child:ElevatedButton.icon(onPressed:(){showDialog(context:ctx,builder:(_)=>AlertDialog(title:const Text('رفض الطلب'),content:TextField(controller:_reason,decoration:const InputDecoration(labelText:'سبب الرفض')),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),TextButton(onPressed:(){if(_reason.text.isEmpty)return;Navigator.pop(ctx);ctx.read<AdminB2BBloc>().add(AdminB2BRejectEvent(a.id,_reason.text));},child:Text('رفض',style:TextStyle(color:AC.error)))]));}  ,icon:const Icon(Icons.close_rounded,size:18),label:const Text('رفض'),style:ElevatedButton.styleFrom(backgroundColor:AC.error,minimumSize:const Size(0,36)))),
            ]),
          ]));
        });
      }
      return const SizedBox.shrink();
    });
}

class _B2BAccountsList extends StatelessWidget {
  @override Widget build(BuildContext ctx)=>BlocConsumer<AdminB2BBloc,AdminB2BState>(
    listener:(ctx,s){if(s is AdminB2BActionDone)_showOk(ctx,'تم');if(s is AdminB2BError)_showErr(ctx,s.msg);},
    builder:(ctx,s){
      if(s is AdminB2BLoading) return const Center(child:CircularProgressIndicator(color:AC.primary));
      if(s is AdminB2BAccountsLoaded){
        if(s.accounts.isEmpty) return const Center(child:Text('لا توجد حسابات نشطة'));
        return ListView.builder(padding:const EdgeInsets.all(AD.md),itemCount:s.accounts.length,itemBuilder:(_,i){
          final a=s.accounts[i];
          return ACard(onTap:()=>ctx.push('/b2b/${a.id}'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(children:[const Icon(Icons.business_rounded,color:AC.b2b,size:18),const SizedBox(width:8),Expanded(child:Text(a.companyName,style:AT.bodyM,overflow:TextOverflow.ellipsis)),StatusBadge(status:a.payLaterStatus,small:true)]),
            const SizedBox(height:AD.sm),
            LinearPercentIndicator(percent:a.usagePercent,lineHeight:6,backgroundColor:AC.surfaceAlt,progressColor:a.usagePercent>0.8?AC.error:AC.primary,barRadius:const Radius.circular(3),padding:EdgeInsets.zero),
            const SizedBox(height:4),
            Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('الحد: ${a.creditLimit.toStringAsFixed(0)} ج.م',style:AT.cap),Text('المتاح: ${a.availableCredit.toStringAsFixed(0)} ج.م',style:AT.cap.copyWith(color:AC.success))]),
            if(a.overdueAmount>0)Padding(padding:const EdgeInsets.only(top:4),child:Text('متأخرة: ${a.overdueAmount.toStringAsFixed(0)} ج.م',style:AT.cap.copyWith(color:AC.error))),
          ]));
        });
      }
      return const SizedBox.shrink();
    });
}

class B2BDetailScreen extends StatefulWidget { final String id; const B2BDetailScreen({super.key,required this.id}); @override State<B2BDetailScreen> createState()=>_B2BDetailState(); }
class _B2BDetailState extends State<B2BDetailScreen> {
  B2BAccount? _acc; bool _loading=true;
  final _newLimit=TextEditingController();
  @override void initState(){super.initState();_load();}
  @override void dispose(){_newLimit.dispose();super.dispose();}
  Future<void> _load()async{
    try{
      final a=await AdminB2BRepo().getAccount(widget.id);
      if(!mounted)return;
      setState((){_acc=a;_loading=false;});
    } catch(e){
      print('[B2BDetail._load] $e');
      if(!mounted)return;
      setState((){_loading=false;});
    }
  }
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:AC.bg,
    appBar:AppBar(title:Text(_acc?.companyName??'B2B Detail'),backgroundColor:AC.primary,leading:IconButton(icon:const Icon(Icons.arrow_back_ios_new_rounded),onPressed:()=>ctx.pop())),
    body:_loading?const Center(child:CircularProgressIndicator(color:AC.primary)):_acc==null?const Center(child:Text('حدث خطأ')):
    BlocListener<AdminB2BBloc,AdminB2BState>(
      listener:(ctx,s){if(s is AdminB2BActionDone){_showOk(ctx,'تم');_load();}if(s is AdminB2BError)_showErr(ctx,s.msg);},
      child:ListView(padding:const EdgeInsets.all(AD.md),children:[
        ACard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Row(children:[Text(_acc!.companyName,style:AT.h2),const Spacer(),StatusBadge(status:_acc!.payLaterStatus)]),
          const Divider(height:16),
          _Row('الرقم الضريبي',_acc!.taxId),
          _Row('الحد الائتماني','${_acc!.creditLimit.toStringAsFixed(0)} ج.م'),
          _Row('المستخدم','${_acc!.usedCredit.toStringAsFixed(0)} ج.م'),
          _Row('المتاح','${_acc!.availableCredit.toStringAsFixed(0)} ج.م',valueColor:AC.success),
          _Row('مدة السداد','${_acc!.paymentTermDays} يوم'),
          const SizedBox(height:AD.md),
          LinearPercentIndicator(percent:_acc!.usagePercent,lineHeight:10,backgroundColor:AC.surfaceAlt,progressColor:_acc!.usagePercent>0.8?AC.error:AC.primary,barRadius:const Radius.circular(5),padding:EdgeInsets.zero),
        ])),
        const SizedBox(height:AD.md),
        ACard(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('تحديث الحد الائتماني',style:AT.h3),const SizedBox(height:AD.sm),
          TextField(controller:_newLimit,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الحد الجديد (ج.م)',border:OutlineInputBorder())),
          const SizedBox(height:AD.sm),
          SizedBox(width:double.infinity,height:AD.btnH,child:ElevatedButton(onPressed:(){final lim=double.tryParse(_newLimit.text.trim());if(lim==null||lim<=0){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('أدخل حد ائتماني صحيح')));return;}ctx.read<AdminB2BBloc>().add(AdminB2BUpdateLimitEvent(_acc!.id,lim));},child:const Text('تحديث',style:AT.btn))),
        ])),
        const SizedBox(height:AD.sm),
        SizedBox(width:double.infinity,height:AD.btnH,child:ElevatedButton.icon(onPressed:()=>ctx.read<AdminB2BBloc>().add(AdminB2BSuspendEvent(_acc!.id)),icon:const Icon(Icons.block_rounded,size:18),label:const Text('تعليق الحساب',style:AT.btn),style:ElevatedButton.styleFrom(backgroundColor:AC.error))),
        const SizedBox(height:AD.xxl),
      ])));
}

// ════════════════════════════════════════════════════════
//  SERVICES SCREEN
// ════════════════════════════════════════════════════════
class ServicesScreen extends StatefulWidget { const ServicesScreen({super.key}); @override State<ServicesScreen> createState()=>_ServicesState(); }
class _ServicesState extends State<ServicesScreen> {
  @override void initState(){super.initState();context.read<AdminServicesBloc>().add(AdminServicesLoadEvent());}
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:AC.bg,
    bottomNavigationBar: const AdminBottomNav(current: 'services'),
    appBar:AppBar(title:const Text('الخدمات'),backgroundColor:AC.primary,
      actions:[IconButton(icon:const Icon(Icons.add_rounded),onPressed:()=>_showAddProvider(ctx))]),
    drawer:const AdminDrawer(),
    body:BlocConsumer<AdminServicesBloc,AdminServicesState>(
      listener:(ctx,s){if(s is AdminServicesError)_showErr(ctx,s.msg);},
      builder:(ctx,s){
        if(s is AdminServicesLoading) return const Center(child:CircularProgressIndicator(color:AC.primary));
        if(s is AdminServicesLoaded){
          return ListView.builder(padding:const EdgeInsets.all(AD.md),itemCount:s.providers.length,itemBuilder:(_,i){
            final p=s.providers[i];
            return ACard(child:ExpansionTile(
              leading: _ImageAvatar(url: p.logoUrl, fallbackIcon: Icons.business_center_rounded),
              // Title row: keep only the name + a compact Switch + a 3-dot menu.
              // ExpansionTile gives the title ~187px after reserving leading + chevron,
              // so we can't fit Text + 3 IconButtons + Switch inline — overflows by ~17px.
              title: Row(children: [
                Expanded(child: Text(p.displayName, style: AT.bodyM, overflow: TextOverflow.ellipsis)),
                Transform.scale(scale: 0.85, child: Switch.adaptive(
                  value: p.isActive,
                  onChanged: (v) => ctx.read<AdminServicesBloc>().add(AdminServicesToggleProviderEvent(p.id, v)),
                  activeColor: AC.success,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                )),
                PopupMenuButton<String>(
                  tooltip: 'إجراءات',
                  icon: const Icon(Icons.more_vert_rounded, size: 20, color: AC.textSec),
                  padding: EdgeInsets.zero,
                  onSelected: (v) {
                    if (v == 'logo')   _pickProviderLogo(ctx, p.id);
                    if (v == 'edit')   _showEditProvider(ctx, p);
                    if (v == 'delete') _confirmDeleteProvider(ctx, p);
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'logo',   child: ListTile(dense: true, leading: Icon(Icons.add_a_photo_rounded, color: AC.primary), title: Text('تغيير الشعار'))),
                    const PopupMenuItem(value: 'edit',   child: ListTile(dense: true, leading: Icon(Icons.edit_rounded, color: AC.primary), title: Text('تعديل'))),
                    const PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline_rounded, color: AC.error), title: Text('حذف', style: TextStyle(color: AC.error)))),
                  ],
                ),
              ]),
              subtitle:Text('${p.category} — ${p.subServices.length} خدمات',style:AT.cap),
              children:[
                ...p.subServices.map((sub)=>ListTile(
                  leading: _ImageAvatar(url: sub.imageUrl, fallbackIcon: Icons.miscellaneous_services_rounded, size: 40),
                  title: Text(sub.nameAr, style: AT.body),
                  subtitle: Text('ثابتة: ${sub.fixedFee} ج.م  |  نسبة: ${(sub.percentageFee*100).toStringAsFixed(1)}%', style: AT.cap),
                  // Sub-service actions also live in an overflow menu so the trailing
                  // area stays narrow regardless of screen width.
                  trailing: PopupMenuButton<String>(
                    tooltip: 'إجراءات',
                    icon: const Icon(Icons.more_vert_rounded, size: 20, color: AC.textSec),
                    padding: EdgeInsets.zero,
                    onSelected: (v) {
                      if (v == 'image')  _pickSubServiceImage(ctx, sub.id);
                      if (v == 'edit')   _showEditSub(ctx, sub);
                      if (v == 'delete') _confirmDeleteSub(ctx, sub);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'image',  child: ListTile(dense: true, leading: Icon(Icons.add_a_photo_outlined, color: AC.primary), title: Text('تغيير الصورة'))),
                      const PopupMenuItem(value: 'edit',   child: ListTile(dense: true, leading: Icon(Icons.edit_rounded, color: AC.primary), title: Text('تعديل'))),
                      const PopupMenuItem(value: 'delete', child: ListTile(dense: true, leading: Icon(Icons.delete_outline_rounded, color: AC.error), title: Text('حذف', style: TextStyle(color: AC.error)))),
                    ],
                  ),
                )),
                ListTile(leading:const Icon(Icons.add_rounded,color:AC.primary),title:Text('إضافة خدمة فرعية',style:AT.body.copyWith(color:AC.primary)),onTap:()=>_showAddSub(ctx,p.id)),
              ]));
          });
        }
        return const SizedBox.shrink();
      }));

  void _showAddProvider(BuildContext ctx){
    final _name=TextEditingController(); final _display=TextEditingController(); String _cat='TELECOM';
    showDialog(context:ctx,builder:(_)=>AlertDialog(title:const Text('إضافة مزود خدمة'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:_name,decoration:const InputDecoration(labelText:'الاسم الداخلي')),TextField(controller:_display,decoration:const InputDecoration(labelText:'الاسم المعروض')),DropdownButtonFormField<String>(value:_cat,items:['TELECOM','ELECTRICITY','GAS','WATER','INTERNET','INSURANCE','GOVERNMENT'].map((c)=>DropdownMenuItem(value:c,child:Text(c))).toList(),onChanged:(v)=>_cat=v!,decoration:const InputDecoration(labelText:'الفئة'))]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),TextButton(onPressed:() async {
      final name=_name.text.trim(); final display=_display.text.trim();
      if(name.isEmpty||display.isEmpty){ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('الاسم والاسم المعروض مطلوبان')));return;}
      Navigator.pop(ctx);
      try {
        await AdminServicesRepo().createProvider({'name':name,'displayName':display,'category':_cat,'isActive':true});
        if(ctx.mounted) ctx.read<AdminServicesBloc>().add(AdminServicesLoadEvent());
      } on AdminApiException catch(e) {
        if(ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content:Text(e.message),backgroundColor:AC.error));
      }
    },child:const Text('إضافة'))])).then((_){_name.dispose();_display.dispose();});
  }

  Future<void> _showEditSub(BuildContext ctx, SubService sub) async {
    final result = await showDialog<Map<String,dynamic>>(
      context: ctx,
      builder: (_) => _EditSubServiceDialog(sub: sub),
    );
    if (result == null) return;
    try {
      await AdminServicesRepo().updateSubService(sub.id, result);
      if (!ctx.mounted) return;
      _showOk(ctx, '✅ تم التعديل');
      ctx.read<AdminServicesBloc>().add(AdminServicesLoadEvent());
    } on AdminApiException catch (e) {
      if (ctx.mounted) _showErr(ctx, e.message);
    }
  }

  void _showAddSub(BuildContext ctx,String providerId){
    final _name=TextEditingController(); final _nameAr=TextEditingController(); final _fixed=TextEditingController(text:'1.5'); final _pct=TextEditingController(text:'0'); String _cat='TELECOM';
    showDialog(context:ctx,builder:(_)=>AlertDialog(title:const Text('إضافة خدمة فرعية'),content:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:_name,decoration:const InputDecoration(labelText:'الاسم بالإنجليزية')),TextField(controller:_nameAr,decoration:const InputDecoration(labelText:'الاسم بالعربية')),TextField(controller:_fixed,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'الرسوم الثابتة (ج.م)')),TextField(controller:_pct,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'النسبة المئوية (%)'))])),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('إلغاء')),TextButton(onPressed:(){if(_name.text.isEmpty||_nameAr.text.isEmpty)return;Navigator.pop(ctx);AdminServicesRepo().createSubService(providerId,{'name':_name.text,'nameAr':_nameAr.text,'category':_cat,'fixedFee':double.tryParse(_fixed.text)??0,'percentageFee':(double.tryParse(_pct.text)??0)/100}).then((_)=>ctx.read<AdminServicesBloc>().add(AdminServicesLoadEvent()));},child:const Text('إضافة'))])).then((_){_name.dispose();_nameAr.dispose();_fixed.dispose();_pct.dispose();});
  }

  Future<void> _pickProviderLogo(BuildContext ctx, String providerId) async {
    final file = await _pickImage(ctx);
    if (file == null) return;
    try {
      _showOk(ctx, 'جارٍ الرفع...');
      await AdminServicesRepo().uploadProviderLogo(providerId, file);
      if (!ctx.mounted) return;
      _showOk(ctx, '✅ تم رفع الشعار');
      ctx.read<AdminServicesBloc>().add(AdminServicesLoadEvent());
    } on AdminApiException catch (e) {
      if (ctx.mounted) _showErr(ctx, e.message);
    } catch (e) {
      if (ctx.mounted) _showErr(ctx, 'فشل الرفع: $e');
    }
  }

  Future<void> _pickSubServiceImage(BuildContext ctx, String subId) async {
    final file = await _pickImage(ctx);
    if (file == null) return;
    try {
      _showOk(ctx, 'جارٍ الرفع...');
      await AdminServicesRepo().uploadSubServiceImage(subId, file);
      if (!ctx.mounted) return;
      _showOk(ctx, '✅ تم رفع الصورة');
      ctx.read<AdminServicesBloc>().add(AdminServicesLoadEvent());
    } on AdminApiException catch (e) {
      if (ctx.mounted) _showErr(ctx, e.message);
    } catch (e) {
      if (ctx.mounted) _showErr(ctx, 'فشل الرفع: $e');
    }
  }

  Future<String?> _pickImage(BuildContext ctx) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: ctx, builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AC.primary), title: const Text('الكاميرا'), onTap: () => Navigator.pop(ctx, ImageSource.camera)),
        ListTile(leading: const Icon(Icons.photo_library_rounded, color: AC.primary), title: const Text('المعرض'), onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
      ])),
    );
    if (source == null) return null;
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source, imageQuality: 80, maxWidth: 1200);
    return file?.path;
  }

  // Edit a provider's displayName + category. Uses a stateful dialog to safely own controllers.
  Future<void> _showEditProvider(BuildContext ctx, ServiceProvider p) async {
    final result = await showDialog<Map<String,dynamic>>(
      context: ctx,
      builder: (_) => _EditProviderDialog(provider: p),
    );
    if (result == null) return;
    try {
      await AdminServicesRepo().updateProvider(p.id, result);
      if (!ctx.mounted) return;
      _showOk(ctx, '✅ تم التعديل');
      ctx.read<AdminServicesBloc>().add(AdminServicesLoadEvent());
    } on AdminApiException catch (e) {
      if (ctx.mounted) _showErr(ctx, e.message);
    }
  }

  // Hard delete (deactivate) a provider with confirm.
  Future<void> _confirmDeleteProvider(BuildContext ctx, ServiceProvider p) async {
    final ok = await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
      title: const Text('حذف المزود'),
      content: Text('سيتم إخفاء "${p.displayName}" وكل خدماته الفرعية من العملاء. متأكد؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: AC.error))),
      ],
    ));
    if (ok != true) return;
    try {
      await AdminServicesRepo().deleteProvider(p.id);
      if (!ctx.mounted) return;
      _showOk(ctx, 'تم الحذف');
      ctx.read<AdminServicesBloc>().add(AdminServicesLoadEvent());
    } on AdminApiException catch (e) {
      if (ctx.mounted) _showErr(ctx, e.message);
    }
  }

  // Hard delete (deactivate) a sub-service with confirm.
  Future<void> _confirmDeleteSub(BuildContext ctx, SubService sub) async {
    final ok = await showDialog<bool>(context: ctx, builder: (_) => AlertDialog(
      title: const Text('حذف الخدمة الفرعية'),
      content: Text('سيتم إخفاء "${sub.nameAr}" من العملاء. متأكد؟'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('حذف', style: TextStyle(color: AC.error))),
      ],
    ));
    if (ok != true) return;
    try {
      await AdminServicesRepo().deleteSubService(sub.id);
      if (!ctx.mounted) return;
      _showOk(ctx, 'تم الحذف');
      ctx.read<AdminServicesBloc>().add(AdminServicesLoadEvent());
    } on AdminApiException catch (e) {
      if (ctx.mounted) _showErr(ctx, e.message);
    }
  }
}

// Edits an existing provider's displayName + category. Stateful so it disposes safely.
class _EditProviderDialog extends StatefulWidget {
  final ServiceProvider provider;
  const _EditProviderDialog({required this.provider});
  @override State<_EditProviderDialog> createState() => _EditProviderDialogState();
}
class _EditProviderDialogState extends State<_EditProviderDialog> {
  late final TextEditingController _display;
  late String _category;
  static const _cats = ['TELECOM','ELECTRICITY','GAS','WATER','INTERNET','INSURANCE','GOVERNMENT'];
  @override
  void initState() {
    super.initState();
    _display = TextEditingController(text: widget.provider.displayName);
    _category = _cats.contains(widget.provider.category) ? widget.provider.category : 'TELECOM';
  }
  @override void dispose() { _display.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: Text('تعديل ${widget.provider.displayName}'),
    content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _display, decoration: const InputDecoration(labelText: 'الاسم المعروض', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      DropdownButtonFormField<String>(
        value: _category,
        decoration: const InputDecoration(labelText: 'الفئة', border: OutlineInputBorder()),
        items: _cats.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
        onChanged: (v) => setState(() => _category = v ?? _category),
      ),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        if (_display.text.trim().isEmpty) {
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الاسم المعروض مطلوب'), backgroundColor: AC.error));
          return;
        }
        Navigator.pop(ctx, <String,dynamic>{
          'displayName': _display.text.trim(),
          'category': _category,
        });
      }, child: const Text('حفظ')),
    ],
  );
}

// Edits an existing sub-service's Arabic name and fees. Stateful → safe dispose.
class _EditSubServiceDialog extends StatefulWidget {
  final SubService sub;
  const _EditSubServiceDialog({required this.sub});
  @override State<_EditSubServiceDialog> createState() => _EditSubServiceDialogState();
}
class _EditSubServiceDialogState extends State<_EditSubServiceDialog> {
  late final TextEditingController _nameAr;
  late final TextEditingController _fixed;
  late final TextEditingController _pct;
  @override
  void initState() {
    super.initState();
    _nameAr = TextEditingController(text: widget.sub.nameAr);
    _fixed  = TextEditingController(text: widget.sub.fixedFee.toString());
    _pct    = TextEditingController(text: (widget.sub.percentageFee * 100).toString());
  }
  @override void dispose() { _nameAr.dispose(); _fixed.dispose(); _pct.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: Text('تعديل ${widget.sub.nameAr}'),
    content: SizedBox(width: 320, child: Column(mainAxisSize: MainAxisSize.min, children: [
      TextField(controller: _nameAr, decoration: const InputDecoration(labelText: 'الاسم بالعربية', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _fixed, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'الرسوم الثابتة (ج.م)', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _pct, keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'النسبة المئوية (%)', border: OutlineInputBorder())),
    ])),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        final n = _nameAr.text.trim();
        if (n.isEmpty) {
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('الاسم بالعربية مطلوب'), backgroundColor: AC.error));
          return;
        }
        final fixed = double.tryParse(_fixed.text.trim()) ?? widget.sub.fixedFee;
        final pct   = (double.tryParse(_pct.text.trim()) ?? widget.sub.percentageFee * 100) / 100;
        Navigator.pop(ctx, <String,dynamic>{
          'nameAr': n,
          'fixedFee': fixed,
          'percentageFee': pct,
        });
      }, child: const Text('حفظ')),
    ],
  );
}

/// Small avatar that renders a network image (with cache) or falls back to an icon.
class _ImageAvatar extends StatelessWidget {
  final String? url; final IconData fallbackIcon; final double size;
  const _ImageAvatar({required this.url, required this.fallbackIcon, this.size = 44});
  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: AC.surfaceAlt, borderRadius: BorderRadius.circular(10)),
        child: Icon(fallbackIcon, color: AC.primary, size: size * 0.55),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: CachedNetworkImage(
        imageUrl: url!, width: size, height: size, fit: BoxFit.cover,
        placeholder: (_, __) => Container(width: size, height: size, color: AC.surfaceAlt, child: const Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))),
        errorWidget: (_, __, ___) => Container(width: size, height: size, color: AC.errorBg, child: Icon(Icons.broken_image_rounded, color: AC.error, size: size * 0.5)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  USERS SCREEN
// ════════════════════════════════════════════════════════
class UsersScreen extends StatefulWidget { const UsersScreen({super.key}); @override State<UsersScreen> createState()=>_UsersState(); }
class _UsersState extends State<UsersScreen> {
  List<AdminUser> _users=[]; bool _loading=true; final _search=TextEditingController();
  @override void initState(){super.initState();_load();}
  @override void dispose(){_search.dispose();super.dispose();}
  Future<void> _load({String?search})async{
    setState((){_loading=true;});
    try{
      final r=await AdminUsersRepo().getUsers(search:search);
      if(!mounted)return;
      setState((){_users=r.data;_loading=false;});
    } catch(e){
      print('[UsersScreen._load] $e');
      if(!mounted)return;
      setState((){_loading=false;});
    }
  }
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:AC.bg,
    appBar:AppBar(title:const Text('المستخدمون'),backgroundColor:AC.primary),
    drawer:const AdminDrawer(),
    body:Column(children:[
      Padding(padding:const EdgeInsets.all(AD.md),child:TextField(controller:_search,textDirection:TextDirection.rtl,decoration:InputDecoration(hintText:'بحث بالهاتف أو الاسم...',prefixIcon:const Icon(Icons.search_rounded),border:OutlineInputBorder(borderRadius:BorderRadius.circular(AD.r12)),filled:true,fillColor:AC.surface),onSubmitted:(v)=>_load(search:v.trim()))),
      Expanded(child:_loading?const Center(child:CircularProgressIndicator(color:AC.primary)):_users.isEmpty?const Center(child:Text('لا يوجد مستخدمون')):
      ListView.builder(padding:const EdgeInsets.symmetric(horizontal:AD.md),itemCount:_users.length,itemBuilder:(_,i){
        final u=_users[i];
        return ACard(child:ListTile(
          leading:CircleAvatar(backgroundColor:AC.infoBg,child:Text(u.fullName.isNotEmpty?u.fullName[0]:'؟',style:AT.bodyM.copyWith(color:AC.primary))),
          title:Text(u.fullName,style:AT.bodyM),
          subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(u.phone,style:AT.cap),Row(children:[Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:2),decoration:BoxDecoration(color:u.type=='B2B'?AC.b2bBg:AC.surfaceAlt,borderRadius:BorderRadius.circular(10)),child:Text(u.type,style:AT.cap.copyWith(color:u.type=='B2B'?AC.b2b:AC.textSec))),const SizedBox(width:6),StatusBadge(status:u.status,small:true)])]),
          trailing:IconButton(icon:const Icon(Icons.block_rounded,color:AC.error,size:20),onPressed:()=>showDialog(context:ctx,builder:(_)=>AlertDialog(title:const Text('تغيير حالة الحساب'),content:Column(mainAxisSize:MainAxisSize.min,children:[ListTile(title:const Text('تفعيل'),onTap:(){Navigator.pop(ctx);AdminUsersRepo().updateStatus(u.id,'ACTIVE').then((_){_showOk(ctx,'تم');_load();});}),ListTile(title:const Text('تعليق'),onTap:(){Navigator.pop(ctx);AdminUsersRepo().updateStatus(u.id,'SUSPENDED').then((_){_showOk(ctx,'تم');_load();});}),ListTile(title:const Text('حظر',style:TextStyle(color:AC.error)),onTap:(){Navigator.pop(ctx);AdminUsersRepo().updateStatus(u.id,'BANNED').then((_){_showOk(ctx,'تم');_load();});})]))))));
      })),
    ]));
}

// ════════════════════════════════════════════════════════
//  NOTIFICATIONS SCREEN
// ════════════════════════════════════════════════════════
class AdminNotifsScreen extends StatefulWidget { const AdminNotifsScreen({super.key}); @override State<AdminNotifsScreen> createState()=>_ANotifsState(); }
class _ANotifsState extends State<AdminNotifsScreen> {
  @override void initState(){super.initState();context.read<AdminNotifBloc>().add(AdminNotifLoadEvent());}
  @override Widget build(BuildContext ctx)=>Scaffold(backgroundColor:AC.bg,
    appBar:AppBar(title:const Text('الإشعارات'),backgroundColor:AC.primary,
      actions:[TextButton(onPressed:()=>ctx.read<AdminNotifBloc>().add(AdminNotifMarkAllEvent()),child:const Text('تعيين الكل',style:TextStyle(color:Colors.white70)))]),
    drawer:const AdminDrawer(),
    body:BlocBuilder<AdminNotifBloc,AdminNotifState>(builder:(ctx,s){
      if(s is AdminNotifLoading) return const Center(child:CircularProgressIndicator(color:AC.primary));
      if(s is AdminNotifLoaded){
        if(s.items.isEmpty) return const Center(child:Text('لا توجد إشعارات'));
        return ListView.builder(padding:const EdgeInsets.all(AD.md),itemCount:s.items.length,itemBuilder:(_,i){
          final n=s.items[i];
          final col=n.priority=='CRITICAL'?AC.error:n.priority=='HIGH'?AC.warning:AC.primary;
          return Container(margin:const EdgeInsets.only(bottom:8),
            decoration:BoxDecoration(color:n.isRead?AC.surface:col.withOpacity(0.05),borderRadius:BorderRadius.circular(AD.r12),border:Border.all(color:n.isRead?AC.border:col.withOpacity(0.3))),
            child:ListTile(
              leading:Container(width:40,height:40,decoration:BoxDecoration(color:col.withOpacity(0.1),shape:BoxShape.circle),child:Icon(n.priority=='CRITICAL'?Icons.error_rounded:n.priority=='HIGH'?Icons.warning_rounded:Icons.notifications_rounded,color:col,size:20)),
              title:Text(n.title,style:AT.bodyM),
              subtitle:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(n.body,style:AT.cap,maxLines:2,overflow:TextOverflow.ellipsis),Text('${n.createdAt.day}/${n.createdAt.month} ${n.createdAt.hour}:${n.createdAt.minute.toString().padLeft(2,'0')}',style:AT.cap.copyWith(color:AC.textMuted,fontSize:10))]),
              trailing:Row(mainAxisSize:MainAxisSize.min,children:[if(!n.isRead)Container(width:8,height:8,decoration:BoxDecoration(color:col,shape:BoxShape.circle)),if(n.requestId!=null)IconButton(icon:const Icon(Icons.open_in_new_rounded,size:16),onPressed:()=>ctx.push('/requests/${n.requestId}'))]),
            ));
        });
      }
      return const SizedBox.shrink();
    }));
}

// ════════════════════════════════════════════════════════
//  SETTINGS SCREEN
// ════════════════════════════════════════════════════════
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override State<SettingsScreen> createState() => _SettingsState();
}
class _SettingsState extends State<SettingsScreen> {
  bool _bioEnabled = false; bool _bioAvailable = false; String _bioLabel = 'القياس الحيوي';
  @override void initState() { super.initState(); _loadBio(); }
  Future<void> _loadBio() async {
    final svc = AdminBiometricService.instance;
    final available = await svc.canUseBiometrics();
    final enabled   = await svc.isEnabled();
    final label     = await svc.bestAvailableLabel();
    if (mounted) setState(() { _bioAvailable = available; _bioEnabled = enabled; _bioLabel = label; });
  }
  Future<void> _toggleBio(bool v) async {
    final svc = AdminBiometricService.instance;
    if (v) {
      final ok = await svc.authenticate(reason: 'تأكيد لتفعيل الدخول بـ$_bioLabel');
      if (!ok) {
        if (mounted) _showErr(context, 'تعذر تفعيل $_bioLabel');
        return;
      }
    }
    await svc.setEnabled(v);
    if (mounted) {
      setState(() => _bioEnabled = v);
      _showOk(context, v ? 'تم تفعيل $_bioLabel' : 'تم إيقاف $_bioLabel');
    }
  }
  @override
  Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: AC.bg,
    appBar: AppBar(title: const Text('الإعدادات'), backgroundColor: AC.primary),
    drawer: const AdminDrawer(),
    body: ListView(padding: const EdgeInsets.all(AD.md), children: [
      if (_bioAvailable) ACard(child: SwitchListTile(
        contentPadding: EdgeInsets.zero,
        secondary: const Icon(Icons.fingerprint_rounded, color: AC.primary),
        title: Text('الدخول بـ$_bioLabel', style: AT.bodyM),
        subtitle: Text(_bioEnabled ? 'مفعل — يُطلب منك التحقق عند فتح اللوحة' : 'غير مفعل', style: AT.cap),
        value: _bioEnabled, onChanged: _toggleBio, activeColor: AC.primary,
      )),
      if (_bioAvailable) const SizedBox(height: AD.md),
      ACard(child: ListTile(
        leading: const Icon(Icons.logout_rounded, color: AC.error),
        title: Text('تسجيل الخروج', style: AT.body.copyWith(color: AC.error)),
        onTap: () => ctx.read<AdminAuthBloc>().add(AdminLogoutEvent()),
      )),
    ]),
  );
}


// ════════════════════════════════════════════════════════
//  REPORTS SCREEN
// ════════════════════════════════════════════════════════
class ReportsScreen extends StatefulWidget { const ReportsScreen({super.key}); @override State<ReportsScreen> createState()=>_ReportsState(); }
class _ReportsState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tab;
  Map<String,dynamic>? _txReport;
  List<dynamic> _payLaterInvoices = [];
  List<dynamic> _payLaterSummary = [];
  bool _loading = true;
  DateTime _from = DateTime.now().subtract(const Duration(days: 30));
  DateTime _to = DateTime.now();
  @override void initState() { super.initState(); _tab = TabController(length: 2, vsync: this); _load(); }
  @override void dispose() { _tab.dispose(); super.dispose(); }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final tx = await AdminApiClient.instance.get('/admin/reports/transactions', params: {
        'from': _from.toIso8601String(), 'to': _to.toIso8601String(),
      });
      final pl = await AdminApiClient.instance.get('/admin/reports/pay-later');
      if (!mounted) return;
      setState(() {
        _txReport = tx['data'] as Map<String, dynamic>?;
        _payLaterInvoices = ((pl['data'] as Map<String,dynamic>?)?['invoices'] as List?) ?? [];
        _payLaterSummary = ((pl['data'] as Map<String,dynamic>?)?['summary'] as List?) ?? [];
        _loading = false;
      });
    } catch (e) {
      print('[Reports] $e');
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context, firstDate: DateTime(2025), lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) { setState(() { _from = picked.start; _to = picked.end; }); _load(); }
  }

  Future<void> _markPaid(String invoiceId) async {
    try {
      await AdminApiClient.instance.put('/admin/reports/pay-later/$invoiceId/mark-settled');
      _showOk(context, 'تم تسجيل السداد');
      _load();
    } catch (e) { _showErr(context, '$e'); }
  }

  @override Widget build(BuildContext ctx) => Scaffold(
    backgroundColor: AC.bg,
    bottomNavigationBar: const AdminBottomNav(current: 'reports'),
    appBar: AppBar(title: const Text('التقارير'), backgroundColor: AC.primary,
      actions: [
        IconButton(icon: const Icon(Icons.file_download_outlined), tooltip: 'تصدير CSV لليوم', onPressed: () async {
          try {
            final token = await AdminApiClient.instance.getToken();
            final today = DateTime.now().toIso8601String().substring(0, 10);
            final url = '${AdminConstants.baseUrl}/admin/dashboard/export-csv?date=$today';
            if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
              if (mounted) _showErr(ctx, 'فشل فتح الرابط: $url\nالتوكن: ${token?.substring(0,8) ?? "?"}...');
            }
          } catch (e) { if (mounted) _showErr(ctx, '$e'); }
        }),
        IconButton(icon: const Icon(Icons.date_range_rounded), onPressed: _pickRange),
      ],
      bottom: TabBar(controller: _tab, tabs: const [Tab(text: 'المعاملات'), Tab(text: 'الدفع الآجل')]),
    ),
    drawer: const AdminDrawer(),
    body: _loading
      ? const Center(child: CircularProgressIndicator(color: AC.primary))
      : TabBarView(controller: _tab, children: [
        // Transactions tab
        RefreshIndicator(onRefresh: _load, color: AC.primary, child: ListView(padding: const EdgeInsets.all(AD.md), children: [
          ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الفترة: ${_from.day}/${_from.month} → ${_to.day}/${_to.month}', style: AT.cap),
            const Divider(height: 16),
            if (_txReport?['totals'] != null) ...[
              _Row('عدد المعاملات', '${_txReport!['totals']['count'] ?? 0}'),
              _Row('إجمالي المبلغ', '${_txReport!['totals']['totalAmount'] ?? '0'} ج.م'),
              _Row('إجمالي الرسوم', '${_txReport!['totals']['totalFee'] ?? '0'} ج.م'),
            ],
          ])),
          const SizedBox(height: AD.md),
          ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('حسب الحالة', style: AT.h3), const SizedBox(height: AD.sm),
            ...((_txReport?['byStatus'] as List?) ?? []).map((s) => _Row(
              '${s['status']}', '${s['_count']?['_all'] ?? 0} — ${s['_sum']?['totalAmount'] ?? 0} ج.م',
            )),
          ])),
          const SizedBox(height: AD.md),
          ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('حسب طريقة الدفع', style: AT.h3), const SizedBox(height: AD.sm),
            ...((_txReport?['byMethod'] as List?) ?? []).map((m) => _Row(
              '${m['paymentMethod']}', '${m['_count']?['_all'] ?? 0} — ${m['_sum']?['totalAmount'] ?? 0} ج.م',
            )),
          ])),
        ])),

        // Pay-later tab
        RefreshIndicator(onRefresh: _load, color: AC.primary, child: ListView(padding: const EdgeInsets.all(AD.md), children: [
          ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('الملخص حسب الحالة', style: AT.h3), const SizedBox(height: AD.sm),
            ..._payLaterSummary.map((s) => _Row(
              '${s['status']}', '${s['_count']?['_all'] ?? 0} فاتورة — ${s['_sum']?['amount'] ?? 0} ج.م',
            )),
          ])),
          const SizedBox(height: AD.md),
          ..._payLaterInvoices.map((inv) {
            final user = (inv['b2bAccount']?['user']) as Map<String,dynamic>?;
            final amount = inv['amount']?.toString() ?? '0';
            final status = inv['status']?.toString() ?? '';
            return ACard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(inv['invoiceNo']?.toString() ?? '—', style: AT.bodyM)),
                StatusBadge(status: status, small: true),
              ]),
              const SizedBox(height: 6),
              Text('${user?['fullName'] ?? '—'} • ${user?['phone'] ?? '—'}', style: AT.cap),
              const SizedBox(height: 4),
              Text('$amount ج.م', style: AT.bodyM.copyWith(color: AC.primary)),
              if (status != 'SETTLED') ...[
                const SizedBox(height: 8),
                SizedBox(width: double.infinity, child: OutlinedButton.icon(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: const Text('تسجيل سداد'),
                  onPressed: () => _markPaid(inv['id']?.toString() ?? ''),
                )),
              ],
            ]));
          }),
        ])),
      ]),
  );
}

// ════════════════════════════════════════════════════════
//  STATEFUL DIALOG — safely owns its TextEditingController
// ════════════════════════════════════════════════════════
class _SetAmountDialog extends StatefulWidget {
  final String initial;
  const _SetAmountDialog({required this.initial});
  @override State<_SetAmountDialog> createState() => _SetAmountDialogState();
}
class _SetAmountDialogState extends State<_SetAmountDialog> {
  late final TextEditingController _amt;
  @override void initState() { super.initState(); _amt = TextEditingController(text: widget.initial); }
  @override void dispose() { _amt.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext ctx) => AlertDialog(
    title: const Text('تحديد مبلغ الفاتورة'),
    content: TextField(
      controller: _amt,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      decoration: const InputDecoration(labelText: 'المبلغ (ج.م)', border: OutlineInputBorder()),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
      TextButton(onPressed: () {
        final v = double.tryParse(_amt.text.trim());
        if (v == null || v <= 0) {
          ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('أدخل مبلغاً صحيحاً'), backgroundColor: AC.error));
          return;
        }
        Navigator.pop(ctx, v);
      }, child: const Text('تأكيد')),
    ],
  );
}
