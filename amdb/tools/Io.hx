package amdb.tools;

import haxe.ds.Vector;
import haxe.Int32;
import haxe.Int64;
import haxe.io.*;
import haxe.extern.EitherType as Or;

import sys.io.*;
import pm.Arch;

import amdb.Table;
import amdb.SType;
import amdb.Val;

class Io {
    public static function toVal(dat: Dynamic):Val {
        if ((dat is Val))
            return cast(dat, Val);
        else {
            if (Arch.isNull(dat)) return Val.CNil;
            if (Arch.isInt(dat)) return Val.CInt(cast(dat, Int));
            if (Arch.isFloat(dat)) return Val.CFloat(cast(dat, Float));
            if (Arch.isString(dat)) return Val.CText(cast(dat, String));

            throw new Error('Invalid $dat');
        }
    }

    public static function readHunk(input:Input, readData:Bool=true):Hunk {
        var res:Hunk = {
            type: input.readInt32()
        };
        if ( readData ) {
            var size = input.readInt32();
            res.data = input.read( size );
        }
        return res;
    }

    public static function writeHunkData(output:Output, type:Int32, data:Or<Bytes, Input>):Void {
        output.writeInt32( type );
        if ((data is Bytes)) {
            var d:Bytes = cast(data, Bytes);
            output.writeInt32( d.length );
            output.write( d );
        }
        else if ((data is Input)) {
            var d:Input = cast(data, Input);
            var dat:Bytes = d.readAll();
            output.writeInt32( dat.length );
            output.write( dat );
        }
        else {
            output.writeInt32( 0 );
        }
        output.flush();
    }

    public static inline function writeHunk(output:Output, hunk:Hunk):Void {
        writeHunkData(output, hunk.type, hunk.data);
    }

    public static inline function makeHunk(type:Int32, fn:Output->Void):Hunk {
        var res:Hunk = {type: type};
        var o:BytesOutput = new BytesOutput();
        fn( o );
        res.data = o.getBytes();
        if (res.data.length == 0)
            res.data = null;
        return res;
    }

    public static inline function readIn(b: Bytes):Input {
        return new BytesInput( b );
    }

    public static inline function readString(i: Input):String {
        return i.readString(i.readInt32(), Encoding.UTF8);
    }

    public static inline function writeString(o:Output, s:String) {
        o.writeInt32( s.length );
        o.writeString(s, Encoding.UTF8);
        o.flush();
    }

    public static inline function readEnumValueParams(i:Input):Null<Array<Dynamic>> {
        var val:Dynamic = haxe.Unserializer.run(readString(i));
        if (val == null)
            return cast val;
        else
            return cast(val, Array<Dynamic>);
    }

    public static inline function writeEnumValueParams(o:Output, params:Null<Array<Dynamic>>) {
        var enc = haxe.Serializer.run( params );
        writeString(o, enc);
    }

    public static inline function readEnumValue<E>(i:Input, enumType:Enum<E>):E {
        return enumType.createByName(readString(i), readEnumValueParams(i));
    }

    public static inline function writeEnumValue(o:Output, value:EnumValue):Void {
        writeString(o, value.getName());
        writeEnumValueParams(o, value.getParameters());
    }

    public static function readBoolean(i: Input):Bool {
        return switch (i.readByte()) {
            case 0: false;
            case 1: true;
            case other: throw new Error('Unexpected $other');
        }
    }

    public static inline function writeBoolean(o:Output, b:Bool):Void {
        o.writeByte(b ? 1 : 0);
        o.flush();
    }

    public static function readTableHeader(input: Input):{columns:Array<TableColumnInit>, rowCount:Int32} {
        var root:Hunk = readHunk(input, true);
        assert(root.type == TableHeaderType.HeaderRoot);
        input = readIn( root.data );
        var cols = readTableColumns( input );
        var count = input.readInt32();
        return {
            columns: cols,
            rowCount: count
        };
    }

    public static function readTableColumns(input: Input):Array<TableColumnInit> {
        var h:Hunk = readHunk(input, true);
        assert(h.type == TableHeaderType.ColumnInfo);
        input = readIn( h.data );

        var count:Int = input.readInt32();
        var res:Array<TableColumnInit> = Arrays.alloc( count );
        for (i in 0...count) {
            var c = res[i] = {
                name: readString(input),
                type: readEnumValue(input, SType)
            };
            c.primaryKey = readBoolean( input );
            c.autoIncrement = readBoolean( input );
            c.notNull = readBoolean( input );
            c.unique = readBoolean( input );
        }
        return res;
    }
}

typedef Hunk = {
    type: Int32,
    ?data: Null<Bytes>
};

enum abstract TableHeaderType (Int32) from Int32 to Int32 {
    var HeaderRoot = 0x000;
    var ColumnInfo;
    var RowInfo;
}
