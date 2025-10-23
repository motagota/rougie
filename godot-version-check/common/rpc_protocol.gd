extends Node

# Define the RPC protocol for version checking
rpc_mode = RPC_MODE_REMOTE

# Remote procedure call to get the server version
remote func rpc_get_server_version() -> String:
    return VERSION

# Remote procedure call to check if the client version is correct
remote func rpc_check_client_version(client_version: String) -> bool:
    return client_version == VERSION