extends CharacterBody3D

@export var speed: float = 6.0
@export var jump_velocity: float = 6.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var _label: Label3D = null
var _mesh: MeshInstance3D = null
var _camera: Camera3D = null
var _is_local: bool = false

func setup(username: String, color: Color) -> void:
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
        _camera.position = Vector3(0, 3, 6)
        _camera.rotation_degrees.x = -20
        add_child(_camera)

    _is_local = is_multiplayer_authority()
    _camera.current = _is_local

func _physics_process(delta: float) -> void:
    if _is_local:
        _local_move(delta)
        # Send transform to others unreliably each physics tick
        rpc("receive_transform", global_transform)

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

    var dir := Vector3(input_vec.x, 0, input_vec.y).normalized()
    v.x = dir.x * speed
    v.z = dir.z * speed

    velocity = v
    move_and_slide()

@rpc("unreliable")
func receive_transform(t: Transform3D) -> void:
    if _is_local:
        return
    global_transform = t
