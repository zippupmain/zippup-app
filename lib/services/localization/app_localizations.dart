import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppLocalizations {
  final Locale locale;

  AppLocalizations(this.locale);

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  // Supported locales
  static const List<Locale> supportedLocales = [
    Locale('en', 'US'), // English
    Locale('es', 'ES'), // Spanish
    Locale('fr', 'FR'), // French
    Locale('de', 'DE'), // German
    Locale('pt', 'BR'), // Portuguese (Brazil)
    Locale('ar', 'SA'), // Arabic
    Locale('zh', 'CN'), // Chinese (Simplified)
    Locale('hi', 'IN'), // Hindi
    Locale('ja', 'JP'), // Japanese
    Locale('ko', 'KR'), // Korean
    Locale('ru', 'RU'), // Russian
    Locale('it', 'IT'), // Italian
    Locale('nl', 'NL'), // Dutch
    Locale('sv', 'SE'), // Swedish
    Locale('da', 'DK'), // Danish
    Locale('no', 'NO'), // Norwegian
    Locale('fi', 'FI'), // Finnish
    Locale('pl', 'PL'), // Polish
    Locale('tr', 'TR'), // Turkish
    Locale('th', 'TH'), // Thai
    Locale('vi', 'VN'), // Vietnamese
    Locale('id', 'ID'), // Indonesian
    Locale('ms', 'MY'), // Malay
    Locale('tl', 'PH'), // Filipino
    Locale('sw', 'KE'), // Swahili
    Locale('am', 'ET'), // Amharic
    Locale('ha', 'NG'), // Hausa
    Locale('yo', 'NG'), // Yoruba
    Locale('ig', 'NG'), // Igbo
  ];

  // Common translations
  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'app_name': 'ZippUp',
      'home': 'Home',
      'transport': 'Transport',
      'food': 'Food',
      'grocery': 'Grocery',
      'hire': 'Hire',
      'emergency': 'Emergency',
      'moving': 'Moving',
      'personal': 'Personal',
      'rentals': 'Rentals',
      'marketplace': 'Marketplace',
      'digital': 'Digital',
      'others': 'Others',
      'wallet': 'My Wallet',
      'airtime': 'Airtime',
      'data': 'Data',
      'bills': 'Bills',
      'add_funds': 'Add Funds',
      'withdraw': 'Withdraw',
      'balance': 'Balance',
      'quick_services': 'Quick Services',
      'pay_bills': 'Pay Bills',
      'buy_airtime': 'Buy Airtime',
      'buy_data': 'Buy Data',
      'digital_products': 'Digital Products',
      'select_country': 'Select Country',
      'global_coverage': 'Global Coverage',
      'search': 'Search',
      'book_now': 'Book Now',
      'request': 'Request',
      'accept': 'Accept',
      'decline': 'Decline',
      'cancel': 'Cancel',
      'complete': 'Complete',
      'online': 'Online',
      'offline': 'Offline',
      'earnings': 'Earnings',
      'analytics': 'Analytics',
      'manage': 'Manage',
      'settings': 'Settings',
    },
    'es': {
      'app_name': 'ZippUp',
      'home': 'Inicio',
      'transport': 'Transporte',
      'food': 'Comida',
      'grocery': 'Supermercado',
      'hire': 'Contratar',
      'emergency': 'Emergencia',
      'moving': 'Mudanza',
      'personal': 'Personal',
      'rentals': 'Alquileres',
      'marketplace': 'Mercado',
      'digital': 'Digital',
      'others': 'Otros',
      'wallet': 'Mi Billetera',
      'airtime': 'Tiempo Aire',
      'data': 'Datos',
      'bills': 'Facturas',
      'add_funds': 'Agregar Fondos',
      'withdraw': 'Retirar',
      'balance': 'Saldo',
      'quick_services': 'Servicios Rápidos',
      'pay_bills': 'Pagar Facturas',
      'buy_airtime': 'Comprar Tiempo Aire',
      'buy_data': 'Comprar Datos',
      'digital_products': 'Productos Digitales',
      'select_country': 'Seleccionar País',
      'global_coverage': 'Cobertura Global',
      'search': 'Buscar',
      'book_now': 'Reservar Ahora',
      'request': 'Solicitar',
      'accept': 'Aceptar',
      'decline': 'Rechazar',
      'cancel': 'Cancelar',
      'complete': 'Completar',
      'online': 'En Línea',
      'offline': 'Fuera de Línea',
      'earnings': 'Ganancias',
      'analytics': 'Analíticas',
      'manage': 'Gestionar',
      'settings': 'Configuración',
    },
    'fr': {
      'app_name': 'ZippUp',
      'home': 'Accueil',
      'transport': 'Transport',
      'food': 'Nourriture',
      'grocery': 'Épicerie',
      'hire': 'Embaucher',
      'emergency': 'Urgence',
      'moving': 'Déménagement',
      'personal': 'Personnel',
      'rentals': 'Locations',
      'marketplace': 'Marché',
      'digital': 'Numérique',
      'others': 'Autres',
      'wallet': 'Mon Portefeuille',
      'airtime': 'Crédit Téléphone',
      'data': 'Données',
      'bills': 'Factures',
      'add_funds': 'Ajouter des Fonds',
      'withdraw': 'Retirer',
      'balance': 'Solde',
      'quick_services': 'Services Rapides',
      'pay_bills': 'Payer les Factures',
      'buy_airtime': 'Acheter du Crédit',
      'buy_data': 'Acheter des Données',
      'digital_products': 'Produits Numériques',
      'select_country': 'Sélectionner le Pays',
      'global_coverage': 'Couverture Mondiale',
      'search': 'Rechercher',
      'book_now': 'Réserver Maintenant',
      'request': 'Demander',
      'accept': 'Accepter',
      'decline': 'Refuser',
      'cancel': 'Annuler',
      'complete': 'Terminer',
      'online': 'En Ligne',
      'offline': 'Hors Ligne',
      'earnings': 'Revenus',
      'analytics': 'Analyses',
      'manage': 'Gérer',
      'settings': 'Paramètres',
    },
    'de': {
      'app_name': 'ZippUp',
      'home': 'Startseite',
      'transport': 'Transport',
      'food': 'Essen',
      'grocery': 'Lebensmittel',
      'hire': 'Beauftragen',
      'emergency': 'Notfall',
      'moving': 'Umzug',
      'personal': 'Persönlich',
      'rentals': 'Vermietungen',
      'marketplace': 'Marktplatz',
      'digital': 'Digital',
      'others': 'Andere',
      'wallet': 'Meine Brieftasche',
      'airtime': 'Guthaben',
      'data': 'Daten',
      'bills': 'Rechnungen',
      'add_funds': 'Geld Hinzufügen',
      'withdraw': 'Abheben',
      'balance': 'Guthaben',
      'quick_services': 'Schnelle Dienste',
      'pay_bills': 'Rechnungen Bezahlen',
      'buy_airtime': 'Guthaben Kaufen',
      'buy_data': 'Daten Kaufen',
      'digital_products': 'Digitale Produkte',
      'select_country': 'Land Auswählen',
      'global_coverage': 'Globale Abdeckung',
      'search': 'Suchen',
      'book_now': 'Jetzt Buchen',
      'request': 'Anfragen',
      'accept': 'Akzeptieren',
      'decline': 'Ablehnen',
      'cancel': 'Stornieren',
      'complete': 'Abschließen',
      'online': 'Online',
      'offline': 'Offline',
      'earnings': 'Einnahmen',
      'analytics': 'Analysen',
      'manage': 'Verwalten',
      'settings': 'Einstellungen',
    },
    'ar': {
      'app_name': 'زيب أب',
      'home': 'الرئيسية',
      'transport': 'النقل',
      'food': 'الطعام',
      'grocery': 'البقالة',
      'hire': 'استئجار',
      'emergency': 'الطوارئ',
      'moving': 'النقل',
      'personal': 'شخصي',
      'rentals': 'الإيجارات',
      'marketplace': 'السوق',
      'digital': 'رقمي',
      'others': 'أخرى',
      'wallet': 'محفظتي',
      'airtime': 'رصيد الهاتف',
      'data': 'البيانات',
      'bills': 'الفواتير',
      'add_funds': 'إضافة أموال',
      'withdraw': 'سحب',
      'balance': 'الرصيد',
      'quick_services': 'خدمات سريعة',
      'pay_bills': 'دفع الفواتير',
      'buy_airtime': 'شراء رصيد',
      'buy_data': 'شراء بيانات',
      'digital_products': 'منتجات رقمية',
      'select_country': 'اختر البلد',
      'global_coverage': 'تغطية عالمية',
      'search': 'بحث',
      'book_now': 'احجز الآن',
      'request': 'طلب',
      'accept': 'قبول',
      'decline': 'رفض',
      'cancel': 'إلغاء',
      'complete': 'إكمال',
      'online': 'متصل',
      'offline': 'غير متصل',
      'earnings': 'الأرباح',
      'analytics': 'التحليلات',
      'manage': 'إدارة',
      'settings': 'الإعدادات',
    },
    'zh': {
      'app_name': 'ZippUp',
      'home': '首页',
      'transport': '交通',
      'food': '食物',
      'grocery': '杂货',
      'hire': '雇佣',
      'emergency': '紧急',
      'moving': '搬家',
      'personal': '个人',
      'rentals': '租赁',
      'marketplace': '市场',
      'digital': '数字',
      'others': '其他',
      'wallet': '我的钱包',
      'airtime': '话费',
      'data': '流量',
      'bills': '账单',
      'add_funds': '充值',
      'withdraw': '提现',
      'balance': '余额',
      'quick_services': '快速服务',
      'pay_bills': '缴费',
      'buy_airtime': '购买话费',
      'buy_data': '购买流量',
      'digital_products': '数字产品',
      'select_country': '选择国家',
      'global_coverage': '全球覆盖',
      'search': '搜索',
      'book_now': '立即预订',
      'request': '请求',
      'accept': '接受',
      'decline': '拒绝',
      'cancel': '取消',
      'complete': '完成',
      'online': '在线',
      'offline': '离线',
      'earnings': '收入',
      'analytics': '分析',
      'manage': '管理',
      'settings': '设置',
    },
    'hi': {
      'app_name': 'ZippUp',
      'home': 'होम',
      'transport': 'परिवहन',
      'food': 'खाना',
      'grocery': 'किराना',
      'hire': 'किराया',
      'emergency': 'आपातकाल',
      'moving': 'स्थानांतरण',
      'personal': 'व्यक्तिगत',
      'rentals': 'किराया',
      'marketplace': 'बाज़ार',
      'digital': 'डिजिटल',
      'others': 'अन्य',
      'wallet': 'मेरा वॉलेट',
      'airtime': 'एयरटाइम',
      'data': 'डेटा',
      'bills': 'बिल',
      'add_funds': 'पैसे जोड़ें',
      'withdraw': 'निकालें',
      'balance': 'बैलेंस',
      'quick_services': 'त्वरित सेवाएं',
      'pay_bills': 'बिल भुगतान',
      'buy_airtime': 'एयरटाइम खरीदें',
      'buy_data': 'डेटा खरीदें',
      'digital_products': 'डिजिटल उत्पाद',
      'select_country': 'देश चुनें',
      'global_coverage': 'वैश्विक कवरेज',
      'search': 'खोजें',
      'book_now': 'अभी बुक करें',
      'request': 'अनुरोध',
      'accept': 'स्वीकार',
      'decline': 'अस्वीकार',
      'cancel': 'रद्द करें',
      'complete': 'पूर्ण',
      'online': 'ऑनलाइन',
      'offline': 'ऑफलाइन',
      'earnings': 'कमाई',
      'analytics': 'विश्लेषण',
      'manage': 'प्रबंधन',
      'settings': 'सेटिंग्स',
    },
  };

  String translate(String key) {
    final languageCode = locale.languageCode;
    return _localizedValues[languageCode]?[key] ?? _localizedValues['en']?[key] ?? key;
  }

  // Convenience getters
  String get appName => translate('app_name');
  String get home => translate('home');
  String get transport => translate('transport');
  String get food => translate('food');
  String get grocery => translate('grocery');
  String get hire => translate('hire');
  String get emergency => translate('emergency');
  String get moving => translate('moving');
  String get personal => translate('personal');
  String get rentals => translate('rentals');
  String get marketplace => translate('marketplace');
  String get digital => translate('digital');
  String get others => translate('others');
  String get wallet => translate('wallet');
  String get airtime => translate('airtime');
  String get data => translate('data');
  String get bills => translate('bills');
  String get addFunds => translate('add_funds');
  String get withdraw => translate('withdraw');
  String get balance => translate('balance');
  String get quickServices => translate('quick_services');
  String get payBills => translate('pay_bills');
  String get buyAirtime => translate('buy_airtime');
  String get buyData => translate('buy_data');
  String get digitalProducts => translate('digital_products');
  String get selectCountry => translate('select_country');
  String get globalCoverage => translate('global_coverage');
  String get search => translate('search');
  String get bookNow => translate('book_now');
  String get request => translate('request');
  String get accept => translate('accept');
  String get decline => translate('decline');
  String get cancel => translate('cancel');
  String get complete => translate('complete');
  String get online => translate('online');
  String get offline => translate('offline');
  String get earnings => translate('earnings');
  String get analytics => translate('analytics');
  String get manage => translate('manage');
  String get settings => translate('settings');

  // Static method to save language preference
  static Future<void> saveLanguage(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_language', languageCode);
  }

  // Static method to get saved language
  static Future<String> getSavedLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_language') ?? 'en';
  }
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales.any((supportedLocale) => 
      supportedLocale.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}