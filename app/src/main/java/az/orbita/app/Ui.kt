package az.orbita.app

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.text.input.KeyboardType
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private val avatarColors = listOf(
    Color(0xFF3B4CCA), Color(0xFF0F8F7E), Color(0xFFC2410C), Color(0xFF7C3AED), Color(0xFF5A6280),
)

private fun hhmm(t: Long): String = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(t))

@Composable
fun App(vm: AppVm) {
    val s = vm.screen
    BackHandler(enabled = s is Screen.ChatView || s is Screen.NewChat || s is Screen.Code) {
        vm.error = null
        vm.screen = if (s is Screen.Code) Screen.Login else Screen.Chats
    }
    when (s) {
        is Screen.Login -> LoginScreen(vm)
        is Screen.Code -> CodeScreen(vm)
        is Screen.Profile -> ProfileScreen(vm)
        is Screen.Chats -> ChatsScreen(vm)
        is Screen.NewChat -> NewChatScreen(vm)
        is Screen.ChatView -> ChatScreen(vm, s.chat)
    }
}

@Composable
private fun ErrorText(vm: AppVm) {
    val e = vm.error
    if (e != null) {
        Text(e, color = MaterialTheme.colorScheme.error, modifier = Modifier.padding(vertical = 8.dp))
    }
}

@Composable
private fun Avatar(title: String, size: Int = 48) {
    val color = avatarColors[(title.hashCode() and 0x7fffffff) % avatarColors.size]
    Box(
        modifier = Modifier.size(size.dp).clip(CircleShape).background(color),
        contentAlignment = Alignment.Center,
    ) {
        Text(title.take(1).uppercase(), color = Color.White, fontWeight = FontWeight.SemiBold)
    }
}

@Composable
fun LoginScreen(vm: AppVm) {
    var base by remember { mutableStateOf(vm.api.base) }
    var mail by remember { mutableStateOf(vm.email) }
    Column(
        Modifier.fillMaxSize().statusBarsPadding().padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text("Орбита", fontSize = 36.sp, fontWeight = FontWeight.Bold)
        Text("Чаты, сообщества и видео в одном месте", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(32.dp))
        OutlinedTextField(
            value = mail, onValueChange = { mail = it }, label = { Text("E-mail") }, singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Email),
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = base, onValueChange = { base = it }, label = { Text("Адрес сервера") }, singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Uri),
        )
        ErrorText(vm)
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = { vm.requestCode(base, mail) },
            enabled = !vm.busy && mail.contains("@") && base.isNotBlank(),
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text(if (vm.busy) "Отправка…" else "Получить код") }
    }
}

@Composable
fun CodeScreen(vm: AppVm) {
    var code by remember { mutableStateOf("") }
    Column(
        Modifier.fillMaxSize().statusBarsPadding().padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text("Введите код", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text("Код отправлен на ${vm.email}", color = MaterialTheme.colorScheme.onSurfaceVariant)
        val dev = vm.devCode
        if (dev != null) {
            Text("Тестовый режим, код: $dev", color = MaterialTheme.colorScheme.primary, modifier = Modifier.padding(top = 8.dp))
        }
        Spacer(Modifier.height(24.dp))
        OutlinedTextField(
            value = code, onValueChange = { if (it.length <= 6) code = it.filter { c -> c.isDigit() } },
            label = { Text("6 цифр") }, singleLine = true, modifier = Modifier.fillMaxWidth(),
            keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number),
        )
        ErrorText(vm)
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = { vm.verify(code) }, enabled = !vm.busy && code.length == 6,
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text(if (vm.busy) "Проверка…" else "Войти") }
        TextButton(onClick = { vm.error = null; vm.screen = Screen.Login }) { Text("Другой e-mail") }
    }
}

