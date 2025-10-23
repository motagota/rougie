extends Node

# Load the version from the common version script
const Version = preload("../../common/version.gd")

# The URL of the server to connect to
var server_url = "ws://localhost:8080"

# Called when the node enters the scene tree for the first time.
func _ready():
    # Display the current version
    $ui/version_label.text = "Version: " + Version.CURRENT_VERSION
    # Connect to the server
    connect_to_server()

func connect_to_server():
    var websocket = WebSocketClient.new()
    websocket.connect_to_url(server_url)

    # Wait for the connection to be established
    while websocket.get_connection_status() == WebSocketClient.CONNECTION_STATUS_CONNECTING:
        yield(get_tree(), "idle_frame")

    if websocket.get_connection_status() == WebSocketClient.CONNECTION_STATUS_OPEN:
        print("Connected to server")
        check_version(websocket)
    else:
        print("Failed to connect to server")

func check_version(websocket):
    # Send the current version to the server
    websocket.send_string(Version.CURRENT_VERSION)

    # Wait for a response from the server
    while websocket.get_connection_status() == WebSocketClient.CONNECTION_STATUS_OPEN:
        var event = websocket.get_peer(1).get_packet()
        if event:
            var response = event.get_string()
            if response == "VERSION_OK":
                print("Version is correct")
            else:
                print("Version mismatch: " + response)
            break

    websocket.close()