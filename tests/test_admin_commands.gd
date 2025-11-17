extends Node

func run() -> Dictionary:
    var passed := 0
    var failed := 0
    var net_script := load("res://shared/scripts/Network.gd")
    var net: Node = Node.new()
    net.set_script(net_script)
    add_child(net)

    var tree: SceneTree = Engine.get_main_loop()
    await tree.process_frame
    net.start_server(1909)
    var sid: int = net.multiplayer.get_unique_id()
    net.players[sid] = {"username": "admin", "color": "#ffffff"}

    var srv_script := load("res://server/server_only/scripts/ServerMain.gd")
    var srv := Node.new()
    srv.set_script(srv_script)
    add_child(srv)
    await tree.process_frame

    var world_script := load("res://shared/scripts/World.gd")
    var world: Node3D = Node3D.new()
    world.set_script(world_script)
    add_child(world)
    net.set_world(world)

    net.client_recv_chat("admin", "/bots 2")
    await tree.process_frame
    await tree.create_timer(2.0).timeout
    var bm := _find_bot_manager_recursive(tree.get_root())
    if bm != null and bm.bot_count == 2:
        var deadline := Time.get_ticks_msec() + 5000
        while bm.bots.size() < 2 and Time.get_ticks_msec() < deadline:
            await tree.create_timer(0.2).timeout
        if bm.bots.size() == 2:
            passed += 1
        else:
            failed += 1
            print("FAIL: expected 2 bots, got %d" % bm.bots.size())
    else:
        failed += 1
        var count: int = bm.bot_count if bm != null else -1
        print("FAIL: BotManager absent or wrong count (count=%d)" % count)

    net.client_recv_chat("admin", "/clearbots")
    await tree.process_frame
    await tree.create_timer(0.5).timeout
    bm = _find_bot_manager_recursive(tree.get_root())
    if bm != null and bm.bots.size() == 0:
        passed += 1
    else:
        failed += 1
        var size: int = bm.bots.size() if bm != null else -1
        print("FAIL: clearbots did not remove all bots (size=%d)" % size)

    var got_help := false
    net.chat_received.connect(func(name: String, text: String):
        if name == "SERVER" and text.begins_with("Admin commands"):
            got_help = true
    )
    net.client_recv_chat("admin", "/help")
    await tree.process_frame
    await tree.create_timer(0.2).timeout
    if got_help:
        passed += 1
    else:
        failed += 1
        print("FAIL: help did not announce commands")

    return {"passed": passed, "failed": failed}

func _find_bot_manager_recursive(node: Node) -> Node:
    if node == null:
        return null
    var script: Script = node.get_script()
    if script != null and String(script.resource_path).ends_with("BotManager.gd"):
        return node
    for c in node.get_children():
        var found := _find_bot_manager_recursive(c)
        if found != null:
            return found
    return null