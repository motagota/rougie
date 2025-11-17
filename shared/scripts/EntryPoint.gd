extends Node
@onready var network := preload("res://shared/scripts/Network.gd").new()

func _ready() -> void:
    var args = OS.get_cmdline_args()
    print("args %s" % [args])
    var is_server = "--server" in args
    var port: int = Network.DEFAULT_PORT
    var name := "guest_%d" % (randi() % 10000)   
    var bot_cli := _parse_bot_cli(args)

    for i in range(args.size()):
        if args[i] == "--port" and i + 1 < args.size():
            port = int(args[i + 1])
        if args[i] == "--name" and i + 1 < args.size():
            name = args[i + 1]
    add_child(network)

    if is_server:       
        network.start_server(port)
        if bot_cli["enabled"]:
            var count = bot_cli["bot_count"]
            if count != null and int(count) > 0:
                network.admin_command.emit("admin", "/bots", [int(count)])
        var srv_script: Script = null
        var paths := ["res://server_only/scripts/ServerMain.gd", "res://server/server_only/scripts/ServerMain.gd"]
        for p in paths:
            if ResourceLoader.exists(p):
                srv_script = load(p)
                break
        if srv_script != null:
            var srv := Node.new()
            srv.set_script(srv_script)
            add_child(srv)
        
        #if Network.username.is_empty():
        #    Network.set_profile("Server", Color(1,1,1))
        #Network.host(port)
        #get_tree().change_scene_to_file("res://scenes/ServerMain.tscn")
    else:
        Network.set_profile(name, Color.from_hsv(randf(), 0.7, 0.9))
        network.start_client("127.0.0.1", port , name)
        #get_tree().change_scene_to_file("res://scenes/Main.tscn")
        get_tree().change_scene_to_file("res://shared/scenes/World.tscn")

func _parse_bot_cli(args: PackedStringArray) -> Dictionary:
    var config := {
        "enabled": false,
        "bot_count": null,
        "spawn_interval": null,
        "chat_interval_min": null,
        "chat_interval_max": null,
    }
    for i in range(args.size()):
        var arg := args[i]
        if arg == "--bots":
            config["enabled"] = true
        elif arg == "--bot-count" and i + 1 < args.size():
            config["enabled"] = true
            config["bot_count"] = max(1, int(args[i + 1]))
        elif arg == "--bot-spawn-interval" and i + 1 < args.size():
            config["enabled"] = true
            config["spawn_interval"] = max(0.1, float(args[i + 1]))
        elif arg == "--bot-chat-min" and i + 1 < args.size():
            config["enabled"] = true
            config["chat_interval_min"] = max(0.5, float(args[i + 1]))
        elif arg == "--bot-chat-max" and i + 1 < args.size():
            config["enabled"] = true
            config["chat_interval_max"] = max(0.5, float(args[i + 1]))
    var has_min := config["chat_interval_min"] != null
    var has_max := config["chat_interval_max"] != null
    if has_min and has_max and config["chat_interval_min"] > config["chat_interval_max"]:
        var tmp : float = config["chat_interval_min"]
        config["chat_interval_min"] = config["chat_interval_max"]
        config["chat_interval_max"] = tmp
    return config
