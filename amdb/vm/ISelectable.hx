package amdb.vm;

import amdb.Val;
import amdb.vm.ProgramContext.StatefulIterator;

interface ISelectable {
    function getColumns():Array<ColumnLike>;
    function open():StatefulIterator<Dynamic, Array<Val>>;
}

typedef ColumnLike = {name:String, type:SType};

