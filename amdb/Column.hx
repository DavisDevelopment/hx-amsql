package amdb;

import amdb.SType;

class Column {
    public var name: String;
    public var type: SType;

    public function new(name, type) {
        this.name = name;
        this.type = type;
    }
}
