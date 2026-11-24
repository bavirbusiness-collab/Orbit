package az.orbita.app

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.withContext
import org.json.JSONObject
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.HttpURLConnection
import java.net.URL

class ApiError(message: String, val status: Int = 0) : Exception(message)

data class User(val id: Long, val username: String?, val name: String, val bio: String)

data class Msg(
    val id: Long,
    val chatId: Long,
    val senderId: Long,
    val text: String?,
    val replyTo: Long?,
    val created: Long,
    val edited: Boolean,
    val deleted: Boolean,
)

data class Chat(val id: Long, val type: String, val title: String, val last: Msg?, val expires: Long?)

fun JSONObject.str(k: String): String? = if (isNull(k)) null else getString(k)
fun JSONObject.lng(k: String): Long? = if (isNull(k)) null else getLong(k)

fun JSONObject.toUser() = User(getLong("id"), str("username"), str("name") ?: "", str("bio") ?: "")

fun JSONObject.toMsg() = Msg(
    getLong("id"), getLong("chatId"), getLong("senderId"), str("text"), lng("replyTo"),
    getLong("created"), !isNull("edited"), optBoolean("deleted", false),
)

fun JSONObject.toChat() = Chat(
    getLong("id"), getString("type"), str("title") ?: "",
    if (isNull("last")) null else getJSONObject("last").toMsg(), lng("expires"),
)

class Api(var base: String, var token: String?) {

    private fun open(method: String, path: String): HttpURLConnection {
        val c = URL(base.trimEnd('/') + path).openConnection() as HttpURLConnection
        c.requestMethod = method
        c.connectTimeout = 10000
        c.readTimeout = 15000
        c.setRequestProperty("Content-Type", "application/json")
        val t = token
        if (t != null) c.setRequestProperty("Authorization", "Bearer $t")
        return c
    }

    suspend fun call(method: String, path: String, body: JSONObject? = null): JSONObject =
        withContext(Dispatchers.IO) {
            val c = open(method, path)
            try {
                if (body != null) {
                    c.doOutput = true
                    c.outputStream.use { it.write(body.toString().toByteArray(Charsets.UTF_8)) }
                }
                val code = c.responseCode
                val stream = if (code in 200..299) c.inputStream else c.errorStream
                val text = stream?.bufferedReader(Charsets.UTF_8)?.use { it.readText() } ?: "{}"
                val json = try {
                    JSONObject(text)
                } catch (e: Exception) {
                    JSONObject()
                }
                if (code !in 200..299) throw ApiError(json.optString("error", "Ошибка $code"), code)
                json
            } catch (e: ApiError) {
                throw e
            } catch (e: Exception) {
                throw ApiError("Нет связи с сервером", 0)
            } finally {
                c.disconnect()
            }
        }

    /** Держит соединение SSE открытым, пока корутина жива. Бросает исключение при обрыве. */
    suspend fun listen(onEvent: (String, String) -> Unit) {
        withContext(Dispatchers.IO) {
            val c = open("GET", "/events")
            c.readTimeout = 0
            val handle = coroutineContext[Job]?.invokeOnCompletion { c.disconnect() }
            try {
                val r = BufferedReader(InputStreamReader(c.inputStream, Charsets.UTF_8))
                var ev = "message"
                while (true) {
                    val line = r.readLine() ?: break
                    if (line.startsWith("event:")) {
                        ev = line.substring(6).trim()
                    } else if (line.startsWith("data:")) {
                        onEvent(ev, line.substring(5).trim())
                        ev = "message"
                    }
                }
            } finally {
                handle?.dispose()
                c.disconnect()
            }
        }
    }
}
