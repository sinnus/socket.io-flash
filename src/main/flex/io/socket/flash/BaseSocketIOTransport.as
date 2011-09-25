package io.socket.flash
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	
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
		
		public function decode(data:String):Array{
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
						data = unescape(data.substr(number.length + FRAME.length));
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