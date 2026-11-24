package az.orbita.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.viewModels
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color

class MainActivity : ComponentActivity() {
    private val vm: AppVm by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            val colors = if (isSystemInDarkTheme()) {
                darkColorScheme(primary = Color(0xFF9AA7FF))
            } else {
                lightColorScheme(primary = Color(0xFF3B4CCA))
            }
            MaterialTheme(colorScheme = colors) {
                Surface(modifier = Modifier.fillMaxSize()) { App(vm) }
            }
        }
    }
}
