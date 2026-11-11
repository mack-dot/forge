using System;
using System.Collections.Generic;
using System.Diagnostics.Contracts;
using System.Linq;
using System.Numerics;
using System.Text;

namespace Microsoft.Dafny.Compilers {
  public class Bake {
    // NOTE We do not consistently throw errors on unsupported
    //   features, so it is possible that a program we don't
    //   actually support gets translated into something similar.

    // TODO? Use NormalizeExpand() on types?

    private static string seq_name = "Then";

    public static string ProgramToString(Program program) {
      var compileModules = program.CompileModules;

      // For now, we only consider programs with a single module besides
      // the system module
      if (compileModules.Count() != 2) {
        throw UnsupportedError(compileModules);
      }
      if (!compileModules.First().Name.Equals("_System")) {
        throw UnsupportedError(compileModules.First());
      }

      // The single module we consider should only have a DefaultClassDecl
      var topLevelDecls = compileModules.ElementAt(1).TopLevelDecls;
      if (topLevelDecls.Count() != 1) {
        throw UnsupportedError(topLevelDecls);
      }
      var defaultClassDecl = (DefaultClassDecl)topLevelDecls.First();
      var members = defaultClassDecl.Members;


      return StringListToString([
        "Program",
        ListToString(MemberDeclToString, members)
      ]);
    }

    // Helper functions in case we need to handle these nodes less naively,
    // that is, do more than pretending they are complicated lists of expressions
    public static string AttributedExpressionToString(AttributedExpression attrExp) =>
      ExpressionToString(attrExp.E);

    public static string FrameExpSpecToString(Specification<FrameExpression> specs) {
      var expressions = specs.Expressions;

      // Instead of mapping "null" to None, map it to []
      expressions ??= [];

      return ListToString(ExpressionToString, expressions.Select(x => x.E));
    }

    public static string ExpSpecToString(Specification<Expression> specs) =>
      ListToString(ExpressionToString, specs.Expressions);

    public static string MemberDeclToString(MemberDecl member) {
      if (member is Method method) {
        var name = method.Name;
        var ins = method.Ins;
        var req = method.Req;
        var ens = method.Ens;
        var reads = method.Reads;
        var decreases = method.Decreases;
        var outs = method.Outs;
        var mod = method.Mod;

        // Make sure there is a return statement at the end
        var body = method.Body;
        var bodyBody = body.Body;

        if (bodyBody.Count == 0 || bodyBody[bodyBody.Count - 1] is not ReturnStmt) {
          body.AppendStmt(new ReturnStmt(Token.NoToken, null, null));
        }

        return StringListToString([
          "Method",
          EscapeAndQuote(name),
          ListToString(FormalToString, ins),
          ListToString(AttributedExpressionToString, req),
          ListToString(AttributedExpressionToString, ens),
          FrameExpSpecToString(reads),
          ExpSpecToString(decreases),
          ListToString(FormalToString, outs),
          FrameExpSpecToString(mod),
          StatementToString(body)
        ]);
      } else if (member is Function function) {
        var name = function.Name;
        var ins = function.Ins;
        var resultType = function.ResultType;
        var req = function.Req;
        var reads = function.Reads;
        var decreases = function.Decreases;
        var body = function.Body;

        return StringListToString([
          "Function",
          EscapeAndQuote(name),
          ListToString(FormalToString, ins),
          TypeToString(resultType),
          ListToString(AttributedExpressionToString, req),
          FrameExpSpecToString(reads),
          ExpSpecToString(decreases),
          ExpressionToString(body)
        ]);
      } else {
        throw UnsupportedError(member);
      }
    }

    public static string FormalToString(Formal formal) {
      var name = formal.Name;
      var type = formal.Type;

      return StringListToString([
        EscapeAndQuote(name),
        TypeToString(type)
      ]);
    }

    public static string TypeToString(Type type) {
      if (type is TypeProxy typeProxy) {
        return TypeToString(typeProxy.T);
      }

      if (type.IsStringType) {
        return StringListToString(["StrT"]);
      } else if (type is IntType) {
        return StringListToString(["IntT"]);
      } else if (type is BoolType) {
        return StringListToString(["BoolT"]);
      } else if (type.IsArrayType) {
        var arrayType = type.AsArrayType;
        if (arrayType.Dims != 1) {
          throw UnsupportedError(type);
        }

        // Resolve type argument
        Contract.Assert(type.TypeArgs.Count == 1);

        return StringListToString([
          "ArrT",
          TypeToString(type.TypeArgs[0])
        ]);
      } else {
        throw UnsupportedError(type);
      }
    }

