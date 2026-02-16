# Pretty Good Encrypted Chat Protocol (WebSocket)

Encrypted chatroom protocol with automatic key rotation and PGP + AES key encryption

## Installation
```bash
sudo luarocks install https://github.com/n3xus-unblocker/pgec-ws/raw/main/pgec-ws-1.0-3.src.rock
```
or
```bash
git clone https://github.com/n3xus-unblocker/pgec-ws.git
cd pgec-ws
luarocks make pgec-ws-1.0-3.rockspec
```

### Notice

When installing pgec-ws, you may get this error:
```bash
Missing dependencies for pgec-ws 1.0-3:
   luasocket >= 3.0, < 3.2 (not installed)
```
Please ignore it, I don't know why that happens, it might just be my computer but just know luasocket IS most likely installed when that shows up.

## Usage

### Start Server
```bash
chmod +x bin/pgec-server
./bin/pgec-server
```

### Create a User
```bash
chmod +x bin/pgec-user
./bin/pgec-user
```

### Start Client
```bash
chmod +x bin/pgec-client
./bin/pgec-client
```

## To-Do List
- [ ] Add genuine end-to-end encryption
- [X] Fix Luarocks packages
- [ ] Fix Github Actions
- [ ] To stop vibecoding
- [X] Fix some code

## Features

-  Easy encryption (AES + PGP)
-  12-hour automatic key rotation
-  Trust-on-First-Use authentication
-  WebSocket-based
-  Cross-platform (Linux, Mac-OS, Unix-based/Unix-like operating systems)
-  14 simple commands

## License

Pretty Good Encrypted Chat Protocol © 2025 by itzjigsaw is licensed under CC BY-NC-SA 4.0.
To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/4.0/
