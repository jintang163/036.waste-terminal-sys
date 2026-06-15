import 'dart:async';
import 'dart:io';

import 'package:fijkplayer/fijkplayer.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../db/local_record_task_db.dart';
import '../models/local_record_task.dart';
import 'api_service.dart';

class VideoPlayerService {
  static final VideoPlayerService _instance = VideoPlayerService._internal();
  factory VideoPlayerService() => _instance;

  final LocalRecordTaskDb _recordTaskDb = LocalRecordTaskDb();
  final ApiService _apiService = ApiService();
  final Logger _logger = Logger();
  final Uuid _uuid = const Uuid();

  FijkPlayer? _player;
  FijkPlayer? _backgroundPlayer;

  bool _isPlaying = false;
  bool _isRecording = false;
  String? _currentRtspUrl;
  String? _currentCameraCode;
  String? _currentTaskId;
  DateTime? _recordStartTime;

  final List<_BufferFrame> _ringBuffer = [];
  final int _bufferMaxSeconds = 15;
  final int _frameRate = 15;
  Timer? _bufferTimer;

  bool _ringBufferEnabled = false;

  bool get isPlaying => _isPlaying;
  bool get isRecording => _isRecording;
  FijkPlayer? get player => _player;

  VideoPlayerService._internal();

  FijkPlayer getPlayer() {
    if (_player == null) {
      _player = FijkPlayer();
    }
    return _player!;
  }

  Future<bool> connectStream(String url, {String? cameraCode}) async {
    try {
      if (_isPlaying && _currentRtspUrl == url) {
        _logger.w('已在播放相同流: $url');
        return true;
      }

      if (_isPlaying) {
        await disconnectStream();
      }

      _player ??= FijkPlayer();

      await _player!.setDataSource(url, autoPlay: true);

      _currentRtspUrl = url;
      _currentCameraCode = cameraCode;
      _isPlaying = true;

      _logger.i('连接视频流成功: $url');
      return true;
    } catch (e) {
      _logger.e('连接视频流失败: $e');
      _isPlaying = false;
      _currentRtspUrl = null;
      _currentCameraCode = null;
      return false;
    }
  }

  Future<void> disconnectStream() async {
    try {
      if (_isRecording) {
        await stopRecording();
      }

      _stopRingBuffer();

      if (_player != null) {
        await _player!.stop();
        await _player!.release();
        _player = null;
      }

      _isPlaying = false;
      _currentRtspUrl = null;
      _currentCameraCode = null;
      _logger.i('断开视频流');
    } catch (e) {
      _logger.e('断开视频流失败: $e');
      _isPlaying = false;
      _currentRtspUrl = null;
      _currentCameraCode = null;
    }
  }

  Future<void> startPreviewOnly(String url, {String? cameraCode}) async {
    await connectStream(url, cameraCode: cameraCode);
  }

  Future<void> startRingBuffer(String url, {String? cameraCode}) async {
    try {
      if (_ringBufferEnabled) {
        _logger.w('环形缓冲已在运行');
        return;
      }

      _backgroundPlayer ??= FijkPlayer();
      await _backgroundPlayer!.setDataSource(url, autoPlay: true);

      _ringBufferEnabled = true;
      _currentCameraCode = cameraCode;

      _startBufferCapture();

      _logger.i('环形缓冲已启动，预录时长: ${_bufferMaxSeconds}秒');
    } catch (e) {
      _logger.e('启动环形缓冲失败: $e');
      _ringBufferEnabled = false;
    }
  }

  void _startBufferCapture() {
    _bufferTimer?.cancel();

    _bufferTimer = Timer.periodic(Duration(milliseconds: 1000 ~/ _frameRate), (timer) {
      _captureFrameToBuffer();
    });
  }

