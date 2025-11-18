extends Node3D

@onready var _players_root: Node3D = null
@onready var _chat_layer: CanvasLayer = null
@onready var _chat_log: RichTextLabel = null
@onready var _chat_input: LineEdit = null
@onready var _inventory_layer: CanvasLayer = null
@onready var _inv_panel: PanelContainer = null
@onready var _inv_list: VBoxContainer = null
@onready var _inv_drop_btn: Button = null
@onready var _hint_layer: CanvasLayer = null
@onready var _hint_panel: PanelContainer = null
@onready var _hint_label: Label = null

var players: Dictionary = {} # peer_id -> Node3D
var items: Dictionary = {} # item_id -> Node3D
@onready var _items_root: Node3D = null
var _selected_item_id: int = -1
var _nearest_item_id: int = -1

func _ready() -> void:
    print("WORLD: ready")
    # Minimal world: ground plane, light, and a container for players
    _players_root = Node3D.new()
    _players_root.name = "Players"
    add_child(_players_root)
    _items_root = Node3D.new()
    _items_root.name = "Items"
    add_child(_items_root)

    var ground := MeshInstance3D.new()
    ground.name = "Ground"
    var plane := PlaneMesh.new()
    plane.size = Vector2(100, 100)
    ground.mesh = plane
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.25, 0.6, 0.25)
    ground.material_override = mat
    add_child(ground)

    # Add static collision so CharacterBody3D can walk on the plane
    var floor := StaticBody3D.new()
    floor.name = "FloorBody"
    var cshape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = Vector3(100, 0.2, 100)
    cshape.shape = box
    cshape.position = Vector3(0, -0.1, 0)
    floor.add_child(cshape)
    add_child(floor)

    var light := DirectionalLight3D.new()
    light.rotation_degrees = Vector3(-45, 45, 0)
    add_child(light)

    # Temporary camera so we see the world before our player spawns
    var temp_cam := Camera3D.new()
    temp_cam.name = "TempCamera"
    temp_cam.position = Vector3(0, 8, 8)
    temp_cam.current = true
    add_child(temp_cam)
    # Call look_at after adding to tree
    await get_tree().process_frame
    temp_cam.look_at(Vector3(0, 1, 0), Vector3.UP)

    # Optional: simple environment tweaks (keeps defaults if editor has any)
    var we := WorldEnvironment.new()
    var env := Environment.new()
    env.ambient_light_sky_contribution = 0.4
    we.environment = env
    add_child(we)

    # Simple chat UI (CanvasLayer)
    _chat_layer = CanvasLayer.new()
    add_child(_chat_layer)

    var chat_root := PanelContainer.new()
    chat_root.anchor_left = 0.02
    chat_root.anchor_right = 0.5
    chat_root.anchor_bottom = 0.35
    chat_root.set_anchors_preset(Control.PRESET_TOP_LEFT)
    _chat_layer.add_child(chat_root)

    var vb := VBoxContainer.new()
    vb.custom_minimum_size = Vector2(300, 180)
    chat_root.add_child(vb)

    var scroll := ScrollContainer.new()
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.follow_focus = true
    vb.add_child(scroll)

    _chat_log = RichTextLabel.new()
    _chat_log.fit_content = true
    _chat_log.scroll_following = true
    _chat_log.bbcode_enabled = false
    _chat_log.autowrap_mode = TextServer.AUTOWRAP_WORD
    _chat_log.text = "Global chat ready. Press Enter to type.\n"
    _chat_log.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    _chat_log.add_theme_font_size_override("normal_font_size", 14)
    scroll.add_child(_chat_log)

    _chat_input = LineEdit.new()
    _chat_input.placeholder_text = "Type a message and press Enter"
    _chat_input.text_submitted.connect(_on_chat_submit)
    vb.add_child(_chat_input)

    # Hook network events
    Network.set_world(self)
    Network.chat_received.connect(_on_chat_received)
    Network.inventory_updated.connect(_on_inventory_updated)
    set_process(true)

    _inventory_layer = CanvasLayer.new()
    add_child(_inventory_layer)
    _inv_panel = PanelContainer.new()
    _inv_panel.anchor_right = 0.98
    _inv_panel.anchor_left = 0.58
    _inv_panel.anchor_top = 0.02
    _inv_panel.anchor_bottom = 0.35
    _inv_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    _inventory_layer.add_child(_inv_panel)
    var vb2 := VBoxContainer.new()
    vb2.custom_minimum_size = Vector2(280, 180)
    _inv_panel.add_child(vb2)
    _inv_list = VBoxContainer.new()
    vb2.add_child(_inv_list)
    _inv_drop_btn = Button.new()
    _inv_drop_btn.text = "Drop Selected"
    _inv_drop_btn.disabled = true
    _inv_drop_btn.pressed.connect(_on_drop_pressed)
    vb2.add_child(_inv_drop_btn)

    _hint_layer = CanvasLayer.new()
    add_child(_hint_layer)
    _hint_panel = PanelContainer.new()
    _hint_panel.anchor_left = 0.4
    _hint_panel.anchor_right = 0.6
    _hint_panel.anchor_top = 0.92
    _hint_panel.anchor_bottom = 0.98
    _hint_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    _hint_layer.add_child(_hint_panel)    
    var hb := HBoxContainer.new()
    hb.custom_minimum_size = Vector2(260, 28)    
    _hint_panel.add_child(hb)
    _hint_label = Label.new()
    _hint_label.text = "Press [E] to pick up"
    _hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    _hint_label.visible = true
    hb.add_child(_hint_label)
   
    
    _hint_label.custom_minimum_size = Vector2(260, 28)
    _hint_label.add_theme_color_override("font_color", Color(0, 0, 0)) # black
    _hint_label.add_theme_font_size_override("font_size", 24)   
    var style := StyleBoxFlat.new()
    style.bg_color = Color(1, 0, 1, 0.9)   # magenta, opaque
   
    
    print("[World] Hint label created: ", _hint_label != null)
    print("[World] Hint label visible: ", _hint_label.visible if _hint_label else "null")
    print("[World] Hint label text: ", _hint_label.text if _hint_label else "null")
    print("[World] Hint layer visible: ", _hint_layer.visible)
    print("[World] Hint panel visible: ", _hint_panel.visible)
    
    # --- bottom-center test button ---------------------------------
    var test_btn := Button.new()
    test_btn.text = "Force show hint"
    test_btn.custom_minimum_size = Vector2(200, 40)

    # anchor it center-bottom (like the hint panel)
    test_btn.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
    test_btn.anchor_top = 0.85
    test_btn.anchor_bottom = 0.85
    test_btn.grow_horizontal = Control.GROW_DIRECTION_BOTH

    test_btn.pressed.connect(func():
        _hint_label.visible = true
        _hint_label.modulate = Color.RED
        prints("Forced hint visible =", _hint_label.visible,
           "in_tree =", _hint_label.is_inside_tree())
    )
    add_child(test_btn)

