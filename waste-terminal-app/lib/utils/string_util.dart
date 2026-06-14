class StringUtil {
  StringUtil._();

  static bool isEmpty(String? str) {
    return str == null || str.isEmpty;
  }

  static bool isNotEmpty(String? str) {
    return !isEmpty(str);
  }

  static bool isBlank(String? str) {
    return str == null || str.trim().isEmpty;
  }

  static bool isNotBlank(String? str) {
    return !isBlank(str);
  }

  static String? trim(String? str) {
    return str?.trim();
  }

  static String defaultString(String? str, [String defaultValue = '']) {
    return isEmpty(str) ? defaultValue : str!;
  }

  static String? obscurePhone(String? phone) {
    if (isEmpty(phone) || phone!.length < 11) return phone;
    return phone.replaceRange(3, 7, '****');
  }

  static String? obscureIdCard(String? idCard) {
    if (isEmpty(idCard) || idCard!.length < 8) return idCard;
    return idCard.replaceRange(4, idCard.length - 4, '********');
  }

  static String? obscureEmail(String? email) {
    if (isEmpty(email) || !email!.contains('@')) return email;
    final parts = email.split('@');
    final name = parts.first;
    final domain = parts.last;
    if (name.length <= 2) {
      return '***@$domain';
    }
    return '${name.substring(0, 2)}***@$domain';
  }

  static String? obscureBankCard(String? cardNo) {
    if (isEmpty(cardNo) || cardNo!.length < 8) return cardNo;
    return cardNo.replaceRange(4, cardNo.length - 4, ' **** **** ');
  }

  static bool equalsIgnoreCase(String? a, String? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    return a.toLowerCase() == b.toLowerCase();
  }

  static String? capitalize(String? str) {
    if (isEmpty(str)) return str;
    return str![0].toUpperCase() + str.substring(1);
  }

  static String? capitalizeWords(String? str) {
    if (isEmpty(str)) return str;
    return str!.split(' ').map((e) => capitalize(e)).join(' ');
  }

  static String reverse(String? str) {
    if (isEmpty(str)) return '';
    return str!.split('').reversed.join();
  }

  static int countMatches(String? str, String? subStr) {
    if (isEmpty(str) || isEmpty(subStr)) return 0;
    int count = 0;
    int index = 0;
    while (true) {
      index = str!.indexOf(subStr!, index);
      if (index == -1) break;
      count++;
      index += subStr.length;
    }
    return count;
  }

  static String? removePrefix(String? str, String prefix) {
    if (str == null || !str.startsWith(prefix)) return str;
    return str.substring(prefix.length);
  }

  static String? removeSuffix(String? str, String suffix) {
    if (str == null || !str.endsWith(suffix)) return str;
    return str.substring(0, str.length - suffix.length);
  }

  static List<String> split(String? str, String delimiter) {
    if (isEmpty(str)) return [];
    return str!.split(delimiter);
  }

  static String join(List<String>? list, [String separator = '']) {
    if (list == null || list.isEmpty) return '';
    return list.join(separator);
  }

  static bool isNumeric(String? str) {
    if (str == null || str.isEmpty) return false;
    return num.tryParse(str) != null;
  }

  static bool isEmail(String? str) {
    if (isEmpty(str)) return false;
    final emailRegex = RegExp(r'^[\w-]+(\.[\w-]+)*@[\w-]+(\.[\w-]+)+$');
    return emailRegex.hasMatch(str!);
  }

  static bool isPhone(String? str) {
    if (isEmpty(str)) return false;
    final phoneRegex = RegExp(r'^1[3-9]\d{9}$');
    return phoneRegex.hasMatch(str!);
  }

  static bool isIdCard(String? str) {
    if (isEmpty(str)) return false;
    final idCardRegex =
        RegExp(r'^[1-9]\d{5}(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[\dXx]$');
    return idCardRegex.hasMatch(str!);
  }

  static bool isUrl(String? str) {
    if (isEmpty(str)) return false;
    final urlRegex = RegExp(r'^https?://[^\s]+');
    return urlRegex.hasMatch(str!);
  }

  static String? limitLength(String? str, int maxLength, [String suffix = '...']) {
    if (isEmpty(str) || str!.length <= maxLength) return str;
    return str.substring(0, maxLength) + suffix;
  }

  static String padLeft(String? str, int length, [String pad = '0']) {
    if (str == null) return pad * length;
    if (str.length >= length) return str;
    return pad * (length - str.length) + str;
  }

  static String padRight(String? str, int length, [String pad = '0']) {
    if (str == null) return pad * length;
    if (str.length >= length) return str;
    return str + pad * (length - str.length);
  }

  static String randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final result = StringBuffer();
    for (var i = 0; i < length; i++) {
      result.write(chars[i % chars.length]);
    }
    return result.toString();
  }
}
