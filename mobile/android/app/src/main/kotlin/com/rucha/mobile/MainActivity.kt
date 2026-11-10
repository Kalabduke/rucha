package com.rucha.mobile

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val LOCATION_PERMISSION_REQUEST = 1001
    private val METHOD_CHANNEL = "com.rucha.mobile/gps_control"
    private val EVENT_CHANNEL = "com.rucha.mobile/gps_stream"

    private var eventSink: EventChannel.EventSink? = null
    private var locationManager: LocationManager? = null

    private val locationListener = object : LocationListener {
        override fun onLocationChanged(loc: Location) {
            val data = HashMap<String, Any?>()
            data["latitude"] = loc.latitude
            data["longitude"] = loc.longitude
            data["altitude"] = if (loc.hasAltitude()) loc.altitude else 2355.0
            data["accuracy"] = if (loc.hasAccuracy()) loc.accuracy.toDouble() else 10.0
            data["speed"] = if (loc.hasSpeed()) loc.speed.toDouble() else 0.0
            data["timestamp"] = loc.time
            runOnUiThread {
                eventSink?.success(data)
            }
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        locationManager = getSystemService(Context.LOCATION_SERVICE) as LocationManager

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermissions" -> {
                    checkAndRequestPermissions()
                    result.success(hasLocationPermissions())
                }
                "hasPermissions" -> {
                    result.success(hasLocationPermissions())
                }
                "startGps" -> {
                    startLocationUpdates()
                    result.success(true)
                }
                "stopGps" -> {
                    stopLocationUpdates()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    startLocationUpdates()
                }

                override fun onCancel(arguments: Any?) {
                    stopLocationUpdates()
                    eventSink = null
                }
            }
        )
    }

    private fun hasLocationPermissions(): Boolean {
        val fine = ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED
        val coarse = ActivityCompat.checkSelfPermission(this, Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED
        return fine || coarse
    }

    private fun checkAndRequestPermissions() {
        if (!hasLocationPermissions()) {
            ActivityCompat.requestPermissions(
                this,
                arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION),
                LOCATION_PERMISSION_REQUEST
            )
        }
    }

    private fun startLocationUpdates() {
        if (!hasLocationPermissions()) {
            checkAndRequestPermissions()
            return
        }

        try {
            locationManager?.let { lm ->
                // Register GPS Provider for raw precision satellites
                if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    lm.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        1000L, // 1000 ms
                        1.0f,  // 1 meter
                        locationListener,
                        Looper.getMainLooper()
                    )
                }
                // Also register Network Provider for instant fix while GPS locks
                if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    lm.requestLocationUpdates(
                        LocationManager.NETWORK_PROVIDER,
                        1000L,
                        2.0f,
                        locationListener,
                        Looper.getMainLooper()
                    )
                }

                // Immediately emit last known fix
                val lastGps = lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                val lastNet = lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
                val best = lastGps ?: lastNet
                best?.let { locationListener.onLocationChanged(it) }
            }
        } catch (_: SecurityException) {
            checkAndRequestPermissions()
        }
    }

    private fun stopLocationUpdates() {
        try {
            locationManager?.removeUpdates(locationListener)
        } catch (_: Exception) {}
    }
}
