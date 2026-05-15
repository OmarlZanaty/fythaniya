// Single source of truth — package:fythaniya/data/models/models.dart

class UserModel {
  final String id, phone, fullName, type, status;
  final String? email, deviceToken;
  final bool kycVerified;
  final int pointsBalance;
  final double walletBalance;
  final bool payLaterEligible;
  final bool payLaterPending;
  final String? payLaterPendingRequestId;
  final DateTime? createdAt, lastLoginAt;

  const UserModel({required this.id, required this.phone, required this.fullName,
    this.email, this.deviceToken, required this.type, required this.status,
    required this.kycVerified, required this.pointsBalance, required this.walletBalance,
    this.payLaterEligible = false, this.payLaterPending = false, this.payLaterPendingRequestId,
    this.createdAt, this.lastLoginAt});

  factory UserModel.fromJson(Map<String,dynamic> j) => UserModel(
    id: j['id'] as String, phone: j['phone'] as String,
    fullName: j['fullName'] as String, email: j['email'] as String?,
    deviceToken: j['deviceToken'] as String?,
    type: j['type'] as String? ?? 'B2C', status: j['status'] as String? ?? 'ACTIVE',
    kycVerified: (j['kycVerified'] as bool?) ?? true,
    pointsBalance: (j['pointsBalance'] as int?) ?? 0,
    walletBalance: double.tryParse(j['walletBalance'].toString()) ?? 0.0,
    payLaterEligible: (j['payLaterEligible'] as bool?) ?? false,
    payLaterPending: (j['payLaterPending'] as bool?) ?? false,
    payLaterPendingRequestId: j['payLaterPendingRequestId'] as String?,
    createdAt: j['createdAt'] != null ? DateTime.tryParse(j['createdAt'] as String) : null,
    lastLoginAt: j['lastLoginAt'] != null ? DateTime.tryParse(j['lastLoginAt'] as String) : null,
  );

  Map<String,dynamic> toJson() => {'id':id,'phone':phone,'fullName':fullName,'email':email,'type':type,'status':status,'kycVerified':kycVerified,'pointsBalance':pointsBalance,'walletBalance':walletBalance,'payLaterEligible':payLaterEligible};

  UserModel copyWith({String? fullName, String? email, int? pointsBalance, double? walletBalance, bool? payLaterEligible}) =>
    UserModel(id:id,phone:phone,fullName:fullName??this.fullName,email:email??this.email,deviceToken:deviceToken,type:type,status:status,kycVerified:kycVerified,pointsBalance:pointsBalance??this.pointsBalance,walletBalance:walletBalance??this.walletBalance,payLaterEligible:payLaterEligible??this.payLaterEligible,payLaterPending:payLaterPending,payLaterPendingRequestId:payLaterPendingRequestId,createdAt:createdAt,lastLoginAt:lastLoginAt);

  bool get isB2B => type == 'B2B';
  bool get isActive => status == 'ACTIVE';
  String get tierAr => pointsBalance>=2000?'ذهبي':pointsBalance>=500?'فضي':'برونزي';
  int get nextTierPts => pointsBalance>=2000?0:pointsBalance>=500?2000-pointsBalance:500-pointsBalance;
  String get initials { final p=fullName.trim().split(' '); return p.length>=2?'${p[0][0]}${p[1][0]}':fullName.isNotEmpty?fullName[0]:'؟'; }
}

class AuthResponse {
  final String accessToken, refreshToken;
  final UserModel user;
  const AuthResponse({required this.accessToken, required this.refreshToken, required this.user});
  factory AuthResponse.fromJson(Map<String,dynamic> j) => AuthResponse(
    accessToken: j['accessToken'] as String,
    refreshToken: j['refreshToken'] as String,
    user: UserModel.fromJson(j['user'] as Map<String,dynamic>));
}

class ServiceProviderModel {
  final String id, name, displayName, category;
  final String? logoUrl;
  final bool isActive;
  final int sortOrder;
  final double commissionRate;
  final List<SubServiceModel> subServices;

  const ServiceProviderModel({required this.id, required this.name, required this.displayName,
    required this.category, this.logoUrl, this.isActive=true,
    this.sortOrder=0, this.commissionRate=0, this.subServices=const[]});

  factory ServiceProviderModel.fromJson(Map<String,dynamic> j) {
    final id = j['id'] as String;
    // Some endpoints narrow the select and omit `name` / `displayName` — fall back gracefully.
    final name = (j['name'] as String?) ?? id;
    final displayName = (j['displayName'] as String?) ?? name;
    return ServiceProviderModel(
      id: id, name: name, displayName: displayName,
      category: j['category'] as String? ?? 'OTHER',
      logoUrl: j['logoUrl'] as String?,
      isActive: (j['isActive'] as bool?) ?? true,
      sortOrder: (j['sortOrder'] as int?) ?? 0,
      commissionRate: double.tryParse((j['commissionRate'] ?? '0').toString()) ?? 0,
      subServices: (j['subServices'] as List<dynamic>?)?.map((s)=>SubServiceModel.fromJson(s as Map<String,dynamic>)).toList() ?? [],
    );
  }
}

