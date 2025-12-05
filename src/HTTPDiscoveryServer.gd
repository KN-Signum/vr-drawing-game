extends Node

const DISCOVERY_PORT: int = 8080
const WEBSOCKET_PORT: int = 9001
var _http_server: TCPServer = TCPServer.new()
var _connections: Array[StreamPeerTCP] = []

func _ready() -> void:
	_http_server.listen(DISCOVERY_PORT, "0.0.0.0")
	print("HTTP Discovery: port %d" % DISCOVERY_PORT)

func _process(_delta: float) -> void:
	while _http_server.is_connection_available():
		var conn = _http_server.take_connection()
		conn.set_no_delay(true)
		_connections.append(conn)
	
	for i in range(_connections.size() - 1, -1, -1):
		var conn = _connections[i]
		if conn.get_available_bytes() > 0:
			var local_ip = _get_local_ip()
			var json_data = '{"websocket_url":"ws://%s:%d","ip":"%s","type":"vr_goggles","name":"VR Headset"}' % [local_ip, WEBSOCKET_PORT, local_ip]
			var response = "HTTP/1.1 200 OK\r\nAccess-Control-Allow-Origin: *\r\nContent-Type: application/json\r\nContent-Length: %d\r\n\r\n%s" % [json_data.length(), json_data]
			conn.put_data(response.to_utf8_buffer())
			conn.disconnect_from_host()
			_connections.remove_at(i)

func _get_local_ip() -> String:
	for ip in IP.get_local_addresses():
		if not ip.begins_with("127.") and not ip.contains(":"):
			return ip
	return "127.0.0.1"
