extends Node3D
signal player_entered(body)
signal player_exited(body)

func _ready() -> void:
    var mesh := MeshInstance3D.new()
    var sphere := SphereMesh.new()
    sphere.radial_segments = 12
    sphere.rings = 8
    sphere.radius = 0.4
    mesh.mesh = sphere
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.5, 0.5, 0.5)
    mat.roughness = 1.0
    mesh.material_override = mat
    add_child(mesh)

    var area := Area3D.new()
    area.name = "InteractArea"
    area.monitoring = true
    area.monitorable = true
    area.collision_layer = 0
    area.collision_mask = 1
    var cs := CollisionShape3D.new()
    var shape := SphereShape3D.new()
    shape.radius = 2.5
    cs.shape = shape
    area.add_child(cs)
    add_child(area)

func _on_player_near_rock(_body):
    print("_player near rock")
    #Main.show_pickup_prompt()

func _on_player_left_rock(_body):
    print("Play left near rock")
    #Main.hide_pickup_prompt()

func _on_body_entered(body):
    if body.is_in_group("player"):
        player_entered.emit(body)

func _on_body_exited(body):
    if body.is_in_group("player"):
        player_exited.emit(body)
