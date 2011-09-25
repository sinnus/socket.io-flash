package io.socket.flash
{
	import flash.events.IEventDispatcher;

	public interface ISocketIOTransport extends IEventDispatcher
	{
		function send(message:Object):void;
		
		function connect():void;
		
		function disconnect():void;
	}
}