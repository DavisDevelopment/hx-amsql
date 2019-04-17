package amdb;

import haxe.ds.Vector;

class TableRow extends ARow {
    public function new(t, vals) {
        super( vals );
        this.table = table;
        this.columns = Vector.fromArrayCopy(vi(table.columns).map(c -> new Column(c.name, c.type)).array());
    }

    public var table: Table;
}
