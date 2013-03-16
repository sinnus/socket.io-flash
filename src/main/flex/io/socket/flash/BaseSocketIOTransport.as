package io.socket.flash
{
	import com.adobe.serialization.json.JSON;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.unescapeMultiByte;
	
	public class BaseSocketIOTransport extends EventDispatcher implements ISocketIOTransport
	{
		private var _hostname:String;
		public static const FRAME:String = "\ufffd";
		public static const SEPARATOR:String = ":";
		public static const PROTOCOL_VERSION:String = "1";
		private var _connectLoader:URLLoader;
		protected var _sessionId:String;

		public function BaseSocketIOTransport(hostname:String)
		{
			_hostname = hostname;
		}
		
		public function get hostname():String
		{
			return _hostname;
		}
		
		public function send(message:Object):void
		{
		}
		
		protected function sendPacket(packet:Packet):void
		{
			
		}
		
		public function connect():void
		{
			var urlLoader:URLLoader = new URLLoader();
			var urlRequest:URLRequest = new URLRequest(hostname + "/" + PROTOCOL_VERSION + "/?t=" + currentMills());
			urlLoader.addEventListener(Event.COMPLETE, onConnectedComplete);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onConnectIoErrorEvent);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onConnectSecurityError);
			_connectLoader = urlLoader;
			urlLoader.load(urlRequest);
		}
		
		private function onConnectedComplete(event:Event):void
		{
			var urlLoader:URLLoader = event.target as URLLoader;
			var data:String = urlLoader.data;
			var handShake:Array = data.split(":");
			
			_sessionId = handShake[0];
			_connectLoader.close();
			_connectLoader = null;
			if (_sessionId == null)
			{
				// Invalid request
				var errorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.CONNECTION_FAULT, "Invalid sessionId request");
				dispatchEvent(errorEvent);
				return;
			}
			onSessionIdRecevied(_sessionId);
		}

		protected function onSessionIdRecevied(sessionId:String):void
		{
			
		}
		
		private function onConnectSecurityError(event:SecurityErrorEvent):void
		{
			_connectLoader = null;
			var socketIOErrorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.SECURITY_FAULT, event.text);
			dispatchEvent(socketIOErrorEvent);
		}
		
		private function onConnectIoErrorEvent(event:IOErrorEvent):void
		{
			_connectLoader = null;
			var socketIOErrorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.CONNECTION_FAULT, event.text);
			dispatchEvent(socketIOErrorEvent);
		}
		
		protected function currentMills():Number
		{
			return (new Date()).time;
		}
		
		public function disconnect():void
		{
		}

		public function processMessages(messages:Array):void
		{
			for each (var message:String in messages)
			{
				var type:String = message.charAt(0);
				var index:int = 1;
				// Skip messageId
				for(index++;index < message.length;index++)
				{
					if (message.charAt(index) == SEPARATOR)
					{
						break;
					}
				}
				// Skip endpoint
				for(index++;index < message.length;index++)
				{
					if (message.charAt(index) == SEPARATOR)
					{
						break;
					}
				}
				// Skip separator
				index++;
				
				var data:String = message.substr(index, message.length);
				switch (type)
				{
					case Packet.CONNECT_TYPE:
						fireConnected();
						break;
					case Packet.HEARTBEAT_TYPE:
						fireHeartbeat();
						break;
					case Packet.MESSAGE_TYPE:
						fireMessageEvent(data);
						break;
					case Packet.JSON_TYPE:
						fireMessageEvent(com.adobe.serialization.json.JSON.decode(data));
						break;
					case Packet.DISCONNECT_TYPE:
						disconnect();
						return;
					case Packet.ERROR_TYPE:
						disconnect();						
					default:
				}
			}
		}
		
		protected function fireConnected():void
		{
			dispatchEvent(new SocketIOEvent(SocketIOEvent.CONNECT));
		}
		
		protected function fireHeartbeat():void
		{
			sendPacket(new Packet(Packet.HEARTBEAT_TYPE, null));
		}
		
		protected function fireMessageEvent(message:Object):void
		{
			var messageEvent:SocketIOEvent;
			messageEvent = new SocketIOEvent(SocketIOEvent.MESSAGE, message);
			dispatchEvent(messageEvent);
		}
		
		protected function fireDisconnectEvent():void
		{
			var disconnectEvent:SocketIOEvent = new SocketIOEvent(SocketIOEvent.DISCONNECT);
			dispatchEvent(disconnectEvent);
		}
		
		public function decode(data:String, unescape:Boolean = false):Array{
			if (unescape)
			{
				data = unescapeMultiByte(data);
			}
			if (data.substr(0, FRAME.length) !== FRAME)
			{
				return [data];				
			}

			var messages:Array = [], number:*, n:*;
			do {
				if (data.substr(0, FRAME.length) !== FRAME)
				{
					return messages;	
				}
				data = data.substr(FRAME.length);
				number = "", n = "";
				for (var i:int = 0, l:int = data.length; i < l; i++)
				{
					n = Number(data.substr(i, 1));
					if (data.substr(i, 1) == n){
						number += n;
					} else {
						data = data.substr(number.length + FRAME.length);
						number = Number(number);
						break;
					}
				}
				messages.push(data.substr(0, number));
				data = data.substr(number);
			} while(data !== "");
			return messages;
		}
		
		public function encodePackets(packets:Array):String
		{
			var ret:String = "";
			if (packets.length == 1)
			{
				ret = encodePacket(packets[0]);
			}
			else
			{
				for each(var packet:Packet in packets)
				{
					var message:String = encodePacket(packet);
					if (message != null)
					{
						ret += FRAME + message.length + FRAME + message
					}
				}
			}
			return ret;
		};
		
		private function encodePacket(packet:Packet):String
		{
			switch (packet.type)
			{
				case Packet.HEARTBEAT_TYPE:
					return Packet.HEARTBEAT_TYPE + "::";
				case Packet.MESSAGE_TYPE:
					return Packet.MESSAGE_TYPE + ":::" + String(packet.data);
				case Packet.JSON_TYPE:
					return Packet.JSON_TYPE + ":::" + com.adobe.serialization.json.JSON.encode(packet.data);
				default:
					return "";
			}
		}
	}
}