    public static LiteralExpr InitExpr(Type type) {
      if (type is IntType) {
        return new LiteralExpr(Token.NoToken, 0);
      } else {
        throw UnsupportedError(type);
      }
    }
    public static string VarDeclToStringAux(List<Statement> scope, List<LocalVariable> localsVars) {
      string BuildString(LocalVariable var, string rest) =>
          StringListToString(["Dec", LocalVariableToString(var), rest]);

      return localsVars switch {
        [] => throw new Exception("Expected at least one local to be declared"),
        [LocalVariable localVar] => BuildString(localVar, StatementListToString(scope)),
        [LocalVariable localVar, .. var rest] => BuildString(localVar, VarDeclToStringAux(scope, rest))
      };
    }

    public static string VarDeclToString(VarDeclStmt varDeclStmt, List<Statement> scope) {
      var locals = varDeclStmt.Locals;
      var assign = varDeclStmt.Assign;

      // Make assignment part of scope
      if (assign is not null) {
        scope.Insert(0, assign);
      }

      return VarDeclToStringAux(scope, locals);
    }

    public static string IdentifierExprToString(IdentifierExpr identifierExpr, bool isLhs) {
      var name = identifierExpr.Name;

      return StringListToString([
        isLhs ? "VarLhs" : "Var",
        EscapeAndQuote(name)
      ]);
    }

    public static string SeqSelectExprToString(SeqSelectExpr seqSelectExpr, bool isLhs) {
      var selectOne = seqSelectExpr.SelectOne;
      var seq = seqSelectExpr.Seq;
      var e0 = seqSelectExpr.E0;
      var e1 = seqSelectExpr.E1;

      if (selectOne && seq.Type.IsArrayType) {
        Contract.Assert(e0 != null && e1 == null);
        return StringListToString([
          isLhs ? "ArrSelLhs" : "ArrSel",
          ExpressionToString(seq),
          ExpressionToString(e0)
        ]);
      } else {
        throw UnsupportedError(seqSelectExpr);
      }
    }

    public static string LhsToString(Expression expression) {
      if (expression.WasResolved()) {
        expression = expression.Resolved;
      }

      if (expression is IdentifierExpr identifierExpr) {
        return IdentifierExprToString(identifierExpr, true);
      } else if (expression is SeqSelectExpr seqSelectExpr) {
        return SeqSelectExprToString(seqSelectExpr, true);
      } else {
        throw UnsupportedError(expression);
      }
    }

    public static string SimplePrintToString(Expression arg) {
      if (arg.WasResolved()) {
        arg = arg.Resolved;
      }

      var type = arg.Type;

      return StringListToString([
        "Print",
        ExpressionToString(arg),
        TypeToString(type)
      ]);
    }

    public static string SplitPrintToString(List<Expression> args) =>
      args switch {
        [] => "",
        [Expression arg] => SimplePrintToString(arg),
        [Expression arg, .. var rest] =>
          StringListToString([
            seq_name,
            SimplePrintToString(arg),
            SplitPrintToString(rest)
          ])
      };

    public static IEnumerable<string> AssignToString(List<Expression> lhss, List<AssignmentRhs> rhss) =>
      (lhss, rhss) switch {
        ([], []) => [],
        ([Expression lhs, .. var lhssRest], [AssignmentRhs rhs, .. var rhssRest]) =>
          AssignToString(lhssRest, rhssRest).Prepend(
            StringListToString([
              LhsToString(lhs),
              RhsExpToString(rhs)])),
          _ => throw new Exception("Expected equal number of LHS and RHS expressions")
      };

