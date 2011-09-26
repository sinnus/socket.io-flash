package io.socket.flash
{
	import flash.display.DisplayObject;
	import flash.utils.Dictionary;

	public class SocketIOTransportFactory implements ISocketIOTransportFactory
	{
		private var _transpors:Dictionary = new Dictionary();
		
		public function SocketIOTransportFactory()
		{
			_transpors[XhrPollingTransport.TRANSPORT_TYPE] = XhrPollingTransport;
		}
		
		public function createSocketIOTransport(transportName:String, hostname:String, displayObject:DisplayObject):ISocketIOTransport	
		{
			return new _transpors[transportName](hostname, displayObject);
		}
	}
}