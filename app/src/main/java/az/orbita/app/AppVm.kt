package az.orbita.app

import android.app.Application
import android.content.Context
import android.os.Build
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import org.json.JSONArray
import org.json.JSONObject
import java.net.URLEncoder

sealed class Screen {
    object Login : Screen()
    object Code : Screen()
    object Profile : Screen()
    object Chats : Screen()
    object NewChat : Screen()
    data class ChatView(val chat: Chat) : Screen()
}

private fun JSONArray.objects(): List<JSONObject> = (0 until length()).map { getJSONObject(it) }

class AppVm(app: Application) : AndroidViewModel(app) {
    private val prefs = app.getSharedPreferences("orbita", Context.MODE_PRIVATE)

    var api = Api(prefs.getString("base", "http://10.0.2.2:8080") ?: "", prefs.getString("token", null))
        private set

    var screen by mutableStateOf<Screen>(if (api.token == null) Screen.Login else Screen.Chats)
    var busy by mutableStateOf(false)
    var error by mutableStateOf<String?>(null)
    var email by mutableStateOf("")
    var devCode by mutableStateOf<String?>(null)
    var me by mutableStateOf<User?>(null)
    var chats by mutableStateOf<List<Chat>>(emptyList())
    var messages by mutableStateOf<List<Msg>>(emptyList())
    var found by mutableStateOf<List<User>>(emptyList())

    private var eventsJob: Job? = null

    init {
        if (api.token != null) start()
    }

    private fun start() {
        viewModelScope.launch {
            try {
                me = api.call("GET", "/me").getJSONObject("user").toUser()
                if (me?.username == null) screen = Screen.Profile
                loadChats()
            } catch (e: ApiError) {
                if (e.status == 401) logout() else error = e.message
            }
        }
        eventsJob?.cancel()
        eventsJob = viewModelScope.launch {
            while (isActive) {
                try {
                    api.listen { ev, data -> viewModelScope.launch { handleEvent(ev, data) } }
                } catch (e: Exception) {
                    // обрыв связи: подождём и подключимся снова
                }
                delay(3000)
            }
        }
    }

    private suspend fun loadChats() {
        chats = api.call("GET", "/chats").getJSONArray("chats").objects().map { it.toChat() }
    }

    private fun refreshChats() {
        viewModelScope.launch {
            try {
                loadChats()
            } catch (e: ApiError) {
                // не критично
            }
        }
    }

    private fun addMsg(m: Msg) {
        val s = screen
        if (s is Screen.ChatView && s.chat.id == m.chatId && messages.none { it.id == m.id }) {
            messages = messages + m
        }
    }

    private fun handleEvent(ev: String, data: String) {
        try {
            val j = JSONObject(data)
            when (ev) {
                "message" -> {
                    addMsg(j.toMsg())
                    refreshChats()
                }
                "message_edited" -> {
                    val m = j.toMsg()
                    messages = messages.map { if (it.id == m.id) m else it }
                    refreshChats()
                }
                "message_deleted" -> {
                    val id = j.getLong("id")
                    messages = messages.map { if (it.id == id) it.copy(text = null, deleted = true) else it }
                    refreshChats()
                }
                "chat" -> refreshChats()
            }
        } catch (e: Exception) {
            // игнорируем повреждённое событие
        }
    }

    private fun fail(e: ApiError) {
        if (e.status == 401 && api.token != null) logout() else error = e.message
    }

    fun requestCode(base: String, mail: String) {
        viewModelScope.launch {
            busy = true
            error = null
            try {
                val b = base.trim()
                api = Api(b, null)
                prefs.edit().putString("base", b).apply()
                email = mail.trim()
                val r = api.call("POST", "/auth/request", JSONObject().put("email", email))
                devCode = r.optString("devCode", "").ifEmpty { null }
                screen = Screen.Code
            } catch (e: ApiError) {
                error = e.message
            } finally {
                busy = false
            }
        }
    }

    fun verify(code: String) {
        viewModelScope.launch {
            busy = true
            error = null
            try {
                val body = JSONObject().put("email", email).put("code", code.trim()).put("device", Build.MODEL ?: "Android")
                val r = api.call("POST", "/auth/verify", body)
                val token = r.getString("token")
                api.token = token
                prefs.edit().putString("token", token).apply()
                me = r.getJSONObject("user").toUser()
                screen = if (r.optBoolean("needsProfile", false)) Screen.Profile else Screen.Chats
                start()
            } catch (e: ApiError) {
                error = e.message
            } finally {
                busy = false
            }
        }
    }

    fun saveProfile(name: String, username: String) {
        viewModelScope.launch {
            busy = true
            error = null
            try {
                val body = JSONObject().put("name", name.trim()).put("username", username.trim())
                me = api.call("PATCH", "/me", body).getJSONObject("user").toUser()
                screen = Screen.Chats
                loadChats()
            } catch (e: ApiError) {
                fail(e)
            } finally {
                busy = false
            }
        }
    }

    fun openChat(chat: Chat) {
        error = null
        messages = emptyList()
        screen = Screen.ChatView(chat)
        viewModelScope.launch {
            try {
                messages = api.call("GET", "/chats/${chat.id}/messages?limit=100")
                    .getJSONArray("messages").objects().map { it.toMsg() }
            } catch (e: ApiError) {
                fail(e)
            }
        }
    }

    fun send(chat: Chat, text: String, editingId: Long?) {
        viewModelScope.launch {
            try {
                if (editingId != null) {
                    val m = api.call("PATCH", "/messages/$editingId", JSONObject().put("text", text))
                        .getJSONObject("message").toMsg()
                    messages = messages.map { if (it.id == m.id) m else it }
                } else {
                    val m = api.call("POST", "/chats/${chat.id}/messages", JSONObject().put("text", text))
                        .getJSONObject("message").toMsg()
                    addMsg(m)
                }
                refreshChats()
            } catch (e: ApiError) {
                fail(e)
            }
        }
    }

    fun delete(msg: Msg) {
        viewModelScope.launch {
            try {
                api.call("DELETE", "/messages/${msg.id}")
                messages = messages.map { if (it.id == msg.id) it.copy(text = null, deleted = true) else it }
                refreshChats()
            } catch (e: ApiError) {
                fail(e)
            }
        }
    }

    fun search(q: String) {
        val s = q.trim()
        if (s.length < 2) {
            found = emptyList()
            return
        }
        viewModelScope.launch {
            try {
                found = api.call("GET", "/users/search?q=" + URLEncoder.encode(s, "UTF-8"))
                    .getJSONArray("users").objects().map { it.toUser() }
                    .filter { it.id != me?.id }
            } catch (e: ApiError) {
                fail(e)
            }
        }
    }

    fun startDirect(u: User) {
        viewModelScope.launch {
            try {
                val id = api.call("POST", "/chats/direct", JSONObject().put("userId", u.id)).getLong("chatId")
                loadChats()
                val chat = chats.firstOrNull { it.id == id }
                if (chat != null) openChat(chat) else screen = Screen.Chats
            } catch (e: ApiError) {
                fail(e)
            }
        }
    }

    fun logout() {
        eventsJob?.cancel()
        prefs.edit().remove("token").apply()
        api.token = null
        me = null
        chats = emptyList()
        messages = emptyList()
        error = null
        screen = Screen.Login
    }
}
