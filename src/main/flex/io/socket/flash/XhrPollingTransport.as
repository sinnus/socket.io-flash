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
		private var _sessionId:String;
		private var _connected:Boolean;
		private var _displayObject:DisplayObject;
		// References to avoid GC
		private var _pollingLoader:URLLoader;
		private var _connectLoader:URLLoader;
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
			var urlLoader:URLLoader = new URLLoader();
			var urlRequest:URLRequest = new URLRequest(hostname + "/" + TRANSPORT_TYPE + "//" + currentMills());
			urlLoader.addEventListener(Event.COMPLETE, onConnectedComplete);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onConnectIoErrorEvent);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onConnectSecurityError);
			_connectLoader = urlLoader;
			urlLoader.load(urlRequest);
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
		
		private var _messageQueue:Array = [];
		private var _enterFrame:Boolean = false;
		
		public override function send(message:Object):void
		{
			if (!_connected)
			{
				return;
			}
			var socketIOMessage:String;
			if (message is String)
			{
				socketIOMessage = encode([message], false);
			}
			else if (message is Object)
			{
				var jsonMessage:String = JSON.encode(message);
				socketIOMessage = encode([jsonMessage], true);
			}
			_messageQueue.push(socketIOMessage);
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
			var resultData:String = "";
			for each(var data:String in _messageQueue)
			{
				resultData = resultData + data;
			}
			_messageQueue = [];
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
		
		private function currentMills():Number
		{
			return (new Date()).time;
		}
		
		private function onConnectIoErrorEvent(event:IOErrorEvent):void
		{
			_connectLoader = null;
			var socketIOErrorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.CONNECTION_FAULT, event.text);
			dispatchEvent(socketIOErrorEvent);
		}
		
		private function onConnectSecurityError(event:SecurityErrorEvent):void
		{
			_connectLoader = null;
			var socketIOErrorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.SECURITY_FAULT, event.text);
			dispatchEvent(socketIOErrorEvent);
		}
		
		
		private function startPolling():void
		{
			if (_pollingLoader == null)
			{
				_pollingLoader = new URLLoader();
				_pollingLoader.addEventListener(IOErrorEvent.IO_ERROR, onPollingIoError);
				_pollingLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onPollingSecurityError);
				_pollingLoader.addEventListener(Event.COMPLETE, onPollingComplete);
			}
			var urlRequest:URLRequest = new URLRequest(hostname + "/" + TRANSPORT_TYPE + "/" + _sessionId + "/" + currentMills());
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
		
		private function onConnectedComplete(event:Event):void
		{
			var urlLoader:URLLoader = event.target as URLLoader;
			var data:String = urlLoader.data;
			var connectEvent:SocketIOEvent = new SocketIOEvent(SocketIOEvent.CONNECT);
			_sessionId = decode(data)[0];
			_connectLoader.close();
			_connectLoader = null;
			if (_sessionId == null)
			{
				// Invalid request
				var errorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.CONNECTION_FAULT, "Invalid sessionId request");
				dispatchEvent(errorEvent);
				return;
			}
			_connected = true;

			_httpDataSender = new HttpDataSender(hostname + "/" + TRANSPORT_TYPE + "/" + _sessionId + "/send");
			_httpDataSender.addEventListener(IOErrorEvent.IO_ERROR, onSendIoError);
			_httpDataSender.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSendSecurityError);

			dispatchEvent(connectEvent);
			startPolling();
		}
	}
}