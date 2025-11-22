extends Node

signal chat_received(username: String, text: String)
signal inventory_updated(peer_id: int, inv: Array)
signal admin_command(sender_name: String, cmd: String, args: Array)

const DEFAULT_PORT: int = 8910
var current_port: int = DEFAULT_PORT

var username: String = ""
var toon_color: Color = Color.from_hsv(randf(), 0.7, 0.9)

var world: Node = null
var players := {} # peer_id -> {"username": String, "color": String}
var items := {} # item_id -> {"type": String, "node": Node}
var _next_item_id: int = 10000

var _spawn_queue: Array = []
var _remove_queue: Array = []
var _chat_queue: Array = []
var _transform_queue: Dictionary = {}
var _registration_sent: bool = false 
var _item_spawn_queue: Array = []
var _item_remove_queue: Array = []
var _initial_items_spawned: bool = false

func _ready() -> void:
    randomize()
    # Connect multiplayer tree signals
    if not multiplayer.connected_to_server.is_connected(_on_connected_to_server):
        multiplayer.connected_to_server.connect(_on_connected_to_server)
    if not multiplayer.connection_failed.is_connected(_on_connection_failed):
        multiplayer.connection_failed.connect(_on_connection_failed)
    if not multiplayer.server_disconnected.is_connected(_on_server_disconnected):
        multiplayer.server_disconnected.connect(_on_server_disconnected)

func start_server(port:int):
    print("[ServerMain] start server")
    var peer = ENetMultiplayerPeer.new()
    peer.create_server(port)
    multiplayer.multiplayer_peer = peer
    print("Server started on port %d" %port)
    multiplayer.peer_connected.connect(_on_peer_connected)
    multiplayer.peer_disconnected.connect(_on_peer_disconnected)
    if not _initial_items_spawned:
        _spawn_default_rocks(24)
    
func start_client(host:String, port:int, name:String):

    set_profile(name, Color.from_hsv(randf(), 0.7, 0.9))
    var peer = ENetMultiplayerPeer.new()
    peer.create_client(host, port)
    multiplayer.multiplayer_peer = peer
   
@rpc("any_peer")
func _rpc_join(name:String):
    print("[_RPC_JOIN] %s" %name)
    if multiplayer.is_server():
        print("join server")
        var id = multiplayer.get_remote_sender_id()
        rpc_id(id, "_rpc_spawn", id, name)
        for p_id in players:
            var p = players[p_id]
            rpc_id(id, "_rpc_spawn", p_id, p.name)
    else:
        pass
        
@rpc("any_peer")
func _rpc_spawn(id:int, name:String):
    print("[_rpc_spawn ] name:%s" % name)
    if players.has(id): return
    var p = preload("res://shared/scenes/Player.tscn").instantiate()
    p.set_name("Player_%d" % id)
    p.username = name
    get_tree().root.get_node("World").add_child(p)
    players[id] = { "username": name, "node": p }

@rpc("any_peer")
func _rpc_despawn(id:int):
    if not players.has(id): return
    players[id].node.queue_free()
    players.erase(id)

@rpc("any_peer")
func _rpc_set_transform(id:int, xform:Transform3D):
    if players.has(id) and not players[id].node.is_multiplayer_authority():
        players[id].node.transform = xform

@rpc("any_peer")
func _rpc_chat(name:String, msg:String):
    if multiplayer.is_server():
        rpc("_rpc_chat", name, msg)

func _on_peer_connected(id:int):
    print("Peer joined: %d" % id)
    if not _initial_items_spawned:
        _spawn_default_rocks(24)

func _on_peer_disconnected(id:int):
    print("Peer left: %d" % id)
    rpc("_rpc_despawn", id)
    players.erase(id)
       
                          
func set_profile(name: String, color: Color) -> void:
    username = name.strip_edges()
    toon_color = color
    print("[Network] Profile set: username=%s, color=%s" % [username, color])

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
    var pending := _transform_queue.keys()
    for peer_id in pending:
        var xform: Transform3D = _transform_queue[peer_id]
        _transform_queue.erase(peer_id)
        _apply_transform_to_world(peer_id, xform)
    for it in _item_spawn_queue:
        (world as Node).call_deferred("spawn_item", it["nid"], it["type"], it["pos"], it["node"]) 
    _item_spawn_queue.clear()
    for rid in _item_remove_queue:
        (world as Node).call_deferred("remove_item", rid)
    _item_remove_queue.clear()

