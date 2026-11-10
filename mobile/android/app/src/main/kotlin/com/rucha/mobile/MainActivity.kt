package com.rucha.mobile

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattDescriptor
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Looper
import android.os.ParcelUuid
import android.provider.MediaStore
import androidx.core.app.ActivityCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class MainActivity : FlutterActivity() {
    private val LOCATION_PERMISSION_REQUEST = 1001
    private val CAMERA_REQUEST_CODE = 2001
    private val GALLERY_REQUEST_CODE = 2002

    private val GPS_METHOD_CHANNEL = "com.rucha.mobile/gps_control"
    private val GPS_EVENT_CHANNEL = "com.rucha.mobile/gps_stream"

    private val MEDIA_CHANNEL = "com.rucha.mobile/media_share"
    private val WATCH_METHOD_CHANNEL = "com.rucha.mobile/smartwatch"
    private val WATCH_EVENT_CHANNEL = "com.rucha.mobile/smartwatch_stream"

    // Standard Bluetooth SIG UUIDs for Smartwatch Heart Rate
    private val UUID_HEART_RATE_SERVICE = UUID.fromString("0000180d-0000-1000-8000-00805f9b34fb")
    private val UUID_HEART_RATE_MEASUREMENT = UUID.fromString("00002a37-0000-1000-8000-00805f9b34fb")
    private val UUID_CLIENT_CHARACTERISTIC_CONFIG = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb")

    private var gpsEventSink: EventChannel.EventSink? = null
    private var watchEventSink: EventChannel.EventSink? = null
    private var locationManager: LocationManager? = null

    // Pending Flutter result callbacks for Camera / Gallery
    private var pendingMediaResult: MethodChannel.Result? = null
    private var currentCameraPhotoPath: String? = null

    // Bluetooth Smartwatch state
    private var bluetoothAdapter: BluetoothAdapter? = null
    private var bluetoothGatt: BluetoothGatt? = null
    private var isScanningWatches = false
    private val discoveredWatches = HashMap<String, String>() // Address -> Name
    private var connectedWatchName: String? = null
    private var lastRecordedBpm: Int = 0

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
                gpsEventSink?.success(data)
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
        val bm = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        bluetoothAdapter = bm?.adapter

        // 1. GPS Channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, GPS_METHOD_CHANNEL).setMethodCallHandler { call, result ->
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

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, GPS_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    gpsEventSink = events
                    startLocationUpdates()
                }

                override fun onCancel(arguments: Any?) {
                    stopLocationUpdates()
                    gpsEventSink = null
                }
            }
        )

        // 2. Media, Camera, Gallery & Share Channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openCamera" -> {
                    openCamera(result)
                }
                "pickImage" -> {
                    pickImage(result)
                }
                "openTelegram" -> {
                    val bot = call.argument<String>("bot") ?: "ruchaabot"
                    val start = call.argument<String>("start") ?: ""
                    val ok = openTelegramApp(bot, start)
                    result.success(ok)
                }
                "saveImageToGallery" -> {
                    val filePath = call.argument<String>("filePath")
                    val bytes = call.argument<ByteArray>("bytes")
                    if (filePath != null) {
                        val saved = saveFileToGallery(File(filePath))
                        result.success(saved)
                    } else if (bytes != null) {
                        val saved = saveBytesToGallery(bytes)
                        result.success(saved)
                    } else {
                        result.error("INVALID_ARGS", "Missing filePath or bytes", null)
                    }
                }
                "shareCard" -> {
                    val filePath = call.argument<String>("filePath")
                    val caption = call.argument<String>("caption") ?: "RUCHA Highland Athlete Card"
                    if (filePath != null) {
                        shareCardImage(File(filePath), caption)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "filePath is required", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 3. Smartwatch BLE Channels
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WATCH_METHOD_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isBluetoothAvailable" -> {
                    result.success(bluetoothAdapter?.isEnabled == true)
                }
                "startScan" -> {
                    val ok = startWatchScan()
                    result.success(ok)
                }
                "stopScan" -> {
                    stopWatchScan()
                    result.success(true)
                }
                "connectWatch" -> {
                    val address = call.argument<String>("address")
                    val name = call.argument<String>("name") ?: "Smartwatch"
                    if (address != null) {
                        connectWatchGatt(address, name)
                        result.success(true)
                    } else {
                        result.error("INVALID_ARGS", "address is required", null)
                    }
                }
                "disconnectWatch" -> {
                    disconnectWatchGatt()
                    result.success(true)
                }
                "getWatchStatus" -> {
                    val map = HashMap<String, Any?>()
                    map["connected"] = (bluetoothGatt != null && connectedWatchName != null)
                    map["name"] = connectedWatchName
                    map["bpm"] = lastRecordedBpm
                    result.success(map)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WATCH_EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    watchEventSink = events
                }

                override fun onCancel(arguments: Any?) {
                    watchEventSink = null
                }
            }
        )
    }

    // --- Camera & Gallery Handling ---

    private fun openCamera(result: MethodChannel.Result) {
        try {
            if (ActivityCompat.checkSelfPermission(this, Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.CAMERA), 1002)
                result.error("PERMISSION_DENIED", "Camera permission requested, try again.", null)
                return
            }

            val photoFile = File(cacheDir, "camera_photo_${System.currentTimeMillis()}.jpg")
            currentCameraPhotoPath = photoFile.absolutePath

            val photoUri = FileProvider.getUriForFile(
                this,
                "$packageName.fileprovider",
                photoFile
            )

            pendingMediaResult = result
            val intent = Intent(MediaStore.ACTION_IMAGE_CAPTURE).apply {
                putExtra(MediaStore.EXTRA_OUTPUT, photoUri)
                addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
            }
            startActivityForResult(intent, CAMERA_REQUEST_CODE)
        } catch (e: Exception) {
            result.error("CAMERA_ERROR", e.localizedMessage, null)
        }
    }

    private fun pickImage(result: MethodChannel.Result) {
        try {
            pendingMediaResult = result
            val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                type = "image/*"
                addCategory(Intent.CATEGORY_OPENABLE)
            }
            startActivityForResult(intent, GALLERY_REQUEST_CODE)
        } catch (e: Exception) {
            result.error("GALLERY_ERROR", e.localizedMessage, null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode == CAMERA_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && currentCameraPhotoPath != null) {
                pendingMediaResult?.success(currentCameraPhotoPath)
            } else {
                pendingMediaResult?.error("CANCELLED", "User cancelled camera", null)
            }
            pendingMediaResult = null
        } else if (requestCode == GALLERY_REQUEST_CODE) {
            if (resultCode == Activity.RESULT_OK && data?.data != null) {
                try {
                    val destFile = File(cacheDir, "picked_photo_${System.currentTimeMillis()}.jpg")
                    contentResolver.openInputStream(data.data!!)?.use { input ->
                        FileOutputStream(destFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    pendingMediaResult?.success(destFile.absolutePath)
                } catch (e: Exception) {
                    pendingMediaResult?.error("IO_ERROR", "Failed to load selected photo: ${e.message}", null)
                }
            } else {
                pendingMediaResult?.error("CANCELLED", "User cancelled photo selection", null)
            }
            pendingMediaResult = null
        }
    }

    private fun openTelegramApp(bot: String, startParam: String): Boolean {
        val tgUri = if (startParam.isNotEmpty()) {
            Uri.parse("tg://resolve?domain=$bot&start=$startParam")
        } else {
            Uri.parse("tg://resolve?domain=$bot")
        }
        val tgIntent = Intent(Intent.ACTION_VIEW, tgUri).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        return try {
            startActivity(tgIntent)
            true
        } catch (_: Exception) {
            try {
                val webUri = if (startParam.isNotEmpty()) {
                    Uri.parse("https://t.me/$bot?start=$startParam")
                } else {
                    Uri.parse("https://t.me/$bot")
                }
                val webIntent = Intent(Intent.ACTION_VIEW, webUri).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(webIntent)
                true
            } catch (_: Exception) {
                false
            }
        }
    }

    private fun saveFileToGallery(file: File): Boolean {
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "RUCHA_${System.currentTimeMillis()}.png")
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/RUCHA")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }

            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                contentResolver.openOutputStream(uri)?.use { out ->
                    file.inputStream().use { inp -> inp.copyTo(out) }
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                } else {
                    MediaScannerConnection.scanFile(this, arrayOf(file.absolutePath), arrayOf("image/png"), null)
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun saveBytesToGallery(bytes: ByteArray): Boolean {
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, "RUCHA_${System.currentTimeMillis()}.png")
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/RUCHA")
                    put(MediaStore.Images.Media.IS_PENDING, 1)
                }
            }

            val uri = contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
            if (uri != null) {
                contentResolver.openOutputStream(uri)?.use { out ->
                    out.write(bytes)
                }
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    values.clear()
                    values.put(MediaStore.Images.Media.IS_PENDING, 0)
                    contentResolver.update(uri, values, null, null)
                }
                true
            } else {
                false
            }
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun shareCardImage(file: File, caption: String) {
        val uri: Uri = FileProvider.getUriForFile(
            this,
            "$packageName.fileprovider",
            file
        )

        val shareIntent = Intent(Intent.ACTION_SEND).apply {
            type = "image/png"
            putExtra(Intent.EXTRA_STREAM, uri)
            putExtra(Intent.EXTRA_TEXT, caption)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val chooser = Intent.createChooser(shareIntent, "Share RUCHA Activity via")
        startActivity(chooser)
    }

    // --- Smartwatch BLE Scanning & GATT Integration ---

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult?) {
            result?.device?.let { dev ->
                val name = dev.name ?: "Smartwatch Device"
                val addr = dev.address
                if (!discoveredWatches.containsKey(addr)) {
                    discoveredWatches[addr] = name
                    val map = HashMap<String, Any>()
                    map["type"] = "discovered"
                    map["address"] = addr
                    map["name"] = name
                    map["rssi"] = result.rssi
                    runOnUiThread {
                        watchEventSink?.success(map)
                    }
                }
            }
        }

        override fun onScanFailed(errorCode: Int) {
            val map = HashMap<String, Any>()
            map["type"] = "scan_failed"
            map["error"] = errorCode
            runOnUiThread {
                watchEventSink?.success(map)
            }
        }
    }

    private fun startWatchScan(): Boolean {
        val adapter = bluetoothAdapter ?: return false
        if (!adapter.isEnabled) return false

        discoveredWatches.clear()
        val scanner = adapter.bluetoothLeScanner ?: return false

        try {
            val filters = mutableListOf<ScanFilter>()
            filters.add(ScanFilter.Builder().setServiceUuid(ParcelUuid(UUID_HEART_RATE_SERVICE)).build())

            val settings = ScanSettings.Builder()
                .setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY)
                .build()

            isScanningWatches = true
            scanner.startScan(filters, settings, scanCallback)
            return true
        } catch (e: SecurityException) {
            return false
        }
    }

    private fun stopWatchScan() {
        if (!isScanningWatches) return
        try {
            bluetoothAdapter?.bluetoothLeScanner?.stopScan(scanCallback)
        } catch (_: SecurityException) {}
        isScanningWatches = false
    }

    private fun connectWatchGatt(address: String, name: String) {
        stopWatchScan()
        disconnectWatchGatt()

        val adapter = bluetoothAdapter ?: return
        val device = try {
            adapter.getRemoteDevice(address)
        } catch (_: Exception) {
            return
        }

        try {
            bluetoothGatt = device.connectGatt(this, false, object : BluetoothGattCallback() {
                override fun onConnectionStateChange(gatt: BluetoothGatt?, status: Int, newState: Int) {
                    if (newState == BluetoothProfile.STATE_CONNECTED) {
                        connectedWatchName = name
                        val map = HashMap<String, Any>()
                        map["type"] = "status"
                        map["status"] = "connected"
                        map["name"] = name
                        map["address"] = address
                        runOnUiThread { watchEventSink?.success(map) }

                        // Discover GATT services
                        gatt?.discoverServices()
                    } else if (newState == BluetoothProfile.STATE_DISCONNECTED) {
                        connectedWatchName = null
                        val map = HashMap<String, Any>()
                        map["type"] = "status"
                        map["status"] = "disconnected"
                        runOnUiThread { watchEventSink?.success(map) }
                    }
                }

                override fun onServicesDiscovered(gatt: BluetoothGatt?, status: Int) {
                    if (status == BluetoothGatt.GATT_SUCCESS && gatt != null) {
                        val hrService = gatt.getService(UUID_HEART_RATE_SERVICE)
                        val hrChar = hrService?.getCharacteristic(UUID_HEART_RATE_MEASUREMENT)
                        if (hrChar != null) {
                            gatt.setCharacteristicNotification(hrChar, true)
                            val descriptor = hrChar.getDescriptor(UUID_CLIENT_CHARACTERISTIC_CONFIG)
                            if (descriptor != null) {
                                descriptor.value = BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE
                                gatt.writeDescriptor(descriptor)
                            }
                        }
                    }
                }

                override fun onCharacteristicChanged(gatt: BluetoothGatt?, characteristic: BluetoothGattCharacteristic?) {
                    if (characteristic?.uuid == UUID_HEART_RATE_MEASUREMENT) {
                        val value = characteristic.value ?: return
                        if (value.isNotEmpty()) {
                            val flag = value[0].toInt()
                            val bpm = if ((flag and 0x01) != 0) {
                                (value[1].toInt() and 0xFF) or ((value[2].toInt() and 0xFF) shl 8)
                            } else {
                                value[1].toInt() and 0xFF
                            }

                            lastRecordedBpm = bpm
                            val map = HashMap<String, Any>()
                            map["type"] = "bpm"
                            map["bpm"] = bpm
                            map["device"] = connectedWatchName ?: "Smartwatch"
                            runOnUiThread { watchEventSink?.success(map) }
                        }
                    }
                }
            })
        } catch (_: SecurityException) {}
    }

    private fun disconnectWatchGatt() {
        try {
            bluetoothGatt?.disconnect()
            bluetoothGatt?.close()
        } catch (_: Exception) {}
        bluetoothGatt = null
        connectedWatchName = null
    }

    // --- Location Permissions & Management ---

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
                if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER)) {
                    lm.requestLocationUpdates(
                        LocationManager.GPS_PROVIDER,
                        1000L,
                        1.0f,
                        locationListener,
                        Looper.getMainLooper()
                    )
                }
                if (lm.isProviderEnabled(LocationManager.NETWORK_PROVIDER)) {
                    lm.requestLocationUpdates(
                        LocationManager.NETWORK_PROVIDER,
                        1000L,
                        2.0f,
                        locationListener,
                        Looper.getMainLooper()
                    )
                }

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

    override fun onDestroy() {
        super.onDestroy()
        stopLocationUpdates()
        disconnectWatchGatt()
        stopWatchScan()
    }
}
