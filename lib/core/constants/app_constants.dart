/// App-wide constants. No magic strings/numbers scattered across the codebase.
class AppConstants {
  const AppConstants._();

  static const String appName = 'Shop Manager';

  // Supabase table names ------------------------------------------------------
  static const String tblProfiles = 'profiles';
  static const String tblShops = 'shops';
  static const String tblShopMembers = 'shop_members';
  static const String tblShopInvites = 'shop_invites';
  static const String tblProducts = 'products';
  static const String tblCustomers = 'customers';
  static const String tblReceipts = 'receipts';
  static const String tblReceiptItems = 'receipt_items';
  static const String tblKhata = 'khata_transactions';
  static const String tblSearchStats = 'product_search_stats';
  static const String viewKhataBalances = 'customer_khata_balances';

  // RPC names -----------------------------------------------------------------
  static const String rpcAcceptInvite = 'accept_invite';
  static const String rpcRecordSearch = 'record_product_search';
  static const String rpcDashboard = 'dashboard_summary';

  // Storage -------------------------------------------------------------------
  static const String bucketProductImages = 'product-images';

  // Hive box names ------------------------------------------------------------
  static const String boxProducts = 'products_box';
  static const String boxCustomers = 'customers_box';
  static const String boxReceipts = 'receipts_box';
  static const String boxKhata = 'khata_box';
  static const String boxOutbox = 'outbox_box'; // pending offline mutations
  static const String boxPrefs = 'prefs_box';

  // Prefs keys ----------------------------------------------------------------
  static const String prefLastShopId = 'last_shop_id';
  static const String prefThemeMode = 'theme_mode';
  static const String prefKhataReminders = 'khata_reminders_enabled';

  // Misc ----------------------------------------------------------------------
  static const Duration searchDebounce = Duration(milliseconds: 250);
  static const int lowStockThreshold = 5;
  static const List<String> defaultUnits = [
    'pcs', 'kg', 'g', 'litre', 'ml', 'box', 'bag', 'gallon', 'roll', 'metre',
  ];
}
