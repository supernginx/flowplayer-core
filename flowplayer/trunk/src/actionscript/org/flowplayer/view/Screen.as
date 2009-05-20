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
package org.flowplayer.view {
	import org.flowplayer.controller.MediaController;
	import org.flowplayer.flow_internal;
	import org.flowplayer.model.Clip;
	import org.flowplayer.model.ClipEvent;
	import org.flowplayer.model.ClipEventSupport;
	import org.flowplayer.model.ClipType;
	import org.flowplayer.model.DisplayProperties;
	import org.flowplayer.model.MediaSize;
	import org.flowplayer.model.PlayButtonOverlay;
	import org.flowplayer.model.Playlist;
	import org.flowplayer.util.Arrange;
	import org.flowplayer.util.Log;
	import org.flowplayer.view.MediaDisplay;

	import flash.display.DisplayObject;
	import flash.events.Event;
	import flash.events.FullScreenEvent;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;

	use namespace flow_internal;

	internal class Screen extends AbstractSprite {

		private var _displayFactory:MediaDisplayFactory;
		private var _displays:Dictionary;
		private var _resizer:ClipResizer;
		private var _playList:Playlist;
		private var _prevClip:Clip;
		private var _fullscreenManaer:FullscreenManager;
		private var _animatioEngine:AnimationEngine;
		private var _pluginRegistry:PluginRegistry;

		public function Screen(playList:Playlist, animationEngine:AnimationEngine, play:PlayButtonOverlay, pluginRegistry:PluginRegistry) {
            _displays = new Dictionary();
			_displayFactory = new MediaDisplayFactory(playList);
			_resizer = new ClipResizer(playList, this);
			createDisplays(playList.clips.concat(playList.childClips));
			addListeners(playList);
			_playList = playList;
			_animatioEngine = animationEngine;
			_pluginRegistry = pluginRegistry;
		}

		private function createDisplays(clips:Array):void {
			for (var i:Number = 0; i < clips.length; i++) {
				var clip:Clip = clips[i];
				if (! clip.isNullClip) {
					createDisplay(clip);
				}
			}
		}

        private function createDisplay(clip:Clip):void {
            var display:DisplayObject = _displayFactory.createMediaDisplay(clip);
            display.width = this.width;
            display.height = this.height;
            display.visible = false;
            addChild(display);
            log.debug("created display " + display);
            _displays[clip] = display;
        }

		public function set fullscreenManager(manager:FullscreenManager):void {
			_fullscreenManaer = manager;
		}

		protected override function onResize():void {
			log.debug("onResize " + Arrange.describeBounds(this));
			_resizer.setMaxSize(width, height);
			// we need to resize the previous clip because it might be the stopped image that we are currently showing
			resizeClip(_playList.previousClip);
			resizeClip(_playList.current);
			arrangePlay();
		}

		private function get play():DisplayProperties {
			return DisplayProperties(_pluginRegistry.getPlugin("play"));
		}

		internal function arrangePlay():void {
			if (playView) {
				playView.setSize(play.dimensions.width.toPx(this.width), play.dimensions.height.toPx(this.height));
				Arrange.center(playView, width, height);
				if (playView.parent == this) {
					setChildIndex(playView, numChildren-1);
				}
			}
		}

		private function get playView():AbstractSprite {
			if (! play) return null;
			return play.getDisplayObject() as AbstractSprite;
		}

		private function resizeClip(clip:Clip):void {
			if (! clip) return;
			if (! clip.getContent()) {
				log.warn("clip does not have content, cannot resize. Clip " + clip);
			}
			if (clip && clip.getContent()) {
				if (_fullscreenManaer.isFullscreen) {
					var nonHwScaled:MediaSize = clip.scaling == MediaSize.ORIGINAL ? MediaSize.FITTED_PRESERVING_ASPECT_RATIO : clip.scaling;
					_resizer.resizeClipTo(clip, clip.accelerated ? MediaSize.ORIGINAL : nonHwScaled);
				} else {
					_resizer.resizeClipTo(clip, clip.scaling);
				}
			}
		}

		// resized is called when the clip has been resized
		internal function resized(clip:Clip):void {
			var disp:DisplayObject = _displays[clip];
            log.debug("resized " + clip + ", display " + disp);
            disp.width = clip.width;
			disp.height = clip.height;
			if (clip.accelerated && _fullscreenManaer.isFullscreen) {
				log.debug("in hardware accelerated fullscreen, will not center the clip");
				disp.x = 0;
				disp.y = 0;
				return;
			}
			Arrange.center(disp, width, height);
			log.debug("resized() " + Arrange.describeBounds(this));
			log.info("display of clip " +clip+ " arranged to  " + Arrange.describeBounds(disp));
		}

		public function getDisplayBounds():Rectangle {
			var clip:Clip = _playList.current;
			var disp:DisplayObject = _displays[clip];
			if (! disp) {
				return fallbackDisplayBounds();
			}
			if (! disp.visible && _prevClip) {
				clip = _prevClip;
				disp = _displays[clip];
			}
			if (! (disp && disp.visible)) {
				return fallbackDisplayBounds();
			}
			if (clip.width > 0) {
				var result:Rectangle = new Rectangle(disp.x, disp.y, clip.width, clip.height);
				log.debug("disp size is " + result.width + " x " + result.height);
				return result;
			} else {
				return fallbackDisplayBounds();
			}
		}

		private function fallbackDisplayBounds():Rectangle {
			return new Rectangle(0, 0, stage.stageWidth, stage.stageHeight);
		}

		public function set mediaController(controller:MediaController):void {
		}

		private function showDisplay(event:ClipEvent):void {
			log.info("showDisplay()");
			var clipNow:Clip = event.target as Clip;
			if (clipNow.isNullClip) return;
			setDisplayVisible(clipNow, true);
			_prevClip = clipNow;
			log.info("showDisplay done");
		}

		private function setDisplayVisible(clipNow:Clip, visible:Boolean):void {
			var disp:DisplayObject = _displays[clipNow];
			log.debug("display " + disp + ", " + disp.name + ", will be made " + (visible ? "visible" : "hidden"));
			if (visible) {
				MediaDisplay(disp).init(clipNow);
				disp.visible = true;
				disp.alpha = 0;
				log.debug("starting fadeIn for " + disp);
				_animatioEngine.animateProperty(disp, "alpha", 1, clipNow.fadeInSpeed);
				Arrange.center(disp, width, height);
			} else if (disp.visible) {
				_animatioEngine.animateProperty(disp, "alpha", 0, clipNow.fadeOutSpeed, function():void { disp.visible = false; });
				return;
			}
		}

        private function onPlaylistChanged(event:ClipEvent):void {
            log.info("onPlaylistChanged()");
            _prevClip = null;
            removeDisplays(ClipEventSupport(event.info).clips);
            createDisplays(Playlist(event.target).clips);
        }

        private function onClipAdded(event:ClipEvent):void {
            log.info("onClipAdded(): " + event.info + ", " + event.info2);
            var clip:Clip = event.info2 ? event.info2 as Clip : ClipEventSupport(event.target).clips[event.info] as Clip;
            log.debug("added clip " + clip);
            createDisplay(clip);
        }

		private function removeDisplays(clips:Array):void {
			for (var i:Number = 0; i < clips.length; i++) {
				removeChild(_displays[clips[i]]);
			}
		}

		private function addListeners(eventSupport:ClipEventSupport):void {
            eventSupport.onPlaylistReplace(onPlaylistChanged);
            eventSupport.onClipAdd(onClipAdded);
			eventSupport.onBufferFull(onBufferFull);

			eventSupport.onBegin(onBegin);
            eventSupport.onStart(onStart);
            eventSupport.onResume(onResume);

            var oneShot:Function = function(clip:Clip):Boolean { return clip.isOneShot; };
            eventSupport.onStop(removeOneShotDisplay, oneShot);
            eventSupport.onFinish(removeOneShotDisplay, oneShot);
		}

        private function removeOneShotDisplay(event:ClipEvent):void {
            log.debug("removing display of a one shot clip " + event.target);
            removeChild(_displays[event.target]);
            delete _displays[event.target];
        }

        private function onBegin(event:ClipEvent):void {
            var clip:Clip = event.target as Clip;
            if (clip.metaData == false) {
                log.info("onBegin: clip.metaData == false, showing it");
                handleStart(clip, event.info as Boolean);
            }
            if (clip.getContent() && clip.metaData) {
                handleStart(clip, event.info as Boolean );
            }
        }

        private function onStart(event:ClipEvent):void {
            var clip:Clip = event.target as Clip;
            if (clip.metaData == false) return;
            handleStart(clip, event.info as Boolean);
        }

        private function onResume(event:ClipEvent):void {
            var clip:Clip = event.target as Clip;
            setDisplayVisibleIfHidden(clip);
            
            var shown:Array = [_displays[clip]];
            if (onAudioWithRelatedImage(clip)) {
                shown.push(_displays[_playList.previousClip]);
            }
            hideAllDisplays(shown);
        }

        private function handleStart(clip:Clip, pauseAfterStart:Boolean):void {
            if (clip.isNullClip) return;
            log.debug("handleStart(), previous clip " + _playList.previousClip);
            if (pauseAfterStart && _playList.previousClip && _playList.previousClip.type == ClipType.IMAGE) {
                log.debug("autoBuffering next clip on a splash image, will not show next display");
                setDisplayVisibleIfHidden(_playList.previousClip);
                if (clip.type == ClipType.AUDIO && clip.image) return;

                clip.onResume(onFirstFrameResume);
                return;
            }

            if (_playList.previousClip && clip.type == ClipType.AUDIO) {
                if (onAudioWithRelatedImage(clip)) {
                    setDisplayVisibleIfHidden(_playList.previousClip);
                } else {
                    hideAllDisplays();
                }
                _prevClip = clip;
                return;
            }
            
            setDisplayVisibleIfHidden(clip);
            hideAllDisplays([_displays[clip]]);
        }

        private function onAudioWithRelatedImage(clip:Clip):Boolean {
            if (! _playList.previousClip) return false;
            if (clip.type != ClipType.AUDIO) return false;
            return _playList.previousClip.type == ClipType.IMAGE && _playList.previousClip.image;
        }

		private function setDisplayVisibleIfHidden(clip:Clip):void {
			var disp:DisplayObject = _displays[clip];
			if (disp.alpha < 1 || ! disp.visible) {
				setDisplayVisible(clip, true);
			}
		}

		private function hideAllDisplays(except:Array = null):void {
			var clips:Array = _playList.clips.concat(_playList.childClips);
			for (var i:Number = 0; i < clips.length; i++) {
				var clip:Clip = clips[i] as Clip;
				var disp:MediaDisplay = _displays[clip];
				if (disp && (! except || except.indexOf(disp) < 0)) {
					setDisplayVisible(clips[i] as Clip, false);
				}
			}
		}

		private function onFirstFrameResume(event:ClipEvent):void {
			var clip:Clip = event.target as Clip;
			clip.unbind(onFirstFrameResume);
			showDisplay(event);
		}

		private function onBufferFull(event:ClipEvent):void {
			var clipNow:Clip = event.target as Clip;
			if (clipNow.type == ClipType.IMAGE) {
				showDisplay(event);
			}
			if (clipNow.type == ClipType.VIDEO) {
				var disp:MediaDisplay = _displays[clipNow];
                if (! disp) return;
				disp.init(clipNow);

				if (clipNow.live) {
					showDisplay(event);
				}
			}
		}

		internal function hidePlay():void {
			if (playView.parent == this) {
				removeChild(playView);
			}
		}

		internal function showPlay():void {
			log.debug("showPlay");
			addChild(playView);
			playView.visible = true;
			playView.alpha = play.alpha;

			arrangePlay();
			log.debug("play bounds: " + Arrange.describeBounds(playView));
			log.debug("play parent: " + playView.parent);
		}
	}
}
