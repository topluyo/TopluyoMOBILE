package com.topluyo

import android.content.Context
import android.media.AudioManager
import android.os.Bundle
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var audioManager: AudioManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Set the default volume stream
        volumeControlStream = AudioManager.STREAM_MUSIC
        audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        // Manually intercept volume keys to ensure they always control STREAM_MUSIC
        // This is necessary because older Android versions (like 8.1) might override 
        // volumeControlStream when WebRTC sets MODE_IN_COMMUNICATION.
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_RAISE, AudioManager.FLAG_SHOW_UI)
                return true
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                audioManager.adjustStreamVolume(AudioManager.STREAM_MUSIC, AudioManager.ADJUST_LOWER, AudioManager.FLAG_SHOW_UI)
                return true
            }
        }
        return super.onKeyDown(keyCode, event)
    }
}
