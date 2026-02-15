# Pretty Good Encrypted Chat Protocol (WebSocket)

Encrypted chatroom protocol with automatic key rotation and PGP + AES key encryption

## Installation
```bash
luarocks install https://github.com/n3xus-unblocker/pgec-ws/raw/main/pgec-ws-1.0-1.src.rock
```
or
```bash
git clone https://github.com/n3xus-unblocker/pgec-ws.git
cd pgec-ws
luarocks make pgec-ws-1.0-1.rockspec
```
## Usage

### Start Server
```bash
run.sh server
```

### Create User
```bash
run.sh user
```

### Start Client
```bash
run.sh client
```

## Features

-  Easy encryption (AES + PGP)
-  12-hour automatic key rotation
-  Trust-on-First-Use authentication
-  WebSocket-based
-  Cross-platform (Linux, Mac-OS, Unix-based/Unix-like operating systems)
-  14 simple commands

## To-Do List
- [ ] Add genuine end-to-end encryption
- [ ] Fix Luarocks packages and fix Github Actions
- [ ] To stop vibecoding
- [ ] Fix some code

## License

Pretty Good Encrypted Chat Protocol © 2025 by itzjigsaw is licensed under CC BY-NC-SA 4.0.
To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/4.0/
