package io.socket.flash
{
	import com.adobe.serialization.json.JSON;
	
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	
	public class XhrPollingTransport extends BaseSocketIOTransport
	{
		public static var TRANSPORT_TYPE:String = "xhr-polling";
		private var _connected:Boolean;
		private var _displayObject:DisplayObject;
		// References to avoid GC
		private var _pollingLoader:URLLoader;
		private var _httpDataSender:HttpDataSender;
		
		public function XhrPollingTransport(hostname:String, displayObject:DisplayObject)
		{
			super("http://" + hostname);
			_displayObject = displayObject;
		}
		
		public override function connect():void
		{
			if (_connected)
			{
				// TODO ADd reconnect
				return;
			}
			super.connect();
		}
		
		public override function disconnect():void
		{
			if (!_connected)
			{
				return;
			}
			if (_httpDataSender)
			{
				_httpDataSender.close();
				_httpDataSender = null;
			}
			
			if (_pollingLoader)
			{
				_pollingLoader.close();
				_pollingLoader.removeEventListener(IOErrorEvent.IO_ERROR, onPollingIoError);
				_pollingLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onPollingSecurityError);
				_pollingLoader.removeEventListener(Event.COMPLETE, onPollingComplete);
				_pollingLoader = null;
			}
			_connected = false;
			fireDisconnectEvent();
		}
		
		private var _packetsQueue:Array = [];
		private var _enterFrame:Boolean = false;
		
		public override function send(message:Object):void
		{
			if (!_connected)
			{
				return;
			}
			var packet:Packet;
			if (message is String)
			{
				packet = new Packet(Packet.MESSAGE_TYPE, message);
			}
			else if (message is Object)
			{
				packet = new Packet(Packet.JSON_TYPE, message);
			}
			sendPacket(packet);
		}

		protected override function sendPacket(packet:Packet):void
		{
			if (!_connected)
			{
				return;
			}
			_packetsQueue.push(packet);
			if (!_enterFrame)
			{
				_displayObject.addEventListener(Event.ENTER_FRAME, onEnterFrame);
				_enterFrame = true;
			}
		}
		
		private function onEnterFrame(event:Event):void
		{
			_displayObject.removeEventListener(Event.ENTER_FRAME, onEnterFrame);
			_enterFrame = false;
			var resultData:String = encodePackets(_packetsQueue);
			_packetsQueue = [];
			sendData(resultData);		
		}
		
		private function sendData(data:String):void
		{
			_httpDataSender.send(data);
		}
		
		private function onSendIoError(event:IOErrorEvent):void
		{
			disconnect();
		}
		
		private function onSendSecurityError(event:SecurityErrorEvent):void
		{
			disconnect();
		}
		
		private function startPolling():void
		{
			if (!_connected)
			{
				return;
			}
			if (_pollingLoader == null)
			{
				_pollingLoader = new URLLoader();
				_pollingLoader.addEventListener(IOErrorEvent.IO_ERROR, onPollingIoError);
				_pollingLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onPollingSecurityError);
				_pollingLoader.addEventListener(Event.COMPLETE, onPollingComplete);
			}
			var urlRequest:URLRequest = new URLRequest(hostname + "/" + PROTOCOL_VERSION + "/" +  TRANSPORT_TYPE + "/" + _sessionId);
			_pollingLoader.load(urlRequest);
		}

		private function onPollingComplete(event:Event):void
		{
			var urlLoader:URLLoader = event.target as URLLoader;
			var data:String = urlLoader.data;
			var messages:Array = decode(data);
			processMessages(messages);
			startPolling();
		}
		
		protected override function fireConnected():void
		{
			_connected = true;
			super.fireConnected();
			startPolling();
		}
		
		private function onPollingIoError(event:IOErrorEvent):void
		{
			disconnect();
		}
		
		private function onPollingSecurityError(event:SecurityErrorEvent):void
		{
			_pollingLoader = null;
			var socketIOErrorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.SECURITY_FAULT, event.text);
			dispatchEvent(socketIOErrorEvent);
		}
		
		protected override function onSessionIdRecevied(sessionId:String):void
		{
			_connected = true;
			_httpDataSender = new HttpDataSender(hostname + "/" + PROTOCOL_VERSION + "/" +  TRANSPORT_TYPE + "/" + _sessionId);
			_httpDataSender.addEventListener(IOErrorEvent.IO_ERROR, onSendIoError);
			_httpDataSender.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSendSecurityError);
			startPolling();
		}		
	}
}