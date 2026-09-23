import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ponytail: English-keyed lookup map instead of ARB/gen-l10n. Covers the
// cashier path (login, POS, cart, payment, receipt, dashboard). Untranslated
// strings fall back to English. Move to gen-l10n if a third language lands.

const kLanguages = ['English', 'Hausa'];
const _prefsKey = 'app_language';

String _lang = 'English';
String get currentLanguage => _lang;

Future<void> loadLanguage() async {
  final prefs = await SharedPreferences.getInstance();
  final saved = prefs.getString(_prefsKey);
  if (saved != null && kLanguages.contains(saved)) _lang = saved;
}

/// Saves [lang] and rebuilds the whole widget tree so every `.tr` re-reads.
Future<void> setLanguage(String lang) async {
  _lang = lang;
  void rebuild(Element el) {
    el.markNeedsBuild();
    el.visitChildren(rebuild);
  }
  WidgetsBinding.instance.rootElement?.visitChildren(rebuild);
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefsKey, lang);
}

extension Tr on String {
  String get tr => _lang == 'Hausa' ? (_ha[this] ?? this) : this;
}

const _ha = <String, String>{
  // Settings
  'Language': 'Harshe',

  // Login
  'Pharmacy Management System': 'Tsarin Gudanar da Kantin Magani',
  'Welcome back': 'Barka da dawowa',
  'Sign in with your phone number and password': 'Shiga da lambar wayarka da kalmar sirri',
  'Phone Number': 'Lambar Waya',
  'Password': 'Kalmar Sirri',

  // POS
  'Select Branch': 'Zaɓi Reshe',
  'All Branches': 'Duk Rassa',
  'Show items across all branches': 'Nuna kaya daga duk rassa',
  'No branches available.': 'Babu reshe.',
  'Select Customer': 'Zaɓi Abokin Ciniki',
  'Clear': 'Share',
  'Search customers…': 'Nemo abokin ciniki…',
  'No customers found': 'Ba a sami abokin ciniki ba',
  'Try a different name or phone number': 'Gwada wani suna ko lambar waya',
  'Retail POS': 'Sayar da Magani',
  'Link a customer (optional)': 'Haɗa abokin ciniki (ba dole ba)',
  'Search items by name, brand, barcode…': 'Nemo magani da suna, kamfani ko barcode…',
  'Loading catalogue…': 'Ana loda kaya…',
  'Failed to load items': 'An kasa loda kaya',
  'Retry': 'Sake gwadawa',
  'No items found': 'Ba a sami kaya ba',
  'Tap to add': 'Taɓa don ƙarawa',
  'Drug Warnings': 'Gargaɗin Magani',
  'Understood': 'Na fahimta',
  'Checking drug interactions…': 'Ana duba haɗuwar magunguna…',
  'Cart is empty': 'Kwando babu komai',
  'Tap any item to add': 'Taɓa kowane kaya don ƙarawa',
  'Checkout': 'Biya',
  'Discount:': 'Ragi:',

  // Cart
  'Send to Cashier': 'Tura wa Mai Karɓar Kuɗi',
  'Patient / Customer name (optional)': 'Sunan majinyaci / abokin ciniki (ba dole ba)',
  'Cancel': 'Soke',
  'Send': 'Tura',
  'Search cart items…': 'Nemo a cikin kwando…',
  'Cart': 'Kwando',
  'Go back and tap an item to add it': 'Koma ka taɓa kaya don ƙarawa',
  'Back to catalogue': 'Koma ga kaya',

  // Payment
  'Sale Saved Offline': 'An ajiye ciniki ba tare da intanet ba',
  'View Receipt': 'Duba Rasiti',
  'OK, Got It': 'To, na gane',
  'Payment': 'Biyan Kuɗi',
  'Complete the transaction': 'Kammala cinikin',
  'Total Amount': 'Jimillar Kuɗi',
  'Buyer Name (optional)': 'Sunan Mai Saye (ba dole ba)',
  'Payment Method': 'Hanyar Biya',
  'Split Amounts': 'Raba Kuɗin',
  'Selected': 'An zaɓa',
  'Payment Successful!': 'An biya cikin nasara!',
  'New Sale': 'Sabon Ciniki',

  // Receipt (screen only; printed receipt stays English)
  'Receipt': 'Rasiti',
  'Print or share this receipt': 'Buga ko tura wannan rasiti',
  'Printed successfully': 'An buga cikin nasara',
  'Share Receipt': 'Tura Rasiti',
  'Share as Text': 'Tura a matsayin rubutu',
  'Send via WhatsApp, SMS or any app': 'Tura ta WhatsApp, SMS ko wata manhaja',
  'Share as Image': 'Tura a matsayin hoto',
  'Sale Completed': 'An kammala ciniki',
  'Send to customer on WhatsApp': 'Tura wa abokin ciniki ta WhatsApp',

  // Customer
  'Remind on WhatsApp': 'Tunatar ta WhatsApp',

  // Dashboard
  "Today's Sales": 'Cinikin Yau',
  "Today's Profit": 'Ribar Yau',
  'Expiring Soon': 'Zai Kusa Lalacewa',
  'Within 30 days': 'Cikin kwana 30',
  'Money in today': 'Kuɗin da aka samu yau',
  'After cost of drugs': 'Bayan cire kuɗin magani',
  'Inventory': 'Kaya',
  'Customers': 'Abokan Ciniki',
  'More': 'Ƙari',
  'Low Stock': 'Kaya Sun Kusa Ƙarewa',
  'Below threshold': 'Ƙasa da iyaka',
  'Good morning': 'Barka da safiya',
  'Good afternoon': 'Barka da rana',
  'Good evening': 'Barka da yamma',
};