  Future<void> _captureFrameToBuffer() async {
    try {
      if (_backgroundPlayer == null || !_ringBufferEnabled) return;

      final tempDir = await getTemporaryDirectory();
      final bufferDir = Directory('${tempDir.path}/ring_buffer');
      if (!await bufferDir.exists()) {
        await bufferDir.create(recursive: true);
      }

      final frameTime = DateTime.now();
      final fileName = 'buf_${frameTime.millisecondsSinceEpoch}.jpg';
      final filePath = '${bufferDir.path}/$fileName';

      _ringBuffer.add(_BufferFrame(
        timestamp: frameTime,
        filePath: filePath,
        isKeyFrame: true,
      ));

      final maxFrames = _bufferMaxSeconds * _frameRate;
      while (_ringBuffer.length > maxFrames) {
        final oldFrame = _ringBuffer.removeAt(0);
        try {
          final oldFile = File(oldFrame.filePath);
          if (await oldFile.exists()) {
            await oldFile.delete();
          }
        } catch (_) {}
      }
    } catch (e) {
      _logger.d('采集帧到缓冲失败: $e');
    }
  }

  void _stopRingBuffer() {
    _bufferTimer?.cancel();
    _bufferTimer = null;
    _ringBufferEnabled = false;

    _clearRingBuffer();

    if (_backgroundPlayer != null) {
      _backgroundPlayer!.stop().then((_) => _backgroundPlayer!.release());
      _backgroundPlayer = null;
    }
  }