func host(port: int = DEFAULT_PORT) -> void:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(port)
    if err != OK:
        push_error("Failed to host server: %s" % err)
        return
    multiplayer.multiplayer_peer = peer
    current_port = port

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
    if _registration_sent:
        print("[Network] Registration already sent, skipping")
        return        
    print("[Network] _register_self_on_server called")
    if multiplayer.multiplayer_peer == null:
        print("ERROR: multiplayer_peer is null!")
        return
        
    if username.is_empty():
        print("ERROR: username is empty!")
        return   
    _registration_sent = true     
    # Whether host or client, use the same RPC path to server (ID 1)
    var color_html := toon_color.to_html(false)
    print("Sending registration: username=%s, color=%s" % [username, color_html])
    
    if multiplayer.is_server():   
        var my_id := multiplayer.get_unique_id()
        players[my_id] = {"username": username, "color": color_html}
        client_spawn_player(my_id, username, color_html)
    else:
        rpc_id(1, "server_register_player", username, color_html)

func _on_connected_to_server() -> void:
    print("Connected to server! Registering...")
    call_deferred("_register_self_on_server")

func _on_connection_failed() -> void:
    push_warning("Connection failed")
    _registration_sent = false


func _on_server_disconnected() -> void:
    push_warning("Disconnected from server")
    _registration_sent = false

@rpc("any_peer","call_local", "reliable")
func server_register_player(reg_username: String, color_html: String) -> void:
    print("[server_register_player] %s %s"%[reg_username, color_html])
    if not multiplayer.is_server():
        return
    var from_id := multiplayer.get_remote_sender_id()
    if from_id == 0:
        from_id = multiplayer.get_unique_id()
    players[from_id] = {"username": reg_username, "color": color_html}
    # Send full roster (including self) to the new peer
    for pid in players.keys():
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
    players[peer_id] = {"username": reg_username, "color": color_html}
    if world == null:
        _spawn_queue.append({"peer_id": peer_id, "username": reg_username, "color": color_html})
        return
    (world as Node).call_deferred("spawn_player", peer_id, reg_username, Color(color_html))

@rpc("any_peer")
func client_remove_player(peer_id: int) -> void:
    players.erase(peer_id)
    if _transform_queue.has(peer_id):
        _transform_queue.erase(peer_id)
    if world == null:
        _remove_queue.append(peer_id)
        return
    (world as Node).call_deferred("remove_player", peer_id)

@rpc("any_peer", "call_local", "unreliable")
func client_update_player_transform(peer_id: int, xform: Transform3D) -> void:
    _apply_transform_to_world(peer_id, xform)

@rpc("any_peer", "call_local", "unreliable")
func server_receive_player_transform(xform: Transform3D) -> void:
    if not multiplayer.is_server():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id == 0:
        sender_id = multiplayer.get_unique_id()
    rpc("client_update_player_transform", sender_id, xform)

func server_broadcast_transform(peer_id: int, xform: Transform3D) -> void:
    if not multiplayer.is_server():
        return
    rpc("client_update_player_transform", peer_id, xform)

func _apply_transform_to_world(peer_id: int, xform: Transform3D) -> void:
    if world == null or not is_instance_valid(world):
        _transform_queue[peer_id] = xform
        return
    if not world.has_method("network_apply_transform"):
        _transform_queue[peer_id] = xform
        return
    var applied: bool = bool(world.call("network_apply_transform", peer_id, xform))
    if not applied:
        _transform_queue[peer_id] = xform

func notify_player_spawned(peer_id: int) -> void:
    if not _transform_queue.has(peer_id):
        return
    var xform: Transform3D = _transform_queue[peer_id]
    _transform_queue.erase(peer_id)
    _apply_transform_to_world(peer_id, xform)

func send_chat(text: String) -> void:
    text = text.strip_edges()
    if text.is_empty():
        return
    rpc_id(1, "server_send_chat", text)

@rpc("any_peer", "call_local")
func server_send_chat(text: String) -> void:
    print("[server_send_chat] %s" % text)
    if not multiplayer.is_server():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id == 0:
        sender_id = multiplayer.get_unique_id()
    var name: String= players[sender_id].get("username","unknown")
    print("[server_send_chat] name is %s " % name)
    var t := text.strip_edges()
    if t.begins_with("/"):
        var parts := t.split(" ", false)
        var cmd := parts[0].to_lower()
        var args: Array = parts.slice(1, parts.size()) if parts.size() > 1 else []
        admin_command.emit(name, cmd, args)
        return
    rpc("client_recv_chat", name, text)
    client_recv_chat(name, text)