class SubServiceModel {
  final String id, serviceProviderId, name, nameAr, category;
  final String? description;
  final String? imageUrl;
  final double? minAmount, maxAmount;
  final double fixedFee, percentageFee;
  final List<int> quickAmounts;
  final bool isActive;
  final bool requiresPayLater;
  final int sortOrder;

  const SubServiceModel({required this.id, required this.serviceProviderId,
    required this.name, required this.nameAr, required this.category,
    this.description, this.imageUrl, this.minAmount, this.maxAmount,
    this.fixedFee=0, this.percentageFee=0, this.quickAmounts=const[],
    this.isActive=true, this.requiresPayLater=false, this.sortOrder=0});

  factory SubServiceModel.fromJson(Map<String,dynamic> j) {
    List<int> qa = [];
    try {
      final raw = j['quickAmounts'];
      if (raw is String && raw.isNotEmpty) {
        final parsed = raw.replaceAll('[','').replaceAll(']','').split(',');
        qa = parsed.map((e)=>int.tryParse(e.trim())??0).where((e)=>e>0).toList();
      }
    } catch (e) { /* swallow — quickAmounts is best-effort */ }
    final id = j['id'] as String;
    final nameAr = (j['nameAr'] as String?) ?? '';
    // Some endpoints narrow the select and only ship {id, nameAr}. Fall back so we never crash.
    return SubServiceModel(
      id: id,
      serviceProviderId: (j['serviceProviderId'] as String?) ?? '',
      name: (j['name'] as String?) ?? nameAr,
      nameAr: nameAr,
      category: (j['category'] as String?) ?? 'OTHER',
      description: j['description'] as String?,
      minAmount: j['minAmount']!=null ? double.tryParse(j['minAmount'].toString()) : null,
      maxAmount: j['maxAmount']!=null ? double.tryParse(j['maxAmount'].toString()) : null,
      fixedFee: double.tryParse((j['fixedFee']??'0').toString())??0,
      percentageFee: double.tryParse((j['percentageFee']??'0').toString())??0,
      quickAmounts: qa,
      isActive: (j['isActive'] as bool?)??true,
      requiresPayLater: (j['requiresPayLater'] as bool?)??false,
      imageUrl: j['imageUrl'] as String?,
      sortOrder: (j['sortOrder'] as int?)??0,
    );
  }

  double feeFor(double a) => fixedFee + (a * percentageFee);
  double totalFor(double a) => a + feeFor(a);
}

class RequestModel {
  final String id, type, status;
  final double amount, fee, totalAmount;
  final String? accountNumber, phoneNumber, adminNote, externalRef;
  final String? serviceProviderId, subServiceId;
  final ServiceProviderModel? serviceProvider;
  final SubServiceModel? subService;
  final DateTime createdAt;
  final DateTime? completedAt, slaDeadline;

  const RequestModel({required this.id, required this.type, required this.status,
    required this.amount, required this.fee, required this.totalAmount,
    this.accountNumber, this.phoneNumber, this.adminNote, this.externalRef,
    this.serviceProviderId, this.subServiceId, this.serviceProvider, this.subService,
    required this.createdAt, this.completedAt, this.slaDeadline});

  factory RequestModel.fromJson(Map<String,dynamic> j) => RequestModel(
    id: j['id'] as String, type: j['type'] as String, status: j['status'] as String,
    amount: double.tryParse((j['amount']??'0').toString())??0,
    fee: double.tryParse((j['fee']??'0').toString())??0,
    totalAmount: double.tryParse((j['totalAmount']??'0').toString())??0,
    accountNumber: j['accountNumber'] as String?,
    phoneNumber: j['phoneNumber'] as String?,
    adminNote: j['adminNote'] as String?,
    externalRef: j['externalRef'] as String?,
    serviceProviderId: j['serviceProviderId'] as String?,
    subServiceId: j['subServiceId'] as String?,
    serviceProvider: j['serviceProvider']!=null?ServiceProviderModel.fromJson(j['serviceProvider'] as Map<String,dynamic>):null,
    subService: j['subService']!=null?SubServiceModel.fromJson(j['subService'] as Map<String,dynamic>):null,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    completedAt: j['completedAt']!=null?DateTime.tryParse(j['completedAt'] as String):null,
    slaDeadline: j['slaDeadline']!=null?DateTime.tryParse(j['slaDeadline'] as String):null,
  );

