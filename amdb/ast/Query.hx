package amdb.ast;

/**
  ADT for representing SQL query-statement
 **/
enum Query {
	Select(fields:Array<Field>, table:QuerySrc, cond:Expr);
	Insert(target:String, ?columns:Array<String>, values:Array<Expr>);
	CreateTable(table:String, fields : Array<FieldDesc>, props : Array<TableProp> );
	AlterTable(table:String, alters : Array<AlterCommand> );
}

enum QuerySrc {
    Table(name: String);
    Alias(src:QuerySrc, alias:String);
    Join(kind:JoinKind, left:QuerySrc, right:QuerySrc, predicate:Expr);

    Subquery(query: Query);
}

/**
  ADT for SQL statement-expression
 **/
enum Expr {
	CTrue;
	CFalse;
	CNull;
	CInt(i: Int);
	CFloat(n: Float);
	CString(v: String);
	
	EParent(e: Expr);
	EList(arr: Array<Expr>);
	EId(id: String);
	EField(e:Expr, field:String);
	EBinop(op:Binop, l:Expr, r:Expr);
	ECall(e:Expr, args:Array<Expr>);

	EQuery(q: Query);
}

enum Binop {
	Eq;
	NEq;
	In;
	Like;

	Add;
	Sub;
	Div;
	Mult;

	LogAnd;
	LogOr;
}

enum Unop {
    Not;
}

typedef Field = {
	?table: String,
	?field: String,
	?alias: String,
	?all: Bool
};

enum SqlType {
	SInt;
	SFloat;
	SBigInt;
	SDouble;

	SText;
    SBlob;
	SDate;
	SDateTime;
}

typedef FieldDesc = {
    name: String,
    ?type: SqlType,
    ?notNull: Bool,
    ?autoIncrement: Bool,
    ?unique: Bool,
    ?primaryKey: Bool,
    ?digits: Int
};

enum TableProp {
	PrimaryKey(field : Array<String>);
	Engine(name : String);
}

enum AlterCommand {
	AddConstraintFK( name : String, field : String, table : String, targetField : String, ?onDelete : FKDelete );
}

enum QueryOrder {
    ASC;
    DESC;
}

enum JoinKind {
    JoinLeft;
    JoinRight;
    JoinInner;
    JoinOuter;
}

enum CreateTableEntry {
    TableField(field: FieldDesc);
    TableProp(prop: TableProp);
}

enum FKDelete {
	FKDSetNull;
	FKDCascade;
}
