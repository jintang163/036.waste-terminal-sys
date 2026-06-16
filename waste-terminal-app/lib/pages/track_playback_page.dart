import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:amap_flutter_base/amap_flutter_base.dart';

import '../config/app_theme.dart';
import '../config/app_config.dart';
import '../models/transport_track.dart';
import '../models/transport_vehicle.dart';
import '../models/transport_driver.dart';
import '../services/api_service.dart';
import '../db/transport_track_db.dart';
import '../widgets/loading_widget.dart';
import '../widgets/common_button.dart';
import '../utils/date_util.dart';
import '../utils/num_util.dart';
import '../utils/toast_util.dart';

class TrackPlaybackPage extends StatefulWidget {
  final String trackId;
  final String? transferOrderNo;

  const TrackPlaybackPage({
    super.key,
    required this.trackId,
    this.transferOrderNo,
  });

  static void show(
    BuildContext context, {
    required String trackId,
    String? transferOrderNo,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TrackPlaybackPage(
          trackId: trackId,
          transferOrderNo: transferOrderNo,
        ),
      ),
    );
  }

  @override
  State<TrackPlaybackPage> createState() => _TrackPlaybackPageState();
}

class _TrackPlaybackPageState extends State<TrackPlaybackPage> {
  final Logger _logger = Logger();
  final ApiService _apiService = ApiService();

  TransportTrack? _track;
  TransportVehicle? _vehicle;
  TransportDriver? _driver;
  List<TrackPoint> _trackPoints = [];

  AMapController? _mapController;
  PolylineId? _fullPolylineId;
  PolylineId? _playedPolylineId;
  MarkerId? _startMarkerId;
  MarkerId? _endMarkerId;
  MarkerId? _currentMarkerId;
  final Map<PolylineId, Polyline> _polylines = {};
  final Map<MarkerId, Marker> _markers = {};

  bool _isLoading = true;
  bool _isPlaying = false;
  int _currentPointIndex = 0;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;
  bool _dataFromAmap = false;

  final List<double> _playbackSpeeds = [0.5, 1.0, 2.0, 5.0, 10.0];

  static const AMapApiKey _apiKey = AMapApiKey(
    androidKey: AppConfig.amapAndroidKey,
    iosKey: AppConfig.amapIosKey,
  );

  @override
  void initState() {
    super.initState();
    _loadTrackData();
  }

