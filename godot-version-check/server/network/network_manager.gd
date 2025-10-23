extends Node

# NetworkManager handles network communication for the server.
class_name NetworkManager

var server : WebSocketServer
var clients : Dictionary = {}

# Called when the node enters the scene tree for the first time.
func _ready():
    start_server(8080)

# Starts the WebSocket server on the specified port.
func start_server(port: int):
    server = WebSocketServer.new()
    var err = server.listen(port)
    if err != OK:
        print("Failed to start server: ", err)
        return
    print("Server started on port: ", port)
    get_tree().create_timer(1.0).connect("timeout", self, "_on_timer_timeout")

# Called every second to check for new connections.
func _on_timer_timeout():
    server.poll()
    while server.is_connection_available():
        var client_id = server.get_connection_id()
        clients[client_id] = server.get_peer(client_id)
        print("Client connected: ", client_id)

    for client_id in clients.keys():
        if server.is_peer_connected(client_id):
            var message = server.get_peer(client_id).get_packet()
            if message:
                handle_message(client_id, message)

# Handles incoming messages from clients.
func handle_message(client_id: int, message: String):
    print("Received message from client ", client_id, ": ", message)
    # Here you can add logic to handle version checking and other messages.

# Sends a message to a specific client.
func send_message(client_id: int, message: String):
    if clients.has(client_id):
        clients[client_id].put_packet(message)

# Called when a client disconnects.
func _on_client_disconnected(client_id: int):
    clients.erase(client_id)
    print("Client disconnected: ", client_id)