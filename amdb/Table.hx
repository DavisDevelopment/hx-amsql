package amdb;

import haxe.ds.Vector;
import haxe.Int32;
import haxe.Int64;
import haxe.DynamicAccess;
import haxe.io.*;
import haxe.extern.EitherType as Or;

import sys.io.*;
//import 

import pm.AVLTree;
import pm.Arch;

import amdb.SType;
import amdb.tools.Io;

class Table {
    /* Constructor Function */
    public function new(init:{columns:Iterable<TableColumnInit>}) {
        setColumns( init.columns );

        for (i in 0...columns.length) {
            if (columns[i].primaryKey) {
                primaryKeyPos = i;
            }
        }

        assert(primaryKeyPos != -1);
        indexes = new Map();
        for (c in columns) {
            indexes[c.name] = new TableIndex({
                column: c,
                sparse: !c.notNull
            });
        }

        
    }

/* === Methods === */

    /**
      get the primary-key value of [row]
     **/
    private inline function primaryKeyOf(row: RowData):Val {
        return row.get( columns[primaryKeyPos].name );
    }

    /**
      prepare [row] to be inserted into [this] Table
     **/
    private function prepareForInsertion(row: RowData):RowData {
        var row = row.clone();

        for (i in 0...columns.length) {
            var col = columns[i];
            var field:Ref<Val> = Ref.to(row[col.name]);


            if (field.value == null)
                field.value = Val.CNil;

            if (field.value.match(CNil) && col.autoIncrement) {
                field.value = _autoIncrementNextVal( col );
            }

            if (field.value.match(CNil)) {
                if ( col.notNull ) {
                    if (col.defaultValue.match(CNil)) {
                        throw new Error('NullConstraintViolated: "${col.name}"');
                    }
                    else {
                        //row.set(i, col.defaultValue.clone());
                        //field = row.get( i );
                        field.value = col.defaultValue.clone();
                    }
                }

            }

            if (!col.type.checkVal(field.value))
                throw new Error('TypeConstraintViolated: ${col.name}');

            row[col.name] = field.get();
        }

        return row;
    }

    static function _autoIncrementNextVal(c: TableColumn):Val {
        var v = c._autoIncrementState;
        @:privateAccess c._autoIncrementState = c.nextAutoIncrementState();
        return v;
    }

    /**
      convert an anonymous object into a RowData
     **/
    private function anonRowData(anon: Dynamic):RowData {
        var values:DynamicAccess<Val> = {};
        for (i in 0...columns.length) {
            values[columns[i].name] = Reflect.hasField(anon, columns[i].name) ? Io.toVal(Reflect.field(anon, columns[i].name)) : Val.CNil;
        }
        return new RowData( values );
    }

    static inline function lookup(idx:TableIndex, key:KeyLookup) {
        return switch key {
            case One(val): nor(idx.getByKey( val ), []);
            case Many(vals): idx.getByKeys( vals );
            case Between(min, max): idx.betweenBounds(min, max);
            case Matches(fn):
                var res = [];
                idx.tree.executeOnEveryNode(function(node) {
                    for (row in node.data)
                        if (fn(row))
                            res.push( row );
                });
                res;
        }
    }

    /**
      look a row up by id
     **/
    public function get(id: KeyLookup):Null<RowData> {
        var idx = indexes[columns[primaryKeyPos].name];
        return lookup(idx, id)[0];
    }

    /**
      query [this] Table where [col]=[val]
     **/
    public function by(col:String, val:KeyLookup):Array<RowData> {
        if (indexes.exists( col )) {
            return lookup(indexes[col], val);
        }
        else {
            throw new Error('Unknown column "$col"');
        }
    }

    public function all(?iterColumn:String):Array<RowData> {
        if (iterColumn == null)
            iterColumn = columns[primaryKeyPos].name;
        return indexes[iterColumn].getAll();
    }

    /**
      insert a row onto [this] Table
     **/
    public function insertOne(row: Dynamic):RowData {
        var row1 = toRow( row );
        var row2 = prepareForInsertion( row1 );

        insertOneIntoCache( row2 );

        return row2;
    }

