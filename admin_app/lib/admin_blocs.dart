import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'admin_core.dart';
import 'admin_api.dart';

// ── Auth Bloc ──────────────────────────────────────────────
abstract class AdminAuthEvent extends Equatable { const AdminAuthEvent(); @override List<Object?> get props=>[]; }
class AdminLoginEvent  extends AdminAuthEvent { final String email,pass; const AdminLoginEvent(this.email,this.pass); @override List<Object?> get props=>[email]; }
class AdminCheckEvent  extends AdminAuthEvent {}
class AdminLogoutEvent extends AdminAuthEvent {}

abstract class AdminAuthState extends Equatable { const AdminAuthState(); @override List<Object?> get props=>[]; }
class AdminAuthInitial  extends AdminAuthState {}
class AdminAuthLoading  extends AdminAuthState {}
class AdminAuthLoggedIn extends AdminAuthState { final AdminModel admin; const AdminAuthLoggedIn(this.admin); @override List<Object?> get props=>[admin]; }
class AdminAuthLoggedOut extends AdminAuthState {}
class AdminAuthError    extends AdminAuthState { final String msg; const AdminAuthError(this.msg); @override List<Object?> get props=>[msg]; }

class AdminAuthBloc extends Bloc<AdminAuthEvent,AdminAuthState> {
  final _repo = AdminAuthRepo();
  AdminAuthBloc():super(AdminAuthInitial()){on<AdminLoginEvent>(_login);on<AdminCheckEvent>(_check);on<AdminLogoutEvent>(_logout);}
  Future<void> _check(AdminCheckEvent e,Emitter<AdminAuthState> emit)async{emit(AdminAuthLoading());final ok=await _repo.isLoggedIn();emit(ok?const AdminAuthLoggedIn(AdminModel(id:'',email:'',fullName:'Admin',role:'SUPER_ADMIN')):AdminAuthLoggedOut());}
  Future<void> _login(AdminLoginEvent e,Emitter<AdminAuthState> emit)async{emit(AdminAuthLoading());try{final r=await _repo.login(e.email,e.pass);emit(AdminAuthLoggedIn(r.admin));}on AdminApiException catch(ex){emit(AdminAuthError(ex.message));}}
  Future<void> _logout(AdminLogoutEvent e,Emitter<AdminAuthState> emit)async{await _repo.logout();emit(AdminAuthLoggedOut());}
}

// ── Dashboard Bloc ─────────────────────────────────────────
abstract class DashEvent extends Equatable { const DashEvent(); @override List<Object?> get props=>[]; }
class DashLoadEvent extends DashEvent {}

abstract class DashState extends Equatable { const DashState(); @override List<Object?> get props=>[]; }
class DashInitial extends DashState {}
class DashLoading extends DashState {}
class DashLoaded  extends DashState { final DashboardStats stats; final Map<String,dynamic> analytics; const DashLoaded({required this.stats,required this.analytics}); @override List<Object?> get props=>[stats]; }
class DashError   extends DashState { final String msg; const DashError(this.msg); @override List<Object?> get props=>[msg]; }

class DashBloc extends Bloc<DashEvent,DashState> {
  DashBloc():super(DashInitial()){on<DashLoadEvent>(_load);}
  Future<void> _load(DashLoadEvent e,Emitter<DashState> emit)async{emit(DashLoading());try{final res=await Future.wait([AdminDashboardRepo().getStats(),AdminDashboardRepo().getAnalytics()]);emit(DashLoaded(stats:res[0] as DashboardStats,analytics:res[1] as Map<String,dynamic>));}on AdminApiException catch(ex){emit(DashError(ex.message));}}
}

// ── Requests Bloc ──────────────────────────────────────────
abstract class ReqEvent extends Equatable { const ReqEvent(); @override List<Object?> get props=>[]; }
class ReqLoadEvent     extends ReqEvent { final String? status,type,search; const ReqLoadEvent({this.status,this.type,this.search}); @override List<Object?> get props=>[status,type,search]; }
class ReqMoreEvent     extends ReqEvent {}
class ReqRefreshEvent  extends ReqEvent {}
class ReqNewEvent      extends ReqEvent { final RequestItem req; const ReqNewEvent(this.req); @override List<Object?> get props=>[req]; }
class ReqUpdatedEvent  extends ReqEvent { final String id,status; const ReqUpdatedEvent(this.id,this.status); @override List<Object?> get props=>[id,status]; }
class ReqAssignEvent   extends ReqEvent { final String id; const ReqAssignEvent(this.id); @override List<Object?> get props=>[id]; }
class ReqCompleteEvent extends ReqEvent { final String id; final String? ref,note; const ReqCompleteEvent(this.id,{this.ref,this.note}); @override List<Object?> get props=>[id]; }
class ReqFailEvent     extends ReqEvent { final String id,reason; const ReqFailEvent(this.id,this.reason); @override List<Object?> get props=>[id]; }
class ReqRefundEvent   extends ReqEvent { final String id; const ReqRefundEvent(this.id); @override List<Object?> get props=>[id]; }
class ReqEscalateEvent extends ReqEvent { final String id,reason; const ReqEscalateEvent(this.id,this.reason); @override List<Object?> get props=>[id]; }

