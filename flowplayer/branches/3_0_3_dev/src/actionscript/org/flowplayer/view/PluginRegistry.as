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
	import org.flowplayer.controller.NetStreamControllingStreamProvider;	
	import org.flowplayer.model.DisplayPluginModel;	
	import org.flowplayer.model.Cloneable;
	import org.flowplayer.model.DisplayProperties;
	import org.flowplayer.model.Plugin;
	import org.flowplayer.model.PluginModel;
	import org.flowplayer.model.ProviderModel;
	import org.flowplayer.util.Assert;
	import org.flowplayer.util.Log;
	import org.flowplayer.util.PropertyBinder;
	
	import flash.display.DisplayObject;
	import flash.utils.Dictionary;		

	/**
	 * @author api
	 */
	public class PluginRegistry {

		private var log:Log = new Log(this);
		private var _plugins:Dictionary = new Dictionary();
		private var _originalProps:Dictionary = new Dictionary();
		private var _providers:Dictionary = new Dictionary();
		private var _fonts:Array = new Array();
		private var _panel:Panel;
		private var _flowPlayer:FlowplayerBase;

		public function PluginRegistry(panel:Panel) {
			_panel = panel;
		}
		
		/**
		 * Gets all plugins.
		 * @return the plugins keyed by the plugin name
		 */
		public function get plugins():Dictionary {
			return _plugins;
		}
		
		/**
		 * Gets all providers.
		 * @return the providers keyed by the plugin name
		 */
		public function get providers():Dictionary {
			return _providers;
		}

		/**
		 * Gets a plugin by it's name.
		 * @return the plugin mode, this is a clone of the current model and changes made
		 * to the returned object are not reflected to the copy stored in this registrty
		 */
		public function getPlugin(name:String):Object {
			var plugin:Object = _plugins[name] || _providers[name];
			log.debug("found plugin " + plugin);
			if (plugin is DisplayProperties) {
				updateZIndex(plugin as DisplayProperties);
			}
			return clone(plugin);
		}
		
		private function updateZIndex(props:DisplayProperties):void {
			var zIndex:int = _panel.getZIndex(props.getDisplayObject());
			if (zIndex >= 0) {
				props.zIndex = zIndex;
			}
		}

		private function clone(obj:Object):Object {
			return obj && obj is Cloneable ? Cloneable(obj).clone() : obj;
		}

		/**
		 * Gets plugin's model corresponding to the specified DisplayObject.
		 * @param disp the display object whose model is looked up
		 * @param return the display properties, or <code>null</code> if a plugin cannot be found
		 */
		public function getPluginByDisplay(disp:DisplayObject):DisplayProperties {
			for each (var plugin:DisplayProperties in _plugins) {
				if (plugin.getDisplayObject() == disp) {
					updateZIndex(plugin);
					return plugin;
				}
			}
			return null;
		}

		/**
		 * Gets all FontProvider plugins.
		 * @return an array of FontProvider instances configured or loaded into the player
		 * @see FontProvider
		 */
		public function get fonts():Array {
			return _fonts;
		}

		/**
		 * Gets the original display properties. The original values were the ones
		 * configured for the plugin or as the ones specified when the plugin was loaded.
		 * @param pluginName
		 * @return a clone of the original display properties, or <code>null</code> if there is no plugin
		 * corresponding to the specified name
		 */
		public function getOriginalProperties(pluginName:String):DisplayProperties {
			return clone(_originalProps[pluginName]) as DisplayProperties;
		}

		internal function registerFont(fontFamily:String):void {
			_fonts.push(fontFamily);
		} 

		internal function registerDisplayPlugin(plugin:DisplayProperties, view:DisplayObject):void {
			plugin.setDisplayObject(view);
			_plugins[plugin.name] = plugin;
			_originalProps[plugin.name] = plugin.clone();
		}
		
		internal function removePlugin(plugin:PluginModel):void {
            if (! plugin) return;
			delete _plugins[plugin.name];
			delete _originalProps[plugin.name];
			delete _providers[plugin.name];
			
			if (plugin is DisplayPluginModel) {
				_panel.removeChild(DisplayPluginModel(plugin).getDisplayObject());
			}
		}
		
		public function updateDisplayProperties(props:DisplayProperties, updateOriginalProps:Boolean = false):void {
			Assert.notNull(props.name, "displayProperties.name cannot be null");
			var view:DisplayObject = DisplayProperties(_plugins[props.name]).getDisplayObject();
			if (view) {
				props.setDisplayObject(view);
			}
			_plugins[props.name] = props.clone();
			if (updateOriginalProps) {
				_originalProps[props.name] = props.clone();
			}
		}
		
		internal function updateDisplayPropertiesForDisplay(view:DisplayObject, updated:Object):void {
			var props:DisplayProperties = getPluginByDisplay(view);
			if (props) {
				new PropertyBinder(props).copyProperties(updated);
				updateDisplayProperties(props);
			}
		}

		internal function registerProvider(model:ProviderModel, provider:Object):void {
			_providers[model.name] = model;
		}
		
		internal function onLoad(flowPlayer:FlowplayerBase):void {
			_flowPlayer = flowPlayer;
			setPlayerToPlugins(_plugins);
			setPlayerToPlugins(_providers);
		}
		
		private function setPlayerToPlugins(plugins:Dictionary):void {
			for each (var model:Object in plugins) {
				setPlayerToPlugin(model);
			}
		}
		
		internal function setPlayerToPlugin(plugin:Object):void {
			var pluginObj:Object;
			try {
				if (plugin is DisplayProperties) {
					pluginObj = DisplayProperties(plugin).getDisplayObject(); 
				} else {
					pluginObj = ProviderModel(plugin).getProviderObject(); 
				}
				if (pluginObj is NetStreamControllingStreamProvider) {
					log.debug("setting player to " + pluginObj);
					NetStreamControllingStreamProvider(pluginObj).player = _flowPlayer as Flowplayer;
				} else {
					pluginObj["onLoad"](_flowPlayer);
				}
				log.debug("onLoad() successfully executed for plugin " + plugin);
			} catch (e:Error) {
				if (pluginObj is Plugin) {
					throw e;
				}
				log.warn("was not able to initialize player to plugin: " + e.message);
			}
		}

		internal function addPluginEventListener(listener:Function):void {
			for each (var model:Object in _plugins) {
				if (model is PluginModel) {
					PluginModel(model).onPluginEvent(listener);
				}
			}
		}
	}
}
