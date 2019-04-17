package amdb;

import amdb.Val;
import amdb.ast.Query.SqlType;

@:using(amdb.SType.STypes)
enum SType {
    SBit;
	SInt;
	SBigInt;
	SFloat(precision: Int);
	SDouble;
	//STinyInt;

	SChar(size : Int);
	SText;
	SBlob;
	SDate;
	SDateTime;
}

class STypes {
    public static function checkVal(type:SType, val:Val):Bool {
        return switch [type, val] {
            case [_, CNil]: true;
            case [SBit, CInt(i)]: i.matchFor(0|1, true, false);
            case [SInt, CInt(i)]: i.isFinite();
            case [SFloat(precision), CFloat(num)]: (num == num.toPrecision(precision));
            case [SDouble, CFloat(num)]: !num.isNaN() && num.isFinite();
            case [SChar(size), CText(txt)]: (txt.length <= size);
            case [SText, CText(txt)]: true;

            case _:
                throw new Error('Unhandled $type or $val');
        }
    }
}

class SqlTypes {
    public static function toSType(type: SqlType):SType {
        return switch type {
            case SqlType.SBigInt: SBigInt;
            case SqlType.SBlob: SBlob;
            case SqlType.SDate: SDate;
            case SqlType.SDateTime: SDateTime;
            case SqlType.SText: SText;
            case SqlType.SInt: SInt;
            case SqlType.SDouble: SDouble;
            case SqlType.SFloat: SDouble;
        }
    }
}