@rpc("any_peer", "call_local")
func client_recv_chat(name: String, text: String) -> void:
    if multiplayer.is_server() and text.strip_edges() == "/quit":
        print("[Server] Shutdown command received from %s" % name)
        rpc("client_recv_chat", "SERVER", "Server shutting down in 3 seconds...")
        await get_tree().create_timer(3.0).timeout
        Network.shutdown()
        get_tree().quit()
        return
    
    # Server-side admin chat commands (parsed and emitted to server-only handlers)
    if multiplayer.is_server() and text.begins_with("/"):
        var raw := text.strip_edges()
        var parts := raw.split(" ", false)
        var cmd := parts[0].to_lower()
        var args: Array = parts.slice(1, parts.size()) if parts.size() > 1 else []
        admin_command.emit(name, cmd, args)
        return
    
    if world == null:
        _chat_queue.append({"name": name, "text": text})
        return
    emit_signal("chat_received", name, text)

@rpc("any_peer", "call_local", "reliable")
func server_request_pick_item(item_id: int) -> void:
    if not multiplayer.is_server():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id == 0:
        sender_id = multiplayer.get_unique_id()
    if not items.has(item_id):
        return
    if world == null:
        return
    if not world.has_method("can_pick_item"):
        return
    var ok: bool = bool(world.call("can_pick_item", sender_id, item_id))
    if not ok:
        return
    var info: Dictionary = items[item_id]
    client_remove_item(item_id)
    rpc("client_remove_item", item_id)
    items.erase(item_id)
    _ensure_player_inventory(sender_id)
    var inv: Array = players[sender_id]["inventory"]
    inv.append({"id": item_id, "type": String(info["type"])})
    rpc("client_update_player_inventory", sender_id, inv)

@rpc("any_peer", "call_local", "reliable")
func server_request_drop_item(item_id: int, pos: Vector3) -> void:
    if not multiplayer.is_server():
        return
    var sender_id := multiplayer.get_remote_sender_id()
    if sender_id == 0:
        sender_id = multiplayer.get_unique_id()
    _ensure_player_inventory(sender_id)
    var inv: Array = players[sender_id]["inventory"]
    var idx: int = -1
    var type_name: String = ""
    for i in range(inv.size()):
        var it: Dictionary = inv[i]
        if int(it.get("id", -1)) == item_id:
            idx = i
            type_name = String(it.get("type", ""))
            break
    if idx == -1:
        return
    inv.remove_at(idx)
    rpc("client_update_player_inventory", sender_id, inv)
    var nid := item_id
    _spawn_item_on_server(nid, type_name, pos)

func _ensure_player_inventory(peer_id: int) -> void:
    if not players.has(peer_id):
        players[peer_id] = {"username": "", "color": "#ffffff"}
    if not players[peer_id].has("inventory"):
        players[peer_id]["inventory"] = []

func server_spawn_rock_at(pos: Vector3) -> int:
    if not multiplayer.is_server():
        return -1
    var nid := _next_item_id
    _next_item_id += 1
    _spawn_item_on_server(nid, "rock", pos)
    return nid

func _spawn_item_on_server(nid: int, type_name: String, pos: Vector3) -> void:
    var node: Node = null
    if type_name == "rock":
        node = load("res://shared/scripts/Rock.gd").new()
    if node == null:
        return
    items[nid] = {"type": type_name, "node": node}
    rpc("client_spawn_item", nid, type_name, pos)
    if world != null:
        world.call_deferred("spawn_item", nid, type_name, pos, node)

@rpc("any_peer")
func client_spawn_item(nid: int, type_name: String, pos: Vector3) -> void:
    var node: Node = null
    if type_name == "rock":
        node = load("res://shared/scripts/Rock.gd").new()
    if node == null:
        return
    items[nid] = {"type": type_name, "node": node}
    if world == null:
        _item_spawn_queue.append({"nid": nid, "type": type_name, "pos": pos, "node": node})
    else:
        world.call_deferred("spawn_item", nid, type_name, pos, node)

@rpc("any_peer")
func client_remove_item(nid: int) -> void:
    if items.has(nid):
        items.erase(nid)
    if world == null:
        _item_remove_queue.append(nid)
    else:
        world.call_deferred("remove_item", nid)

@rpc("any_peer")
func client_update_player_inventory(peer_id: int, inv: Array) -> void:
    if not players.has(peer_id):
        players[peer_id] = {"username": "", "color": "#ffffff"}
    players[peer_id]["inventory"] = inv
    inventory_updated.emit(peer_id, inv)

func _spawn_default_rocks(count: int) -> void:
    if _initial_items_spawned:
        return
    for i in range(count):
        var angle := randf() * TAU
        var radius := randf_range(4.0, 18.0)
        var pos := Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)
        server_spawn_rock_at(pos)
    _initial_items_spawned = true
