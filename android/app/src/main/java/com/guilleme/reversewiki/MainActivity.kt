package com.guilleme.reversewiki

import android.Manifest
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.FileProvider
import androidx.lifecycle.viewmodel.compose.viewModel
import com.guilleme.reversewiki.ui.MainViewModel
import com.guilleme.reversewiki.ui.ReverseWikiApp
import java.io.File

class MainActivity : ComponentActivity() {
    private var cameraUri: Uri? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val takePicture = registerForActivityResult(ActivityResultContracts.TakePicture()) { success ->
            if (success) cameraUri?.let { uri ->
                contentResolver.openInputStream(uri)?.use { stream -> pendingViewModel?.analyze(stream.readBytes(), true) }
            }
        }
        val pickPhoto = registerForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri ->
            uri?.let { contentResolver.openInputStream(it)?.use { stream -> pendingViewModel?.analyze(stream.readBytes(), false) } }
        }
        val requestPermissions = registerForActivityResult(
            ActivityResultContracts.RequestMultiplePermissions(),
        ) {
            val directory = File(cacheDir, "camera").apply { mkdirs() }
            val file = File(directory, "capture-${System.currentTimeMillis()}.jpg")
            val uri = FileProvider.getUriForFile(this, "$packageName.files", file)
            cameraUri = uri
            takePicture.launch(uri)
        }

        setContent {
            val mainViewModel: MainViewModel = viewModel()
            pendingViewModel = mainViewModel
            ReverseWikiApp(
                viewModel = mainViewModel,
                onCamera = {
                    requestPermissions.launch(arrayOf(
                        Manifest.permission.CAMERA,
                        Manifest.permission.ACCESS_COARSE_LOCATION,
                        Manifest.permission.ACCESS_FINE_LOCATION,
                    ))
                },
                onImport = {
                    pickPhoto.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                },
            )
        }
    }

    private var pendingViewModel: MainViewModel? = null
}
