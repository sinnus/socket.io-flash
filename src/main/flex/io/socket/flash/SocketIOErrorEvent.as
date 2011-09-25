package io.socket.flash
{
	import flash.events.Event;
	
	public class SocketIOErrorEvent extends Event
	{
		public static const CONNECTION_FAULT:String = "connectionFault";
		public static const SECURITY_FAULT:String = "securityFault";
		
		private var _text:String;
		
		public function SocketIOErrorEvent(type:String, text:String = "")
		{
			super(type);
			this._text = text;
		}
		
		public function get text():String
		{
			return _text;
		}
	}
}