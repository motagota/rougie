# Godot Version Check Project

## Overview
The Godot Version Check project is a simple client-server application developed using the Godot Engine. The server manages connections from clients and verifies their versions, while the client displays its version and checks with the server to ensure it is up to date.

## Project Structure
```
godot-version-check
├── project.godot          # Main configuration file for the Godot project
├── client                 # Contains client-side files
│   ├── client.tscn       # Scene for the client application
│   ├── client.gd         # Logic for the client
│   └── ui
│       └── version_label.tscn # Scene for displaying the version label
├── server                 # Contains server-side files
│   ├── server.tscn       # Scene for the server application
│   ├── server.gd         # Logic for the server
│   └── network
│       └── network_manager.gd # Handles network communication
├── common                 # Shared resources between client and server
│   ├── version.gd        # Defines the current version of the application
│   └── rpc_protocol.gd   # Defines the RPC protocol for communication
├── tests                  # Contains test files
│   └── version_check_test.gd # Tests for version check functionality
├── .gitignore             # Specifies files to ignore in version control
└── README.md              # Documentation for the project
```

## Setup Instructions
1. **Clone the Repository**
   Clone the repository to your local machine using Git:
   ```
   git clone <repository-url>
   ```

2. **Open the Project in Godot**
   Launch the Godot Engine and open the `project.godot` file.

3. **Run the Server**
   - Navigate to the server scene (`server/server.tscn`) and run it to start the server.

4. **Run the Client**
   - Navigate to the client scene (`client/client.tscn`) and run it to start the client.

## Usage
- The client will display its version and automatically check with the server to ensure it is running the correct version.
- If the versions do not match, the client will notify the user.

## Contributing
Contributions are welcome! Please submit a pull request or open an issue for any enhancements or bug fixes.

## License
This project is licensed under the MIT License. See the LICENSE file for more details.