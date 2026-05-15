import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';

// ── Exception ─────────────────────────────────────────────
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  const ApiException(this.message, {this.statusCode});
  factory ApiException.fromDio(DioException e) {
    if (e.type==DioExceptionType.connectionTimeout||e.type==DioExceptionType.receiveTimeout||e.error is SocketException) {
      return const ApiException(S.networkErr, statusCode: 0);
    }
    final d = e.response?.data;
    final msg = d is Map ? (d['message'] as String?)??S.serverErr : S.serverErr;
    return ApiException(msg, statusCode: e.response?.statusCode);
  }
  bool get isUnauthorized => statusCode==401;
  @override String toString() => message;
}

// ── API Client ─────────────────────────────────────────────
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();
  late final Dio _dio;
  final _sec = const FlutterSecureStorage(aOptions: AndroidOptions(encryptedSharedPreferences:true));
  bool _ready = false;

  void init() {
    if (_ready) return; _ready = true;
    _dio = Dio(BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(milliseconds:AppConstants.connectMs),
      receiveTimeout: const Duration(milliseconds:AppConstants.receiveMs),
      headers: {'Content-Type':'application/json','Accept':'application/json'},
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (opts, handler) async {
        final tok = await _sec.read(key:AppConstants.tokenKey);
        if (tok!=null) opts.headers['Authorization']='Bearer $tok';
        return handler.next(opts);
      },
      onError: (err, handler) async {
        if (err.response?.statusCode==401) {
          final ok = await _tryRefresh();
          if (ok) {
            final tok = await _sec.read(key:AppConstants.tokenKey);
            err.requestOptions.headers['Authorization']='Bearer $tok';
            try { final r=await _dio.fetch(err.requestOptions); return handler.resolve(r); } catch (e) { debugPrint('[ApiClient] retry-after-refresh failed: $e'); }
          }
          await clearAll();
        }
        return handler.next(err);
      },
    ));
    if (kDebugMode) _dio.interceptors.add(LogInterceptor(requestBody:true,responseBody:true,logPrint:(o)=>debugPrint('[API] $o')));
  }

  Future<bool> _tryRefresh() async {
    try {
      final ref = await _sec.read(key:AppConstants.refreshKey);
      if (ref==null) return false;
      final res = await Dio().post('${AppConstants.baseUrl}/auth/refresh-token', data:{'refreshToken':ref});
      final d = res.data['data'] as Map<String,dynamic>;
      await _sec.write(key:AppConstants.tokenKey, value:d['accessToken'] as String);
      if (d['refreshToken']!=null) await _sec.write(key:AppConstants.refreshKey, value:d['refreshToken'] as String);
      return true;
    } catch (e) { debugPrint('[ApiClient] refresh failed: $e'); return false; }
  }

  Future<Map<String,dynamic>> get(String path, {Map<String,dynamic>? params}) async {
    try { final r=await _dio.get(path,queryParameters:params); return r.data as Map<String,dynamic>; }
    on DioException catch(e) { throw ApiException.fromDio(e); }
  }
  Future<Map<String,dynamic>> post(String path, {Map<String,dynamic>? body}) async {
    try { final r=await _dio.post(path,data:body); return r.data as Map<String,dynamic>; }
    on DioException catch(e) { throw ApiException.fromDio(e); }
  }
  Future<Map<String,dynamic>> put(String path, {Map<String,dynamic>? body}) async {
    try { final r=await _dio.put(path,data:body); return r.data as Map<String,dynamic>; }
    on DioException catch(e) { throw ApiException.fromDio(e); }
  }
  Future<void> del(String path) async {
    try { await _dio.delete(path); } on DioException catch(e) { throw ApiException.fromDio(e); }
  }
  Future<void> saveTokens(String a, String r) => Future.wait([
    _sec.write(key:AppConstants.tokenKey,value:a),
    _sec.write(key:AppConstants.refreshKey,value:r),
  ]);
  Future<String?> getToken() => _sec.read(key:AppConstants.tokenKey);
  Future<void> clearAll() => Future.wait([
    _sec.delete(key:AppConstants.tokenKey),
    _sec.delete(key:AppConstants.refreshKey),
  ]);
}

// ── Auth Repo ──────────────────────────────────────────────
class AuthRepo {
  final _c = ApiClient.instance;

  Future<AuthResponse> register(String phone, String fullName, String password) async {
    final res = await _c.post('/auth/register', body:{'phone':phone,'fullName':fullName,'password':password});
    final m = AuthResponse.fromJson(res['data'] as Map<String,dynamic>);
    await _c.saveTokens(m.accessToken, m.refreshToken);
    return m;
  }

