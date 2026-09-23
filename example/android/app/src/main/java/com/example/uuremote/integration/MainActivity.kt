package com.example.uuremote.integration

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.selection.SelectionContainer
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material3.Button
import androidx.compose.material3.ElevatedCard
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.core.net.toUri
import com.example.uuremote.integration.ui.theme.UuRemoteIntegrationDemoTheme
import java.util.UUID

/** 回调 scheme/host，需与 AndroidManifest 里 <data> 的声明一致。 */
private const val CALLBACK_SCHEME = "uuremote-integration"
private const val CALLBACK_HOST = "callback"
private const val CALLBACK_URL = "$CALLBACK_SCHEME://$CALLBACK_HOST"

class MainActivity : ComponentActivity() {

    /** 结果区显示的内容：回调 deeplink 原文，发送失败时是失败原因。 */
    private var resultText by mutableStateOf<String?>(null)

    /** 已绑定设备（anonymous_device_id）。放进程级，避免回执重新拉起 Activity 时列表丢失。 */
    private val boundDevices = mutableStateListOf<String>()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleCallback(intent)
        enableEdgeToEdge()
        setContent {
            UuRemoteIntegrationDemoTheme {
                MainScreen(
                    devices = boundDevices,
                    result = resultText,
                    onBind = ::bindDevice,
                    onRemoteControl = ::startRemoteControl,
                    onFloatWindow = ::startFloatWindow,
                    onRemove = { boundDevices.remove(it) },
                    onCopy = ::copyToClipboard,
                )
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallback(intent)
    }

    /** 发起绑定：用户授权后 UU 远程回传 anonymous_device_id。 */
    private fun bindDevice() {
        sendDeeplink(
            "uuremote://external/device/authorize" +
                    "?callback=${Uri.encode(CALLBACK_URL)}" +
                    "&nonce=${UUID.randomUUID()}",
        )
    }

    /** 全屏远控（window_type=0）。UU 远程端不会回跳第三方，所以不带 callback。 */
    private fun startRemoteControl(deviceId: String) {
        sendDeeplink(
            "uuremote://external/device/control" +
                    "?anonymous_device_id=${Uri.encode(deviceId)}" +
                    "&window_type=0",
        )
    }

    /** 悬浮小窗（window_type=1）。带 callback，UU 远程端启动完成后回执本 App。 */
    private fun startFloatWindow(deviceId: String) {
        sendDeeplink(
            "uuremote://external/device/control" +
                    "?anonymous_device_id=${Uri.encode(deviceId)}" +
                    "&window_type=1" +
                    "&callback=${Uri.encode(CALLBACK_URL)}",
        )
    }

    private fun sendDeeplink(url: String) {
        runCatching {
            startActivity(Intent(Intent.ACTION_VIEW, url.toUri()))
        }.onFailure {
            resultText = getString(R.string.send_failed_prefix) + it.message.orEmpty()
        }
    }

    private fun handleCallback(intent: Intent) {
        val data = intent.data ?: return
        if (data.scheme != CALLBACK_SCHEME || data.host != CALLBACK_HOST) return
        resultText = data.toString()

        // 绑定成功的回执带着加密设备标识，存起来供后续拉起远控
        val deviceId = data.getQueryParameter("anonymous_device_id")
        if (deviceId != null && deviceId !in boundDevices) boundDevices.add(deviceId)
    }

    private fun copyToClipboard(value: String) {
        getSystemService(ClipboardManager::class.java)?.setPrimaryClip(
            ClipData.newPlainText("deeplink", value)
        )
    }
}

@Composable
private fun MainScreen(
    devices: List<String>,
    result: String?,
    onBind: () -> Unit,
    onRemoteControl: (String) -> Unit,
    onFloatWindow: (String) -> Unit,
    onRemove: (String) -> Unit,
    onCopy: (String) -> Unit,
) {
    Scaffold(modifier = Modifier.fillMaxSize()) { innerPadding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(innerPadding)
        ) {
            if (devices.isEmpty()) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        text = stringResource(R.string.bound_device_empty),
                        style = MaterialTheme.typography.bodyMedium,
                    )
                }
            } else {
                LazyColumn(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxWidth(),
                    contentPadding = PaddingValues(horizontal = 16.dp, vertical = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    items(devices, key = { it }) { deviceId ->
                        DeviceItem(
                            deviceId = deviceId,
                            onRemoteControl = { onRemoteControl(deviceId) },
                            onFloatWindow = { onFloatWindow(deviceId) },
                            onRemove = { onRemove(deviceId) },
                        )
                    }
                }
            }
            if (result != null) {
                Text(
                    text = stringResource(R.string.result_title),
                    style = MaterialTheme.typography.labelMedium,
                    modifier = Modifier.padding(horizontal = 16.dp),
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SelectionContainer(modifier = Modifier.weight(1f)) {
                        Text(
                            text = result,
                            style = MaterialTheme.typography.bodySmall,
                        )
                    }
                    TextButton(onClick = { onCopy(result) }) {
                        Text(text = stringResource(R.string.action_copy))
                    }
                }
            }
            Button(
                onClick = onBind,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(16.dp),
            ) {
                Text(text = stringResource(R.string.bind_device))
            }
        }
    }
}

@Composable
private fun DeviceItem(
    deviceId: String,
    onRemoteControl: () -> Unit,
    onFloatWindow: () -> Unit,
    onRemove: () -> Unit,
) {
    ElevatedCard(modifier = Modifier.fillMaxWidth()) {
        Column(modifier = Modifier.fillMaxWidth()) {
            Box(modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = stringResource(R.string.device_id, deviceId),
                    modifier = Modifier.padding(start = 16.dp, end = 56.dp, top = 16.dp),
                )
                IconButton(
                    onClick = onRemove,
                    modifier = Modifier.align(Alignment.TopEnd),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = stringResource(R.string.device_remove),
                    )
                }
            }
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(start = 10.dp, end = 4.dp, bottom = 4.dp),
                horizontalArrangement = Arrangement.End,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                TextButton(
                    onClick = onRemoteControl,
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 0.dp),
                ) {
                    Text(text = stringResource(R.string.device_open_remote_control))
                }
                TextButton(
                    onClick = onFloatWindow,
                    contentPadding = PaddingValues(horizontal = 6.dp, vertical = 0.dp),
                ) {
                    Text(text = stringResource(R.string.device_open_float_window))
                }
            }
        }
    }
}