abstract class ReqState extends Equatable { const ReqState(); @override List<Object?> get props=>[]; }
class ReqInitial extends ReqState {}
class ReqLoading extends ReqState {}
class ReqLoaded  extends ReqState { final List<RequestItem> items; final bool hasMore; final String? status,type; const ReqLoaded({required this.items,required this.hasMore,this.status,this.type}); @override List<Object?> get props=>[items,hasMore,status,type]; }
class ReqError   extends ReqState { final String msg; const ReqError(this.msg); @override List<Object?> get props=>[msg]; }
class ReqProcessing extends ReqState { final List<RequestItem> items; const ReqProcessing(this.items); @override List<Object?> get props=>[items]; }

class ReqBloc extends Bloc<ReqEvent,ReqState> {
  final _repo=AdminRequestsRepo(); int _page=1; String? _status,_type,_search;
  ReqBloc():super(ReqInitial()){on<ReqLoadEvent>(_load);on<ReqMoreEvent>(_more);on<ReqRefreshEvent>((e,em)=>_load(ReqLoadEvent(status:_status,type:_type,search:_search),em));on<ReqNewEvent>(_new);on<ReqUpdatedEvent>(_updated);on<ReqAssignEvent>(_assign);on<ReqCompleteEvent>(_complete);on<ReqFailEvent>(_fail);on<ReqRefundEvent>(_refund);on<ReqEscalateEvent>(_escalate);}
  Future<void> _load(ReqLoadEvent e,Emitter<ReqState> emit)async{emit(ReqLoading());_page=1;_status=e.status;_type=e.type;_search=e.search;try{final r=await _repo.getRequests(page:1,status:_status,type:_type,search:_search);emit(ReqLoaded(items:r.data,hasMore:r.hasNext,status:_status,type:_type));}on AdminApiException catch(ex){emit(ReqError(ex.message));}}
  Future<void> _more(ReqMoreEvent e,Emitter<ReqState> emit)async{
    final c=state; if(c is!ReqLoaded||!c.hasMore)return;
    _page++;
    try{
      final r=await _repo.getRequests(page:_page,status:_status,type:_type);
      emit(ReqLoaded(items:[...c.items,...r.data],hasMore:r.hasNext,status:_status,type:_type));
    } catch(ex,st){ print('[ReqBloc.more] $ex\n$st'); _page--; }
  }
  Future<void> _new(ReqNewEvent e,Emitter<ReqState> emit)async{final c=state;if(c is ReqLoaded)emit(ReqLoaded(items:[e.req,...c.items],hasMore:c.hasMore,status:c.status,type:c.type));}
  Future<void> _updated(ReqUpdatedEvent e,Emitter<ReqState> emit)async{final c=state;if(c is!ReqLoaded)return;final items=c.items.map((r)=>r.id==e.id?RequestItem.fromJson({...{'id':r.id,'type':r.type,'status':e.status,'amount':r.amount,'fee':r.fee,'totalAmount':r.totalAmount,'createdAt':r.createdAt.toIso8601String()}}):r).toList();emit(ReqLoaded(items:items,hasMore:c.hasMore,status:c.status,type:c.type));}
  Future<void> _action(String id,Future<void> Function() action,Emitter<ReqState> emit)async{final c=state;if(c is ReqLoaded)emit(ReqProcessing(c.items));try{await action();add(ReqRefreshEvent());}on AdminApiException catch(ex){emit(ReqError(ex.message));}}
  Future<void> _assign  (ReqAssignEvent   e,Emitter<ReqState> em)async=>_action(e.id,()=>_repo.assign(e.id),em);
  Future<void> _complete(ReqCompleteEvent e,Emitter<ReqState> em)async=>_action(e.id,()=>_repo.complete(e.id,ref:e.ref,note:e.note),em);
  Future<void> _fail    (ReqFailEvent     e,Emitter<ReqState> em)async=>_action(e.id,()=>_repo.fail(e.id,e.reason),em);
  Future<void> _refund  (ReqRefundEvent   e,Emitter<ReqState> em)async=>_action(e.id,()=>_repo.refund(e.id),em);
  Future<void> _escalate(ReqEscalateEvent e,Emitter<ReqState> em)async=>_action(e.id,()=>_repo.escalate(e.id,e.reason),em);
}

