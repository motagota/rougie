extends Node

signal chat_received(username: String, text: String)

const DEFAULT_PORT: int = 8910
var current_port: int = DEFAULT_PORT

var username: String = ""
var toon_color: Color = Color.from_hsv(randf(), 0.7, 0.9)

var world: Node = null
var players := {} # peer_id -> {"username": String, "color": String}

var _spawn_queue: Array = []
var _remove_queue: Array = []
var _chat_queue: Array = []

func _ready() -> void:
    randomize()
    # Connect multiplayer tree signals
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    multiplayer.connected_to_server.connect(_on_connected_to_server)
    multiplayer.connection_failed.connect(_on_connection_failed)
    multiplayer.server_disconnected.connect(_on_server_disconnected)

func set_profile(name: String, color: Color) -> void:
    username = name.strip_edges()
    toon_color = color

func set_world(w: Node) -> void:
    world = w
    # Flush any queued events that arrived before the world loaded
    for s in _spawn_queue:
        (world as Node).call_deferred("spawn_player", s["peer_id"], s["username"], Color(s["color"]))
    _spawn_queue.clear()
    for r in _remove_queue:
        (world as Node).call_deferred("remove_player", r)
    _remove_queue.clear()
    for c in _chat_queue:
        emit_signal("chat_received", c["name"], c["text"])
    _chat_queue.clear()

func host(port: int = DEFAULT_PORT) -> void:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(port)
    if err != OK:
        push_error("Failed to host server: %s" % err)
        return
    multiplayer.multiplayer_peer = peer
    current_port = port
    # As server, consider self connected; register our player
    # Delay slightly to allow scenes to catch up
    call_deferred("_register_self_on_server")

func join(address: String, port: int = DEFAULT_PORT) -> void:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(address, port)
    if err != OK:
        push_error("Failed to connect: %s" % err)
        return
    multiplayer.multiplayer_peer = peer

func shutdown() -> void:
    if multiplayer.multiplayer_peer:
        multiplayer.multiplayer_peer.close()
    multiplayer.multiplayer_peer = null
    players.clear()

func _register_self_on_server() -> void:
    if multiplayer.multiplayer_peer == null:
        return
    # Whether host or client, use the same RPC path to server (ID 1)
    var color_html := toon_color.to_html(false)
    rpc_id(1, "server_register_player", username, color_html)

func _on_connected_to_server() -> void:
    # After connection, register profile with server
    _register_self_on_server()

func _on_connection_failed() -> void:
    push_warning("Connection failed")

func _on_server_disconnected() -> void:
    push_warning("Disconnected from server")

func _on_peer_connected(id: int) -> void:
    # Server can use this if needed; spawns are handled in server_register_player
    pass

func _on_peer_disconnected(id: int) -> void:
    if multiplayer.is_server():
        players.erase(id)
        # Broadcast removal to all clients
        rpc("client_remove_player", id)
        # Also remove on server locally
        client_remove_player(id)

@rpc("any_peer")
func server_register_player(reg_username: String, color_html: String) -> void:
    if not multiplayer.is_server():
        return
    var from_id := multiplayer.get_remote_sender_id()
    if from_id == 0:
        from_id = multiplayer.get_unique_id()
    players[from_id] = {"username": reg_username, "color": color_html}
    # Send existing players to the new peer first (including server and others)
    for pid in players.keys():
        if pid == from_id:
            continue
        var info = players[pid]
        rpc_id(from_id, "client_spawn_player", pid, info["username"], info["color"])
    # Now broadcast the new player to everyone else
    for pid in players.keys():
        if pid == from_id:
            continue
        rpc_id(pid, "client_spawn_player", from_id, reg_username, color_html)
    # Ensure server also spawns locally
    client_spawn_player(from_id, reg_username, color_html)

@rpc("any_peer")
func client_spawn_player(peer_id: int, reg_username: String, color_html: String) -> void:
    # Cache locally too so clients know names/colors for chat
    players[peer_id] = {"username": reg_username, "color": color_html}
    if world == null:
        _spawn_queue.append({"peer_id": peer_id, "username": reg_username, "color": color_html})
        return
    (world as Node).call_deferred("spawn_player", peer_id, reg_username, Color(color_html))

@rpc("any_peer")
func client_remove_player(peer_id: int) -> void:
    players.erase(peer_id)
    if world == null:
        _remove_queue.append(peer_id)
        return
    (world as Node).call_deferred("remove_player", peer_id)

func send_chat(text: String) -> void:
    text = text.strip_edges()
    if text.is_empty():
        return
    rpc_id(1, "server_send_chat", text)

@rpc("any_peer", "call_local")
func server_send_chat(text: String) -> void:
    if not multiplayer.is_server():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id == 0:
        sender_id = multiplayer.get_unique_id()
    var name := String(players[sender_id]["username"]) if players.has(sender_id) else "Unknown"
    # Broadcast to all clients
    rpc("client_recv_chat", name, text)
    # And handle on server locally
    client_recv_chat(name, text)

@rpc("any_peer")
func client_recv_chat(name: String, text: String) -> void:
    if world == null:
        _chat_queue.append({"name": name, "text": text})
        return
    emit_signal("chat_received", name, text)
