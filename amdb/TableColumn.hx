package amdb;

class TableColumn extends Column {
    public var offset: Int = -1;

    public var notNull: Bool = false;
    public var unique: Bool = false;
    public var primaryKey: Bool = false;
    public var autoIncrement: Bool = false;

    public var defaultValue: Val;

    @:isVar
    public var _autoIncrementState(get, null):Val;
    function get__autoIncrementState():Val {
        if (_autoIncrementState == null) {
            switch type {
                case SType.SInt:
                    _autoIncrementState = Val.CInt( 0x000001 );

                case other:
                    throw other;
            }
        }
        return _autoIncrementState;
    }

    public function new(name, type) {
        super(name, type);

        defaultValue = Val.CNil;
    }

    public inline function nextAutoIncrementState():Val {
        return switch _autoIncrementState {
            case Val.CInt(n): Val.CInt(n + 1);
            case x: throw x;
        }
    }
}
