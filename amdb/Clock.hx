package amdb;

import haxe.PosInfos;

//import 
class Clock {
    /**
      get most accurate possible timestamp
     **/
    #if !js inline #end
    public static function stamp(?pos: PosInfos):Float {
        #if nodejs
            var tmp = js.Node.process.hrtime();
            return tmp[0] * 1e3 + tmp[1] / 1e6;
        #elseif python
            return python.Syntax.code('{0}.perf_counter() * 1e3', python.lib.Time);
        #else
            return (1000.0 * Sys.time());
        #end
    }

    /**
      measure `func`'s execution time
     **/
    public static inline function measure(func: Void -> Void, ?pos:PosInfos):Float {
        var start = stamp( pos );
        func();
        return (stamp(pos) - start);
    }
}


