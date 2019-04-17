package amdb.tools;

import pm.Assert.assert;
//import polygonal.ds.tools.MathTools;

//using polygonal.ds.tools.NativeArrayTools;

using amdb.tools.Bits;

class BitVector {
	/**
		A unique identifier for this object.
		
		A hash table transforms this key into an index of an array element by using a hash function.
	**/
	public var key(default, null):Int = pm.HashKey.next();
	
	/**
		The total number of bits that the bit-vector can store.
	**/
	public var numBits(default, null):Int = 0;
	
	/**
		The total number of 32-bit integers allocated for storing the bits.
	**/
	public var arrSize(default, null):Int = 0;
	
	private var mData : Array<Int>;
	
	/**
		Creates a bit-vector capable of storing a total of `numBits` bits.
	**/
	public function new(numBits: Int) {
		assert(numBits > 0);
		
		mData = null;
		resize( numBits );
	}
	
	/**
		Destroys this object by explicitly nullifying the array storing the bits.
	**/
	public function free() {
		mData = null;
	}
	
	/**
		The total number of bits set to one.
	**/
	public function ones():Int {
		var c = 0, d = mData;
		for (i in 0...arrSize) c += d.get(i).ones();
		return c;
	}
	
	/**
		Returns true if the bit at index `i` is 1.
	**/
	public inline function has(i: Int):Bool {
		assert(i < numBits, 'i index out of range ($i)');
		
		return ((mData.get(i >> 5) & (1 << (i & (32 - 1)))) >> (i & (32 - 1))) != 0;
	}
	
	/**
		Sets the bit at index `i` to one.
	**/
	public inline function set(i: Int):BitVector {
		assert(i < numBits, 'i index out of range ($i)');
		
		var p = i >> 5, d = mData;
		d.set(p, d.get(p) | (1 << (i & (32 - 1))));
		return this;
	}
	
	/**
		Sets the bit at index `i` to zero.
	**/
	public inline function clear(i: Int) {
		assert(i < numBits, 'i index out of range ($i)');
		
		var p = i >> 5, d = mData;
		d.set(p, d.get(p) & (~(1 << (i & (32 - 1)))));
	}
	
	/**
		Sets all bits in the bit-vector to zero.
	**/
	public inline function clearAll():BitVector {
		var d = mData;
		for (i in 0...arrSize) d.set(i, 0);
		return this;
	}
	
	/**
		Sets all bits in the bit-vector to one.
	**/
	public inline function setAll():BitVector {
		var d = mData;
		for (i in 0...arrSize) d.set(i, -1);
		return this;
	}
	
	/**
		Clears all bits in the range [`min`, `max`).
		
		This is faster than clearing individual bits by using `this.clear()`.
	**/
	public function clearRange(min:Int, max:Int):BitVector {
		assert(min >= 0 && min <= max && max < numBits, 'min/max out of range ($min/$max)');
		
		var current = min, binIndex, nextBound, mask, d = mData;
		while (current < max) {
			binIndex = current >> 5;
			nextBound = (binIndex + 1) << 5;
			mask = -1 << (32 - nextBound + current);
			mask &= (max < nextBound) ? -1 >>> (nextBound - max) : -1;
			d.set(binIndex, d.get(binIndex) & ~mask);
			current = nextBound;
		}
		return this;
	}
	
	/**
		Sets all bits in the range [`min`, `max`).
		
		This is faster than setting individual bits by using `this.set()`.
	**/
	public function setRange(min:Int, max:Int):BitVector
	{
		assert(min >= 0 && min <= max && max < numBits, 'min/max out of range ($min/$max)');
		
		var current = min;
		while (current < max)
		{
			var binIndex = current >> 5;
			var nextBound = (binIndex + 1) << 5;
			var mask = -1 << (32 - nextBound + current);
			mask &= (max < nextBound) ? -1 >>> (nextBound - max) : -1;
			mData.set(binIndex, mData.get(binIndex) | mask);
			current = nextBound;
		}
		return this;
	}
	
	/**
		Sets the bit at index `i` to one if `cond` is true or clears the bit at index `i` if `cond` is false.
	**/
	public inline function ofBool(i:Int, cond:Bool):BitVector
	{
		cond ? set(i) : clear(i);
		return this;
	}
	
	/**
		Returns the bucket at index `i`.
		
		A bucket is a 32-bit integer for storing bit flags.
	**/
	public inline function getBucketAt(i:Int):Int
	{
		assert(i >= 0 && i < arrSize, 'i index out of range ($i)');
		
		return mData.get(i);
	}
	
