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
    _world = get_parent()
    
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
    
    Network.players[bot_id]={
        "username": bot_name,
        "color": bot_color.to_html(false)
    }
    
    _world.spawn_player(bot_id, bot_name, bot_color)
    Network.rpc("client_spawn_player", bot_id, bot_name, bot_color.to_html(false))
    
    var bot :={
        "id": bot_id,
        "name": bot_name,
        "color": bot_color,
        "position": Vector3.ZERO,
        "target": Vector3.ZERO,
        "speed": randf_range(2.0,4.0),
        "next_chat_time": Time.get_ticks_msec()/ 1000.0 + randf_range(chat_interval_min, chat_interval_max)
    }
    
    bots.append(bot)
    await get_tree().process_frame
    _set_new_target(bot)
    print("[BotManager] Spawned bot: %s (ID: %d)" % [bot_name, bot_id])
 
func _physics_process(delta: float)->void:
    if not multiplayer.is_server():
        print("[Botmanager] is not server")
        return
    
    for bot in bots:
        _update_bot(bot, delta)  

func _update_bot( bot:Dictionary, delta:float)-> void:
    var player_node = _world.players.get(bot["id"])
    if not is_instance_valid(player_node):
        return
    
    var current_pos: Vector3 = player_node.global_transform.origin
    var direction: Vector3 =  (bot["target"] - current_pos)
    direction.y = 0
    var distance :=  direction.length()
    
    if distance < 0.5 :
        _set_new_target(bot)
    else:
        direction = direction.normalized()
        var move_amount : float =  bot["speed"]* delta
        var new_pos := current_pos + direction * move_amount
        new_pos.y = 1.0
        
        player_node.global_transform.origin = new_pos
        
        if direction.length()> 0.01:
            var angle := atan2(direction.x, direction.z)
            player_node.rotation.y = angle
    
    var current_time := Time.get_ticks_msec()/1000.0
    if current_time >= bot["next_chat_time"]:
        _bot_send_chat(bot)
        bot["next_chat_time"] = current_time + randf_range(chat_interval_min, chat_interval_max)

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
        if Network.players.has(bot["id"]):
            Network.players.erase(bot["id"])
            Network.rpc("client_remove_player", bot["id"])
    
    
