package com.waste.video;

import lombok.Data;
import lombok.extern.slf4j.Slf4j;
import org.bytedeco.ffmpeg.global.avcodec;
import org.bytedeco.ffmpeg.global.avutil;
import org.bytedeco.javacv.FFmpegFrameGrabber;
import org.bytedeco.javacv.FFmpegFrameRecorder;
import org.bytedeco.javacv.Frame;

import java.io.File;
import java.time.LocalDateTime;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

@Data
@Slf4j
public class RtspStreamSession {

    private String cameraCode;
    private String rtspUrl;
    private String hlsPath;
    private String snapshotPath;

    private FFmpegFrameGrabber grabber;
    private FFmpegFrameRecorder recorder;

    private AtomicBoolean running = new AtomicBoolean(false);
    private AtomicBoolean recording = new AtomicBoolean(false);

    private AtomicLong lastFrameTime = new AtomicLong(0);
    private AtomicLong lastAccessTime = new AtomicLong(0);

    private Thread grabThread;
    private Thread recordThread;

    private int width;
    private int height;
    private double frameRate;

    private LocalDateTime startTime;

    public RtspStreamSession(String cameraCode, String rtspUrl, String hlsPath, String snapshotPath) {
        this.cameraCode = cameraCode;
        this.rtspUrl = rtspUrl;
        this.hlsPath = hlsPath;
        this.snapshotPath = snapshotPath;
        this.lastAccessTime.set(System.currentTimeMillis());
    }

    public synchronized void start() throws Exception {
        if (running.get()) {
            log.info("[{}] 流已在运行中", cameraCode);
            return;
        }

        log.info("[{}] 开始连接RTSP流: {}", cameraCode, rtspUrl);

        try {
            grabber = new FFmpegFrameGrabber(rtspUrl);
            grabber.setOption("rtsp_transport", "tcp");
            grabber.setOption("stimeout", "5000000");
            grabber.setOption("analyzeduration", "2000000");
            grabber.setOption("probesize", "2000000");
            grabber.start();

            width = grabber.getImageWidth();
            height = grabber.getImageHeight();
            frameRate = grabber.getFrameRate();
            if (frameRate <= 0) {
                frameRate = 25;
            }

            log.info("[{}] RTSP流连接成功，分辨率: {}x{}, 帧率: {}", cameraCode, width, height, frameRate);

            File hlsDir = new File(hlsPath);
            if (!hlsDir.exists()) {
                hlsDir.mkdirs();
            }

            String hlsFile = new File(hlsPath, "stream.m3u8").getAbsolutePath();

            recorder = new FFmpegFrameRecorder(hlsFile, width, height);
            recorder.setFormat("hls");
            recorder.setFrameRate(frameRate);
            recorder.setGopSize((int) (frameRate * 2));
            recorder.setVideoCodec(avcodec.AV_CODEC_ID_H264);
            recorder.setVideoOption("preset", "ultrafast");
            recorder.setVideoOption("tune", "zerolatency");
            recorder.setVideoOption("hls_time", "2");
            recorder.setVideoOption("hls_list_size", "6");
            recorder.setVideoOption("hls_flags", "delete_segments+append_list");
            recorder.setVideoOption("hls_segment_filename",
                    new File(hlsPath, "segment_%03d.ts").getAbsolutePath());
            recorder.setPixelFormat(avutil.AV_PIX_FMT_YUV420P);
            recorder.setVideoBitrate(2000000);
            recorder.start();

            running.set(true);
            startTime = LocalDateTime.now();

            grabThread = new Thread(this::grabLoop, "rtsp-grab-" + cameraCode);
            grabThread.setDaemon(true);
            grabThread.start();

            log.info("[{}] HLS转流启动成功", cameraCode);
        } catch (Exception e) {
            log.error("[{}] RTSP流启动失败: {}", cameraCode, e.getMessage(), e);
            stop();
            throw e;
        }
    }

    private void grabLoop() {
        Frame frame = null;
        long frameCount = 0;

        while (running.get()) {
            try {
                frame = grabber.grab();
                if (frame == null) {
                    Thread.sleep(10);
                    continue;
                }

                lastFrameTime.set(System.currentTimeMillis());
                lastAccessTime.set(System.currentTimeMillis());

                if (frame.image != null && recorder != null) {
                    synchronized (recorder) {
                        try {
                            recorder.record(frame);
                        } catch (Exception e) {
                            log.warn("[{}] 录制帧失败: {}", cameraCode, e.getMessage());
                        }
                    }
                }

                frameCount++;

            } catch (InterruptedException e) {
                log.info("[{}] 抓取线程被中断", cameraCode);
                break;
            } catch (Exception e) {
                log.error("[{}] 抓取帧异常: {}", cameraCode, e.getMessage());
                try {
                    Thread.sleep(100);
                } catch (InterruptedException ie) {
                    break;
                }
            }
        }

        log.info("[{}] 抓取线程结束，总帧数: {}", cameraCode, frameCount);
    }

    public synchronized String takeSnapshot() throws Exception {
        if (!running.get() || grabber == null) {
            throw new IllegalStateException("RTSP流未连接");
        }

        File snapDir = new File(snapshotPath);
        if (!snapDir.exists()) {
            snapDir.mkdirs();
        }

        String fileName = "snap_" + cameraCode + "_" + System.currentTimeMillis() + ".jpg";
        String filePath = new File(snapshotPath, fileName).getAbsolutePath();

        Frame frame = grabber.grabImage();
        if (frame == null) {
            throw new RuntimeException("无法获取视频帧");
        }

        FFmpegFrameRecorder snapshotRecorder = new FFmpegFrameRecorder(filePath, width, height);
        snapshotRecorder.setFormat("image2");
        snapshotRecorder.setVideoCodec(avcodec.AV_CODEC_ID_MJPEG);
        snapshotRecorder.setFrameRate(frameRate);
        snapshotRecorder.start();
        snapshotRecorder.record(frame);
        snapshotRecorder.stop();
        snapshotRecorder.release();

        log.info("[{}] 抓拍成功: {}", cameraCode, filePath);
        return filePath;
    }

    public synchronized void stop() {
        if (!running.get() && grabber == null) {
            return;
        }

        log.info("[{}] 停止RTSP流", cameraCode);

        running.set(false);
        recording.set(false);

        if (grabThread != null) {
            grabThread.interrupt();
            try {
                grabThread.join(3000);
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
            }
            grabThread = null;
        }

        if (recorder != null) {
            try {
                synchronized (recorder) {
                    recorder.stop();
                    recorder.release();
                }
            } catch (Exception e) {
                log.error("[{}] 关闭录制器失败: {}", cameraCode, e.getMessage());
            }
            recorder = null;
        }

        if (grabber != null) {
            try {
                grabber.stop();
                grabber.release();
            } catch (Exception e) {
                log.error("[{}] 关闭抓取器失败: {}", cameraCode, e.getMessage());
            }
            grabber = null;
        }
    }

    public boolean isAlive() {
        if (!running.get()) {
            return false;
        }
        long idle = System.currentTimeMillis() - lastFrameTime.get();
        return idle < 10000;
    }

    public void updateAccessTime() {
        lastAccessTime.set(System.currentTimeMillis());
    }

    public boolean isIdle(int idleTimeoutMs) {
        return System.currentTimeMillis() - lastAccessTime.get() > idleTimeoutMs;
    }
}
