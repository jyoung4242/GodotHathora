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

#Login Button Press Event
func _on_Button_pressed():
	$Hathora.login_Anonymous()

#Signal Callback passed during Hathora Init call
func _Login_Response_login(_result, _response_code, _headers, body):
	var response = parse_json(body.get_string_from_utf8())
	token = response.token
	if token != "":
		$LoginResponse.text = "Token Received: " + token
		# Will print the user agent string used by the HTTPRequest node (as recognized by httpbin.org).
		print("token: " + response.token)

#Create Game button pressed
func _on_Create_pressed():
	$Hathora.create(token, data)

#Signal Callback that was passed during Hathora Init Call
func _Create_Response_login(_result, _response_code, _headers, body):
	var response = parse_json(body.get_string_from_utf8())
	RoomID = response.stateId
	if RoomID != null:
		$CreateResponse.text = "Room ID Received: " + RoomID

#Connect to game button pressed
func _on_Connect_pressed():
	
	#setting up client connection for sockets
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

#when socket connects, this callback was passed in connectConfig
#this also sends the authentication bytes as well
func _on_Socket_Connection(proto = ""):
	print("socket connected  ", proto)
	$ConnectResponse.text="socket connected"
	$Hathora.sendAuthpackets(token, RoomID)

#when socket closes, this callback was passed in connectConfig
func _on_Socket_Closed(was_clean=false):
	print("closed: ", was_clean)

#when socket data is received, this callback was passed in connectConfig
func _on_Socket_Data(client):
	$DataBuffer.text = $DataBuffer.text + client.get_peer(1).get_packet().get_string_from_utf8() + "\n"
	var b = $DataBuffer.get_line_count()
	$DataBuffer.cursor_set_line(b)

#UI event for send data button press
func _on_SendData_pressed():
	$Hathora.sendData("Test Message yeah!!!!")
