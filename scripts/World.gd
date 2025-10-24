extends Node3D

@onready var _players_root: Node3D = null
@onready var _chat_layer: CanvasLayer = null
@onready var _chat_log: RichTextLabel = null
@onready var _chat_input: LineEdit = null

var players: Dictionary = {} # peer_id -> Node3D

func _ready() -> void:
    # Minimal world: ground plane, light, and a container for players
    _players_root = Node3D.new()
    _players_root.name = "Players"
    add_child(_players_root)

    var ground := MeshInstance3D.new()
    ground.name = "Ground"
    var plane := PlaneMesh.new()
    plane.size = Vector2(100, 100)
    ground.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.25, 0.6, 0.25)
    ground.material_override = mat
    add_child(ground)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, 45, 0)
    add_child(light)

    # Simple chat UI (CanvasLayer)
    _chat_layer = CanvasLayer.new()
    add_child(_chat_layer)

    var chat_root := PanelContainer.new()
    chat_root.anchor_left = 0.02
    chat_root.anchor_right = 0.4
    chat_root.anchor_bottom = 0.35
    chat_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _chat_layer.add_child(chat_root)

    var vb := VBoxContainer.new()
    vb.custom_minimum_size = Vector2(0, 180)
    chat_root.add_child(vb)

    _chat_log = RichTextLabel.new()
    _chat_log.fit_content = true
    _chat_log.scroll_following = true
    _chat_log.bbcode_enabled = false
    _chat_log.autowrap_mode = TextServer.AUTOWRAP_WORD
    _chat_log.text = "Global chat ready. Press Enter to type.\n"
    vb.add_child(_chat_log)

    _chat_input = LineEdit.new()
    _chat_input.placeholder_text = "Type a message and press Enter"
    _chat_input.text_submitted.connect(_on_chat_submit)
    vb.add_child(_chat_input)

    # Hook network events
    Network.set_world(self)
    Network.chat_received.connect(_on_chat_received)

func spawn_player(peer_id: int, username: String, color: Color) -> void:
    if players.has(peer_id):
        return
    var scene := load("res://scenes/Player.tscn") as PackedScene
    var player := scene.instantiate() as CharacterBody3D
    player.name = "Player_%d" % peer_id
    # Set multiplayer authority so only owner drives its RPCs
    player.set_multiplayer_authority(peer_id)
    _players_root.add_child(player)
    players[peer_id] = player
    player.call_deferred("setup", username, color)
    # Place new players at random nearby positions for visibility
    var r := randf()*TAU
    player.global_transform.origin = Vector3(cos(r), 0.0, sin(r)) * 4.0

func remove_player(peer_id: int) -> void:
    if not players.has(peer_id):
        return
    var n: Node3D = players[peer_id]
    players.erase(peer_id)
    if is_instance_valid(n):
        n.queue_free()

func _on_chat_submit(text: String) -> void:
    if text.strip_edges().is_empty():
        return
    Network.send_chat(text)
    _chat_input.clear()

func _on_chat_received(name: String, text: String) -> void:
    _chat_log.append_text("%s: %s\n" % [name, text])
