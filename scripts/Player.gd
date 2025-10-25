extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_velocity: float = 6.0
@export var mouse_sensitivity: float = 0.002

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

func setup(username: String, color: Color) -> void:
    print("Setup start - username: %s, color: %s" % [username, color])
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

    _is_local = is_multiplayer_authority()
    if _is_local:
        print("Setup: is local")
        _camera.make_current()
        set_process_input(true)
        if not _mouse_captured:
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
            _mouse_captured = true
    else:
        print("Setup: not local")
        _camera.set_current(false)
        set_process_input(false)

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
        # Send transform to others unreliably each physics tick
        rpc("receive_transform", global_transform)

func _local_move(delta: float) -> void:
    var v := velocity
    
    # Apply gravity
    if not is_on_floor():
        v.y -= gravity * delta
    else:
        # The "jump" action should now be correctly mapped
        if Input.is_action_just_pressed("jump"):
            v.y = jump_velocity

    # Get movement input
    var input_vec := Vector2.ZERO
    # The action names must match the ones you set in the Input Map
    input_vec.y = int(Input.is_action_pressed("move_back")) - int(Input.is_action_pressed("move_forward"))
    input_vec.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
    
    if input_vec.length() > 1.0:
        input_vec = input_vec.normalized()

    # Transform input direction to player's current basis
    var dir := Vector3.ZERO
    dir += transform.basis.z * input_vec.y
    dir += transform.basis.x * input_vec.x
    dir.y = 0
    dir = dir.normalized()
    
    # Calculate target velocity
    if dir != Vector3.ZERO:
        # Smoothly interpolate velocity to the desired movement direction
        var target_velocity = dir * speed
        v.x = lerp(v.x, target_velocity.x, 0.1)
        v.z = lerp(v.z, target_velocity.z, 0.1)
    else:
        # Decelerate if no input
        v.x = lerp(v.x, 0.0, 0.1)
        v.z = lerp(v.z, 0.0, 0.1)
        
    velocity = v
    move_and_slide()

# --- RPCs for Multiplayer Synchronization ---

@rpc("unreliable")
func receive_transform(t: Transform3D) -> void:
    if _is_local:
        return
    # Use global_transform to smoothly move the remote player
    # A simple snap for now, but in a full game you'd use interpolation
    global_transform = t
    
    # Since we only rotate the local player, we need to apply the remote
    # player's rotation directly for the other clients.
    rotation = Vector3(0, t.basis.get_euler().y, 0)
    _yaw = t.basis.get_euler().y # Sync yaw to keep it consistent

    # The pitch (camera rotation) is not sent, which is fine, 
    # as other players don't need to see the camera pitch.
    # If the mesh's rotation was meant to include pitch, we would need 
    # to sync that rotation component here too.