  bool get isCompleted => status=='COMPLETED';
  bool get isPending   => ['PENDING','ASSIGNED','IN_PROGRESS'].contains(status);
  bool get isFailed    => status=='FAILED';
  bool get isRefunded  => status=='REFUNDED';
  String get displayTarget => accountNumber ?? phoneNumber ?? '';
}

class TransactionModel {
  final String id, status;
  final String? requestId, externalRef, paymentMethod;
  final double amount, fee, totalAmount;
  final DateTime createdAt;
  final RequestModel? request;

  const TransactionModel({required this.id, this.requestId,
    required this.amount, required this.fee, required this.totalAmount,
    required this.status, this.externalRef, this.paymentMethod,
    required this.createdAt, this.request});

  factory TransactionModel.fromJson(Map<String,dynamic> j) => TransactionModel(
    id: j['id'] as String, requestId: j['requestId'] as String?,
    amount: double.tryParse((j['amount']??'0').toString())??0,
    fee: double.tryParse((j['fee']??'0').toString())??0,
    totalAmount: double.tryParse((j['totalAmount']??'0').toString())??0,
    status: j['status'] as String,
    externalRef: j['externalRef'] as String?,
    paymentMethod: j['paymentMethod'] as String?,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    request: j['request']!=null?RequestModel.fromJson(j['request'] as Map<String,dynamic>):null,
  );

  bool get isSuccess  => status=='SUCCESS'||status=='COMPLETED';
  bool get isPending  => status=='PENDING';
  bool get isFailed   => status=='FAILED';
  bool get isRefunded => status=='REFUNDED';
}

class NotificationModel {
  final String id, title, body, channel, priority;
  final bool isRead;
  final String? actionUrl;
  final DateTime createdAt;

  const NotificationModel({required this.id, required this.title, required this.body,
    required this.channel, required this.priority, required this.isRead,
    this.actionUrl, required this.createdAt});

  factory NotificationModel.fromJson(Map<String,dynamic> j) => NotificationModel(
    id: j['id'] as String, title: j['title'] as String, body: j['body'] as String,
    channel: j['channel'] as String, priority: j['priority'] as String,
    isRead: (j['isRead'] as bool?)??false,
    actionUrl: j['actionUrl'] as String?,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now());
}

class RewardHistory {
  final String id, reason;
  final int points;
  final bool isEarned;
  final DateTime createdAt;
  const RewardHistory({required this.id, required this.points, required this.reason, required this.isEarned, required this.createdAt});
  factory RewardHistory.fromJson(Map<String,dynamic> j) => RewardHistory(
    id: j['id'] as String, points: (j['points'] as int?)??0,
    reason: j['reason'] as String,
    isEarned: (j['isEarned'] as bool?)??((j['points'] as int??0)>0),
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now());
}

class RewardsSummary {
  final int pointsBalance, nextTierPoints;
  final String tier;
  final List<RewardHistory> history;
  const RewardsSummary({required this.pointsBalance, required this.nextTierPoints, required this.tier, required this.history});
  factory RewardsSummary.fromJson(Map<String,dynamic> j) => RewardsSummary(
    pointsBalance: (j['pointsBalance'] as int?)??0,
    nextTierPoints: (j['nextTierPoints'] as int?)??500,
    tier: (j['tier'] as String?)?? 'Bronze',
    history: (j['history'] as List<dynamic>?)?.map((h)=>RewardHistory.fromJson(h as Map<String,dynamic>)).toList()??[]);
  double get progress { if(pointsBalance>=2000)return 1.0; if(pointsBalance>=500)return(pointsBalance-500)/1500; return pointsBalance/500; }
}

class VoucherModel {
  final String id, code;
  final double discountPercent;
  final int maxUses, usedCount, pointsCost;
  final DateTime? validUntil;
  final bool isActive, canRedeem;
  const VoucherModel({required this.id, required this.code, required this.discountPercent,
    required this.maxUses, required this.usedCount, required this.pointsCost,
    this.validUntil, required this.isActive, this.canRedeem=false});
  factory VoucherModel.fromJson(Map<String,dynamic> j) => VoucherModel(
    id: j['id'] as String, code: j['code'] as String,
    discountPercent: double.tryParse((j['discountPercent']??'0').toString())??0,
    maxUses: j['maxUses'] as int, usedCount: j['usedCount'] as int,
    pointsCost: j['pointsCost'] as int,
    validUntil: j['validUntil']!=null?DateTime.tryParse(j['validUntil'] as String):null,
    isActive: (j['isActive'] as bool?)??true,
    canRedeem: (j['canRedeem'] as bool?)??false);
}

