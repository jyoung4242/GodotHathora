extends Control


var token
var RoomID
var data = PoolByteArray()

var clientConfig={
	"coordinator": "coordinator.hathora.dev",
	"app_ID": "8d6c68f72a4ec708a7aff1bf012067b696bcfe8cfc5843fc4c33f7d102a5367b",
	"parent_Node": self,
	"Login_Response_Signal": "_Login_Response_login",
	"Create_Response_Signal": "_Create_Response_login",
}

# Called when the node enters the scene tree for the first time.
func _ready():
	$Hathora.init(clientConfig)

func _on_Button_pressed():
	$Hathora.login_Anonymous()

func _Login_Response_login(_result, _response_code, _headers, body):
	var response = parse_json(body.get_string_from_utf8())
	
	token = response.token
	if token != "":
		$LoginResponse.text = "Token Received: " + token
		
	# Will print the user agent string used by the HTTPRequest node (as recognized by httpbin.org).
	print("token: " + response.token)

func _on_Create_pressed():
	$Hathora.create(token, data)

func _Create_Response_login(_result, _response_code, _headers, body):
	var response = parse_json(body.get_string_from_utf8())
	
	RoomID = response.stateId
	if RoomID != null:
		$CreateResponse.text = "Room ID Received: " + RoomID

func _on_Connect_pressed():
	
	var connectconfig={
		"stateId": RoomID,
		"token": token,
		"onData": data,
		"onClose": "_on_Socket_Closed",
		"onError": "_on_Socket_Closed",
		"onConnect": "_on_Socket_Connection",
		"onMessage": "_on_Socket_Data",
		"requestComplete":"_on_Connection_received",
	}
	$Hathora.client_connect(connectconfig)

func _on_Socket_Connection(proto = ""):
	print("socket connected  ", proto)
	$ConnectResponse.text="socket connected"
	$Hathora.sendAuthpackets(token, RoomID)

func _on_Socket_Closed(was_clean=false):
	print("closed: ", was_clean)

func _on_Socket_Data(client):
	$DataBuffer.text = $DataBuffer.text + client.get_peer(1).get_packet().get_string_from_utf8() + "\n"
	var b = $DataBuffer.get_line_count()
	$DataBuffer.cursor_set_line(b)


func _on_SendData_pressed():
	$Hathora.sendData("Test Message yeah!!!!")
