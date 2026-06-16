import 'dart:async';

import 'package:logger/logger.dart';
import 'package:geolocator/geolocator.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';

import '../models/transport_track.dart';
import '../db/transport_track_db.dart';
import '../utils/logger_util.dart';
import 'api_service.dart';

enum TrackingStatus { idle, tracking, paused, stopped }

class GpsService {
  static final GpsService _instance = GpsService._internal();
  factory GpsService() => _instance;

  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();
  final ApiService _apiService = ApiService();
  final TransportTrackDb _trackDb = TransportTrackDb();
  final Connectivity _connectivity = Connectivity();

  StreamSubscription<Position>? _positionSubscription;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  TrackingStatus _trackingStatus = TrackingStatus.idle;
  TransportTrack? _currentTrack;
  TrackPoint? _lastPosition;
  String? _currentVehicleId;
  String? _currentDriverId;
  String? _currentTransferOrderId;

  final StreamController<TrackPoint> _positionController = StreamController<TrackPoint>.broadcast();
  final StreamController<TrackingStatus> _statusController = StreamController<TrackingStatus>.broadcast();
  final StreamController<int> _offlinePointCountController = StreamController<int>.broadcast();

  bool _isOnline = true;
  bool _autoSyncEnabled = true;
  int _offlinePointCount = 0;

  GpsService._internal();

  TrackingStatus get trackingStatus => _trackingStatus;
  TrackPoint? get lastPosition => _lastPosition;
  TransportTrack? get currentTrack => _currentTrack;
  bool get isOnline => _isOnline;
  int get offlinePointCount => _offlinePointCount;

  Stream<TrackPoint> get positionStream => _positionController.stream;
  Stream<TrackingStatus> get statusStream => _statusController.stream;
  Stream<int> get offlinePointCountStream => _offlinePointCountController.stream;

  Future<void> init() async {
    _initConnectivityListener();
    await _checkLocationPermission();
    _logger.i('GPS服务初始化完成');
  }

