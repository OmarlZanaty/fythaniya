import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/core/network/socket_service.dart';
import 'package:fythaniya/core/notifications/notification_service.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/screens/all_screens.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  ApiClient.instance.init();
  await NotificationService.instance.init();
  runApp(const FythaniyaApp());
}

class FythaniyaApp extends StatefulWidget {
  const FythaniyaApp({super.key});
  @override State<FythaniyaApp> createState() => _FythaniyaAppState();
}

class _FythaniyaAppState extends State<FythaniyaApp> {
  late final AuthBloc _authBloc;
  late final _AuthNotifier _notifier;
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _authBloc = AuthBloc();
    _notifier = _AuthNotifier(_authBloc);
    _authBloc.stream.listen((state) {
      if (state is AuthAuthenticated) {
        SocketService.instance.connect();
      } else if (state is AuthUnauthenticated) {
        SocketService.instance.disconnect();
      }
    });
    _router = GoRouter(
      initialLocation: AppRoutes.splash,
      refreshListenable: _notifier,
      redirect: (context, state) {
        final auth = _authBloc.state;
        final loc = state.uri.path;
        const pub = {AppRoutes.splash, AppRoutes.onboard, AppRoutes.login, AppRoutes.register, AppRoutes.forgot};
        if (auth is AuthAuthenticated && pub.contains(loc) && loc != AppRoutes.splash) return AppRoutes.home;
        if (auth is AuthUnauthenticated && !pub.contains(loc)) return AppRoutes.login;
        return null;
      },
      routes: [
        GoRoute(path: AppRoutes.splash,     builder: (_,__) => const SplashScreen()),
        GoRoute(path: AppRoutes.onboard,    builder: (_,__) => const OnboardingScreen()),
        GoRoute(path: AppRoutes.login,      builder: (_,__) => const LoginScreen()),
        GoRoute(path: AppRoutes.register,   builder: (_,__) => const RegisterScreen()),
        GoRoute(path: AppRoutes.forgot,     builder: (_,__) => const ForgotScreen()),
        GoRoute(path: AppRoutes.home,       builder: (_,__) => const HomeScreen()),
        GoRoute(path: AppRoutes.recharge,   builder: (_,__) => const RechargeScreen()),
        GoRoute(path: AppRoutes.bill,       builder: (_,s)  => BillScreen(category: s.extra as String? ?? 'ELECTRICITY')),
        GoRoute(path: AppRoutes.txList,     builder: (_,__) => const TransactionsScreen()),
        GoRoute(path: AppRoutes.notifs,     builder: (_,__) => const NotificationsScreen()),
        GoRoute(path: AppRoutes.wallet,     builder: (_,__) => const WalletScreen()),
        GoRoute(path: AppRoutes.walletTopup,    builder: (_,__) => const TopUpScreen()),
        GoRoute(path: AppRoutes.walletTransfer, builder: (_,__) => const TransferScreen()),
        GoRoute(path: AppRoutes.rewards,    builder: (_,__) => const RewardsScreen()),
        GoRoute(path: AppRoutes.profile,    builder: (_,__) => const ProfileScreen()),
        GoRoute(path: AppRoutes.editProf,   builder: (_,__) => const EditProfileScreen()),
        GoRoute(path: AppRoutes.changePass, builder: (_,__) => const ChangePasswordScreen()),
        GoRoute(path: AppRoutes.b2bApply,   builder: (_,__) => const B2BApplyScreen()),
        GoRoute(path: AppRoutes.b2bDash,    builder: (_,__) => const B2BDashboardScreen()),
        GoRoute(path: AppRoutes.b2bRequest, builder: (_,__) => const B2BRequestScreen()),
        GoRoute(path: AppRoutes.b2bInvoices,builder: (_,__) => const B2BInvoicesScreen()),
      ],
    );
  }

  @override void dispose() { _authBloc.close(); _notifier.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => MultiBlocProvider(
    providers: [
      BlocProvider<AuthBloc>.value(value: _authBloc),
      BlocProvider<HomeBloc>(create: (_) => HomeBloc()),
      BlocProvider<TxBloc>(create: (_) => TxBloc()),
      BlocProvider<RechargeBloc>(create: (_) => RechargeBloc()),
      BlocProvider<BillBloc>(create: (_) => BillBloc()),
      BlocProvider<NotifBloc>(create: (_) => NotifBloc()),
      BlocProvider<ProfileBloc>(create: (_) => ProfileBloc()),
      BlocProvider<RewardsBloc>(create: (_) => RewardsBloc()),
      BlocProvider<WalletBloc>(create: (_) => WalletBloc()),
      BlocProvider<B2BBloc>(create: (_) => B2BBloc()),
    ],
    child: MaterialApp.router(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
      locale: const Locale('ar', 'EG'),
      supportedLocales: const [Locale('ar','EG'), Locale('en','US')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (ctx, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
    ),
  );
}

class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier(AuthBloc bloc) { _sub = bloc.stream.listen((_) => notifyListeners()); }
  late final dynamic _sub;
  @override void dispose() { _sub.cancel(); super.dispose(); }
}
