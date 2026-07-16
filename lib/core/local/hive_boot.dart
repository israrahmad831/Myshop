import 'package:hive_flutter/hive_flutter.dart';

import '../constants/app_constants.dart';

/// Opens all Hive boxes used for offline caching. Called once at boot.
///
/// We store cached rows as plain `Map` (JSON) to avoid a large amount of
/// generated TypeAdapter code; each feature (de)serialises its own model.
class HiveBoot {
  const HiveBoot._();

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox<Map>(AppConstants.boxProducts),
      Hive.openBox<Map>(AppConstants.boxCustomers),
      Hive.openBox<Map>(AppConstants.boxReceipts),
      Hive.openBox<Map>(AppConstants.boxKhata),
      Hive.openBox<Map>(AppConstants.boxOutbox),
      Hive.openBox(AppConstants.boxPrefs),
    ]);
  }
}
