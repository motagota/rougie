extends Node3D

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
