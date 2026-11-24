class PhoneUtils {
  /// Regular expression matching standard Ethiopian mobile phone format in 10-digit local format:
  /// Starts with 0, followed by 7 or 9, followed by 8 digits (10 digits total).
  /// regex: /^0[79]\d{8}$/
  static final RegExp ethiopianPhoneRegex = RegExp(r'^0[79]\d{8}$');

  /// Regular expression matching Ethiopian mobile phone format in 12-digit international/auth format:
  /// Starts with 251, followed by 7 or 9, followed by 8 digits (12 digits total).
  /// regex: /^251[79]\d{8}$/
  static final RegExp ethiopianAuthPhoneRegex = RegExp(r'^251[79]\d{8}$');

  /// Formats any Ethiopian phone number into the required auth/backend format:
  /// `2519xxxxxxxx` or `2517xxxxxxxx` (12 digits, starting with 251).
  ///
  /// Examples:
  /// - `0912345678`    -> `251912345678`
  /// - `912345678`     -> `251912345678`
  /// - `0712345678`    -> `251712345678`
  /// - `712345678`     -> `251712345678`
  /// - `+251912345678` -> `251912345678`
  /// - `251912345678`  -> `251912345678`
  static String formatForAuth(String? phone) {
    if (phone == null) return '';
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    // Case 1: 12 digits starting with 2519 or 2517
    if (digits.length == 12 && (digits.startsWith('2519') || digits.startsWith('2517'))) {
      return digits;
    }
    // Case 2: 10 digits starting with 09 or 07
    if (digits.length == 10 && (digits.startsWith('09') || digits.startsWith('07'))) {
      return '251${digits.substring(1)}';
    }
    // Case 3: 9 digits starting with 9 or 7
    if (digits.length == 9 && (digits.startsWith('9') || digits.startsWith('7'))) {
      return '251$digits';
    }

    // Fallbacks
    if (digits.startsWith('251') && digits.length >= 12) {
      return digits;
    }
    if (digits.startsWith('0') && digits.length >= 10) {
      return '251${digits.substring(1)}';
    }
    if (digits.startsWith('9') || digits.startsWith('7')) {
      return '251$digits';
    }

    return digits;
  }

  /// Formats any Ethiopian phone number into the required payment initialization format:
  /// `09xxxxxxxx` or `07xxxxxxxx` (10 digits starting with 0, matching regex `/^0[79]\d{8}$/`).
  ///
  /// Examples:
  /// - `251912345678`  -> `0912345678`
  /// - `+251912345678` -> `0912345678`
  /// - `912345678`     -> `0912345678`
  /// - `0912345678`    -> `0912345678`
  /// - `251712345678`  -> `0712345678`
  /// - `0712345678`    -> `0712345678`
  /// - `712345678`     -> `0712345678`
  static String formatForPayment(String? phone) {
    if (phone == null) return '';
    String digits = phone.replaceAll(RegExp(r'\D'), '');

    // Case 1: 12 digits starting with 2519 or 2517
    if (digits.length == 12 && digits.startsWith('251')) {
      return '0${digits.substring(3)}';
    }
    // Case 2: 10 digits starting with 09 or 07
    if (digits.length == 10 && (digits.startsWith('09') || digits.startsWith('07'))) {
      return digits;
    }
    // Case 3: 9 digits starting with 9 or 7
    if (digits.length == 9 && (digits.startsWith('9') || digits.startsWith('7'))) {
      return '0$digits';
    }

    // Fallback
    if (digits.startsWith('251') && digits.length >= 12) {
      return '0${digits.substring(3)}';
    }
    if (digits.startsWith('9') || digits.startsWith('7')) {
      return '0$digits';
    }

    return digits;
  }

  /// Alias for formatForPayment:
  /// Normalizes into 10-digit format starting with 0 (`/^0[79]\d{8}$/`).
  static String normalize(String? phone) => formatForPayment(phone);

  /// Checks if the phone number represents a valid Ethiopian mobile phone:
  /// Matches valid inputs whether entered as:
  /// - 9 digits starting with 9 or 7 (e.g. `912345678`, `712345678`)
  /// - 10 digits starting with 09 or 07 (e.g. `0912345678`, `0712345678`)
  /// - 12 digits starting with 2519 or 2517 (e.g. `251912345678`, `+251912345678`)
  static bool isValidEthiopianPhone(String? phone, {bool autoNormalize = true}) {
    if (phone == null || phone.trim().isEmpty) return false;
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length == 9 && (digits.startsWith('9') || digits.startsWith('7'))) {
      return true;
    }
    if (digits.length == 10 && (digits.startsWith('09') || digits.startsWith('07'))) {
      return true;
    }
    if (digits.length == 12 && (digits.startsWith('2519') || digits.startsWith('2517'))) {
      return true;
    }
    return false;
  }

  /// Formats phone number for user display (e.g. `+251 912345678` or `0912345678`).
  static String formatForDisplay(String? phone) {
    if (phone == null || phone.isEmpty) return '';
    final auth = formatForAuth(phone);
    if (auth.startsWith('251') && auth.length == 12) {
      return '+251 ${auth.substring(3)}';
    }
    return phone;
  }

  /// Returns the exception phone number in local 09 format if this phone/credential matches
  /// any known backend exception (e.g. 0949384998, 0930549842).
  /// Otherwise returns null.
  static String? getExceptionPhoneNumber(String? phone, [String? password]) {
    if (phone == null) return null;
    final digits = phone.replaceAll(RegExp(r'\D'), '');

    // Exception: 0949384998
    if (digits == '0949384998' || digits == '251949384998' || digits == '949384998') {
      if (password == null || password.trim() == 'Maru@123') {
        return '0949384998';
      }
    }

    // Exception: 0930549842
    if (digits == '0930549842' || digits == '251930549842' || digits == '930549842') {
      return '0930549842';
    }

    return null;
  }

  /// Checks if the credential matches a specific exception credential.
  static bool isExceptionCredential(String? phone, String? password) {
    return getExceptionPhoneNumber(phone, password) != null;
  }
}
