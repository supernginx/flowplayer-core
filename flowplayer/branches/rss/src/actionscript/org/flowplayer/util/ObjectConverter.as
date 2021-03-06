package org.flowplayer.util {
	import flash.utils.describeType;
import flash.utils.getQualifiedClassName;
	
	public class ObjectConverter {
		private var _input:Object;

		public function ObjectConverter(value:*) {
			_input = value;
		}
		
		public function convert():Object {
			return process(_input);
		}
		
		private function process(value:*):Object {
			if (value is String) {
				return value;
			} else if ( value is Number ) {
				return value;
			} else if ( value is Boolean ) {
				return value;
			} else if ( value is Array ) {
				return convertArray(value as Array);
			} else if ( value is Object && value != null ) {
				return convertObject(value);
			}
            return value;
		}
		
		private function convertArray(a:Array):Array {
			var arr:Array = new Array();
			for (var i:int = 0; i < a.length; i++) {
				arr.push(process(a[i]));	
			}
			return arr;
		}
		
		private function convertObject(o:Object):Object {
			var obj:Object = new Object();
			var classInfo:XML = describeType(o);
			
			if (classInfo.@name.toString() == "Object") {
				var value:Object;
				for (var key:String in o) {
					value = o[key];
					if (value != null && !(value is Function)) {
						obj[key] = value;
					}
				}
			} else { // o is a class instance
				// Loop over all of the *annotated* variables and accessors in the class and convert
				var exposed:XMLList = classInfo.*.(hasOwnProperty("metadata") && metadata.@name=="Value");
				for each (var v:XML in exposed) {
					if (o[v.@name] != null) {
						var key2:String = v.metadata.arg.@key == "name" ? v.metadata.arg.@value : v.@name.toString();
						obj[key2] = process(o[v.@name]);
					}
				}
				
			}
			return obj;
		}

		
	}
	
}
