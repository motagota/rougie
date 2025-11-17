extends Node3D

var item_id: int = 0
var item_type: String = ""

func setup(id: int, type_name: String) -> void:
    item_id = id
    item_type = type_name