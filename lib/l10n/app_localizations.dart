import 'package:flutter/material.dart';

/// Simple localization support
/// For full l10n setup, use Flutter's built-in localization with .arb files
class AppLocalizations {

  AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en'));
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static final Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appName': 'ReadEng',
      'schoolCode': 'School Code',
      'email': 'Email',
      'password': 'Password',
      'signIn': 'Sign In',
      'signOut': 'Sign Out',
      'continue_': 'Continue',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'error': 'Error',
      'success': 'Success',
      'loading': 'Loading...',
      'library': 'Library',
      'vocabulary': 'Vocabulary',
      'profile': 'Profile',
      'settings': 'Settings',
      'home': 'Home',
      'xp': 'XP',
      'level': 'Level',
      'streak': 'Streak',
      'days': 'days',
      'books': 'Books',
      'chapters': 'Chapters',
      'activities': 'Activities',
      'words': 'Words',
    },
    'tr': {
      'appName': 'ReadEng',
      'schoolCode': 'Okul Kodu',
      'email': 'E-posta',
      'password': 'Şifre',
      'signIn': 'Giriş Yap',
      'signOut': 'Çıkış Yap',
      'continue_': 'Devam Et',
      'cancel': 'İptal',
      'confirm': 'Onayla',
      'error': 'Hata',
      'success': 'Başarılı',
      'loading': 'Yükleniyor...',
      'library': 'Kütüphane',
      'vocabulary': 'Kelime',
      'profile': 'Profil',
      'settings': 'Ayarlar',
      'home': 'Ana Sayfa',
      'xp': 'XP',
      'level': 'Seviye',
      'streak': 'Seri',
      'days': 'gün',
      'books': 'Kitaplar',
      'chapters': 'Bölümler',
      'activities': 'Aktiviteler',
      'words': 'Kelimeler',
    },
  };

  String get(String key) {
    return _localizedValues[locale.languageCode]?[key] ??
        _localizedValues['en']?[key] ??
        key;
  }

  // Shortcuts
  String get appName => get('appName');
  String get schoolCode => get('schoolCode');
  String get email => get('email');
  String get password => get('password');
  String get signIn => get('signIn');
  String get signOut => get('signOut');
  String get continueText => get('continue_');
  String get cancel => get('cancel');
  String get confirm => get('confirm');
  String get error => get('error');
  String get success => get('success');
  String get loading => get('loading');
  String get library => get('library');
  String get vocabulary => get('vocabulary');
  String get profile => get('profile');
  String get settings => get('settings');
  String get home => get('home');
  String get xp => get('xp');
  String get level => get('level');
  String get streak => get('streak');
  String get days => get('days');
  String get books => get('books');
  String get chapters => get('chapters');
  String get activities => get('activities');
  String get words => get('words');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return ['en', 'tr'].contains(locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
