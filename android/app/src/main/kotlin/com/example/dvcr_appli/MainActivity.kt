package com.example.dvcr_appli

import com.example.live_activities.LiveActivityManagerHolder
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        val liveManager = DvcrLiveActivityManager(this)
        liveManager.ensureNotificationChannel()
        LiveActivityManagerHolder.instance = liveManager
        super.configureFlutterEngine(flutterEngine)
    }
}
