import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';
import 'package:fythaniya/presentation/screens/all_screens.dart';

// ─── Icon + color registry for admin-driven home tiles ────────────────────────
// `iconKey` strings the admin can pick from. Unknown keys fall back to apps_rounded.
const Map<String, IconData> kHomeIconMap = {
  'smartphone':   Icons.smartphone_rounded,
  'phone':        Icons.phone_rounded,
  'bolt':         Icons.bolt_rounded,
  'gas':          Icons.local_fire_department_rounded,
  'water':        Icons.water_drop_rounded,
  'wifi':         Icons.wifi_rounded,
  'instapay':     Icons.bolt_rounded,
  'bank':         Icons.account_balance_rounded,
  'business':     Icons.business_rounded,
  'wallet':       Icons.account_balance_wallet_rounded,
  'rewards':      Icons.stars_rounded,
  'notifications':Icons.notifications_rounded,
  'pay_later':    Icons.payments_rounded,
  'receipt':      Icons.receipt_long_rounded,
  'shield':       Icons.shield_rounded,
  'gift':         Icons.card_giftcard_rounded,
  'cart':         Icons.shopping_cart_rounded,
  'school':       Icons.school_rounded,
  'medical':      Icons.medical_services_rounded,
  'sports':       Icons.sports_esports_rounded,
  'travel':       Icons.flight_rounded,
  'globe':        Icons.public_rounded,
  'gov':          Icons.account_balance_rounded,
  'apps':         Icons.apps_rounded,
};
IconData iconFromKey(String k) => kHomeIconMap[k] ?? Icons.apps_rounded;
Color colorFromHex(String hex) {
  var h = hex.replaceFirst('#', '').trim();
  if (h.length == 6) h = 'FF$h';
  return Color(int.tryParse(h, radix: 16) ?? 0xFF3B82F6);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override State<HomeScreen> createState() => _HomeScreenState();
}
class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  @override void initState() { super.initState(); context.read<HomeBloc>().add(HomeLoadEvent()); }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    body: IndexedStack(index: _tab, children: const [
      _HomeTab(), TransactionsScreen(), WalletScreen(), ProfileScreen()
    ]),
    bottomNavigationBar: Container(
      decoration: const BoxDecoration(color:AppColors.surface, border:Border(top:BorderSide(color:AppColors.divider))),
      child: SafeArea(child: SizedBox(height:60, child:Row(children:[
        _NavItem(icon:Icons.home_rounded,         label:'الرئيسية', active:_tab==0, onTap:()=>setState(()=>_tab=0)),
        _NavItem(icon:Icons.receipt_long_rounded, label:'المعاملات',active:_tab==1, onTap:()=>setState(()=>_tab=1)),
        _NavItem(icon:Icons.account_balance_wallet_rounded,label:'المحفظة',active:_tab==2,onTap:()=>setState(()=>_tab=2)),
        _NavItem(icon:Icons.person_rounded,       label:'حسابي',    active:_tab==3, onTap:()=>setState(()=>_tab=3)),
      ]))),
    ),
  );
}

class _NavItem extends StatelessWidget {
  final IconData icon; final String label; final bool active; final VoidCallback onTap;
  const _NavItem({required this.icon,required this.label,required this.active,required this.onTap});
  @override Widget build(BuildContext ctx) => Expanded(child:GestureDetector(onTap:onTap,
    child:Container(color:Colors.transparent,child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon, color:active?AppColors.primary:AppColors.textMuted, size:24),
      const SizedBox(height:3),
      Text(label,style:TS.cap.copyWith(color:active?AppColors.primary:AppColors.textMuted,fontWeight:active?FontWeight.w600:FontWeight.w400,fontSize:11)),
    ]))));
}

// ─── HOME TAB ─────────────────────────────────────────────
class _HomeTab extends StatelessWidget {
  const _HomeTab();
  @override Widget build(BuildContext context) => BlocBuilder<HomeBloc,HomeState>(
    builder:(ctx,state){
      if(state is HomeLoading) return const _HomeShimmer();
      if(state is HomeError) return AppErrorWidget(message:state.msg,onRetry:()=>ctx.read<HomeBloc>().add(HomeRefreshEvent()));
      if(state is HomeLoaded) return _HomeContent(state:state);
      return const SizedBox.shrink();
    });
}

class _HomeContent extends StatelessWidget {
  final HomeLoaded state;
  const _HomeContent({required this.state});

