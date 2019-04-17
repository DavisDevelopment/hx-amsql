package amdb;

import haxe.io.*;

import amdb.Table.KeyLookup;
import amdb.Table.EKeyLookup;

@:using(amdb.Val.Vals)
@:using(amdb.Val.ValOperators)
@:using(amdb.Val.ValComparisons)
enum Val {
    CNil;
    CInt(n: Int);
    CFloat(n: Float);
    CText(s: String);
    CDateTime(dt: Date);

    Blob(b: Bytes);
    List(l: Array<Val>);
}

class Vals {
    /**
      numerically compare [a] to [b]
     **/
    public static function compare(a:Val, b:Val):Int {
        var ai = a.getIndex(), bi = b.getIndex();
        if (ai < bi) return -1;
        else if (ai > bi) return 1;
        else return switch [a, b] {
            case [CNil, CNil]: 0;
            case [CInt(va), CInt(vb)]: Ints.compare(va, vb);
            case [CFloat(va), CFloat(vb)]: Floats.compare(va, vb);
            case [CText(va), CText(vb)]: Reflect.compare(va, vb);
            case [CDateTime(va), CDateTime(vb)]: Floats.compare(va.getTime(), vb.getTime());
            case [Blob(va), Blob(vb)]: va.compare( vb );
            case [List(va), List(vb)]: compareArrays(va, vb);

            case _:
                throw new Error('Impossible');
        }
    }

    static function compareArrays(a:Array<Val>, b:Array<Val>):Int {
        var comp:Int = 0;
        for (i in 0...Ints.min(a.length, b.length)) {
            comp = compare(a[i], b[i]);
            if (comp != 0)
                break;
        }
        return comp == 0 ? Ints.compare(a.length, b.length) : comp;
    }

    public static function getValue(v: Val):Dynamic {
        return switch v {
            case CNil: null;
            case CInt(x): x;
            case CFloat(x): x;
            case CText(x): x;
            case CDateTime(x): x;
            case List(x): x;
            case Blob(x): x;
        }
    }


    public static function clone(v: Val):Val {
        return switch v {
            case CNil: CNil;
            case CInt(x): CInt(x);
            case CFloat(x): CFloat(x);
            case CText(x): CText(x);
            case Blob(x): Blob(x.sub(0, x.length));
            case CDateTime(x): CDateTime(Date.fromTime(x.getTime()));
            case List(l): List(l.map(clone));
        }
    }

    public static function testKeyLookup(v:Val, k:KeyLookup):Bool {
        switch k {
            case EKeyLookup.One(key): 
                return key.eq( v );
            case EKeyLookup.Many(keys): 
                for (key in keys)
                    if (key.eq( v ))
                        return true;
                return false;
            case EKeyLookup.Between(min, null):
                switch min {
                    case Edge(min):
                        return v.gt(min);
                    case Inclusive(min):
                        return v.gte(min);
                }
            case EKeyLookup.Between(null, max):
                switch max {
                    case Edge(max):
                        return v.lt(max);
                    case Inclusive(max):
                        return v.lte(max);
                }
            case EKeyLookup.Between(min, max):
                var gtmin = switch min {
                    case Edge(x): v.gt( x );
                    case Inclusive(x): v.gte( x );
                };
                var ltmax = switch max {
                    case Edge(x): v.lt( x );
                    case Inclusive(x): v.lte( x );
                };
                return gtmin && ltmax;

            case EKeyLookup.Matches(fn): 
                return false;
        }
    }
}

class ValComparisons {
    public static function eq(a:Val, b:Val):Bool {
        //TODO optimize
        return a.compare( b ) == 0;
    }

    public static function neq(a:Val, b:Val):Bool {
        return a.compare( b ) != 0;
    }

    public static function gt(a:Val, b:Val):Bool {
        return a.compare( b ) > 0;
    }
    public static function gte(a:Val, b:Val):Bool {
        return a.compare( b ) >= 0;
    }
    public static function lt(a:Val, b:Val):Bool {
        return a.compare( b ) < 0;
    }
    public static function lte(a:Val, b:Val):Bool {
        return a.compare( b ) <= 0;
    }
}

class ValOperators {
    public static function add(a:Val, b:Val):Val {
        return switch a {
            case CNil: throw new Error('Cannot add $a to $b');
            case CInt(a): switch b {
                case CInt(b): Val.CInt(a + b);
                case CFloat(b): Val.CFloat(a + b);
                case _: throw new Error('Invalid $a + $b');
            }
            default: throw new Error('Invalid $a + $b');
        }
    }
}
