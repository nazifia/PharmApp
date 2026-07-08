/// Nigerian (NCC) mobile number helpers.
///
/// Valid mobile numbers are 11 digits in local format `0XXXXXXXXXX` with
/// network prefixes 070x, 080x, 081x, 090x, 091x, or the same number in
/// international form `+234…` / `234…`.
library;

final _ngMobile = RegExp(r'^0(70|80|81|90|91)\d{8}$');
final _strip = RegExp(r'[\s\-().]');

/// Returns the canonical local form `0XXXXXXXXXX`, or null if invalid.
String? normalizeNigerianPhone(String raw) {
  var digits = raw.replaceAll(_strip, '');
  if (digits.startsWith('+234')) {
    digits = '0${digits.substring(4)}';
  } else if (digits.startsWith('234') && digits.length == 13) {
    digits = '0${digits.substring(3)}';
  }
  return _ngMobile.hasMatch(digits) ? digits : null;
}

/// TextFormField validator for a required Nigerian mobile number.
String? nigerianPhoneValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Enter phone number';
  if (normalizeNigerianPhone(v) == null) {
    return 'Enter a valid Nigerian number (e.g. 08012345678)';
  }
  return null;
}

/// Same as [nigerianPhoneValidator] but an empty field is allowed.
String? nigerianPhoneValidatorOptional(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  return nigerianPhoneValidator(v);
}

// NCC geographic fixed lines: 0 + area code + subscriber, 9–11 digits.
final _ngLandline = RegExp(r'^0[1-9]\d{7,9}$');

/// True for a valid Nigerian mobile OR fixed-line number.
/// Use for business contacts (suppliers, hospitals) where landlines are legal.
bool isValidNigerianContactPhone(String raw) {
  if (normalizeNigerianPhone(raw) != null) return true;
  return _ngLandline.hasMatch(raw.replaceAll(_strip, ''));
}
