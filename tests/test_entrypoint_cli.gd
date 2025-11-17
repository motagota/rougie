extends Node

func run() -> Dictionary:
    var passed := 0
    var failed := 0
    var ep_script := load("res://shared/scripts/EntryPoint.gd")
    var ep: Node = Node.new()
    ep.set_script(ep_script)

    var args: PackedStringArray = PackedStringArray(["--bots", "--bot-count", "5", "--bot-spawn-interval", "1.5", "--bot-chat-min", "2", "--bot-chat-max", "8"]) 
    var cfg: Dictionary = ep._parse_bot_cli(args)
    if cfg["enabled"] and cfg["bot_count"] == 5 and abs(cfg["spawn_interval"] - 1.5) < 0.001 and abs(cfg["chat_interval_min"] - 2.0) < 0.001 and abs(cfg["chat_interval_max"] - 8.0) < 0.001:
        passed += 1
    else:
        failed += 1
        print("FAIL: _parse_bot_cli config mismatch: %s" % [cfg])

    args = PackedStringArray(["--bots", "--bot-chat-min", "10", "--bot-chat-max", "5"]) 
    cfg = ep._parse_bot_cli(args)
    if cfg["enabled"] and cfg["chat_interval_min"] == 5.0 and cfg["chat_interval_max"] == 10.0:
        passed += 1
    else:
        failed += 1
        print("FAIL: chat min/max swap not corrected: %s" % [cfg])

    return {"passed": passed, "failed": failed}