  Future<void> _clearRingBuffer() async {
    for (var frame in _ringBuffer) {
      try {
        final file = File(frame.filePath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}
    }
    _ringBuffer.clear();
  }

  Future<String?> startRecording(String cameraCode, String triggerType,
      {String? triggerId, int preSeconds = 10, int postSeconds = 10}) async {
    try {
      if (_isRecording) {
        _logger.w('已在录制中');
        return _currentTaskId;
      }

      if (!_isPlaying && !_ringBufferEnabled) {
        _logger.w('视频流未连接，启动录制失败');
        return null;
      }

      _currentTaskId = _uuid.v4();
      _currentCameraCode = cameraCode;
      _recordStartTime = DateTime.now();
      _isRecording = true;

      final directory = await getApplicationDocumentsDirectory();
      final recordsDir = Directory('${directory.path}/records');
      if (!await recordsDir.exists()) {
        await recordsDir.create(recursive: true);
      }

      final fileName = 'record_$_currentTaskId.mp4';
      final filePath = '${recordsDir.path}/$fileName';

      await _recordTaskDb.insert({
        'task_id': _currentTaskId,
        'camera_code': cameraCode,
        'camera_name': cameraCode,
        'trigger_type': triggerType,
        'trigger_id': triggerId,
        'pre_seconds': preSeconds.toString(),
        'post_seconds': postSeconds.toString(),
        'start_time': _recordStartTime!.toIso8601String(),
        'file_path': filePath,
        'status': 0,
        'sync_status': 0,
        'is_deleted': 0,
        'create_time': DateTime.now().toIso8601String(),
        'update_time': DateTime.now().toIso8601String(),
      });

      _logger.i('开始录制: taskId=$_currentTaskId, cameraCode=$cameraCode, triggerType=$triggerType, pre=$preSeconds s, post=$postSeconds s');

      _schedulePostRecord(postSeconds);

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

  void _schedulePostRecord(int postSeconds) {
    Timer(Duration(seconds: postSeconds), () {
      if (_isRecording) {
        stopRecording();
      }
    });
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
      final recordsDir = Directory('${directory.path}/records');
      if (!await recordsDir.exists()) {
        await recordsDir.create(recursive: true);
      }

      final fileName = 'record_$_currentTaskId.mp4';
      final filePath = '${recordsDir.path}/$fileName';

      File videoFile = File(filePath);
      if (!await videoFile.exists()) {
        await videoFile.create();
      }

      final fileSize = await videoFile.length();

      await _recordTaskDb.updateRecordInfo(
        _currentTaskId!,
        filePath: filePath,
        fileSize: fileSize,
        durationSeconds: durationSeconds,
        endTime: endTime.toIso8601String(),
        status: 1,
      );

      _logger.i('停止录制: taskId=$_currentTaskId, duration=${durationSeconds}s, size=$fileSize bytes, path=$filePath');

      final taskId = _currentTaskId;

      _isRecording = false;
      _currentTaskId = null;
      _currentCameraCode = null;
      _recordStartTime = null;

      _tryUploadRecord(taskId!);

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

  Future<void> _tryUploadRecord(String taskId) async {
    try {
      bool hasNetwork = await _apiService.isNetworkAvailable();
      if (!hasNetwork) {
        _logger.d('无网络，录像稍后自动同步: $taskId');
        return;
      }

      final task = await _recordTaskDb.queryByTaskId(taskId);
      if (task == null || task['file_path'] == null) {
        _logger.w('录像任务不存在或无文件: $taskId');
        return;
      }

      final filePath = task['file_path'];
      final file = File(filePath);
      if (!await file.exists()) {
        _logger.w('录像文件不存在: $filePath');
        return;
      }

      _logger.i('自动上传录像: $taskId');

      bool uploadSuccess = false;
      String? serverFilePath;

      try {
        final response = await _apiService.uploadFile(
          filePath,
          bizType: 'local_record',
          bizId: taskId,
        );

        if (response != null && response.data != null) {
          uploadSuccess = true;
          serverFilePath = response.data['data']?['filePath'] ?? response.data['data']?['url'];
        }
      } catch (e) {
        _logger.w('录像上传失败，等待同步任务重试: $e');
        return;
      }

      if (uploadSuccess) {
        try {
          await _apiService.post('/local-record/confirm-upload', data: {
            'taskId': taskId,
            'filePath': serverFilePath ?? filePath,
            'fileSize': task['file_size'] ?? 0,
            'durationSeconds': task['duration_seconds'] ?? 0,
            'startTime': task['start_time'],
            'endTime': task['end_time'],
          });

          await _recordTaskDb.updateSyncStatus(
            taskId,
            1,
            syncTime: DateTime.now().toIso8601String(),
          );

          _logger.i('录像上传并确认成功: $taskId');
        } catch (e) {
          _logger.w('确认录像上传失败: $e');
        }
      }
    } catch (e) {
      _logger.e('处理录像上传异常: $e');
    }
  }

  Future<String?> takeSnapshot() async {
    try {
      if (!_isPlaying || _player == null) {
        _logger.w('未在播放，无法抓拍');
        return null;
      }

      final directory = await getTemporaryDirectory();
      final fileName = 'snapshot_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${directory.path}/$fileName';

      _logger.i('抓拍: $filePath');

      return filePath;
    } catch (e) {
      _logger.e('抓拍失败: $e');
      return null;
    }
  }

  Future<bool> triggerEventRecord({
    required String cameraCode,
    required String triggerType,
    String? triggerId,
    int preSeconds = 10,
    int postSeconds = 10,
  }) async {
    try {
      if (_ringBufferEnabled || _isPlaying) {
        final taskId = await startRecording(
          cameraCode,
          triggerType,
          triggerId: triggerId,
          preSeconds: preSeconds,
          postSeconds: postSeconds,
        );
        return taskId != null;
      } else {
        _logger.w('视频流未连接，无法触发录制');
        return false;
      }
    } catch (e) {
      _logger.e('触发事件录制失败: $e');
      return false;
    }
  }

  int getRingBufferFrameCount() {
    return _ringBuffer.length;
  }

  Duration getRingBufferDuration() {
    if (_ringBuffer.isEmpty) return Duration.zero;
    return DateTime.now().difference(_ringBuffer.first.timestamp);
  }

  void dispose() {
    disconnectStream();
    _stopRingBuffer();
  }
}

class _BufferFrame {
  final DateTime timestamp;
  final String filePath;
  final bool isKeyFrame;

  _BufferFrame({
    required this.timestamp,
    required this.filePath,
    required this.isKeyFrame,
  });
}
