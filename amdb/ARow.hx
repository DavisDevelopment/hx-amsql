package amdb;

import haxe.ds.Vector;

#if macro
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Type;
#end

class ARow extends Entry {
    public function new(vals) {
        super( vals );

        //this.table = t;
    }

    inline function _checkColumns() {
        assert(columns != null && !columns.empty(), new Error('columns was not initialized!'));
    }

    function indexOfColumn(name: String):Int {
        _checkColumns();
        for (i in 0...columns.length) {
            if (columns[i].name == name) {
                return i;
            }
        }
        return -1;
    }

    public inline function getByIndex(i: Int):Val {
        _checkColumns();
        assert(i.inRange(0, columns.length));

        return values[i];
    }

    public inline function getByName(name: String):Val {
        return getByIndex(indexOfColumn( name ));
    }

    public inline function setByIndex(index:Int, value:Val) {
        _checkColumns();
        assert(i.inRange(0, columns.length));

        values[index] = value;
    }

    public inline function setByName(name:String, value:Val) {
        setByIndex(indexOfColumn(name), value);
    }

    public macro function get(self:ExprOf<ARow>, key:Expr):ExprOf<Val> {
        switch (Context.toComplexType(Context.typeof( key ))) {
            case (macro : Int)|(macro : StdTypes.Int):
                return macro $self.getByIndex( $key );

            case (macro : String)|(macro : StdTypes.String):
                return macro $self.getByName( $key );

            default:
                throw 'ass';
        }
    }

    //public macro function set(self:ExprOf<ARow>, key:Expr, value:Expr) {
        //switch (Context.toComplexType(Context.typeof( key ))) {
            //case (macro : Int)|(macro : StdTypes.Int):
                //return macro $self.getByIndex( $key );

            //case (macro : String)|(macro : StdTypes.String):
                //return macro $self.getByName( $key );

            //default:
                //throw 'ass';
        //}
    //}

    //public var table: Table;
    private var columns(default, null): Null<Vector<Column>> = null;
}
