package io.socket.flash
{
	import flash.events.Event;
	
	public class SocketIOEvent extends Event
	{
		public static const CONNECT:String = "connect";
		public static const DISCONNECT:String = "disconnect";
		public static const MESSAGE:String = "message";
		
		private var _message:Object;
		
		public function SocketIOEvent(type:String, message:Object=null, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			super(type, bubbles, cancelable);
			_message = message;
		}
		
		public function get message():Object
		{
			return _message;
		}
	}
}