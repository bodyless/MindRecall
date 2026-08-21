package com.wishtech.mind_recall;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.wishtech.mind_recall/storage";
    private static final String PROCESS_TEXT_CHANNEL =
            "com.wishtech.mind_recall/process_text";
    private static final int STORAGE_REQUEST_CODE = 1001;

    @Nullable
    private String pendingProcessText;
    @Nullable
    private EventChannel.EventSink processTextSink;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("requestStorage".equals(call.method)) {
                        requestStoragePermissionIfNeeded();
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
        new EventChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                PROCESS_TEXT_CHANNEL)
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        processTextSink = events;
                        if (pendingProcessText != null) {
                            events.success(pendingProcessText);
                            pendingProcessText = null;
                        }
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        processTextSink = null;
                    }
                });
        offerProcessTextFrom(getIntent());
    }

    @Override
    protected void onNewIntent(@NonNull Intent intent) {
        super.onNewIntent(intent);
        setIntent(intent);
        offerProcessTextFrom(intent);
    }

    // 取出选区文本写入 pending；有监听则立刻下发。
    // PROCESS_TEXT 的 setResult/finish 只允许在 ProcessTextActivity，此处只收转发来的 extra。
    private void offerProcessTextFrom(@Nullable Intent intent) {
        if (intent == null) {
            return;
        }
        final CharSequence extra = intent.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT);
        if (extra == null) {
            return;
        }
        final String text = extra.toString().trim();
        if (text.isEmpty()) {
            return;
        }
        pendingProcessText = text;
        intent.removeExtra(Intent.EXTRA_PROCESS_TEXT);
        if (processTextSink != null) {
            processTextSink.success(text);
            pendingProcessText = null;
        }
    }

    private void requestStoragePermissionIfNeeded() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return;
        }

        String readPermission = Manifest.permission.READ_EXTERNAL_STORAGE;
        if (ContextCompat.checkSelfPermission(this, readPermission)
                == PackageManager.PERMISSION_GRANTED) {
            return;
        }

        ActivityCompat.requestPermissions(
                this,
                new String[]{
                        Manifest.permission.READ_EXTERNAL_STORAGE,
                        Manifest.permission.WRITE_EXTERNAL_STORAGE
                },
                STORAGE_REQUEST_CODE
        );
    }
}
