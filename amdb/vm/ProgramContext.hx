package amdb.vm;

import haxe.ds.Vector;
import pm.LinkedStack;
import haxe.ds.Option;

import haxe.Int32;
import haxe.Int64;
import pm.BigInt;
import pm.Decimal;

import haxe.io.*;

import pm.AVLTree;
import pm.AVLTree as Tree;
import pm.AVLTree.AVLTreeNode as Leaf;
import pm.Arch;

import amdb.Val;
import amdb.SType;
import amdb.vm.ISelectable;

import haxe.extern.EitherType as Or;

import amdb.SType;
import amdb.Table;
import amdb.tools.Io;

class ProgramContext {
    public function new() {
        //mSelStack = new LinkedStack();
        mTableMap = new Map();
    }

/* === Methods === */

    //public inline function acctab(k: String):Null<ISelectable> {
        //return mTableMapL[k];
    //}

    //public inline function alloctab(k: String):Void {
        //mTableMapL[k] = mTableMapG[k]();
    //}

    //public inline function usetab(t: ISelectable) {
        //selpush(new SelState(t, null, null));
    //}

    //public inline function opentab() {
        //selpush(new SelState(sel.s, sel.s.open(), null));
    //}

    //public inline function selpush(s: SelState){mSelStack.push(s);}
    //public inline function selpop():SelState {
        //if (mSelStack.size > 1) {
            //return mSelStack.pop();
        //}
        //else return mSelStack.top();
    //}

/* === Properties === */

    //public var sel(get, never): SelState;
    //inline function get_sel():SelState return mSelStack.top();

/* === Variables === */

    private var mTableMap(default, null): Map<String, Void->ISelectable>;
    //private var mTableMapL(default, null): Map<String, ISelectable>;
    //private var mSelStack(default, null): LinkedStack<SelState>;
}

class SelState {
    public var s: ISelectable;
    public var itr: Null<StatefulIterator<Dynamic, Array<Val>>>;
    private var itrState: Null<Dynamic>;

    public function new(?sel, ?iter, ?state) {
        s = sel;
        itr = iter;
        itrState = state;
    }
    public inline function restore() {
        if (itr != null && itrState != null) {
            itr.restore( itrState );
        }
    }
}

typedef StatefulIterator<State, Item> = Iterator<Item> & {
    function save():State;
    function restore(state: State):Void;
};
