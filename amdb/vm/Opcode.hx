package amdb.vm;

enum Operation {
/* === opcodes for 'reading' basic values === */
    //OAccNull;
    //OAccTrue;
    //OAccFalse;
    OAccVal(v: Val);
    OAccThis;

    OAccStack(idx: Int);
    OAccStack0;
    OAccStack1;
    OAccIndex(idx: Int);
    OAccIndex0;
    OAccIndex1;

    OSetStack(idx: Int);

/* === Stack-Manipulation === */

    OPush;//appends [acc] onto [stack]
    OPop(n: Int);//removes [n] items from top of stack
    OSwap;
    
/* === Operators === */

    OAdd;
    OSub;
    OMul;
    ODiv;

    OEq;
    ONeq;
    OGt;
    OGte;
    OLt;
    OLte;

/* === Misc === */

    OHash;

/* === Query Opcodes === */

    OBegin;
    //O
}

#if !macro @:build(amdb.tools.EnumBuilders.enumFlatCopy('amdb.vm.Opcode.Operation')) #end
enum Opcode {}
