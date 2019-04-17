package amdb;

import haxe.ds.Vector;

class Entry {
    public function new(vals: Vector<Val>) {
        values = vals;
    }

    public var values: Vector<Val>;
}
