import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'admin_core.dart';

// ── Exception ──────────────────────────────────────────────
class AdminApiException implements Exception {
  final String message; final int? statusCode;
  const AdminApiException(this.message,{this.statusCode});
  factory AdminApiException.fromDio(DioException e){
    if(e.type==DioExceptionType.connectionTimeout||e.error is SocketException) return const AdminApiException('تعذر الاتصال',statusCode:0);
    final d=e.response?.data;
    final msg=d is Map?(d['message'] as String?)??' خطأ في الخادم':'خطأ في الخادم';
    return AdminApiException(msg,statusCode:e.response?.statusCode);
  }
  bool get isUnauthorized => statusCode==401;
  @override String toString()=>message;
}

// ── Admin API Client ───────────────────────────────────────
class AdminApiClient {
  AdminApiClient._();
  static final AdminApiClient instance = AdminApiClient._();
  late final Dio _dio;
  final _sec = const FlutterSecureStorage(aOptions:AndroidOptions(encryptedSharedPreferences:true));
  bool _ready = false;

  void init(){
    if(_ready)return; _ready=true;
    _dio=Dio(BaseOptions(baseUrl:AdminConstants.baseUrl,connectTimeout:const Duration(seconds:30),receiveTimeout:const Duration(seconds:30),headers:{'Content-Type':'application/json','Accept':'application/json'}));
    _dio.interceptors.add(InterceptorsWrapper(onRequest:(opts,handler)async{final tok=await _sec.read(key:AdminConstants.tokenKey);if(tok!=null)opts.headers['Authorization']='Bearer $tok';return handler.next(opts);}));
    if(kDebugMode)_dio.interceptors.add(LogInterceptor(requestBody:true,responseBody:true,logPrint:(o)=>debugPrint('[ADMIN API] $o')));
  }

  Future<Map<String,dynamic>> get(String path,{Map<String,dynamic>? params})async{try{final r=await _dio.get(path,queryParameters:params);return r.data as Map<String,dynamic>;}on DioException catch(e){throw AdminApiException.fromDio(e);}}
  Future<Map<String,dynamic>> post(String path,{Map<String,dynamic>? body})async{try{final r=await _dio.post(path,data:body);return r.data as Map<String,dynamic>;}on DioException catch(e){throw AdminApiException.fromDio(e);}}
  Future<Map<String,dynamic>> put(String path,{Map<String,dynamic>? body})async{try{final r=await _dio.put(path,data:body);return r.data as Map<String,dynamic>;}on DioException catch(e){throw AdminApiException.fromDio(e);}}
  Future<void> saveToken(String t)=>_sec.write(key:AdminConstants.tokenKey,value:t);
  Future<String?> getToken()=>_sec.read(key:AdminConstants.tokenKey);
  Future<void> clearToken()=>_sec.delete(key:AdminConstants.tokenKey);
}

// ── Admin Repositories ─────────────────────────────────────
class AdminAuthRepo {
  final _c = AdminApiClient.instance;
  Future<AdminLoginResponse> login(String email,String password)async{
    final res=await _c.post('/auth/admin/login',body:{'email':email,'password':password});
    final m=AdminLoginResponse.fromJson(res['data'] as Map<String,dynamic>);
    await _c.saveToken(m.token); return m;
  }
  Future<void> logout()async{await _c.clearToken();}
  Future<bool> isLoggedIn()async{final t=await _c.getToken();return t!=null;}
  Future<void> updateDeviceToken(String t)=>_c.put('/auth/admin/device-token',body:{'deviceToken':t});
}

class AdminRequestsRepo {
  final _c = AdminApiClient.instance;
  Future<PagedData<RequestItem>> getRequests({int page=1,String? status,String? type,String? search})async{
    final res=await _c.get('/admin/requests',params:{'page':page,'limit':20,if(status!=null)'status':status,if(type!=null)'type':type,if(search!=null&&search.isNotEmpty)'search':search});
    return PagedData.fromJson(res,RequestItem.fromJson);
  }
  Future<RequestItem> getRequest(String id)async{final res=await _c.get('/admin/requests/$id');return RequestItem.fromJson(res['data'] as Map<String,dynamic>);}
  Future<void> assign(String id)=>_c.put('/admin/requests/$id/assign');
  Future<void> start(String id)=>_c.put('/admin/requests/$id/start');
  Future<void> complete(String id,{String? ref,String? note})=>_c.put('/admin/requests/$id/complete',body:{if(ref!=null)'externalRef':ref,if(note!=null)'adminNote':note});
  Future<void> fail(String id,String reason)=>_c.put('/admin/requests/$id/fail',body:{'reason':reason});
  Future<void> refund(String id,{String? reason})=>_c.put('/admin/requests/$id/refund',body:{if(reason!=null)'reason':reason});
  Future<void> escalate(String id,String reason,{String level='LEVEL_1'})=>_c.put('/admin/requests/$id/escalate',body:{'reason':reason,'level':level});
  Future<void> addNote(String id,String note)=>_c.put('/admin/requests/$id/note',body:{'note':note});
}

class AdminDashboardRepo {
  final _c = AdminApiClient.instance;
  Future<DashboardStats> getStats()async{final res=await _c.get('/admin/dashboard');return DashboardStats.fromJson(res['data'] as Map<String,dynamic>);}
  Future<Map<String,dynamic>> getAnalytics({int days=30})async{final res=await _c.get('/admin/analytics/overview',params:{'days':days});return res['data'] as Map<String,dynamic>;}
}