class SpendingRecord {
  final String category, month;
  final double amount;
  final int count, year;
  const SpendingRecord({required this.category, required this.amount, required this.count, required this.month, required this.year});
  factory SpendingRecord.fromJson(Map<String,dynamic> j) => SpendingRecord(
    category: j['category'] as String,
    amount: double.tryParse((j['amount']??'0').toString())??0,
    count: (j['count'] as int?)??0,
    month: j['month']?.toString()??'',
    year: (j['year'] as int?)??DateTime.now().year);
}

// B2B Models
class B2BAccountModel {
  final String id, userId, companyName, taxId;
  final String? commercialReg, contactName, contactPhone, rejectionReason;
  final double creditLimit, usedCredit, availableCredit;
  final String payLaterStatus;
  final int paymentTermDays;
  final DateTime? approvedAt;
  final DateTime createdAt;
  final List<B2BPayLaterModel> b2bPayLaters;

  const B2BAccountModel({required this.id, required this.userId, required this.companyName,
    required this.taxId, this.commercialReg, this.contactName, this.contactPhone,
    this.rejectionReason, required this.creditLimit, required this.usedCredit,
    required this.availableCredit, required this.payLaterStatus,
    required this.paymentTermDays, this.approvedAt, required this.createdAt,
    this.b2bPayLaters=const[]});

  factory B2BAccountModel.fromJson(Map<String,dynamic> j) => B2BAccountModel(
    id: j['id'] as String, userId: j['userId'] as String,
    companyName: j['companyName'] as String, taxId: j['taxId'] as String,
    commercialReg: j['commercialReg'] as String?,
    contactName: j['contactName'] as String?,
    contactPhone: j['contactPhone'] as String?,
    rejectionReason: j['rejectionReason'] as String?,
    creditLimit: double.tryParse((j['creditLimit']??'0').toString())??0,
    usedCredit: double.tryParse((j['usedCredit']??'0').toString())??0,
    availableCredit: double.tryParse((j['availableCredit']??'0').toString())??0,
    payLaterStatus: j['payLaterStatus'] as String? ?? 'PENDING_APPROVAL',
    paymentTermDays: (j['paymentTermDays'] as int?)??30,
    approvedAt: j['approvedAt']!=null?DateTime.tryParse(j['approvedAt'] as String):null,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    b2bPayLaters: (j['b2bPayLaters'] as List<dynamic>?)?.map((p)=>B2BPayLaterModel.fromJson(p as Map<String,dynamic>)).toList()??[],
  );

  bool get isActive => payLaterStatus=='ACTIVE';
  bool get isPending => payLaterStatus=='PENDING_APPROVAL';
  bool get isRejected => payLaterStatus=='REJECTED';
  bool get isOverdue => payLaterStatus=='OVERDUE';
  double get usagePercent => creditLimit>0?(usedCredit/creditLimit).clamp(0,1):0;
}

class B2BPayLaterModel {
  final String id, b2bAccountId, requestId, status, invoiceNo;
  final double amount;
  final DateTime dueDate, createdAt;
  final DateTime? settledAt;
  final String? notes;

  const B2BPayLaterModel({required this.id, required this.b2bAccountId,
    required this.requestId, required this.amount, required this.dueDate,
    required this.status, required this.invoiceNo, required this.createdAt,
    this.settledAt, this.notes});

  factory B2BPayLaterModel.fromJson(Map<String,dynamic> j) => B2BPayLaterModel(
    id: j['id'] as String, b2bAccountId: j['b2bAccountId'] as String,
    requestId: j['requestId'] as String,
    amount: double.tryParse((j['amount']??'0').toString())??0,
    dueDate: DateTime.tryParse(j['dueDate']?.toString() ?? '') ?? DateTime.now(),
    status: j['status'] as String,
    invoiceNo: j['invoiceNo'] as String,
    createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    settledAt: j['settledAt']!=null?DateTime.tryParse(j['settledAt'] as String):null,
    notes: j['notes'] as String?,
  );

  bool get isOverdue => status=='OVERDUE'||(status=='ACTIVE'&&dueDate.isBefore(DateTime.now()));
  bool get isSettled => status=='SETTLED';
}

class PagedResult<T> {
  final List<T> data;
  final int total, page, limit, totalPages;
  final bool hasNext, hasPrev;
  const PagedResult({required this.data, required this.total, required this.page, required this.limit, required this.totalPages, required this.hasNext, required this.hasPrev});
  factory PagedResult.fromJson(Map<String,dynamic> json, T Function(Map<String,dynamic>) fromItem) {
    final list = json['data'] as List<dynamic>;
    final p = json['pagination'] as Map<String,dynamic>;
    return PagedResult(data:list.map((e)=>fromItem(e as Map<String,dynamic>)).toList(), total:p['total'] as int, page:p['page'] as int, limit:p['limit'] as int, totalPages:p['totalPages'] as int, hasNext:p['hasNextPage'] as bool, hasPrev:p['hasPrevPage'] as bool);
  }
}
