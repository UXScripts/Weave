/*
    Weave (Web-based Analysis and Visualization Environment)
    Copyright (C) 2008-2011 University of Massachusetts Lowell

    This file is a part of Weave.

    Weave is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License, Version 3,
    as published by the Free Software Foundation.

    Weave is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with Weave.  If not, see <http://www.gnu.org/licenses/>.
*/

package weave.data.AttributeColumns
{
	import flash.utils.Dictionary;
	import flash.utils.getQualifiedClassName;
	
	import mx.formatters.NumberFormatter;
	
	import weave.api.WeaveAPI;
	import weave.api.data.AttributeColumnMetadata;
	import weave.api.data.IPrimitiveColumn;
	import weave.api.data.IQualifiedKey;
	import weave.api.newLinkableChild;
	import weave.api.registerLinkableChild;
	import weave.compiler.StandardLib;
	import weave.core.LinkableString;
	
	/**
	 * SecondaryKeyColumn
	 * 	
	 */
	public class SecondaryKeyNumColumn extends AbstractAttributeColumn implements IPrimitiveColumn
	{
		public function SecondaryKeyNumColumn(metadata:XML = null)
		{
			super(metadata);
			registerLinkableChild(this, secondaryKeyFilter);
		}

		/**
		 * This function overrides the min,max values.
		 */
		override public function getMetadata(propertyName:String):String
		{
			switch (propertyName)
			{
				case AttributeColumnMetadata.MIN: return String(_minNumber);
				case AttributeColumnMetadata.MAX: return String(_maxNumber);
			}
			
			var value:String = super.getMetadata(propertyName);
			
			switch (propertyName)
			{
				case AttributeColumnMetadata.TITLE:
					if (value != null && secondaryKeyFilter.value)
						return value + ' (' + secondaryKeyFilter.value + ')';
					break;
				case AttributeColumnMetadata.KEY_TYPE:
					if (secondaryKeyFilter.value == null)
						return value + TYPE_SUFFIX
					break;
			}
			
			return value;
		}
		
		private var TYPE_SUFFIX:String = ',Year';
		
		private var _minNumber:Number = NaN; // returned by getMetadata
		private var _maxNumber:Number = NaN; // returned by getMetadata
		
		/**
		 * _keyToNumericDataMapping
		 * This object maps keys to data values.
		 */
		protected var _keyToNumericDataMapping:Dictionary = new Dictionary();
		protected var _keyToNumericDataMappingAB:Dictionary = new Dictionary();

		/**
		 * uniqueStrings
		 * Derived from the record data, this is a list of all existing values in the dimension, each appearing once, sorted alphabetically.
		 */
		private var _uniqueStrings:Vector.<String> = new Vector.<String>();

		/**
		 * This is the value used to filter the data.
		 */
		public static const secondaryKeyFilter:LinkableString = new LinkableString();
		
		protected static const _uniqueSecondaryKeys:Array = new Array();
		public static function get secondaryKeys():Array
		{
			return _uniqueSecondaryKeys;
		}

		/**
		 * _uniqueKeys
		 * This is a list of unique keys this column defines values for.
		 */
		protected const _uniqueKeysA:Array = new Array();
		protected const _uniqueKeysAB:Array = new Array();
		override public function get keys():Array
		{
			if (secondaryKeyFilter.value == null) // when no secondary key specified, use the real unique keys
				return _uniqueKeysAB;
			return _uniqueKeysA;
		}

		/**
		 * @param key A key to test.
		 * @return true if the key exists in this IKeySet.
		 */
		override public function containsKey(key:IQualifiedKey):Boolean
		{
			if (_keyToNumericDataMapping[key] == null)
				return false;
			return _keyToNumericDataMapping[key][secondaryKeyFilter.value] != undefined;
		}

		public function updateRecords(keysA:Vector.<IQualifiedKey>, keysB:Vector.<String>, data:Array):void
		{
			if (_uniqueStrings.length > 0)
				throw new Error("Replacing existing records is not supported");
			
			var index:int, qkeyA:IQualifiedKey, keyB:String, qkeyAB:IQualifiedKey;
			var _keyA:*;
			var dataObject:Object = null;

			if (keysA.length > data.length)
			{
				trace("WARNING: keys vector length > data vector length. keys truncated.",keysA.length,data.length);
				keysA.length = data.length; // numericData.length;
			}
			
			// clear previous data mapping
			_keyToNumericDataMapping = new Dictionary();
			
			//if it's string data - create list of unique strings
			if (data[0] is String)
			{
				for (var i:int = 0; i < data.length; i++)
				{
					if (_uniqueStrings.indexOf(data[i]) < 0)
						_uniqueStrings.push(data[i]);
				}
				_uniqueStrings.sort(Array.CASEINSENSITIVE);
				
				// min,max numbers are the min,max indices in the unique strings array
				_minNumber = 0;
				_maxNumber = _uniqueStrings.length - 1; 
			}
			else
			{
				// reset min,max before looping over records
				_minNumber = NaN;
				_maxNumber = NaN;
			}
			
			// save a mapping from keys to data
			//for (index = keysA.length - 1; index >= 0; index--)
			for (index = 0; index < keysA.length; index++)
			{
				qkeyA = keysA[index] as IQualifiedKey;
				keyB = keysB[index] as String;
				qkeyAB = WeaveAPI.QKeyManager.getQKey(qkeyA.keyType + TYPE_SUFFIX, qkeyA.localName + ',' + keyB);
				//if we don't already have keyB - add it to _uniqueKeysB
				//  @todo - optimize this - searching every time is not the optimal method
				if (_uniqueSecondaryKeys.indexOf(keyB) < 0)
					_uniqueSecondaryKeys.push(keyB);
				if (! _keyToNumericDataMapping[qkeyA])
					_keyToNumericDataMapping[qkeyA] = new Dictionary();
				dataObject = data[index];
				if (dataObject is String)
				{
					var iString:int = _uniqueStrings.indexOf(dataObject as String);
					if (iString < 0)
					{
						//iString = _uniqueStrings.push(dataObject as String) - 1;
						iString = _uniqueStrings.length;
						_uniqueStrings[iString] = dataObject as String;
					}
					_keyToNumericDataMapping[qkeyA][keyB] = iString;
					_keyToNumericDataMappingAB[qkeyAB] = iString;
				}
				else
				{
					_keyToNumericDataMapping[qkeyA][keyB] = data[index];//Number(data[index]);
					_keyToNumericDataMappingAB[qkeyAB] = data[index];//Number(data[index]);
					
					_minNumber = isNaN(_minNumber) ? data[index] : Math.min(_minNumber, data[index]);
					_maxNumber = isNaN(_maxNumber) ? data[index] : Math.max(_maxNumber, data[index]);
				}
			}
			
			_uniqueSecondaryKeys.sort();
			
			// save list of unique keys
			index = 0;
			for (_keyA in _keyToNumericDataMapping)
				_uniqueKeysA[index++] = _keyA;
			_uniqueKeysA.length = index; // trim to new size
			
			index = 0;
			for (_keyA in _keyToNumericDataMappingAB)
				_uniqueKeysAB[index++] = _keyA;
			_uniqueKeysAB.length = index; // trim to new size
			
			triggerCallbacks();
		}

		/**
		 * numberFormatter:
		 * the NumberFormatter to use when generating a string from a number
		 */
		private var _numberFormatter:NumberFormatter = new NumberFormatter();

		/**
		 * maxDerivedSignificantDigits:
		 * maximum number of significant digits to return when calling deriveStringFromNorm()
		 */		
		private var maxDerivedSignificantDigits:uint = 10;
		
		// get a string value for a given numeric value
		public function deriveStringFromNumber(number:Number):String
		{
			if (int(number) == number && (_uniqueStrings.length > 0) && (number < _uniqueStrings.length))
				return _uniqueStrings[number];
			
			if (_numberFormatter == null)
				return number.toString();
			else
				return _numberFormatter.format(
					StandardLib.roundSignificant(
							number,
							maxDerivedSignificantDigits
						)
					);
		}

		/**
		 * get data from key value
		 */
		override public function getValueFromKey(qkey:IQualifiedKey, dataType:Class = null):*
		{
			var value:Object = undefined;
			
			if (_keyToNumericDataMappingAB[qkey] || _keyToNumericDataMapping[qkey])
				value = _keyToNumericDataMappingAB[qkey] || _keyToNumericDataMapping[qkey][secondaryKeyFilter.value];
			
			if (dataType == String)
			{
				if (value is String)
					return value;
				else if (value != null)
					return deriveStringFromNumber(Number(value));
				return null;
			}
			
			return StandardLib.asNumber(value);
		}

		override public function toString():String
		{
			return getQualifiedClassName(this).split("::")[1] + '{recordCount: '+keys.length+', keyType: "'+getMetadata('keyType')+'", title: "'+getMetadata('title')+'"}';
		}

	}
}