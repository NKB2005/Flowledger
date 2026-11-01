package com.example.flutter_application_1

import android.Manifest
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val methodChannelName = "com.example.flutter_application_1/sms_channel"
    private val eventChannelName = "com.example.flutter_application_1/sms_stream"
    private val permissionRequestCode = 101

    private var eventSink: EventChannel.EventSink? = null
    private var pendingPermissionResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Stream channel for live incoming SMS
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, eventChannelName).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    SmsReceiver.onSmsReceived = { sender, body, timestamp ->
                        runOnUiThread {
                            val map = mapOf(
                                "sender" to sender,
                                "body" to body,
                                "timestamp" to timestamp
                            )
                            eventSink?.success(map)
                        }
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    SmsReceiver.onSmsReceived = null
                }
            }
        )

        // Method channel for checking permissions, requesting permissions, and scanning inbox
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val receiveGranted = checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                        val readGranted = checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                        result.success(receiveGranted && readGranted)
                    } else {
                        result.success(true)
                    }
                }
                "requestSmsPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val receiveGranted = checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                        val readGranted = checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                        if (receiveGranted && readGranted) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            requestPermissions(
                                arrayOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS),
                                permissionRequestCode
                            )
                        }
                    } else {
                        result.success(true)
                    }
                }
                "getRecentBankSms" -> {
                    val limit = call.argument<Int>("limit") ?: 30
                    try {
                        val messages = readRecentBankSms(limit)
                        result.success(messages)
                    } catch (e: Exception) {
                        result.error("READ_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == permissionRequestCode) {
            val granted = grantResults.isNotEmpty() && grantResults.all { it == PackageManager.PERMISSION_GRANTED }
            pendingPermissionResult?.success(granted)
            pendingPermissionResult = null
        }
    }

    private fun readRecentBankSms(limit: Int): List<Map<String, Any>> {
        val list = mutableListOf<Map<String, Any>>()
        val uri = Uri.parse("content://sms/inbox")
        val projection = arrayOf("address", "body", "date")
        val cursor: Cursor? = contentResolver.query(uri, projection, null, null, "date DESC")

        cursor?.use {
            val addressIdx = it.getColumnIndex("address")
            val bodyIdx = it.getColumnIndex("body")
            val dateIdx = it.getColumnIndex("date")

            var count = 0
            while (it.moveToNext() && count < limit) {
                val address = if (addressIdx != -1) it.getString(addressIdx) ?: "" else ""
                val body = if (bodyIdx != -1) it.getString(bodyIdx) ?: "" else ""
                val date = if (dateIdx != -1) it.getLong(dateIdx) else System.currentTimeMillis()

                list.add(mapOf("sender" to address, "body" to body, "timestamp" to date))
                count++
            }
        }
        return list
    }
}
