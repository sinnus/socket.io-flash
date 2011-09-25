package io.socket.flash
{
	import com.adobe.serialization.json.JSON;
	
	import flash.events.Event;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLLoaderDataFormat;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	import flash.utils.Dictionary;
	
	import mx.controls.Alert;
	
	import org.osmf.utils.URL;
	
	public class XhrPollingTransport extends BaseSocketIOTransport
	{
		private var _transportType:String = "xhr-polling";
		private var _sessionId:String;
		private var _connected:Boolean;
		private static var _urlLoaders:Dictionary = new Dictionary();
		// References to avoid GC
		private var _pollingLoader:URLLoader;
		private var _connectLoader:URLLoader;
		private var _opendLoaders:Dictionary = new Dictionary();
		private var _requestHeaders:Array;
		
		public function XhrPollingTransport(hostname:String)
		{
			super(hostname);
			_requestHeaders = new Array(
				new URLRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=utf-8"),
				new URLRequestHeader("Pragma", "no-cache"),
				new URLRequestHeader("Cache-Control", "no-cache")); 
		}
		
		public override function connect():void
		{
			if (_connected)
			{
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
			_pollingLoader = null;
			_connected = false;
			fireDisconnectEvent();
		}
		
		public override function send(message:Object):void
		{
			if (!_connected)
			{
				// TODO Throw exception
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
			} else
			{
				return;
			}
			sendData(socketIOMessage);		
		}
		
		private function sendData(data:String):void
		{
			var urlLoader:URLLoader = new URLLoader();
			var urlRequest:URLRequest = new URLRequest(hostname + "/" + _transportType + "/" + _sessionId + "/send");
			urlRequest.method = URLRequestMethod.POST;
			var urlVariables:URLVariables = new URLVariables("data=" + data);
			urlRequest.data = urlVariables;
			urlRequest.requestHeaders = _requestHeaders;
			urlLoader.addEventListener(Event.COMPLETE, onSendCompleted);
			urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onSendIoError);
			urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSendSecurityError);
			_opendLoaders[urlLoader] = urlLoader;
			urlLoader.load(urlRequest);
		}
		
		private function onSendCompleted(event:Event):void
		{
			var urlLoader:URLLoader = event.target as URLLoader;
			delete _opendLoaders[urlLoader];
		}

		private function onSendIoError(event:IOErrorEvent):void
		{
			Alert.show("onSendIoError");
			var urlLoader:URLLoader = event.target as URLLoader;
			delete _opendLoaders[urlLoader];
		}
		
		private function onSendSecurityError(event:SecurityErrorEvent):void
		{
			Alert.show("onSendSecurityError");
			var urlLoader:URLLoader = event.target as URLLoader;
			delete _opendLoaders[urlLoader];
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
			Alert.show("onConnectIoErrorEvent");
		}
		
		private function onConnectSecurityError(event:SecurityErrorEvent):void
		{
			_connectLoader = null;
			Alert.show("onConnectSecurityError");
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
			Alert.show("onPollingIoError");
		}
		
		private function onPollingSecurityError(event:SecurityErrorEvent):void
		{
			_pollingLoader = null;
			Alert.show("onPollingSecurityError");
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
			startPolling();
		}
	}
}