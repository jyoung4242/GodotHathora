extends Node

class_name HathoraClient

var coordinator
var appID
var parent_Node
var http_request_login
var http_request_create
var buffer=PoolByteArray([])
var connection
var http_request_connect
var token
var RoomID
var authACKreceived = false;

signal hathora_login
signal hathora_create
signal hathora_data_received
signal hathora_game_connect
signal hathora_connection_error
signal hathora_connection_closed

# Our WebSocketClient instance
var _wsclient=null
var websocket_url

func _ready():
	pass	

func _process(_delta):
	if _wsclient!=null:
		_wsclient.poll()

#called from main to initialie http connection
func init(config):
	appID = config.app_ID
	coordinator = config.coordinator
	parent_Node=config.parent_Node
	http_request_login = HTTPRequest.new()
	http_request_create = HTTPRequest.new()
	parent_Node.add_child(http_request_login)
	parent_Node.add_child(http_request_create)
	http_request_login.connect("request_completed", self, "login_response", [config])
	http_request_create.connect("request_completed", self, "create_game", [config])
	
func login_response(_result, _response_code, _headers, body, config):
	var response = parse_json(body.get_string_from_utf8())
	token = response.token
	if token != "":
		var _nouse = self.connect("hathora_login", parent_Node, config.Login_Response_Signal)
		emit_signal("hathora_login", [token])
		
func create_game(_result, _response_code, _headers, body, config):
	var response = parse_json(body.get_string_from_utf8())
	RoomID = response.stateId
	if RoomID != null:
		var _nouse = self.connect("hathora_create", parent_Node, config.Create_Response_Signal)
		emit_signal("hathora_create", [RoomID])

#send http request for anonymous login
func login_Anonymous():
	#do HTTP request here
	var body= to_json({})
	
	var error = http_request_login.request("https://"+ coordinator + "/" + appID +"/login/anonymous",[],true, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		print('error')
	
#send http request for creating new game
func create(create_token, data):
	buffer=data
	var body= to_json({})
	var error = http_request_create.request("https://"+ coordinator + "/" + appID +"/create",["Authorization:"+create_token, "Content-Type: application/octet-stream"],false, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		print('error')
		

#set up Socket connection to the socket server
func client_connect(config):
	_wsclient = WebSocketClient.new()
	_wsclient.connect("connection_closed", self, "on_Close")
	_wsclient.connect("connection_error", self, "on_Error")
	_wsclient.connect("connection_established", self, "on_Connect")
	_wsclient.connect("data_received", self, "on_Message")
	websocket_url = "wss://" + coordinator + "/connect/" + appID
	var _nouse = self.connect("hathora_data_received", parent_Node, config.onMessage)
	_nouse = self.connect("hathora_game_connect", parent_Node, config.onConnect)
	_nouse = self.connect("hathora_connection_error", parent_Node, config.onError)
	_nouse = self.connect("hathora_connection_closed", parent_Node, config.onClose)
	var err = _wsclient.connect_to_url(websocket_url)

	if err != OK:
		print("Unable to connect socket")

func on_Connect(proto=""):
	print("socket connected  ", proto)
	self.sendAuthpackets(RoomID)
	emit_signal("hathora_game_connect")

func on_Error():
	print("Connection Error Occurred")
	emit_signal("hathora_connection_error")

func on_Close():
	print("Connection Error Occurred")
	emit_signal("hathora_connection_closed")

func on_Message():
	print('data received')
	if(authACKreceived):
		var response = _wsclient.get_peer(1).get_packet().get_string_from_utf8()
		emit_signal("hathora_data_received", [response])
	else:
		var _response = _wsclient.get_peer(1).get_packet().get_string_from_utf8()
		authACKreceived = true
		print("Auth Packets Acknowledged")

#general send data command
func sendData(data=null):
	var msgDict = {
		"type": 0,
		"msg": data		
	}	
	var connectionString = JSON.print(msgDict)
	buffer=[]
	buffer.append_array(connectionString.to_utf8())
	_wsclient.get_peer(1).put_packet(buffer)

#authenticates client to the Hathora coordinator
func sendAuthpackets(roomID):
	print('sending token and roomid')
	var myDict = {"token": token, "stateId": roomID}
	var connectionString = JSON.print(myDict)
	buffer.append_array(connectionString.to_utf8())
	_wsclient.get_peer(1).put_packet(buffer)
	
	