  Future<AuthResponse> login(String phone, String password) async {
    final res = await _c.post('/auth/login', body:{'phone':phone,'password':password});
    final m = AuthResponse.fromJson(res['data'] as Map<String,dynamic>);
    await _c.saveTokens(m.accessToken, m.refreshToken);
    return m;
  }

  Future<void> forgotPassword(String phone) =>
    _c.post('/auth/forgot-password', body:{'phone':phone});

  Future<void> resetPassword(String phone, String otp, String pw) =>
    _c.post('/auth/reset-password', body:{'phone':phone,'otp':otp,'newPassword':pw});

  Future<void> logout() async {
    try { await _c.post('/auth/logout'); } catch (e) { debugPrint('[AuthRepo] server logout failed (clearing local anyway): $e'); }
    await _c.clearAll();
  }

  Future<UserModel?> getMe() async {
    final tok = await _c.getToken();
    if (tok==null) return null;
    try {
      final res = await _c.get('/user/profile');
      return UserModel.fromJson(res['data'] as Map<String,dynamic>);
    } on ApiException catch (e) {
      // Only treat 401 as "not authenticated". Network/server errors should bubble so the caller can retry.
      if (e.isUnauthorized) return null;
      rethrow;
    }
  }

  Future<void> updateDeviceToken(String token) =>
    _c.put('/auth/device-token', body:{'deviceToken':token});
}

// ── Services Repo ──────────────────────────────────────────
class ServicesRepo {
  final _c = ApiClient.instance;

  Future<List<ServiceProviderModel>> getProviders({String? category}) async {
    final res = await _c.get('/services/providers', params: category!=null?{'category':category}:null);
    return (res['data'] as List<dynamic>).map((e)=>ServiceProviderModel.fromJson(e as Map<String,dynamic>)).toList();
  }

  Future<Map<String,List<ServiceProviderModel>>> getCategories() async {
    final res = await _c.get('/services/categories');
    final raw = res['data'] as Map<String,dynamic>;
    return raw.map((k,v)=>MapEntry(k,(v as List<dynamic>).map((e)=>ServiceProviderModel.fromJson(e as Map<String,dynamic>)).toList()));
  }
}

// ── User Repo ──────────────────────────────────────────────
class UserRepo {
  final _c = ApiClient.instance;

  Future<UserModel> getProfile() async {
    final res = await _c.get('/user/profile');
    return UserModel.fromJson(res['data'] as Map<String,dynamic>);
  }

  Future<UserModel> updateProfile(String fullName, String? email) async {
    final res = await _c.put('/user/profile', body:{'fullName':fullName, if(email!=null&&email.isNotEmpty)'email':email});
    return UserModel.fromJson(res['data'] as Map<String,dynamic>);
  }

  Future<void> changePassword(String cur, String nw) =>
    _c.put('/user/change-password', body:{'currentPassword':cur,'newPassword':nw});

  Future<PagedResult<TransactionModel>> getTransactions({int page=1, String? status}) async {
    final res = await _c.get('/user/transactions', params:{'page':page,'limit':AppConstants.pageSize, if(status!=null&&status!='ALL')'status':status});
    return PagedResult.fromJson(res, TransactionModel.fromJson);
  }

  Future<RequestModel> createRequest({required String serviceProviderId, String? subServiceId,
    required String type, required double amount, String? accountNumber, String? phoneNumber,
    String? paymentMethod, String? proofImageUrl}) async {
    final res = await _c.post('/user/requests', body:{
      'serviceProviderId':serviceProviderId, if(subServiceId!=null)'subServiceId':subServiceId,
      'type':type, 'amount':amount,
      if(accountNumber!=null)'accountNumber':accountNumber,
      if(phoneNumber!=null)'phoneNumber':phoneNumber,
      if(paymentMethod!=null)'paymentMethod':paymentMethod,
      if(proofImageUrl!=null)'proofImageUrl':proofImageUrl,
    });
    return RequestModel.fromJson(res['data'] as Map<String,dynamic>);
  }

  Future<PagedResult<RequestModel>> getRequests({int page=1, String? status}) async {
    final res = await _c.get('/user/requests', params:{'page':page,'limit':AppConstants.pageSize, if(status!=null)'status':status});
    return PagedResult.fromJson(res, RequestModel.fromJson);
  }

  Future<Map<String,dynamic>> getNotifications({int page=1, bool? isRead}) async {
    final params = <String,dynamic>{'page':page,'limit':30};
    if (isRead!=null) params['isRead'] = isRead.toString();
    return _c.get('/user/notifications', params:params);
  }

