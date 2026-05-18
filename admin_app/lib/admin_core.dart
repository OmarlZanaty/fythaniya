// ═══════════════════════════════════════════════════════════
// ADMIN APP — COMPLETE IMPLEMENTATION
// ═══════════════════════════════════════════════════════════
// This file contains the complete admin app implementation.
// Split into logical sections for clarity.

// lib/core/theme/admin_theme.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:badges/badges.dart' as badges;

// ── Colors (brand palette derived from the app logo) ───────
class AC {
  AC._();
  static const Color primary    = Color(0xFF1E40AF); // royal blue (logo accent)
  static const Color dark       = Color(0xFF0F1729); // logo background
  static const Color deep       = Color(0xFF172554); // mid-step between dark and primary
  static const Color light      = Color(0xFF3B82F6); // logo highlight
  static const Color pale       = Color(0xFF60A5FA);
  static const Color secondary  = Color(0xFF06B6D4); // cyan
  static const Color accent     = Color(0xFFF59E0B); // amber
  static const Color bg         = Color(0xFFF8FAFC);
  static const Color bgTint     = Color(0xFFEFF6FF);
  static const Color surface    = Color(0xFFFFFFFF);
  static const Color surfaceAlt = Color(0xFFF1F5F9);
  static const Color text       = Color(0xFF0F172A);
  static const Color textSec    = Color(0xFF475569);
  static const Color textMuted  = Color(0xFF94A3B8);
  static const Color success    = Color(0xFF10B981);
  static const Color successBg  = Color(0xFFD1FAE5);
  static const Color warning    = Color(0xFFF59E0B);
  static const Color warningBg  = Color(0xFFFEF3C7);
  static const Color error      = Color(0xFFEF4444);
  static const Color errorBg    = Color(0xFFFEE2E2);
  static const Color info       = Color(0xFF3B82F6);
  static const Color infoBg     = Color(0xFFDBEAFE);
  static const Color border     = Color(0xFFCBD5E1);
  static const Color borderLight= Color(0xFFE2E8F0);
  static const Color divider    = Color(0xFFE2E8F0);
  static const Color b2b        = Color(0xFF7C3AED);
  static const Color b2bBg      = Color(0xFFF5F3FF);
  static const Color critical   = Color(0xFFEF4444);
  static const Color criticalBg = Color(0xFFFEE2E2);
}

// Admin-side gradients mirroring the user app
class AG {
  AG._();
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topCenter, end: Alignment.bottomCenter,
    colors: [Color(0xFF0F1729), Color(0xFF172554), Color(0xFF1E40AF), Color(0xFF3B82F6)],
    stops: [0.0, 0.35, 0.75, 1.0],
  );
  static const LinearGradient primary = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF1E40AF), Color(0xFF3B82F6)],
  );
  static const LinearGradient primaryDeep = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF0F1729), Color(0xFF1E40AF)],
  );
  static const LinearGradient b2b = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF7C3AED), Color(0xFFA855F7)],
  );
  static const LinearGradient success = LinearGradient(
    begin: Alignment.topLeft, end: Alignment.bottomRight,
    colors: [Color(0xFF10B981), Color(0xFF34D399)],
  );
}

// ── Text Styles ────────────────────────────────────────────
class AT {
  AT._();
  static const _f = 'Cairo';
  static const TextStyle h1    = TextStyle(fontFamily:_f,fontSize:22,fontWeight:FontWeight.w700,color:AC.text,height:1.25);
  static const TextStyle h2    = TextStyle(fontFamily:_f,fontSize:18,fontWeight:FontWeight.w700,color:AC.text,height:1.3);
  static const TextStyle h3    = TextStyle(fontFamily:_f,fontSize:15,fontWeight:FontWeight.w600,color:AC.text,height:1.4);
  static const TextStyle body  = TextStyle(fontFamily:_f,fontSize:14,fontWeight:FontWeight.w400,color:AC.text,height:1.6);
  static const TextStyle bodyM = TextStyle(fontFamily:_f,fontSize:14,fontWeight:FontWeight.w600,color:AC.text,height:1.5);
  static const TextStyle cap   = TextStyle(fontFamily:_f,fontSize:12,fontWeight:FontWeight.w400,color:AC.textSec,height:1.4);
  static const TextStyle capM  = TextStyle(fontFamily:_f,fontSize:12,fontWeight:FontWeight.w600,color:AC.textSec,height:1.3);
  static const TextStyle btn   = TextStyle(fontFamily:_f,fontSize:14,fontWeight:FontWeight.w700,color:Colors.white,height:1.2);
  static const TextStyle num   = TextStyle(fontFamily:_f,fontSize:26,fontWeight:FontWeight.w800,color:AC.text,height:1.1);
}

