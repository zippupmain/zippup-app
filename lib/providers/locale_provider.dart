import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zippup/services/localization/app_localizations.dart';

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en', 'US')) {
    _loadSavedLocale();
  }

  Future<void> _loadSavedLocale() async {
    try {
      final savedLanguage = await AppLocalizations.getSavedLanguage();
      final supportedLocale = AppLocalizations.supportedLocales.firstWhere(
        (locale) => locale.languageCode == savedLanguage,
        orElse: () => const Locale('en', 'US'),
      );
      state = supportedLocale;
    } catch (e) {
      print('Error loading saved locale: $e');
    }
  }

  Future<void> changeLocale(String languageCode) async {
    try {
      final newLocale = AppLocalizations.supportedLocales.firstWhere(
        (locale) => locale.languageCode == languageCode,
        orElse: () => const Locale('en', 'US'),
      );
      
      await AppLocalizations.saveLanguage(languageCode);
      state = newLocale;
    } catch (e) {
      print('Error changing locale: $e');
    }
  }
}

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});