  @override
  void dispose() {
    _stopPlayback();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _loadTrackData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadTrackInfo(),
        _loadTrackPoints(),
      ]);
      if (_trackPoints.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _setupMapElements());
      }
    } catch (e) {
      _logger.e('加载轨迹数据失败: $e');
      ToastUtil.showError('加载轨迹数据失败');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadTrackInfo() async {
    try {
      final trackResponse = await _apiService.getTransportTrackDetail(widget.trackId);
      if (trackResponse != null) {
        _track = trackResponse;
        if (_track?.vehicleId != null) {
          try {
            final vehicleResponse = await _apiService.getTransportVehicleDetail(
              int.tryParse(_track!.vehicleId!) ?? 0,
            );
            _vehicle = vehicleResponse;
          } catch (e) {
            _logger.w('加载车辆信息失败: $e');
          }
        }
        if (_track?.driverId != null) {
          try {
            final driverResponse = await _apiService.getTransportDriverDetail(
              int.tryParse(_track!.driverId!) ?? 0,
            );
            _driver = driverResponse;
          } catch (e) {
            _logger.w('加载驾驶员信息失败: $e');
          }
        }
      }
    } catch (e) {
      _logger.w('从API加载轨迹信息失败，尝试从本地加载: $e');
      final localTrack = await _loadLocalTrack();
      if (localTrack != null) {
        _track = localTrack;
      } else {
        rethrow;
      }
    }
  }

  Future<TransportTrack?> _loadLocalTrack() async {
    try {
      final trackDb = TransportTrackDb();
      final trackData = await trackDb.queryById(widget.trackId);
      if (trackData != null) {
        return TransportTrack.fromDbMap(trackData);
      }
    } catch (e) {
      _logger.w('从本地加载轨迹信息失败: $e');
    }
    return null;
  }

  Future<void> _loadTrackPoints() async {
    try {
      final response = await _apiService.replayTrack(widget.trackId);
      final dynamic data = response.data['data'];
      if (data is List && data.isNotEmpty) {
        _trackPoints = data.map((e) => TrackPoint.fromJson(Map<String, dynamic>.from(e))).toList();
        _dataFromAmap = _trackPoints.any((p) => p.sourceType == 'AMAP');
        _logger.i('轨迹回放加载点数: ${_trackPoints.length}, 数据源: ${_dataFromAmap ? "高德猎鹰" : "本地数据库"}');
        return;
      }
      _logger.w('服务端回放接口无数据，尝试普通轨迹点接口');
    } catch (e) {
      _logger.w('从回放接口加载轨迹点失败: $e');
    }

    try {
      final response = await _apiService.getTrackPoints(widget.trackId);
      final dynamic data = response.data['data'];
      if (data is List) {
        _trackPoints = data.map((e) => TrackPoint.fromJson(Map<String, dynamic>.from(e))).toList();
      }
    } catch (e) {
      _logger.w('从API加载轨迹点失败，尝试从本地加载: $e');
      await _loadLocalTrackPoints();
    }
  }

  Future<void> _loadLocalTrackPoints() async {
    try {
      final trackDb = TransportTrackDb();
      final pointData = await trackDb.queryPointsByTrackId(widget.trackId);
      _trackPoints = pointData.map((e) => TrackPoint.fromDbMap(e)).toList();
    } catch (e) {
      _logger.w('从本地加载轨迹点失败: $e');
    }
  }

  void _onMapCreated(AMapController controller) {
    _mapController = controller;
    if (_trackPoints.isNotEmpty) {
      _setupMapElements();
    }
  }

  void _setupMapElements() {
    if (_mapController == null || _trackPoints.isEmpty) return;

    _clearMapElements();

    final allPoints = _trackPoints
        .where((p) => p.lng != null && p.lat != null)
        .map((p) => LatLng(p.lat!, p.lng!))
        .toList();

    if (allPoints.length < 2) {
      _moveCameraToPoint(allPoints.isNotEmpty ? allPoints.first : const LatLng(39.90923, 116.397428));
      return;
    }

    final fullPolyline = Polyline(
      points: allPoints,
      color: AppTheme.primaryColor.withOpacity(0.5),
      width: 6,
      joinType: JoinType.round,
      capType: CapType.round,
    );
    _fullPolylineId = fullPolyline.id;
    _polylines[_fullPolylineId!] = fullPolyline;

    final playedPoints = allPoints.sublist(0, (_currentPointIndex + 1).clamp(1, allPoints.length));
    final playedPolyline = Polyline(
      points: playedPoints,
      color: AppTheme.successColor,
      width: 7,
      joinType: JoinType.round,
      capType: CapType.round,
      zIndex: 1,
    );
    _playedPolylineId = playedPolyline.id;
    _polylines[_playedPolylineId!] = playedPolyline;

    final startMarker = Marker(
      position: allPoints.first,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      infoWindow: InfoWindow(title: '起点', snippet: _trackPoints.first.gpsTime != null
          ? DateUtil.formatDateTime(_trackPoints.first.gpsTime!)
          : null),
      anchor: const Offset(0.5, 1.0),
    );
    _startMarkerId = startMarker.id;
    _markers[_startMarkerId!] = startMarker;

    final endMarker = Marker(
      position: allPoints.last,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      infoWindow: InfoWindow(title: '终点', snippet: _trackPoints.last.gpsTime != null
          ? DateUtil.formatDateTime(_trackPoints.last.gpsTime!)
          : null),
      anchor: const Offset(0.5, 1.0),
    );
    _endMarkerId = endMarker.id;
    _markers[_endMarkerId!] = endMarker;

    final currentIndex = _currentPointIndex.clamp(0, allPoints.length - 1);
    final currentMarker = Marker(
      position: allPoints[currentIndex],
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(
        title: '当前位置',
        snippet: _buildCurrentSnippet(currentIndex),
      ),
      anchor: const Offset(0.5, 1.0),
      zIndex: 2,
    );
    _currentMarkerId = currentMarker.id;
    _markers[_currentMarkerId!] = currentMarker;

    _mapController?.addPolylines(_polylines.values.toSet());
    _mapController?.addMarkers(_markers.values.toSet());

    _moveCameraToIncludeAllPoints(allPoints);
  }

  String _buildCurrentSnippet(int index) {
    final point = index < _trackPoints.length ? _trackPoints[index] : null;
    if (point == null) return '';
    final parts = <String>[];
    if (point.gpsTime != null) parts.add(DateUtil.formatDateTime(point.gpsTime!));
    if (point.speed != null) parts.add('${_formatSpeed(point.speed)}');
    return parts.join('  ');
  }

  void _clearMapElements() {
    if (_mapController == null) return;
    if (_fullPolylineId != null) _mapController!.removePolyline(_fullPolylineId!);
    if (_playedPolylineId != null) _mapController!.removePolyline(_playedPolylineId!);
    if (_startMarkerId != null) _mapController!.removeMarker(_startMarkerId!);
    if (_endMarkerId != null) _mapController!.removeMarker(_endMarkerId!);
    if (_currentMarkerId != null) _mapController!.removeMarker(_currentMarkerId!);
    _polylines.clear();
    _markers.clear();
  }

  void _moveCameraToIncludeAllPoints(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;
    for (final p in points) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }
    final latDelta = maxLat - minLat;
    final lngDelta = maxLng - minLng;
    final padding = 0.01;
    final target = LatLngBounds(
      southwest: LatLng(minLat - padding, minLng - padding),
      northeast: LatLng(maxLat + padding, maxLng + padding),
    );
    final cameraUpdate = CameraUpdate.newLatLngBounds(target, 80.0);
    _mapController!.moveCamera(cameraUpdate);
  }

  void _moveCameraToPoint(LatLng point) {
    _mapController?.moveCamera(CameraUpdate.newLatLngZoom(point, 15.0));
  }

  void _updatePlaybackPosition() {
    if (_mapController == null || _trackPoints.isEmpty) return;

    final validPoints = _trackPoints
        .where((p) => p.lng != null && p.lat != null)
        .toList();
    if (validPoints.length < 2) return;

    final maxIndex = validPoints.length - 1;
    final idx = _currentPointIndex.clamp(0, maxIndex);
    final playedCount = (idx + 1).clamp(1, validPoints.length);

    final playedPoints = validPoints
        .sublist(0, playedCount)
        .map((p) => LatLng(p.lat!, p.lng!))
        .toList();

    if (_playedPolylineId != null) {
      _mapController!.removePolyline(_playedPolylineId!);
    }
    final updatedPlayed = Polyline(
      id: _playedPolylineId ?? const PolylineId('played_temp'),
      points: playedPoints,
      color: AppTheme.successColor,
      width: 7,
      joinType: JoinType.round,
      capType: CapType.round,
      zIndex: 1,
    );
    _playedPolylineId = updatedPlayed.id;
    _polylines[_playedPolylineId!] = updatedPlayed;
    _mapController!.addPolyline(updatedPlayed);

    final currentPos = LatLng(validPoints[idx].lat!, validPoints[idx].lng!);
    if (_currentMarkerId != null) {
      _mapController!.removeMarker(_currentMarkerId!);
    }
    final updatedMarker = Marker(
      id: _currentMarkerId ?? const MarkerId('current_temp'),
      position: currentPos,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(
        title: '当前位置',
        snippet: _buildCurrentSnippet(_currentPointIndex),
      ),
      anchor: const Offset(0.5, 1.0),
      zIndex: 2,
    );
    _currentMarkerId = updatedMarker.id;
    _markers[_currentMarkerId!] = updatedMarker;
    _mapController!.addMarker(updatedMarker);

    _mapController!.moveCamera(CameraUpdate.newLatLng(currentPos));
  }

  void _startPlayback() {
    if (_trackPoints.isEmpty || _isPlaying) return;

    _isPlaying = true;
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: (1000 / _playbackSpeed).round()),
      (timer) {
        if (_currentPointIndex < _trackPoints.length - 1) {
          setState(() {
            _currentPointIndex++;
          });
          _updatePlaybackPosition();
        } else {
          _stopPlayback();
          ToastUtil.showInfo('轨迹回放完成');
        }
      },
    );
    setState(() {});
  }

  void _pausePlayback() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    setState(() {});
  }

  void _stopPlayback() {
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _currentPointIndex = 0;
    _updatePlaybackPosition();
    setState(() {});
  }

  void _togglePlayback() {
    if (_isPlaying) {
      _pausePlayback();
    } else {
      _startPlayback();
    }
  }

  void _setPlaybackSpeed(double speed) {
    _playbackSpeed = speed;
    if (_isPlaying) {
      _pausePlayback();
      _startPlayback();
    }
    setState(() {});
  }

  void _onSliderChanged(double value) {
    final newIndex = (value * (_trackPoints.length - 1)).round();
    setState(() {
      _currentPointIndex = newIndex;
    });
    _updatePlaybackPosition();
  }

  String _formatDuration(int? seconds) {
    if (seconds == null || seconds <= 0) return '--:--:--';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  String _formatDistance(double? distance) {
    if (distance == null || distance <= 0) return '0 km';
    if (distance < 1000) {
      return '${distance.toStringAsFixed(0)} m';
    }
    return '${(distance / 1000).toStringAsFixed(2)} km';
  }

  String _formatSpeed(double? speed) {
    if (speed == null || speed <= 0) return '0 km/h';
    return '${(speed * 3.6).toStringAsFixed(1)} km/h';
  }

  double _calculateAverageSpeed() {
    if (_track?.totalDistance == null ||
        _track?.totalDuration == null ||
        _track!.totalDuration! <= 0) {
      return 0.0;
    }
    return (_track!.totalDistance! / 1000) / (_track!.totalDuration! / 3600);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('轨迹回放'),
        actions: [
          if (_track != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () {
                _stopPlayback();
                _loadTrackData();
              },
              tooltip: '刷新',
            ),
        ],
      ),
      body: _isLoading
          ? const LoadingWidget()
          : _track == null
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.route_outlined,
            size: 64.sp,
            color: AppTheme.textHint,
          ),
          SizedBox(height: 16.h),
          Text(
            '暂无轨迹数据',
            style: AppTextStyle.bodySecondary,
          ),
          SizedBox(height: 16.h),
          CommonButton(
            text: '重试',
            type: ButtonType.primary,
            size: ButtonSize.small,
            onPressed: _loadTrackData,
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final currentPoint = _trackPoints.isNotEmpty && _currentPointIndex < _trackPoints.length
        ? _trackPoints[_currentPointIndex]
        : null;

    return Column(
      children: [
        _buildMapCard(),
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTrackInfoCard(),
                SizedBox(height: 16.h),
                _buildCurrentPointInfo(currentPoint),
                SizedBox(height: 16.h),
                _buildStatsCard(),
                SizedBox(height: 140.h),
              ],
            ),
          ),
        ),
        _buildPlaybackControls(),
      ],
    );
  }

  Widget _buildMapCard() {
    return SizedBox(
      height: 280.h,
      width: double.infinity,
      child: Stack(
        children: [
          AMapWidget(
            apiKey: _apiKey,
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(39.90923, 116.397428),
              zoom: 14,
            ),
            myLocationButtonEnabled: false,
            compassEnabled: true,
            scaleEnabled: true,
            zoomGesturesEnabled: true,
            scrollGesturesEnabled: true,
            tiltGesturesEnabled: false,
            rotateGesturesEnabled: false,
            polylines: Set<Polyline>.of(_polylines.values),
            markers: Set<Marker>.of(_markers.values),
          ),
          Positioned(
            top: 12.h,
            left: 12.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.55),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _dataFromAmap ? Icons.satellite : Icons.storage,
                    size: 12.sp,
                    color: Colors.white,
                  ),
                  SizedBox(width: 4.w),
                  Text(
                    _dataFromAmap ? '高德猎鹰' : '本地数据',
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_trackPoints.isNotEmpty)
            Positioned(
              bottom: 12.h,
              left: 12.w,
              right: 12.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(8.r),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 3,
                        thumbShape: RoundSliderThumbShape(enabledThumbRadius: 7),
                        overlayShape: RoundSliderOverlayShape(overlayRadius: 14),
                      ),
                      child: Slider(
                        value: _trackPoints.length > 1
                            ? _currentPointIndex / (_trackPoints.length - 1)
                            : 0.0,
                        onChanged: _onSliderChanged,
                        activeColor: AppTheme.primaryColor,
                        inactiveColor: AppTheme.borderColor,
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8.w),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _trackPoints.first.gpsTime != null
                                ? DateUtil.formatTime(_trackPoints.first.gpsTime!)
                                : '--:--:--',
                            style: AppTextStyle.caption,
                          ),
                          Text(
                            '${_currentPointIndex + 1} / ${_trackPoints.length}',
                            style: AppTextStyle.caption.copyWith(
                              color: AppTheme.primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _trackPoints.last.gpsTime != null
                                ? DateUtil.formatTime(_trackPoints.last.gpsTime!)
                                : '--:--:--',
                            style: AppTextStyle.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTrackInfoCard() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: AppSize.iconMedium,
                  color: AppTheme.primaryColor,
                ),
                SizedBox(width: 8.w),
                Text(
                  '轨迹信息',
                  style: AppTextStyle.subtitle,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _buildInfoRow('轨迹编号', _track?.trackNo ?? '-'),
            SizedBox(height: 8.h),
            if (widget.transferOrderNo != null) ...[
              _buildInfoRow('转移联单号', widget.transferOrderNo!),
              SizedBox(height: 8.h),
            ],
            _buildInfoRow(
              '车辆',
              _vehicle?.vehicleNo ?? _track?.vehicleNo ?? '-',
            ),
            SizedBox(height: 8.h),
            _buildInfoRow(
              '驾驶员',
              _driver?.driverName ?? _track?.driverName ?? '-',
            ),
            SizedBox(height: 8.h),
            _buildInfoRow(
              '开始时间',
              _track?.startTime != null
                  ? DateUtil.formatDateTime(_track!.startTime!)
                  : '-',
            ),
            SizedBox(height: 8.h),
            _buildInfoRow(
              '结束时间',
              _track?.endTime != null
                  ? DateUtil.formatDateTime(_track!.endTime!)
                  : '-',
            ),
            SizedBox(height: 8.h),
            _buildInfoRow(
              '轨迹点数',
              '${_track?.pointCount ?? _trackPoints.length} 个',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80.w,
          child: Text(
            label,
            style: AppTextStyle.bodySecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: AppTextStyle.body.copyWith(
              color: valueColor ?? AppTheme.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPointInfo(TrackPoint? point) {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: AppSize.iconMedium,
                  color: AppTheme.dangerColor,
                ),
                SizedBox(width: 8.w),
                Text(
                  '当前位置',
                  style: AppTextStyle.subtitle,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            if (point == null)
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  child: Text(
                    '暂无位置信息',
                    style: AppTextStyle.bodySecondary,
                  ),
                ),
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          '经度',
                          point.lng?.toStringAsFixed(6) ?? '-',
                          Icons.explore_outlined,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem(
                          '纬度',
                          point.lat?.toStringAsFixed(6) ?? '-',
                          Icons.explore_outlined,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Expanded(
                        child: _buildStatItem(
                          '速度',
                          _formatSpeed(point.speed),
                          Icons.speed_outlined,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem(
                          '方向',
                          point.direction != null
                              ? '${point.direction!.toStringAsFixed(0)}°'
                              : '-',
                          Icons.navigation_outlined,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: _buildStatItem(
                          '海拔',
                          point.altitude != null
                              ? '${point.altitude!.toStringAsFixed(1)} m'
                              : '-',
                          Icons.terrain_outlined,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  _buildInfoRow(
                    '定位时间',
                    point.gpsTime != null
                        ? DateUtil.formatDateTime(point.gpsTime!)
                        : '-',
                  ),
                  if (point.location != null && point.location!.isNotEmpty) ...[
                    SizedBox(height: 8.h),
                    _buildInfoRow('位置描述', point.location!),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: AppTheme.bgPrimary,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                size: 14.sp,
                color: AppTheme.primaryColor,
              ),
              SizedBox(width: 4.w),
              Text(
                label,
                style: AppTextStyle.caption,
              ),
            ],
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: AppTextStyle.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final avgSpeed = _calculateAverageSpeed();

    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.analytics_outlined,
                  size: AppSize.iconMedium,
                  color: AppTheme.accentColor,
                ),
                SizedBox(width: 8.w),
                Text(
                  '统计信息',
                  style: AppTextStyle.subtitle,
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildBigStatItem(
                    '总里程',
                    _formatDistance(_track?.totalDistance?.toDouble()),
                    Icons.route_outlined,
                    AppTheme.primaryColor,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildBigStatItem(
                    '总时长',
                    _formatDuration(_track?.totalDuration),
                    Icons.timer_outlined,
                    AppTheme.secondaryColor,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: _buildBigStatItem(
                    '平均速度',
                    avgSpeed > 0 ? '${avgSpeed.toStringAsFixed(1)} km/h' : '-',
                    Icons.speed_outlined,
                    AppTheme.accentColor,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBigStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(AppRadius.r8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 24.sp,
            color: color,
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: AppTextStyle.subtitle.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            style: AppTextStyle.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        boxShadow: [
          BoxShadow(
            color: AppTheme.shadowColor,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  onPressed: _trackPoints.isEmpty ? null : _stopPlayback,
                  icon: const Icon(Icons.stop),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.dangerColor,
                    foregroundColor: AppTheme.textInverse,
                  ),
                ),
                SizedBox(width: 16.w),
                IconButton.filled(
                  onPressed: _trackPoints.isEmpty ? null : _togglePlayback,
                  icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: AppTheme.textInverse,
                    fixedSize: Size(56.w, 56.h),
                  ),
                ),
                SizedBox(width: 16.w),
                _buildSpeedSelector(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeedSelector() {
    return PopupMenuButton<double>(
      onSelected: _setPlaybackSpeed,
      itemBuilder: (context) => _playbackSpeeds
          .map((speed) => PopupMenuItem<double>(
                value: speed,
                child: Row(
                  children: [
                    if (speed == _playbackSpeed)
                      Icon(
                        Icons.check,
                        size: 16.sp,
                        color: AppTheme.primaryColor,
                      ),
                    SizedBox(width: 8.w),
                    Text('${speed}x 速度'),
                  ],
                ),
              ))
          .toList(),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: AppTheme.bgPrimary,
          borderRadius: BorderRadius.circular(AppRadius.r8),
          border: Border.all(color: AppTheme.borderColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${_playbackSpeed}x',
              style: AppTextStyle.body,
            ),
            SizedBox(width: 4.w),
            Icon(
              Icons.arrow_drop_down,
              size: 16.sp,
            ),
          ],
        ),
      ),
    );
  }
}
