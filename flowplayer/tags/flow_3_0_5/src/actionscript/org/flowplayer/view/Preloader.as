package org.flowplayer.view {
	import flash.display.DisplayObject;
	import flash.display.MovieClip;
	import flash.display.Sprite;
	import flash.display.StageAlign;
	import flash.display.StageScaleMode;
	import flash.events.Event;
	import flash.events.ProgressEvent;
	import flash.text.TextField;
	import flash.text.TextFormat;
	import flash.utils.getDefinitionByName;		

	public class Preloader extends MovieClip {

		private var _app:DisplayObject;
		private var _percent:TextField;

		public function Preloader() {
            stop();
            if (loaderInfo.bytesLoaded == loaderInfo.bytesTotal) {
            	init();
            	return;
            }
            _percent = new TextField();
			var format:TextFormat = new TextFormat();
			format.font = "Lucida Grande, Lucida Sans Unicode, Bitstream Vera, Verdana, Arial, _sans, _serif";
			_percent.defaultTextFormat = format;
			_percent.text = "Loading...";
            addChild(_percent);
            addEventListener(Event.ADDED_TO_STAGE, onAddedToStage);
		}
		
		private function onAddedToStage(event:Event):void {
            loaderInfo.addEventListener(ProgressEvent.PROGRESS, onLoadProgress);
            loaderInfo.addEventListener(Event.COMPLETE, init);
		}

		private function onLoadProgress(event:ProgressEvent):void {
  			var percent:Number = Math.floor((event.bytesLoaded*100) / event.bytesTotal);
            graphics.clear();
        	_percent.text = (percent + "%"); 
            _percent.x = stage.stageWidth / 2 - _percent.textWidth / 2;
            _percent.y = stage.stageHeight / 2 - _percent.textHeight / 2;
   		}
       
        private function init(event:Event = null):void {
        	if (_percent) {
        		removeChild(_percent);
        	}
        	nextFrame();
        	prepareStage();
			var mainClass:Class = Class(getDefinitionByName("org.flowplayer.view.Launcher"));
            _app = new mainClass() as DisplayObject;
			addChild(_app as DisplayObject);
        }

		private function prepareStage():void {
			stage.align = StageAlign.TOP_LEFT;
			stage.scaleMode = StageScaleMode.NO_SCALE;
		}
    }
}
