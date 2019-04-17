package amdb;

import haxe.io.*;

import haxe.extern.EitherType as Or;
import pm.AVLTree;
import pm.Arch;

import amdb.SType;
import amdb.Table;
import amdb.ast.Query;
import amdb.tools.Io;
import amdb.sql.SqlParser;
import amdb.vm.QueryPlan;
import amdb.vm.QueryCompiler;
import amdb.vm.ISelectable.ColumnLike;

using amdb.SType;

@:access(am.db.SqlParser)
class Database {
    /* Constructor Function */
    public function new(init: DbInit) {
        mTbls = new Map();
        mFlags = {
            lazyLoadTables: false
        };

        var pat = ~/([A-Za-z_]+[0-9A-Za-z_]*)\s*:\s*([A-Za-z_]+[0-9A-Za-z_]*)/gm;
        for (name=>tableInit in init.tables) {
            var cols:Array<Dynamic> = tableInit.columns;
            var columns:Array<TableColumnInit> = Arrays.alloc(cols.length);
            for (i in 0...cols.length) {
                var c = cols[i];
                if ((c is String)) {
                    var c:String = c;
                    if (pat.match( c )) {
                        switch ([pat.matched(1), stype(pat.matched(2))]) {
                            case [column_name, column_type] if (!column_name.empty() && (column_type is SType)):
                                columns[i] = {name:column_name, type:column_type};

                            default:
                                throw new Error('Invalid column initializer');
                        }
                    }
                    else {
                        switch SqlParser.readTableCreateEntry( c ) {
                            case CreateTableEntry.TableField( field ):
                                columns[i] = {
                                    name: field.name,
                                    unique: field.unique,
                                    notNull: field.notNull,
                                    primaryKey: field.primaryKey,
                                    autoIncrement: field.autoIncrement,
                                    type: switch field.type {
                                        case null: throw new Error('must provide column type');
                                        case other: other.toSType();
                                    }
                                }

                            case other:
                                throw new Error('Unexpected $other');
                        }
                    }
                }
                else if (Reflect.isObject( c )) {
                    var c:TColInit = cast c;
                    inline function og(o, n) return Reflect.field(o, n);
                    inline function g(n) return og(c, n);
                    switch ([c.name, c.type, c.autoIncrement, c.unique, c.notNull, c.primaryKey]) {
                        case [null, null, null, null, null, null]:
                            throw 'invalid';

                        case [name, type, autoIncrement, unique, notNull, primaryKey]:

                        case [(_ : String)=>name, stype(_)=>type, autoIncrement, unique, notNull, primaryKey] if ((name is String) && (type is SType)):
                            columns[i] = {
                                name: name,
                                type: type,
                                autoIncrement: autoIncrement,
                                unique: unique,
                                notNull: notNull,
                                primaryKey: primaryKey
                            };
                    }
                }
                else {
                    throw 'invalid';
                }
            }
            var t = createTable(name, columns, true);
        }

        null_info();
        _c = new QueryCompiler(get_info());
    }

/* === Methods === */

    /**
      create and return a new Table instance
     **/
    public function createTable(tableName:String, columns:Array<TableColumnInit>, overwrite=false):Table {
        if (mTbls.exists( tableName )) {
            //
            return mTbls[tableName];
        }
        else {
            mTbls[tableName] = new DbTable(this, {
                columns: columns.map(c -> {
                    name: c.name,
                    type: c.type,
                    autoIncrement: c.autoIncrement,
                    unique: c.unique,
                    primaryKey: c.primaryKey,
                    notNull: c.notNull,
                    defaultValue: null
                })
            });

            return mTbls[tableName];
        }
    }

    /**
      delete and purge the given table
     **/
    public function dropTable(tableName: String):Bool {
        return mTbls.remove( tableName );
    }

    /**
      obtain a reference to the table of the given name
     **/
    public function table(name:String, safe=true):Table {
        if (!mTbls.exists(name) || mTbls[name] == null) {
            if (safe) throw new Error('cannot access "$name" table');

            //TODO
        }
        
        return mTbls[name];
    }

    public function insert(into:String, values:Dynamic):RowData {
        return table( into ).insertOne( values );
    }

    public function get(tableName:String, id:Dynamic):Null<RowData> {
        return table( tableName ).get(KeyLookup.oned( id ));
    }

    public function by(tableName:String, columnName:String, columnValue:KeyLookup):Array<RowData> {
        return table( tableName ).by(columnName, columnValue);
    }

    /**
      SELECT operation
     **/
    public function select(src:String, what:String, ?where:String) {
        var qsrc = SqlParser.readSelectSource( src );
        var qfields = SqlParser.readSelectFieldList( what );
        var qcond = where == null ? Expr.CTrue : SqlParser.readExpr(where);

        switch ([qsrc, qfields, qcond]) {
            case [Table(tableName), [{all:true}], Expr.CTrue]:
                return table(tableName).all();

            case [Table(tableName), _, cond]:
                throw 'ass';

            case _:
                throw 'assert';
        }
    }

    /**
      
     **/
    static function stype(t: Or<String, SType>):SType {
        if ((t is String)) {
            var t:String = t;
            return SqlParser.readSqlType( t ).toSType();
        }
        else return cast(t, SType);
    }

    function build_info() {
        return _info = {
            _instance: this,
            tables: [for (name=>table in mTbls) {
                    name => {
                        name: name, 
                        columns: [
                            for (i in 0...table.columns.length) 
                            {
                                name: table.columns[i].name,
                                type: table.columns[i].type
                            }
                        ]
                    };
                }
            ]
        };
    }

    inline function null_info() {
        return _info = null;
    }

/* === Properties === */

    public var info(get, never): DbInfo;
    private function get_info() {
        return _info == null ? build_info() : _info;
    }

/* === Variables === */

    private var mTbls(default, null): Map<String, Null<DbTable>>;
    private var mFlags(default, null): {lazyLoadTables:Bool};

    @:noCompletion
    public var _c(default, null): QueryCompiler;
    private var _info(default, null): Null<DbInfo> = null;
}

typedef DbInit = {
    tables: Map<String, TableInit>
};

typedef TableInit = {
    columns: Or<Array<String>, Array<ColInit>>
};

typedef TColInit = {name:String, type:Or<String, SType>, ?notNull:Bool,?autoIncrement:Bool,?unique:Bool,?primaryKey:Bool};
typedef ColInit = Or<TColInit, Or<Array<String>, String>>;

class DbTable extends Table {
    public var db: Database;

    public function new(db, init) {
        super( init );
        this.db = db;
    }
}
