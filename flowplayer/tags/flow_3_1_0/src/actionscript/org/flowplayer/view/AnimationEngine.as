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
	import org.flowplayer.flow_internal;
	import org.flowplayer.layout.LengthMath;
	import org.flowplayer.model.DisplayProperties;
	import org.flowplayer.util.Assert;
	import org.flowplayer.util.Log;
	import org.flowplayer.view.Animation;
	import org.flowplayer.view.Panel;
	import org.goasap.events.GoEvent;
	import org.goasap.interfaces.IPlayable;
	import org.goasap.utils.PlayableGroup;
	
	import flash.display.DisplayObject;
	import flash.geom.Rectangle;
	import flash.utils.Dictionary;			
	use namespace flow_internal;
	
	/**
	 * AnimationAngine is used to animate DisplayProperties. 
	 * 
	 */
	public class AnimationEngine {

		private var log:Log = new Log(this);
		private var _panel:Panel;
		private var _pluginRegistry:PluginRegistry;
		private var _runningPlayablesByView:Dictionary = new Dictionary();
		private var _canceledByPlayable:Dictionary = new Dictionary();
		public function AnimationEngine(panel:Panel, pluginRegistry:PluginRegistry) {
			_panel = panel;
			_pluginRegistry = pluginRegistry;
		}
		
		/**
		 * Animates a DisplayObject according to supplied properties. 
		 * 
		 * If the supplied display object is a plugin, the properties can contain relative values and percentage values.
		 * A relative value specifies a new position relative
		 * to the plugin's current position. For example:
		 * <code>
		 * 		animations.animate("content", { top: "+20px", left: "-20%", width: 90 });
		 * </code>
		 * Here we animate the content plugin so that the top position is increased by 20 pixels, left position is decreased by 20%,
		 * and the width is set to 90 pixels. Following display properties can be animated with relative and absolute, pixel based
		 * and percentage values:
		 * <ul>
		 * <li>left</li>
		 * <li>right</li>
		 * <li>top</li>
		 * <li>bottom</li>
		 * <li>width</li>
		 * <li>height</li>
		 * </ul>
		 * <p>
		 * The <code>opacity</code> property only supports absolute numeric values.
		 * </p>
		 * <p>
		 * All changes made to the plugin's display propertites are stored into the PluginRegistry
		 * </p>
		 * 
		 * @param pluginName the name of the plugin to animate, the plugin is looked up from the PluginRegistry using this name
		 * @param props an object containing display properties
		 * @param durationMillis the duration it takes for the animation to complete
		 * @param endCallback a function to be called when the animation is complete
		 * @see #animate()
		 * @see PluginRegistry
		 */
		public function animate(disp:DisplayObject, props:Object, durationMillis:int = 400, endCallback:Function = null):DisplayProperties {
			var currentProps:DisplayProperties = _pluginRegistry.getPluginByDisplay(disp);
			var isPlugin:Boolean = currentProps != null;
			if (isPlugin) {
				log.debug("animating plugin " + currentProps);
			} else {
				log.debug("animating non-plugin displayObject " + disp);
			}
			
			
			if (isPlugin) {
				var newProps:DisplayProperties = props is DisplayProperties ? props as DisplayProperties : LengthMath.sum(currentProps, props, _panel.stage);
				log.debug("current dimensions " + currentProps.dimensions);
				disp.visible = newProps.visible;
				if (disp.visible) {
					panelAnimate(currentProps.getDisplayObject(), newProps, durationMillis, endCallback);
				} else {
					_panel.removeChild(disp);
				}
				_pluginRegistry.updateDisplayProperties(newProps);
			} else {
				startTweens(disp, alpha(props), props.width, props.height, props.x, props.y, durationMillis, endCallback);
			}
			return newProps;
		}

		flow_internal function animateNonPanel(parent:DisplayObject, disp:DisplayObject, props:Object, durationMillis:int = 400, endCallback:Function = null):DisplayProperties {
			log.debug("animateNonPanel", props);
			var currentProps:DisplayProperties = _pluginRegistry.getPluginByDisplay(disp);
			var newProps:DisplayProperties = props is DisplayProperties ? props as DisplayProperties : LengthMath.sum(currentProps, props, parent);
			startTweens(disp, alpha(props), props.width, props.height, props.x, props.y, durationMillis, endCallback);
			return newProps;
		}
		
		private function alpha(props:Object):Number {
			if (props.hasOwnProperty("alpha")) return props["alpha"];
			if (props.hasOwnProperty("opacity")) return props["opacity"];
			return NaN;
		}

		/**
		 * Animates a single DisplayObject property.
		 * @param view the display object to animate 
		 */
		public function animateProperty(view:DisplayObject, propertyName:String, target:Number, durationMillis:int = 500, callback:Function = null):void {
			var props:Object = new Object();
			props[propertyName] = target;
			animate(view, props, durationMillis, callback);
		}

		/**
		 * Fades in a DisplayObject.
		 */
		public function fadeIn(view:DisplayObject, durationMillis:Number = 500, callback:Function = null, updatePanel:Boolean = true):Animation {
			return animateAlpha(view, 1, durationMillis, callback, updatePanel);
		}

		/**
		 * Fades a DisplayObject to a specified alpha value.
		 */
		public function fadeTo(view:DisplayObject, alpha:Number, durationMillis:Number = 500, callback:Function = null, updatePanel:Boolean = true):Animation {
			return animateAlpha(view, alpha, durationMillis, callback, updatePanel);
		}

		/**
		 * Fades out a DisplayObject.
		 */
		public function fadeOut(view:DisplayObject, durationMillis:Number = 500, callback:Function = null, updatePanel:Boolean = true):Animation {
			return animateAlpha(view, 0, durationMillis, callback, updatePanel);
		}

		/**
		 * Cancels all animations that are currently running for the specified view. The callbacks specified in animation calls
		 * are not invoked for canceled animations.
		 * @param currentAnimation if specified all other animations except the specified one will be canceled
		 */
		public function cancel(view:DisplayObject, currentAnimation:Animation = null):void {
			log.debug("cancel");
			for (var viewObj:Object in _runningPlayablesByView) {
				var viewWithRunningAnimation:DisplayObject = viewObj as DisplayObject;
				if (viewWithRunningAnimation == view) {
					var anim:Animation = _runningPlayablesByView[viewWithRunningAnimation] as Animation;
					
					if (anim && currentAnimation && anim != currentAnimation) {
						if (currentAnimation.tweenProperty == anim.tweenProperty) {
							log.info("tween for property " + anim.tweenProperty + " was canceled on view " + view);
							_canceledByPlayable[anim] = true;
							anim.stop();
						}
					}
				}
			}
		}

		private function animateAlpha(view:DisplayObject, target:Number, durationMillis:Number = 500, callback:Function = null, updatePanel:Boolean = true):Animation {
			Assert.notNull(view, "animateAlpha: view cannot be null");
			var playable:Animation = createTween("alpha", view, target, durationMillis);
			if (! playable) {
				if (callback != null) {
					callback();
				}
				return null;
			}

			// cancel previous alpha animations
			cancel(view, playable);

			var plugin:DisplayProperties = _pluginRegistry.getPluginByDisplay(view);
			if (updatePanel && plugin) {
				log.debug("animateAlpha(): will add/remove from panel");
				// this is a plugin, add/remove it from a panel
				if (target == 0) {
					playable.addEventListener(GoEvent.COMPLETE, 
						function(event:GoEvent):void {
							if (!_canceledByPlayable[playable]) { 
								log.debug("removing " + view + " from panel");
								view.parent.removeChild(view);
							} else {
								log.info("previous fadeout was canceled, will not remove " + view + " from panel");
							}
						});
				} else if (view.parent != _panel) {
					_panel.addView(view);
				}
			} else {
				log.debug("animateAlpha, view is not added/removed from panel");
			}
			 
			var tween:Animation = start(view, playable, callback) as Animation;
			if (tween) {
				_pluginRegistry.updateDisplayPropertiesForDisplay(view, { alpha: target, display: (target == 0 ? "none" : "block") });
			}
			return tween;
		}

		private function panelAnimate(view:DisplayObject, props:DisplayProperties, durationMillis:int = 500, callback:Function = null):void {
			Assert.notNull(props.name, "displayProperties.name must be specified");
			log.debug("animate " + view);
			if (view.parent != _panel) {
				_panel.addView(view);
			}
			var target:Rectangle = _panel.update(view, props);
			startTweens(view, props.alpha, target.width, target.height, target.x, target.y, durationMillis, callback);			
			if (durationMillis == 0) {
				if (props.alpha >= 0) {
					view.alpha = props.alpha;
				}
				_panel.draw(view);
			}
		}
		
		private function startTweens(view:DisplayObject, alpha: Number, width:Number, height:Number, x:Number, y:Number, durationMillis:int, callback:Function):Array {
			var tweens:Array = new Array();
			
			var alphaTween:Animation = createTween("alpha", view, alpha, durationMillis);
			if (alphaTween) {
				cancel(view, alphaTween); 
				addTween(tweens, alphaTween);
			}
			
			addTween(tweens, createTween("width", view, width, durationMillis));
			addTween(tweens, createTween("height", view, height, durationMillis));
			addTween(tweens, createTween("x", view, x, durationMillis));
			addTween(tweens, createTween("y", view, y, durationMillis));
			if (tweens.length == 0) {
				// call the callback also when not animating anything
				if (callback != null) {
					callback();
				}
				return tweens;
			}
			var playable:IPlayable = tweens.length > 1 ? new PlayableGroup(tweens) : tweens[0];
			start(view, playable, callback);
			return tweens;
		}

		private function addTween(tweens:Array, tween:IPlayable):void {
			if (! tween) return;
			log.debug("will animate " + tween);
			tweens.push(tween);
		}

		private function start(view:DisplayObject, playable:IPlayable, callback:Function = null):IPlayable {
			if (playable == null) return null;
			_runningPlayablesByView[view] = playable; 
			log.debug("staring animation " + playable);

			playable.addEventListener(GoEvent.COMPLETE, 
				function(event:GoEvent):void {
					onComplete(view, playable, callback); 
			});

			playable.start();
			return playable;
		}
		
		private function onComplete(view:DisplayObject, playable:IPlayable, callback:Function = null):void {
			if (callback != null && !_canceledByPlayable[playable]) {
				callback();
			}
			
			delete _canceledByPlayable[playable];
			delete _runningPlayablesByView[view];
		}

		private function createTween(property:String, view:DisplayObject, targetValue:Number, durationMillis:int):Animation {
			if (isNaN(targetValue)) return null;
			if (view[property] == targetValue) {
				log.debug("view property " + property + " already in target value " + targetValue + ", will not animate");
				return null;
			}
			log.debug("creating tween for property " + property + ", target value is " + targetValue + ", current value is " + view[property]);
			return new Animation(view, property, targetValue, durationMillis);
		}
	}
}
