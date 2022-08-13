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

# Our WebSocketClient instance
var _wsclient=null
var websocket_url

#var  token
#var  roomID

func _ready():
	pass	

func _process(_delta):
	if _wsclient!=null:
		_wsclient.poll()

func init(config):
	appID = config.app_ID
	coordinator = config.coordinator
	parent_Node=config.parent_Node
	http_request_login = HTTPRequest.new()
	http_request_create = HTTPRequest.new()
	var loginResponse = config.Login_Response_Signal
	var createResponse = config.Create_Response_Signal
	parent_Node.add_child(http_request_login)
	parent_Node.add_child(http_request_create)
	http_request_login.connect("request_completed", parent_Node, loginResponse)
	http_request_create.connect("request_completed", parent_Node, createResponse)
	

func login_Anonymous():
	#do HTTP request here
	var body= to_json({})
	print('here')
	var error = http_request_login.request("https://"+ coordinator + "/" + appID +"/login/anonymous",[],true, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		print('error')
	
	
func create(token, data):
	buffer=data
	var body= to_json({})
	
	var error = http_request_create.request("https://"+ coordinator + "/" + appID +"/create",["Authorization:"+token, "Content-Type: application/octet-stream"],false, HTTPClient.METHOD_POST, body)
	if error != OK:
		push_error("An error occurred in the HTTP request.")
		print('error')

	#do HTTP request here
		
	
func client_connect(config):
		
	var token = config.token
	var roomID = config.stateId
	print ('token: ', token)
	print ('roomid: ',roomID)
	_wsclient = WebSocketClient.new()
	_wsclient.connect("connection_closed", parent_Node, config.onClose)
	_wsclient.connect("connection_error", parent_Node, config.onError)
	_wsclient.connect("connection_established", parent_Node, config.onConnect)
	_wsclient.connect("data_received", parent_Node, config.onMessage,[_wsclient])
	websocket_url = "wss://" + coordinator + "/connect/" + appID
	
	print ("Connecting to ",websocket_url)
	var err = _wsclient.connect_to_url(websocket_url)
	
	if err != OK:
		print("Unable to connect socket")

func sendData(data=null):
	var msgDict = {
		"type": 0,
		"msg": data		
	}	
	var connectionString = JSON.print(msgDict)
	buffer=[]
	buffer.append_array(connectionString.to_utf8())
	_wsclient.get_peer(1).put_packet(buffer)
	
func sendAuthpackets(token, roomID):
	print('sending token and roomid')
	var myDict = {"token": token, "stateId": roomID}
	var connectionString = JSON.print(myDict)
	buffer.append_array(connectionString.to_utf8())
	_wsclient.get_peer(1).put_packet(buffer)
	
	
