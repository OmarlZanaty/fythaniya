import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/core/network/api_client.dart';
import 'package:fythaniya/data/models/models.dart';

// ════════════════════════════════════════════════════════
//  AUTH BLOC
// ════════════════════════════════════════════════════════
abstract class AuthEvent extends Equatable { const AuthEvent(); @override List<Object?> get props=>[]; }
class AuthCheckEvent    extends AuthEvent {}
class AuthLoginEvent    extends AuthEvent { final String phone,pass; const AuthLoginEvent(this.phone,this.pass); @override List<Object?> get props=>[phone]; }
class AuthRegisterEvent extends AuthEvent { final String phone,name,pass; const AuthRegisterEvent(this.phone,this.name,this.pass); @override List<Object?> get props=>[phone,name]; }
class AuthForgotEvent   extends AuthEvent { final String phone; const AuthForgotEvent(this.phone); @override List<Object?> get props=>[phone]; }
class AuthResetEvent    extends AuthEvent { final String phone,otp,pw; const AuthResetEvent(this.phone,this.otp,this.pw); @override List<Object?> get props=>[phone]; }
class AuthLogoutEvent   extends AuthEvent {}
class AuthUpdateUserEvent extends AuthEvent { final UserModel user; const AuthUpdateUserEvent(this.user); @override List<Object?> get props=>[user]; }

abstract class AuthState extends Equatable { const AuthState(); @override List<Object?> get props=>[]; }
class AuthInitial         extends AuthState {}
class AuthLoading         extends AuthState {}
class AuthAuthenticated   extends AuthState { final UserModel user; const AuthAuthenticated(this.user); @override List<Object?> get props=>[user]; }
class AuthUnauthenticated extends AuthState {}
class AuthOtpSent         extends AuthState { final String phone; const AuthOtpSent(this.phone); @override List<Object?> get props=>[phone]; }
class AuthResetSuccess    extends AuthState {}
class AuthError           extends AuthState { final String msg; const AuthError(this.msg); @override List<Object?> get props=>[msg]; }

class AuthBloc extends Bloc<AuthEvent,AuthState> {
  final _repo = AuthRepo();
  AuthBloc():super(AuthInitial()) {
    on<AuthCheckEvent>   (_check);
    on<AuthLoginEvent>   (_login);
    on<AuthRegisterEvent>(_register);
    on<AuthForgotEvent>  (_forgot);
    on<AuthResetEvent>   (_reset);
    on<AuthLogoutEvent>  (_logout);
    on<AuthUpdateUserEvent>(_updateUser);
  }
  Future<void> _check(AuthCheckEvent e, Emitter<AuthState> emit) async {
    emit(AuthLoading());
    try {
      final u = await _repo.getMe();
      emit(u != null ? AuthAuthenticated(u) : AuthUnauthenticated());
    } on ApiException catch (ex) {
      // 401 → really unauthenticated. Other errors (network, server) → surface so the splash screen can retry.
      if (ex.isUnauthorized) { emit(AuthUnauthenticated()); }
      else { emit(AuthError(ex.message)); }
    } catch (ex, st) {
      print('[AuthBloc.check] $ex\n$st');
      emit(AuthError('تعذر التحقق من الجلسة'));
    }
  }
  Future<void> _login(AuthLoginEvent e, Emitter<AuthState> emit) async { emit(AuthLoading()); try { final r=await _repo.login(e.phone,e.pass); emit(AuthAuthenticated(r.user)); } on ApiException catch(ex) { emit(AuthError(ex.message)); } }
  Future<void> _register(AuthRegisterEvent e, Emitter<AuthState> emit) async { emit(AuthLoading()); try { final r=await _repo.register(e.phone,e.name,e.pass); emit(AuthAuthenticated(r.user)); } on ApiException catch(ex) { emit(AuthError(ex.message)); } }
  Future<void> _forgot(AuthForgotEvent e, Emitter<AuthState> emit) async { emit(AuthLoading()); try { await _repo.forgotPassword(e.phone); emit(AuthOtpSent(e.phone)); } on ApiException catch(ex) { emit(AuthError(ex.message)); } }
  Future<void> _reset(AuthResetEvent e, Emitter<AuthState> emit) async { emit(AuthLoading()); try { await _repo.resetPassword(e.phone,e.otp,e.pw); emit(AuthResetSuccess()); } on ApiException catch(ex) { emit(AuthError(ex.message)); } }
  Future<void> _logout(AuthLogoutEvent e, Emitter<AuthState> emit) async { await _repo.logout(); final p=await SharedPreferences.getInstance(); await p.clear(); emit(AuthUnauthenticated()); }
  Future<void> _updateUser(AuthUpdateUserEvent e, Emitter<AuthState> emit) async { emit(AuthAuthenticated(e.user)); }
}

