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
    import flash.display.DisplayObject;
    import flash.display.MovieClip;
    import flash.display.StageAlign;
    import flash.display.StageScaleMode;
    import flash.events.Event;
    import flash.events.ProgressEvent;
    import flash.events.TimerEvent;
    import flash.utils.Timer;
    import flash.utils.getDefinitionByName;

    import org.flowplayer.util.Arrange;

    public class Preloader extends MovieClip {

        private var _app:DisplayObject;
        private var _initTimer:Timer;
        private var _rotation:RotatingAnimation;

        public function Preloader() {
            stop();
            if (checkLoaded()) return;
            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
        }

        private function get rotationEnabled():Boolean {
            var config:Object = stage.loaderInfo.parameters["config"];
            if (! config) return true;
            if (config.replace(/\s/g, "").indexOf("buffering:null") > 0) return false;
            return true;
        }

        private function checkLoaded():Boolean {
            if (loaderInfo.bytesLoaded == loaderInfo.bytesTotal) {
                init();
                return true;
            }
            return false;
        }
		
		private function onAddedToStage(event:Event):void {
            trace("added to stage");
            prepareStage();
            if (rotationEnabled) {
                _rotation = new RotatingAnimation();
                addChild(_rotation);
                _rotation.setSize(stage.stageWidth * 0.22, stage.stageHeight * 0.22);
                Arrange.center(_rotation, stage.stageWidth, stage.stageHeight);
                _rotation.start();
            }

            if (checkLoaded()) return;
            loaderInfo.addEventListener(ProgressEvent.PROGRESS, onLoadProgress);
            loaderInfo.addEventListener(Event.COMPLETE, init);
		}

		private function onLoadProgress(event:ProgressEvent):void {
            if (checkLoaded()) return;
  			var percent:Number = Math.floor((event.bytesLoaded*100) / event.bytesTotal);
            graphics.clear();
            trace("percent " + percent);
   		}
       
        private function init(event:Event = null):void {
            trace("init");
            prepareStage();
            if (_initTimer) {
                _initTimer.stop();
            }
            if (_app) return;
            
            nextFrame();
            if (_rotation) {
                _rotation.stop();
                removeChild(_rotation);
            }
            try {
                var mainClass:Class = Class(getDefinitionByName("org.flowplayer.view.Launcher"));
                _app = new mainClass() as DisplayObject;
                addChild(_app as DisplayObject);
                trace("Launcher instantiated and added to frame " + currentFrame);
            } catch (e:Error) {
                trace("error instantiating Launcher " + e + ": " + e.message);
                if (! _initTimer) {
                    trace("starting init timer");
                    _app = null;
                    prevFrame();
                    _initTimer = new Timer(300);
                    _initTimer.addEventListener(TimerEvent.TIMER, function(e:TimerEvent):void { init(); });
                }
                _initTimer.start();
                if (_rotation) {
                    addChild(_rotation);
                    _rotation.start();
                }
            }
        }

		private function prepareStage():void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
		}
    }
}