// ── Dimensions ─────────────────────────────────────────────
class AD {
  AD._();
  static const double xs=4,sm=8,md=16,lg=24,xl=32,xxl=48;
  static const double r8=8,r12=12,r16=16,r20=20;
  static const double btnH=48;
}

// ── Theme ──────────────────────────────────────────────────
ThemeData get adminTheme => ThemeData(
  useMaterial3:true,brightness:Brightness.light,fontFamily:'Cairo',
  scaffoldBackgroundColor:AC.bg,primaryColor:AC.primary,
  colorScheme:const ColorScheme.light(
    primary:AC.primary,onPrimary:Colors.white,
    primaryContainer:AC.infoBg,onPrimaryContainer:AC.deep,
    secondary:AC.secondary,onSecondary:Colors.white,
    tertiary:AC.accent,onTertiary:Colors.white,
    surface:AC.surface,onSurface:AC.text,
    error:AC.error,outline:AC.border,
  ),
  appBarTheme:const AppBarTheme(backgroundColor:AC.primary,elevation:0,centerTitle:true,scrolledUnderElevation:0,titleTextStyle:TextStyle(fontFamily:'Cairo',fontSize:17,fontWeight:FontWeight.w700,color:Colors.white),iconTheme:IconThemeData(color:Colors.white,size:22),systemOverlayStyle:SystemUiOverlayStyle(statusBarColor:Colors.transparent,statusBarIconBrightness:Brightness.light)),
  elevatedButtonTheme:ElevatedButtonThemeData(style:ButtonStyle(
    backgroundColor:WidgetStateProperty.resolveWith((s)=>s.contains(WidgetState.disabled)?AC.divider:AC.primary),
    foregroundColor:WidgetStateProperty.all(Colors.white),
    elevation:WidgetStateProperty.resolveWith((s)=>s.contains(WidgetState.pressed)?1:2),
    shadowColor:WidgetStateProperty.all(AC.primary.withOpacity(0.35)),
    minimumSize:WidgetStateProperty.all(const Size(double.infinity,AD.btnH)),
    shape:WidgetStateProperty.all(RoundedRectangleBorder(borderRadius:BorderRadius.circular(AD.r16))),
    textStyle:WidgetStateProperty.all(AT.btn),
  )),
  outlinedButtonTheme:OutlinedButtonThemeData(style:ButtonStyle(
    foregroundColor:WidgetStateProperty.all(AC.primary),
    side:WidgetStateProperty.all(const BorderSide(color:AC.primary,width:1.5)),
    shape:WidgetStateProperty.all(RoundedRectangleBorder(borderRadius:BorderRadius.circular(AD.r16))),
  )),
  textButtonTheme:TextButtonThemeData(style:ButtonStyle(foregroundColor:WidgetStateProperty.all(AC.primary))),
  inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:AC.surface,
    border:OutlineInputBorder(borderRadius:BorderRadius.circular(AD.r12),borderSide:const BorderSide(color:AC.border)),
    enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(AD.r12),borderSide:const BorderSide(color:AC.border)),
    focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(AD.r12),borderSide:const BorderSide(color:AC.light,width:1.8)),
    errorBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(AD.r12),borderSide:const BorderSide(color:AC.error)),
    contentPadding:const EdgeInsets.symmetric(horizontal:16,vertical:16),
  ),
  cardTheme:CardThemeData(color:AC.surface,elevation:0,surfaceTintColor:Colors.transparent,
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(AD.r16),side:const BorderSide(color:AC.borderLight,width:1)),
    margin:EdgeInsets.zero,
  ),
  bottomNavigationBarTheme:const BottomNavigationBarThemeData(
    backgroundColor:AC.surface,selectedItemColor:AC.primary,unselectedItemColor:AC.textMuted,
    type:BottomNavigationBarType.fixed,elevation:8,
    selectedLabelStyle:TextStyle(fontFamily:'Cairo',fontSize:11,fontWeight:FontWeight.w700),
    unselectedLabelStyle:TextStyle(fontFamily:'Cairo',fontSize:11),
  ),
  tabBarTheme:const TabBarThemeData(
    labelColor:Colors.white,unselectedLabelColor:Color(0xFFCBD5E1),
    indicatorColor:Colors.white,indicatorSize:TabBarIndicatorSize.label,
    labelStyle:TextStyle(fontFamily:'Cairo',fontSize:14,fontWeight:FontWeight.w700),
    unselectedLabelStyle:TextStyle(fontFamily:'Cairo',fontSize:14,fontWeight:FontWeight.w500),
  ),
  dividerTheme:const DividerThemeData(color:AC.divider,thickness:1,space:0),
  dialogTheme:DialogThemeData(backgroundColor:AC.surface,surfaceTintColor:Colors.transparent,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(24))),
  snackBarTheme:SnackBarThemeData(backgroundColor:AC.dark,contentTextStyle:AT.body.copyWith(color:Colors.white),behavior:SnackBarBehavior.floating,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(12))),
  progressIndicatorTheme:const ProgressIndicatorThemeData(color:AC.primary),
  chipTheme:ChipThemeData(
    backgroundColor:AC.surfaceAlt, selectedColor:AC.infoBg,
    labelStyle:AT.cap, side:const BorderSide(color:AC.borderLight),
    shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20)),
  ),
);