// ── B2B Bloc ───────────────────────────────────────────────
abstract class AdminB2BEvent extends Equatable { const AdminB2BEvent(); @override List<Object?> get props=>[]; }
class AdminB2BLoadApplicationsEvent extends AdminB2BEvent {}
class AdminB2BLoadAccountsEvent     extends AdminB2BEvent { final String? status; const AdminB2BLoadAccountsEvent({this.status}); @override List<Object?> get props=>[status]; }
class AdminB2BApproveEvent  extends AdminB2BEvent { final String id; final double limit; final int? termDays; const AdminB2BApproveEvent(this.id,this.limit,{this.termDays}); @override List<Object?> get props=>[id,limit]; }
class AdminB2BRejectEvent   extends AdminB2BEvent { final String id,reason; const AdminB2BRejectEvent(this.id,this.reason); @override List<Object?> get props=>[id]; }
class AdminB2BUpdateLimitEvent extends AdminB2BEvent { final String id; final double limit; const AdminB2BUpdateLimitEvent(this.id,this.limit); @override List<Object?> get props=>[id]; }
class AdminB2BSuspendEvent  extends AdminB2BEvent { final String id; const AdminB2BSuspendEvent(this.id); @override List<Object?> get props=>[id]; }
class AdminB2BSettleInvoiceEvent extends AdminB2BEvent { final String id; const AdminB2BSettleInvoiceEvent(this.id); @override List<Object?> get props=>[id]; }

abstract class AdminB2BState extends Equatable { const AdminB2BState(); @override List<Object?> get props=>[]; }
class AdminB2BInitial  extends AdminB2BState {}
class AdminB2BLoading  extends AdminB2BState {}
class AdminB2BApplicationsLoaded extends AdminB2BState { final List<B2BAccount> applications; const AdminB2BApplicationsLoaded(this.applications); @override List<Object?> get props=>[applications]; }
class AdminB2BAccountsLoaded extends AdminB2BState { final List<B2BAccount> accounts; const AdminB2BAccountsLoaded(this.accounts); @override List<Object?> get props=>[accounts]; }
class AdminB2BActionDone extends AdminB2BState {}
class AdminB2BError    extends AdminB2BState { final String msg; const AdminB2BError(this.msg); @override List<Object?> get props=>[msg]; }

class AdminB2BBloc extends Bloc<AdminB2BEvent,AdminB2BState> {
  final _repo=AdminB2BRepo();
  AdminB2BBloc():super(AdminB2BInitial()){on<AdminB2BLoadApplicationsEvent>(_apps);on<AdminB2BLoadAccountsEvent>(_accounts);on<AdminB2BApproveEvent>(_approve);on<AdminB2BRejectEvent>(_reject);on<AdminB2BUpdateLimitEvent>(_limit);on<AdminB2BSuspendEvent>(_suspend);on<AdminB2BSettleInvoiceEvent>(_settle);}
  Future<void> _apps(AdminB2BLoadApplicationsEvent e,Emitter<AdminB2BState> emit)async{emit(AdminB2BLoading());try{final r=await _repo.getApplications();emit(AdminB2BApplicationsLoaded(r.data));}on AdminApiException catch(ex){emit(AdminB2BError(ex.message));}}
  Future<void> _accounts(AdminB2BLoadAccountsEvent e,Emitter<AdminB2BState> emit)async{emit(AdminB2BLoading());try{final r=await _repo.getAccounts(status:e.status);emit(AdminB2BAccountsLoaded(r.data));}on AdminApiException catch(ex){emit(AdminB2BError(ex.message));}}
  Future<void> _approve(AdminB2BApproveEvent e,Emitter<AdminB2BState> emit)async{try{await _repo.approve(e.id,e.limit,termDays:e.termDays??30);emit(AdminB2BActionDone());add(AdminB2BLoadApplicationsEvent());}on AdminApiException catch(ex){emit(AdminB2BError(ex.message));}}
  Future<void> _reject(AdminB2BRejectEvent e,Emitter<AdminB2BState> emit)async{try{await _repo.reject(e.id,e.reason);emit(AdminB2BActionDone());add(AdminB2BLoadApplicationsEvent());}on AdminApiException catch(ex){emit(AdminB2BError(ex.message));}}
  Future<void> _limit(AdminB2BUpdateLimitEvent e,Emitter<AdminB2BState> emit)async{try{await _repo.updateCreditLimit(e.id,e.limit);emit(AdminB2BActionDone());add(AdminB2BLoadAccountsEvent());}on AdminApiException catch(ex){emit(AdminB2BError(ex.message));}}
  Future<void> _suspend(AdminB2BSuspendEvent e,Emitter<AdminB2BState> emit)async{try{await _repo.suspend(e.id);emit(AdminB2BActionDone());add(AdminB2BLoadAccountsEvent());}on AdminApiException catch(ex){emit(AdminB2BError(ex.message));}}
  Future<void> _settle(AdminB2BSettleInvoiceEvent e,Emitter<AdminB2BState> emit)async{try{await _repo.settleInvoice(e.id);emit(AdminB2BActionDone());}on AdminApiException catch(ex){emit(AdminB2BError(ex.message));}}
}

