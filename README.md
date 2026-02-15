# PGEC-WS - Pretty Good Encrypted Chat Protocol (WebSocket)

End-to-end encrypted group chat protocol with automatic key rotation and zero server logging.

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
pgec-server [host] [port]
# Example: pgec-server 0.0.0.0 9110
```

### Create User
```bash
pgec-user
```

### Start Client
```bash
pgec-client
```

## Features

- ✅ End-to-end encryption (AES + PGP)
- ✅ 12-hour automatic key rotation
- ✅ Zero server logging
- ✅ Trust-on-First-Use authentication
- ✅ WebSocket-based
- ✅ Cross-platform
- ✅ 14 simple commands

## License

Pretty Good Encrypted Chat Protocol © 2025 by itzjigsaw is licensed under CC BY-NC-SA 4.0.
To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/4.0/