// ════════════════════════════════════════════════════════
//  HOME BLOC
// ════════════════════════════════════════════════════════
abstract class HomeEvent extends Equatable { const HomeEvent(); @override List<Object?> get props=>[]; }
class HomeLoadEvent    extends HomeEvent {}
class HomeRefreshEvent extends HomeEvent {}

abstract class HomeState extends Equatable { const HomeState(); @override List<Object?> get props=>[]; }
class HomeInitial extends HomeState {}
class HomeLoading extends HomeState {}
class HomeLoaded  extends HomeState { final UserModel user; final Map<String,List<ServiceProviderModel>> categories; final List<TransactionModel> recent; const HomeLoaded({required this.user,required this.categories,required this.recent}); @override List<Object?> get props=>[user,categories,recent]; }
class HomeError   extends HomeState { final String msg; const HomeError(this.msg); @override List<Object?> get props=>[msg]; }

class HomeBloc extends Bloc<HomeEvent,HomeState> {
  HomeBloc():super(HomeInitial()) { on<HomeLoadEvent>(_load); on<HomeRefreshEvent>(_load); }
  Future<void> _load(HomeEvent e, Emitter<HomeState> emit) async {
    if (e is HomeLoadEvent) emit(HomeLoading());
    try {
      final results = await Future.wait([UserRepo().getProfile(), ServicesRepo().getCategories(), UserRepo().getTransactions(page:1)]);
      emit(HomeLoaded(user:results[0] as UserModel, categories:results[1] as Map<String,List<ServiceProviderModel>>, recent:(results[2] as PagedResult<TransactionModel>).data.take(5).toList()));
    } on ApiException catch(ex) { emit(HomeError(ex.message)); }
    catch(ex, st) { emit(HomeError('Home load failed: $ex')); print('[HomeBloc] $ex\n$st'); }
  }
}

// ════════════════════════════════════════════════════════
//  TRANSACTIONS BLOC
// ════════════════════════════════════════════════════════
abstract class TxEvent extends Equatable { const TxEvent(); @override List<Object?> get props=>[]; }
class TxLoadEvent   extends TxEvent { final String? status; const TxLoadEvent({this.status}); @override List<Object?> get props=>[status]; }
class TxFilterEvent extends TxEvent { final String? status; const TxFilterEvent(this.status); @override List<Object?> get props=>[status]; }
class TxMoreEvent   extends TxEvent {}

abstract class TxState extends Equatable { const TxState(); @override List<Object?> get props=>[]; }
class TxInitial extends TxState {}
class TxLoading extends TxState {}
class TxLoaded  extends TxState { final List<TransactionModel> items; final bool hasMore; final String? filter; const TxLoaded({required this.items,required this.hasMore,this.filter}); @override List<Object?> get props=>[items,hasMore,filter]; }
class TxError   extends TxState { final String msg; const TxError(this.msg); @override List<Object?> get props=>[msg]; }

class TxBloc extends Bloc<TxEvent,TxState> {
  int _page=1; String? _filter;
  TxBloc():super(TxInitial()) { on<TxLoadEvent>(_load); on<TxFilterEvent>(_filterEvt); on<TxMoreEvent>(_more); }
  Future<void> _load(TxLoadEvent e, Emitter<TxState> emit) async { emit(TxLoading()); _page=1; _filter=e.status; try { final r=await UserRepo().getTransactions(page:1,status:_filter); emit(TxLoaded(items:r.data,hasMore:r.hasNext,filter:_filter)); } on ApiException catch(ex) { emit(TxError(ex.message)); } }
  Future<void> _filterEvt(TxFilterEvent e, Emitter<TxState> emit) async { _filter=e.status; add(TxLoadEvent(status:_filter)); }
  Future<void> _more(TxMoreEvent e, Emitter<TxState> emit) async {
    final c = state;
    if (c is! TxLoaded || !c.hasMore) return;
    _page++;
    try {
      final r = await UserRepo().getTransactions(page: _page, status: _filter);
      emit(TxLoaded(items: [...c.items, ...r.data], hasMore: r.hasNext, filter: _filter));
    } catch (ex, st) {
      print('[TxBloc.more] $ex\n$st');
      _page--; // roll back page so user can retry by scrolling again
    }
  }
}

