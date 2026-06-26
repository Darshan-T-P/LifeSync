import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppSettings {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  // Settings Notifiers
  final ValueNotifier<String> fontStyle = ValueNotifier<String>('Outfit');
  final ValueNotifier<String> language = ValueNotifier<String>('English');
  final ValueNotifier<String> currency = ValueNotifier<String>('₹');
  final ValueNotifier<String> metricSystem = ValueNotifier<String>('Metric (m, kg, °C)');

  // Available options
  static const List<String> fonts = [
    'Outfit',
    'Inter',
    'Poppins',
    'Fira Code',
    'Playfair Display'
  ];

  static const List<String> languages = [
    'English',
    'Spanish',
    'Hindi',
    'French',
    'Japanese'
  ];

  static const List<String> currencies = [
    '₹',
    '\$',
    '€',
    '£',
    '¥'
  ];

  static const List<String> metrics = [
    'Metric (m, kg, °C)',
    'Imperial (ft, lbs, °F)'
  ];

  // Font Theme Generator
  TextTheme getTextTheme(String font, TextTheme baseTheme) {
    switch (font) {
      case 'Inter':
        return GoogleFonts.interTextTheme(baseTheme);
      case 'Poppins':
        return GoogleFonts.poppinsTextTheme(baseTheme);
      case 'Fira Code':
        return GoogleFonts.firaCodeTextTheme(baseTheme);
      case 'Playfair Display':
        return GoogleFonts.playfairDisplayTextTheme(baseTheme);
      case 'Outfit':
      default:
        return GoogleFonts.outfitTextTheme(baseTheme);
    }
  }

  // Translation Helper
  static const Map<String, Map<String, String>> _localizedValues = {
    'English': {
      'home': 'Home',
      'calendar': 'Calendar',
      'tasks': 'Tasks',
      'finance': 'Finance',
      'goals': 'Goals',
      'spent_this_month': 'SPENT THIS MONTH',
      'net_saved': 'NET SAVED',
      'recent_transactions': 'RECENT TRANSACTIONS',
      'budget_limits': 'BUDGET LIMITS',
      'budgets': 'Budgets',
      'add': 'Add',
      'reset_done': 'Reset done',
      'today_tasks': 'Today\'s Tasks',
      'upcoming': 'Upcoming (7 days)',
      'notes': 'NOTES',
      'search_notes': 'Search notes...',
      'no_notes': 'No notes yet',
      'ai_assistant': 'AI Assistant',
      'ask_dash': 'Ask Dash...',
      'settings': 'Settings',
      'user_profile': 'User Profile',
      'preferences': 'Preferences',
      'font_style': 'Font Style',
      'language_label': 'Language',
      'currency_label': 'Currency Metric',
      'system_units': 'System Units',
      'save_settings': 'Save Settings',
      'daily_limits': 'Daily Limits',
      'by_source': 'BY SOURCE',
      'sources': 'Sources',
      'savings': 'Savings',
      'overview': 'Overview',
      'spending': 'SPENDING',
    },
    'Spanish': {
      'home': 'Inicio',
      'calendar': 'Calendario',
      'tasks': 'Tareas',
      'finance': 'Finanzas',
      'goals': 'Metas',
      'spent_this_month': 'GASTADO ESTE MES',
      'net_saved': 'AHORRO NETO',
      'recent_transactions': 'TRANSACCIONES RECIENTES',
      'budget_limits': 'LÍMITES DE PRESUPUESTO',
      'budgets': 'Presupuestos',
      'add': 'Añadir',
      'reset_done': 'Reiniciar',
      'today_tasks': 'Tareas de Hoy',
      'upcoming': 'Próximos (7 días)',
      'notes': 'NOTAS',
      'search_notes': 'Buscar notas...',
      'no_notes': 'Sin notas aún',
      'ai_assistant': 'Asistente IA',
      'ask_dash': 'Pregunta a Dash...',
      'settings': 'Ajustes',
      'user_profile': 'Perfil de Usuario',
      'preferences': 'Preferencias',
      'font_style': 'Estilo de Fuente',
      'language_label': 'Idioma',
      'currency_label': 'Métrica de Moneda',
      'system_units': 'Unidades del Sistema',
      'save_settings': 'Guardar Ajustes',
      'daily_limits': 'Límites Diarios',
      'by_source': 'POR FUENTE',
      'sources': 'Fuentes',
      'savings': 'Ahorros',
      'overview': 'Resumen',
      'spending': 'GASTOS',
    },
    'Hindi': {
      'home': 'होम',
      'calendar': 'कैलेंडर',
      'tasks': 'कार्य',
      'finance': 'वित्त',
      'goals': 'लक्ष्य',
      'spent_this_month': 'इस महीने का खर्च',
      'net_saved': 'शुद्ध बचत',
      'recent_transactions': 'हाल के लेन-देन',
      'budget_limits': 'बजट सीमाएं',
      'budgets': 'बजट',
      'add': 'जोड़ें',
      'reset_done': 'रीसेट करें',
      'today_tasks': 'आज के कार्य',
      'upcoming': 'आगामी (7 दिन)',
      'notes': 'नोट्स',
      'search_notes': 'नोट्स खोजें...',
      'no_notes': 'कोई नोट नहीं',
      'ai_assistant': 'एआई सहायक',
      'ask_dash': 'डैश से पूछें...',
      'settings': 'सेटिंग्स',
      'user_profile': 'उपयोगकर्ता प्रोफ़ाइल',
      'preferences': 'वरीयताएँ',
      'font_style': 'फ़ॉन्ट शैली',
      'language_label': 'भाषा',
      'currency_label': 'मुद्रा मीट्रिक',
      'system_units': 'प्रणाली इकाइयाँ',
      'save_settings': 'सेटिंग्स सहेजें',
      'daily_limits': 'दैनिक सीमाएं',
      'by_source': 'स्रोत के अनुसार',
      'sources': 'स्रोत',
      'savings': 'बचत',
      'overview': 'अवलोकन',
      'spending': 'खर्च',
    },
    'French': {
      'home': 'Accueil',
      'calendar': 'Calendrier',
      'tasks': 'Tâches',
      'finance': 'Finances',
      'goals': 'Objectifs',
      'spent_this_month': 'DÉPENSÉ CE MOIS',
      'net_saved': 'ÉCONOMIE NETTE',
      'recent_transactions': 'TRANSACTIONS RÉCENTES',
      'budget_limits': 'LIMITES BUDGÉTAIRES',
      'budgets': 'Budgets',
      'add': 'Ajouter',
      'reset_done': 'Réinitialiser',
      'today_tasks': 'Tâches du Jour',
      'upcoming': 'À venir (7 jours)',
      'notes': 'NOTES',
      'search_notes': 'Rechercher des notes...',
      'no_notes': 'Pas encore de notes',
      'ai_assistant': 'Assistant IA',
      'ask_dash': 'Demander à Dash...',
      'settings': 'Paramètres',
      'user_profile': 'Profil de l\'utilisateur',
      'preferences': 'Préférences',
      'font_style': 'Style de police',
      'language_label': 'Langue',
      'currency_label': 'Devise',
      'system_units': 'Unités système',
      'save_settings': 'Enregistrer',
      'daily_limits': 'Limites quotidiennes',
      'by_source': 'PAR SOURCE',
      'sources': 'Sources',
      'savings': 'Épargne',
      'overview': 'Aperçu',
      'spending': 'DÉPENSES',
    },
    'Japanese': {
      'home': 'ホーム',
      'calendar': 'カレンダー',
      'tasks': 'タスク',
      'finance': '金融',
      'goals': '目標',
      'spent_this_month': '今月の支出',
      'net_saved': '純貯蓄',
      'recent_transactions': '最近の取引',
      'budget_limits': '予算制限',
      'budgets': '予算',
      'add': '追加',
      'reset_done': 'リセット',
      'today_tasks': '今日のタスク',
      'upcoming': '今後の予定 (7日間)',
      'notes': 'メモ',
      'search_notes': 'メモを検索...',
      'no_notes': 'メモはまだありません',
      'ai_assistant': 'AIアシスタント',
      'ask_dash': 'Dashに聞く...',
      'settings': '設定',
      'user_profile': 'ユーザープロファイル',
      'preferences': '環境設定',
      'font_style': 'フォントスタイル',
      'language_label': '言語',
      'currency_label': '通貨単位',
      'system_units': 'システム単位',
      'save_settings': '設定を保存',
      'daily_limits': '日々の制限',
      'by_source': 'ソース別',
      'sources': 'ソース',
      'savings': '貯金',
      'overview': '概要',
      'spending': '支出',
    }
  };

  static String translate(String key) {
    final lang = instance.language.value;
    return _localizedValues[lang]?[key] ?? _localizedValues['English']![key]!;
  }
}

class MultiListenable extends ChangeNotifier {
  MultiListenable(List<Listenable> listenables) {
    for (final l in listenables) {
      l.addListener(notifyListeners);
    }
  }
}

