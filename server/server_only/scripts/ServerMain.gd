extends Node

var _ticker: Timer
var _spawned_initial: bool = false

func _ready() -> void:
    # In headless mode this just runs the ENet server started by EntryPoint.
    # Add a small heartbeat to print basic status.
    _ticker = Timer.new()
    _ticker.wait_time = 5.0
    _ticker.autostart = true
    _ticker.one_shot = false
    _ticker.timeout.connect(_on_tick)
    add_child(_ticker)
    print("[Server] Dedicated server running on port %d" % Network.current_port)
    if Network != null and Network.has_signal("admin_command"):
        Network.admin_command.connect(_on_admin_command)
    
    if OS.has_feature("linux") or OS.has_feature("macos"):
        get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)

func _on_tick() -> void:
    # Log connected peers count and usernames.
    var ids: Array = Network.players.keys()
    var names: Array[String] = []
    for id in ids:
        var info = Network.players[id]
        names.append(String(info["username"]))
    print("[Server] Peers: %d => %s" % [ids.size(), ", ".join(names)])
    if not _spawned_initial and Network.world != null:
        _spawn_initial_rocks(20)
        _spawned_initial = true

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
        print("[Server] Shutting down...")
        if Network != null:
            Network.shutdown()
        var tree := get_tree()
        if tree != null:
            tree.quit()

func _on_admin_command(sender_name: String, cmd: String, args: Array) -> void:
    if sender_name.to_lower() != "admin":
        return
    if cmd == "/bots":
        var count := 0
        if args.size() >= 1:
            count = int(args[0])
        if count <= 0:
            _announce("Usage: /bots <count>")
            return
        var bm := _get_or_create_bot_manager()
        if bm == null:
            _announce("BotManager could not be created.")
            return
        bm.call("set_bot_target_count", count)
        _announce("Spawning %d bots..." % count)
    elif cmd == "/removebots" or cmd == "/clearbots":
        var bm := _find_bot_manager()
        if bm == null:
            _announce("No BotManager active.")
            return
        bm.call_deferred("remove_all_bots")
        _announce("All bots removed.")
    elif cmd == "/rocks":
        var count := 0
        if args.size() >= 1:
            count = int(args[0])
        count = clamp(count, 1, 200)
        for i in range(count):
            var angle := randf() * TAU
            var radius := randf_range(3.0, 20.0)
            var pos := Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)
            Network.server_spawn_rock_at(pos)
        _announce("Spawned %d rocks" % count)
    elif cmd == "/help":
        var lines := [
            "/help - list admin commands",
            "/bots <count> - spawn bots",
            "/clearbots - remove all bots",
            "/rocks <count> - spawn rocks",
            "/quit - shutdown server"
        ]
        _send_private(sender_name, "Admin commands:\n" + "\n".join(lines))
    elif cmd == "/quit":
        _announce("Server shutting down in 3 seconds...")
        await get_tree().create_timer(3.0).timeout
        if Network != null:
            Network.shutdown()
        var tree := get_tree()
        if tree != null:
            tree.quit()

func _announce(text: String) -> void:
    Network.rpc("client_recv_chat", "SERVER", text)
    Network.client_recv_chat("SERVER", text)

func _find_bot_manager() -> Node:
    var root := get_tree().get_root()
    if root == null:
        return null
    for c in root.get_children():
        if c.get_script() != null and String(c.get_script().resource_path).ends_with("BotManager.gd"):
            return c
    return null

func _get_or_create_bot_manager() -> Node:
    var bm := _find_bot_manager()
    if bm != null:
        return bm
    var paths := ["res://server_only/scripts/BotManager.gd", "res://server/server_only/scripts/BotManager.gd"]
    var script: Script = null
    for p in paths:
        if ResourceLoader.exists(p):
            script = load(p)
            break
    if script == null:
        return null
    var node := Node.new()
    node.set_script(script)
    get_tree().get_root().add_child(node)
    return node

func _spawn_initial_rocks(n: int) -> void:
    for i in range(n):
        var angle := randf() * TAU
        var radius := randf_range(3.0, 15.0)
        var pos := Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)
        Network.server_spawn_rock_at(pos)

func _send_private(to_username: String, text: String) -> void:
    var target_id := -1
    for pid in Network.players.keys():
        var info = Network.players[pid]
        if String(info.get("username", "")).to_lower() == to_username.to_lower():
            target_id = int(pid)
            break
    if target_id == -1:
        return
    Network.rpc_id(target_id, "client_recv_chat", "SERVER", text)
    var self_id := Network.multiplayer.get_unique_id()
    if target_id == self_id:
        Network.client_recv_chat("SERVER", text)