func spawn_player(peer_id: int, username: String, color: Color) -> void:
    print("[World] Spawn player: start username: %s"%username)
    if players.has(peer_id):
        return
    var scene := load("res://shared/scenes/Player.tscn") as PackedScene
    var player := scene.instantiate() as CharacterBody3D
    player.name = "Player_%d" % peer_id
    # Set multiplayer authority so only owner drives its RPCs
    player.set_multiplayer_authority(peer_id)
    _players_root.add_child(player)
    players[peer_id] = player
    player.call_deferred("setup", username, color)
    # Place new players at random nearby positions for visibility
    var r := randf()*TAU
    player.global_transform.origin = Vector3(cos(r), 1.0, sin(r)) * 4.0
    if peer_id == multiplayer.get_unique_id():
        var temp_cam := get_node_or_null("TempCamera")
        if temp_cam:
            temp_cam.queue_free()
    Network.notify_player_spawned(peer_id)

func remove_player(peer_id: int) -> void:
    if not players.has(peer_id):
        return
    var n: Node3D = players[peer_id]
    players.erase(peer_id)
    if is_instance_valid(n):
        n.queue_free()

func spawn_item(item_id: int, type_name: String, pos: Vector3, node: Node3D) -> void:
    if items.has(item_id):
        return
    node.name = "Item_%d" % item_id
    _items_root.add_child(node)
    node.global_transform.origin = pos
    node.set("item_id", item_id)
    var area := node.get_node_or_null("InteractArea")
    if area != null and area is Area3D:
        (area as Area3D).body_entered.connect(Callable(self, "_on_item_area_entered").bind(item_id))
        (area as Area3D).body_exited.connect(Callable(self, "_on_item_area_exited").bind(item_id))
    items[item_id] = node
    call_deferred("_check_item_overlap", item_id)

func remove_item(item_id: int) -> void:
    if not items.has(item_id):
        return
    var n: Node3D = items[item_id]
    items.erase(item_id)
    if is_instance_valid(n):
        n.queue_free()

func can_pick_item(peer_id: int, item_id: int) -> bool:
    if not players.has(peer_id):
        return false
    if not items.has(item_id):
        return false
    var player: Node3D = players[peer_id]
    var item: Node3D = items[item_id]
    if not is_instance_valid(player) or not is_instance_valid(item):
        return false
    if not player.is_inside_tree() or not item.is_inside_tree():
        return false
    var d := player.global_transform.origin.distance_to(item.global_transform.origin)
    return d <= 2.5

