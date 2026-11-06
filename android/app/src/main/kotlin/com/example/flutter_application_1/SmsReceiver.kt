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

            val body = fullBody.toString()
            if (body.isNotEmpty()) {
                if (onSmsReceived != null) {
                    onSmsReceived?.invoke(sender, body, timestamp)
                } else if (context != null) {
                    // App is not active in foreground, detect payment SMS and notify user
                    parseAndNotifyBackground(context, body)
                }
            }
        }
    }

    private fun parseAndNotifyBackground(context: Context, body: String) {
        val lower = body.lowercase()
        val isDebit = lower.contains("debited") || lower.contains("spent") || lower.contains("paid") || lower.contains("sent rs")
        val isCredit = lower.contains("credited") || lower.contains("received")

        if (!isDebit && !isCredit) return

        val amountRegex = Regex("""(?:rs\.?|inr|₹)\s*([\d,]+(?:\.\d{1,2})?)""", RegexOption.IGNORE_CASE)
        val match = amountRegex.find(body) ?: return
        val rawAmount = match.groupValues[1].replace(",", "")
        val amount = rawAmount.toDoubleOrNull() ?: return
        if (amount <= 0) return

        val merchantRegex = Regex("""(?:at|to|info)\s+([A-Za-z0-9\s\-]+?)(?:\s+(?:on|ref|upi|avl|bal|using|\.|\,)|$)""", RegexOption.IGNORE_CASE)
        val merchantMatch = merchantRegex.find(body)
        val merchant = merchantMatch?.groupValues?.get(1)?.trim() ?: ""

        NotificationHelper.showPaymentNotification(
            context = context,
            amount = amount,
            merchant = merchant,
            category = "Other",
            isExpense = !isCredit
        )
    }
}