@Composable
fun ProfileScreen(vm: AppVm) {
    var name by remember { mutableStateOf(vm.me?.name ?: "") }
    var username by remember { mutableStateOf(vm.me?.username ?: "") }
    Column(
        Modifier.fillMaxSize().statusBarsPadding().padding(24.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        Text("Ваш профиль", fontSize = 28.sp, fontWeight = FontWeight.Bold)
        Text("Имя увидят другие, по @username вас смогут найти", color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(24.dp))
        OutlinedTextField(
            value = name, onValueChange = { name = it }, label = { Text("Имя") }, singleLine = true,
            modifier = Modifier.fillMaxWidth(),
        )
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(
            value = username, onValueChange = { username = it }, label = { Text("@username") }, singleLine = true,
            modifier = Modifier.fillMaxWidth(),
            supportingText = { Text("Латиница, цифры и _, от 3 символов") },
        )
        ErrorText(vm)
        Spacer(Modifier.height(8.dp))
        Button(
            onClick = { vm.saveProfile(name, username) },
            enabled = !vm.busy && name.isNotBlank() && username.length >= 3,
            modifier = Modifier.fillMaxWidth().height(52.dp),
        ) { Text("Продолжить") }
    }
}

@Composable
fun ChatsScreen(vm: AppVm) {
    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Row(
            Modifier.fillMaxWidth().padding(start = 20.dp, end = 8.dp, top = 12.dp, bottom = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Чаты", fontSize = 26.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f))
            TextButton(onClick = { vm.found = emptyList(); vm.screen = Screen.NewChat }) { Text("Новый чат") }
            TextButton(onClick = { vm.logout() }) { Text("Выйти") }
        }
        ErrorText(vm)
        if (vm.chats.isEmpty()) {
            Text(
                "Чатов пока нет. Нажмите «Новый чат» и найдите человека по @username.",
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(20.dp),
            )
        }
        LazyColumn(Modifier.fillMaxSize()) {
            items(vm.chats, key = { it.id }) { c ->
                Row(
                    Modifier.fillMaxWidth().clickable { vm.openChat(c) }.padding(horizontal = 20.dp, vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Avatar(c.title)
                    Column(Modifier.weight(1f)) {
                        Row {
                            Text(c.title, fontWeight = FontWeight.SemiBold, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
                            val last = c.last
                            if (last != null) {
                                Text(hhmm(last.created), fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                        val last = c.last
                        val preview = when {
                            last == null -> "Нет сообщений"
                            last.deleted -> "Сообщение удалено"
                            else -> last.text ?: ""
                        }
                        Text(preview, maxLines = 1, overflow = TextOverflow.Ellipsis, color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@Composable
fun NewChatScreen(vm: AppVm) {
    var q by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().statusBarsPadding().padding(horizontal = 20.dp)) {
        Row(Modifier.padding(top = 12.dp), verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { vm.screen = Screen.Chats }) { Text("Назад") }
            Text("Новый чат", fontSize = 22.sp, fontWeight = FontWeight.Bold)
        }
        OutlinedTextField(
            value = q, onValueChange = { q = it; vm.search(it) }, label = { Text("Имя или @username") },
            singleLine = true, modifier = Modifier.fillMaxWidth(),
        )
        ErrorText(vm)
        LazyColumn(Modifier.fillMaxSize()) {
            items(vm.found, key = { it.id }) { u ->
                Row(
                    Modifier.fillMaxWidth().clickable { vm.startDirect(u) }.padding(vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(12.dp),
                ) {
                    Avatar(u.name)
                    Column {
                        Text(u.name, fontWeight = FontWeight.SemiBold)
                        Text("@" + (u.username ?: ""), color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                }
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
fun ChatScreen(vm: AppVm, chat: Chat) {
    val listState = rememberLazyListState()
    var draft by remember { mutableStateOf("") }
    var editing by remember { mutableStateOf<Msg?>(null) }
    var menuMsg by remember { mutableStateOf<Msg?>(null) }
    val myId = vm.me?.id

    LaunchedEffect(vm.messages.size) {
        if (vm.messages.isNotEmpty()) listState.animateScrollToItem(vm.messages.lastIndex)
    }

    Column(Modifier.fillMaxSize().statusBarsPadding().imePadding()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 8.dp, vertical = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            TextButton(onClick = { vm.screen = Screen.Chats }) { Text("Назад") }
            Avatar(chat.title, 36)
            Spacer(Modifier.size(10.dp))
            Text(chat.title, fontWeight = FontWeight.SemiBold, fontSize = 17.sp, maxLines = 1, overflow = TextOverflow.Ellipsis)
        }
        ErrorText(vm)
        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).fillMaxWidth().padding(horizontal = 12.dp),
            verticalArrangement = Arrangement.spacedBy(6.dp),
        ) {
            items(vm.messages, key = { it.id }) { m ->
                val mine = m.senderId == myId
                Row(Modifier.fillMaxWidth(), horizontalArrangement = if (mine) Arrangement.End else Arrangement.Start) {
                    Column(
                        Modifier
                            .widthIn(max = 280.dp)
                            .clip(RoundedCornerShape(16.dp))
                            .background(if (mine) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.surfaceVariant)
                            .combinedClickable(onClick = {}, onLongClick = { if (mine && !m.deleted) menuMsg = m })
                            .padding(horizontal = 12.dp, vertical = 8.dp),
                    ) {
                        val textColor = if (mine) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant
                        if (m.deleted) {
                            Text("Сообщение удалено", color = textColor, fontStyle = FontStyle.Italic)
                        } else {
                            Text(m.text ?: "", color = textColor)
                        }
                        Text(
                            hhmm(m.created) + if (m.edited && !m.deleted) " · изм." else "",
                            fontSize = 11.sp, color = textColor.copy(alpha = 0.7f),
                        )
                    }
                }
            }
        }
        if (editing != null) {
            Text("Редактирование сообщения", color = MaterialTheme.colorScheme.primary, fontSize = 13.sp, modifier = Modifier.padding(horizontal = 16.dp))
        }
        Row(Modifier.fillMaxWidth().padding(8.dp), verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = draft, onValueChange = { draft = it }, placeholder = { Text("Сообщение") },
                modifier = Modifier.weight(1f), maxLines = 4,
            )
            TextButton(onClick = {
                val t = draft.trim()
                if (t.isNotEmpty()) {
                    vm.send(chat, t, editing?.id)
                    draft = ""
                    editing = null
                }
            }) { Text(if (editing != null) "Сохранить" else "Отправить") }
        }
    }

    val sel = menuMsg
    if (sel != null) {
        AlertDialog(
            onDismissRequest = { menuMsg = null },
            title = { Text("Сообщение") },
            confirmButton = {
                TextButton(onClick = { editing = sel; draft = sel.text ?: ""; menuMsg = null }) { Text("Изменить") }
            },
            dismissButton = {
                TextButton(onClick = { vm.delete(sel); menuMsg = null }) { Text("Удалить") }
            },
        )
    }
}
