package com.wishtech.mind_recall;

import android.Manifest;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.os.Environment;
import android.provider.Settings;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

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
    private static final int MANAGE_STORAGE_REQUEST_CODE = 1002;

    @Nullable
    private String pendingProcessText;
    @Nullable
    private EventChannel.EventSink processTextSink;
    @Nullable
    private MethodChannel.Result pendingStorageResult;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);
        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("requestStorage".equals(call.method)) {
                        requestStorageAccess(result);
                    } else if ("hasStorageAccess".equals(call.method)) {
                        result.success(hasBackupAccess());
                    } else if ("copyDirectoryTree".equals(call.method)) {
                        final String source = call.argument("source");
                        final String destination = call.argument("destination");
                        final String skipName = call.argument("skipName");
                        if (source == null || destination == null) {
                            result.error("bad_args", "source/destination required", null);
                            return;
                        }
                        try {
                            result.success(
                                    copyDirectoryTree(
                                            new File(source),
                                            new File(destination),
                                            skipName));
                        } catch (Exception e) {
                            result.error("copy_failed", e.getMessage(), null);
                        }
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

    @Override
    protected void onActivityResult(int requestCode, int resultCode, @Nullable Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == MANAGE_STORAGE_REQUEST_CODE) {
            if (!requestMediaImagesIfNeeded()) {
                completePendingStorageResult(hasBackupAccess());
            }
        }
    }

    @Override
    public void onRequestPermissionsResult(
            int requestCode,
            @NonNull String[] permissions,
            @NonNull int[] grantResults
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults);
        if (requestCode == STORAGE_REQUEST_CODE) {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                    && !Environment.isExternalStorageManager()) {
                openManageAllFilesSettings();
                return;
            }
            completePendingStorageResult(hasBackupAccess());
        }
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

    private boolean hasBackupAccess() {
        return hasStorageAccess() && hasMediaImagesAccess();
    }

    private boolean hasMediaImagesAccess() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true;
        }
        return ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_MEDIA_IMAGES)
                == PackageManager.PERMISSION_GRANTED;
    }

    private boolean hasStorageAccess() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return Environment.isExternalStorageManager();
        }
        return hasLegacyStoragePermission();
    }

    private boolean hasLegacyStoragePermission() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true;
        }
        return ContextCompat.checkSelfPermission(
                this, Manifest.permission.READ_EXTERNAL_STORAGE)
                == PackageManager.PERMISSION_GRANTED;
    }

    private void requestStorageAccess(@NonNull MethodChannel.Result result) {
        if (hasBackupAccess()) {
            result.success(true);
            return;
        }
        pendingStorageResult = result;
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R
                && !Environment.isExternalStorageManager()) {
            openManageAllFilesSettings();
            return;
        }
        if (requestMediaImagesIfNeeded()) {
            return;
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            completePendingStorageResult(true);
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

    /// 返回 true 表示已弹出系统对话框，调用方须等回调。
    private boolean requestMediaImagesIfNeeded() {
        if (hasMediaImagesAccess()) {
            return false;
        }
        ActivityCompat.requestPermissions(
                this,
                new String[]{Manifest.permission.READ_MEDIA_IMAGES},
                STORAGE_REQUEST_CODE
        );
        return true;
    }

    private void openManageAllFilesSettings() {
        try {
            final Intent intent = new Intent(
                    Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION);
            intent.setData(Uri.parse("package:" + getPackageName()));
            startActivityForResult(intent, MANAGE_STORAGE_REQUEST_CODE);
        } catch (Exception ignored) {
            try {
                startActivityForResult(
                        new Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
                        MANAGE_STORAGE_REQUEST_CODE);
            } catch (Exception fallback) {
                completePendingStorageResult(false);
            }
        }
    }

    private void completePendingStorageResult(boolean granted) {
        if (pendingStorageResult == null) {
            return;
        }
        pendingStorageResult.success(granted);
        pendingStorageResult = null;
    }

    /// 用 Java File API 递归复制，避免 dart:io Directory.list 漏掉媒体子目录。
    private int copyDirectoryTree(File src, File dest, @Nullable String skipName)
            throws IOException {
        if (!src.exists()) {
            //noinspection ResultOfMethodCallIgnored
            dest.mkdirs();
            return 0;
        }
        //noinspection ResultOfMethodCallIgnored
        dest.mkdirs();
        final File[] children = src.listFiles();
        if (children == null) {
            return 0;
        }
        int memos = 0;
        for (File child : children) {
            final String name = child.getName();
            if (".".equals(name) || "..".equals(name)) {
                continue;
            }
            if (skipName != null && skipName.equals(name)) {
                continue;
            }
            final File target = new File(dest, name);
            if (child.isDirectory()) {
                memos += copyDirectoryTree(child, target, skipName);
            } else if (child.isFile()) {
                copyFileBytes(child, target);
                final String lower = name.toLowerCase();
                if (lower.endsWith(".md") || lower.endsWith(".txt")) {
                    memos++;
                }
            }
        }
        return memos;
    }

    private void copyFileBytes(File src, File dest) throws IOException {
        final File parent = dest.getParentFile();
        if (parent != null) {
            //noinspection ResultOfMethodCallIgnored
            parent.mkdirs();
        }
        try (InputStream in = new FileInputStream(src);
             OutputStream out = new FileOutputStream(dest)) {
            final byte[] buf = new byte[64 * 1024];
            int n;
            while ((n = in.read(buf)) > 0) {
                out.write(buf, 0, n);
            }
        }
    }
}
