# Experimental Multiplayer Tutorial

This project supports direct multiplayer connections with up to four total players: one host and three clients. There is no connection screen, matchmaking, or automatic network setup. Everyone starts the game with command-line arguments.

## Requirements

- Every player needs a copy of the project and a compatible Godot 4.6.x installation.
- Run commands from the project root, where `project.godot` is located.
- The host must start before clients try to connect.
- Every player must use the same UDP port. The default is `7000`.

## Test on One Computer

Open one terminal and start the host:

```bash
godot --path . -- --host
```

Open up to three more terminals and start a client in each one:

```bash
godot --path . -- --join=127.0.0.1
```

The host and the first three clients form a four-player session. Any additional client cannot connect.

## Connect on the Same Network

Use this method when all computers are connected to the same router or local network.

1. The host finds their local IP address. It usually looks like `192.168.1.25` or `10.0.0.25`.
2. The host allows Godot through the operating-system firewall when prompted.
3. The host starts the session:

```bash
godot --path . -- --host
```

4. The host gives their local IP address to the other players.
5. Each client replaces the example address below with the host's local IP:

```bash
godot --path . -- --join=192.168.1.25
```

Common commands for finding the host's local IP address are:

```bash
# Windows
ipconfig

# Linux
ip addr

# macOS
ifconfig
```

## Connect over the Internet

Internet hosting requires manual router and firewall configuration because this experimental project does not include NAT traversal or relay servers.

1. The host forwards UDP port `7000` in their router settings to the host computer's local IP address.
2. The host allows incoming UDP traffic on port `7000` through the operating-system firewall.
3. The host starts the session:

```bash
godot --path . -- --host
```

4. The host finds their public IP address using their router status page or a public IP lookup service.
5. The host gives that public IP address to no more than three clients.
6. Each client connects using the host's public IP:

```bash
godot --path . -- --join=203.0.113.25
```

Forward UDP, not TCP. If the host's internet provider uses carrier-grade NAT (CGNAT), direct internet hosting may not work even with router port forwarding. In that case, players need a shared VPN network or a future relay-server feature.

## Use a Different Port

The host and every client must specify the same port:

```bash
# Host
godot --path . -- --host --port=7001

# Client
godot --path . -- --join=192.168.1.25 --port=7001
```

When connecting over the internet, forward and allow the selected UDP port instead of `7000`.

## Connection Logs

Networking status appears in the terminal because the game has no connection UI. A successful host prints a hosting message. A successful client prints its assigned peer ID, followed by Player spawn messages.

If a client only prints `Connecting`, check that:

- The host started first and is still running.
- The address belongs to the host computer.
- The host and client use the same port.
- The firewall allows Godot and incoming UDP traffic.
- The router forwards the selected UDP port when connecting over the internet.
- The session does not already contain four players.

## Current Limitations

- The host counts as one of the four players.
- There is no server browser, lobby, password, authentication, or reconnect support.
- The session ends for clients when the host closes the game.
- Movement is client-authoritative and is not protected against cheating.
- Networking is experimental and should only be exposed to people you trust.
