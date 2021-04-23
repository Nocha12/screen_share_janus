package com.example.screen_share_janus

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.lang.ref.SoftReference
import kotlin.concurrent.thread

class ForegroundService : Service() {
    private val CHANNEL_ID = "Screen Share Notification"

    private val builder = NotificationCompat.Builder(this, CHANNEL_ID)

    private fun myAppContext(): Context{
        return myApplicationContextRef?.get() ?: throw Exception("ForegroundServicePlugin application context was null")
    }
    private val notificationManager: NotificationManager
        get(){
            return myAppContext().getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        }

    private var isFiledIcon = true


    companion object {
        private var myApplicationContextRef: SoftReference<Context>? = null
        private lateinit var changeIconThread: Thread
        private var stopBlinking = false

        fun startService(context: Context) {
            stopBlinking = false
            myApplicationContextRef = SoftReference(context)

            val startIntent = Intent(context, ForegroundService::class.java)
            ContextCompat.startForegroundService(context, startIntent)
        }
        fun stopService(context: Context) {
            stopBlinking = true

            val stopIntent = Intent(context, ForegroundService::class.java)
            context.stopService(stopIntent)
        }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createNotificationChannel()

        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
                this,
                0, notificationIntent, 0
        )

        builder.setContentTitle("On the Live")
                .setContentText("화면공유중")
                .setSmallIcon(R.drawable.ic_stat_cast_connected)
                .setContentIntent(pendingIntent).priority = NotificationCompat.PRIORITY_LOW


        startForeground(1, builder.build())

        makeIconBlinking()

        return START_STICKY
    }

    private fun makeIconBlinking() {
        changeIconThread = thread(start = true) {
            Handler(Looper.getMainLooper()).postDelayed({
                isFiledIcon = if(isFiledIcon) {
                    builder.setSmallIcon(R.drawable.black)
                    false
                } else {
                    builder.setSmallIcon(R.drawable.ic_stat_cast_connected)
                    true
                }

                notificationManager.notify(1, builder.build())

                if(stopBlinking)
                    notificationManager.cancel(1)
                else
                    makeIconBlinking()
            }, 1000)
        }
    }

    override fun onBind(intent: Intent): IBinder? {
        return null
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val serviceChannel = NotificationChannel(CHANNEL_ID, "화면 공유 알림",
                    NotificationManager.IMPORTANCE_LOW)
            val manager = getSystemService(NotificationManager::class.java)
            manager!!.createNotificationChannel(serviceChannel)
        }
    }
}