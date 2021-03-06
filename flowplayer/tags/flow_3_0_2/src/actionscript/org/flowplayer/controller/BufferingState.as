/*    
 *    Copyright 2008 Flowplayer Oy
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
	import flash.utils.Dictionary;
	
	import org.flowplayer.controller.PlayListController;
	import org.flowplayer.flow_internal;
	import org.flowplayer.model.Clip;
	import org.flowplayer.model.ClipEvent;
	import org.flowplayer.model.ClipEventSupport;
	import org.flowplayer.model.ClipEventType;
	import org.flowplayer.model.Playlist;
	import org.flowplayer.model.State;
	import org.flowplayer.model.Status;				
	use namespace flow_internal;
	
	/**
	 * @author api
	 */
	internal class BufferingState extends PlayState {
		
		private var _nextStateAfterBufferFull:PlayState;
		
		public function BufferingState(stateCode:State, playList:Playlist, playListController:PlayListController, providers:Dictionary) {
			super(stateCode, playList, playListController, providers);
		}
		
		internal override function play():void {
			log.debug("play()");
			stop();
			playList.current.played = true;
			bufferingState.nextStateAfterBufferFull = playingState;
			if (onEvent(ClipEventType.BEGIN, getMediaController(), [false])) {
				changeState(bufferingState);
			}
		}

		internal override function stopBuffering():void {
			log.debug("stopBuffering() called");
			stop();
			getMediaController().stopBuffering();
		}

		internal override function pause():void {
			if (onEvent(ClipEventType.PAUSE)) {
				changeState(pausedState);
			}
		}

		override protected function setEventListeners(eventSupport:ClipEventSupport, add:Boolean = true):void {
			if (add) {
				eventSupport.onBufferFull(moveState);
				eventSupport.onPause(moveState);
				eventSupport.onError(onError);
			} else {
				eventSupport.unbind(moveState);
				eventSupport.unbind(onError);
			}
		}

		private function onError(event:ClipEvent):void {
			getMediaController().onEvent(ClipEventType.STOP);
		}

		private function moveState(event:ClipEvent):void {
			log.debug("moving to state " + _nextStateAfterBufferFull);
			playListController.setPlayState(_nextStateAfterBufferFull);
		}

		public function set nextStateAfterBufferFull(nextState:PlayState):void {
			this._nextStateAfterBufferFull = nextState;
		}

		internal override function get status():Status {
			return getMediaController().getStatus(state);
		}
	}
}