    public function removeOne(row: RowData) {
        removeOneFromCache( row );
    }

    function removeOneFromCache(row: RowData) {
        for (idx in indexes) {
            idx.removeOne( row );
        }
    }

    /**
      convert a Dynamic value into a [RowData]
     **/
    private function toRow(row: Dynamic):RowData {
        var dat:RowData;
        if ((row is Array<Dynamic>)) {
            var row:Array<Dynamic> = cast row;
            dat = (0...columns.length).map(i -> {key: columns[i].name, value:Io.toVal(row[i])});
        }
        else if (Arch.isObject( row )) {
            dat = anonRowData( row );
        }
        else {
            dat = null;
            throw 'ass';
        }
        return dat;
    }

    /**
      insert an Array of rows onto [this] Table
     **/
    public function insertMany(rows: Array<Dynamic>) {
        for (row in rows) {
            insertOne( row );
        }
    }

    /**
      insert the given [row] into the index-cache
     **/
    private function insertOneIntoCache(row: RowData):Void {
        for (idx in indexes) {
            idx.insertOne( row );
        }
    }

    /**
      assign [columns] from an Iterable of initializer objects
     **/
    private inline function setColumns(columns: Iterable<TableColumnInit>) {
        var ca = columns
            .map(function(c) {
                return {
                    name: c.name,
                    type: c.type,
                    unique: nor(c.unique, false),
                    autoIncrement: nor(c.autoIncrement, false),
                    notNull: nor(c.notNull, false),
                    primaryKey: nor(c.primaryKey, false),
                    defaultValue: nor(c.defaultValue, null)
                };
            })
            .reduce(function(a:Array<TableColumn>, col) {
                var c = new TableColumn(col.name, col.type);
                c.unique = col.unique;
                c.autoIncrement = col.autoIncrement;
                c.notNull = col.notNull;
                c.primaryKey = col.primaryKey;
                c.defaultValue = Io.toVal( col.defaultValue );
                a.push( c );
                return a;
            }, new Array<TableColumn>());
        setColumnsDirect(ca, true);
    }

    /**
      directly assign [columns]
     **/
    private inline function setColumnsDirect(cols:Array<TableColumn>, recalcRowByteLength:Bool=false) {
        columnNameToIndex = new Map();

        this.columns = cols;

        for (i in 0...columns.length) {
            columns[i].offset = i;
            columnNameToIndex[columns[i].name] = i;
        }
    }

    /**
      get a reference to a particular TableColumn
     **/
    public inline function col(n: String):TableColumn {
        assert(columnNameToIndex.exists(n) && columnNameToIndex[n].inRange(0, columns.length));
        return columns[columnNameToIndex[n]];
    }

/* === Variables === */

    public var columns: Array<TableColumn>;
    public var indexes(default, null): Map<String, TableIndex>;

    private var primaryKeyPos: Int = -1;
    private var columnNameToIndex:Map<String, Int>;
}

typedef Ptr<T> = Int32;

typedef TableColumnInit = {
    name: String, 
    type: SType,
    ?unique: Bool,
    ?notNull: Bool,
    ?autoIncrement: Bool,
    ?primaryKey: Bool,
    ?defaultValue: Dynamic
};

@:forward
abstract KeyLookup (EKeyLookup) from EKeyLookup to EKeyLookup {
    @:from public static inline function many(a: Array<Val>):KeyLookup return EKeyLookup.Many( a );
    @:from public static inline function manyd(a: Array<Dynamic>):KeyLookup return EKeyLookup.Many(a.map(Io.toVal));
    @:from public static inline function one(v: Val):KeyLookup return EKeyLookup.One( v );
    @:from public static inline function oned(v: Dynamic):KeyLookup return EKeyLookup.One(Io.toVal( v ));

    @:from public static inline function tester(f: RowData -> Bool):KeyLookup return EKeyLookup.Matches( f );
}

enum EKeyLookup {
    One(key: Val);
    Many(keys: Array<Val>);
    Between(?min:BoundingValue<Val>, ?max:BoundingValue<Val>);

    Matches(fn: RowData -> Bool);
}
