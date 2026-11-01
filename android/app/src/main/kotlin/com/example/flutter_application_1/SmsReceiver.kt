package com.example.flutter_application_1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

class SmsReceiver : BroadcastReceiver() {
    companion object {
        var onSmsReceived: ((sender: String, body: String, timestamp: Long) -> Unit)? = null
    }

    override fun onReceive(context: Context?, intent: Intent?) {
        if (intent?.action == Telephony.Sms.Intents.SMS_RECEIVED_ACTION) {
            val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
            val fullBody = StringBuilder()
            var sender = ""
            var timestamp = System.currentTimeMillis()

            for (sms in messages) {
                sender = sms.displayOriginatingAddress ?: ""
                fullBody.append(sms.displayMessageBody ?: "")
                timestamp = sms.timestampMillis
            }

            if (fullBody.isNotEmpty()) {
                onSmsReceived?.invoke(sender, fullBody.toString(), timestamp)
            }
        }
    }
}
