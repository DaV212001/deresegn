import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppSettings {
  static const _storage = FlutterSecureStorage();

  static const String _keyCashierName = 'cashier_name';
  static const String _keySystemNumber = 'system_number';
  static const String _keyDefaultCity = 'default_city';
  static const String _keyTradeName = 'trade_name';
  static const String _keyVatNumber = 'vat_number';

  static Future<void> saveSettings({
    required String cashierName,
    required String systemNumber,
    required String defaultCity,
    required String tradeName,
    required String vatNumber,
  }) async {
    await _storage.write(key: _keyCashierName, value: cashierName);
    await _storage.write(key: _keySystemNumber, value: systemNumber);
    await _storage.write(key: _keyDefaultCity, value: defaultCity);
    await _storage.write(key: _keyTradeName, value: tradeName);
    await _storage.write(key: _keyVatNumber, value: vatNumber);
  }

  static Future<String> getCashierName() async =>
      (await _storage.read(key: _keyCashierName)) ?? 'Default Cashier';

  static Future<String> getSystemNumber() async =>
      (await _storage.read(key: _keySystemNumber)) ?? 'F86A66EF99';

  static Future<String> getDefaultCity() async =>
      (await _storage.read(key: _keyDefaultCity)) ?? '101';

  static Future<String> getTradeName() async =>
      (await _storage.read(key: _keyTradeName)) ?? 'MicroSun&SolutionPLC';

  static Future<String> getVatNumber() async =>
      (await _storage.read(key: _keyVatNumber)) ?? '43256663343256663322';
}