  Future<void> markAllNotifsRead() => _c.put('/user/notifications/read-all');
  Future<void> markNotifRead(String id) => _c.put('/user/notifications/$id/read');

  Future<RewardsSummary> getRewards() async {
    final res = await _c.get('/user/rewards');
    return RewardsSummary.fromJson(res['data'] as Map<String,dynamic>);
  }

  Future<List<VoucherModel>> getVouchers() async {
    final res = await _c.get('/user/vouchers');
    return (res['data'] as List<dynamic>).map((e)=>VoucherModel.fromJson(e as Map<String,dynamic>)).toList();
  }

  Future<Map<String,dynamic>> redeemVoucher(String vId) async {
    final res = await _c.post('/user/vouchers/redeem', body:{'voucherId':vId});
    return res['data'] as Map<String,dynamic>;
  }

  // Wallet topup is now a REQUEST that requires admin approval after the user uploads payment proof.
  // Returns the new request id so the client can immediately upload a proof image.
  Future<String> walletTopupRequest({required double amount, String paymentMethod='BANK_TRANSFER'}) async {
    final res = await _c.post('/user/wallet/topup', body:{'amount':amount,'paymentMethod':paymentMethod});
    final d = res['data'] as Map<String,dynamic>;
    return d['requestId'] as String;
  }

  // Request activation of pay-later (admin must approve).
  Future<String> requestPayLaterActivation() async {
    final res = await _c.post('/user/pay-later/activate');
    final d = res['data'] as Map<String,dynamic>;
    return d['requestId'] as String;
  }

  // Upload payment proof for a request. Returns the public image URL.
  Future<String> uploadProof(String requestId, String filePath) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath, filename: filePath.split(RegExp(r'[\\/]')).last),
    });
    final r = await ApiClient.instance._dio.post('/user/requests/$requestId/proof', data: form);
    final d = (r.data as Map<String,dynamic>)['data'] as Map<String,dynamic>;
    return d['proofImageUrl'] as String;
  }

  Future<Map<String,dynamic>> walletTransfer({required String toPhone, required double amount, String? note}) async {
    final res = await _c.post('/user/wallet/transfer', body:{
      'toPhone': toPhone, 'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
    });
    final d = res['data'] as Map<String,dynamic>;
    return {
      'newBalance': double.tryParse(d['newBalance'].toString()) ?? 0,
      'recipientName': d['recipientName'] as String?,
    };
  }

  Future<List<SpendingRecord>> getSpending({int? year}) async {
    final res = await _c.get('/user/spending', params:{'year':year??DateTime.now().year});
    return (res['data'] as List<dynamic>).map((e)=>SpendingRecord.fromJson(e as Map<String,dynamic>)).toList();
  }
}

// ── B2B Repo ───────────────────────────────────────────────
class B2BRepo {
  final _c = ApiClient.instance;

  Future<B2BAccountModel> applyForB2B({required String companyName, required String taxId,
    String? commercialReg, required String contactName, required String contactPhone,
    required double requestedLimit}) async {
    final res = await _c.post('/b2b/apply', body:{
      'companyName':companyName,'taxId':taxId,'contactName':contactName,
      'contactPhone':contactPhone,'requestedLimit':requestedLimit,
      if(commercialReg!=null)'commercialReg':commercialReg,
    });
    return B2BAccountModel.fromJson(res['data'] as Map<String,dynamic>);
  }

  Future<B2BAccountModel> getAccount() async {
    final res = await _c.get('/b2b/account');
    return B2BAccountModel.fromJson(res['data'] as Map<String,dynamic>);
  }

  Future<PagedResult<B2BPayLaterModel>> getPayLaters({int page=1, String? status}) async {
    final res = await _c.get('/b2b/pay-laters', params:{'page':page,'limit':20, if(status!=null)'status':status});
    return PagedResult.fromJson(res, B2BPayLaterModel.fromJson);
  }

  Future<Map<String,dynamic>> createB2BRequest({required String serviceProviderId,
    String? subServiceId, required double amount, required String accountNumber, String? phoneNumber}) async {
    final res = await _c.post('/b2b/request', body:{
      'serviceProviderId':serviceProviderId, if(subServiceId!=null)'subServiceId':subServiceId,
      'amount':amount,'accountNumber':accountNumber, if(phoneNumber!=null)'phoneNumber':phoneNumber,
    });
    return res['data'] as Map<String,dynamic>;
  }

  Future<void> settleInvoice(String payLaterId) =>
    _c.post('/b2b/settle/$payLaterId');
}
