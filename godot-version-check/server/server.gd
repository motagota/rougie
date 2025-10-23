extends Node

# Constants
const VERSION = "1.0.0"

# Called when the node enters the scene tree for the first time.
func _ready():
    var server = NetworkedMultiplayerENet.new()
    server.create_server(12345, 32)  # Port and max clients
    get_tree().set_network_peer(server)
    print("Server started on port 12345")

# Function to handle new connections
func _on_peer_connected(id):
    print("Client connected: ", id)
    rpc_id(id, "send_version", VERSION)

# Function to handle disconnections
func _on_peer_disconnected(id):
    print("Client disconnected: ", id)

# RPC function to receive version check from client
rpc func check_version(client_version):
    if client_version == VERSION:
        rpc_id(get_tree().get_network_peer().get_peer_id(), "version_check_response", true)
    else:
        rpc_id(get_tree().get_network_peer().get_peer_id(), "version_check_response", false)