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

package org.flowplayer.config {
    import org.flowplayer.controller.ResourceLoader;
import org.flowplayer.flow_internal;
	import org.flowplayer.util.Log;
	
	import com.adobe.serialization.json.JSON;

    use namespace flow_internal;

	/**
	 * @author anssi
	 */
	public class ConfigLoader {
		private static var log:Log = new Log(ConfigLoader);

        flow_internal static function parse(config:String):Object {
            return JSON.decode(config);
        }

        flow_internal static function parseConfig(config:Object, playerSwfName:String, controlsVersion:String, audioVersion:String):Config {
            if (!config) return new Config({}, playerSwfName, controlsVersion, audioVersion);
            var configObj:Object = config is String ? JSON.decode(config as String) : config;
            return new Config(configObj, playerSwfName, controlsVersion, audioVersion);
        }

        flow_internal static function loadConfig(fileName:String, listener:Function, loader:ResourceLoader, playerSwfName:String, controlsVersion:String, audioVersion:String):void {
            loader.load(fileName, function(loader:ResourceLoader):void {
                trace(loader.getContent());
                listener(parseConfig(loader.getContent(), playerSwfName, controlsVersion, audioVersion))
            }, true);
        }
	}
}