// ════════════════════════════════════════════════════════
//  RECHARGE BLOC
// ════════════════════════════════════════════════════════
abstract class RechargeEvent extends Equatable { const RechargeEvent(); @override List<Object?> get props=>[]; }
class RechargeInitEvent  extends RechargeEvent {}
class RechargeSubmitEvent extends RechargeEvent { final String providerId,subServiceId,phone; final double amount; const RechargeSubmitEvent({required this.providerId,required this.subServiceId,required this.phone,required this.amount}); @override List<Object?> get props=>[providerId,subServiceId,phone,amount]; }

abstract class RechargeState extends Equatable { const RechargeState(); @override List<Object?> get props=>[]; }
class RechargeInitial    extends RechargeState {}
class RechargeLoading    extends RechargeState {}
class RechargeLoaded     extends RechargeState { final List<ServiceProviderModel> providers; const RechargeLoaded(this.providers); @override List<Object?> get props=>[providers]; }
class RechargeSubmitting extends RechargeState {}
class RechargeSuccess    extends RechargeState { final RequestModel req; const RechargeSuccess(this.req); @override List<Object?> get props=>[req]; }
class RechargeError      extends RechargeState { final String msg; const RechargeError(this.msg); @override List<Object?> get props=>[msg]; }

class RechargeBloc extends Bloc<RechargeEvent,RechargeState> {
  RechargeBloc():super(RechargeInitial()) { on<RechargeInitEvent>(_load); on<RechargeSubmitEvent>(_submit); }
  Future<void> _load(RechargeInitEvent e, Emitter<RechargeState> emit) async { emit(RechargeLoading()); try { emit(RechargeLoaded(await ServicesRepo().getProviders(category:'TELECOM'))); } on ApiException catch(ex) { emit(RechargeError(ex.message)); } }
  Future<void> _submit(RechargeSubmitEvent e, Emitter<RechargeState> emit) async { emit(RechargeSubmitting()); try { final r=await UserRepo().createRequest(serviceProviderId:e.providerId,subServiceId:e.subServiceId,type:'MOBILE_RECHARGE',amount:e.amount,phoneNumber:e.phone); emit(RechargeSuccess(r)); } on ApiException catch(ex) { emit(RechargeError(ex.message)); } }
}

// ════════════════════════════════════════════════════════
//  BILL BLOC
// ════════════════════════════════════════════════════════
abstract class BillEvent extends Equatable { const BillEvent(); @override List<Object?> get props=>[]; }
class BillLoadEvent   extends BillEvent { final String category; const BillLoadEvent(this.category); @override List<Object?> get props=>[category]; }
class BillSubmitEvent extends BillEvent { final String providerId,subServiceId,accountNumber; final double amount; const BillSubmitEvent({required this.providerId,required this.subServiceId,required this.accountNumber,required this.amount}); @override List<Object?> get props=>[providerId,amount]; }

abstract class BillState extends Equatable { const BillState(); @override List<Object?> get props=>[]; }
class BillInitial    extends BillState {}
class BillLoading    extends BillState {}
class BillLoaded     extends BillState { final List<ServiceProviderModel> providers; final String category; const BillLoaded(this.providers,this.category); @override List<Object?> get props=>[providers,category]; }
class BillSubmitting extends BillState {}
class BillSuccess    extends BillState { final RequestModel req; const BillSuccess(this.req); @override List<Object?> get props=>[req]; }
class BillError      extends BillState { final String msg; const BillError(this.msg); @override List<Object?> get props=>[msg]; }

class BillBloc extends Bloc<BillEvent,BillState> {
  BillBloc():super(BillInitial()) { on<BillLoadEvent>(_load); on<BillSubmitEvent>(_submit); }
  Future<void> _load(BillLoadEvent e, Emitter<BillState> emit) async { emit(BillLoading()); try { emit(BillLoaded(await ServicesRepo().getProviders(category:e.category),e.category)); } on ApiException catch(ex) { emit(BillError(ex.message)); } }
  Future<void> _submit(BillSubmitEvent e, Emitter<BillState> emit) async { emit(BillSubmitting()); try { final r=await UserRepo().createRequest(serviceProviderId:e.providerId,subServiceId:e.subServiceId,type:'BILL_PAYMENT',amount:e.amount,accountNumber:e.accountNumber); emit(BillSuccess(r)); } on ApiException catch(ex) { emit(BillError(ex.message)); } }
}

