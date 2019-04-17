package amdb;

import haxe.ds.Vector;
import haxe.Int32;
import haxe.Int64;
import haxe.io.*;
import haxe.extern.EitherType as Or;

import sys.io.*;
//import 

import pm.AVLTree;
import pm.AVLTree as Tree;
import pm.AVLTree.AVLTreeNode as Leaf;
import pm.Arch;

import amdb.SType;
import amdb.Table;
import amdb.tools.Io;

/**
  class used to index data along particular columns
 **/
class TableIndex {
    public function new(o: TableIndexInit) {
        column = o.column;
        sparse = o.sparse;

        tree = new Tree({
            unique: column.unique,
            compareKeys: (a, b) -> _cmp(a, b)
        });
    }

/* === Methods === */

    public function insertOne(row: RowData):Void {
        var key:Val = keyOf( row );
        if (key.equals(CNil) && !sparse) {
            throw new Error('IndexError: Missing "${column.name}" column');
        }
        tree.insert(key, row);
    }

    public function removeOne(row: RowData):Void {
        var key:Val = keyOf( row );
        if (key.equals(CNil)) {
            if ( sparse )
                return ;
            else
                throw new Error('IndexError');
        }
        tree.delete(key, row);
    }

    public function updateOne(oldRow:RowData, newRow:RowData):Void {
        removeOne( oldRow );
        try {
            insertOne( newRow );
        }
        catch (e: Dynamic) {
            insertOne( oldRow );
            throw e;
        }
    }

    /**
      insert many [RowData] instances onto [this]
     **/
    public function insertMany(rows: Array<RowData>) {
        try {
            for (i in 0...rows.length) {
                try {
                    insertOne( rows[i] );
                }
                catch (e: Dynamic) {
                    throw new IndexRollback(e, i);
                }
            }
        }
        catch (rollback: IndexRollback) {
            for (i in 0...rollback.failingIndex) {
                removeOne(rows[i]);
            }

            throw rollback.error;
        }
    }

    public function removeMany(rows: Array<RowData>) {
        for (row in rows) {
            removeOne( row );
        }
    }

    public function updateMany(updates: Array<{oldRow:RowData, newRow:RowData}>) {
        var revert = [];
        for (update in updates) {
            try {
                updateOne(update.oldRow, update.newRow);
                revert.push( update );
            }
            catch (e: Dynamic) {
                revertUpdates( revert );
                throw e;
            }
        }
        revert = [];
    }

    public function revertUpdates(updates: Array<{oldRow:RowData, newRow:RowData}>) {
        updates = updates.map(u -> {oldRow:u.newRow, newRow:u.oldRow});
        updateMany( updates );
    }

    public function getByKey(key: Val):Null<Array<RowData>> {
        return tree.get( key );
    }

    public function getByKeys(keys: Array<Val>):Array<RowData> {
        var res = [];
        for (key in keys) {
            switch (getByKey( key )) {
                case null:
                    continue;

                case items:
                    Arrays.append(res, items);
            }
        }
        return res;
    }

    public function betweenBounds(?min:BoundingValue<Val>, ?max:BoundingValue<Val>):Array<RowData> {
        return tree.betweenBounds(min, max);
    }

    public function getAll():Array<RowData> {
        var res = [];
        tree.executeOnEveryNode(function(node) {
            Arrays.append(res, node.data);
        });
        return res;
    }

    public inline function size():Int {
        return tree.size();
    }

    inline function keyOf(row: RowData):Val {
        return row.get( column.name );
    }

    function _cmp(a:Val, b:Val):Int {
        //return Arch.compareEnumValues(a, b);
        return inline a.compare( b );
    }

/* === Variables === */

    public var tree(default, null): Tree<Val, RowData>;
    public var sparse(default, null): Bool = false;

    private var column(default, null): TableColumn;
}

typedef TableIndexInit = {
    column: TableColumn,
    sparse: Bool
};

class IndexRollback {
    public var error: Dynamic;
    public var failingIndex: Int;

    public inline function new(e, i) {
        error = e;
        failingIndex = i;
    }
}
