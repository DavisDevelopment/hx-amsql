package amdb.tools;

import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.Type;

using haxe.macro.ExprTools;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;

class EnumBuilders {
    #if macro
    public static function enumFlatCopy(typeName: String):Array<Field> {
        var src: Type, srcE:EnumType;
        try {
            src = Context.getType( typeName );
            srcE = switch src {
                case TEnum(_.get()=>e, params): e;
                case _: null;
            }
        }
        catch (err: Dynamic) {
            Context.error('Error: Unknown type $typeName', Context.currentPos());
            src = null;
            srcE = null;
        }

        if (src == null) {
            return [];
        }

        var fields:Array<Field> = new Array();

        for (key in srcE.constructs.keys()) {
            var c = srcE.constructs[key];
            var argc = 0, args = null;
            var ef = makeEnumField(c.name, (switch c.type {
                case TFun(_args, ret): 
                    argc = _args.length;
                    args = _args;
                    FieldType.FFun({
                        args: null,
                        expr: null,
                        ret: null
                    });

                case _: null;
            }));
            fields.push( ef );
            //ef.meta.push({
                //name: 'argc',
                //params: [macro $v{argc}],
                //position: ef.pos
            //});
        }

        fields = fields.filter(x -> x != null);

        return fields;
    }

    private static function makeEnumField(name, kind) {
        return {
            name: name,
            doc: null,
            meta: [],
            access: [],
            kind: kind,
            pos: Context.currentPos()
        };
    }
    #end
}
