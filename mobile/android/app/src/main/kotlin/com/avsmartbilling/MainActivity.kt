package com.avsmartbilling

import android.media.AudioManager
import android.media.ToneGenerator
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val soundChannel = "in.avsmartbilling.mobile/sound"
    private var toneGenerator: ToneGenerator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        try {
            toneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        } catch (e: Exception) {
            e.printStackTrace()
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, soundChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "beepSuccess" -> {
                    try {
                        toneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP, 130)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                "beepError" -> {
                    try {
                        toneGenerator?.startTone(ToneGenerator.TONE_PROP_NACK, 280)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        toneGenerator?.release()
        toneGenerator = null
        super.onDestroy()
    }
}

