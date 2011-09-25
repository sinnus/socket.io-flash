package io.socket.flash
{
	import com.adobe.serialization.json.JSON;
	
	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.utils.Dictionary;
	
	import mx.controls.Alert;
	
	public class XhrPollingTransport extends BaseSocketIOTransport
	{
		private var _transportType:String = "xhr-polling";
		private var _sessionId:String;
		private var _connected:Boolean;
		private static var _urlLoaders:Dictionary = new Dictionary();
		// References to avoid GC
		private var _pollingLoader:URLLoader;
		private var _connectLoader:URLLoader;
		private var _httpDataSender:HttpDataSender;
		private var _displayObject:DisplayObject;
		
		public function XhrPollingTransport(hostname:String, displayObject:DisplayObject)
		{
			super(hostname);
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
			var urlRequest:URLRequest = new URLRequest(hostname + "/" + _transportType + "//" + currentMills());
			urlLoader.addEventListener(Event.COMPLETE, onConnectedComplete);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onConnectIoErrorEvent);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onConnectSecurityError);
			_connectLoader = urlLoader;
			urlLoader.load(urlRequest);
		}
		
		public override function disconnect():void
		{
			if (!_connected || !_pollingLoader)
			{
				return;
			}
			_pollingLoader.close();
			_pollingLoader.removeEventListener(IOErrorEvent.IO_ERROR, onPollingIoError);
			_pollingLoader.removeEventListener(SecurityErrorEvent.SECURITY_ERROR, onPollingSecurityError);
			_pollingLoader.removeEventListener(Event.COMPLETE, onPollingComplete);
			_pollingLoader = null;
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
			}
		}
		
		private function onEnterFrame(event:Event):void
		{
			_displayObject.removeEventListener(Event.ENTER_FRAME, onEnterFrame);	
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
			dispatchEvent(event.clone());
		}
		
		private function onSendSecurityError(event:SecurityErrorEvent):void
		{
			dispatchEvent(event.clone());
		}
		
		private function fireDisconnectEvent():void
		{
			var disconnectEvent:SocketIOEvent = new SocketIOEvent(SocketIOEvent.DISCONNECT);
			dispatchEvent(disconnectEvent);
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
			var urlLoader:URLLoader = new URLLoader();
			var urlRequest:URLRequest = new URLRequest(hostname + "/" + _transportType + "/" + _sessionId + "/" + currentMills());
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onPollingIoError);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onPollingSecurityError);
			urlLoader.addEventListener(Event.COMPLETE, onPollingComplete);
			_pollingLoader = urlLoader;
			urlLoader.load(urlRequest);
		}

		private function onPollingComplete(event:Event):void
		{
			var urlLoader:URLLoader = event.target as URLLoader;
			var data:String = urlLoader.data;
			var messages:Array = decode(data);
			for each (var message:String in messages)
			{
				if (message.substr(0, 3) == '~h~')
				{
					// TODO Heartbeat
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
			startPolling();
		}
		
		private function fireMessageEvent(message:Object):void
		{
			var messageEvent:SocketIOEvent;
			messageEvent = new SocketIOEvent(SocketIOEvent.MESSAGE, message);
			dispatchEvent(messageEvent);
		}
		
		private function onPollingIoError(event:IOErrorEvent):void
		{
			_pollingLoader = null;
			_connected = false;
			fireDisconnectEvent();
		}
		
		private function onPollingSecurityError(event:SecurityErrorEvent):void
		{
			_pollingLoader = null;
			var socketIOErrorEvent:SocketIOErrorEvent = new SocketIOErrorEvent(SocketIOErrorEvent.SECURITY_FAULT, event.text);
			dispatchEvent(socketIOErrorEvent);
		}
		
		// TODO Add server http result code
		private function onConnectedComplete(event:Event):void
		{
			var urlLoader:URLLoader = event.target as URLLoader;
			var data:String = urlLoader.data;
			var connectEvent:SocketIOEvent = new SocketIOEvent(SocketIOEvent.CONNECT);
			dispatchEvent(connectEvent);
			_sessionId = decode(data)[0];
			_connected = true;
			_connectLoader = null;

			_httpDataSender = new HttpDataSender(hostname + "/" + _transportType + "/" + _sessionId + "/send");
			_httpDataSender.addEventListener(IOErrorEvent.IO_ERROR, onSendIoError);
			_httpDataSender.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSendSecurityError);
				
			startPolling();
		}
	}
}