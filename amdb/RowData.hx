package amdb;

import haxe.ds.Vector;
import haxe.Int32;
import haxe.Int64;
import haxe.io.*;
import haxe.extern.EitherType as Or;
import haxe.DynamicAccess;

import sys.io.*;
//import 

import pm.AVLTree;
import pm.Arch;

import amdb.SType;
import amdb.Val;
import amdb.tools.Io;

@:forward
abstract RowData (RowDataClass) from RowDataClass to RowDataClass {
    /* Constructor Function */
    public inline function new(vals: DynamicAccess<Val>) {
        this = new RowDataClass( vals );
    }

/* === Methods === */

    @:arrayAccess
    public inline function get(n: String):Val {
        return this.get( n );
    }

    @:arrayAccess
    public inline function set(n:String, v:Val):Val {
        this.set(n, v);
        return v;
    }

    public inline function clone():RowData {
        return this.clone();
    }

    @:to
    public inline function toString():String {
        return this.toString();
    }

    @:to
    public inline function toArray():Array<Val> {
        return this.toArray();
    }

    @:from
    public static inline function fromValAnon(a: DynamicAccess<Val>):RowData {
        return new RowData( a );
    }
    @:from 
    public static inline function fromAnon(a: DynamicAccess<Dynamic>):RowData {
        return new RowData(a.keyValueIterator().map(x -> {key:x.key, value:Io.toVal(x.value)}).reduce(function(o:DynamicAccess<Val>, e) {
            o[e.key] = e.value;
            return o;
        }, {}));
    }

    @:from
    public static function fromValMap(m: Map<String, Val>):RowData {
        return fromKeyValItr(m.keyValueIterator());
    }

    @:from
    public static function fromKeyValItr(it: KeyValueIterator<String, Val>):RowData {
        return fromValAnon(
            it.reduce(
                function(anon:DynamicAccess<Val>, e) {
                    anon[e.key] = e.value;
                    return anon;
                },
                new DynamicAccess<Val>()
            )
        );
    }

    @:from
    public static function fromKeyAnyItr(it: KeyValueIterator<String, Dynamic>):RowData {
        return fromKeyValItr(it.map(x -> {key:x.key, value:Io.toVal(x.value)}));
    }
}

class RowDataClass {
    /* Constructor Function */
    public function new(o:DynamicAccess<Val>) {
        d = o;
    }

/* === Methods === */

    /**
      look up a value
     **/
    public inline function get(n: String):Val {
        return d[n];
    }

    /**
      look up a value
     **/
    public inline function getv(n: String):Dynamic {
        return Vals.getValue(get( n ));
    }

    /**
      assign a value
     **/
    public inline function set(n:String, v:Val) {
        d[n] = v;
    }

    /**
      assign a value
     **/
    public inline function setv(n:String, v:Dynamic) {
        set(n, Io.toVal( v ));
    }

    public inline function has(name: String):Bool {
        return d.exists( name );
    }

    public inline function del(name: String):Bool {
        return d.remove( name );
    }

    public inline function keys():Array<String> {
        return d.keys();
    }

    public inline function iterator():Iterator<Val> {
        return d.iterator();
    }

    public inline function keyValueIterator():KeyValueIterator<String, Val> {
        return d.keyValueIterator();
    }

    public function clone():RowDataClass {
        var d:DynamicAccess<Val> = new DynamicAccess<Val>();
        for (key=>value in this.d.keyValueIterator()) {
            d[key] = value.clone();
        }
        return new RowDataClass( d );
    }

    /**
      convert [this] to an array of values
     **/
    public function toArray():Array<Val> {
        return [for (name in d.keys()) get(name)];
    }

    /**
      convert [this] to a human-readable String
     **/
    public function toString():String {
        //return '(' + toArray().map(x -> '$x').join(', ') + ')';
        return '(' + keyValueIterator().map(function(e) {
            return '${e.key}=${e.value}';
        }).reduce(function(a:Array<String>, pair) {
            a.push( pair );
            return a;
        }, []).join(', ') + ')';
    }

/* === Fields === */

    public var d: DynamicAccess<Val>;
}
