package com.example.phone_power_monitor

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.BatteryManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import org.json.JSONException
import kotlin.math.roundToInt

class MainActivity : FlutterActivity() {
    private var batteryDetailsReceiver: BroadcastReceiver? = null
    private val batteryHandler = Handler(Looper.getMainLooper())
    private var batteryPollTask: Runnable? = null
    private var batteryEventSink: EventChannel.EventSink? = null
    private var latestBatteryIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BATTERY_DETAILS_CHANNEL
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                unregisterBatteryReceiver()
                batteryEventSink = events
                val receiver = object : BroadcastReceiver() {
                    override fun onReceive(context: Context, intent: Intent) {
                        latestBatteryIntent = intent
                        events.success(readBatteryDetails(intent))
                    }
                }
                batteryDetailsReceiver = receiver
                val stickyIntent = ContextCompat.registerReceiver(
                    applicationContext,
                    receiver,
                    IntentFilter(Intent.ACTION_BATTERY_CHANGED),
                    ContextCompat.RECEIVER_NOT_EXPORTED
                )
                latestBatteryIntent = stickyIntent
                events.success(readBatteryDetails(stickyIntent))
                startBatteryPolling()
            }

            override fun onCancel(arguments: Any?) {
                batteryEventSink = null
                unregisterBatteryReceiver()
            }
        })
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            BATTERY_HISTORY_CHANNEL
        ).setMethodCallHandler { call, result ->
            val preferences = getSharedPreferences(HISTORY_PREFERENCES, MODE_PRIVATE)
            when (call.method) {
                "loadHistory" -> result.success(
                    preferences.getString(HISTORY_KEY, "[]")
                )
                "loadPowerHistory" -> result.success(
                    preferences.getString(POWER_HISTORY_KEY, "[]")
                )
                "saveHistory" -> saveHistory(
                    call.arguments as? String,
                    preferences,
                    HISTORY_KEY,
                    result
                )
                "savePowerHistory" -> saveHistory(
                    call.arguments as? String,
                    preferences,
                    POWER_HISTORY_KEY,
                    result
                )
                else -> result.notImplemented()
            }
        }
    }

    override fun onResume() {
        super.onResume()
        if (batteryEventSink != null) startBatteryPolling()
    }

    override fun onPause() {
        stopBatteryPolling()
        super.onPause()
    }

    override fun onDestroy() {
        batteryEventSink = null
        unregisterBatteryReceiver()
        super.onDestroy()
    }

    private fun unregisterBatteryReceiver() {
        stopBatteryPolling()
        batteryDetailsReceiver?.let { receiver ->
            applicationContext.unregisterReceiver(receiver)
            batteryDetailsReceiver = null
        }
        latestBatteryIntent = null
    }

    private fun startBatteryPolling() {
        stopBatteryPolling()
        val task = object : Runnable {
            override fun run() {
                val sink = batteryEventSink ?: return
                sink.success(readBatteryDetails(latestBatteryIntent))
                batteryHandler.postDelayed(this, BATTERY_POLL_INTERVAL_MS)
            }
        }
        batteryPollTask = task
        batteryHandler.postDelayed(task, BATTERY_POLL_INTERVAL_MS)
    }

    private fun stopBatteryPolling() {
        batteryPollTask?.let(batteryHandler::removeCallbacks)
        batteryPollTask = null
    }

    private fun saveHistory(
        json: String?,
        preferences: android.content.SharedPreferences,
        key: String,
        result: MethodChannel.Result
    ) {
        if (json == null) {
            result.error(
                "invalid_history",
                "Battery history must be a JSON string.",
                null
            )
            return
        }
        try {
            JSONArray(json)
            if (preferences.edit().putString(key, json).commit()) {
                result.success(null)
            } else {
                result.error("save_failed", "Battery history could not be saved.", null)
            }
        } catch (error: JSONException) {
            result.error(
                "invalid_history",
                "Battery history must be a JSON array.",
                null
            )
        }
    }

    private fun readBatteryDetails(intent: Intent?): Map<String, Any?> {
        if (intent == null) {
            return mapOf(
                "level" to null,
                "temperatureCelsius" to null,
                "remainingChargeMah" to readRemainingChargeMah(),
                "voltageMillivolts" to null,
                "currentNowMicroamps" to readCurrentNowMicroamps(),
                "status" to null,
                "health" to null,
                "technology" to null,
                "plugged" to null,
                "powerSource" to null
            )
        }

        val rawLevel = intent.getIntExtra(BatteryManager.EXTRA_LEVEL, -1)
        val scale = intent.getIntExtra(BatteryManager.EXTRA_SCALE, -1)
        val level = if (rawLevel >= 0 && scale > 0) {
            (rawLevel * 100.0 / scale).roundToInt().coerceIn(0, 100)
        } else {
            null
        }
        val rawTemperature = intent.getIntExtra(
            BatteryManager.EXTRA_TEMPERATURE,
            Int.MIN_VALUE
        )
        val temperatureCelsius = if (rawTemperature == Int.MIN_VALUE) {
            null
        } else {
            rawTemperature / 10.0
        }
        val health = when (
            intent.getIntExtra(
                BatteryManager.EXTRA_HEALTH,
                BatteryManager.BATTERY_HEALTH_UNKNOWN
            )
        ) {
            BatteryManager.BATTERY_HEALTH_GOOD -> "Good"
            BatteryManager.BATTERY_HEALTH_OVERHEAT -> "Overheating"
            BatteryManager.BATTERY_HEALTH_DEAD -> "Dead"
            BatteryManager.BATTERY_HEALTH_OVER_VOLTAGE -> "Over voltage"
            BatteryManager.BATTERY_HEALTH_UNSPECIFIED_FAILURE -> "Unspecified failure"
            BatteryManager.BATTERY_HEALTH_COLD -> "Cold"
            else -> null
        }
        val pluggedValue = intent.getIntExtra(BatteryManager.EXTRA_PLUGGED, 0)
        val batteryStatus = when (
            intent.getIntExtra(
                BatteryManager.EXTRA_STATUS,
                BatteryManager.BATTERY_STATUS_UNKNOWN
            )
        ) {
            BatteryManager.BATTERY_STATUS_CHARGING -> "charging"
            BatteryManager.BATTERY_STATUS_DISCHARGING -> "discharging"
            BatteryManager.BATTERY_STATUS_FULL -> "full"
            BatteryManager.BATTERY_STATUS_NOT_CHARGING -> "notCharging"
            else -> "unknown"
        }
        val powerSource = when (pluggedValue) {
            0 -> "Battery"
            BatteryManager.BATTERY_PLUGGED_AC -> "AC power"
            BatteryManager.BATTERY_PLUGGED_USB -> "USB"
            BatteryManager.BATTERY_PLUGGED_WIRELESS -> "Wireless"
            else -> "External power"
        }

        return mapOf(
            "level" to level,
            "temperatureCelsius" to temperatureCelsius,
            "remainingChargeMah" to readRemainingChargeMah(),
            "voltageMillivolts" to intent.getIntExtra(
                BatteryManager.EXTRA_VOLTAGE,
                -1
            ).takeIf { it in 1..MAX_BATTERY_VOLTAGE_MILLIVOLTS },
            "currentNowMicroamps" to readCurrentNowMicroamps(),
            "status" to batteryStatus,
            "health" to health,
            "technology" to intent.getStringExtra(BatteryManager.EXTRA_TECHNOLOGY)
                ?.takeIf { it.isNotBlank() },
            "plugged" to (pluggedValue != 0),
            "powerSource" to powerSource
        )
    }

    private fun readRemainingChargeMah(): Double? {
        val chargeCounterMicroAmpHours = (getSystemService(Context.BATTERY_SERVICE) as? BatteryManager)
            ?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CHARGE_COUNTER)
            ?: return null
        return chargeCounterMicroAmpHours
            .takeIf { it >= 0 }
            ?.div(1000.0)
    }

    private fun readCurrentNowMicroamps(): Int? {
        val current = (getSystemService(Context.BATTERY_SERVICE) as? BatteryManager)
            ?.getIntProperty(BatteryManager.BATTERY_PROPERTY_CURRENT_NOW)
            ?: return null
        return current.takeIf { it != Int.MIN_VALUE && it != -1 }
    }

    companion object {
        private const val BATTERY_POLL_INTERVAL_MS = 5000L
        private const val MAX_BATTERY_VOLTAGE_MILLIVOLTS = 20000
        private const val BATTERY_DETAILS_CHANNEL =
            "batteryguard/device_battery_details"
        private const val BATTERY_HISTORY_CHANNEL =
            "batteryguard/health_history"
        private const val HISTORY_PREFERENCES = "batteryguard_health_history"
        private const val HISTORY_KEY = "measurements"
        private const val POWER_HISTORY_KEY = "power_measurements"
    }
}