func network_apply_transform(peer_id: int, xform: Transform3D) -> bool:
    if not players.has(peer_id):
        return false
    var player: Node3D = players[peer_id]
    if not is_instance_valid(player):
        return false
    if player.has_method("receive_transform"):
        player.call_deferred("receive_transform", xform)
    else:
        player.global_transform = xform
    return true

func _on_chat_submit(text: String) -> void:
    print("[World] _on_chat_submit :: %s "%text)
    if text.strip_edges().is_empty():
        return
    Network.send_chat(text)
    _chat_input.clear()

func _on_chat_received(name: String, text: String) -> void:
    _chat_log.append_text("%s: %s\n" % [name, text])

func _on_inventory_updated(peer_id: int, inv: Array) -> void:
    if peer_id != multiplayer.get_unique_id():
        return
    _refresh_inventory_ui(inv)

func _refresh_inventory_ui(inv: Array) -> void:
    for c in _inv_list.get_children():
        c.queue_free()
    for it in inv:
        var id := int(it.get("id", -1))
        var type_name := String(it.get("type", ""))
        var b := Button.new()
        b.text = "%s #%d" % [type_name, id]
        b.pressed.connect(Callable(self, "_on_inv_select").bind(id))
        _inv_list.add_child(b)
    _inv_drop_btn.disabled = _selected_item_id == -1

func _on_inv_select(id: int) -> void:
    _selected_item_id = id
    _inv_drop_btn.disabled = false

func _on_drop_pressed() -> void:
    request_drop_selected()

func _process(delta: float) -> void:
    var local_id := multiplayer.get_unique_id()
    if not players.has(local_id):
        _hint_label.visible = false
        return
        
    var player: Node3D = players[local_id]
    if not is_instance_valid(player):
        _hint_label.visible = false
        return
    
    var p := player.global_transform.origin
    var best_id := -1
    var best_d := 99999.0
    
    for nid in items.keys():
        var n: Node3D = items[nid]
        if not is_instance_valid(n):
            continue
        if not n.is_inside_tree():
            continue
        var d := p.distance_to(n.global_transform.origin)
        if d < best_d:
            best_d = d
            best_id = int(nid)
            
    _nearest_item_id = best_id
    
    var show := best_id != -1 and best_d <= 2.5
    if _hint_label:
        _hint_label.visible = show
        if show:
            print("[World] Showing pickup hint for item %d at distance %.2f" % [best_id, best_d])
            
func _on_item_area_entered(body: Node, item_id: int) -> void:
    var local_id := multiplayer.get_unique_id()
    if players.has(local_id) and body == players[local_id]:
        _nearest_item_id = item_id
        _hint_label.visible = true

func _on_item_area_exited(body: Node, item_id: int) -> void:
    var local_id := multiplayer.get_unique_id()
    if players.has(local_id) and body == players[local_id]:
        if _nearest_item_id == item_id:
            _hint_label.visible = false

func _check_item_overlap(item_id: int) -> void:
    if not items.has(item_id):
        return
    var node: Node3D = items[item_id]
    var area := node.get_node_or_null("InteractArea")
    if area == null or not (area is Area3D):
        return
    var bodies := (area as Area3D).get_overlapping_bodies()
    var local_id := multiplayer.get_unique_id()
    if players.has(local_id):
        var player: Node3D = players[local_id]
        for b in bodies:
            if b == player:
                _nearest_item_id = item_id
                _hint_label.visible = true
                break

func request_pickup_nearest() -> void:
    var local_id := multiplayer.get_unique_id()
    if not players.has(local_id):
        return
    var player: Node3D = players[local_id]
    var best_id := -1
    var best_d := 99999.0
    var p := player.global_transform.origin
    for nid in items.keys():
        var n: Node3D = items[nid]
        if not is_instance_valid(n):
            continue
        var d := p.distance_to(n.global_transform.origin)
        if d < best_d:
            best_d = d
            best_id = int(nid)
    if best_id == -1:
        return
    Network.rpc_id(1, "server_request_pick_item", best_id)

func request_drop_selected() -> void:
    if _selected_item_id == -1:
        return
    var local_id := multiplayer.get_unique_id()
    if not players.has(local_id):
        return
    var player: Node3D = players[local_id]
    var f := -player.transform.basis.z.normalized()
    var pos := player.global_transform.origin + f * 1.5
    pos.y = 1.0
    Network.rpc_id(1, "server_request_drop_item", _selected_item_id, pos)
