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

package org.flowplayer.model {
	import flash.events.Event;		

	/**
	 * @author anssi
	 */
	public class PluginEvent extends AbstractEvent {

		public static const PLUGIN_EVENT:String = "onPluginEvent";
		
		private var _id:String;

		public function PluginEvent(eventType:PluginEventType, id:String = null, info:Object = null) {
			super(eventType, info);
			_id = id;
		}

		public override function clone():Event {
			return new PluginEvent(eventType as PluginEventType, _id, info);
		}

		public override function toString():String {
			return formatToString("PluginEvent", "callbackId", "info");
		}

		/**
		 * Same as Id. Preserved here for backward compatibility.
		 */
		public function get callbackId():String {
			return _id;
		}
		
		/**
		 * Gets the event Id.
		 */
		public function get id():String {
			return _id;
		}

		protected override function get externalEventArgument():Object {
			return info;
		}

		protected override function get externalEventArgument2():Object {
			return _id;
		}
	}
}
