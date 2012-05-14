package io.socket.flash
{
	import com.adobe.serialization.json.JSON;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.unescapeMultiByte;
	
	public class BaseSocketIOTransport extends EventDispatcher implements ISocketIOTransport
	{
		private var _hostname:String;
		public static const FRAME:String = "\ufffd";
		public static const SEPARATOR:String = ":";

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
						fireMessageEvent(JSON.decode(data));
						break;
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
				data = data.substr(3);
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
					return Packet.JSON_TYPE + ":::" + JSON.encode(packet.data);
				default:
					return "";
			}
		}
	}
}