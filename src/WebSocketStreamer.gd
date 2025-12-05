extends Node

const PORT: int = 9001
const BIND_IP: String = "0.0.0.0"   # listen on all interfaces
const TARGET_W: int = 960
const TARGET_H: int = 540
const JPEG_QUALITY: int = 60  # Reduced from 70 to decrease frame size
const FPS: float = 10.0  # Reduced from 15 to give more time for buffer to clear

var _tcp: TCPServer = TCPServer.new()
var _clients: Array[WebSocketPeer] = []
var _accum: float = 0.0
var _frame_skip_counter: int = 0

func _ready() -> void:
	var err: int = _tcp.listen(PORT, BIND_IP)
	if err != OK:
		push_error("TCP listen error: %s" % err)
	else:
		print("Listening TCP on %s:%d (WS handshake by client)" % [BIND_IP, PORT])
		print("Uwaga: zezwól zaporze na port %d (sieć prywatna)." % PORT)
		_print_local_ip()

func _print_local_ip() -> void:
	# Get local IP addresses
	var local_ips = IP.get_local_addresses()
	print("Available IP addresses:")
	for ip in local_ips:
		# Filter out localhost and IPv6
		if not ip.begins_with("127.") and not ip.contains(":"):
			print("  - ws://%s:%d (use this in your frontend app)" % [ip, PORT])

func _process(delta: float) -> void:
	# Accept new connections
	while _tcp.is_connection_available():
		var conn: StreamPeerTCP = _tcp.take_connection()
		conn.set_no_delay(true)
		var ws := WebSocketPeer.new()
		# Increase outbound buffer size to handle larger frames (default is 65536)
		ws.outbound_buffer_size = 262144  # 256 KB buffer
		var herr: int = ws.accept_stream(conn)  # OK or ERR_BUSY
		if herr == OK or herr == ERR_BUSY:
			_clients.append(ws)
			# show client IP
			print("WS client from %s (state=%s, total=%d)"
				% [conn.get_connected_host(), _state_name(ws.get_ready_state()), _clients.size()])
			# Send initial menu state info
			_send_menu_state()
		else:
			conn.disconnect_from_host()

	# Poll existing clients and remove closed ones
	for i in range(_clients.size() - 1, -1, -1):
		var c: WebSocketPeer = _clients[i]
		c.poll()
		
		# Process incoming messages
		while c.get_available_packet_count() > 0:
			var packet: PackedByteArray = c.get_packet()
			var message: String = packet.get_string_from_utf8()
			_handle_message(message)
		
		if c.get_ready_state() == WebSocketPeer.STATE_CLOSED:
			_clients.remove_at(i)
			print("WS: client removed (total=%d)" % _clients.size())

	# Broadcast frame every 1/FPS
	_accum += delta
	if _accum >= 1.0 / FPS:
		_accum = 0.0
		_broadcast_frame()

func _broadcast_frame() -> void:
	if _clients.is_empty():
		return
	var tex := get_viewport().get_texture()
	if tex == null:
		return
	var img: Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGB8)
	img.resize(TARGET_W, TARGET_H, Image.INTERPOLATE_BILINEAR)
	var jpg: PackedByteArray = img.save_jpg_to_buffer(JPEG_QUALITY)

	# Send to clients, but skip if buffer is full
	for i in range(_clients.size() - 1, -1, -1):
		var c: WebSocketPeer = _clients[i]
		if c.get_ready_state() == WebSocketPeer.STATE_OPEN:
			# Check if there's space in the buffer before sending
			var err = c.send(jpg)
			if err == ERR_OUT_OF_MEMORY:
				# Buffer full, skip this frame for this client (they'll get the next one)
				pass
			elif err != OK:
				# Other error, might need to disconnect this client
				print("Failed to send to client: %s" % err)

func _handle_message(message: String) -> void:
	print("WS received: %s" % message)
	var json = JSON.new()
	var parse_result = json.parse(message)
	
	if parse_result == OK:
		var data = json.get_data()
		if typeof(data) == TYPE_DICTIONARY:
			if data.has("action"):
				match data["action"]:
					"next":
						# Trigger menu progression
						get_tree().call_group("menu", "remote_next")
					"start_game":
						# Start the selected game
						get_tree().call_group("menu", "remote_start_game")
					_:
						print("Unknown action: %s" % data["action"])

func _send_menu_state() -> void:
	# Send current menu state to newly connected clients
	var state = {
		"type": "menu_state",
		"screen": "info"  # or "menu" depending on current state
	}
	_send_json(state)

func _send_json(data: Dictionary) -> void:
	var json_string = JSON.stringify(data)
	var packet = json_string.to_utf8_buffer()
	
	for c in _clients:
		if c.get_ready_state() == WebSocketPeer.STATE_OPEN:
			c.send_text(json_string)

func _state_name(s: int) -> String:
	match s:
		WebSocketPeer.STATE_CONNECTING: return "CONNECTING"
		WebSocketPeer.STATE_OPEN:       return "OPEN"
		WebSocketPeer.STATE_CLOSING:    return "CLOSING"
		WebSocketPeer.STATE_CLOSED:     return "CLOSED"
		_: return str(s)