// ════════════════════════════════════════════════════════
//  NOTIFICATIONS BLOC
// ════════════════════════════════════════════════════════
abstract class NotifEvent extends Equatable { const NotifEvent(); @override List<Object?> get props=>[]; }
class NotifLoadEvent    extends NotifEvent {}
class NotifMarkAllEvent extends NotifEvent {}
class NotifNewEvent     extends NotifEvent { final NotificationModel notif; const NotifNewEvent(this.notif); @override List<Object?> get props=>[notif]; }

abstract class NotifState extends Equatable { const NotifState(); @override List<Object?> get props=>[]; }
class NotifInitial extends NotifState {}
class NotifLoading extends NotifState {}
class NotifLoaded  extends NotifState { final List<NotificationModel> items; final int unread; const NotifLoaded({required this.items,required this.unread}); @override List<Object?> get props=>[items,unread]; }
class NotifError   extends NotifState { final String msg; const NotifError(this.msg); @override List<Object?> get props=>[msg]; }

class NotifBloc extends Bloc<NotifEvent,NotifState> {
  NotifBloc():super(NotifInitial()) { on<NotifLoadEvent>(_load); on<NotifMarkAllEvent>(_mark); on<NotifNewEvent>(_new); }
  Future<void> _load(NotifLoadEvent e, Emitter<NotifState> emit) async {
    emit(NotifLoading());
    try {
      final res = await UserRepo().getNotifications();
      final items = (res['data'] as List<dynamic>).map((e)=>NotificationModel.fromJson(e as Map<String,dynamic>)).toList();
      final unread = res['unreadCount'] as int? ?? items.where((n)=>!n.isRead).length;
      emit(NotifLoaded(items:items,unread:unread));
    } on ApiException catch(ex) { emit(NotifError(ex.message)); }
  }
  Future<void> _mark(NotifMarkAllEvent e, Emitter<NotifState> emit) async { await UserRepo().markAllNotifsRead(); add(NotifLoadEvent()); }
  Future<void> _new(NotifNewEvent e, Emitter<NotifState> emit) async {
    final c = state;
    if (c is NotifLoaded) emit(NotifLoaded(items:[e.notif,...c.items],unread:c.unread+1));
  }
}

// ════════════════════════════════════════════════════════
//  PROFILE BLOC
// ════════════════════════════════════════════════════════
abstract class ProfileEvent extends Equatable { const ProfileEvent(); @override List<Object?> get props=>[]; }
class ProfileLoadEvent       extends ProfileEvent {}
class ProfileUpdateEvent     extends ProfileEvent { final String name; final String? email; const ProfileUpdateEvent(this.name,this.email); @override List<Object?> get props=>[name,email]; }
class ProfileChangePassEvent extends ProfileEvent { final String cur,nw; const ProfileChangePassEvent(this.cur,this.nw); @override List<Object?> get props=>[]; }

abstract class ProfileState extends Equatable { const ProfileState(); @override List<Object?> get props=>[]; }
class ProfileInitial extends ProfileState {}
class ProfileLoading extends ProfileState {}
class ProfileLoaded  extends ProfileState { final UserModel user; const ProfileLoaded(this.user); @override List<Object?> get props=>[user]; }
class ProfileSaving  extends ProfileState { final UserModel user; const ProfileSaving(this.user); @override List<Object?> get props=>[user]; }
class ProfileSaved   extends ProfileState { final UserModel user; const ProfileSaved(this.user); @override List<Object?> get props=>[user]; }
class ProfileError   extends ProfileState { final String msg; const ProfileError(this.msg); @override List<Object?> get props=>[msg]; }

class ProfileBloc extends Bloc<ProfileEvent,ProfileState> {
  ProfileBloc():super(ProfileInitial()) { on<ProfileLoadEvent>(_load); on<ProfileUpdateEvent>(_update); on<ProfileChangePassEvent>(_pass); }
  Future<void> _load  (ProfileLoadEvent e, Emitter<ProfileState> emit) async { emit(ProfileLoading()); try { emit(ProfileLoaded(await UserRepo().getProfile())); } on ApiException catch(ex) { emit(ProfileError(ex.message)); } }
  Future<void> _update(ProfileUpdateEvent e, Emitter<ProfileState> emit) async { final c=state; if(c is ProfileLoaded)emit(ProfileSaving(c.user)); try { emit(ProfileSaved(await UserRepo().updateProfile(e.name,e.email))); } on ApiException catch(ex) { emit(ProfileError(ex.message)); } }
  Future<void> _pass  (ProfileChangePassEvent e, Emitter<ProfileState> emit) async { try { await UserRepo().changePassword(e.cur,e.nw); final c=state; if(c is ProfileLoaded)emit(ProfileSaved(c.user)); } on ApiException catch(ex) { emit(ProfileError(ex.message)); } }
}