class AdminServicesRepo {
  final _c = AdminApiClient.instance;
  Future<List<ServiceProvider>> getProviders()async{final res=await _c.get('/services/admin/providers');return(res['data'] as List<dynamic>).map((e)=>ServiceProvider.fromJson(e as Map<String,dynamic>)).toList();}
  Future<void> createProvider(Map<String,dynamic> data)=>_c.post('/services/admin/providers',body:data);
  Future<void> updateProvider(String id,Map<String,dynamic> data)=>_c.put('/services/admin/providers/$id',body:data);
  Future<void> deleteProvider(String id)=>_c.put('/services/admin/providers/$id',body:{'isActive':false});
  Future<void> createSubService(String providerId,Map<String,dynamic> data)=>_c.post('/services/admin/providers/$providerId/sub-services',body:data);
  Future<void> updateSubService(String id,Map<String,dynamic> data)=>_c.put('/services/admin/sub-services/$id',body:data);
  Future<void> deleteSubService(String id)=>_c.put('/services/admin/sub-services/$id',body:{'isActive':false});
}

class AdminB2BRepo {
  final _c = AdminApiClient.instance;
  Future<PagedData<B2BAccount>> getApplications({int page=1})async{final res=await _c.get('/b2b/admin/applications',params:{'page':page,'status':'PENDING_APPROVAL'});return PagedData.fromJson(res,B2BAccount.fromJson);}
  Future<PagedData<B2BAccount>> getAccounts({int page=1,String? status})async{final res=await _c.get('/b2b/admin/accounts',params:{'page':page,'limit':20,if(status!=null)'status':status});return PagedData.fromJson(res,B2BAccount.fromJson);}
  Future<B2BAccount> getAccount(String id)async{final res=await _c.get('/b2b/admin/accounts/$id');return B2BAccount.fromJson(res['data'] as Map<String,dynamic>);}
  Future<void> approve(String id,double creditLimit,{int termDays=30})=>_c.put('/b2b/admin/applications/$id/approve',body:{'creditLimit':creditLimit,'paymentTermDays':termDays});
  Future<void> reject(String id,String reason)=>_c.put('/b2b/admin/applications/$id/reject',body:{'reason':reason});
  Future<void> updateCreditLimit(String id,double newLimit)=>_c.put('/b2b/admin/accounts/$id/credit-limit',body:{'creditLimit':newLimit});
  Future<void> suspend(String id)=>_c.put('/b2b/admin/accounts/$id/suspend');
  Future<void> settleInvoice(String invoiceId)=>_c.put('/b2b/admin/pay-laters/$invoiceId/mark-settled');
}

class AdminUsersRepo {
  final _c = AdminApiClient.instance;
  Future<PagedData<AdminUser>> getUsers({int page=1,String? search,String? status})async{final res=await _c.get('/admin/users',params:{'page':page,'limit':20,if(search!=null&&search.isNotEmpty)'search':search,if(status!=null)'status':status});return PagedData.fromJson(res,AdminUser.fromJson);}
  Future<Map<String,dynamic>> getUser(String id)async{final res=await _c.get('/admin/users/$id');return res['data'] as Map<String,dynamic>;}
  Future<void> updateStatus(String id,String status)=>_c.put('/admin/users/$id/status',body:{'status':status});
}

class AdminNotifsRepo {
  final _c = AdminApiClient.instance;
  Future<Map<String,dynamic>> getNotifications({int page=1})=>_c.get('/admin/notifications',params:{'page':page,'limit':30});
  Future<void> markAllRead()=>_c.put('/admin/notifications/read-all');
  Future<void> markRead(String id)=>_c.put('/admin/notifications/$id/read');
}

// ── Admin Socket ───────────────────────────────────────────
class AdminSocketService {
  AdminSocketService._();
  static final AdminSocketService instance = AdminSocketService._();
  io.Socket? _socket; bool _connected=false;
  final ValueNotifier<RequestItem?> newRequest = ValueNotifier(null);
  final ValueNotifier<Map<String,dynamic>?> requestUpdated = ValueNotifier(null);
  final ValueNotifier<Map<String,dynamic>?> slaBreach = ValueNotifier(null);
  final ValueNotifier<Map<String,dynamic>?> b2bApplication = ValueNotifier(null);
  final ValueNotifier<int> unreadNotifs = ValueNotifier(0);

  Future<void> connect()async{
    if(_connected)return;
    final token=await AdminApiClient.instance.getToken(); if(token==null)return;
    _socket=io.io(AdminConstants.socketUrl,io.OptionBuilder().setTransports(['websocket']).setAuth({'token':token}).enableAutoConnect().enableReconnection().build());
    _socket!.onConnect((_){_connected=true;debugPrint('[ADMIN SOCKET] Connected');});
    _socket!.onDisconnect((_){_connected=false;});
    _socket!.on('new_request',(d) async {
      try {
        final payload = Map<String,dynamic>.from(d as Map);
        final id = (payload['requestId'] ?? payload['id']) as String?;
        if (id == null) return;
        newRequest.value = await AdminRequestsRepo().getRequest(id);
      } catch (e) { debugPrint('[ADMIN SOCKET] new_request parse failed: $e'); }
    });
    _socket!.on('request_updated',(d)=>requestUpdated.value=Map<String,dynamic>.from(d as Map));
    _socket!.on('sla_breach',(d)=>slaBreach.value=Map<String,dynamic>.from(d as Map));
    _socket!.on('b2b_application',(d)=>b2bApplication.value=Map<String,dynamic>.from(d as Map));
    _socket!.connect();
  }
  void disconnect(){_socket?.disconnect();_connected=false;}
  bool get isConnected=>_connected;
}
