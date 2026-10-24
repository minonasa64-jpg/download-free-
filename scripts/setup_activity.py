import os

dir_path = "android/app/src/main/java/com/boykta/pro_downloader"
os.makedirs(dir_path, exist_ok=True)

java_code = """package com.boykta.pro_downloader;

import android.app.PictureInPictureParams;
import android.content.Context;
import android.media.MediaCodec;
import android.media.MediaExtractor;
import android.media.MediaFormat;
import android.media.MediaMuxer;
import android.os.Build;
import android.util.Log;
import android.util.Rational;
import androidx.annotation.NonNull;
import io.flutter.embedding.android.FlutterFragmentActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugins.GeneratedPluginRegistrant;

import com.yausername.youtubedl_android.YoutubeDL;
import com.yausername.youtubedl_android.YoutubeDLRequest;
import com.yausername.youtubedl_android.YoutubeDLResponse;
import com.yausername.youtubedl_android.mapper.VideoFormat;
import com.yausername.youtubedl_android.mapper.VideoInfo;
import com.yausername.ffmpeg.FFmpeg;
import com.yausername.aria2c.Aria2c;

import java.io.BufferedReader;
import java.io.File;
import java.io.InputStreamReader;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends FlutterFragmentActivity {
    private static final String PIP_CHANNEL = "com.boykta.app/pip";
    private static final String MUXER_CHANNEL = "com.boykta.app/media_muxer";
    private static final String TAG = "MainActivity";
    private final ExecutorService executor = Executors.newCachedThreadPool();
    private volatile boolean nativeEnginesReady = false;

    private synchronized void ensureNativeEnginesInit() {
        if (nativeEnginesReady) return;
        try {
            Context appCtx = getApplicationContext();
            YoutubeDL.getInstance().init(appCtx);
            FFmpeg.getInstance().init(appCtx);
            try {
                Aria2c.getInstance().init(appCtx);
            } catch (Exception ignored) {}
            nativeEnginesReady = true;
            Log.i(TAG, "YoutubeDL + FFmpeg + Aria2c Full Native Libraries initialized successfully!");
        } catch (Exception e) {
            Log.e(TAG, "Failed to init YoutubeDL/FFmpeg native engines: " + e.getMessage(), e);
        }
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine);
        } catch (Exception e) {
            Log.e(TAG, "Plugin registration error: " + e.getMessage());
        }

        // Pre-warm native YoutubeDL + FFmpeg + Aria2c in background on startup
        executor.execute(this::ensureNativeEnginesInit);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), PIP_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if ("enterPip".equals(call.method)) {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        try {
                            PictureInPictureParams params = new PictureInPictureParams.Builder()
                                .setAspectRatio(new Rational(16, 9))
                                .build();
                            enterPictureInPictureMode(params);
                            result.success(true);
                        } catch (Exception e) {
                            result.error("PIP_ERROR", e.getMessage(), null);
                        }
                    } else {
                        result.error("NOT_SUPPORTED", "PiP requires Android Oreo (API 26) or higher", null);
                    }
                } else {
                    result.notImplemented();
                }
            });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), MUXER_CHANNEL)
            .setMethodCallHandler((call, result) -> {
                if ("muxAudioVideo".equals(call.method)) {
                    final String videoPath = call.argument("videoPath");
                    final String audioPath = call.argument("audioPath");
                    final String outputPath = call.argument("outputPath");

                    if (videoPath == null || audioPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Paths cannot be null", null);
                        return;
                    }

                    executor.execute(() -> {
                        boolean success = muxNativeAudioVideo(videoPath, audioPath, outputPath);
                        runOnUiThread(() -> result.success(success));
                    });
                } else if ("runNativeFFmpeg".equals(call.method)) {
                    final List<String> args = call.argument("args");
                    if (args == null || args.isEmpty()) {
                        result.error("INVALID_ARGS", "FFmpeg args cannot be empty", null);
                        return;
                    }
                    executor.execute(() -> {
                        boolean ok = executeStandaloneFFmpeg(args);
                        runOnUiThread(() -> result.success(ok));
                    });
                } else if ("downloadLinkWithYtDlp".equals(call.method)) {
                    final String url = call.argument("url");
                    final String outputPath = call.argument("outputPath");
                    final Number maxHeightNum = call.argument("maxHeight");
                    final Boolean isAudioObj = call.argument("isAudio");

                    if (url == null || outputPath == null) {
                        result.error("INVALID_ARGS", "url and outputPath are required", null);
                        return;
                    }

                    final int maxHeight = maxHeightNum != null ? maxHeightNum.intValue() : 1080;
                    final boolean isAudio = isAudioObj != null && isAudioObj;

                    executor.execute(() -> {
                        boolean ok = downloadWithNativeYtDlp(url, outputPath, maxHeight, isAudio);
                        runOnUiThread(() -> result.success(ok));
                    });
                } else if ("extractLinkWithYtDlp".equals(call.method)) {
                    final String url = call.argument("url");
                    if (url == null || url.isEmpty()) {
                        result.error("INVALID_ARGS", "url is required", null);
                        return;
                    }
                    executor.execute(() -> {
                        Map<String, Object> info = extractWithNativeYtDlp(url);
                        runOnUiThread(() -> result.success(info));
                    });
                } else if ("trimAudio".equals(call.method)) {
                    final String inputPath = call.argument("inputPath");
                    final String outputPath = call.argument("outputPath");
                    final Number startMsNum = call.argument("startMs");
                    final Number endMsNum = call.argument("endMs");

                    if (inputPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Paths cannot be null", null);
                        return;
                    }

                    final long startMs = startMsNum != null ? startMsNum.longValue() : 0L;
                    final long endMs = endMsNum != null ? endMsNum.longValue() : Long.MAX_VALUE;

                    executor.execute(() -> {
                        boolean success = trimNativeAudio(inputPath, outputPath, startMs, endMs);
                        runOnUiThread(() -> result.success(success));
                    });
                } else if ("extractAudio".equals(call.method)) {
                    final String videoPath = call.argument("videoPath");
                    final String outputPath = call.argument("outputPath");

                    if (videoPath == null || outputPath == null) {
                        result.error("INVALID_ARGS", "Paths cannot be null", null);
                        return;
                    }

                    executor.execute(() -> {
                        boolean success = extractNativeAudio(videoPath, outputPath);
                        runOnUiThread(() -> result.success(success));
                    });
                } else {
                    result.notImplemented();
                }
            });
    }

    private boolean executeStandaloneFFmpeg(List<String> args) {
        try {
            ensureNativeEnginesInit();
            Context appCtx = getApplicationContext();
            File binDir = new File(appCtx.getApplicationInfo().nativeLibraryDir);
            File ffmpegBin = new File(binDir, "libffmpeg.so");
            if (!ffmpegBin.exists()) {
                Log.e(TAG, "libffmpeg.so not found in " + binDir.getAbsolutePath());
                return false;
            }

            File baseDir = new File(appCtx.getNoBackupFilesDir(), "youtubedl-android");
            File packagesDir = new File(baseDir, "packages");
            String ldPath = new File(packagesDir, "ffmpeg/usr/lib").getAbsolutePath() + ":" +
                            new File(packagesDir, "python/usr/lib").getAbsolutePath() + ":" +
                            binDir.getAbsolutePath();

            List<String> command = new ArrayList<>();
            command.add(ffmpegBin.getAbsolutePath());
            command.addAll(args);

            ProcessBuilder pb = new ProcessBuilder(command);
            Map<String, String> env = pb.environment();
            env.put("LD_LIBRARY_PATH", ldPath);
            env.put("PATH", System.getenv("PATH") + ":" + binDir.getAbsolutePath());
            env.put("TMPDIR", appCtx.getCacheDir().getAbsolutePath());
            pb.redirectErrorStream(true);

            Process process = pb.start();
            BufferedReader reader = new BufferedReader(new InputStreamReader(process.getInputStream()));
            StringBuilder logBuilder = new StringBuilder();
            String line;
            while ((line = reader.readLine()) != null) {
                logBuilder.append(line).append("\\n");
            }
            int exitCode = process.waitFor();
            if (exitCode != 0) {
                Log.e(TAG, "Standalone libffmpeg.so exited with " + exitCode + ": " + logBuilder);
            }
            return exitCode == 0;
        } catch (Exception e) {
            Log.e(TAG, "executeStandaloneFFmpeg error: " + e.getMessage(), e);
            return false;
        }
    }

    private boolean downloadWithNativeYtDlp(String url, String outputPath, int maxHeight, boolean isAudio) {
        try {
            ensureNativeEnginesInit();
            File outFile = new File(outputPath);
            if (outFile.exists()) {
                outFile.delete();
            }
            YoutubeDLRequest request = new YoutubeDLRequest(url);
            request.addOption("--no-playlist");
            request.addOption("--no-mtime");
            request.addOption("--geo-bypass");
            request.addOption("--concurrent-fragments", 8);

            if (isAudio) {
                request.addOption("-x");
                request.addOption("--audio-format", "mp3");
                request.addOption("--audio-quality", "0");
            } else {
                int effHeight = maxHeight >= 720 ? maxHeight : 1080;
                String formatSelector = "bestvideo[height<=" + effHeight + "][ext=mp4]+bestaudio[ext=m4a]/" +
                                        "bestvideo[height<=" + effHeight + "]+bestaudio/" +
                                        "best[height<=" + effHeight + "][ext=mp4]/" +
                                        "bestvideo+bestaudio/best[ext=mp4]/best";
                request.addOption("-f", formatSelector);
                request.addOption("--merge-output-format", "mp4");
            }
            request.addOption("-o", outputPath);

            YoutubeDLResponse response = YoutubeDL.getInstance().execute(request);
            Log.i(TAG, "YoutubeDL download exitCode=" + response.getExitCode());
            return outFile.exists() && outFile.length() > 1024;
        } catch (Exception e) {
            Log.e(TAG, "downloadWithNativeYtDlp error: " + e.getMessage(), e);
            return false;
        }
    }

    private Map<String, Object> extractWithNativeYtDlp(String url) {
        try {
            ensureNativeEnginesInit();
            YoutubeDLRequest request = new YoutubeDLRequest(url);
            request.addOption("--no-playlist");
            request.addOption("--geo-bypass");
            VideoInfo info = YoutubeDL.getInstance().getInfo(request);
            if (info == null) return null;

            Map<String, Object> map = new HashMap<>();
            map.put("id", info.getId() != null ? info.getId() : "");
            map.put("title", info.getTitle() != null ? info.getTitle() : (info.getFulltitle() != null ? info.getFulltitle() : ""));
            map.put("thumbnail", info.getThumbnail() != null ? info.getThumbnail() : "");
            map.put("uploader", info.getUploader() != null ? info.getUploader() : "");
            map.put("duration", info.getDuration());
            map.put("url", info.getUrl() != null ? info.getUrl() : "");
            map.put("ext", info.getExt() != null ? info.getExt() : "mp4");
            map.put("width", info.getWidth());
            map.put("height", info.getHeight());

            List<Map<String, Object>> formatsList = new ArrayList<>();
            if (info.getFormats() != null) {
                for (VideoFormat vf : info.getFormats()) {
                    if (vf.getUrl() == null || vf.getUrl().isEmpty()) continue;
                    Map<String, Object> fm = new HashMap<>();
                    fm.put("formatId", vf.getFormatId() != null ? vf.getFormatId() : "");
                    fm.put("ext", vf.getExt() != null ? vf.getExt() : "mp4");
                    fm.put("vcodec", vf.getVcodec() != null ? vf.getVcodec() : "none");
                    fm.put("acodec", vf.getAcodec() != null ? vf.getAcodec() : "none");
                    fm.put("width", vf.getWidth());
                    fm.put("height", vf.getHeight());
                    fm.put("tbr", vf.getTbr());
                    fm.put("abr", vf.getAbr());
                    fm.put("fileSize", vf.getFileSize() > 0 ? vf.getFileSize() : vf.getFileSizeApproximate());
                    fm.put("url", vf.getUrl());
                    formatsList.add(fm);
                }
            }
            map.put("formats", formatsList);
            return map;
        } catch (Exception e) {
            Log.e(TAG, "extractWithNativeYtDlp error: " + e.getMessage(), e);
            return null;
        }
    }

    private boolean muxNativeAudioVideo(String videoPath, String audioPath, String outputPath) {
        MediaExtractor videoExtractor = new MediaExtractor();
        MediaExtractor audioExtractor = new MediaExtractor();
        MediaMuxer muxer = null;

        try {
            File vFile = new File(videoPath);
            File aFile = new File(audioPath);
            if (!vFile.exists() || !aFile.exists()) {
                Log.e(TAG, "Source files do not exist: v=" + vFile.exists() + ", a=" + aFile.exists());
                return false;
            }

            videoExtractor.setDataSource(videoPath);
            audioExtractor.setDataSource(audioPath);

            int videoSourceTrack = -1;
            for (int i = 0; i < videoExtractor.getTrackCount(); i++) {
                MediaFormat format = videoExtractor.getTrackFormat(i);
                String mime = format.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("video/")) {
                    videoSourceTrack = i;
                    break;
                }
            }

            int audioSourceTrack = -1;
            for (int i = 0; i < audioExtractor.getTrackCount(); i++) {
                MediaFormat format = audioExtractor.getTrackFormat(i);
                String mime = format.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    audioSourceTrack = i;
                    break;
                }
            }

            if (videoSourceTrack == -1 || audioSourceTrack == -1) {
                Log.e(TAG, "Tracks not found: videoTrack=" + videoSourceTrack + ", audioTrack=" + audioSourceTrack);
                return false;
            }

            File outFile = new File(outputPath);
            if (outFile.exists()) {
                outFile.delete();
            }

            videoExtractor.selectTrack(videoSourceTrack);
            MediaFormat videoFormat = videoExtractor.getTrackFormat(videoSourceTrack);
            String videoMime = videoFormat.getString(MediaFormat.KEY_MIME);

            int outputFormat = MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4;
            if (outputPath.toLowerCase().endsWith(".webm") || (videoMime != null && (videoMime.contains("vp8") || videoMime.contains("vp9")))) {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    outputFormat = MediaMuxer.OutputFormat.MUXER_OUTPUT_WEBM;
                }
            }

            muxer = new MediaMuxer(outputPath, outputFormat);
            int muxerVideoTrack = muxer.addTrack(videoFormat);

            audioExtractor.selectTrack(audioSourceTrack);
            MediaFormat audioFormat = audioExtractor.getTrackFormat(audioSourceTrack);
            int muxerAudioTrack = muxer.addTrack(audioFormat);

            muxer.start();

            int maxBufferSize = 1024 * 1024 * 4;
            if (videoFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                int s = videoFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE);
                if (s > maxBufferSize) maxBufferSize = s;
            }
            if (audioFormat.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                int s = audioFormat.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE);
                if (s > maxBufferSize) maxBufferSize = s;
            }

            ByteBuffer buffer = ByteBuffer.allocateDirect(maxBufferSize);
            MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();

            boolean videoDone = false;
            boolean audioDone = false;
            long lastVideoTime = -1;
            long lastAudioTime = -1;
            int videoSampleCount = 0;
            int audioSampleCount = 0;

            while (!videoDone || !audioDone) {
                long videoTime = videoDone ? Long.MAX_VALUE : videoExtractor.getSampleTime();
                long audioTime = audioDone ? Long.MAX_VALUE : audioExtractor.getSampleTime();

                if (!videoDone && (audioDone || videoTime <= audioTime)) {
                    bufferInfo.offset = 0;
                    bufferInfo.size = videoExtractor.readSampleData(buffer, 0);
                    if (bufferInfo.size < 0) {
                        videoDone = true;
                    } else {
                        long sampleTime = videoExtractor.getSampleTime();
                        if (sampleTime <= lastVideoTime) {
                            sampleTime = lastVideoTime + 1000;
                        }
                        lastVideoTime = sampleTime;

                        bufferInfo.presentationTimeUs = sampleTime;
                        bufferInfo.flags = videoExtractor.getSampleFlags();
                        muxer.writeSampleData(muxerVideoTrack, buffer, bufferInfo);
                        videoSampleCount++;
                        videoExtractor.advance();
                    }
                } else if (!audioDone) {
                    bufferInfo.offset = 0;
                    bufferInfo.size = audioExtractor.readSampleData(buffer, 0);
                    if (bufferInfo.size < 0) {
                        audioDone = true;
                    } else {
                        long sampleTime = audioExtractor.getSampleTime();
                        if (sampleTime <= lastAudioTime) {
                            sampleTime = lastAudioTime + 1000;
                        }
                        lastAudioTime = sampleTime;

                        bufferInfo.presentationTimeUs = sampleTime;
                        bufferInfo.flags = audioExtractor.getSampleFlags();
                        muxer.writeSampleData(muxerAudioTrack, buffer, bufferInfo);
                        audioSampleCount++;
                        audioExtractor.advance();
                    }
                }
            }

            if (videoSampleCount > 0) {
                try {
                    muxer.stop();
                } catch (Exception stopEx) {
                    Log.e(TAG, "muxer.stop() error: " + stopEx.getMessage());
                }
            }
            muxer.release();
            muxer = null;

            File finalFile = new File(outputPath);
            return finalFile.exists() && finalFile.length() > (vFile.length() * 0.7);
        } catch (Exception e) {
            Log.e(TAG, "Native MediaMuxer error: " + e.getMessage(), e);
            return false;
        } finally {
            try { videoExtractor.release(); } catch (Exception ignored) {}
            try { audioExtractor.release(); } catch (Exception ignored) {}
            if (muxer != null) {
                try { muxer.release(); } catch (Exception ignored) {}
            }
        }
    }

    private boolean trimNativeAudio(String inputPath, String outputPath, long startMs, long endMs) {
        MediaExtractor extractor = new MediaExtractor();
        MediaMuxer muxer = null;

        try {
            extractor.setDataSource(inputPath);
            int audioSourceTrack = -1;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat format = extractor.getTrackFormat(i);
                String mime = format.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    audioSourceTrack = i;
                    break;
                }
            }
            if (audioSourceTrack == -1) return false;

            extractor.selectTrack(audioSourceTrack);
            MediaFormat format = extractor.getTrackFormat(audioSourceTrack);

            File outFile = new File(outputPath);
            if (outFile.exists()) outFile.delete();

            muxer = new MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            int audioTrackIndex = muxer.addTrack(format);
            muxer.start();

            long startUs = startMs * 1000L;
            long endUs = endMs * 1000L;

            extractor.seekTo(startUs, MediaExtractor.SEEK_TO_PREVIOUS_SYNC);

            int maxBufferSize = 512 * 1024;
            if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                int s = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE);
                if (s > maxBufferSize) maxBufferSize = s;
            }

            ByteBuffer buffer = ByteBuffer.allocateDirect(maxBufferSize);
            MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();
            long firstSampleTimeUs = -1;

            while (true) {
                bufferInfo.offset = 0;
                bufferInfo.size = extractor.readSampleData(buffer, 0);
                if (bufferInfo.size < 0) break;

                long sampleTimeUs = extractor.getSampleTime();
                if (sampleTimeUs > endUs) break;

                if (sampleTimeUs >= startUs) {
                    if (firstSampleTimeUs == -1) {
                        firstSampleTimeUs = sampleTimeUs;
                    }
                    bufferInfo.presentationTimeUs = sampleTimeUs - firstSampleTimeUs;
                    bufferInfo.flags = extractor.getSampleFlags();
                    muxer.writeSampleData(audioTrackIndex, buffer, bufferInfo);
                }
                extractor.advance();
            }

            muxer.stop();
            muxer.release();
            muxer = null;

            File finalFile = new File(outputPath);
            return finalFile.exists() && finalFile.length() > 0;
        } catch (Exception e) {
            Log.e(TAG, "trimNativeAudio error: " + e.getMessage(), e);
            return false;
        } finally {
            try { extractor.release(); } catch (Exception ignored) {}
            if (muxer != null) {
                try { muxer.release(); } catch (Exception ignored) {}
            }
        }
    }

    private boolean extractNativeAudio(String videoPath, String outputPath) {
        MediaExtractor extractor = new MediaExtractor();
        MediaMuxer muxer = null;

        try {
            extractor.setDataSource(videoPath);
            int audioSourceTrack = -1;
            for (int i = 0; i < extractor.getTrackCount(); i++) {
                MediaFormat format = extractor.getTrackFormat(i);
                String mime = format.getString(MediaFormat.KEY_MIME);
                if (mime != null && mime.startsWith("audio/")) {
                    audioSourceTrack = i;
                    break;
                }
            }
            if (audioSourceTrack == -1) {
                Log.e(TAG, "No audio track found in video: " + videoPath);
                return false;
            }

            extractor.selectTrack(audioSourceTrack);
            MediaFormat format = extractor.getTrackFormat(audioSourceTrack);

            File outFile = new File(outputPath);
            if (outFile.exists()) outFile.delete();

            muxer = new MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);
            int audioTrackIndex = muxer.addTrack(format);
            muxer.start();

            int maxBufferSize = 1024 * 1024;
            if (format.containsKey(MediaFormat.KEY_MAX_INPUT_SIZE)) {
                int s = format.getInteger(MediaFormat.KEY_MAX_INPUT_SIZE);
                if (s > maxBufferSize) maxBufferSize = s;
            }

            ByteBuffer buffer = ByteBuffer.allocateDirect(maxBufferSize);
            MediaCodec.BufferInfo bufferInfo = new MediaCodec.BufferInfo();

            while (true) {
                bufferInfo.offset = 0;
                bufferInfo.size = extractor.readSampleData(buffer, 0);
                if (bufferInfo.size < 0) break;

                bufferInfo.presentationTimeUs = extractor.getSampleTime();
                bufferInfo.flags = extractor.getSampleFlags();
                muxer.writeSampleData(audioTrackIndex, buffer, bufferInfo);
                extractor.advance();
            }

            muxer.stop();
            muxer.release();
            muxer = null;

            File finalFile = new File(outputPath);
            return finalFile.exists() && finalFile.length() > 0;
        } catch (Exception e) {
            Log.e(TAG, "extractNativeAudio error: " + e.getMessage(), e);
            return false;
        } finally {
            try { extractor.release(); } catch (Exception ignored) {}
            if (muxer != null) {
                try { muxer.release(); } catch (Exception ignored) {}
            }
        }
    }
}
"""

with open(os.path.join(dir_path, "MainActivity.java"), "w") as f:
    f.write(java_code)

print("MainActivity.java successfully written!")