    public static string StatementToString(Statement statement) {
      if (statement is AssignStatement assignStatement) {
        var lhss = assignStatement.Lhss;
        var rhss = assignStatement.Rhss;

        if (rhss.Count == 1 && IsMethodCall(rhss[0])) {
          return MethodCallToString(lhss, rhss[0]);
        } else {
          Contract.Assert(!rhss.Any(IsMethodCall));
          Contract.Assert(lhss.Count == rhss.Count);

          return StringListToString([
            "Assign",
            StringListToString(AssignToString(lhss, rhss))
          ]);
        }
      } else if (statement is IfStmt ifStmt) {
        var guard = ifStmt.Guard;
        var thn = ifStmt.Thn;
        var els = ifStmt.Els;

        return StringListToString([
          "If",
          ExpressionToString(guard),
          StatementToString(thn),
          NullableStatementToString(els)
        ]);
      } else if (statement is VarDeclStmt varDeclStmt) {
        return VarDeclToString(varDeclStmt, null);
      } else if (statement is WhileStmt whileStmt) {
        var guard = whileStmt.Guard;
        var invariants = whileStmt.Invariants;
        var decreases = whileStmt.Decreases;
        var mod = whileStmt.Mod;
        var body = whileStmt.Body;

        return StringListToString([
          "While",
          ExpressionToString(guard),
          ListToString(AttributedExpressionToString, invariants),
          ExpSpecToString(decreases),
          FrameExpSpecToString(mod),
          StatementToString(body)
        ]);
      } else if (statement is BlockStmt blockStmt) {
        return StatementListToString(blockStmt.Body);
      } else if (statement is PrintStmt printStmt) {
        var args = printStmt.Args;

        return SplitPrintToString(args);

      } else if (statement is ReturnStmt returnStmt) {
        var return_string = StringListToString(["Return"]);
        var hiddenUpdate = returnStmt.HiddenUpdate;

        if (hiddenUpdate is null) {
          return return_string;
        } else {
          return StringListToString([
            seq_name,
            StatementToString(hiddenUpdate),
            return_string
          ]);
        }
      } else if (statement is AssertStmt assertStmt) {
        var expr = assertStmt.Expr;

        return StringListToString([
          "Assert",
          ExpressionToString(expr)
        ]);
      } else {
        throw UnsupportedError(statement);
      }
    }

    public static string StatementListToString(List<Statement> stmts) =>
      stmts switch {
        [] => StringListToString(["Skip"]),
        [var stmt] => StatementToString(stmt),
        [VarDeclStmt varDecl, .. var rest] =>
          VarDeclToString(varDecl, rest),
        [var stmt, .. var rest] =>
          StringListToString([
            seq_name,
            StatementToString(stmt),
            StatementListToString(rest)
          ])
      };