// ════════════════════════════════════════════════════════
//  REWARDS BLOC
// ════════════════════════════════════════════════════════
abstract class RewardsEvent extends Equatable { const RewardsEvent(); @override List<Object?> get props=>[]; }
class RewardsLoadEvent   extends RewardsEvent {}
class RewardsRedeemEvent extends RewardsEvent { final String vId; const RewardsRedeemEvent(this.vId); @override List<Object?> get props=>[vId]; }

abstract class RewardsState extends Equatable { const RewardsState(); @override List<Object?> get props=>[]; }
class RewardsInitial   extends RewardsState {}
class RewardsLoading   extends RewardsState {}
class RewardsLoaded    extends RewardsState { final RewardsSummary summary; final List<VoucherModel> vouchers; const RewardsLoaded({required this.summary,required this.vouchers}); @override List<Object?> get props=>[summary,vouchers]; }
class RewardsRedeeming extends RewardsState {}
class RewardsRedeemed  extends RewardsState { final String code; const RewardsRedeemed(this.code); @override List<Object?> get props=>[code]; }
class RewardsError     extends RewardsState { final String msg; const RewardsError(this.msg); @override List<Object?> get props=>[msg]; }

class RewardsBloc extends Bloc<RewardsEvent,RewardsState> {
  RewardsBloc():super(RewardsInitial()) { on<RewardsLoadEvent>(_load); on<RewardsRedeemEvent>(_redeem); }
  Future<void> _load  (RewardsLoadEvent e, Emitter<RewardsState> emit) async { emit(RewardsLoading()); try { final res=await Future.wait([UserRepo().getRewards(),UserRepo().getVouchers()]); emit(RewardsLoaded(summary:res[0] as RewardsSummary,vouchers:res[1] as List<VoucherModel>)); } on ApiException catch(ex) { emit(RewardsError(ex.message)); } }
  Future<void> _redeem(RewardsRedeemEvent e, Emitter<RewardsState> emit) async { emit(RewardsRedeeming()); try { final d=await UserRepo().redeemVoucher(e.vId); emit(RewardsRedeemed(d['code'] as String)); } on ApiException catch(ex) { emit(RewardsError(ex.message)); } }
}

// ════════════════════════════════════════════════════════
//  WALLET BLOC
// ════════════════════════════════════════════════════════
abstract class WalletEvent extends Equatable { const WalletEvent(); @override List<Object?> get props=>[]; }
class WalletLoadEvent extends WalletEvent {}

abstract class WalletState extends Equatable { const WalletState(); @override List<Object?> get props=>[]; }
class WalletInitial extends WalletState {}
class WalletLoading extends WalletState {}
class WalletLoaded  extends WalletState { final UserModel user; final List<TransactionModel> txs; final List<SpendingRecord> spending; const WalletLoaded({required this.user,required this.txs,required this.spending}); @override List<Object?> get props=>[user,txs,spending]; }
class WalletError   extends WalletState { final String msg; const WalletError(this.msg); @override List<Object?> get props=>[msg]; }

class WalletBloc extends Bloc<WalletEvent,WalletState> {
  WalletBloc():super(WalletInitial()) { on<WalletLoadEvent>(_load); }
  Future<void> _load(WalletLoadEvent e, Emitter<WalletState> emit) async {
    emit(WalletLoading());
    try {
      final res = await Future.wait([UserRepo().getProfile(), UserRepo().getTransactions(page:1), UserRepo().getSpending()]);
      emit(WalletLoaded(user:res[0] as UserModel, txs:(res[1] as PagedResult<TransactionModel>).data, spending:res[2] as List<SpendingRecord>));
    } on ApiException catch(ex) { emit(WalletError(ex.message)); }
  }
}

