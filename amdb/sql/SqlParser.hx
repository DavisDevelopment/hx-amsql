package amdb.sql;

import haxe.ds.GenericStack;
import amdb.ast.Query;

class SqlParser {
	static var KWDS = [
		"ALTER", "SELECT", "UPDATE", "WHERE", "CREATE", "FROM", "TABLE", "NOT", "NULL", "PRIMARY", "KEY", "ENGINE", "AUTO_INCREMENT", "UNIQUE",
		"ADD", "CONSTRAINT", "FOREIGN", "REFERENCES", "ON", "DELETE", "SET", "NULL", "CASCADE", "ASC", "DESC", "ORDER", "BY", "AS",
		"LEFT", "RIGHT", "INNER", "OUTER", "JOIN", "IN", "LIKE"
	];

	var query : String;
	var pos : Int;
	var keywords : Map<String,Bool>;
	var sqlTypes : Map<String, SqlType>;
	var idChar : Array<Bool>;
	var cache : Array<Token>;

	var opPriority : Map<Binop, Int>;

	var eofStack : Array<Token>;

    /* Constructor Functions */
	public function new() {
		idChar = [];
		for (i in 'A'.code...'Z'.code + 1)
			idChar[i] = true;
		for (i in 'a'.code...'z'.code + 1)
			idChar[i] = true;
		for (i in '0'.code...'9'.code + 1)
			idChar[i] = true;
		idChar['_'.code] = true;

		keywords = [for (k in KWDS) k => true];

		sqlTypes = [
			"DATE" => SDate,
			"DATETIME" => SDateTime,
			"FLOAT" => SFloat,
			"DOUBLE" => SDouble,
			"INT" => SInt,
			"INTEGER" => SInt,
			"BIGINT" => SBigInt,
			"TEXT" => SText,
			"BLOB" => SBlob,
			"BYTES" => SBlob
		];

		var priorities = [
		    [Binop.Mult, Binop.Div],
		    [Binop.Add, Binop.Sub],
		    [],
		    [],
		    [Binop.Eq, Binop.NEq, Binop.In, Binop.Like]
		];

        opPriority = new Map();
	    for (i in 0...priorities.length) {
	        for (x in priorities[i]) {
	            opPriority.set(x, i);
	        }
	    }

	    eofStack = [Token.Eof];
	}

	static function _setup(p:SqlParser, s:String){
	    p.query = s;
	    p.pos = 0;
	    p.cache = [];
	}
	static function _parseOf<T>(p:SqlParser, code:String, fn:(parser: SqlParser)->T):T {
	    _setup(p, code);
	    return fn( p );
	}
	static function _po<T>(s:String, fn:SqlParser->T):T return _parseOf(new SqlParser(), s, fn);

    public static function readSqlType(code: String):SqlType return _po(code, x->x.parseSqlType());
	public static function readSelectFieldList(code: String) {
	    return _parseOf(new SqlParser(), code, x->x.parseSelectFieldList());
	}
	public static function readSelectSource(code: String) {
	    return _parseOf(new SqlParser(), code, x->x.parseQuerySource());
	}
	public static function readTableCreateEntries(code: String) {
	    return _parseOf(new SqlParser(), code, x->x.parseTableCreateEntries());
	}
	public static function readTableCreateEntry(code: String) {
	    return readTableCreateEntries('($code)')[0];
	}
	public static function readExpr(code: String) {
	    return _parseOf(new SqlParser(), code, x->x.parseExpr());
	}

    /**
      parse out a Query statement from the given String
     **/
	public function parse(q : String) {
		this.query = q;
		this.pos = 0;
		cache = [];

		#if neko
		try {
			return parseQuery();
		}
		catch( e : Dynamic ) {
			neko.Lib.rethrow(e+" in " + q);
			return null;
		}
		#else
		return parseQuery();
		#end
	}

	inline function push(t) {
		cache.push( t );
	}

	inline function nextChar():Int {
		return StringTools.fastCodeAt(query, pos++);
	}

	inline function isIdentChar( c : Int ) {
		return idChar[c];
	}

	function invalidChar(c) {
		throw "Unexpected char '" + String.fromCharCode(c)+"'";
	}