    public static string ExpressionToString(Expression expression) {
      if (expression.WasResolved()) {
        expression = expression.Resolved;
      }

      if (expression is IdentifierExpr identifierExpr) {
        return IdentifierExprToString(identifierExpr, false);
      } else if (expression is UnaryOpExpr unaryOpExpr) {
        var rop = unaryOpExpr.ResolvedOp;
        var e = unaryOpExpr.E;

        return StringListToString([
          "UnOp",
          ResolvedUnOpcodeToString(rop),
          ExpressionToString(e)
        ]);
      } else if (expression is BinaryExpr binaryExpr) {
        var rop = binaryExpr.ResolvedOp;
        var e0 = binaryExpr.E0;
        var e1 = binaryExpr.E1;

        return StringListToString([
          "BinOp",
          ResolvedBinOpcodeToString(rop),
          ExpressionToString(e0),
          ExpressionToString(e1)
        ]);
      } else if (expression is LiteralExpr literalExpr) {
        string valueAsString;

        var value = literalExpr.Value;
        if (expression is StringLiteralExpr stringLiteralExpr) {
          var isVerbatim = stringLiteralExpr.IsVerbatim;

          if (isVerbatim) {
            throw UnsupportedError(stringLiteralExpr);
          }

          valueAsString = StringListToString([
            "StrL",
            EscapeAndQuote((string)value)
          ]);
        } else if (expression is StaticReceiverExpr) {
          // We do not support receivers, so reaching the point
          // probably means we have an unnecessary field somewhere.
          throw UnsupportedError(expression);
        } else if (value is BigInteger bigInteger) {
          valueAsString = StringListToString([
            "IntL",
            bigInteger.ToString()
          ]);
        } else if (LiteralExpr.IsTrue(literalExpr)) {
          valueAsString = StringListToString([
            "BoolL",
            "True"
          ]);
        } else if (LiteralExpr.IsFalse(literalExpr)) {
          valueAsString = StringListToString([
            "BoolL",
            "False"
         ]);
        } else {
          throw UnsupportedError(literalExpr);
        }

        return StringListToString([
          "Lit",
          valueAsString
        ]);
      } else if (expression is SeqSelectExpr seqSelectExpr) {
        return SeqSelectExprToString(seqSelectExpr, false);
      } else if (expression is ITEExpr iteeExpr) {
        var test = iteeExpr.Test;
        var thn = iteeExpr.Thn;
        var els = iteeExpr.Els;

        return StringListToString([
          "Exp_If",
          ExpressionToString(test),
          ExpressionToString(thn),
          ExpressionToString(els)
        ]);

      } else if (expression is FunctionCallExpr functionCallExpr) {
        var name = functionCallExpr.Name;
        var receiver = functionCallExpr.Receiver;
        var args = functionCallExpr.Args;

        if (receiver is StaticReceiverExpr staticReceiver) {
          // We can drop the receiver, since we only support
          // default for now.
          return StringListToString([
            "FunCall",
            EscapeAndQuote(name),
            ListToString(ExpressionToString, args)
          ]);
        } else {
          throw UnsupportedError(functionCallExpr);
        }
      } else if (expression is MemberSelectExpr memberSelectExpr) {
        var obj = memberSelectExpr.Obj.Resolved;
        var name = memberSelectExpr.MemberName;

        // For now, only support length for one-dimensional arrays
        var type = obj.Type;
        if (name == "Length" && type.IsArrayType && type.AsArrayType.Dims == 1) {
          return StringListToString([
            "ArrLen",
            ExpressionToString(obj)
          ]);
        } else {
          throw UnsupportedError(memberSelectExpr);
        }
      } else if (expression is ForallExpr forallExpr) {
        // NOTE We ignore attributes, which may contain triggers; these might be useful?
        var origin = forallExpr.Origin;
        var boundVars = forallExpr.BoundVars;
        var range = forallExpr.Range;
        var term = forallExpr.Term;

        if (range is not null) {
          throw UnsupportedError(forallExpr);
        }

        var splitForall = SplitForall(origin, boundVars, term);

        // At this point, we know that we have exactly one bound var

        return StringListToString([
          "Forall",
          BoundVarToString(splitForall.BoundVars[0]),
          ExpressionToString(splitForall.Term)
        ]);
      } else if (expression is OldExpr oldExpr) {
        var e = oldExpr.E;
        var atLabel = oldExpr.AtLabel;

        if (atLabel is not null) {
          throw UnsupportedError(oldExpr);
        }

        return StringListToString([
          "OldHeap",
          ExpressionToString(e)
        ]);
      } else {
        throw UnsupportedError(expression);
      }
    }

    public static ForallExpr SplitForall(IOrigin origin, List<BoundVar> boundVars, Expression term) =>
      // NOTE Assumes that range is null
      boundVars switch {
        [] => throw new Exception("Expected at least one bound variable"),
        [BoundVar boundVar] =>
          new ForallExpr(origin, [boundVar], null, term),
        [BoundVar boundVar, .. var rest] =>
          new ForallExpr(origin, [boundVar], null, SplitForall(origin, rest, term))
      };

    public static string BoundVarToString(BoundVar boundVar) {
      var name = boundVar.Name;
      var type = boundVar.Type;

      // Note that this is essentially a tuple
      return StringListToString([
        EscapeAndQuote(name),
        TypeToString(type)
      ]);
    }

    public static string LocalVariableToString(LocalVariable localVariable) {
      var name = localVariable.Name;
      var type = localVariable.Type;

      return StringListToString([
        EscapeAndQuote(name),
        TypeToString(type)
      ]);
    }

    public static string ResolvedUnOpcodeToString(UnaryOpExpr.ResolvedOpcode rop) =>
      rop switch {
        UnaryOpExpr.ResolvedOpcode.BoolNot => StringListToString(["Not"]),
        _ => throw UnsupportedError(rop)
      };

    public static string ResolvedBinOpcodeToString(BinaryExpr.ResolvedOpcode rop) =>
      rop switch {
        BinaryExpr.ResolvedOpcode.Lt => StringListToString(["Lt"]),
        BinaryExpr.ResolvedOpcode.Le => StringListToString(["Le"]),
        BinaryExpr.ResolvedOpcode.Ge => StringListToString(["Ge"]),
        BinaryExpr.ResolvedOpcode.EqCommon => StringListToString(["Eq"]),
        BinaryExpr.ResolvedOpcode.NeqCommon => StringListToString(["Neq"]),
        BinaryExpr.ResolvedOpcode.Sub => StringListToString(["Sub"]),
        BinaryExpr.ResolvedOpcode.Add => StringListToString(["Add"]),
        BinaryExpr.ResolvedOpcode.Mul => StringListToString(["Mul"]),
        BinaryExpr.ResolvedOpcode.Div => StringListToString(["Div"]),
        BinaryExpr.ResolvedOpcode.And => StringListToString(["And"]),
        BinaryExpr.ResolvedOpcode.Imp => StringListToString(["Imp"]),
        BinaryExpr.ResolvedOpcode.Or => StringListToString(["Or"]),
        BinaryExpr.ResolvedOpcode.Mod => StringListToString(["Mod"]),
        _ => throw UnsupportedError(rop)
      };