  // Fallback tiles used when the admin hasn't populated /home-tiles yet.
  static final _fallbackServices = [
    _Svc(S.recharge,   'TELECOM',      Icons.smartphone_rounded,            AppColors.telecom,     'recharge'),
    _Svc('فواتير موبايل','TELECOM',     Icons.phone_rounded,                 AppColors.telecom,     'bill_telecom'),
    _Svc(S.electricity,'ELECTRICITY',  Icons.bolt_rounded,                  AppColors.electricity, 'bill_elec'),
    _Svc(S.gas,        'GAS',          Icons.local_fire_department_rounded,  AppColors.gas,         'bill_gas'),
    _Svc(S.water,      'WATER',        Icons.water_drop_rounded,            AppColors.water,       'bill_water'),
    _Svc(S.internet,   'INTERNET',     Icons.wifi_rounded,                  AppColors.internet,    'bill_internet'),
    _Svc('InstaPay',   'INSTAPAY',     Icons.bolt_rounded,                  AppColors.primaryLight,'instapay'),
    _Svc('تحويل بنكي', 'BANK',         Icons.account_balance_rounded,        AppColors.b2b,         'bank_transfer'),
    _Svc('شركات',      'B2B',          Icons.business_rounded,              AppColors.b2b,         'b2b'),
    _Svc('فودافون كاش','VC',           Icons.account_balance_wallet_rounded,AppColors.telecom,     'vodafone_cash'),
    _Svc('مكافآت',     'REWARDS',      Icons.stars_rounded,                 AppColors.accent,      'rewards'),
    _Svc(S.notifTitle, 'NOTIF',        Icons.notifications_rounded,         AppColors.info,        'notifs'),
    _Svc('محفظتي',     'WALLET',       Icons.account_balance_wallet_rounded,AppColors.primary,     'wallet'),
    _Svc('الدفع الآجل','PAY_LATER',    Icons.payments_rounded,              AppColors.accent,      'pay_later'),
  ];

  List<_Svc> _resolve(List<HomeTileModel>? remote) {
    if (remote == null || remote.isEmpty) return _fallbackServices;
    return remote.map((t) => _Svc(t.label, t.category ?? t.route.toUpperCase(),
      iconFromKey(t.iconKey), colorFromHex(t.colorHex), t.route)).toList();
  }

