import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'admin_core.dart';
import 'admin_notification_service.dart';

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

  Map<String,dynamic> _ensureMap(dynamic d){if(d is Map<String,dynamic>)return d;if(d is Map)return Map<String,dynamic>.from(d);throw const AdminApiException('Invalid server response',statusCode:0);}
  Future<Map<String,dynamic>> get(String path,{Map<String,dynamic>? params})async{try{final r=await _dio.get(path,queryParameters:params);return _ensureMap(r.data);}on DioException catch(e){throw AdminApiException.fromDio(e);}}
  Future<Map<String,dynamic>> post(String path,{Map<String,dynamic>? body})async{try{final r=await _dio.post(path,data:body);return _ensureMap(r.data);}on DioException catch(e){throw AdminApiException.fromDio(e);}}
  Future<Map<String,dynamic>> put(String path,{Map<String,dynamic>? body})async{try{final r=await _dio.put(path,data:body);return _ensureMap(r.data);}on DioException catch(e){throw AdminApiException.fromDio(e);}}
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

  // Multipart image upload — returns the public image URL stored on the entity.
  Future<String> uploadProviderLogo(String id, String filePath) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
    });
    final r = await AdminApiClient.instance._dio.post('/services/admin/providers/$id/logo', data: form);
    final d = (r.data as Map<String,dynamic>)['data'] as Map<String,dynamic>;
    return d['logoUrl'] as String;
  }
  Future<String> uploadSubServiceImage(String id, String filePath) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
    });
    final r = await AdminApiClient.instance._dio.post('/services/admin/sub-services/$id/image', data: form);
    final d = (r.data as Map<String,dynamic>)['data'] as Map<String,dynamic>;
    return d['imageUrl'] as String;
  }
}

// ── Payment Numbers ───────────────────────────────────────
class AdminPaymentNumbersRepo {
  final _c = AdminApiClient.instance;
  Future<List<Map<String,dynamic>>> list() async {
    final res = await _c.get('/admin/payment-numbers');
    return ((res['data'] as List<dynamic>?) ?? []).cast<Map<String,dynamic>>();
  }
  Future<Map<String,dynamic>> create(Map<String,dynamic> body) async {
    final res = await _c.post('/admin/payment-numbers', body: body);
    return res['data'] as Map<String,dynamic>;
  }
  Future<void> update(String id, Map<String,dynamic> body) =>
    _c.put('/admin/payment-numbers/$id', body: body);
  Future<void> delete(String id) async {
    try { await _c._dio.delete('/admin/payment-numbers/$id'); }
    on DioException catch (e) { throw AdminApiException.fromDio(e); }
  }
}

// ── Admin Settings ────────────────────────────────────────
class AdminSettingsRepo {
  final _c = AdminApiClient.instance;
  Future<List<Map<String,dynamic>>> list() async {
    final res = await _c.get('/admin/settings');
    return ((res['data'] as List<dynamic>?) ?? []).cast<Map<String,dynamic>>();
  }
  Future<void> updateBulk(Map<String,dynamic> settings) =>
    _c.put('/admin/settings', body: {'settings': settings});
}

// ── Admin Clients ─────────────────────────────────────────
class AdminClientsRepo {
  final _c = AdminApiClient.instance;
  Future<PagedData<Map<String,dynamic>>> search({String? search, int page = 1}) async {
    final res = await _c.get('/admin/clients', params: {
      'page': page, 'limit': 20, if (search != null && search.isNotEmpty) 'search': search,
    });
    final list = ((res['data'] as List<dynamic>?) ?? []).cast<Map<String,dynamic>>();
    final pagination = (res['pagination'] as Map<String,dynamic>?) ?? {};
    return PagedData<Map<String,dynamic>>(
      data: list,
      total: (pagination['total'] as int?) ?? list.length,
      page: (pagination['page'] as int?) ?? 1,
      limit: (pagination['limit'] as int?) ?? 20,
      hasNext: (pagination['hasNextPage'] as bool?) ?? false,
    );
  }
  Future<Map<String,dynamic>> addBalance(String userId, double amount, {String? note}) async {
    final res = await _c.post('/admin/clients/$userId/add-balance', body: {
      'amount': amount, if (note != null && note.isNotEmpty) 'note': note,
    });
    return res['data'] as Map<String,dynamic>;
  }
}

// ── Request Chat + Set-Amount ─────────────────────────────
class AdminMessagesRepo {
  final _c = AdminApiClient.instance;
  Future<List<Map<String,dynamic>>> list(String requestId) async {
    final res = await _c.get('/requests/$requestId/messages');
    return ((res['data'] as List<dynamic>?) ?? []).cast<Map<String,dynamic>>();
  }
  Future<Map<String,dynamic>> send(String requestId, String body) async {
    final res = await _c.post('/admin/requests/$requestId/messages', body: {'body': body});
    return res['data'] as Map<String,dynamic>;
  }
}

extension AdminRequestsRepoSetAmount on AdminRequestsRepo {
  Future<Map<String,dynamic>> setAmount(String requestId, double amount) async {
    final c = AdminApiClient.instance;
    final res = await c.put('/admin/requests/$requestId/set-amount', body: {'amount': amount});
    return (res['data'] as Map<String,dynamic>?) ?? {};
  }
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
        final amount = payload['amount']?.toString() ?? '';
        final type = payload['type']?.toString() ?? '';
        AdminNotificationService.instance.show(
          title: '🔔 طلب جديد', body: '$type — $amount ج.م', payload: id,
        );
      } catch (e) { debugPrint('[ADMIN SOCKET] new_request parse failed: $e'); }
    });
    _socket!.on('request_updated',(d){
      final m=Map<String,dynamic>.from(d as Map);
      requestUpdated.value=m;
    });
    _socket!.on('sla_breach',(d){
      final m=Map<String,dynamic>.from(d as Map);
      slaBreach.value=m;
      AdminNotificationService.instance.show(
        title: '⚠️ تجاوز SLA', body: 'طلب تجاوز مدة المعالجة المسموحة', payload: m['requestId']?.toString(),
      );
    });
    _socket!.on('b2b_application',(d){
      final m=Map<String,dynamic>.from(d as Map);
      b2bApplication.value=m;
      AdminNotificationService.instance.show(
        title: '🏢 طلب B2B جديد', body: m['companyName']?.toString() ?? 'طلب اعتماد حساب أعمال', payload: (m['accountId'] ?? m['applicationId'])?.toString(),
      );
    });
    _socket!.connect();
  }
  void disconnect(){_socket?.disconnect();_connected=false;}
  bool get isConnected=>_connected;
}
