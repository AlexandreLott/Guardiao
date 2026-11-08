package br.edu.guardiaogamer.guardiao

import android.annotation.SuppressLint
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothGatt
import android.bluetooth.BluetoothGattCallback
import android.bluetooth.BluetoothGattCharacteristic
import android.bluetooth.BluetoothGattServer
import android.bluetooth.BluetoothGattServerCallback
import android.bluetooth.BluetoothGattService
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothProfile
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.bluetooth.le.BluetoothLeScanner
import android.bluetooth.le.ScanCallback
import android.bluetooth.le.ScanFilter
import android.bluetooth.le.ScanResult
import android.bluetooth.le.ScanSettings
import android.content.Context
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelUuid
import android.os.SystemClock
import java.util.UUID
import java.util.concurrent.atomic.AtomicBoolean

/**
 * Pareamento por Bluetooth Low Energy, sem biblioteca de terceiros.
 *
 * O aparelho do filho vira "periférico": anuncia um serviço e aceita UMA
 * escrita, o código de pareamento de 8 caracteres. O aparelho do responsável
 * faz o papel de "central": procura quem anuncia esse serviço, conecta e
 * escreve o código. Nada além do código viaja pelo Bluetooth; a confirmação
 * e o vínculo de verdade acontecem pelo Firebase.
 *
 * Os eventos (código recebido, aparelho encontrado, estado) saem pelo
 * callback [emit], sempre na thread principal.
 */
