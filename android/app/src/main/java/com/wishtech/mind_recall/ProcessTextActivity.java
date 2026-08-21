package com.wishtech.mind_recall;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;

// PROCESS_TEXT 入口：必须在调用方任务栈里立刻 finish，再用 NEW_TASK 打开本 App。
// 禁止把 Flutter MainActivity 直接注册为 PROCESS_TEXT（会黑屏卡住源 App）。
public class ProcessTextActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        final Intent source = getIntent();
        final CharSequence extra = source == null
                ? null
                : source.getCharSequenceExtra(Intent.EXTRA_PROCESS_TEXT);

        final Intent launch = new Intent(this, MainActivity.class);
        launch.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_ACTIVITY_CLEAR_TOP
                        | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        if (extra != null) {
            final String text = extra.toString();
            if (!text.trim().isEmpty()) {
                launch.putExtra(Intent.EXTRA_PROCESS_TEXT, text);
            }
        }
        try {
            startActivity(launch);
        } finally {
            setResult(RESULT_CANCELED);
            finish();
        }
    }
}