// ── Notifications Bloc ─────────────────────────────────────
abstract class AdminNotifEvent extends Equatable { const AdminNotifEvent(); @override List<Object?> get props=>[]; }
class AdminNotifLoadEvent    extends AdminNotifEvent {}
class AdminNotifMarkAllEvent extends AdminNotifEvent {}

abstract class AdminNotifState extends Equatable { const AdminNotifState(); @override List<Object?> get props=>[]; }
class AdminNotifInitial extends AdminNotifState {}
class AdminNotifLoading extends AdminNotifState {}
class AdminNotifLoaded  extends AdminNotifState { final List<AdminNotification> items; final int unread; const AdminNotifLoaded({required this.items,required this.unread}); @override List<Object?> get props=>[items,unread]; }
class AdminNotifError   extends AdminNotifState { final String msg; const AdminNotifError(this.msg); @override List<Object?> get props=>[msg]; }

class AdminNotifBloc extends Bloc<AdminNotifEvent,AdminNotifState> {
  final _repo=AdminNotifsRepo();
  AdminNotifBloc():super(AdminNotifInitial()){on<AdminNotifLoadEvent>(_load);on<AdminNotifMarkAllEvent>(_mark);}
  Future<void> _load(AdminNotifLoadEvent e,Emitter<AdminNotifState> emit)async{emit(AdminNotifLoading());try{final res=await _repo.getNotifications();final items=(res['data'] as List<dynamic>).map((n)=>AdminNotification.fromJson(n as Map<String,dynamic>)).toList();final unread=(res['unreadCount'] as int?)??items.where((n)=>!n.isRead).length;emit(AdminNotifLoaded(items:items,unread:unread));}on AdminApiException catch(ex){emit(AdminNotifError(ex.message));}}
  Future<void> _mark(AdminNotifMarkAllEvent e,Emitter<AdminNotifState> emit)async{await _repo.markAllRead();add(AdminNotifLoadEvent());}
}

// ── Services Bloc ──────────────────────────────────────────
abstract class AdminServicesEvent extends Equatable { const AdminServicesEvent(); @override List<Object?> get props=>[]; }
class AdminServicesLoadEvent         extends AdminServicesEvent {}
class AdminServicesToggleProviderEvent extends AdminServicesEvent { final String id; final bool active; const AdminServicesToggleProviderEvent(this.id,this.active); @override List<Object?> get props=>[id]; }
class AdminServicesUpdateFeeEvent extends AdminServicesEvent { final String subId; final double fixed,pct; const AdminServicesUpdateFeeEvent(this.subId,this.fixed,this.pct); @override List<Object?> get props=>[subId]; }

abstract class AdminServicesState extends Equatable { const AdminServicesState(); @override List<Object?> get props=>[]; }
class AdminServicesInitial extends AdminServicesState {}
class AdminServicesLoading extends AdminServicesState {}
class AdminServicesLoaded  extends AdminServicesState { final List<ServiceProvider> providers; const AdminServicesLoaded(this.providers); @override List<Object?> get props=>[providers]; }
class AdminServicesError   extends AdminServicesState { final String msg; const AdminServicesError(this.msg); @override List<Object?> get props=>[msg]; }

class AdminServicesBloc extends Bloc<AdminServicesEvent,AdminServicesState> {
  final _repo=AdminServicesRepo();
  AdminServicesBloc():super(AdminServicesInitial()){on<AdminServicesLoadEvent>(_load);on<AdminServicesToggleProviderEvent>(_toggle);on<AdminServicesUpdateFeeEvent>(_updateFee);}
  Future<void> _load(AdminServicesLoadEvent e,Emitter<AdminServicesState> emit)async{emit(AdminServicesLoading());try{emit(AdminServicesLoaded(await _repo.getProviders()));}on AdminApiException catch(ex){emit(AdminServicesError(ex.message));}}
  Future<void> _toggle(AdminServicesToggleProviderEvent e,Emitter<AdminServicesState> emit)async{try{await _repo.updateProvider(e.id,{'isActive':e.active});add(AdminServicesLoadEvent());}on AdminApiException catch(ex){emit(AdminServicesError(ex.message));}}
  Future<void> _updateFee(AdminServicesUpdateFeeEvent e,Emitter<AdminServicesState> emit)async{try{await _repo.updateSubService(e.subId,{'fixedFee':e.fixed,'percentageFee':e.pct});add(AdminServicesLoadEvent());}on AdminApiException catch(ex){emit(AdminServicesError(ex.message));}}
}
