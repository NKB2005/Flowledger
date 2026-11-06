package com.example.flutter_application_1

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import java.util.Locale

object NotificationHelper {
    const val CHANNEL_ID = "flowledger_payments"
    private const val CHANNEL_NAME = "Payment Alerts"

    fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifies you when online payments are detected so you can add their category"
                enableVibration(true)
                setShowBadge(true)
            }
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    fun showPaymentNotification(
        context: Context,
        amount: Double,
        merchant: String,
        category: String,
        isExpense: Boolean,
        transactionId: String? = null
    ) {
        createNotificationChannel(context)

        val intent = Intent(context, MainActivity::class.java).apply {
            action = "com.example.flutter_application_1.CATEGORIZE_PAYMENT"
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("action", "categorize_payment")
            putExtra("amount", amount)
            putExtra("merchant", merchant)
            putExtra("category", category)
            putExtra("isExpense", isExpense)
            putExtra("transactionId", transactionId ?: "")
        }

        val pendingIntentFlags = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        } else {
            PendingIntent.FLAG_UPDATE_CURRENT
        }

        val notificationId = (System.currentTimeMillis() % 100000).toInt()
        val pendingIntent = PendingIntent.getActivity(context, notificationId, intent, pendingIntentFlags)

        val actionText = if (isExpense) "paid" else "received"
        val merchantText = if (merchant.trim().isNotEmpty()) " at $merchant" else ""
        val title = "Payment detected: ₹${String.format(Locale.ENGLISH, "%.2f", amount)}"
        val body = "Tap to add category for what you just $actionText$merchantText"

        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(
                NotificationCompat.BigTextStyle()
                    .bigText("$body\n\nChoose Food, Shopping, Travel, Bills, etc. to keep your spending organized.")
            )
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .setDefaults(NotificationCompat.DEFAULT_ALL)

        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.notify(notificationId, builder.build())
    }
}