// ════════════════════════════════════════════════════════
//  B2B BLOC
// ════════════════════════════════════════════════════════
abstract class B2BEvent extends Equatable { const B2BEvent(); @override List<Object?> get props=>[]; }
class B2BLoadEvent    extends B2BEvent {}
class B2BApplyEvent   extends B2BEvent { final String companyName,taxId,contactName,contactPhone; final double requestedLimit; final String? commercialReg; const B2BApplyEvent({required this.companyName,required this.taxId,required this.contactName,required this.contactPhone,required this.requestedLimit,this.commercialReg}); @override List<Object?> get props=>[companyName,taxId]; }
class B2BRequestEvent extends B2BEvent { final String providerId,accountNumber; final double amount; final String? subServiceId,phoneNumber; const B2BRequestEvent({required this.providerId,required this.accountNumber,required this.amount,this.subServiceId,this.phoneNumber}); @override List<Object?> get props=>[providerId,amount]; }
class B2BLoadInvoicesEvent extends B2BEvent { final String? status; const B2BLoadInvoicesEvent({this.status}); @override List<Object?> get props=>[status]; }
class B2BSettleEvent  extends B2BEvent { final String payLaterId; const B2BSettleEvent(this.payLaterId); @override List<Object?> get props=>[payLaterId]; }

abstract class B2BState extends Equatable { const B2BState(); @override List<Object?> get props=>[]; }
class B2BInitial     extends B2BState {}
class B2BLoading     extends B2BState {}
class B2BLoaded      extends B2BState { final B2BAccountModel account; const B2BLoaded(this.account); @override List<Object?> get props=>[account]; }
class B2BNoAccount   extends B2BState {}
class B2BApplying    extends B2BState {}
class B2BApplied     extends B2BState { final B2BAccountModel account; const B2BApplied(this.account); @override List<Object?> get props=>[account]; }
class B2BSubmitting  extends B2BState {}
class B2BRequestDone extends B2BState { final Map<String,dynamic> result; const B2BRequestDone(this.result); @override List<Object?> get props=>[result]; }
class B2BInvoicesLoaded extends B2BState { final List<B2BPayLaterModel> invoices; final bool hasMore; const B2BInvoicesLoaded({required this.invoices,required this.hasMore}); @override List<Object?> get props=>[invoices,hasMore]; }
class B2BError       extends B2BState { final String msg; const B2BError(this.msg); @override List<Object?> get props=>[msg]; }

class B2BBloc extends Bloc<B2BEvent,B2BState> {
  final _repo = B2BRepo();
  B2BBloc():super(B2BInitial()) {
    on<B2BLoadEvent>        (_load);
    on<B2BApplyEvent>       (_apply);
    on<B2BRequestEvent>     (_request);
    on<B2BLoadInvoicesEvent>(_loadInvoices);
    on<B2BSettleEvent>      (_settle);
  }
  Future<void> _load(B2BLoadEvent e, Emitter<B2BState> emit) async {
    emit(B2BLoading());
    try { emit(B2BLoaded(await _repo.getAccount())); }
    on ApiException catch(ex) { if(ex.statusCode==404) emit(B2BNoAccount()); else emit(B2BError(ex.message)); }
  }
  Future<void> _apply(B2BApplyEvent e, Emitter<B2BState> emit) async {
    emit(B2BApplying());
    try { emit(B2BApplied(await _repo.applyForB2B(companyName:e.companyName,taxId:e.taxId,contactName:e.contactName,contactPhone:e.contactPhone,requestedLimit:e.requestedLimit,commercialReg:e.commercialReg))); }
    on ApiException catch(ex) { emit(B2BError(ex.message)); }
  }
  Future<void> _request(B2BRequestEvent e, Emitter<B2BState> emit) async {
    emit(B2BSubmitting());
    try { final r=await _repo.createB2BRequest(serviceProviderId:e.providerId,subServiceId:e.subServiceId,amount:e.amount,accountNumber:e.accountNumber,phoneNumber:e.phoneNumber); emit(B2BRequestDone(r)); }
    on ApiException catch(ex) { emit(B2BError(ex.message)); }
  }
  Future<void> _loadInvoices(B2BLoadInvoicesEvent e, Emitter<B2BState> emit) async {
    emit(B2BLoading());
    try { final r=await _repo.getPayLaters(status:e.status); emit(B2BInvoicesLoaded(invoices:r.data,hasMore:r.hasNext)); }
    on ApiException catch(ex) { emit(B2BError(ex.message)); }
  }
  Future<void> _settle(B2BSettleEvent e, Emitter<B2BState> emit) async {
    try { await _repo.settleInvoice(e.payLaterId); add(B2BLoadInvoicesEvent()); }
    on ApiException catch(ex) { emit(B2BError(ex.message)); }
  }
}
