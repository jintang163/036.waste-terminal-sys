class TransportTrack {
  final int? id;
  final String? trackId;
  final String? trackNo;
  final String? transferOrderId;
  final String? transferOrderNo;
  final String? vehicleId;
  final String? vehicleNo;
  final String? driverId;
  final String? driverName;
  final DateTime? startTime;
  final DateTime? endTime;
  final String? startLocation;
  final double? startLng;
  final double? startLat;
  final String? endLocation;
  final double? endLng;
  final double? endLat;
  final String? currentLocation;
  final double? currentLng;
  final double? currentLat;
  final DateTime? lastGpsTime;
  final double? totalDistance;
  final int? totalDuration;
  final int? pointCount;
  final double? expectedDurationHours;
  final DateTime? expectedArrivalTime;
  final int? status;
  final String? sourceType;
  final int? syncStatus;
  final DateTime? syncTime;
  final int? offlinePoints;
  final DateTime? createTime;
  final DateTime? updateTime;
  final int? isDeleted;

  TransportTrack({
    this.id,
    this.trackId,
    this.trackNo,
    this.transferOrderId,
    this.transferOrderNo,
    this.vehicleId,
    this.vehicleNo,
    this.driverId,
    this.driverName,
    this.startTime,
    this.endTime,
    this.startLocation,
    this.startLng,
    this.startLat,
    this.endLocation,
    this.endLng,
    this.endLat,
    this.currentLocation,
    this.currentLng,
    this.currentLat,
    this.lastGpsTime,
    this.totalDistance,
    this.totalDuration,
    this.pointCount,
    this.expectedDurationHours,
    this.expectedArrivalTime,
    this.status,
    this.sourceType,
    this.syncStatus,
    this.syncTime,
    this.offlinePoints,
    this.createTime,
    this.updateTime,
    this.isDeleted,
  });

  factory TransportTrack.fromJson(Map<String, dynamic> json) {
    return TransportTrack(
      id: json['id'] as int?,
      trackId: json['trackId'] as String?,
      trackNo: json['trackNo'] as String?,
      transferOrderId: json['transferOrderId'] as String?,
      transferOrderNo: json['transferOrderNo'] as String?,
      vehicleId: json['vehicleId'] as String?,
      vehicleNo: json['vehicleNo'] as String?,
      driverId: json['driverId'] as String?,
      driverName: json['driverName'] as String?,
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime'] as String)
          : null,
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'] as String)
          : null,
      startLocation: json['startLocation'] as String?,
      startLng: (json['startLng'] as num?)?.toDouble(),
      startLat: (json['startLat'] as num?)?.toDouble(),
      endLocation: json['endLocation'] as String?,
      endLng: (json['endLng'] as num?)?.toDouble(),
      endLat: (json['endLat'] as num?)?.toDouble(),
      currentLocation: json['currentLocation'] as String?,
      currentLng: (json['currentLng'] as num?)?.toDouble(),
      currentLat: (json['currentLat'] as num?)?.toDouble(),
      lastGpsTime: json['lastGpsTime'] != null
          ? DateTime.tryParse(json['lastGpsTime'] as String)
          : null,
      totalDistance: (json['totalDistance'] as num?)?.toDouble(),
      totalDuration: json['totalDuration'] as int?,
      pointCount: json['pointCount'] as int?,
      expectedDurationHours:
          (json['expectedDurationHours'] as num?)?.toDouble(),
      expectedArrivalTime: json['expectedArrivalTime'] != null
          ? DateTime.tryParse(json['expectedArrivalTime'] as String)
          : null,
      status: json['status'] as int?,
      sourceType: json['sourceType'] as String?,
      syncStatus: json['syncStatus'] as int?,
      syncTime: json['syncTime'] != null
          ? DateTime.tryParse(json['syncTime'] as String)
          : null,
      offlinePoints: json['offlinePoints'] as int?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
      updateTime: json['updateTime'] != null
          ? DateTime.tryParse(json['updateTime'] as String)
          : null,
      isDeleted: json['isDeleted'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trackId': trackId,
      'trackNo': trackNo,
      'transferOrderId': transferOrderId,
      'transferOrderNo': transferOrderNo,
      'vehicleId': vehicleId,
      'vehicleNo': vehicleNo,
      'driverId': driverId,
      'driverName': driverName,
      'startTime': startTime?.toIso8601String(),
      'endTime': endTime?.toIso8601String(),
      'startLocation': startLocation,
      'startLng': startLng,
      'startLat': startLat,
      'endLocation': endLocation,
      'endLng': endLng,
      'endLat': endLat,
      'currentLocation': currentLocation,
      'currentLng': currentLng,
      'currentLat': currentLat,
      'lastGpsTime': lastGpsTime?.toIso8601String(),
      'totalDistance': totalDistance,
      'totalDuration': totalDuration,
      'pointCount': pointCount,
      'expectedDurationHours': expectedDurationHours,
      'expectedArrivalTime': expectedArrivalTime?.toIso8601String(),
      'status': status,
      'sourceType': sourceType,
      'syncStatus': syncStatus,
      'syncTime': syncTime?.toIso8601String(),
      'offlinePoints': offlinePoints,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime?.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  factory TransportTrack.fromDbMap(Map<String, dynamic> map) {
    return TransportTrack(
      id: map['id'] as int?,
      trackId: map['track_id'] as String?,
      trackNo: map['track_no'] as String?,
      transferOrderId: map['transfer_order_id'] as String?,
      transferOrderNo: map['transfer_order_no'] as String?,
      vehicleId: map['vehicle_id'] as String?,
      vehicleNo: map['vehicle_no'] as String?,
      driverId: map['driver_id'] as String?,
      driverName: map['driver_name'] as String?,
      startTime: map['start_time'] != null
          ? DateTime.tryParse(map['start_time'] as String)
          : null,
      endTime: map['end_time'] != null
          ? DateTime.tryParse(map['end_time'] as String)
          : null,
      startLocation: map['start_location'] as String?,
      startLng: (map['start_lng'] as num?)?.toDouble(),
      startLat: (map['start_lat'] as num?)?.toDouble(),
      endLocation: map['end_location'] as String?,
      endLng: (map['end_lng'] as num?)?.toDouble(),
      endLat: (map['end_lat'] as num?)?.toDouble(),
      currentLocation: map['current_location'] as String?,
      currentLng: (map['current_lng'] as num?)?.toDouble(),
      currentLat: (map['current_lat'] as num?)?.toDouble(),
      lastGpsTime: map['last_gps_time'] != null
          ? DateTime.tryParse(map['last_gps_time'] as String)
          : null,
      totalDistance: (map['total_distance'] as num?)?.toDouble(),
      totalDuration: map['total_duration'] as int?,
      pointCount: map['point_count'] as int?,
      expectedDurationHours:
          (map['expected_duration_hours'] as num?)?.toDouble(),
      expectedArrivalTime: map['expected_arrival_time'] != null
          ? DateTime.tryParse(map['expected_arrival_time'] as String)
          : null,
      status: map['status'] as int?,
      sourceType: map['source_type'] as String?,
      syncStatus: map['sync_status'] as int?,
      syncTime: map['sync_time'] != null
          ? DateTime.tryParse(map['sync_time'] as String)
          : null,
      offlinePoints: map['offline_points'] as int?,
      createTime: map['create_time'] != null
          ? DateTime.tryParse(map['create_time'] as String)
          : null,
      updateTime: map['update_time'] != null
          ? DateTime.tryParse(map['update_time'] as String)
          : null,
      isDeleted: map['is_deleted'] as int?,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'track_id': trackId,
      'track_no': trackNo,
      'transfer_order_id': transferOrderId,
      'transfer_order_no': transferOrderNo,
      'vehicle_id': vehicleId,
      'vehicle_no': vehicleNo,
      'driver_id': driverId,
      'driver_name': driverName,
      'start_time': startTime?.toIso8601String(),
      'end_time': endTime?.toIso8601String(),
      'start_location': startLocation,
      'start_lng': startLng,
      'start_lat': startLat,
      'end_location': endLocation,
      'end_lng': endLng,
      'end_lat': endLat,
      'current_location': currentLocation,
      'current_lng': currentLng,
      'current_lat': currentLat,
      'last_gps_time': lastGpsTime?.toIso8601String(),
      'total_distance': totalDistance,
      'total_duration': totalDuration,
      'point_count': pointCount,
      'expected_duration_hours': expectedDurationHours,
      'expected_arrival_time': expectedArrivalTime?.toIso8601String(),
      'status': status,
      'source_type': sourceType,
      'sync_status': syncStatus,
      'sync_time': syncTime?.toIso8601String(),
      'offline_points': offlinePoints,
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime?.toIso8601String(),
      'is_deleted': isDeleted,
    };
  }

  TransportTrack copyWith({
    int? id,
    String? trackId,
    String? trackNo,
    String? transferOrderId,
    String? transferOrderNo,
    String? vehicleId,
    String? vehicleNo,
    String? driverId,
    String? driverName,
    DateTime? startTime,
    DateTime? endTime,
    String? startLocation,
    double? startLng,
    double? startLat,
    String? endLocation,
    double? endLng,
    double? endLat,
    String? currentLocation,
    double? currentLng,
    double? currentLat,
    DateTime? lastGpsTime,
    double? totalDistance,
    int? totalDuration,
    int? pointCount,
    double? expectedDurationHours,
    DateTime? expectedArrivalTime,
    int? status,
    String? sourceType,
    int? syncStatus,
    DateTime? syncTime,
    int? offlinePoints,
    DateTime? createTime,
    DateTime? updateTime,
    int? isDeleted,
  }) {
    return TransportTrack(
      id: id ?? this.id,
      trackId: trackId ?? this.trackId,
      trackNo: trackNo ?? this.trackNo,
      transferOrderId: transferOrderId ?? this.transferOrderId,
      transferOrderNo: transferOrderNo ?? this.transferOrderNo,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      startLocation: startLocation ?? this.startLocation,
      startLng: startLng ?? this.startLng,
      startLat: startLat ?? this.startLat,
      endLocation: endLocation ?? this.endLocation,
      endLng: endLng ?? this.endLng,
      endLat: endLat ?? this.endLat,
      currentLocation: currentLocation ?? this.currentLocation,
      currentLng: currentLng ?? this.currentLng,
      currentLat: currentLat ?? this.currentLat,
      lastGpsTime: lastGpsTime ?? this.lastGpsTime,
      totalDistance: totalDistance ?? this.totalDistance,
      totalDuration: totalDuration ?? this.totalDuration,
      pointCount: pointCount ?? this.pointCount,
      expectedDurationHours:
          expectedDurationHours ?? this.expectedDurationHours,
      expectedArrivalTime: expectedArrivalTime ?? this.expectedArrivalTime,
      status: status ?? this.status,
      sourceType: sourceType ?? this.sourceType,
      syncStatus: syncStatus ?? this.syncStatus,
      syncTime: syncTime ?? this.syncTime,
      offlinePoints: offlinePoints ?? this.offlinePoints,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
      isDeleted: isDeleted ?? this.isDeleted,
    );
  }
}

class TrackPoint {
  final int? id;
  final String? pointId;
  final String? pointNo;
  final String? trackId;
  final String? trackNo;
  final String? transferOrderId;
  final String? vehicleId;
  final String? vehicleNo;
  final String? driverId;
  final double? lng;
  final double? lat;
  final String? location;
  final double? speed;
  final double? direction;
  final double? altitude;
  final double? accuracy;
  final DateTime? gpsTime;
  final String? sourceType;
  final int? isOffline;
  final int? synced;
  final String? extraData;
  final DateTime? createTime;

  TrackPoint({
    this.id,
    this.pointId,
    this.pointNo,
    this.trackId,
    this.trackNo,
    this.transferOrderId,
    this.vehicleId,
    this.vehicleNo,
    this.driverId,
    this.lng,
    this.lat,
    this.location,
    this.speed,
    this.direction,
    this.altitude,
    this.accuracy,
    this.gpsTime,
    this.sourceType,
    this.isOffline,
    this.synced,
    this.extraData,
    this.createTime,
  });

  factory TrackPoint.fromJson(Map<String, dynamic> json) {
    return TrackPoint(
      id: json['id'] as int?,
      pointId: json['pointId'] as String?,
      pointNo: json['pointNo'] as String?,
      trackId: json['trackId'] as String?,
      trackNo: json['trackNo'] as String?,
      transferOrderId: json['transferOrderId'] as String?,
      vehicleId: json['vehicleId'] as String?,
      vehicleNo: json['vehicleNo'] as String?,
      driverId: json['driverId'] as String?,
      lng: (json['lng'] as num?)?.toDouble(),
      lat: (json['lat'] as num?)?.toDouble(),
      location: json['location'] as String?,
      speed: (json['speed'] as num?)?.toDouble(),
      direction: (json['direction'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      gpsTime: json['gpsTime'] != null
          ? DateTime.tryParse(json['gpsTime'] as String)
          : null,
      sourceType: json['sourceType'] as String?,
      isOffline: json['isOffline'] as int?,
      synced: json['synced'] as int?,
      extraData: json['extraData'] as String?,
      createTime: json['createTime'] != null
          ? DateTime.tryParse(json['createTime'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pointId': pointId,
      'pointNo': pointNo,
      'trackId': trackId,
      'trackNo': trackNo,
      'transferOrderId': transferOrderId,
      'vehicleId': vehicleId,
      'vehicleNo': vehicleNo,
      'driverId': driverId,
      'lng': lng,
      'lat': lat,
      'location': location,
      'speed': speed,
      'direction': direction,
      'altitude': altitude,
      'accuracy': accuracy,
      'gpsTime': gpsTime?.toIso8601String(),
      'sourceType': sourceType,
      'isOffline': isOffline,
      'synced': synced,
      'extraData': extraData,
      'createTime': createTime?.toIso8601String(),
    };
  }

  factory TrackPoint.fromDbMap(Map<String, dynamic> map) {
    return TrackPoint(
      id: map['id'] as int?,
      pointId: map['point_id'] as String?,
      pointNo: map['point_no'] as String?,
      trackId: map['track_id'] as String?,
      trackNo: map['track_no'] as String?,
      transferOrderId: map['transfer_order_id'] as String?,
      vehicleId: map['vehicle_id'] as String?,
      vehicleNo: map['vehicle_no'] as String?,
      driverId: map['driver_id'] as String?,
      lng: (map['lng'] as num?)?.toDouble(),
      lat: (map['lat'] as num?)?.toDouble(),
      location: map['location'] as String?,
      speed: (map['speed'] as num?)?.toDouble(),
      direction: (map['direction'] as num?)?.toDouble(),
      altitude: (map['altitude'] as num?)?.toDouble(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      gpsTime: map['gps_time'] != null
          ? DateTime.tryParse(map['gps_time'] as String)
          : null,
      sourceType: map['source_type'] as String?,
      isOffline: map['is_offline'] as int?,
      synced: map['synced'] as int?,
      extraData: map['extra_data'] as String?,
      createTime: map['create_time'] != null
          ? DateTime.tryParse(map['create_time'] as String)
          : null,
    );
  }

  Map<String, dynamic> toDbMap() {
    return {
      'id': id,
      'point_id': pointId,
      'point_no': pointNo,
      'track_id': trackId,
      'track_no': trackNo,
      'transfer_order_id': transferOrderId,
      'vehicle_id': vehicleId,
      'vehicle_no': vehicleNo,
      'driver_id': driverId,
      'lng': lng,
      'lat': lat,
      'location': location,
      'speed': speed,
      'direction': direction,
      'altitude': altitude,
      'accuracy': accuracy,
      'gps_time': gpsTime?.toIso8601String(),
      'source_type': sourceType,
      'is_offline': isOffline,
      'synced': synced,
      'extra_data': extraData,
      'create_time': createTime?.toIso8601String(),
    };
  }

  TrackPoint copyWith({
    int? id,
    String? pointId,
    String? pointNo,
    String? trackId,
    String? trackNo,
    String? transferOrderId,
    String? vehicleId,
    String? vehicleNo,
    String? driverId,
    double? lng,
    double? lat,
    String? location,
    double? speed,
    double? direction,
    double? altitude,
    double? accuracy,
    DateTime? gpsTime,
    String? sourceType,
    int? isOffline,
    int? synced,
    String? extraData,
    DateTime? createTime,
  }) {
    return TrackPoint(
      id: id ?? this.id,
      pointId: pointId ?? this.pointId,
      pointNo: pointNo ?? this.pointNo,
      trackId: trackId ?? this.trackId,
      trackNo: trackNo ?? this.trackNo,
      transferOrderId: transferOrderId ?? this.transferOrderId,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleNo: vehicleNo ?? this.vehicleNo,
      driverId: driverId ?? this.driverId,
      lng: lng ?? this.lng,
      lat: lat ?? this.lat,
      location: location ?? this.location,
      speed: speed ?? this.speed,
      direction: direction ?? this.direction,
      altitude: altitude ?? this.altitude,
      accuracy: accuracy ?? this.accuracy,
      gpsTime: gpsTime ?? this.gpsTime,
      sourceType: sourceType ?? this.sourceType,
      isOffline: isOffline ?? this.isOffline,
      synced: synced ?? this.synced,
      extraData: extraData ?? this.extraData,
      createTime: createTime ?? this.createTime,
    );
  }
}
