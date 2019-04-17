package amdb;

import haxe.ds.Vector;
import haxe.Int32;
import haxe.Int64;
import haxe.io.*;
import haxe.extern.EitherType as Or;

import pm.*;
import pm.Arch;

import amdb.SType;
import amdb.Val;

import amdb.Table;
import amdb.tools.Io;

abstract Resultset<T> (AResultset<T>) from AResultset<T> to AResultset<T> {

}

class AResultset<T> {
    public function new() {
        //
    }

    public function get():Iterator<T>;
}

class RowDataResultset extends AResultset<RowData> {
    public var columns: Array<Column>;
    public function new(cols) {
        super();

        columns = cols;
    }
}

class TableQueryResultset extends RowDataResultset {
    public var table: Table;
    private var _get(default, null): Void->Iterator<RowData>;

    public function new(t, fn) {
        super(t.columns.toArray().map(c -> new Column(c.name, c.type)));
        table = t;
        _get = fn;
    }

    override function get():Iterator<RowData> return _get();
}
