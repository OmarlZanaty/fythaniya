class AppConstants {
  AppConstants._();
  static const String baseUrl     = 'http://34.79.246.143/api/v1';
  static const String socketUrl   = 'http://34.79.246.143';
  static const int    connectMs   = 30000;
  static const int    receiveMs   = 30000;
  static const String tokenKey    = 'fyt_access';
  static const String refreshKey  = 'fyt_refresh';
  static const String onboardKey  = 'fyt_onboard';
  static const String appName     = 'فى ثانية';
  static const String appTagline  = 'ادفع كل شيء في ثانية';
  static const int    pageSize    = 20;
}

class AppRoutes {
  AppRoutes._();
  static const String splash     = '/';
  static const String onboard    = '/onboarding';
  static const String login      = '/login';
  static const String register   = '/register';
  static const String forgot     = '/forgot';
  static const String home       = '/home';
  static const String recharge   = '/recharge';
  static const String bill       = '/bill';
  static const String txList     = '/transactions';
  static const String notifs     = '/notifications';
  static const String wallet     = '/wallet';
  static const String walletTopup    = '/wallet/topup';
  static const String walletTransfer = '/wallet/transfer';
  static const String rewards    = '/rewards';
  static const String profile    = '/profile';
  static const String editProf   = '/profile/edit';
  static const String changePass = '/profile/password';
  static const String b2bApply   = '/b2b/apply';
  static const String b2bDash    = '/b2b/dashboard';
  static const String b2bRequest = '/b2b/request';
  static const String b2bInvoices= '/b2b/invoices';
  static const String payLater   = '/pay-later';
}

