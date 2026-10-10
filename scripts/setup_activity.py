import os

dir_path = "android/app/src/main/java/com/boykta/pro_downloader"
os.makedirs(dir_path, exist_ok=True)

java_code = """package com.boykta.pro_downloader;

import android.app.PictureInPictureParams;
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

import java.io.File;
import java.nio.ByteBuffer;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

public class MainActivity extends FlutterFragmentActivity {
    private static final String PIP_CHANNEL = "com.boykta.app/pip";
    private static final String MUXER_CHANNEL = "com.boykta.app/media_muxer";
    private static final String TAG = "MainActivity";
    private final ExecutorService executor = Executors.newSingleThreadExecutor();

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        try {
            GeneratedPluginRegistrant.registerWith(flutterEngine);
        } catch (Exception e) {
            Log.e(TAG, "Plugin registration error: " + e.getMessage());
        }

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

            muxer = new MediaMuxer(outputPath, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4);

            videoExtractor.selectTrack(videoSourceTrack);
            MediaFormat videoFormat = videoExtractor.getTrackFormat(videoSourceTrack);
            int muxerVideoTrack = muxer.addTrack(videoFormat);

            audioExtractor.selectTrack(audioSourceTrack);
            MediaFormat audioFormat = audioExtractor.getTrackFormat(audioSourceTrack);
            int muxerAudioTrack = muxer.addTrack(audioFormat);

            muxer.start();

            int maxBufferSize = 1024 * 1024 * 2;
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
                        if (sampleTime < lastVideoTime) sampleTime = lastVideoTime;
                        lastVideoTime = sampleTime;

                        bufferInfo.presentationTimeUs = sampleTime;
                        bufferInfo.flags = videoExtractor.getSampleFlags();
                        muxer.writeSampleData(muxerVideoTrack, buffer, bufferInfo);
                        videoExtractor.advance();
                    }
                } else if (!audioDone) {
                    bufferInfo.offset = 0;
                    bufferInfo.size = audioExtractor.readSampleData(buffer, 0);
                    if (bufferInfo.size < 0) {
                        audioDone = true;
                    } else {
                        long sampleTime = audioExtractor.getSampleTime();
                        if (sampleTime < lastAudioTime) sampleTime = lastAudioTime;
                        lastAudioTime = sampleTime;

                        bufferInfo.presentationTimeUs = sampleTime;
                        bufferInfo.flags = audioExtractor.getSampleFlags();
                        muxer.writeSampleData(muxerAudioTrack, buffer, bufferInfo);
                        audioExtractor.advance();
                    }
                }
            }

            muxer.stop();
            muxer.release();
            muxer = null;

            File finalFile = new File(outputPath);
            return finalFile.exists() && finalFile.length() > 0;
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
