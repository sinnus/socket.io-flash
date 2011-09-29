package io.socket.flash
{
	import com.adobe.serialization.json.JSON;
	
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.utils.unescapeMultiByte;
	
	public class BaseSocketIOTransport extends EventDispatcher implements ISocketIOTransport
	{
		private var _hostname:String;
		public static const FRAME:String = "~m~";
		
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
				if (message.substr(0, 3) == '~h~')
				{
					// Skip hearbeat because of long polling
				}
				else if (message.substr(0, 3) == '~j~')
				{
					var json:String = message.substring(3,message.length);
					var jsonObject:Object = JSON.decode(json);
					fireMessageEvent(jsonObject);
				}
				else
				{
					fireMessageEvent(message);
				}
			}
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
			var messages:Array = [], number:*, n:*;
			do {
				if (data.substr(0, 3) !== FRAME)
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
		
		public function encode(messages:Array, json:Boolean):String{
			var ret:String = "";
			var message:String;
			for (var i:int = 0, l:int = messages.length; i < l; i++)
			{
				message = messages[i] === null || messages[i] === undefined ? "" : (messages[i].toString());
				if (json)
				{
					message = "~j~" + message;
				}
				ret += FRAME + message.length + FRAME + message;
			}
			return ret;
		};
	}
}