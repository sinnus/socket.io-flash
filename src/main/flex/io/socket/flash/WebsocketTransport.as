package io.socket.flash
{
	import com.adobe.serialization.json.JSON;

	import flash.display.DisplayObject;
	import flash.external.ExternalInterface;

	import net.gimite.websocket.IWebSocketLogger;
	import net.gimite.websocket.WebSocket;
	import net.gimite.websocket.WebSocketEvent;

	public class WebsocketTransport extends BaseSocketIOTransport implements IWebSocketLogger
	{
		public static var TRANSPORT_TYPE:String = "websocket";
		private static var CONNECTING:int = 0;
		private static var CONNECTED:int = 1;
		private static var DISCONNECTED:int = 2;

		private var _displayObject:DisplayObject;
		private var _webSocket:WebSocket;
		private var _origin:String;
		private var _cookie:String;
		private var _status:int = DISCONNECTED;
		private var _simpeHostname:String;
        private var _isSecure:Boolean;

		public function WebsocketTransport(hostname:String, displayObject:DisplayObject, isSecure:Boolean = false)
		{
			super();
            _isSecure = isSecure;
            if (isSecure) {
                _hostname = "https://" + hostname;
            } else {
                _hostname = "http://" + hostname
            }
			_simpeHostname = hostname;
            if (isSecure) {
                _origin = "https://" + hostname + "/";
            } else {
                _origin = "http://" + hostname + "/";
            }
			_displayObject = displayObject;
			if (ExternalInterface.available)
			{
				try
				{
					_cookie = ExternalInterface.call("function(){return document.cookie}");
				}
				catch (e:Error)
				{
					trace(e);
					_cookie = "";
				}
			}
			else
			{
				_cookie = "";
			}
		}

		public override function connect():void
		{
			if (_status != DISCONNECTED)
			{
				return;
			}
			super.connect();
		}

		protected override function onSessionIdRecevied(sessionId:String):void
		{
            var wsPrefix:String;
            if (_isSecure) {
                wsPrefix = "wss";
            } else {
                wsPrefix = "ws";
            }

			var wsHostname:String =  wsPrefix + "://" + _simpeHostname + "/" + PROTOCOL_VERSION + "/" + TRANSPORT_TYPE + "/" + sessionId;
			_status = CONNECTING;
			_webSocket = new WebSocket(0, wsHostname, [], _origin , null, 0, _cookie, null, this);
			_webSocket.addEventListener(WebSocketEvent.OPEN, onWebSocketOpen);
			_webSocket.addEventListener(WebSocketEvent.MESSAGE, onWebSocketMessage);
			_webSocket.addEventListener(WebSocketEvent.CLOSE, onWebSocketClose);
			_webSocket.addEventListener(WebSocketEvent.ERROR, onWebSocketError);
			_status = CONNECTING;
		}

		public override function disconnect():void
		{
			if (_status == CONNECTED || _status == CONNECTING)
			{
				_webSocket.close();
			}
		}

		private function onWebSocketOpen(event:WebSocketEvent):void
		{
			_status = CONNECTED;
			var connectEvent:SocketIOEvent = new SocketIOEvent(SocketIOEvent.CONNECT);
			dispatchEvent(connectEvent);
		}

		private function onWebSocketClose(event:WebSocketEvent):void
		{
			if (_status == CONNECTED || _status == CONNECTING)
			{
				_status = DISCONNECTED;
				_webSocket.removeEventListener(WebSocketEvent.OPEN, onWebSocketOpen);
				_webSocket.removeEventListener(WebSocketEvent.MESSAGE, onWebSocketMessage);
				_webSocket.removeEventListener(WebSocketEvent.CLOSE, onWebSocketClose);
				_webSocket.removeEventListener(WebSocketEvent.ERROR, onWebSocketError);
				_webSocket = null;
				fireDisconnectEvent();
			}
		}

		private function onWebSocketError(event:WebSocketEvent):void
		{
			var errorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.CONNECTION_FAULT, event.reason);
			dispatchEvent(errorEvent);
		}

		private function onWebSocketMessage(event:WebSocketEvent):void
		{
			if (_status == DISCONNECTED)
			{
				return;
			}
			var messages:Array = decode(event.message, true);
			processMessages(messages);
		}

		public override function send(message:Object):void
		{
			if (_status != CONNECTED)
			{
				return;
			}
			var packet:Packet;
			if (message is String)
			{
				packet = new Packet(Packet.MESSAGE_TYPE, message);
			}
			else if (message is Object)
			{
				packet = new Packet(Packet.JSON_TYPE, message);
			}
			sendPacket(packet);
		}

		protected override function sendPacket(packet:Packet):void
		{
			if (_status != CONNECTED)
			{
				return;
			}
			var resultData:String = encodePackets([packet]);
			_webSocket.send(resultData);
		}


		public function log(message:String):void
		{
			trace(message);
		}

		public function error(message:String):void
		{
			trace(message);
		}
	}
}