	function token() {
		var t = cache.pop();
		if( t != null ) return t;
		while( true ) {
			var c = nextChar();
			switch( c ) {
			case ' '.code, '\r'.code, '\n'.code, '\t'.code:
				continue;
			case '*'.code:
				return Star;
			case '('.code:
				return POpen;
			case ')'.code:
				return PClose;
			case ','.code:
				return Comma;
			case '.'.code:
			    return Dot;
			case '!'.code:
			    if (nextChar() == '='.code)
			        return Op(NEq);
			    --pos;
			    return Not;
			case '='.code:
				return Op(Eq);
			case '+'.code:
			    return Op(Add);
			case '-'.code:
			    return Op(Sub);
			case '/'.code:
			    return Op(Div);
			case '`'.code:
				var start = pos;
				do {
					c = nextChar();
				} 
				while (isIdentChar( c ));
				if (c != '`'.code)
					throw "Unclosed `";
				return Ident(query.substr(start, (pos - 1) - start));

			case '"'.code:
			    var start = pos;
			    var escaped = false;
			    do {
			        c = nextChar();
			        if ( escaped ) {
			            escaped = false;
			            continue;
			        }

			        switch c {
                        case '"'.code:
                            if (!escaped)
                                return CString(query.substr(start, (pos - 1) - start));

                        case '\\'.code:
                            if (!escaped)
                                escaped = true;

                        default:
                            //
			        }
			    }
			    while ( true );

			case '0'.code, '1'.code, '2'.code, '3'.code, '4'.code, '5'.code, '6'.code, '7'.code, '8'.code, '9'.code:
				var n = (c - '0'.code) * 1.0;
				var exp = 0.;
				while( true ) {
					c = nextChar();
					exp *= 10;
					switch( c ) {
					case 48,49,50,51,52,53,54,55,56,57:
						n = n * 10 + (c - 48);
					case '.'.code:
						if( exp > 0 )
							invalidChar(c);
						exp = 1.;
					default:
						pos--;
						var i = Std.int(n);
						return (exp > 0) ? CFloat(n * 10 / exp) : ((i == n) ? CInt(i) : CFloat(n));
					}
				}
			default:
				if( (c >= 'A'.code && c <= 'Z'.code) || (c >= 'a'.code && c <= 'z'.code) ) {
					var start = pos - 1;
					do {
						c = nextChar();
					}
					while( #if neko c != null && #end isIdentChar(c) );
					pos--;
					var i = query.substr(start, pos - start);
					var iup = i.toUpperCase();
					if( keywords.exists(iup) )
						return Kwd(iup);
					return Ident(i);
				}
				if( StringTools.isEof(c) )
					return Eof;
				invalidChar(c);
			}
		}
	}

	private function tokenStr(t) {
		return switch( t ) {
		case Kwd(k): k;
		case Ident(k): k;
		case CString(k): '"$k"';
		case Star: "*";
		case Dot: '.';
	    case Not: '!';
		case Eof: "<eof>";
		case POpen: "(";
		case PClose: ")";
		case Comma: ",";
		case Op(o): opStr(o);
		case CInt(i): "" + i;
		case CFloat(f): "" + f;
		};
	}

	function opStr( op : Binop ) {
		return switch( op ) {
		case Eq: "=";
		case NEq: "!=";
	    case In: "in";
        case Like: "like";

		case Add: '+';
		case Sub: '-';
		case Div: '/';
		case Mult: '*';

		case LogAnd: 'and';
		case LogOr: 'or';
		}
	}

	function req(tk: Token) {
		var t = token();
		if (!Type.enumEq(t, tk))
		    unexpected( t );
	}

	function maybe(tk: Token):Bool {
	    var t = token();
	    if (Type.enumEq(tk, t)) {
	        return true;
	    }
        else {
            push( t );
            return false;
        }
	}

	function unexpected(t, ?pos:haxe.PosInfos) : Dynamic {
		//throw "Unexpected " + tokenStr(t);
		throw SqlError.UnexpectedToken(t, pos);
		return null;
	}

	function ident() : String {
		return switch (token()) {
		    case Ident(i): i;
		    case t: unexpected( t );
		}
	}

	function end():Bool {
		var t = token();
        if (Type.enumEq(eofStack[eofStack.length - 1], t)) {
            if (eofStack.length > 1) {
                eofStack.pop();
            }
        }
        else {
            unexpected( t );
        }
		return true;
	}
	inline function asEndOfFile(tk: Token) {
	    eofStack.push( tk );
	}

	function parseQueryNext(q: Query):Query {
	    var t = token();
	    switch t {
            case Eof:
                return q;

            case _:
                push( t );
                return q;
	    }
	}

	function parseSelectFieldList():Array<Field> {
	    var fields = [];
	    while (true) {
	        switch (token()) {
                case Star:
                    fields.push({all: true});

                case Ident(id):
                    var field:Field = {field: id};
                    if (maybe(Kwd("AS"))) switch token() {
                        case Ident(alias):
                            field.alias = alias;

                        case t:
                            unexpected( t );
                    }
                    fields.push( field );

                case t:
                    unexpected( t );
	        }
	        if (!maybe(Comma))
	            return fields;
	    }
	}

	function parseQuerySourceNext(src: QuerySrc):QuerySrc {
        var t = token();
        switch t {
            case Kwd("AS"):
                return Alias(src, ident());

            case Kwd(jk=("INNER"|"OUTER"|"LEFT"|"RIGHT")):
                req(Kwd("JOIN"));
                var src2 = parseQuerySource();
                req(Kwd("ON"));
                var joinMode:JoinKind = switch jk {
                    case "INNER": JoinInner;
                    case "OUTER": JoinOuter;
                    case "LEFT": JoinLeft;
                    case "RIGHT": JoinRight;
                    default: unexpected(Kwd(jk));
                };

                var pred = parseExpr();
                return QuerySrc.Join(joinMode, src, src2, pred);

            default:
                push( t );
                return src;
        }
	}

	function parseQuerySource():QuerySrc {
        var t = token();
        switch ( t ) {
            case Ident(name):
                return parseQuerySourceNext(QuerySrc.Table(name));

            case Kwd("SELECT"):
                push( t );
                return QuerySrc.Subquery(parseQuery());

            case POpen:
                asEndOfFile(PClose);
                var src = parseQuerySource();
                //req(PClose);
                //trace(''+token());
                return parseQuerySourceNext(src);

            case _:
                unexpected( t );
        }
        return QuerySrc.Table('');
	}

	function parseSqlType():SqlType {
	    var t = token();
	    switch t {
            case Ident(i), Kwd(i):
                var st = sqlTypes.get(i.toUpperCase()), params=null;
                if (st != null) {
                    if (maybe(POpen))
                        params = parseExprList(PClose);
                }
                return st;

            default:
                unexpected( t );
                throw t;
        }
	}

	function parseTableCreateEntries():Array<CreateTableEntry> {
	    var entries:Array<CreateTableEntry> = new Array();
        maybe( POpen );
        while ( true ) {
            switch (token()) {
                case Ident( name ):
                    var f:FieldDesc = {
                        name: name 
                    };

                    entries.push(CreateTableEntry.TableField( f ));
                    f.type = parseSqlType();

                    while ( true ) {
                        var t = token();
                        switch t {
                            case Kwd("NOT"):
                                req(Kwd("NULL"));
                                f.notNull = true;
                                continue;

                            case Kwd("AUTO_INCREMENT"|"AUTOINCREMENT"):
                                f.autoIncrement = true;
                                continue;

                            case Kwd("PRIMARY"):
                                req(Kwd("KEY"));
                                f.primaryKey = true;
                                continue;

                            case Kwd("UNIQUE"):
                                f.unique = true;
                                continue;

                            case PClose, Eof, Comma:
                                push( t );
                                break;

                            case t:
                                unexpected(t);
                        }
                    }

                case Kwd("PRIMARY"):
                    req(Kwd("KEY"));
                    req(POpen);
                    var key = [];
                    while ( true ) {
                        key.push(ident());
                        switch (token()) {
                            case PClose:
                                break;
                            case Comma:
                                continue;
                            case t:
                                unexpected( t );
                        }
                    }
                    entries.push(CreateTableEntry.TableProp(PrimaryKey(key)));

                case t:
                    unexpected(t);
            }

            switch (token()) {
                case Comma:
                    continue;

                case PClose, Eof:
                    break;

                case t:
                    unexpected(t);
            }
        }

        while ( true ) {
            switch (token()) {
                case Eof:
                    break;

                case Kwd("ENGINE"):
                    req(Op(Eq));
                    entries.push(TableProp(Engine(ident())));

                case t:
                    unexpected(t);
            }
        }

        return entries;
	}

	function parseQuery():Query {
		var t = token();
		switch( t ) {
		    /* --SELECT STATEMENT-- */
            case Kwd("SELECT"):
                var fields = parseSelectFieldList();
                req(Kwd("FROM"));
                var cond;
                var src = parseQuerySource();
                try {
                    end();
                    cond = Expr.CTrue;
                }
                catch(e: SqlError) switch e {
                    case UnexpectedToken(Kwd("WHERE"), _):
                        cond = parseExpr();

                    default:
                        throw 'wtf';
                }

                //TODO end();
                return Select(fields, src, cond);

            /* --CREATE [?] STATEMENT-- */
            case Kwd("CREATE"):
                switch(token()) {
                    /* --CREATE TABLE STATEMENT-- */
                    case Kwd("TABLE"):
                        var table = ident();
                        var fields = [], props = [];

                        for (entry in parseTableCreateEntries()) {
                            switch (entry) {
                                case CreateTableEntry.TableField( f ):
                                    fields.push( f );

                                case CreateTableEntry.TableProp( p ):
                                    props.push( p );
                            }
                        }

                        return CreateTable(table, fields, props);

                    default:
                }

        /**
          this is gonna get ugly
         **/
		case Kwd("ALTER"):
			req(Kwd("TABLE"));
			var table = ident();
			var cmds = [];
			while( true ) {
				switch( token() ) {
				case Eof: break;
				case Kwd("ADD"):
					switch( token() ) {
					case Kwd("CONSTRAINT"):
						var cname = ident();
						req(Kwd("FOREIGN"));
						req(Kwd("KEY"));
						req(POpen);
						var field = ident();
						req(PClose);
						req(Kwd("REFERENCES"));
						var target = ident();
						req(POpen);
						var tfield = ident();
						req(PClose);
						var onDel = null;
						switch( token() ) {
						case Kwd("ON"):
							req(Kwd("DELETE"));
							switch( token() ) {
							case Kwd("SET"):
								req(Kwd("NULL"));
								onDel = FKDSetNull;
							case Kwd("CASCADE"):
								onDel = FKDCascade;
							case t:
								unexpected(t);
							}
						case t:
							push(t);
						}
						cmds.push(AddConstraintFK(cname, field, target, tfield, onDel));
					case t: unexpected(t);
					}
				case t: unexpected(t);
				}
			}
			return AlterTable(table, cmds);
		default:
		}
		throw "Unsupported query " + query;
	}

	function makeBinop(op:Binop, l:Expr, r:Expr) {
	    return switch ( r ) {
            case EBinop(op2, l2, r2):
                if (opPriority.get(op) <= opPriority.get(op2))
                    EBinop(op2, makeBinop(op, l, l2), r2);
                else
                    EBinop(op, l, r);

            default:
                EBinop(op, l, r);
	    }
	}

	function parseExprNext(e1: Expr):Expr {
	    var t = token();
	    switch ( t ) {
            /* --EndOfFile-- */
            case _ if (eofStack[eofStack.length-1].equals( t )):
                eofStack.pop();
                return e1;

            case Dot:
                return parseExprNext(EField(e1, ident()));

            case Op(op):
                return makeBinop(op, e1, parseExpr());

            case Kwd("AND"):
                push(Op(Binop.LogAnd));
                return parseExprNext(e1);

            case Kwd("OR"):
                push(Op(Binop.LogOr));
                return parseExprNext(e1);

            case Kwd("IN"):
                push(Op(Binop.In));
                return parseExprNext(e1);

            case Kwd("LIKE"):
                push(Op(Binop.Like));
                return parseExprNext(e1);

            default:
                push( t );
                return e1;
	    }
	}

	function parseExpr():Expr {
		var t = token();
		switch( t ) {
            case Ident(_.toUpperCase()=>'NULL'): 
                return parseExprNext(CNull);
            case Ident(_.toUpperCase()=>'TRUE'): 
                return parseExprNext(CTrue);
            case Ident(_.toUpperCase()=>'FALSE'):
                return parseExprNext(CFalse);
            case Ident(id): 
                return parseExprNext(Expr.EId(id));
            case CInt(i): 
                return parseExprNext(Expr.CInt( i ));
            case CFloat(n): 
                return parseExprNext(Expr.CFloat( n ));
            case CString(s):
                return parseExprNext(Expr.CString(s));
            case POpen:
                var el = parseExprList(PClose);
                switch (el) {
                    case []: unexpected(PClose);
                    case [e]:
                        return parseExprNext(EParent(e));
                    case _:
                        return parseExprNext(EList(el));
                }
            default:
                unexpected(t);
		}
		return null;
	}

	function parseExprList(end: Token):Array<Expr> {
	    var res = [];
	    var t = token();
	    if (t.equals( end ))
	        return res;
	    push( t );
	    while (true) {
	        res.push(parseExpr());
	        t = token();
	        switch t {
                case Comma:
                    //

                default:
                    if (t.equals(end))
                        break;
                    unexpected( t );
	        }
	    }
	    return res;
	}
}

enum Token {
	Eof;
	CInt(v : Int);
	CFloat(v : Float);
	CString(v: String);
	Kwd(s : String);
	Ident(s : String);
	Op(op : Binop);

	Star;
	POpen;
	PClose;
	Comma;
	Dot;
	Not;
}

enum SqlError {
    UnexpectedChar(c: String);
    UnexpectedToken(t: Token, pos:haxe.PosInfos);

    Unclosed(c: String);
}

