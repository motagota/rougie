extends Node

func run() -> Dictionary:
    var passed := 0
    var failed := 0

    var net_script := load("res://shared/scripts/Network.gd")
    var net: Node = Node.new()
    net.set_script(net_script)
    add_child(net)

    var world_script := load("res://shared/scripts/World.gd")
    var world: Node3D = Node3D.new()
    world.set_script(world_script)
    add_child(world)
    net.call("set_world", world)

    var tree: SceneTree = Engine.get_main_loop()
    await tree.process_frame
    net.call("start_server", 1909)

    var sid: int = net.multiplayer.get_unique_id()
    net.players[sid] = {"username": "tester", "color": "#ffffff"}

    var p_scene := load("res://shared/scenes/Player.tscn")
    var p: CharacterBody3D = p_scene.instantiate()
    world.add_child(p)
    world.players[sid] = p
    p.global_transform.origin = Vector3(0, 1, 0)

    var item_id: int = int(net.call("server_spawn_rock_at", Vector3(1.5, 1, 0)))
    await tree.process_frame

    net.rpc_id(1, "server_request_pick_item", int(item_id))
    await tree.process_frame
    var inv: Array = net.players[sid].get("inventory", [])
    if inv.size() == 1 and int(inv[0]["id"]) == int(item_id):
        passed += 1
    else:
        failed += 1
        print("FAIL: pick did not add to inventory")

    var drop_pos := Vector3(3, 1, 0)
    net.rpc_id(1, "server_request_drop_item", int(item_id), drop_pos)
    await tree.process_frame
    if world.items.has(int(item_id)):
        var node: Node3D = world.items[int(item_id)]
        if node.global_transform.origin.distance_to(drop_pos) < 0.01:
            passed += 1
        else:
            failed += 1
            print("FAIL: drop position mismatch")
    else:
        failed += 1
        print("FAIL: drop did not spawn item")

    var far_item: int = int(net.call("server_spawn_rock_at", Vector3(50, 1, 0)))
    await tree.process_frame
    var inv_before: Array = net.players[sid].get("inventory", []).duplicate()
    net.rpc_id(1, "server_request_pick_item", int(far_item))
    await tree.process_frame
    var inv_after: Array = net.players[sid].get("inventory", [])
    if inv_after.size() == inv_before.size():
        passed += 1
    else:
        failed += 1
        print("FAIL: far pick should be rejected")

    return {"passed": passed, "failed": failed}