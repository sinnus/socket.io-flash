package io.socket.flash
{
	import flash.display.DisplayObject;

	public interface ISocketIOTransportFactory
	{
		function createSocketIOTransport(transportName:String, hostname:String, displayObject:DisplayObject, isSecure:Boolean = false):ISocketIOTransport;
	}
}