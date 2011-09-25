package io.socket.flash
{
	import flash.events.Event;
	import flash.events.EventDispatcher;
	import flash.events.IOErrorEvent;
	import flash.events.SecurityErrorEvent;
	import flash.net.URLLoader;
	import flash.net.URLRequest;
	import flash.net.URLRequestHeader;
	import flash.net.URLRequestMethod;
	import flash.net.URLVariables;
	
	/*
		Only one URLLoader uses to send data
	*/
	public class HttpDataSender extends EventDispatcher
	{
		private var _sendUrl:String;
		private var _busy:Boolean = false;
		private var _urlLoader:URLLoader;
		private var _requestHeaders:Array;
		private var _messageQueue:Array = new Array();
		
		public function HttpDataSender(sendUrl:String)
		{
			_sendUrl = sendUrl;
			_requestHeaders = new Array(
				new URLRequestHeader("Content-Type", "application/x-www-form-urlencoded; charset=utf-8"),
				new URLRequestHeader("Pragma", "no-cache"),
				new URLRequestHeader("Cache-Control", "no-cache")); 
		}
		
		public function send(data:String):void
		{
			if (_busy)
			{
				_messageQueue.push(data);
				return;
			}
			
			if (_urlLoader == null)
			{
				_urlLoader = new URLLoader();
				_urlLoader.addEventListener(Event.COMPLETE, onSendCompleted);
				_urlLoader.addEventListener(IOErrorEvent.IO_ERROR, onSendIoError);
				_urlLoader.addEventListener(SecurityErrorEvent.SECURITY_ERROR, onSendSecurityError);
			}
			
			var urlRequest:URLRequest = new URLRequest(_sendUrl);
			urlRequest.method = URLRequestMethod.POST;
			var urlVariables:URLVariables = new URLVariables("data=" + data);
			urlRequest.data = urlVariables;
			urlRequest.requestHeaders = _requestHeaders; 
			_urlLoader.load(urlRequest);
			_busy = true;
		}
		
		public function close():void
		{
			if (_urlLoader)
			{
				_messageQueue = [];
				_urlLoader.close();
				_urlLoader = null;
			}
		}

		private function onSendCompleted(event:Event):void
		{
			_busy = false;
			if (_messageQueue.length == 0)
			{
				return;
			}
			var data:String = _messageQueue.pop();
			send(data);
		}
		
		private function onSendIoError(event:IOErrorEvent):void
		{
			dispatchEvent(event.clone());	
		}
		
		private function onSendSecurityError(event:SecurityErrorEvent):void
		{
			dispatchEvent(event.clone());	
		}
		
	}
}