class S {
  S._();
  static const String appName    = 'فى ثانية';
  static const String cont       = 'متابعة';
  static const String back       = 'رجوع';
  static const String confirm    = 'تأكيد';
  static const String cancel     = 'إلغاء';
  static const String save       = 'حفظ';
  static const String done       = 'تم';
  static const String retry      = 'إعادة المحاولة';
  static const String seeAll     = 'عرض الكل';
  static const String egp        = 'ج.م';
  static const String pts        = 'نقطة';
  static const String required   = 'هذا الحقل مطلوب';
  static const String invalidPhone='رقم الهاتف غير صحيح';
  static const String invalidPass = 'كلمة المرور 6 أحرف على الأقل';
  static const String passMismatch= 'كلمة المرور غير متطابقة';
  static const String networkErr  = 'تعذر الاتصال بالإنترنت';
  static const String serverErr   = 'خطأ في الخادم، حاول لاحقاً';
  static const String login       = 'تسجيل الدخول';
  static const String register    = 'إنشاء حساب';
  static const String logout      = 'تسجيل الخروج';
  static const String phone       = 'رقم الهاتف';
  static const String phonePlch   = '01XXXXXXXXX';
  static const String password    = 'كلمة المرور';
  static const String newPassword = 'كلمة المرور الجديدة';
  static const String confirmPass = 'تأكيد كلمة المرور';
  static const String currentPass = 'كلمة المرور الحالية';
  static const String fullName    = 'الاسم الكامل';
  static const String email       = 'البريد الإلكتروني';
  static const String forgotPass  = 'نسيت كلمة المرور؟';
  static const String noAccount   = 'ليس لديك حساب؟';
  static const String hasAccount  = 'لديك حساب؟';
  static const String signupNow   = 'أنشئ حساباً';
  static const String loginNow    = 'سجل دخولك';
  static const String hello       = 'أهلاً';
  static const String walletBal   = 'رصيد المحفظة';
  static const String services    = 'الخدمات';
  static const String recentTx    = 'آخر المعاملات';
  static const String noTxYet     = 'لا توجد معاملات بعد';
  static const String recharge    = 'شحن رصيد';
  static const String bills       = 'الفواتير';
  static const String electricity = 'كهرباء';
  static const String gas         = 'غاز';
  static const String water       = 'مياه';
  static const String internet    = 'إنترنت';
  static const String insurance   = 'تأمين';
  static const String government  = 'حكومي';
  static const String wallet      = 'محفظة';
  static const String topUp       = 'شحن';
  static const String rewards     = 'مكافآت';
  static const String amount      = 'المبلغ';
  static const String fee         = 'رسوم الخدمة';
  static const String total       = 'الإجمالي';
  static const String quickAmounts= 'مبالغ سريعة';
  static const String successTitle= 'تم تقديم الطلب! ✅';
  static const String successSub  = 'سيتم تنفيذ طلبك خلال دقائق';
  static const String selectProv  = 'اختر مزود الخدمة';
  static const String accountNum  = 'رقم الحساب';
  static const String txTitle     = 'المعاملات';
  static const String all         = 'الكل';
  static const String pending     = 'جارٍ';
  static const String completed   = 'مكتمل';
  static const String failed      = 'فشل';
  static const String noTx        = 'لا توجد معاملات';
  static const String notifTitle  = 'الإشعارات';
  static const String markAllRead = 'تعيين الكل كمقروء';
  static const String noNotif     = 'لا توجد إشعارات';
  static const String walletTitle = 'محفظتي';
  static const String spending    = 'الإنفاق';
  static const String rewardsTitle= 'المكافآت';
  static const String myPoints    = 'نقاطي';
  static const String redeemPts   = 'استبدل';
  static const String vouchers    = 'القسائم';
  static const String bronze      = 'برونزي';
  static const String silver      = 'فضي';
  static const String gold        = 'ذهبي';
  static const String nextTier    = 'للمستوى التالي';
  static const String noVouchers  = 'لا توجد قسائم متاحة';
  static const String profileTitle= 'الملف الشخصي';
  static const String editProfile = 'تعديل الملف';
  static const String changePass2 = 'تغيير كلمة المرور';
  static const String support     = 'تواصل مع الدعم';
  static const String terms       = 'الشروط والأحكام';
  static const String privacy     = 'سياسة الخصوصية';
  static const String appVersion  = 'إصدار التطبيق';
  static const String logoutConfirm='هل تريد تسجيل الخروج؟';
  static const String b2bTitle    = 'حساب شركات';
  static const String b2bApply    = 'التقديم على حساب شركات';
  static const String b2bDash     = 'لوحة الشركات';
  static const String payLater    = 'ادفع لاحقاً';
  static const String creditLimit = 'الحد الائتماني';
  static const String usedCredit  = 'الائتمان المستخدم';
  static const String availCredit = 'الائتمان المتاح';
  static const String invoices    = 'الفواتير';
  static const String companyName = 'اسم الشركة';
  static const String taxId       = 'الرقم الضريبي';
  static const String contactName = 'اسم جهة الاتصال';
  static const String contactPhone= 'هاتف جهة الاتصال';
  static const String requestedLim= 'الحد الائتماني المطلوب';
  static const String dueDate     = 'تاريخ الاستحقاق';
  static const String overdue     = 'متأخرة';
  static const String settled     = 'مسددة';
  static const String active      = 'نشط';
  static const String pending2    = 'قيد المراجعة';
}

const Map<String,String> kCategoryNames = {
  'TELECOM':'اتصالات','ELECTRICITY':'كهرباء','GAS':'غاز',
  'WATER':'مياه','INTERNET':'إنترنت','INSURANCE':'تأمين','GOVERNMENT':'حكومي',
};
const Map<String,String> kStatusNames = {
  'PENDING':'قيد الانتظار','ASSIGNED':'تم التعيين','IN_PROGRESS':'جارٍ',
  'COMPLETED':'مكتمل','FAILED':'فشل','REFUNDED':'مسترد','ESCALATED':'مُصعَّد','SUCCESS':'مكتمل',
};
const Map<String,String> kTypeNames = {
  'MOBILE_RECHARGE':'شحن رصيد','BILL_PAYMENT':'دفع فاتورة',
  'INTERNET_RECHARGE':'شحن إنترنت','B2B_PAY_LATER':'ادفع لاحقاً','TRANSFER':'تحويل',
};
const Map<String,String> kPayLaterStatus = {
  'PENDING_APPROVAL':'قيد المراجعة','ACTIVE':'نشط','OVERDUE':'متأخرة',
  'SETTLED':'مسددة','SUSPENDED':'موقوف','REJECTED':'مرفوض',
};
