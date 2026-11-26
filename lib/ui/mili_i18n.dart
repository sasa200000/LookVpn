import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One of the app's selectable languages. [native] is shown in the picker.
typedef MiliLanguage = ({
  String code,
  String native,
  String english,
  String flag,
});

/// Language controller with system detection, RTL support and a growing
/// translation layer. Strings without a dedicated translation fall back to the
/// English source, so every language remains usable and no screen can break.
class MiliLocale {
  static const _prefKey = 'mili_lang';

  static const languages = <MiliLanguage>[
    (code: 'fa', native: 'فارسی', english: 'Persian', flag: '🇮🇷'),
    (code: 'en', native: 'English', english: 'English', flag: '🇬🇧'),
    (code: 'ar', native: 'العربية', english: 'Arabic', flag: '🇸🇦'),
    (code: 'tr', native: 'Türkçe', english: 'Turkish', flag: '🇹🇷'),
    (code: 'ru', native: 'Русский', english: 'Russian', flag: '🇷🇺'),
    (code: 'zh', native: '简体中文', english: 'Chinese', flag: '🇨🇳'),
  ];

  static Set<String> get codes => {for (final l in languages) l.code};

  /// Defaults to English until [init] runs, keeping widget tests deterministic.
  static final ValueNotifier<String> code = ValueNotifier<String>('en');

  static bool get isFa => code.value == 'fa';

  static bool get isRtl => code.value == 'fa' || code.value == 'ar';

  static TextDirection get direction =>
      isRtl ? TextDirection.rtl : TextDirection.ltr;

  static MiliLanguage get current =>
      languages.firstWhere((l) => l.code == code.value, orElse: () => languages[1]);