  void _initConnectivityListener() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      if (results.isNotEmpty) {
        final newResult = results.first;
        final wasOnline = _isOnline;
        _isOnline = newResult != ConnectivityResult.none;

        if (_isOnline && !wasOnline && _autoSyncEnabled) {
          _logger.d('网络已恢复，开始同步离线轨迹点');
          _syncOfflinePoints();
        }
      }
    });
  }

  Future<bool> _checkLocationPermission() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _logger.w('位置服务未开启');
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _logger.w('位置权限被拒绝');
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      _logger.w('位置权限被永久拒绝');
      return false;
    }

    return true;
  }

  Future<bool> startTracking({
    required String vehicleId,
    required String driverId,
    String? transferOrderId,
    String? vehicleNo,
    String? driverName,
    String? transferOrderNo,
  }) async {
    if (_trackingStatus == TrackingStatus.tracking) {
      _logger.w('已经在跟踪中，忽略重复请求');
      return false;
    }

    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        throw Exception('位置权限未授权');
      }

      _currentVehicleId = vehicleId;
      _currentDriverId = driverId;
      _currentTransferOrderId = transferOrderId;

      final trackId = _uuid.v4();
      final trackNo = 'TK${DateTime.now().millisecondsSinceEpoch}';

      final currentPosition = await getCurrentPosition();
      final now = DateTime.now();

      _currentTrack = TransportTrack(
        trackId: trackId,
        trackNo: trackNo,
        transferOrderId: transferOrderId,
        transferOrderNo: transferOrderNo,
        vehicleId: vehicleId,
        vehicleNo: vehicleNo,
        driverId: driverId,
        driverName: driverName,
        startTime: now,
        startLng: currentPosition?.lng,
        startLat: currentPosition?.lat,
        startLocation: currentPosition?.location,
        currentLng: currentPosition?.lng,
        currentLat: currentPosition?.lat,
        currentLocation: currentPosition?.location,
        lastGpsTime: now,
        status: 1,
        sourceType: 'app',
        syncStatus: 0,
        pointCount: 0,
        totalDistance: 0.0,
        totalDuration: 0,
        offlinePoints: 0,
        createTime: now,
        updateTime: now,
        isDeleted: 0,
      );

      await _trackDb.insert(_currentTrack!.toDbMap());

      _updateStatus(TrackingStatus.tracking);

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
          timeLimit: null,
        ),
      ).listen(_onLocationUpdate);

      _logger.i('开始GPS跟踪，轨迹ID: $trackId');
      return true;
    } catch (e) {
      _logger.e('开始GPS跟踪失败: $e');
      _updateStatus(TrackingStatus.stopped);
      rethrow;
    }
  }

  Future<void> stopTracking() async {
    if (_trackingStatus != TrackingStatus.tracking && _trackingStatus != TrackingStatus.paused) {
      _logger.w('未在跟踪中，无法停止');
      return;
    }

    try {
      await _positionSubscription?.cancel();
      _positionSubscription = null;

      if (_currentTrack != null) {
        final endPosition = _lastPosition;
        final now = DateTime.now();
        final duration = _currentTrack!.startTime != null
            ? now.difference(_currentTrack!.startTime!).inSeconds
            : 0;

        _currentTrack = _currentTrack!.copyWith(
          endTime: now,
          endLng: endPosition?.lng,
          endLat: endPosition?.lat,
          endLocation: endPosition?.location,
          lastGpsTime: endPosition?.gpsTime ?? now,
          totalDuration: duration,
          status: 2,
          updateTime: now,
        );

        await _trackDb.update(_currentTrack!.toDbMap());

        if (_isOnline) {
          try {
            await _apiService.endTransportTrack(
              _currentTrack!.trackId!,
              _currentTrack!.toJson(),
            );
            await _trackDb.update({
              'track_id': _currentTrack!.trackId,
              'sync_status': 1,
              'sync_time': DateTime.now().toIso8601String(),
            });
          } catch (e) {
            _logger.w('上报轨迹结束失败，将在同步时重试: $e');
          }
        }
      }

      if (_autoSyncEnabled && _isOnline) {
        await _syncOfflinePoints();
      }

      _currentTrack = null;
      _currentVehicleId = null;
      _currentDriverId = null;
      _currentTransferOrderId = null;
      _lastPosition = null;

      _updateStatus(TrackingStatus.stopped);
      _logger.i('停止GPS跟踪');
    } catch (e) {
      _logger.e('停止GPS跟踪失败: $e');
      rethrow;
    }
  }

  void pauseTracking() {
    if (_trackingStatus != TrackingStatus.tracking) {
      _logger.w('未在跟踪中，无法暂停');
      return;
    }

    _positionSubscription?.pause();
    _updateStatus(TrackingStatus.paused);
    _logger.i('暂停GPS跟踪');
  }

  void resumeTracking() {
    if (_trackingStatus != TrackingStatus.paused) {
      _logger.w('未在暂停状态，无法恢复');
      return;
    }

    _positionSubscription?.resume();
    _updateStatus(TrackingStatus.tracking);
    _logger.i('恢复GPS跟踪');
  }

  Future<TrackPoint?> getCurrentPosition() async {
    try {
      final hasPermission = await _checkLocationPermission();
      if (!hasPermission) {
        return _lastPosition;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final trackPoint = TrackPoint(
        pointId: _uuid.v4(),
        pointNo: 'TP${DateTime.now().millisecondsSinceEpoch}',
        trackId: _currentTrack?.trackId,
        trackNo: _currentTrack?.trackNo,
        transferOrderId: _currentTransferOrderId,
        vehicleId: _currentVehicleId,
        driverId: _currentDriverId,
        lng: position.longitude,
        lat: position.latitude,
        speed: position.speed,
        direction: position.heading,
        altitude: position.altitude,
        accuracy: position.accuracy,
        gpsTime: DateTime.fromMillisecondsSinceEpoch(position.timestamp.millisecondsSinceEpoch),
        sourceType: 'gps',
        isOffline: _isOnline ? 0 : 1,
        synced: 0,
        createTime: DateTime.now(),
      );

      _lastPosition = trackPoint;
      return trackPoint;
    } catch (e) {
      _logger.w('获取当前位置失败: $e');
      return _lastPosition;
    }
  }

  Future<void> _onLocationUpdate(Position position) async {
    if (_trackingStatus != TrackingStatus.tracking) return;

    try {
      final now = DateTime.now();
      final gpsTime = DateTime.fromMillisecondsSinceEpoch(position.timestamp.millisecondsSinceEpoch);

      final trackPoint = TrackPoint(
        pointId: _uuid.v4(),
        pointNo: 'TP${gpsTime.millisecondsSinceEpoch}',
        trackId: _currentTrack?.trackId,
        trackNo: _currentTrack?.trackNo,
        transferOrderId: _currentTransferOrderId,
        vehicleId: _currentVehicleId,
        vehicleNo: _currentTrack?.vehicleNo,
        driverId: _currentDriverId,
        lng: position.longitude,
        lat: position.latitude,
        speed: position.speed,
        direction: position.heading,
        altitude: position.altitude,
        accuracy: position.accuracy,
        gpsTime: gpsTime,
        sourceType: 'gps',
        isOffline: _isOnline ? 0 : 1,
        synced: 0,
        createTime: now,
      );

      _lastPosition = trackPoint;
      _positionController.add(trackPoint);

      await _trackDb.insertPoint(trackPoint.toDbMap());

      if (_currentTrack != null) {
        final newPointCount = (_currentTrack!.pointCount ?? 0) + 1;
        double newDistance = _currentTrack!.totalDistance ?? 0.0;

        if (_currentTrack!.currentLng != null && _currentTrack!.currentLat != null) {
          final distance = Geolocator.distanceBetween(
            _currentTrack!.currentLat!,
            _currentTrack!.currentLng!,
            position.latitude,
            position.longitude,
          );
          newDistance += distance;
        }

        final duration = _currentTrack!.startTime != null
            ? now.difference(_currentTrack!.startTime!).inSeconds
            : 0;

        _currentTrack = _currentTrack!.copyWith(
          currentLng: position.longitude,
          currentLat: position.latitude,
          lastGpsTime: gpsTime,
          pointCount: newPointCount,
          totalDistance: newDistance,
          totalDuration: duration,
          offlinePoints: _isOnline ? _currentTrack!.offlinePoints : (_currentTrack!.offlinePoints ?? 0) + 1,
          updateTime: now,
        );

        await _trackDb.update(_currentTrack!.toDbMap());
      }

      if (_isOnline) {
        _uploadTrackPoint(trackPoint);
      } else {
        _offlinePointCount++;
        _offlinePointCountController.add(_offlinePointCount);
      }
    } catch (e) {
      _logger.e('处理位置更新失败: $e');
    }
  }

  Future<void> _uploadTrackPoint(TrackPoint point) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，轨迹点将在本地缓存');
        return;
      }

      final response = await _apiService.uploadTrackPoint(point.toJson());

      if (response.data['code'] == 200) {
        await _trackDb.updatePointSyncStatus(point.pointId!, 1, syncTime: DateTime.now().toIso8601String());
        LoggerUtil.debug('轨迹点上报成功: ${point.pointId}');
      } else {
        _logger.w('轨迹点上报失败: ${response.data['msg']}');
      }
    } catch (e) {
      _logger.w('轨迹点上报异常，将在同步时重试: $e');
    }
  }

  Future<void> _syncOfflinePoints() async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，跳过离线轨迹点同步');
        return;
      }

      final unsyncedPoints = await _trackDb.queryUnsyncedPoints();
      if (unsyncedPoints.isEmpty) {
        _logger.d('无待同步的轨迹点');
        return;
      }

      _logger.d('待同步轨迹点数量: ${unsyncedPoints.length}');

      final batchSize = 50;
      for (var i = 0; i < unsyncedPoints.length; i += batchSize) {
        final end = (i + batchSize < unsyncedPoints.length) ? i + batchSize : unsyncedPoints.length;
        final batch = unsyncedPoints.sublist(i, end);

        try {
          final pointList = batch.map((e) => TrackPoint.fromDbMap(e).toJson()).toList();
          final response = await _apiService.uploadTrackPoints(pointList);

          if (response.data['code'] == 200) {
            final pointIds = batch
                .map((e) => e['point_id']?.toString() ?? '')
                .where((id) => id.isNotEmpty)
                .toList();

            for (var pointId in pointIds) {
              await _trackDb.updatePointSyncStatus(
                pointId,
                1,
                syncTime: DateTime.now().toIso8601String(),
              );
            }

            _offlinePointCount = unsyncedPoints.length - end;
            _offlinePointCountController.add(_offlinePointCount);

            _logger.d('批量上传轨迹点成功，数量: ${pointIds.length}');
          } else {
            _logger.w('批量上传轨迹点失败: ${response.data['msg']}');
          }
        } catch (e) {
          _logger.w('批量上传轨迹点异常: $e');
        }
      }

      _offlinePointCount = 0;
      _offlinePointCountController.add(0);
      _logger.i('离线轨迹点同步完成');
    } catch (e) {
      _logger.e('同步离线轨迹点失败: $e');
    }
  }

  void setAutoSyncEnabled(bool enabled) {
    _autoSyncEnabled = enabled;
    _logger.d('自动同步${enabled ? "已开启" : "已关闭"}');
  }

  void _updateStatus(TrackingStatus status) {
    _trackingStatus = status;
    _statusController.add(status);
  }

  void dispose() {
    _positionSubscription?.cancel();
    _connectivitySubscription?.cancel();
    _positionController.close();
    _statusController.close();
    _offlinePointCountController.close();
    _logger.i('GPS服务已释放');
  }
}
