extends Node

@export var bot_count: int =3
@export var spawn_interval: float = 2.0
@export var chat_interval_min: float = 10.0
@export var chat_interval_max: float = 30


var bot_names: Array[String] = [
    "Wanderer","Explorer","Nomad","Roamer",
    "Scout","Ranger","Seeker","Drifter","Pilgrim"]
    
var bot_messages: Array[String] = [
    "Hello everyone!",
    "Nice weather today",
    "Anyone seen any good loot?",
    "This place is huge",
    "Where is everyone?",
    "Just passing through",
    "Beautiful scenery here",
    "Anyone want to team up",
    "I love exploring",
    "What's that over there?",
    "Time for adventures!",
    "The ground feels nice",
    "walking simulator engaged",
    "*waves*",
    "Anyone else here?"
    
]

var bots: Array = []
var _spawn_timer: Timer
var _world: Node3D = null


func _ready() -> void:
    if not multiplayer.is_server():
        queue_free()
        return
        
    print("[BotManager] Starting bot manager with %d bots" % bot_count)
    await get_tree().create_timer(1.0).timeout
    _world = _resolve_world()
    
    _spawn_timer = Timer.new()
    _spawn_timer.wait_time = spawn_interval
    _spawn_timer.one_shot = false
    _spawn_timer.timeout.connect(_spawn_next_bot)
    add_child(_spawn_timer)
    _spawn_timer.start()
    
func _spawn_next_bot()->void:
    if bots.size() >= bot_count:
        _spawn_timer.stop()
        return
    
    var bot_name := bot_names[randi() % bot_names.size()] + str(bots.size()+1)
    var bot_color := Color.from_hsv(randf(), 0.6, 0.8)
    var bot_id:= -(bots.size() + 1000)
    
    var color_hex := bot_color.to_html(false)
    Network.client_spawn_player(bot_id, bot_name, color_hex)
    Network.rpc("client_spawn_player", bot_id, bot_name, color_hex)
    
    var bot :={
        "id": bot_id,
        "name": bot_name,
        "color": bot_color,
        "position": _initial_spawn_position(),
        "target": Vector3.ZERO,
        "speed": randf_range(2.0,4.0),
        "rotation": 0.0,
        "next_chat_time": Time.get_ticks_msec()/ 1000.0 + randf_range(chat_interval_min, chat_interval_max)
    }
    
    bots.append(bot)
    await get_tree().process_frame
    _set_new_target(bot)
    _apply_world_transform(bot)
    _sync_bot_transform(bot)
    print("[BotManager] Spawned bot: %s (ID: %d)" % [bot_name, bot_id])
 
func _physics_process(delta: float)->void:
    if not multiplayer.is_server():
        return
    
    if not is_instance_valid(_world):
        _world = _resolve_world()
    
    for bot in bots:
        _update_bot(bot, delta)
        _maybe_send_chat(bot)

func _update_bot( bot:Dictionary, delta:float)-> void:
    var current_pos: Vector3 = bot["position"]
    var direction: Vector3 =  (bot["target"] - current_pos)
    direction.y = 0
    var distance :=  direction.length()
    
    if distance < 0.5 :
        _set_new_target(bot)
        return
    
    var move_dir := direction.normalized()
    var move_amount : float =  bot["speed"]* delta
    move_amount = min(move_amount, distance)
    var new_pos := current_pos + move_dir * move_amount
    new_pos.y = 1.0
    bot["position"] = new_pos
    
    if move_dir.length() > 0.01:
        bot["rotation"] = atan2(move_dir.x, move_dir.z)
    
    _apply_world_transform(bot)
    _sync_bot_transform(bot)

func _set_new_target(bot: Dictionary) ->void:
    var angle := randf()* TAU
    var radius := randf_range(5.0,20.0)
    bot["target"] = Vector3(cos(angle)*radius, 1.0, sin(angle)* radius)

func _bot_send_chat( bot:Dictionary)->void:
    var message := bot_messages[randi() % bot_messages.size()]
    var bot_name: String = bot["name"]
    
    Network.rpc("client_recv_chat",bot_name, message)
    print("[Bot %s] %s"  %[bot_name, message])
func _exit_tree() -> void:
    for bot in bots:
        Network.client_remove_player(bot["id"])
        Network.rpc("client_remove_player", bot["id"])

func _maybe_send_chat(bot: Dictionary) -> void:
    var current_time := Time.get_ticks_msec() / 1000.0
    if current_time >= bot["next_chat_time"]:
        _bot_send_chat(bot)
        bot["next_chat_time"] = current_time + randf_range(chat_interval_min, chat_interval_max)

func _resolve_world() -> Node3D:
    if Network.world != null and is_instance_valid(Network.world):
        return Network.world
    var parent := get_parent()
    if parent is Node3D:
        return parent
    return null
    
func _apply_world_transform(bot: Dictionary) -> void:
    if _world == null or not is_instance_valid(_world):
        return
    if not _world.players.has(bot["id"]):
        return
    var player_node: Node3D = _world.players[bot["id"]]
    if not is_instance_valid(player_node):
        return
    player_node.global_transform.origin = bot["position"]
    player_node.rotation.y = bot.get("rotation", 0.0)

func _sync_bot_transform(bot: Dictionary) -> void:
    var yaw : float = bot.get("rotation", 0.0)
    var basis := Basis.IDENTITY.rotated(Vector3.UP, yaw)
    var transform := Transform3D(basis, bot["position"])
    Network.server_broadcast_transform(bot["id"], transform)

func _initial_spawn_position() -> Vector3:
    var angle := randf() * TAU
    var radius := randf_range(2.0, 6.0)
    return Vector3(cos(angle) * radius, 1.0, sin(angle) * radius)

func set_bot_target_count(n: int) -> void:
    if not multiplayer.is_server():
        return
    bot_count = max(0, n)
    if _spawn_timer == null:
        return
    if bots.size() < bot_count:
        _spawn_timer.start()
    else:
        _spawn_timer.stop()

func remove_all_bots() -> void:
    if not multiplayer.is_server():
        return
    for bot in bots:
        Network.client_remove_player(bot["id"])
        Network.rpc("client_remove_player", bot["id"]) 
    bots.clear()
    if _spawn_timer != null:
        _spawn_timer.stop()