  static String _systemLanguage() {
    final system = PlatformDispatcher.instance.locale.languageCode;
    if (system == 'fa' || system == 'ar' || system == 'tr' || system == 'ru') {
      return system;
    }
    if (system == 'zh' || system == 'cn') return 'zh';
    return 'en';
  }

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefKey);
      code.value = saved != null && codes.contains(saved)
          ? saved
          : _systemLanguage();
    } catch (_) {
      // Platform locale is still available when preferences are not.
      code.value = _systemLanguage();
    }
  }

  static Future<void> toggle() =>
      setLang(isFa ? 'en' : (code.value == 'en' ? 'fa' : 'en'));

  static Future<void> setLang(String lang) async {
    if (!codes.contains(lang)) return;
    code.value = lang;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, lang);
    } catch (_) {}
  }

  /// Persian and English are authored inline at the call site; other languages
  /// use the English source as the dictionary key and fall back to English.
  static String t(String fa, String en) {
    final lang = code.value;
    if (lang == 'fa') return fa;
    if (lang == 'en') return en;
    return _translations[lang]?[en] ?? en;
  }

  static const _translations = <String, Map<String, String>>{
    'ar': {
      'Dashboard': 'لوحة التحكم',
      'Scanner': 'الماسح',
      'Settings': 'الإعدادات',
      'About': 'حول',
      'About & updates': 'حول والتحديثات',
      'Appearance': 'المظهر',
      'Appearance & motion': 'المظهر والحركة',
      'Language & direction': 'اللغة والاتجاه',
      'App language': 'لغة التطبيق',
      'Appearance mode': 'وضع المظهر',
      'System': 'النظام',
      'Light': 'فاتح',
      'Dark': 'داكن',
      'Accent color': 'لون التمييز',
      'App font': 'خط التطبيق',
      'Text size': 'حجم النص',
      'Cancel': 'إلغاء',
      'Save': 'حفظ',
      'Reset': 'إعادة تعيين',
      'Done': 'تم',
      'Search': 'بحث',
      'Connection': 'الاتصال',
      'Connection & network': 'الاتصال والشبكة',
      'Core & connection': 'النواة والاتصال',
      'Network': 'الشبكة',
      'Network & DNS': 'الشبكة وDNS',
      'Tools': 'الأدوات',
      'Toolbox': 'صندوق الأدوات',
      'Clean IPs': 'عناوين IP النظيفة',
      'Proxy IPs': 'عناوين Proxy IP',
      'Worker placement': 'موضع Worker',
      'DNS servers': 'خوادم DNS',
      'Routing & rules': 'التوجيه والقواعد',
      'TCP fragments': 'تجزئة TCP',
      'UDP obfuscation': 'تشويش UDP',
      'Per-app proxy': 'بروكسي لكل تطبيق',
      'Chain proxies': 'بروكسيات متسلسلة',
      'Cloudflare accounts': 'حسابات Cloudflare',
      'Tor bridges': 'جسور Tor',
      'Network scanner': 'ماسح الشبكة',
      'Live logs': 'السجلات المباشرة',
      'Xray config': 'إعداد Xray',
      'Version & updates': 'الإصدار والتحديثات',
      'Theme & color': 'السمة واللون',
      'Type & readability': 'الخط والقراءة',
      'Motion & transitions': 'الحركة والانتقالات',
      'Interface animations': 'حركات الواجهة',
      'Mesh gradient backdrop': 'خلفية متدرجة',
      'Page transition': 'انتقال الصفحات',
      'Preview transition': 'معاينة الانتقال',
    },
    'tr': {
      'Dashboard': 'Panel',
      'Scanner': 'Tarayıcı',
      'Settings': 'Ayarlar',
      'About': 'Hakkında',
      'About & updates': 'Hakkında ve güncellemeler',
      'Appearance': 'Görünüm',
      'Appearance & motion': 'Görünüm ve hareket',
      'Language & direction': 'Dil ve yön',
      'App language': 'Uygulama dili',
      'Appearance mode': 'Görünüm modu',
      'System': 'Sistem',
      'Light': 'Açık',
      'Dark': 'Koyu',
      'Accent color': 'Vurgu rengi',
      'App font': 'Uygulama yazı tipi',
      'Text size': 'Metin boyutu',
      'Cancel': 'İptal',
      'Save': 'Kaydet',
      'Reset': 'Sıfırla',
      'Done': 'Bitti',
      'Search': 'Ara',
      'Connection': 'Bağlantı',
      'Connection & network': 'Bağlantı ve ağ',
      'Core & connection': 'Çekirdek ve bağlantı',
      'Network': 'Ağ',
      'Network & DNS': 'Ağ ve DNS',
      'Tools': 'Araçlar',
      'Toolbox': 'Araç kutusu',
      'Clean IPs': "Temiz IP'ler",
      'Proxy IPs': "Proxy IP'ler",
      'Worker placement': 'Worker konumu',
      'DNS servers': 'DNS sunucuları',
      'Routing & rules': 'Yönlendirme ve kurallar',
      'TCP fragments': 'TCP parçaları',
      'UDP obfuscation': 'UDP gizleme',
      'Per-app proxy': 'Uygulama başına proxy',
      'Chain proxies': "Zincir proxy'ler",
      'Cloudflare accounts': 'Cloudflare hesapları',
      'Tor bridges': 'Tor köprüleri',
      'Network scanner': 'Ağ tarayıcısı',
      'Live logs': 'Canlı günlükler',
      'Xray config': 'Xray yapılandırması',
      'Version & updates': 'Sürüm ve güncellemeler',
      'Theme & color': 'Tema ve renk',
      'Type & readability': 'Yazı tipi ve okunabilirlik',
      'Motion & transitions': 'Hareket ve geçişler',
      'Interface animations': 'Arayüz animasyonları',
      'Mesh gradient backdrop': 'Mesh gradyan arka plan',
      'Page transition': 'Sayfa geçişi',
      'Preview transition': 'Geçişi önizle',
    },
    'ru': {
      'Dashboard': 'Панель',
      'Scanner': 'Сканер',
      'Settings': 'Настройки',
      'About': 'О приложении',
      'About & updates': 'О приложении и обновления',
      'Appearance': 'Внешний вид',
      'Appearance & motion': 'Внешний вид и анимация',
      'Language & direction': 'Язык и направление',
      'App language': 'Язык приложения',
      'Appearance mode': 'Режим оформления',
      'System': 'Система',
      'Light': 'Светлая',
      'Dark': 'Тёмная',
      'Accent color': 'Акцентный цвет',
      'App font': 'Шрифт приложения',
      'Text size': 'Размер текста',
      'Cancel': 'Отмена',
      'Save': 'Сохранить',
      'Reset': 'Сбросить',
      'Done': 'Готово',
      'Search': 'Поиск',
      'Connection': 'Подключение',
      'Connection & network': 'Подключение и сеть',
      'Core & connection': 'Ядро и подключение',
      'Network': 'Сеть',
      'Network & DNS': 'Сеть и DNS',
      'Tools': 'Инструменты',
      'Toolbox': 'Инструментарий',
      'Clean IPs': 'Чистые IP',
      'Proxy IPs': 'Прокси IP',
      'Worker placement': 'Размещение Worker',
      'DNS servers': 'DNS-серверы',
      'Routing & rules': 'Маршрутизация и правила',
      'TCP fragments': 'Фрагменты TCP',
      'UDP obfuscation': 'Обфускация UDP',
      'Per-app proxy': 'Прокси для приложений',
      'Chain proxies': 'Цепочки прокси',
      'Cloudflare accounts': 'Аккаунты Cloudflare',
      'Tor bridges': 'Мосты Tor',
      'Network scanner': 'Сетевой сканер',
      'Live logs': 'Живые логи',
      'Xray config': 'Конфиг Xray',
      'Version & updates': 'Версия и обновления',
      'Theme & color': 'Тема и цвет',
      'Type & readability': 'Шрифт и читаемость',
      'Motion & transitions': 'Движение и переходы',
      'Interface animations': 'Анимации интерфейса',
      'Mesh gradient backdrop': 'Градиентный фон',
      'Page transition': 'Переход страниц',
      'Preview transition': 'Предпросмотр перехода',
    },
    'zh': {
      'Dashboard': '仪表盘',
      'Scanner': '扫描器',
      'Settings': '设置',
      'About': '关于',
      'About & updates': '关于与更新',
      'Appearance': '外观',
      'Appearance & motion': '外观与动效',
      'Language & direction': '语言与方向',
      'App language': '应用语言',
      'Appearance mode': '外观模式',
      'System': '系统',
      'Light': '浅色',
      'Dark': '深色',
      'Accent color': '强调色',
      'App font': '应用字体',
      'Text size': '文字大小',
      'Cancel': '取消',
      'Save': '保存',
      'Reset': '重置',
      'Done': '完成',
      'Search': '搜索',
      'Connection': '连接',
      'Connection & network': '连接与网络',
      'Core & connection': '内核与连接',
      'Network': '网络',
      'Network & DNS': '网络与 DNS',
      'Tools': '工具',
      'Toolbox': '工具箱',
      'Clean IPs': '干净 IP',
      'Proxy IPs': '代理 IP',
      'Worker placement': 'Worker 位置',
      'DNS servers': 'DNS 服务器',
      'Routing & rules': '路由与规则',
      'TCP fragments': 'TCP 分片',
      'UDP obfuscation': 'UDP 混淆',
      'Per-app proxy': '按应用代理',
      'Chain proxies': '链式代理',
      'Cloudflare accounts': 'Cloudflare 账户',
      'Tor bridges': 'Tor 网桥',
      'Network scanner': '网络扫描器',
      'Live logs': '实时日志',
      'Xray config': 'Xray 配置',
      'Version & updates': '版本与更新',
      'Theme & color': '主题与颜色',
      'Type & readability': '字体与可读性',
      'Motion & transitions': '动效与过渡',
      'Interface animations': '界面动画',
      'Mesh gradient backdrop': '网格渐变背景',
      'Page transition': '页面过渡',
      'Preview transition': '预览过渡',
    },
  };
}
