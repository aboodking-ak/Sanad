package com.purecompany.sanad;

import android.os.Bundle;
import android.view.WindowManager;
import io.flutter.embedding.android.FlutterActivity;

public class MainActivity extends FlutterActivity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // منع أخذ لقطات الشاشة أو تسجيل الشاشة
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
    }
}