    // Method calls are special right-hand side expressions, as they can return
    // multiple things; hence, we deal with them separately.

    // Determining method calls like this has been "discovered" by looking at
    // concrete examples, and CloneExpr in ExtremeLemmaBodyCloner.cs
    public static bool IsMethodCall(AssignmentRhs rhs) =>
      rhs is ExprRhs exprRhs && exprRhs.Expr is ApplySuffix && !exprRhs.Expr.WasResolved();

    public static string MethodCallToString(List<Expression> lhss, AssignmentRhs rhs) {
      Contract.Assert(IsMethodCall(rhs));

      var exprRhs = (ExprRhs)rhs;
      var expr = exprRhs.Expr;
      var applySuffix = (ApplySuffix)expr;
      var mse = (MemberSelectExpr)applySuffix.Lhs.Resolved;
      Contract.Assert(mse.Member is Method);
      var name = mse.MemberName;

      // Get arguments
      var args = applySuffix.Bindings.ArgumentBindings.
        Select(b => b.Actual.Resolved);

      return StringListToString([
        "MetCall",
        ListToString(LhsToString, lhss),
        EscapeAndQuote(name),
        ListToString(ExpressionToString, args)
      ]);
    }

    public static string RhsExpToString(AssignmentRhs assignmentRhs) {
      Contract.Assert(!IsMethodCall(assignmentRhs));

      if (assignmentRhs is ExprRhs exprRhs) {
        var expr = exprRhs.Expr;

        return StringListToString([
          "ExpRhs",
          ExpressionToString(expr)
        ]);
      } else if (assignmentRhs is AllocateArray allocateArray) {
        var arrayDimensions = allocateArray.ArrayDimensions;
        var elementInit = allocateArray.ElementInit;
        var initDisplay = allocateArray.InitDisplay;
        var explicitType = allocateArray.ExplicitType;

        if (arrayDimensions.Count != 1) {
          throw UnsupportedError(arrayDimensions);
        }

        if (initDisplay is not null && elementInit is not null) {
          // This should not happen
          Contract.Assert(false);
        }

        var length = arrayDimensions[0];

        if (initDisplay is not null) {
          throw UnsupportedError(assignmentRhs);
        } else {
          var initValue = elementInit is null ? InitExpr(allocateArray.ExplicitType) : elementInit;

          return StringListToString([
            "ArrAlloc",
            ExpressionToString(length),
            ExpressionToString(initValue),
            TypeToString(explicitType)
          ]);
        }
      } else {
        throw UnsupportedError(assignmentRhs);
      }
    }

    public static string NullableStatementToString(Statement stmt) {
      if (stmt is null) {
        return StringListToString(["Skip"]);
      } else {
        return StatementToString(stmt);
      }
    }

    public static string StringListToString(IEnumerable<string> xs) {
      return ListToString(x => x, xs);
    }

    public static string ListToString<T>(Func<T, string> f, IEnumerable<T> xs) {
      return "(" + string.Join(" ", xs.Select(f).Where(x => x != "")) + ")";
    }

    public static string EscapeAndQuote(string str) {
      ArgumentNullException.ThrowIfNull(str);

      StringBuilder sb = new StringBuilder();
      sb.Append('"');
      foreach (char c in str) {
        if (c == '"') {
          sb.Append('\\');
        }
        sb.Append(c);
      }
      sb.Append('"');
      return sb.ToString();
    }

    private static ExtractorError UnsupportedError(object obj) {
      var typeName = obj.GetType().Name;
      var startToken = (obj is INode) ? ((INode)obj).StartToken : Token.NoToken;

      return new ExtractorError(startToken, $"Unsupported {typeName}: {obj}\n{Environment.StackTrace}");
    }
  }
}