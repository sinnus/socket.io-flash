package io.socket.flash
{
	public class Packet
	{
		private var _type:String;
		private var _data:Object;
		
		public static const DISCONNECT_TYPE:String = "0";
		public static const CONNECT_TYPE:String = "1";
		public static const HEARTBEAT_TYPE:String = "2";
		public static const MESSAGE_TYPE:String = "3";
		public static const JSON_TYPE:String = "4";
		public static const EVENT_TYPE:String = "5";
		public static const ACK_TYPE:String = "6";
		public static const ERROR_TYPE:String = "7";
		public static const NOOP_TYPE:String = "8";
		
		public function Packet(type:String, data:Object)
		{
			this._type = type;
			this._data = data;
		}
		
		public function get type():String
		{
			return _type;
		}
		
		public function get data():Object
		{
			return _data;
		}
	}
}