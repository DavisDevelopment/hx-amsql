package amdb.vm;

import pm.LinkedStack;
import haxe.ds.Option;

import haxe.Int32;
import haxe.Int64;
import pm.BigInt;
import pm.Decimal;

import haxe.io.*;

import pm.AVLTree;
import pm.AVLTree as Tree;
import pm.AVLTree.AVLTreeNode as Leaf;
import pm.Arch;

import amdb.Val;
import amdb.SType;
import amdb.ast.Query;
import amdb.vm.ISelectable;

import haxe.extern.EitherType as Or;

import hscript.Expr as HExpr;

import pm.Functions.fn;

import amdb.SType;
import amdb.Table;
import amdb.RowData;
import amdb.vm.ProgramContext.StatefulIterator;
import amdb.tools.Io;

@:allow(amdb.Database)
class QueryCompiler {
    public function new(db: DbInfo) {
        this.db = db;

        this.scope = makeRootScope();
    }

    private function makeRootScope():DbScope {
        return {
            db: db._instance,
            tables: db._instance.info.tables.keys()
                .map(function(key) {
                    return {
                        key: key,
                        value: (function() {
                            var f0 = fn(() -> ATable.ofTable(_)).call(db._instance.table(key));
                            return ((scope:DbScope) -> f0());
                        })()
                    };
                })
                .reduce(function(m:Map<String, DbScope->ATable<RowData>>, kv) {
                    m[kv.key] = kv.value;
                    return m;
                }, new Map<String, DbScope->ATable<RowData>>())
        };
    }

    public function compute(q: Query) {
        return compile(simplify( q ));
    }

    function _sel_(d:DbScope, tableName:String) {
        if (d.tables.exists( tableName )) {
            return d.tables[tableName].call( d );
        }
        else {
            throw new Error('$tableName is not defined', 'ReferenceError');
        }
    }

    function compile(q: Query):CompiledQuery<Dynamic> {
        switch q {
            case Select([{table:null,field:_,alias:alias,all:true}], QuerySrc.Table(tableName), Expr.CTrue):
                return CompiledQuery.Select(_sel_.bind(_, tableName));

            case Select(fields, Table(tableName), condition):
                var fn = (function(f) {
                    return function(scope: DbScope) {
                        return f(scope, scope.db.table(tableName));
                    }
                }).call(compileConditionalTableSelect(tableName, condition));

                return CompiledQuery.Select(function(scope: DbScope):ATable<RowData> {
                    return fn.call( scope );
                });

            case _:
                throw new Error('Unexpected $q');
        }
    }

    function compileConditionalTableSelect(tableName:String, condition:Expr):DbScope->Table->ATable<RowData> {
        var condFn = compileConditionExpr( condition );
        
        return function(scope:DbScope, table:Table):ATable<RowData> {
            return ATable.ofTable(table).apply.fn({columns:_.columns.copy(), open:_.open.map.fn(_.filter(condFn.bind(null, _)))});
        }
    }

    function compileConditionExpr(expr: Expr):ExprScope<Dynamic>->RowData->Bool {
        return switch expr {
            case Expr.CTrue: (scope, row) -> true;
            case Expr.CFalse: (scope, row) -> false;
            case Expr.EBinop(op, left, right):
                var l = compileRowExtractor(left), r = compileRowExtractor(right);
                return function(scope:ExprScope<Dynamic>, row:RowData):Bool {
                    switch op {
                        case Binop.Eq:
                            return l(scope, row).equals(r(scope, row));

                        case Binop.NEq:
                            return !l(scope, row).equals(r(scope, row));

                        case Binop.In:
                            switch r(scope, row) {
                                case Val.List(vals):
                                    var lv = l(scope, row);
                                    for (v in vals)
                                        if (v.eq(lv))
                                            return true;
                                    return false;

                                case v:
                                    throw new Error('Unexpected $v');
                            }

                        case _:
                            throw 'Unexpected $op';
                    }
                }

            case e:
                throw 'Unexpected $e';
        }
    }

    function compileRowExtractor(expr: Expr):ExprScope<Dynamic>->RowData->Val {
        return switch expr {
            case Expr.CTrue: (scope:ExprScope<Dynamic>, row:RowData) -> Val.CInt(1);
            case Expr.CFalse: (scope:ExprScope<Dynamic>, row:RowData) -> Val.CInt(0);
            case Expr.CNull: (scope:ExprScope<Dynamic>, row:RowData) -> Val.CNil;
            case Expr.CInt(num): (scope:ExprScope<Dynamic>, row:RowData) -> Val.CInt( num );

            case Expr.CFloat(num): (scope:ExprScope<Dynamic>, row:RowData) -> Val.CFloat(num);
            case Expr.CString(num): (scope:ExprScope<Dynamic>, row:RowData) -> Val.CText(num);
            case Expr.EId(name): (scope, row) -> row.get( name );
            case Expr.EList(vals):
                var gets = vals.map(e -> compileRowExtractor( e ));
                return (scope, row) -> Val.List(gets.map(f -> f(scope, row)));
            case Expr.EBinop(op, left, right):
                var fop = compileRowExtractorBinop( op ), fr = compileRowExtractor( right ), fl = compileRowExtractor( left );
                return (scope, row) -> fop(fr(scope, row), fl(scope, row));

            case _:
                throw 'Unexpected $expr';
        }
    }

