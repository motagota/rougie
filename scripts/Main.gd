extends Control

@onready var _name_input: LineEdit = null
@onready var _color_picker: ColorPickerButton = null
@onready var _join_addr: LineEdit = null
@onready var _host_btn: Button = null
@onready var _join_btn: Button = null

func _ready() -> void:
    # Build a light-weight UI programmatically to avoid complex .tscn
    anchor_right = 1.0
    anchor_bottom = 1.0

    var panel := PanelContainer.new()
    panel.anchor_left = 0.3
    panel.anchor_right = 0.7
    panel.anchor_top = 0.2
    panel.anchor_bottom = 0.8
    add_child(panel)

    var vb := VBoxContainer.new()
    vb.custom_minimum_size = Vector2(0, 240)
    vb.add_theme_constant_override("separation", 12)
    panel.add_child(vb)

    var title := Label.new()
    title.text = "Rougie MMO Proto"
    title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    title.add_theme_font_size_override("font_size", 24)
    vb.add_child(title)

    # Name
    var name_hb := HBoxContainer.new()
    vb.add_child(name_hb)
    var name_lbl := Label.new()
    name_lbl.text = "Username:"
    name_lbl.custom_minimum_size = Vector2(100, 0)
    name_hb.add_child(name_lbl)
    _name_input = LineEdit.new()
    _name_input.placeholder_text = "e.g. Hero42"
    _name_input.text = "Player" + str(randi()%1000)
    name_hb.add_child(_name_input)

    # Color
    var color_hb := HBoxContainer.new()
    vb.add_child(color_hb)
    var color_lbl := Label.new()
    color_lbl.text = "Toon color:"
    color_lbl.custom_minimum_size = Vector2(100, 0)
    color_hb.add_child(color_lbl)
    _color_picker = ColorPickerButton.new()
    _color_picker.color = Color.from_hsv(randf(), 0.7, 0.9)
    color_hb.add_child(_color_picker)

    # Host / Join controls
    _host_btn = Button.new()
    _host_btn.text = "Host"
    _host_btn.pressed.connect(_on_host)
    vb.add_child(_host_btn)

    var join_hb := HBoxContainer.new()
    vb.add_child(join_hb)
    _join_addr = LineEdit.new()
    _join_addr.placeholder_text = "Server address (e.g. 127.0.0.1)"
    join_hb.add_child(_join_addr)
    _join_btn = Button.new()
    _join_btn.text = "Join"
    _join_btn.pressed.connect(_on_join)
    join_hb.add_child(_join_btn)

    # Footer
    var hint := Label.new()
    hint.text = "WASD to move. Enter to chat."
    hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vb.add_child(hint)

    # Ensure clean network state when returning to menu
    Network.shutdown()

func _validated_profile() -> bool:
    var name := _name_input.text.strip_edges()
    if name.is_empty():
        OS.alert("Please enter a username.")
        return false
    Network.set_profile(name, _color_picker.color)
    return true

func _goto_world() -> void:
    get_tree().change_scene_to_file("res://scenes/World.tscn")

func _on_host() -> void:
    if not _validated_profile():
        return
    Network.host()
    _goto_world()

func _on_join() -> void:
    if not _validated_profile():
        return
    var addr := _join_addr.text.strip_edges()
    if addr.is_empty():
        OS.alert("Please enter server address.")
        return
    Network.join(addr)
    # Change immediately; spawns will sync when connected
    _goto_world()
