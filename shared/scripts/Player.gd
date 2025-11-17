extends CharacterBody3D
var username := ""

@export var speed: float = 6.0
@export var jump_velocity: float = 6.0
@export var mouse_sensitivity: float = 0.002
@export var interpolation_speed: float = 10.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _label: Label3D = null
var _mesh: MeshInstance3D = null
var _camera: Camera3D = null
var _is_local: bool = false
var _collision: CollisionShape3D = null

# Mouse look state
var _mouse_captured: bool = false
var _yaw: float = 0.0
var _pitch: float = 0.0
const TRANSFORM_SEND_INTERVAL := 0.1
var _last_transform_send_time: float = 0.0
var _last_sent_transform: Transform3D = Transform3D.IDENTITY
var _has_sent_transform: bool = false

var _target_transform: Transform3D = Transform3D.IDENTITY
var _has_target: bool = false

func setup(username: String, color: Color) -> void:
    print("[Player] setup start - username: %s, color: %s" % [username, color])
    # Create visual components if not present
    if _mesh == null:
        _mesh = MeshInstance3D.new()
        _mesh.mesh = CapsuleMesh.new()
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        _mesh.material_override = mat
        _mesh.position = Vector3(0, 1, 0)
        add_child(_mesh)
    if _label == null:
        _label = Label3D.new()
        _label.text = username
        _label.position = Vector3(0, 2.2, 0)
        _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED 
        add_child(_label)
    if _camera == null:
        _camera = Camera3D.new()
        _camera.position = Vector3(0, 1.5, 0)
        add_child(_camera)

    # Collision for movement/grounding
    if _collision == null:
        _collision = CollisionShape3D.new()
        var cap := CapsuleShape3D.new()
        cap.radius = 0.5
        cap.height = 1.8
        _collision.shape = cap
        _collision.position = Vector3(0, 1.0, 0)
        add_child(_collision)
    collision_layer = 1
    collision_mask = 1

    _is_local = is_multiplayer_authority()
    if _is_local:
        print("Setup: is local")
        _camera.make_current()
        set_process_input(true)
        if not InputMap.has_action("pickup"):
            InputMap.add_action("pickup")
            var evp := InputEventKey.new()
            evp.physical_keycode = 69
            InputMap.action_add_event("pickup", evp)
        if not InputMap.has_action("drop"):
            InputMap.add_action("drop")
            var evd := InputEventKey.new()
            evd.physical_keycode = 81
            InputMap.action_add_event("drop", evd)
        if not _mouse_captured:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            _mouse_captured = true
    else:
        print("Setup: not local")
        _camera.set_current(false)
        set_process_input(false)
        _target_transform = global_transform
        _has_target = true

func _input(event: InputEvent) -> void:
    if not _is_local:
        print("not local")
        return
    
    # Toggle mouse capture with ESC
    if event.is_action_pressed("ui_cancel"):
        print("ui cancel")
        if _mouse_captured:
            Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
            _mouse_captured = false
        else:
            # Re-capture mouse, which is needed for look and movement
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            _mouse_captured = true

    if event.is_action_pressed("pickup"):
        var w := get_tree().root.get_node("World")
        if w != null and w.has_method("request_pickup_nearest"):
            w.call("request_pickup_nearest")
    if event.is_action_pressed("drop"):
        var w2 := get_tree().root.get_node("World")
        if w2 != null and w2.has_method("request_drop_selected"):
            w2.call("request_drop_selected")
                
    # Process mouse movement for looking
    if _mouse_captured and event is InputEventMouseMotion:
        # Yaw (turning left/right - affects the player body)
        _yaw -= event.relative.x * mouse_sensitivity
        
        # Pitch (looking up/down - affects only the camera)
        _pitch += event.relative.y * mouse_sensitivity
        _pitch = clamp(_pitch, -PI/2.0, PI/2.0)
        
        # Apply rotations
        # 1. Yaw (Player node rotates horizontally)
        rotation = Vector3(0, _yaw, 0)
        
        # 2. Pitch (Camera node rotates vertically)
        _camera.rotation = Vector3(_pitch, 0, 0)

# --- Physics process for movement and gravity ---
func _physics_process(delta: float) -> void:
    if _is_local:
        _local_move(delta)
        _maybe_send_transform()
    else:
        _interpolate_remote(delta)

func _local_move(delta: float) -> void:
    var v := velocity
    
    if not is_on_floor():
        v.y -= gravity * delta
    else:
        if Input.is_action_just_pressed("jump"):
            v.y = jump_velocity

    var input_vec := Vector2.ZERO
    input_vec.y = int(Input.is_action_pressed("move_back")) - int(Input.is_action_pressed("move_forward"))
    input_vec.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
    
    if input_vec.length() > 1.0:
        input_vec = input_vec.normalized()

    var dir := Vector3.ZERO
    dir += transform.basis.z * input_vec.y
    dir += transform.basis.x * input_vec.x
    dir.y = 0
    dir = dir.normalized()
    
    if dir != Vector3.ZERO:
        var target_velocity = dir * speed
        v.x = lerp(v.x, target_velocity.x, 0.1)
        v.z = lerp(v.z, target_velocity.z, 0.1)
    else:
        v.x = lerp(v.x, 0.0, 0.1)
        v.z = lerp(v.z, 0.0, 0.1)
        
    velocity = v
    move_and_slide()

func _interpolate_remote(delta: float) -> void:
    if not _has_target:
        return
    
    # Smoothly interpolate to target position
    var current := global_transform
    var distance := current.origin.distance_to(_target_transform.origin)
    
    # If very far away (teleport/spawn), snap instantly
    if distance > 20.0:
        global_transform = _target_transform
        return
    
    # Otherwise smooth lerp
    var lerp_weight := interpolation_speed * delta
    
    # Interpolate position
    var new_origin := current.origin.lerp(_target_transform.origin, lerp_weight)
    
    # Interpolate rotation (slerp for smooth rotation)
    var current_quat := Quaternion(current.basis)
    var target_quat := Quaternion(_target_transform.basis)
    var new_quat := current_quat.slerp(target_quat, lerp_weight)
    
    # Apply interpolated transform
    global_transform = Transform3D(Basis(new_quat), new_origin)

func receive_transform(t: Transform3D) -> void:
    if _is_local:
        return
    
    # Update target for interpolation
    _target_transform = t
    _has_target = true
    
    # Extract yaw for any additional logic
    _yaw = t.basis.get_euler().y

func _maybe_send_transform() -> void:
    if not _is_local:
        return
    var now := Time.get_ticks_msec() / 1000.0
    if now - _last_transform_send_time < TRANSFORM_SEND_INTERVAL:
        return
    _last_transform_send_time = now
    var current := global_transform
    if _has_sent_transform:
        if current.origin.distance_to(_last_sent_transform.origin) < 0.01 and current.basis.is_equal_approx(_last_sent_transform.basis):
            return
    _has_sent_transform = true
    _last_sent_transform = current
    
    # Send to server, server will broadcast to others
    Network.rpc_id(1, "server_receive_player_transform", current)
