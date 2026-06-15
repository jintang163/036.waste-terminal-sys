import 'dart:async';

import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/local_record_task_db.dart';
import '../models/camera_model.dart';

class VideoPlayerService {
  static final VideoPlayerService _instance = VideoPlayerService._internal();
  factory VideoPlayerService() => _instance;

  final LocalRecordTaskDb _recordTaskDb = LocalRecordTaskDb();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  bool _isPlaying = false;
  bool _isRecording = false;
  String? _currentRtspUrl;
  String? _currentTaskId;
  String? _currentCameraCode;
  DateTime? _recordStartTime;

  bool get isPlaying => _isPlaying;
  bool get isRecording => _isRecording;

  VideoPlayerService._internal();

  Future<bool> connectStream(String rtspUrl) async {
    try {
      if (_isPlaying && _currentRtspUrl == rtspUrl) {
        _logger.w('已在播放相同流: $rtspUrl');
        return true;
      }

      if (_isPlaying) {
        await disconnectStream();
      }

      _currentRtspUrl = rtspUrl;
      _isPlaying = true;
      _logger.i('连接RTSP流成功: $rtspUrl');
      return true;
    } catch (e) {
      _logger.e('连接RTSP流失败: $e');
      _isPlaying = false;
      _currentRtspUrl = null;
      return false;
    }
  }

  Future<void> disconnectStream() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }
      _isPlaying = false;
      _currentRtspUrl = null;
      _logger.i('断开RTSP流');
    } catch (e) {
      _logger.e('断开RTSP流失败: $e');
      _isPlaying = false;
      _currentRtspUrl = null;
    }
  }

  Future<String?> takeSnapshot() async {
    try {
      if (!_isPlaying) {
        _logger.w('未在播放，无法抓拍');
        return null;
      }

      final directory = await getTemporaryDirectory();
      final fileName = 'snapshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory.path}/$fileName';

      _logger.i('抓拍成功: $filePath');
      return filePath;
    } catch (e) {
      _logger.e('抓拍失败: $e');
      return null;
    }
  }

  Future<String?> startRecording(String cameraCode, String triggerType) async {
    try {
      if (_isRecording) {
        _logger.w('已在录制中');
        return _currentTaskId;
      }

      if (!_isPlaying) {
        _logger.w('未在播放，无法录制');
        return null;
      }

      _currentTaskId = _uuid.v4();
      _currentCameraCode = cameraCode;
      _recordStartTime = DateTime.now();
      _isRecording = true;

      await _recordTaskDb.insert({
        'task_id': _currentTaskId,
        'camera_code': cameraCode,
        'trigger_type': triggerType,
        'start_time': _recordStartTime!.toIso8601String(),
        'status': 0,
        'sync_status': 0,
        'is_deleted': 0,
        'create_time': DateTime.now().toIso8601String(),
        'update_time': DateTime.now().toIso8601String(),
      });

      _logger.i('开始录制: taskId=$_currentTaskId, cameraCode=$cameraCode, triggerType=$triggerType');
      return _currentTaskId;
    } catch (e) {
      _logger.e('开始录制失败: $e');
      _isRecording = false;
      _currentTaskId = null;
      _currentCameraCode = null;
      _recordStartTime = null;
      return null;
    }
  }

  Future<String?> stopRecording() async {
    try {
      if (!_isRecording || _currentTaskId == null) {
        _logger.w('未在录制中');
        return null;
      }

      final endTime = DateTime.now();
      final durationSeconds = _recordStartTime != null
          ? endTime.difference(_recordStartTime!).inSeconds
          : 0;

      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'record_${_currentTaskId}.mp4';
      final filePath = '${directory.path}/records/$fileName';

      await _recordTaskDb.updateRecordInfo(
        _currentTaskId!,
        filePath: filePath,
        durationSeconds: durationSeconds,
        endTime: endTime.toIso8601String(),
        status: 1,
      );

      _logger.i('停止录制: taskId=$_currentTaskId, duration=${durationSeconds}s, path=$filePath');

      _isRecording = false;
      final taskId = _currentTaskId;
      _currentTaskId = null;
      _currentCameraCode = null;
      _recordStartTime = null;

      return filePath;
    } catch (e) {
      _logger.e('停止录制失败: $e');
      _isRecording = false;
      _currentTaskId = null;
      _currentCameraCode = null;
      _recordStartTime = null;
      return null;
    }
  }
}
