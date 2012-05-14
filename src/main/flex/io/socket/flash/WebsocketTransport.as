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
		private var _sessionId:String;
		private var _status:int = DISCONNECTED;
		
		public function WebsocketTransport(hostname:String, displayObject:DisplayObject)
		{
			super("ws://" + hostname + "/" + TRANSPORT_TYPE);
			_origin = "http://" + hostname + "/";
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
			_webSocket = new WebSocket(0, hostname, [], _origin , null, 0, _cookie, null, this);
			_webSocket.addEventListener(WebSocketEvent.OPEN, onWebSocketOpen);
			_webSocket.addEventListener(WebSocketEvent.MESSAGE, onWebSocketMessage);
			_webSocket.addEventListener(WebSocketEvent.CLOSE, onWebSocketClose);
			_webSocket.addEventListener(WebSocketEvent.ERROR, onWebSocketError);
			_status = CONNECTING;
			_isFirstMessage = true;
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
		
		private var _isFirstMessage:Boolean = true;
		
		private function onWebSocketMessage(event:WebSocketEvent):void
		{
			if (_status == DISCONNECTED)
			{
				return;
			}
			var messages:Array = decode(event.message, true);
			if (_isFirstMessage)
			{
				_isFirstMessage = false;
				_sessionId = messages.pop();
				_status = CONNECTED;
				var connectEvent:SocketIOEvent = new SocketIOEvent(SocketIOEvent.CONNECT);
				dispatchEvent(connectEvent);
			}
			processMessages(messages);
		}
		
		public override function send(message:Object):void
		{
			if (_webSocket == null || _status != CONNECTED)
			{
				return;
			}
			// TODO Remove code duplication like in XhrPollingTransport
			var socketIOMessage:String;
			if (message is String)
			{
				//socketIOMessage = encodePackets([message], false);
			}
			else if (message is Object)
			{
				var jsonMessage:String = JSON.encode(message);
				//socketIOMessage = encodePackets([jsonMessage], true);
			}
			_webSocket.send(socketIOMessage);
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