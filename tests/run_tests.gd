extends SceneTree

var failures := 0
var passed := 0

func _initialize() -> void:
    print("*** Running unit tests ***")
    await _run_test_module("res://tests/test_entrypoint_cli.gd")
    await _run_test_module("res://tests/test_admin_commands.gd")
    await _run_test_module("res://tests/test_inventory.gd")
    print("*** Tests complete: %d passed, %d failed ***" % [passed, failures])
    if failures > 0:
        quit(1)
    else:
        quit(0)

func _run_test_module(path: String) -> void:
    var script := load(path)
    if script == null:
        print("FAIL: could not load %s" % path)
        failures += 1
        return
    var node: Node = Node.new()
    node.set_script(script)
    get_root().add_child(node)
    var result: Dictionary = await node.run()
    passed += result.get("passed", 0)
    failures += result.get("failed", 0)
    node.queue_free()