    function compileRowExtractorBinop(op: Binop):Val -> Val -> Val {
        return switch op {
            case Binop.Add: (l:Val, r:Val) -> Io.toVal(r.getValue() + l.getValue());
            case Binop.Sub: (l:Val, r:Val) -> Io.toVal(r.getValue() - l.getValue());

            case _:
                            throw 'ass';
        }
    }

    function compileQuerySrc(scope:DbScope, source:QuerySrc):SelSrc {
        return switch source {
            case QuerySrc.Table(tableName): SelSrc.SNamed( tableName );
            case _: throw 'unexpected $source';
        }
    }

    function evalSelSrc(scope:DbScope, source:SelSrc) {
        return switch source {
            case SelSrc.SSel(s): s.get();
            case SelSrc.SNamed(name): scope.tables[name].call( scope );
        }
    }

    function compileSelSrc(scope:DbScope, source:SelSrc) {
        return switch source {
            case SelSrc.SSel(s): (scope: DbScope) -> s.get();
            case SelSrc.SNamed(name): (scope: DbScope) -> scope.tables[name].call( scope );
        }
    }

    /*
    public function hscompile(q: Query):HExpr {
        inline function callm(o:HExpr, m:String, p:Array<Dynamic>) { return ECall(EField(o, m), p); }

        switch q {
            case Query.Select([{table:null,field:_,alias:alias,all:true}], Table(tableName), Expr.CTrue):
                var vn:Array<Null<String>> = [null, null, null];
                var es = new LinkedStack<HExpr>();
                return HExpr.EBlock([
                    HExpr.EVar(vn[0]=varname(++varn), null, ECall(EIdent('open'), [EConst(CString(tableName))])),
                    HExpr.EVar(vn[1]=varname(++varn), null, callm(EIdent(vn[0]), 'iterator', [])),
                    HExpr.EWhile(callm(EIdent(vn[1]), 'hasNext', []), EBlock([
                        EVar(vn[2]=varname(++varn), null, callm(EIdent(vn[1]), 'next', [])),
                        HExpr.EMeta('yield', null|[], ECall(EIdent('column'), exports))
                    ]))
                ]);
        }
    }
    static inline function varname(i: UInt):String {
        return 'var${i}';
    }
    */

    public function simplify(query: Query):Query {
        switch query {
            //case Query.Select([{table:null,field:_,alias:alias,all:true}], src, Expr.CTrue):
            case _: 
                return query;
        }
    }

/* === Variables === */

    public var db: DbInfo;
    public var scope: DbScope;

    var varn:UInt = 0x000000;
}

enum QueryNode {
    QPass;
    QYieldRow;
    QClose;
    QSelAlloc(selCount: Int32);
    QSelG(id:String, addr:Addr);
    QSelSub(program:Dynamic, addr:Addr);

    //AOpenSel;
    QRowAlloc(columnCount: Int32);
    QItr(name:String, source:Addr, ?index:Addr, body:Node);
    QIf(cond:Node, thenNode:Node, elseNode:Node);
    QExpr(expr: amdb.ast.Query.Expr);
    QRowSet(column:Addr, value:Node);
}

enum SelSrc {
    SSel(sel: Lazy<ATable<Dynamic>>);
    SNamed(name: String);
    //SSub(program: Dynamic);
}

typedef Addr = Int32;
typedef Node = QueryNode;
typedef ExprScope<T> = Dynamic;

typedef DbScope = {
    ?parent: DbScope,

    db: Database,
    tables: Map<String, DbScope->ATable<RowData>>
};

typedef DbInfo = {
    ?_instance: Database,
    tables: Map<String, TblInfo>
};
typedef TblInfo = {
    name: String,
    columns: Array<ColumnLike>
};

enum CompiledQuery<Res> {
    Select(fn: DbScope->ATable<RowData>) : CompiledQuery<ATable<RowData>>;
}

typedef ATableObject<T> = {
    columns: Array<ColumnLike>,
    //open: DbScope->StatefulIterator<Array<Dynamic>>
    open: (scope: DbScope)->Array<T>
};

@:forward(columns, open)
abstract ATable<T> (ATableObject<T>) from ATableObject<T> to ATableObject<T> {
    public inline function map<O>(fn:T -> O):ATable<O> {
        return mk(this.columns.copy(), (scope) -> this.open(scope).map( fn ));
    }

    public static inline function mk<T>(cols:Array<ColumnLike>, open:DbScope->Array<T>):ATable<T> {
        return {columns:cols, open:open};
    }

    @:from
    public static function ofTable(t: amdb.Table):ATable<RowData> {
        return mk(t.columns.map(c -> {name:c.name, type:c.type}), (scope: DbScope) -> t.all());
    }

    public static function table(tbl:amdb.Table, fn:Table->Array<RowData>):ATable<RowData> {
        return mk(tbl.columns.map(c->{name:c.name,type:c.type}), (scope:DbScope)->fn(tbl));
    }
}