@SuppressLint("MissingPermission") // as permissões são pedidas antes, em MainActivity.prepare
class BleNearby(
    private val context: Context,
    private val emit: (Map<String, Any?>) -> Unit,
) {
    private val main = Handler(Looper.getMainLooper())
    private val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
    private val adapter: BluetoothAdapter? get() = manager?.adapter

    private fun post(event: Map<String, Any?>) {
        main.post { emit(event) }
    }

    // ------------------------------------------------ periférico (filho)

    private var server: BluetoothGattServer? = null
    private var advertiser: BluetoothLeAdvertiser? = null

    private val advertiseCallback = object : AdvertiseCallback() {
        override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
            post(mapOf("type" to "state", "value" to "advertising"))
        }

        override fun onStartFailure(errorCode: Int) {
            post(mapOf("type" to "state", "value" to "error:advertise:$errorCode"))
        }
    }

    private val serverCallback = object : BluetoothGattServerCallback() {
        override fun onServiceAdded(status: Int, service: BluetoothGattService?) {
            if (status == BluetoothGatt.GATT_SUCCESS) {
                beginAdvertising()
            } else {
                post(mapOf("type" to "state", "value" to "error:service:$status"))
            }
        }

        override fun onCharacteristicWriteRequest(
            device: BluetoothDevice?,
            requestId: Int,
            characteristic: BluetoothGattCharacteristic?,
            preparedWrite: Boolean,
            responseNeeded: Boolean,
            offset: Int,
            value: ByteArray?,
        ) {
            val valid = characteristic?.uuid == CODE_UUID &&
                !preparedWrite &&
                offset == 0 &&
                value != null &&
                value.size in 1..MAX_CODE_BYTES
            if (responseNeeded && device != null) {
                server?.sendResponse(
                    device,
                    requestId,
                    if (valid) BluetoothGatt.GATT_SUCCESS else BluetoothGatt.GATT_INVALID_ATTRIBUTE_LENGTH,
                    offset,
                    null,
                )
            }
            if (valid && value != null) {
                post(mapOf("type" to "code", "value" to String(value, Charsets.UTF_8)))
            }
        }
    }

    /** Devolve "ok", "off" ou "unsupported". O anúncio começa quando o serviço é registrado. */
    fun startAdvertising(): String {
        val ad = adapter ?: return "unsupported"
        if (!ad.isEnabled) return "off"
        val adv = ad.bluetoothLeAdvertiser ?: return "unsupported"
        stopAdvertising()
        val gatt = manager?.openGattServer(context, serverCallback) ?: return "unsupported"
        val service = BluetoothGattService(SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY)
        service.addCharacteristic(
            BluetoothGattCharacteristic(
                CODE_UUID,
                BluetoothGattCharacteristic.PROPERTY_WRITE,
                BluetoothGattCharacteristic.PERMISSION_WRITE,
            ),
        )
        server = gatt
        advertiser = adv
        gatt.addService(service)
        return "ok"
    }

    private fun beginAdvertising() {
        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
            .setConnectable(true)
            .setTimeout(0)
            .build()
        // O UUID vai no anúncio e o nome do aparelho na resposta de varredura,
        // para caber nos 31 bytes de cada pacote.
        val data = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addServiceUuid(ParcelUuid(SERVICE_UUID))
            .build()
        val scanResponse = AdvertiseData.Builder().setIncludeDeviceName(true).build()
        advertiser?.startAdvertising(settings, data, scanResponse, advertiseCallback)
    }

    fun stopAdvertising() {
        try {
            advertiser?.stopAdvertising(advertiseCallback)
        } catch (_: Exception) {
        }
        advertiser = null
        try {
            server?.close()
        } catch (_: Exception) {
        }
        server = null
    }

    // ------------------------------------------------ central (responsável)

    private var scanner: BluetoothLeScanner? = null

    private val scanCallback = object : ScanCallback() {
        override fun onScanResult(callbackType: Int, result: ScanResult) {
            val name = result.scanRecord?.deviceName ?: result.device.name ?: ""
            post(
                mapOf(
                    "type" to "device",
                    "address" to result.device.address,
                    "name" to name,
                ),
            )
        }

        override fun onScanFailed(errorCode: Int) {
            post(mapOf("type" to "state", "value" to "error:scan:$errorCode"))
        }
    }

    /** Devolve "ok", "off" ou "unsupported". */
    fun startScan(): String {
        val ad = adapter ?: return "unsupported"
        if (!ad.isEnabled) return "off"
        val sc = ad.bluetoothLeScanner ?: return "unsupported"
        stopScan()
        val filter = ScanFilter.Builder().setServiceUuid(ParcelUuid(SERVICE_UUID)).build()
        val settings = ScanSettings.Builder().setScanMode(ScanSettings.SCAN_MODE_LOW_LATENCY).build()
        sc.startScan(listOf(filter), settings, scanCallback)
        scanner = sc
        return "ok"
    }

    fun stopScan() {
        try {
            scanner?.stopScan(scanCallback)
        } catch (_: Exception) {
        }
        scanner = null
    }

    /**
     * Conecta no aparelho do filho e escreve o código. [done] recebe `null`
     * em caso de sucesso ou a mensagem de erro; é chamado uma única vez, na
     * thread principal.
     */
    fun sendCode(address: String, code: String, done: (String?) -> Unit) {
        val ad = adapter
        if (ad == null || !ad.isEnabled) {
            done("O Bluetooth está desligado.")
            return
        }
        val remote = try {
            ad.getRemoteDevice(address)
        } catch (_: IllegalArgumentException) {
            done("Endereço Bluetooth inválido.")
            return
        }
        val bytes = code.toByteArray(Charsets.UTF_8)
        val finished = AtomicBoolean(false)
        var gattRef: BluetoothGatt? = null

        fun finish(error: String?) {
            if (!finished.compareAndSet(false, true)) return
            main.removeCallbacksAndMessages(address)
            try {
                gattRef?.disconnect()
                gattRef?.close()
            } catch (_: Exception) {
            }
            main.post { done(error) }
        }

        val callback = object : BluetoothGattCallback() {
            override fun onConnectionStateChange(gatt: BluetoothGatt, status: Int, newState: Int) {
                if (newState == BluetoothProfile.STATE_CONNECTED && status == BluetoothGatt.GATT_SUCCESS) {
                    gatt.discoverServices()
                } else if (newState == BluetoothProfile.STATE_DISCONNECTED || status != BluetoothGatt.GATT_SUCCESS) {
                    finish("Não foi possível conectar ao aparelho.")
                }
            }

            override fun onServicesDiscovered(gatt: BluetoothGatt, status: Int) {
                val characteristic = gatt.getService(SERVICE_UUID)?.getCharacteristic(CODE_UUID)
                if (status != BluetoothGatt.GATT_SUCCESS || characteristic == null) {
                    finish("Esse aparelho não está esperando um código.")
                    return
                }
                val started = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    gatt.writeCharacteristic(
                        characteristic,
                        bytes,
                        BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT,
                    ) == BluetoothGatt.GATT_SUCCESS
                } else {
                    @Suppress("DEPRECATION")
                    run {
                        characteristic.writeType = BluetoothGattCharacteristic.WRITE_TYPE_DEFAULT
                        characteristic.value = bytes
                        gatt.writeCharacteristic(characteristic)
                    }
                }
                if (!started) finish("Não foi possível enviar o código.")
            }

            override fun onCharacteristicWrite(
                gatt: BluetoothGatt,
                characteristic: BluetoothGattCharacteristic,
                status: Int,
            ) {
                finish(if (status == BluetoothGatt.GATT_SUCCESS) null else "O aparelho recusou o código.")
            }
        }

        // Os callbacks do GATT chegam em outra thread; finish() ignora repetições.
        gattRef = remote.connectGatt(context, false, callback, BluetoothDevice.TRANSPORT_LE)
        main.postAtTime(
            { finish("Tempo esgotado. Aproxime os aparelhos e tente de novo.") },
            address,
            SystemClock.uptimeMillis() + SEND_TIMEOUT_MS,
        )
    }

    fun dispose() {
        stopScan()
        stopAdvertising()
    }

    companion object {
        val SERVICE_UUID: UUID = UUID.fromString("7a1c0001-6d5e-4f1b-9a52-4c0de6a1e0b1")
        val CODE_UUID: UUID = UUID.fromString("7a1c0002-6d5e-4f1b-9a52-4c0de6a1e0b1")
        const val MAX_CODE_BYTES = 16
        const val SEND_TIMEOUT_MS = 15_000L
    }
}
