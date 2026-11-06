package com.example.flutter_application_1

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.os.Bundle
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
    private var methodChannel: MethodChannel? = null
    private var pendingCategorizeData: Map<String, Any>? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NotificationHelper.createNotificationChannel(this)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent == null) return
        val action = intent.getStringExtra("action")
        if (action == "categorize_payment") {
            val data = mapOf(
                "amount" to intent.getDoubleExtra("amount", 0.0),
                "merchant" to (intent.getStringExtra("merchant") ?: ""),
                "category" to (intent.getStringExtra("category") ?: "Other"),
                "isExpense" to intent.getBooleanExtra("isExpense", true),
                "transactionId" to (intent.getStringExtra("transactionId") ?: "")
            )
            pendingCategorizeData = data
            methodChannel?.invokeMethod("onCategorizePaymentIntent", data)
        }
    }

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

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannelName)
        methodChannel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val receiveGranted = checkSelfPermission(Manifest.permission.RECEIVE_SMS) == PackageManager.PERMISSION_GRANTED
                        val readGranted = checkSelfPermission(Manifest.permission.READ_SMS) == PackageManager.PERMISSION_GRANTED
                        val notificationGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                        } else true
                        result.success(receiveGranted && readGranted && notificationGranted)
                    } else {
                        result.success(true)
                    }
                }
                "requestSmsPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        val perms = mutableListOf(Manifest.permission.RECEIVE_SMS, Manifest.permission.READ_SMS)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                            perms.add(Manifest.permission.POST_NOTIFICATIONS)
                        }
                        val missing = perms.filter { checkSelfPermission(it) != PackageManager.PERMISSION_GRANTED }
                        if (missing.isEmpty()) {
                            result.success(true)
                        } else {
                            pendingPermissionResult = result
                            requestPermissions(missing.toTypedArray(), permissionRequestCode)
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
                "showPaymentNotification" -> {
                    try {
                        val amount = call.argument<Double>("amount") ?: 0.0
                        val merchant = call.argument<String>("merchant") ?: ""
                        val category = call.argument<String>("category") ?: "Other"
                        val isExpense = call.argument<Boolean>("isExpense") ?: true
                        val transactionId = call.argument<String>("transactionId") ?: ""
                        NotificationHelper.showPaymentNotification(
                            this,
                            amount,
                            merchant,
                            category,
                            isExpense,
                            transactionId
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("NOTIF_ERROR", e.message, null)
                    }
                }
                "getPendingCategorizeTransaction" -> {
                    val data = pendingCategorizeData
                    pendingCategorizeData = null
                    result.success(data)
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
