extends Node

var _ticker: Timer

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

func _on_tick() -> void:
    # Log connected peers count and usernames.
    var ids: Array = Network.players.keys()
    var names: Array[String] = []
    for id in ids:
        var info = Network.players[id]
        names.append(String(info["username"]))
    print("[Server] Peers: %d => %s" % [ids.size(), ", ".join(names)])

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        print("[Server] Shutting down...")
        Network.shutdown()
        get_tree().quit()