  @override Widget build(BuildContext context) => RefreshIndicator(
    color:AppColors.primary,
    onRefresh:()async=>context.read<HomeBloc>().add(HomeRefreshEvent()),
    child:CustomScrollView(slivers:[
      // App Bar
      SliverAppBar(
        backgroundColor:AppColors.primary, floating:true, snap:true,
        toolbarHeight:65,
        flexibleSpace:FlexibleSpaceBar(
          titlePadding:const EdgeInsets.symmetric(horizontal:D.md,vertical:10),
          title:Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[
            Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisSize:MainAxisSize.min,children:[
              Text('${S.hello}، ${state.user.fullName.split(' ').first}',style:TS.h3.copyWith(color:Colors.white)),
              Text('مرحباً بعودتك 👋',style:TS.cap.copyWith(color:Colors.white70)),
            ]),
            Row(children:[
              BlocBuilder<NotifBloc,NotifState>(builder:(ctx,ns){
                final unread=ns is NotifLoaded?ns.unread:0;
                return Stack(children:[
                  IconButton(icon:const Icon(Icons.notifications_outlined,color:Colors.white,size:26),onPressed:()=>context.push(AppRoutes.notifs)),
                  if(unread>0)Positioned(top:8,right:8,child:Container(width:10,height:10,decoration:const BoxDecoration(color:Colors.red,shape:BoxShape.circle))),
                ]);
              }),
              GestureDetector(onTap:()=>context.push(AppRoutes.profile),
                child:CircleAvatar(radius:18,backgroundColor:Colors.white.withOpacity(0.2),
                  child:Text(state.user.initials,style:TS.bodyM.copyWith(color:Colors.white,fontSize:13)))),
            ]),
          ])),
      ),

      SliverToBoxAdapter(child:Column(children:[
        const SizedBox(height:D.md),
        // Wallet Card
        WalletCard(balance:state.user.walletBalance,points:state.user.pointsBalance,tierAr:state.user.tierAr,onTopUp:()=>context.push(AppRoutes.wallet)),
        const SizedBox(height:D.lg),

        // B2B Banner (if B2B user)
        if(state.user.isB2B)Padding(padding:const EdgeInsets.symmetric(horizontal:D.md),child:GestureDetector(
          onTap:()=>context.push(AppRoutes.b2bDash),
          child:Container(padding:const EdgeInsets.all(D.md),
            decoration:BoxDecoration(gradient:AppGradients.b2b,borderRadius:BorderRadius.circular(D.r16)),
            child:Row(children:[
              const Icon(Icons.business_rounded,color:Colors.white,size:28),const SizedBox(width:12),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text('حساب الشركات',style:TS.bodyM.copyWith(color:Colors.white)),
                Text('اضغط لعرض لوحة الشركات',style:TS.cap.copyWith(color:Colors.white70)),
              ])),
              const Icon(Icons.arrow_forward_ios_rounded,color:Colors.white,size:16),
            ])))),
        if(state.user.isB2B)const SizedBox(height:D.md),

        // Services Grid — admin-driven via /home-tiles, falls back to hardcoded list.
        SectionHeader(title:S.services),
        const SizedBox(height:D.md),
        FutureBuilder<List<HomeTileModel>>(
          future: HomeTilesRepo().list().catchError((_) => <HomeTileModel>[]),
          builder: (ctx, snap) {
            final services = _resolve(snap.data);
            return Padding(padding:const EdgeInsets.symmetric(horizontal:D.md),
              child:GridView.builder(
                shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),
                gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:4,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:0.85),
                itemCount:services.length,
                itemBuilder:(_,i){
                  final s=services[i];
                  final eligible = state.user.payLaterEligible;
                  final gated = (s.route=='vodafone_cash' || s.route=='pay_later') && !eligible;
                  return GestureDetector(onTap:(){
                    final r=s.route;
                    if (r=='vodafone_cash' && !eligible) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('الخدمة غير متاحة لحسابك. يرجى تفعيل الدفع الآجل أولاً.'),
                        backgroundColor: AppColors.error,
                      ));
                      return;
                    }
                    if (r=='vodafone_cash') { context.push(AppRoutes.bill, extra:'TELECOM'); return; }
                    if (r=='pay_later')      { context.push(AppRoutes.payLater); return; }
                    if (r=='instapay')       { context.push(AppRoutes.instapay); return; }
                    if (r=='bank_transfer')  { context.push(AppRoutes.bankTransfer); return; }
                    if(r=='recharge') context.push(AppRoutes.recharge);
                    else if(r=='my_requests') context.push(AppRoutes.myRequests);
                    else if(r=='wallet') context.push(AppRoutes.wallet);
                    else if(r=='rewards') context.push(AppRoutes.rewards);
                    else if(r=='notifs') context.push(AppRoutes.notifs);
                    else if(r=='b2b') context.push(state.user.isB2B?AppRoutes.b2bDash:AppRoutes.b2bApply);
                    // Bills now route to the smart-billing flow (admin sets amount)
                    else if(r.startsWith('bill_')) context.push(AppRoutes.smartBilling, extra:s.cat);
                    else context.push(AppRoutes.bill, extra:s.cat);
                  },child:Opacity(opacity: gated ? 0.4 : 1.0, child: Column(mainAxisSize:MainAxisSize.min,children:[
                    Container(width:56,height:56,decoration:BoxDecoration(color:s.color.withOpacity(0.1),borderRadius:BorderRadius.circular(14),border:Border.all(color:s.color.withOpacity(0.2))),child:Icon(s.icon,color:s.color,size:26)),
                    const SizedBox(height:5),
                    Text(s.label,style:TS.cap.copyWith(fontSize:10),textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis),
                  ])));
                }));
          },
        ),

        const SizedBox(height:D.lg),
        // Recent
        SectionHeader(title:S.recentTx,action:S.seeAll,onAction:()=>context.push(AppRoutes.txList)),
        const SizedBox(height:D.md),
        if(state.recent.isEmpty)
          EmptyState(title:S.noTxYet,subtitle:'قم بأول معاملة الآن',icon:Icons.receipt_long_outlined,action:S.recharge,onAction:()=>context.push(AppRoutes.recharge))
        else
          ListView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:state.recent.length,itemBuilder:(_,i)=>TxTile(tx:state.recent[i],onTap:()=>context.push(AppRoutes.txList))),
        const SizedBox(height:D.xxl),
      ])),
    ]));
}

class _Svc { final String label,cat,route; final IconData icon; final Color color; const _Svc(this.label,this.cat,this.icon,this.color,this.route); }

class _HomeShimmer extends StatelessWidget {
  const _HomeShimmer();
  @override Widget build(BuildContext context) => ListView(padding:const EdgeInsets.all(D.md),children:[
    const SizedBox(height:80),
    Shimmer(width:double.infinity,height:130,radius:18),const SizedBox(height:20),
    Shimmer(width:100,height:18),const SizedBox(height:14),
    Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:List.generate(4,(_)=>Shimmer(width:70,height:72,radius:14))),
    const SizedBox(height:20),Shimmer(width:100,height:18),const SizedBox(height:14),
    ...List.generate(3,(_)=>Padding(padding:const EdgeInsets.only(bottom:10),child:Shimmer(width:double.infinity,height:64,radius:10))),
  ]);
}
