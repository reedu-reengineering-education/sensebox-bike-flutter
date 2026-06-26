package de.reedu.senseboxbike

import android.os.Bundle
import com.polidea.rxandroidble2.exceptions.BleException
import io.flutter.embedding.android.FlutterActivity
import io.reactivex.exceptions.UndeliverableException
import io.reactivex.plugins.RxJavaPlugins

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        installRxJavaErrorHandler()
        super.onCreate(savedInstanceState)
    }

    // flutter_reactive_ble (rxandroidble) disposes notification subscriptions on
    // disconnect. When the peripheral drops unexpectedly (e.g. senseBox powered
    // off), a BleDisconnectedException can race that disposal and arrive with no
    // consumer, which RxJava wraps in an UndeliverableException and rethrows on
    // the main thread, crashing the app. Swallow those BLE exceptions and let
    // everything else fall through to the default handler.
    private fun installRxJavaErrorHandler() {
        RxJavaPlugins.setErrorHandler { throwable ->
            val error =
                if (throwable is UndeliverableException) throwable.cause ?: throwable
                else throwable

            if (error is BleException) {
                return@setErrorHandler
            }

            val thread = Thread.currentThread()
            (thread.uncaughtExceptionHandler
                ?: Thread.getDefaultUncaughtExceptionHandler())
                ?.uncaughtException(thread, error)
        }
    }
}
