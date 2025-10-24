extends Node

func _ready() -> void:
    # Decide whether to run dedicated server or client based on user args.
    # Use args after `--` only to avoid engine flags.
    var args: PackedStringArray = OS.get_cmdline_user_args()
    var is_dedicated := false
    var port: int = Network.DEFAULT_PORT

    for a in args:
        var lower := a.to_lower()
        if lower == "--server" or lower == "--dedicated":
            is_dedicated = true
        elif lower.begins_with("--port="):
            var pstr := a.substr(7)
            if pstr.is_valid_int():
                port = int(pstr)

    if is_dedicated:
        # Host and load server scene. No world or UI needed.
        if Network.username.is_empty():
            Network.set_profile("Server", Color(1,1,1))
        Network.host(port)
        get_tree().change_scene_to_file("res://scenes/ServerMain.tscn")
    else:
        # Run standard client main menu.
        get_tree().change_scene_to_file("res://scenes/Main.tscn")
