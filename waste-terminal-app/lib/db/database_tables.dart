class DatabaseTables {
  DatabaseTables._();

  static const int dbVersion = 8;
  static const String dbName = 'waste_terminal.db';

  static const String tableWasteCatalog = 'waste_catalog';
  static const String tableWasteContainer = 'waste_container';
  static const String tableWasteInRecord = 'waste_in_record';
  static const String tableWasteInventory = 'waste_inventory';
  static const String tableWasteOutRecord = 'waste_out_record';
  static const String tableTransferOrder = 'transfer_order';
  static const String tableInventoryCheck = 'inventory_check';
  static const String tableInventoryCheckDetail = 'inventory_check_detail';
  static const String tableWarningRecord = 'warning_record';
  static const String tableSyncLog = 'sync_log';
  static const String tableCamera = 'camera';
  static const String tableAiCaptureEvent = 'ai_capture_event';
  static const String tableLocalRecordTask = 'local_record_task';
  static const String tableUserFace = 'user_face';
  static const String tableFaceAuthRecord = 'face_auth_record';
  static const String tableTransportVehicle = 'transport_vehicle';
  static const String tableTransportDriver = 'transport_driver';
  static const String tableTransportTrack = 'transport_track';
  static const String tableTransportTrackPoint = 'transport_track_point';
  static const String tableWasteOutReview = 'waste_out_review';
  static const String tableLevelSensor = 'level_sensor';
  static const String tableLevelReading = 'level_reading';

  static const String createTableWasteCatalog = '''
    CREATE TABLE $tableWasteCatalog (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      catalog_id TEXT,
      waste_code TEXT,
      waste_name TEXT,
      waste_category TEXT,
      waste_type TEXT,
      hazard_category TEXT,
      unit TEXT,
      description TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableWasteContainer = '''
    CREATE TABLE $tableWasteContainer (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      container_id TEXT,
      container_code TEXT,
      container_name TEXT,
      container_type TEXT,
      capacity REAL,
      unit TEXT,
      status INTEGER DEFAULT 0,
      location TEXT,
      rfid_code TEXT,
      qr_code TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableWasteInRecord = '''
    CREATE TABLE $tableWasteInRecord (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      offline_id TEXT,
      record_id TEXT,
      record_no TEXT,
      waste_code TEXT,
      waste_name TEXT,
      waste_category TEXT,
      container_id TEXT,
      container_code TEXT,
      quantity REAL,
      unit TEXT,
      weight REAL,
      weight_unit TEXT,
      source TEXT,
      operator TEXT,
      operator_id TEXT,
      warehouse TEXT,
      warehouse_id TEXT,
      remark TEXT,
      in_time TEXT,
      sync_status INTEGER DEFAULT 0,
      sync_time TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0,
      face_auth_id TEXT,
      face_id TEXT,
      operator_face_image TEXT
    )
  ''';

  static const String createTableWasteInventory = '''
    CREATE TABLE $tableWasteInventory (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      inventory_id TEXT,
      waste_code TEXT,
      waste_name TEXT,
      waste_category TEXT,
      container_id TEXT,
      container_code TEXT,
      quantity REAL,
      unit TEXT,
      weight REAL,
      weight_unit TEXT,
      warehouse TEXT,
      warehouse_id TEXT,
      location TEXT,
      in_time TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableWasteOutRecord = '''
    CREATE TABLE $tableWasteOutRecord (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      offline_id TEXT,
      record_id TEXT,
      record_no TEXT,
      waste_code TEXT,
      waste_name TEXT,
      waste_category TEXT,
      container_id TEXT,
      container_code TEXT,
      quantity REAL,
      unit TEXT,
      weight REAL,
      weight_unit TEXT,
      receiver TEXT,
      receiver_id TEXT,
      operator TEXT,
      operator_id TEXT,
      warehouse TEXT,
      warehouse_id TEXT,
      remark TEXT,
      out_time TEXT,
      sync_status INTEGER DEFAULT 0,
      sync_time TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0,
      face_auth_id TEXT,
      face_id TEXT,
      operator_face_image TEXT
    )
  ''';

  static const String createTableTransferOrder = '''
    CREATE TABLE $tableTransferOrder (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      offline_id TEXT,
      order_id TEXT,
      order_no TEXT,
      waste_code TEXT,
      waste_name TEXT,
      waste_category TEXT,
      quantity REAL,
      unit TEXT,
      weight REAL,
      weight_unit TEXT,
      transferor TEXT,
      transferor_id TEXT,
      transferee TEXT,
      transferee_id TEXT,
      carrier TEXT,
      carrier_id TEXT,
      driver TEXT,
      vehicle_no TEXT,
      start_time TEXT,
      end_time TEXT,
      status INTEGER DEFAULT 0,
      remark TEXT,
      sync_status INTEGER DEFAULT 0,
      sync_time TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableInventoryCheck = '''
    CREATE TABLE $tableInventoryCheck (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      offline_id TEXT,
      check_id TEXT,
      check_no TEXT,
      check_type TEXT,
      check_time TEXT,
      checker TEXT,
      checker_id TEXT,
      warehouse TEXT,
      warehouse_id TEXT,
      status INTEGER DEFAULT 0,
      remark TEXT,
      sync_status INTEGER DEFAULT 0,
      sync_time TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableInventoryCheckDetail = '''
    CREATE TABLE $tableInventoryCheckDetail (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      detail_id TEXT,
      check_id TEXT,
      check_offline_id TEXT,
      waste_code TEXT,
      waste_name TEXT,
      waste_category TEXT,
      container_id TEXT,
      container_code TEXT,
      system_quantity REAL,
      system_weight REAL,
      check_quantity REAL,
      check_weight REAL,
      diff_quantity REAL,
      diff_weight REAL,
      unit TEXT,
      weight_unit TEXT,
      remark TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableWarningRecord = '''
    CREATE TABLE $tableWarningRecord (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      warning_id TEXT,
      warning_type TEXT,
      warning_level INTEGER,
      warning_title TEXT,
      warning_content TEXT,
      waste_code TEXT,
      waste_name TEXT,
      container_id TEXT,
      container_code TEXT,
      threshold REAL,
      current_value REAL,
      unit TEXT,
      status INTEGER DEFAULT 0,
      handle_time TEXT,
      handler TEXT,
      handler_id TEXT,
      handle_remark TEXT,
      warning_time TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableSyncLog = '''
    CREATE TABLE $tableSyncLog (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      log_id TEXT,
      sync_type TEXT,
      sync_module TEXT,
      sync_status INTEGER DEFAULT 0,
      sync_start_time TEXT,
      sync_end_time TEXT,
      total_count INTEGER DEFAULT 0,
      success_count INTEGER DEFAULT 0,
      fail_count INTEGER DEFAULT 0,
      error_msg TEXT,
      create_time TEXT
    )
  ''';

  static const String createTableUserFace = '''
    CREATE TABLE $tableUserFace (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER,
      username TEXT,
      face_id TEXT,
      face_feature TEXT,
      face_image TEXT,
      status INTEGER DEFAULT 1,
      enroll_quality INTEGER,
      device_id TEXT,
      enterprise_id INTEGER,
      remark TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableFaceAuthRecord = '''
    CREATE TABLE $tableFaceAuthRecord (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      auth_id TEXT,
      user_id INTEGER,
      username TEXT,
      real_name TEXT,
      face_id TEXT,
      similarity REAL,
      liveness_score REAL,
      face_quality INTEGER,
      auth_status INTEGER DEFAULT 0,
      auth_type TEXT,
      business_type TEXT,
      business_id TEXT,
      business_no TEXT,
      device_id TEXT,
      ip TEXT,
      auth_time TEXT,
      enterprise_id INTEGER,
      remark TEXT,
      sync_status INTEGER DEFAULT 0,
      sync_time TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableTransportVehicle = '''
    CREATE TABLE $tableTransportVehicle (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      vehicle_id TEXT,
      vehicle_no TEXT,
      vehicle_type TEXT,
      vehicle_model TEXT,
      load_weight REAL,
      load_volume REAL,
      owner_unit TEXT,
      driver_id TEXT,
      driver_name TEXT,
      road_transport_license TEXT,
      gps_terminal_id TEXT,
      amap_terminal_id TEXT,
      status INTEGER DEFAULT 0,
      remark TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableTransportDriver = '''
    CREATE TABLE $tableTransportDriver (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      driver_id TEXT,
      driver_name TEXT,
      gender TEXT,
      phone TEXT,
      id_card TEXT,
      driver_license TEXT,
      driver_license_type TEXT,
      qualification_cert TEXT,
      hazardous_cert TEXT,
      work_years INTEGER,
      vehicle_id TEXT,
      vehicle_no TEXT,
      emergency_contact TEXT,
      emergency_phone TEXT,
      photo_url TEXT,
      status INTEGER DEFAULT 0,
      remark TEXT,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableTransportTrack = '''
    CREATE TABLE $tableTransportTrack (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      track_id TEXT,
      track_no TEXT,
      transfer_order_id TEXT,
      transfer_order_no TEXT,
      vehicle_id TEXT,
      vehicle_no TEXT,
      driver_id TEXT,
      driver_name TEXT,
      start_time TEXT,
      end_time TEXT,
      start_location TEXT,
      start_lng REAL,
      start_lat REAL,
      end_location TEXT,
      end_lng REAL,
      end_lat REAL,
      current_location TEXT,
      current_lng REAL,
      current_lat REAL,
      last_gps_time TEXT,
      total_distance REAL,
      total_duration INTEGER,
      point_count INTEGER,
      expected_duration_hours REAL DEFAULT 24.0,
      expected_arrival_time TEXT,
      status INTEGER DEFAULT 0,
      source_type TEXT,
      sync_status INTEGER DEFAULT 0,
      sync_time TEXT,
      offline_points INTEGER DEFAULT 0,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static const String createTableTransportTrackPoint = '''
    CREATE TABLE $tableTransportTrackPoint (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      point_id TEXT,
      point_no TEXT,
      track_id TEXT,
      track_no TEXT,
      transfer_order_id TEXT,
      vehicle_id TEXT,
      vehicle_no TEXT,
      driver_id TEXT,
      lng REAL,
      lat REAL,
      location TEXT,
      speed REAL,
      direction REAL,
      altitude REAL,
      accuracy REAL,
      gps_time TEXT,
      source_type TEXT,
      is_offline INTEGER DEFAULT 0,
      synced INTEGER DEFAULT 0,
      extra_data TEXT,
      create_time TEXT
    )
  ''';

  static const String createTableWasteOutReview = '''
    CREATE TABLE $tableWasteOutReview (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      review_no TEXT,
      out_record_id INTEGER,
      out_no TEXT,
      out_offline_id TEXT,
      waste_id INTEGER,
      waste_code TEXT,
      waste_name TEXT,
      weight REAL,
      container_code TEXT,
      operator_id INTEGER,
      operator_name TEXT,
      reviewer_id INTEGER,
      reviewer_name TEXT,
      review_type TEXT,
      review_result INTEGER,
      review_time TEXT,
      review_remark TEXT,
      reviewer_face_auth_id TEXT,
      reviewer_face_id TEXT,
      reviewer_face_image TEXT,
      review_qr_code TEXT,
      sync_status INTEGER DEFAULT 0,
      sync_time TEXT,
      offline_id TEXT,
      enterprise_id INTEGER,
      create_time TEXT,
      update_time TEXT,
      is_deleted INTEGER DEFAULT 0
    )
  ''';

  static List<String> getAllCreateTableSql() {
    return [
      createTableWasteCatalog,
      createTableWasteContainer,
      createTableWasteInRecord,
      createTableWasteInventory,
      createTableWasteOutRecord,
      createTableTransferOrder,
      createTableInventoryCheck,
      createTableInventoryCheckDetail,
      createTableWarningRecord,
      createTableSyncLog,
      createTableCamera,
      createTableAiCaptureEvent,
      createTableLocalRecordTask,
      createTableUserFace,
      createTableFaceAuthRecord,
      createTableTransportVehicle,
      createTableTransportDriver,
      createTableTransportTrack,
      createTableTransportTrackPoint,
      createTableWasteOutReview,
    ];
  }
}
