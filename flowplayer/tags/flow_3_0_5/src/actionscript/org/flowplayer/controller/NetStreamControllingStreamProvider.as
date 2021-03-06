/*    
 *    Copyright (c) 2008, 2009 Flowplayer Oy
 *
 *    This file is part of Flowplayer.
 *
 *    Flowplayer is free software: you can redistribute it and/or modify
 *    it under the terms of the GNU General Public License as published by
 *    the Free Software Foundation, either version 3 of the License, or
 *    (at your option) any later version.
 *
 *    Flowplayer is distributed in the hope that it will be useful,
 *    but WITHOUT ANY WARRANTY; without even the implied warranty of
 *    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *    GNU General Public License for more details.
 *
 *    You should have received a copy of the GNU General Public License
 *    along with Flowplayer.  If not, see <http://www.gnu.org/licenses/>.
 */

package org.flowplayer.controller {
	import org.flowplayer.config.Config;
	import org.flowplayer.controller.StreamProvider;
	import org.flowplayer.controller.VolumeController;
	import org.flowplayer.flow_internal;
	import org.flowplayer.model.Clip;
	import org.flowplayer.model.ClipError;
	import org.flowplayer.model.ClipEvent;
	import org.flowplayer.model.ClipEventType;
	import org.flowplayer.model.Playlist;
	import org.flowplayer.model.PluginModel;
	import org.flowplayer.util.Assert;
	import org.flowplayer.util.Log;
	import org.flowplayer.view.Flowplayer;
	
	import flash.display.DisplayObject;
	import flash.errors.IOError;
	import flash.events.NetStatusEvent;
	import flash.events.TimerEvent;
	import flash.media.Video;
	import flash.net.NetConnection;
	import flash.net.NetStream;
	import flash.utils.Timer;	

	/**
	 * A StreamProvider that does it's job using the Flash's NetStream class.
	 * Implements standard HTTP based progressive download.
	 */
	public class NetStreamControllingStreamProvider implements StreamProvider {

		protected var log:Log = new Log(this);
		private var _connection:NetConnection;
		private var _netStream:NetStream;
		private var _startedClip:Clip;
		private var _playlist:Playlist;
		private var _pauseAfterStart:Boolean;
		private var _volumeController:VolumeController;
		private var _seekTargetWaitTimer:Timer;
		private var _seekTarget:Number;
		
		// state variables
		private var _silentSeek:Boolean;
		private var _paused:Boolean;
		private var _stopping:Boolean;
		private var _started:Boolean;
		private var _model:PluginModel;
		private var _config:Config;

		/**
		 * Sets the plugin model.
		 */
		public function set config(model:PluginModel):void {
			_model = model;
			onConfig(model);
		} 

		flow_internal function set playerConfig(config:Config):void {
			_config = config;
		}

		/**
		 * Sets the player instance.
		 */
		public function set player(player:Flowplayer):void {
			_config = player.config;
			onLoad(player); 
		} 	

		/* ---- implementation of StreamProvider: ---- */

		/**
		 * @inheritDoc
		 */
		public final function load(event:ClipEvent, clip:Clip, pauseAfterStart:Boolean = false):void {
			_paused = false;
			_stopping = false;
			Assert.notNull(clip, "load(clip): clip cannot be null");
			if (pauseAfterStart) {
				log.info("this clip will pause after start");
			}
			_pauseAfterStart = pauseAfterStart;
			clip.onMetaData(onMetaData, function(clip:Clip):Boolean { return clip.provider == (_model ? _model.name : 'http'); });
			
			log.debug("previously started clip " + _startedClip);
			if (_startedClip && _startedClip == clip && _connection) {
				log.info("playing previous clip again, reusing existing connection and resuming");
				_started = false;
				netStream.resume();
				start(null, _startedClip, _pauseAfterStart);
			} else {
				log.debug("will create a new connection");
				_startedClip = clip;
				
				connect(clip);
			}
		}

		/**
		 * @inheritDoc
		 */
		public function get allowRandomSeek():Boolean {
			return false;
		}
		
		/**
		 * @inheritDoc
		 */
		public function stopBuffering():void {
			if (! _netStream) return;
			log.debug("stopBuffering, closing netStream");
			_netStream.close();
			dispatchPlayEvent(ClipEventType.BUFFER_STOP);
		}

		/**
		 * @inheritDoc
		 */
		public final function resume(event:ClipEvent):void {
			_paused = false;
			_stopping = false;
			doResume(_netStream, event);
		}

		/**
		 * @inheritDoc
		 */
		public final function pause(event:ClipEvent):void {
			_paused = true;
			doPause(_netStream, event);
		}
		
		/**
		 * @inheritDoc
		 * @see #doSeek()
		 */
		public final function seek(event:ClipEvent, seconds:Number):void {
			silentSeek = event == null;
			log.debug("seekTo " + seconds);
			_seekTarget = seconds;
			doSeek(event, _netStream, seconds);
		}

		/**
		 * @inheritDoc
		 */
		public final function stop(event:ClipEvent, closeStreamAndConnection:Boolean = false):void {
			log.debug("stop called");
			if (! _netStream) return;
			doStop(event, _netStream, closeStreamAndConnection);
		}
		
		/**
		 * @inheritDoc
		 */
		public function get time():Number {
			if (! _netStream) return 0;
			if (! currentClipStarted()) return 0;
			if (! _started) {
				return 0;
			}
			return getCurrentPlayheadTime(netStream);
		}
		
		/**
		 * @inheritDoc
		 */
		public function get bufferStart():Number {
			return 0;
		}
		
		/**
		 * @inheritDoc
		 */
		public function get bufferEnd():Number {
			if (! _netStream) return 0;
			if (! currentClipStarted()) return 0;
			return Math.min(_netStream.bytesLoaded / _netStream.bytesTotal * clip.durationFromMetadata, clip.duration);
		}

		/**
		 * @inheritDoc
		 */
		public function get fileSize():Number {
			if (! _netStream) return 0;
			if (! currentClipStarted()) return 0;
			return _netStream.bytesTotal;
		}
		
		/**
		 * @inheritDoc
		 */
		public function set volumeController(volumeController:VolumeController):void {
			_volumeController = volumeController;
		}
		
		/**
		 * @inheritDoc
		 */
		public function get stopping():Boolean {
			return _stopping;
		}
		
		/**
		 * @inheritDoc
		 */
		public function getVideo(clip:Clip):DisplayObject {
			var video:Video = new Video();
			video.smoothing = clip.smoothing;
			return video;
		}
		
		/**
		 * @inheritDoc
		 */
		public function attachStream(video:DisplayObject):void {
			Video(video).attachNetStream(_netStream);
		}
		
		/**
		 * @inheritDoc
		 */
		public function get playlist():Playlist {
			return _playlist;
		}
		
		/**
		 * @inheritDoc
		 */
		public function set playlist(playlist:Playlist):void {
			_playlist = playlist;
		}

		/* ---- Methods that can be overridden ----- */
		/* ----------------------------------------- */

		/**
		 * Connects to the backend. The implementation creates a new NetConnection then calls
		 * <code>addConnectionStatusListener(connection)</code> and <code>NetConnection.connect(getConnectUrl(clip))</code>.
		 * 
		 * @see #getConnectUrl()
		 */
		protected function connect(clip:Clip, ... rest):void {
			
			if (_netStream) {
				_netStream.close();
				_netStream = null;
			}
			if (_connection) {
				_connection.close();
				_connection = null;
			}
			
			_connection = new NetConnection();
			_connection.proxyType = "best";
			_connection.client = this;
			addConnectionStatusListener(_connection);
			log.debug("Connecting to " + getConnectUrl(clip));
			
			if (rest.length > 0) {
				_connection.connect(getConnectUrl(clip), rest);
			} else {
				_connection.connect(getConnectUrl(clip));
			}
		}
		
		/**
		 * Adds a connection status listener to the <code>NetConnection</code>.
		 */
		protected final function addConnectionStatusListener(connection:NetConnection):void {
			//connection.addEventListener(NetStatusEvent.NET_STATUS, onConnectionStatus);
			connection.addEventListener(NetStatusEvent.NET_STATUS, _onNetStatus);
		}

		/**
		 * Gets the url used for <code>NetStream.connect(url)</code>. Meant to be overridden by providers that need special
		 * NetConnection URLs. This implementation return's <code>null</code> as required when doing HTTP progressive
		 * download.
		 */
		protected function getConnectUrl(clip:Clip):String {
			return null;
		}

		/**
		 * Starts loading using the specified netStream and clip. Can be overridden in subclasses.
		 * The implementation in this class calls <code>netStream.play(getClipUrl(clip))</code> with the clip's URL.
		 * 
		 * @param event the event that is dispatched after the loading has been successfully
		 * started
		 * @param netStream
		 * @param clip
		 */
		protected function doLoad(event:ClipEvent, netStream:NetStream, clip:Clip):void {
			netStream.client = new NetStreamClient(clip, _config);
			netStream.play(getClipUrl(clip));
		}

		/**
		 * Gets the url when calling <code>NetStream.play(url)</code>. Override this if you need to manipulate the clip's URL.
		 */
		protected function getClipUrl(clip:Clip):String {
			return clip.completeUrl;
		}
		
		/**
		 * Pauses the specified netStream. This implementation calls <code>netStream.pause()</code>
		 * and dispatches the specified event.
		 * 
		 * @param netStream
		 * @param event the event that is dispatched after pausing, is <code>null</code> if
		 * we are pausing silently
		 */
		protected function doPause(netStream:NetStream, event:ClipEvent = null):void {
			if (! netStream) return;
			netStream.pause();
			if (event) {
				dispatchEvent(event);
			}
		}
		
		/**
		 * Resumes the specified netStream. The implementation in this class calls <code>netStream.resume()</code>
		 * and dispatches the specified event.
		 * @param netStream
		 * @param event the event that is dispatched after resuming
		 */		
		protected function doResume(netStream:NetStream, event:ClipEvent):void {
			netStream.resume();
			dispatchEvent(event);
		}
		
		/**
		 * Silent seek mode. When enabled the SEEK event is not dispatched.
		 * @see ClipEventType#SEEK
		 */
		protected final function set silentSeek(value:Boolean):void {
			_silentSeek = value;
			log.info("silent mode was set to " + _silentSeek);
		}
		
		protected final function get silentSeek():Boolean {
			return _silentSeek;
		}

		/**
		 * Are we paused?
		 */
		protected final function get paused():Boolean {
			return _paused;
		}
		
		/**
		 * Seeks the netStream to the specified target. The implementation in this class calls
		 * <code>netStream.seek(seconds)</code>. Override if you need something different.
		 * @param event the event that is dispatched after seeking successfully
		 * @param netStream
		 * @param seconds the seek target position
		 */
		protected function doSeek(event:ClipEvent, netStream:NetStream, seconds:Number):void {
			// the seek event is dispatched when we recevive the seek notification from netStream
			log.debug("calling netStream.seek(" + seconds + ")");
			netStream.seek(seconds);
		}

		/**
		 * Can we dispatch the start event now? This class uses this method every time
		 * before it's about to dispatch the start event. The event is only dispatched
		 * if this method returns <code>true</code>.
		 * 
		 * @return <code>true</code> if the start event can be dispatched
		 * @see ClipEventType#BEGIN
		 */
		protected function canDispatchBegin():Boolean {
			return true;
		}
		
		/**
		 * Can we disppatch the onStreamNotFound ERROR event now? 
		 * @return <code>true</code> if the start event can be dispatched
		 * 
		 * @see ClipEventType#ERROR
		 */
		protected function canDispatchStreamNotFound():Boolean {
			return true;
		}
		
		/**
		 * Dispatches the specified event.
		 */
		protected final  function dispatchEvent(event:ClipEvent):void {
			if (! event) return;
			log.debug("dispatching " + event);
			clip.dispatchEvent(event);
		}

		/**
		 * Called when NetStatusEvents are received.
		 */
		protected function onNetStatus(event:NetStatusEvent):void {
			// can be overridden in subclasses
		}

		/**
		 * Is the playback duration of current clip reached?
		 */
		protected function isDurationReached():Boolean {
			return Math.abs(getCurrentPlayheadTime(netStream) - clip.duration) <= 0.5;
		}
		
		/**
		 * Gets the current playhead time. This should be overridden if the time
		 * is not equl to netStream.time
		 */
		protected function getCurrentPlayheadTime(netStream:NetStream):Number {
			return netStream.time;
		}
		
		/**
		 * The NetStream instance used by this provider.
		 */
		protected final function get netStream():NetStream {
			return _netStream;
		}

		/**
		 * The current clip in the playlist.
		 */
		protected final function get clip():Clip {
			return _playlist.current;
		}
		
		/**
		 * Should we pause on first frame after starting.
		 * @see #load() the load() method has an autoPlay parameter that controls whether we stop on first frame or not
		 */
		protected final function get pauseAfterStart():Boolean {
			return _pauseAfterStart;
		}
		
		protected final function set pauseAfterStart(value:Boolean):void {
			_pauseAfterStart = value;
		}
		
		/**
		 * Have we started streaming the playlist's current clip?
		 */
		protected function currentClipStarted():Boolean {
			return _startedClip == clip;
		}
		
		/**
		 * The NetConnection object.
		 */
		protected function get netConnection():NetConnection {
			return _connection;
		}
		
		/**
		 * Have we already received a NetStream.Play.Start from the NetStream
		 */
		protected function get started():Boolean {
			return _started;
		}
		
		/**
		 * Previous seek target value in seconds.
		 */
		public function get seekTarget():Number {
			return _seekTarget;
		}

		/**
		 * Override this to receive the plugin model.
		 */
		public function onConfig(model:PluginModel):void {
		} 

		/**
		 * Override this to receive the player instance.
		 */
		public function onLoad(player:Flowplayer):void { 
		} 	

		/* ---- Private methods ----- */
		/* -------------------------- */
		
		private function dispatchError(error:ClipError, info:String):void {
			clip.dispatchError(error, info);
		}

		private function _onNetStatus(event:NetStatusEvent):void {
			log.info("_onNetStatus, code: ", event.info.code);
			
			if (_stopping) {
				log.info("_onNetStatus(), _stopping == true and will not process the event any further");
				return;
			}
			
			if (event.info.code == "NetConnection.Connect.Success") {
				createNetStream();
				start(null, clip, _pauseAfterStart);
			} else if (event.info.code == "NetStream.Buffer.Empty") {
				dispatchPlayEvent(ClipEventType.BUFFER_EMPTY);
			}
			else if (event.info.code == "NetStream.Buffer.Full") {
				dispatchPlayEvent(ClipEventType.BUFFER_FULL);
			}
			else if (event.info.code == "NetConnection.Connect.Success") {
				dispatchPlayEvent(ClipEventType.CONNECT);
			}
			else if (event.info.code == "NetStream.Play.Start") {
				if (! _paused && canDispatchBegin()) {
					log.debug("dispatching onBegin");
					clip.dispatchEvent(new ClipEvent(ClipEventType.BEGIN));
				}
			}
			else if (event.info.code == "NetStream.Play.Stop") {
//				dispatchPlayEvent(ClipEventType.STOP);
			}
			else if (event.info.code == "NetStream.Seek.Notify") {
				if (! silentSeek) {
					startSeekTargetWait();
				}
				silentSeek = false;

			} else if (event.info.code == "NetStream.Seek.InvalidTime") {

			} else if (event.info.code == "NetStream.Play.StreamNotFound" || 
				event.info.code == "NetConnection.Connect.Rejected" || 
				event.info.code == "NetConnection.Connect.Failed") {
				
				if (canDispatchStreamNotFound()) {
					clip.dispatchError(ClipError.STREAM_NOT_FOUND, event.info.code);
				}
			}
			
			onNetStatus(event);
		}
		
		private function startSeekTargetWait():void {
			if (_seekTarget < 0) return;
			if (_seekTargetWaitTimer && _seekTargetWaitTimer.running) return;
			log.debug("starting seek target wait timer");
			_seekTargetWaitTimer = new Timer(200);
			_seekTargetWaitTimer.addEventListener(TimerEvent.TIMER, onSeekTargetWait);
			_seekTargetWaitTimer.start();
		}

		private function onSeekTargetWait(event:TimerEvent):void {
			if (time >= _seekTarget) {
				_seekTargetWaitTimer.stop();
				log.debug("dispatching onSeek");
				dispatchPlayEvent(ClipEventType.SEEK, _seekTarget);
				_seekTarget = -1;
			}
		}

		private function dispatchPlayEvent(playEvent:ClipEventType, info:Object = null):void {
			dispatchEvent(new ClipEvent(playEvent, info));
		}
		
		private function doStop(event:ClipEvent, netStream:NetStream, closeStreamAndConnection:Boolean = false):void {
			log.debug("doStop");
			_stopping = true;
			if (closeStreamAndConnection) {
				_startedClip = null;
				log.debug("doStop(), closing netStream and connection");
				netStream.close();
				if (_connection) {
					_connection.close();
					_connection = null;
				}
				clip.setContent(null);
			} else {
				silentSeek = true;
				netStream.client = new NullNetStreamClient();
				netStream.pause();
				netStream.seek(0);
			}
			dispatchEvent(event);
		}

		private function createNetStream():void {
			_netStream = new NetStream(_connection);
			netStream.client = new NetStreamClient(clip, _config);
			_netStream.bufferTime = clip.bufferLength;
			_volumeController.netStream = _netStream;
			_netStream.addEventListener(NetStatusEvent.NET_STATUS, _onNetStatus);
		}

		protected function onMetaData(event:ClipEvent):void {
			log.info("in NetStreamControllingStremProvider.onStart");
			clip.dispatch(ClipEventType.START, _pauseAfterStart);
			// some files require that we seek to the first frame only after receiving metadata
			// otherwise we will never receive the metadata
			if (_pauseAfterStart) {
				log.info("seeking to frame zero");
				seek(null, 0);
				dispatchPlayEvent(ClipEventType.PAUSE);
				_pauseAfterStart = false;
			}
		}

		private function start(event:ClipEvent, clip:Clip, pauseAfterStart:Boolean = false):void {
			log.debug("start called with clip " + clip + ", pauseAfterStart " + pauseAfterStart);

			try {
				doLoad(event, _netStream, clip);
				_started = true;
			} catch (e:SecurityError) {
				dispatchError(ClipError.STREAM_LOAD_FAILED, "cannot access the video file (try loosening Flash security settings): " + e.message);	
			} catch (e:IOError) {
				dispatchError(ClipError.STREAM_LOAD_FAILED, "cannot load the video file, incorrect URL?: " + e.message);
			} catch (e:Error) {
				dispatchError(ClipError.STREAM_LOAD_FAILED, "cannot play video: " + e.message);
			}
			
			if (pauseAfterStart) {
				log.info("pausing to first frame!");
				doPause(_netStream, null);
//				_netStream.seek(0);
			}
		}
		
		public function onBWDone(... rest):void {
		}
	}
}