	/**
		Writes all buckets to `out`.
		
		A bucket is a 32-bit integer for storing bit flags.
		@return the total number of buckets.
	**/
	public inline function getBuckets(out:Array<Int>):Int
	{
		var d = mData;
		for (i in 0...arrSize) out[i] = d.get(i);
		return arrSize;
	}
	
	/**
		Resizes the bit-vector to `numBits` bits.
		
		Preserves existing values if new size > old size.
	**/
	public function resize(numBits:Int):BitVector
	{
		if (this.numBits == numBits) return this;
		
		var newArrSize = numBits >> 5;
		if ((numBits & (32 - 1)) > 0) newArrSize++;
		
		if (mData == null || newArrSize < arrSize)
		{
			mData = NativeArrayTools.alloc(newArrSize);
			mData.zero(0, newArrSize);
		}
		else
		if (newArrSize > arrSize)
		{
			var t = NativeArrayTools.alloc(newArrSize);
			t.zero(0, newArrSize);
			mData.blit(0, t, 0, arrSize);
			mData = t;
		}
		else
		if (numBits < this.numBits)
			mData.zero(0, newArrSize);
		
		this.numBits = numBits;
		arrSize = newArrSize;
		return this;
	}
	
	/**
		Writes the data in this bit-vector to a byte array.
		
		The number of bytes equals `this.bucketSize()` × 4 and the number of bits equals `numBits`.
		@param bigEndian the byte order (default is little endian)
	**/
	public function toBytes(bigEndian:Bool = false):haxe.io.BytesData
	{
		#if flash
		var out = new flash.utils.ByteArray();
		if (!bigEndian) out.endian = flash.utils.Endian.LITTLE_ENDIAN;
		for (i in 0...arrSize)
			out.writeInt(mData.get(i));
		return out;
		#else
		var out = new haxe.io.BytesOutput();
		out.bigEndian = bigEndian;
		for (i in 0...arrSize)
			out.writeInt32(mData.get(i));
		return out.getBytes().getData();
		#end
	}
	
	/**
		Copies the bits from `bytes` into this bit vector.
		
		The bit-vector is resized to the size of `bytes`.
		@param bigEndian the input byte order (default is little endian)
	**/
	public function ofBytes(bytes:haxe.io.BytesData, bigEndian:Bool = false)
	{
		#if flash
		var input = bytes;
		input.position = 0;
		if (!bigEndian) input.endian = flash.utils.Endian.LITTLE_ENDIAN;
		#else
		var input = new haxe.io.BytesInput(haxe.io.Bytes.ofData(bytes));
		input.bigEndian = bigEndian;
		#end
		
		var k =
		#if neko
		neko.NativeString.length(bytes);
		#elseif js
		bytes.byteLength;
		#else
		bytes.length;
		#end
		
		var numBytes = k & 3;
		var numIntegers = (k - numBytes) >> 2;
		arrSize = numIntegers + (numBytes > 0 ? 1 : 0);
		numBits = arrSize << 5;
		mData = NativeArrayTools.alloc(arrSize);
		for (i in 0...arrSize) mData.set(i, 0);
		for (i in 0...numIntegers)
		{
			#if flash
			mData.set(i, input.readInt());
			#elseif cpp
			mData.set(i, (cast input.readInt32()) & 0xFFFFFFFF);
			#else
			mData.set(i, cast input.readInt32());
			#end
		}
		var index:Int = numIntegers << 5;
		for (i in 0...numBytes)
		{
			var b = input.readByte();
			for (j in 0...8)
			{
				if ((b & 1) == 1) set(index);
				b >>= 1;
				index++;
			}
		}
	}
	
	/**
		Prints out all elements.
	**/
	#if !no_tostring
	public function toString():String
	{
		var b = new StringBuf();
		b.add('[ BitVector numBits=$numBits');
		if (ones() == 0)
		{
			b.add(" ]");
			return b.toString();
		}
		b.add("\n");
		var args = new Array<Dynamic>();
		var fmt = '  %${MathTools.numDigits(arrSize)}d -> %.32b\n';
		for (i in 0...arrSize)
		{
			args[0] = i;
			args[1] = mData.get(i);
			b.add(Printf.format(fmt, args));
		}
		b.add("]");
		return b.toString();
	}
	#end
	
	/**
		Creates a copy of this bit vector.
	**/
	public function clone():BitVector
	{
		var copy = new BitVector(numBits);
		mData.blit(0, copy.mData, 0, arrSize);
		return copy;
	}
}
