import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:logger/logger.dart';

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

  bool _isLoading = true;
  bool _isPlaying = false;
  int _currentPointIndex = 0;
  double _playbackSpeed = 1.0;
  Timer? _playbackTimer;

  final List<double> _playbackSpeeds = [0.5, 1.0, 2.0, 5.0, 10.0];

  @override
  void initState() {
    super.initState();
    _loadTrackData();
  }

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  Future<void> _loadTrackData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadTrackInfo(),
        _loadTrackPoints(),
      ]);
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
      final response = await _apiService.getTrackPoints(widget.trackId);
      final List<dynamic> data = response.data['data'] ?? [];
      _trackPoints = data.map((e) => TrackPoint.fromJson(Map<String, dynamic>.from(e))).toList();
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
              onPressed: _loadTrackData,
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
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTrackInfoCard(),
                SizedBox(height: 16.h),
                _buildMapCard(),
                SizedBox(height: 16.h),
                _buildCurrentPointInfo(currentPoint),
                SizedBox(height: 16.h),
                _buildStatsCard(),
                SizedBox(height: 100.h),
              ],
            ),
          ),
        ),
        _buildPlaybackControls(),
      ],
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

  Widget _buildMapCard() {
    return Card(
      child: Padding(
        padding: AppPadding.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.map_outlined,
                  size: AppSize.iconMedium,
                  color: AppTheme.secondaryColor,
                ),
                SizedBox(width: 8.w),
                Text(
                  '轨迹线路',
                  style: AppTextStyle.subtitle,
                ),
                SizedBox(width: 8.w),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: _isPlaying
                        ? AppTheme.successColor.withOpacity(0.1)
                        : AppTheme.textHint.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                  child: Text(
                    _isPlaying ? '播放中' : '已暂停',
                    style: TextStyle(
                      fontSize: 10.sp,
                      color: _isPlaying ? AppTheme.successColor : AppTheme.textHint,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            _trackPoints.isEmpty
                ? _buildEmptyMap()
                : _buildTrackMap(),
            SizedBox(height: 8.h),
            _buildProgressBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMap() {
    return Container(
      height: 200.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.location_off_outlined,
            size: 48.sp,
            color: AppTheme.textHint,
          ),
          SizedBox(height: 8.h),
          Text(
            '暂无轨迹点数据',
            style: AppTextStyle.bodySecondary,
          ),
        ],
      ),
    );
  }

  Widget _buildTrackMap() {
    return Container(
      height: 200.h,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppTheme.bgSecondary,
        borderRadius: BorderRadius.circular(AppRadius.r8),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppRadius.r8),
        child: CustomPaint(
          size: Size(double.infinity, 200.h),
          painter: TrackMapPainter(
            points: _trackPoints,
            currentIndex: _currentPointIndex,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_trackPoints.isEmpty) return const SizedBox.shrink();

    final progress = _trackPoints.length > 1
        ? _currentPointIndex / (_trackPoints.length - 1)
        : 0.0;

    return Column(
      children: [
        Slider(
          value: progress,
          onChanged: (value) {
            final newIndex = (value * (_trackPoints.length - 1)).round();
            setState(() {
              _currentPointIndex = newIndex;
            });
          },
          activeColor: AppTheme.primaryColor,
          inactiveColor: AppTheme.borderColor,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _trackPoints.first.gpsTime != null
                  ? DateUtil.formatDateTime(_trackPoints.first.gpsTime!)
                  : '--:--:--',
              style: AppTextStyle.caption,
            ),
            Text(
              '${_currentPointIndex + 1} / ${_trackPoints.length}',
              style: AppTextStyle.caption,
            ),
            Text(
              _trackPoints.last.gpsTime != null
                  ? DateUtil.formatDateTime(_trackPoints.last.gpsTime!)
                  : '--:--:--',
              style: AppTextStyle.caption,
            ),
          ],
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
                    _formatDistance(_track?.totalDistance),
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

class TrackMapPainter extends CustomPainter {
  final List<TrackPoint> points;
  final int currentIndex;

  TrackMapPainter({
    required this.points,
    required this.currentIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final latitudes = points.map((p) => p.lat ?? 0.0).toList();
    final longitudes = points.map((p) => p.lng ?? 0.0).toList();

    final minLat = latitudes.reduce(min);
    final maxLat = latitudes.reduce(max);
    final minLng = longitudes.reduce(min);
    final maxLng = longitudes.reduce(max);

    final latRange = maxLat - minLat;
    final lngRange = maxLng - minLng;

    const padding = 20.0;
    final mapWidth = size.width - padding * 2;
    final mapHeight = size.height - padding * 2;

    double xMapper(double lng) {
      if (lngRange == 0) return mapWidth / 2 + padding;
      return ((lng - minLng) / lngRange) * mapWidth + padding;
    }

    double yMapper(double lat) {
      if (latRange == 0) return mapHeight / 2 + padding;
      return mapHeight - ((lat - minLat) / latRange) * mapHeight + padding;
    }

    final bgPaint = Paint()
      ..color = AppTheme.bgPrimary
      ..style = PaintingStyle.fill;

    final bgRect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(AppRadius.r8),
    );
    canvas.drawRRect(bgRect, bgPaint);

    final gridPaint = Paint()
      ..color = AppTheme.borderColor.withOpacity(0.5)
      ..strokeWidth = 1;

    const gridCount = 4;
    for (var i = 0; i <= gridCount; i++) {
      final x = padding + (mapWidth / gridCount) * i;
      final y = padding + (mapHeight / gridCount) * i;

      canvas.drawLine(
        Offset(x, padding),
        Offset(x, size.height - padding),
        gridPaint,
      );
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    final trackPaint = Paint()
      ..color = AppTheme.primaryColor.withOpacity(0.6)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final trackPath = Path();
    for (var i = 0; i < points.length; i++) {
      final x = xMapper(points[i].lng ?? 0.0);
      final y = yMapper(points[i].lat ?? 0.0);

      if (i == 0) {
        trackPath.moveTo(x, y);
      } else {
        trackPath.lineTo(x, y);
      }
    }
    canvas.drawPath(trackPath, trackPaint);

    final playedPaint = Paint()
      ..color = AppTheme.successColor
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final playedPath = Path();
    for (var i = 0; i <= currentIndex && i < points.length; i++) {
      final x = xMapper(points[i].lng ?? 0.0);
      final y = yMapper(points[i].lat ?? 0.0);

      if (i == 0) {
        playedPath.moveTo(x, y);
      } else {
        playedPath.lineTo(x, y);
      }
    }
    canvas.drawPath(playedPath, playedPaint);

    final startPaint = Paint()
      ..color = AppTheme.successColor
      ..style = PaintingStyle.fill;
    final startX = xMapper(points.first.lng ?? 0.0);
    final startY = yMapper(points.first.lat ?? 0.0);
    canvas.drawCircle(Offset(startX, startY), 8, startPaint);
    canvas.drawCircle(Offset(startX, startY), 4, Paint()..color = Colors.white);

    final endPaint = Paint()
      ..color = AppTheme.dangerColor
      ..style = PaintingStyle.fill;
    final endX = xMapper(points.last.lng ?? 0.0);
    final endY = yMapper(points.last.lat ?? 0.0);
    canvas.drawCircle(Offset(endX, endY), 8, endPaint);
    canvas.drawCircle(Offset(endX, endY), 4, Paint()..color = Colors.white);

    if (currentIndex >= 0 && currentIndex < points.length) {
      final currentPaint = Paint()
        ..color = AppTheme.primaryColor
        ..style = PaintingStyle.fill;
      final currentX = xMapper(points[currentIndex].lng ?? 0.0);
      final currentY = yMapper(points[currentIndex].lat ?? 0.0);

      final pulsePaint = Paint()
        ..color = AppTheme.primaryColor.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(currentX, currentY), 16, pulsePaint);
      canvas.drawCircle(Offset(currentX, currentY), 10, currentPaint);
      canvas.drawCircle(Offset(currentX, currentY), 5, Paint()..color = Colors.white);
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    textPainter.text = TextSpan(
      text: '起',
      style: TextStyle(
        color: AppTheme.successColor,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(startX + 10, startY - 20),
    );

    textPainter.text = TextSpan(
      text: '终',
      style: TextStyle(
        color: AppTheme.dangerColor,
        fontSize: 10.sp,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(endX + 10, endY - 20),
    );
  }

  @override
  bool shouldRepaint(covariant TrackMapPainter oldDelegate) {
    return currentIndex != oldDelegate.currentIndex ||
        points.length != oldDelegate.points.length;
  }
}
