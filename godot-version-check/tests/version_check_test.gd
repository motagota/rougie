extends Node

# Test for version check functionality between client and server
func _ready():
    var client_version = load("res://common/version.gd").VERSION
    var server_version = get_server_version()

    assert(client_version == server_version, "Version mismatch: Client version is %s, Server version is %s" % [client_version, server_version])

func get_server_version():
    # Simulate a server version check
    return load("res://common/version.gd").VERSION  # Replace with actual server call in real implementation