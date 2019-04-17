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

@:forward(columns, entries)
abstract Collection (CollectionObject) from CollectionObject to CollectionObject {
    public function pluck(cols: Array<String>):Collection {

    }
}

interface CollectionObject {
    var columns: Array<Column>;

    function entries():Iterator<RowData>;
}

class BaseCollectionObject implements CollectionObject {
    public var columns: Array<Column>;
    public function entries():Iterator<RowData> {
        throw '_';
    }
}

