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
	import org.flowplayer.controller.MediaController;
	import org.flowplayer.controller.PlayTimeTracker;
	import org.flowplayer.flow_internal;
	import org.flowplayer.model.Clip;
	import org.flowplayer.model.ClipEvent;
	import org.flowplayer.model.ClipEventType;
	import org.flowplayer.model.Playlist;
	import org.flowplayer.model.State;
	import org.flowplayer.model.Status;
	import org.flowplayer.util.Log;
	
	import flash.events.TimerEvent;		
	use namespace flow_internal;
	/**
	 * @author anssi
	 */
	internal class AbstractDurationTrackingController implements MediaController {

		protected var log:Log = new Log(this);
		protected var durationTracker:PlayTimeTracker;
		private var _volumeController:VolumeController;
		private var _playlist:Playlist;

		public function AbstractDurationTrackingController(volumeController:VolumeController, playlist:Playlist) {
			_volumeController = volumeController;
			_playlist = playlist;
		}

		public final function onEvent(event:ClipEventType, params:Array = null):void {
			if (event == ClipEventType.BEGIN) {
				load(new ClipEvent(event), clip, params ? params[0] : false);
			} else {
				if (event == ClipEventType.PAUSE) {
					pause(new ClipEvent(event));
				} else if (event == ClipEventType.RESUME) {
					resume(new ClipEvent(event));
				} else if (event == ClipEventType.STOP) {
					stop(event ? new ClipEvent(event) : null, params[0]);
				} else if (event == ClipEventType.SEEK) {
					seekTo(new ClipEvent(event), params[0]);
				}
			}
		}

		public final function stopBuffering():void {
			doStopBuffering();
		}
		
		protected final function dispatchPlayEvent(event:ClipEvent):void {
			clip.dispatchEvent(event);
		}

		public final function getStatus(state:State):Status {
//			if (! clip) return new Status(state, clip, 0, 0, 0, 0, _volumeController.muted, _volumeController.volume, false);
			return new Status(state, clip, time, bufferStart, bufferEnd, fileSize, _volumeController.muted, _volumeController.volume, allowRandomSeek);
		}

		private function createDurationTracker(clip:Clip):void {
			if (durationTracker) {
				durationTracker.stop();
			}
			durationTracker = new PlayTimeTracker(clip, this);
			durationTracker.addEventListener(TimerEvent.TIMER_COMPLETE, durationReached);
			durationTracker.start();
		}

		public function get time():Number {
			if (!durationTracker) return 0;
			var time:Number = durationTracker.time;
			return Math.min(time, clip.duration);
		}

		protected function get bufferStart():Number {
			return 0;
		}

		protected function get bufferEnd():Number {
			return 0;
		}

		protected function get fileSize():Number {
			return 0;
		}

		protected function get allowRandomSeek():Boolean {
			return false;
		}

		private final function durationReached(event:TimerEvent):void {
			log.info("durationReached()");
			durationTracker.removeEventListener(TimerEvent.TIMER_COMPLETE, durationReached);
			onDurationReached();
			if (clip.duration > 0) {
				log.debug("dispatching FINISH from durationTracking");
				clip.dispatchBeforeEvent(new ClipEvent(ClipEventType.FINISH));
			}
		}
		
		protected function onDurationReached():void {
		}

		private function load(event:ClipEvent, clip:Clip, pauseAfterStart:Boolean = false):void {
			clip.onPause(onPause);
			createDurationTracker(clip);
			doLoad(event, clip, pauseAfterStart);
		}

		private function onPause(event:ClipEvent):void {
			durationTracker.stop();
		}

		private function pause(event:ClipEvent):void {
			durationTracker.stop();
			doPause(event);
		}

		private function resume(event:ClipEvent):void {
			if (durationTracker && durationTracker.durationReached) {
				log.debug("resume(): duration has been reached");
				return;
			}
			durationTracker.start();
			doResume(event);
		}

		private function stop(event:ClipEvent, closeStream:Boolean):void {
			log.debug("stop " + durationTracker);
			if (durationTracker) {
				durationTracker.stop();
				durationTracker.time = 0;
			}
			doStop(event, closeStream);
		}

		private function seekTo(event:ClipEvent, seconds:Number):void {
			doSeekTo(event, seconds);
			durationTracker.time = seconds;
		}
		
		protected function get clip():Clip {
			return _playlist.current;
		}
		
		protected function get playlist():Playlist {
			return _playlist;
		}

		// FOLLOWING METHODS SHOULD BE OVERRIDDEN IN SUBCLASSES:
		// The mimimum ilmemetation dispatches the event passed in the first parameter.
		
		protected function doLoad(event:ClipEvent, clip:Clip, pauseAfterStart:Boolean = false):void {
		}
		
		protected function doPause(event:ClipEvent):void {
		}
		
		protected function doResume(event:ClipEvent):void {
		}
		
		protected function doStop(event:ClipEvent, closeStream:Boolean):void {
		}
		
		protected function doSeekTo(event:ClipEvent, seconds:Number):void {
		}
		
		protected function doStopBuffering():void {
		}
	}
}
