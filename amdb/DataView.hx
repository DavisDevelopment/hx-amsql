package amdb;

import haxe.io.*;

#if sys
import sys.io.*;
import sys.FileSystem;
#end

@:forward
abstract DataView (IDataView) from IDataView {
    @:noUsing
    public static inline function file(path: String):DataView {
        return new FileDataView(File.read(path, true), File.update(path, true));
    }

    /**
      read `len` bytes into `s`, and write them into the position specified by `pos`
     **/
    public function readBytes(s:Bytes, pos:Int, len:Int):Int {
        var k:Int = len;
        var b:BytesData = 
            #if (js || hl) 
            @:privateAccess s.b
            #else
            s.getData() 
            #end;
        if (pos < 0 || len < 0 || pos + len > s.length) {
            throw Error.OutsideBounds;
        }
        try {
            while (k > 0) {
                #if neko
                    untyped __dollar__sset(b,pos, this.readUInt8());
                #elseif php
                    b.set(pos, this.readUInt8());
                #elseif cpp
                    b[pos] = untyped this.readUInt8();
                #else
                    b[pos] = cast this.readUInt8();
                #end

                ++pos;
                --k;
            }
        }
        catch (eof: haxe.io.Eof) {
            //
        }

        return len-k;
    }

    public function readHunk(data:Bool = true):Hunk {
        var res:Hunk = {
            type: this.readInt32()
        };
        if (data) {
            var size = this.readInt32();
            res.data = readBytes(Bytes.alloc(size), 0, size);
            assert(res.data.length == size, haxe.io.Eof);
        }
        return res;
    }
}


class FileDataView implements IDataView {
    var i: Null<sys.io.FileInput> = null;
    var o: Null<sys.io.FileOutput> = null;
    var sel: Bool = false;

    public function new(?i, ?o) {
        this.i = i;
        this.o = o;
    }

    public inline function totalLength():Int {
        throw 'NotImplemented';
    }

    public function tell():Int {
        return sel ? o.tell() : i.tell();
    }

    public function seek(pos:Int, seek:SeekPos) {
        (sel ? o.seek : i.seek)(pos, switch seek {
            case Begin: FileSeek.SeekBegin;
            case Cur: FileSeek.SeekCur;
            case End: FileSeek.SeekEnd;
        });
    }

    public function truncate(size: Int) throw 'NotImplemented';
    public function close():Void {
        if (i != null)
            i.close();
        if (o != null)
            o.close();
    }

    inline function focus(s: Bool) {
        if (s != sel) {
            sel = s;
            swapped();
        }
    }

    inline function swapped() {
        if ( sel ) {
            o.seek(i.tell(), FileSeek.SeekBegin);
        }
        else {
            i.seek(o.tell(), FileSeek.SeekBegin);
        }
    }

    public function readUInt8():Int {
        return i.readByte();
    }
    public function readInt8():Int {focus(false); return i.readInt8();}
    public function readInt32():Int {
        focus(false);
        return i.readInt32();
    }
    //public function readInt64():Int {
        //focus(false);
        //return i.readInt64();
    //}
    public function writeUInt8(i: Int) {
        focus(true);
        return o.writeByte( i );
    }

    public function writeInt8(i: Int){
        focus(true);
        return o.writeInt8(i);
    }

    public function writeInt32(i: Int){
        focus(true);
        return o.writeInt32(i);
    }
    //public function writeInt64(i: Int){focus(true);return o.writeInt64(i);}
}

interface IInput {
    //function readBit():Bool;
    function readUInt8():Int;
    function readInt8():Int;
    function readInt32():Int;
    //function readInt64():Int64;
}

interface IOutput {
    function writeUInt8(v: Int):Void;
    function writeInt8(v: Int):Void;
    function writeInt32(v: Int):Void;
    //function writeInt64(v: Int):Void;
}

interface IDataView extends IInput extends IOutput {
    function totalLength():Int;
    function tell():Int;
    function seek(pos:Int, seek:SeekPos):Void;
    function truncate(size: Int):Void;
    function close():Void;
}

enum SeekPos {
    Begin;
    Cur;
    End;
}