// ═══════════════════════════════════════════════════════════
// CONSTANTS
// ═══════════════════════════════════════════════════════════
class AdminConstants {
  AdminConstants._();
  static const String baseUrl   = 'http://34.79.246.143/api/v1';
  static const String socketUrl = 'http://34.79.246.143';
  static const String tokenKey  = 'admin_token';
}

class AdminRoutes {
  AdminRoutes._();
  static const String splash     = '/';
  static const String login      = '/login';
  static const String dashboard  = '/dashboard';
  static const String requests   = '/requests';
  static const String requestDetail = '/requests/:id';
  static const String services   = '/services';
  static const String b2b        = '/b2b';
  static const String b2bDetail  = '/b2b/:id';
  static const String users      = '/users';
  static const String userDetail = '/users/:id';
  static const String notifs     = '/notifications';
  static const String settings   = '/settings';
  static const String reports    = '/reports';
  static const String paymentNumbers = '/payment-numbers';
  static const String clients    = '/clients';
  static const String appSettings= '/app-settings';
  static const String homeTiles  = '/home-tiles';
}

// ═══════════════════════════════════════════════════════════
// SHARED BOTTOM NAV
// Used by main tabs and secondary screens. Pass `current: null` (or any
// non-matching string) on secondary screens to skip highlighting.
// ═══════════════════════════════════════════════════════════
class AdminBottomNav extends StatelessWidget {
  final String? current; // 'dashboard' | 'requests' | 'b2b' | 'services' | 'reports' | null
  const AdminBottomNav({super.key, this.current});
  static const _items = [
    ('dashboard', Icons.dashboard_rounded,  'الرئيسية', AdminRoutes.dashboard),
    ('requests',  Icons.queue_rounded,      'الطلبات',  AdminRoutes.requests),
    ('b2b',       Icons.business_rounded,   'شركات',    AdminRoutes.b2b),
    ('services',  Icons.tune_rounded,       'الخدمات',  AdminRoutes.services),
    ('reports',   Icons.assessment_rounded, 'التقارير', AdminRoutes.reports),
  ];
  @override
  Widget build(BuildContext context) {
    final idx = _items.indexWhere((it) => it.$1 == current);
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      selectedItemColor: AC.primary, unselectedItemColor: AC.textMuted,
      backgroundColor: AC.surface, elevation: 8,
      // When current is null/unknown we still need a valid index, but we
      // de-emphasize selection by giving the unselected color to the "selected" tile.
      currentIndex: idx == -1 ? 0 : idx,
      onTap: (i) {
        final target = _items[i].$4;
        if (_items[i].$1 == current) return;
        context.go(target);
      },
      items: _items.map((it) => BottomNavigationBarItem(
        icon: Icon(it.$2, color: idx == -1 ? AC.textMuted : null),
        label: it.$3,
      )).toList(),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════════════════════
class AdminModel {
  final String id,email,fullName,role;
  const AdminModel({required this.id,required this.email,required this.fullName,required this.role});
  factory AdminModel.fromJson(Map<String,dynamic> j)=>AdminModel(id:j['id'] as String,email:j['email'] as String,fullName:j['fullName'] as String,role:j['role'] as String);
  bool get isSuperAdmin => role=='SUPER_ADMIN';
  bool get canProcess => ['SUPER_ADMIN','TRANSACTION_PROCESSOR','B2B_MANAGER'].contains(role);
  bool get canB2B => ['SUPER_ADMIN','B2B_MANAGER'].contains(role);
}

class AdminLoginResponse {
  final String token; final AdminModel admin;
  const AdminLoginResponse({required this.token,required this.admin});
  factory AdminLoginResponse.fromJson(Map<String,dynamic> j)=>AdminLoginResponse(token:j['token'] as String,admin:AdminModel.fromJson(j['admin'] as Map<String,dynamic>));
}

class RequestItem {
  final String id,type,status;
  final double amount,fee,totalAmount;
  final String? accountNumber,phoneNumber,adminNote,externalRef,proofImageUrl,paymentMethod;
  final String? billingNumber, billingType, receiverName, bankName, bankAccount, instapayId;
  final double? adminSetAmount;
  final String? processorId;
  final DateTime createdAt;
  final DateTime? completedAt,slaDeadline;
  final Map<String,dynamic>? user,serviceProvider,subService,processor;
  final bool slaBreached;

  const RequestItem({required this.id,required this.type,required this.status,
    required this.amount,required this.fee,required this.totalAmount,
    this.accountNumber,this.phoneNumber,this.adminNote,this.externalRef,this.proofImageUrl,this.paymentMethod,
    this.billingNumber,this.billingType,this.receiverName,this.bankName,this.bankAccount,this.instapayId,this.adminSetAmount,
    this.processorId,required this.createdAt,this.completedAt,this.slaDeadline,
    this.user,this.serviceProvider,this.subService,this.processor,this.slaBreached=false});

  factory RequestItem.fromJson(Map<String,dynamic> j)=>RequestItem(
    id:j['id'] as String,type:j['type'] as String,status:j['status'] as String,
    amount:double.tryParse((j['amount']??'0').toString())??0,
    fee:double.tryParse((j['fee']??'0').toString())??0,
    totalAmount:double.tryParse((j['totalAmount']??'0').toString())??0,
    accountNumber:j['accountNumber'] as String?,phoneNumber:j['phoneNumber'] as String?,
    adminNote:j['adminNote'] as String?,externalRef:j['externalRef'] as String?,
    proofImageUrl:j['proofImageUrl'] as String?,paymentMethod:j['paymentMethod'] as String?,
    billingNumber:j['billingNumber'] as String?,
    billingType:j['billingType'] as String?,
    receiverName:j['receiverName'] as String?,
    bankName:j['bankName'] as String?,
    bankAccount:j['bankAccount'] as String?,
    instapayId:j['instapayId'] as String?,
    adminSetAmount:j['adminSetAmount']!=null?double.tryParse(j['adminSetAmount'].toString()):null,
    processorId:j['processorId'] as String?,
    createdAt:DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    completedAt:j['completedAt']!=null?DateTime.tryParse(j['completedAt'] as String):null,
    slaDeadline:j['slaDeadline']!=null?DateTime.tryParse(j['slaDeadline'] as String):null,
    user:j['user'] as Map<String,dynamic>?,serviceProvider:j['serviceProvider'] as Map<String,dynamic>?,
    subService:j['subService'] as Map<String,dynamic>?,processor:j['processor'] as Map<String,dynamic>?,
    slaBreached:j['slaDeadline']!=null&&DateTime.tryParse(j['slaDeadline'] as String)?.isBefore(DateTime.now())==true,
  );
  bool get isPending   => ['PENDING','ASSIGNED','IN_PROGRESS'].contains(status);
  bool get isCompleted => status=='COMPLETED';
  bool get isFailed    => status=='FAILED';
  String get target    => accountNumber??phoneNumber??'—';
  String get userPhone => (user?['phone'] as String?) ?? '—';
  String get userName  => (user?['fullName'] as String?) ?? '—';
  String get providerName => (serviceProvider?['displayName'] as String?) ?? '—';
}

class DashboardStats {
  final int pending,inProgress,completedToday,failedToday,slaBreach,totalUsers,newUsersToday,b2bPending,b2bOverdue;
  final double totalRevenue;
  const DashboardStats({required this.pending,required this.inProgress,required this.completedToday,required this.failedToday,required this.slaBreach,required this.totalUsers,required this.newUsersToday,required this.b2bPending,required this.b2bOverdue,required this.totalRevenue});
  factory DashboardStats.fromJson(Map<String,dynamic> j){
    final r=j['requests'] as Map<String,dynamic>;
    final u=j['users'] as Map<String,dynamic>;
    final b=j['b2b'] as Map<String,dynamic>;
    final rev=j['revenue'] as Map<String,dynamic>;
    return DashboardStats(pending:(r['pending'] as int?)??0,inProgress:(r['inProgress'] as int?)??0,completedToday:(r['completedToday'] as int?)??0,failedToday:(r['failedToday'] as int?)??0,slaBreach:(r['slaBreach'] as int?)??0,totalUsers:(u['total'] as int?)??0,newUsersToday:(u['newToday'] as int?)??0,b2bPending:(b['pendingApplications'] as int?)??0,b2bOverdue:(b['overdueInvoices'] as int?)??0,totalRevenue:double.tryParse((rev['total']??'0').toString())??0);
  }
}

class B2BAccount {
  final String id,userId,companyName,taxId,payLaterStatus;
  final double creditLimit,usedCredit,availableCredit;
  final int paymentTermDays;
  final Map<String,dynamic>? user;
  final int activeInvoices; final double overdueAmount;
  const B2BAccount({required this.id,required this.userId,required this.companyName,required this.taxId,required this.payLaterStatus,required this.creditLimit,required this.usedCredit,required this.availableCredit,required this.paymentTermDays,this.user,this.activeInvoices=0,this.overdueAmount=0});
  factory B2BAccount.fromJson(Map<String,dynamic> j)=>B2BAccount(id:j['id'] as String,userId:j['userId'] as String,companyName:j['companyName'] as String,taxId:j['taxId'] as String,payLaterStatus:(j['payLaterStatus'] as String?)??'PENDING_APPROVAL',creditLimit:double.tryParse((j['creditLimit']??'0').toString())??0,usedCredit:double.tryParse((j['usedCredit']??'0').toString())??0,availableCredit:double.tryParse((j['availableCredit']??'0').toString())??0,paymentTermDays:(j['paymentTermDays'] as int?)??30,user:j['user'] as Map<String,dynamic>?,activeInvoices:(j['activeInvoices'] as int?)??0,overdueAmount:double.tryParse((j['overdueAmount']??'0').toString())??0);
  bool get isPending => payLaterStatus=='PENDING_APPROVAL';
  double get usagePercent => creditLimit>0?(usedCredit/creditLimit).clamp(0.0,1.0):0;
}

class AdminNotification {
  final String id,title,body,priority; final bool isRead; final DateTime createdAt; final String? requestId;
  const AdminNotification({required this.id,required this.title,required this.body,required this.priority,required this.isRead,required this.createdAt,this.requestId});
  factory AdminNotification.fromJson(Map<String,dynamic> j)=>AdminNotification(id:j['id'] as String,title:j['title'] as String,body:j['body'] as String,priority:j['priority'] as String,isRead:(j['isRead'] as bool?)??false,createdAt:DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),requestId:j['requestId'] as String?);
}

class ServiceProvider {
  final String id,name,displayName,category; final bool isActive; final int sortOrder; final double commissionRate;
  final String? logoUrl;
  final List<SubService> subServices;
  const ServiceProvider({required this.id,required this.name,required this.displayName,required this.category,required this.isActive,required this.sortOrder,required this.commissionRate,this.logoUrl,this.subServices=const[]});
  factory ServiceProvider.fromJson(Map<String,dynamic> j)=>ServiceProvider(
    id:j['id'] as String,name:j['name'] as String,
    displayName:(j['displayName'] as String?)??(j['name'] as String),
    category:j['category'] as String,
    isActive:(j['isActive'] as bool?)??true,
    sortOrder:(j['sortOrder'] as int?)??0,
    commissionRate:double.tryParse((j['commissionRate']??'0').toString())??0,
    logoUrl:j['logoUrl'] as String?,
    subServices:(j['subServices'] as List<dynamic>?)?.map((s)=>SubService.fromJson(s as Map<String,dynamic>)).toList()??[],
  );
}

class SubService {
  final String id,serviceProviderId,name,nameAr,category; final bool isActive;
  final double fixedFee,percentageFee; final double? minAmount,maxAmount;
  final String? imageUrl;
  final bool requiresPayLater;
  const SubService({required this.id,required this.serviceProviderId,required this.name,required this.nameAr,required this.category,required this.isActive,required this.fixedFee,required this.percentageFee,this.minAmount,this.maxAmount,this.imageUrl,this.requiresPayLater=false});
  factory SubService.fromJson(Map<String,dynamic> j)=>SubService(
    id:j['id'] as String,serviceProviderId:j['serviceProviderId'] as String,
    name:j['name'] as String,nameAr:j['nameAr'] as String,category:j['category'] as String,
    isActive:(j['isActive'] as bool?)??true,
    fixedFee:double.tryParse((j['fixedFee']??'0').toString())??0,
    percentageFee:double.tryParse((j['percentageFee']??'0').toString())??0,
    minAmount:j['minAmount']!=null?double.tryParse(j['minAmount'].toString()):null,
    maxAmount:j['maxAmount']!=null?double.tryParse(j['maxAmount'].toString()):null,
    imageUrl:j['imageUrl'] as String?,
    requiresPayLater:(j['requiresPayLater'] as bool?)??false,
  );
}

class AdminUser {
  final String id,phone,fullName,type,status; final double walletBalance; final int pointsBalance;
  const AdminUser({required this.id,required this.phone,required this.fullName,required this.type,required this.status,required this.walletBalance,required this.pointsBalance});
  factory AdminUser.fromJson(Map<String,dynamic> j)=>AdminUser(id:j['id'] as String,phone:j['phone'] as String,fullName:j['fullName'] as String,type:(j['type'] as String?)??'B2C',status:(j['status'] as String?)??'ACTIVE',walletBalance:double.tryParse((j['walletBalance']??'0').toString())??0,pointsBalance:(j['pointsBalance'] as int?)??0);
}

class PagedData<T> {
  final List<T> data; final int total,page,limit; final bool hasNext;
  const PagedData({required this.data,required this.total,required this.page,required this.limit,required this.hasNext});
  factory PagedData.fromJson(Map<String,dynamic> json,T Function(Map<String,dynamic>) fromItem){
    final list=json['data'] as List<dynamic>;
    final p=json['pagination'] as Map<String,dynamic>;
    return PagedData(data:list.map((e)=>fromItem(e as Map<String,dynamic>)).toList(),total:p['total'] as int,page:p['page'] as int,limit:p['limit'] as int,hasNext:p['hasNextPage'] as bool);
  }
}
