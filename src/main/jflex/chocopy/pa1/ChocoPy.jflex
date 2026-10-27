package chocopy.pa1;
import java_cup.runtime.*;
import java.util.Stack;
import java.util.ArrayList;
import java.util.List;

%%

%unicode
%line
%column
%class ChocoPyLexer
%public
%cupsym ChocoPyTokens
%cup
%cupdebug
%eofclose false

%{
    final ComplexSymbolFactory symbolFactory = new ComplexSymbolFactory();
    private final Stack<Integer> indents = new Stack<Integer>();
    private final List<Symbol> pending = new ArrayList<Symbol>();
    private boolean atLineStart = true;
    private boolean eofDone = false;
    private int eofDedents = 0;
    private int previousToken = -1;
    private int tokenBeforePrevious = -1;
    private int pendingIndent = 0;
    private ComplexSymbolFactory.Location indentLeft;
    private ComplexSymbolFactory.Location indentRight;
    private String indentText = "";
    private Symbol symbol(int type) { return symbol(type, yytext()); }
    private Symbol symbol(int type, Object value) {
        int emittedType = type;
        if (type == ChocoPyTokens.STRING && value instanceof String
                && ((previousToken == ChocoPyTokens.COLON
                     && tokenBeforePrevious == ChocoPyTokens.ID)
                    || previousToken == ChocoPyTokens.ARROW)
                && !((String) value).matches("[A-Za-z_][A-Za-z_0-9]*")) {
            emittedType = ChocoPyTokens.INVALID_TYPE_STRING;
        }
        ComplexSymbolFactory.Location left =
            new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1);
        ComplexSymbolFactory.Location right =
            new ComplexSymbolFactory.Location(yyline + 1, yycolumn + yylength());
        if (type == ChocoPyTokens.NEWLINE || type == ChocoPyTokens.INDENT
                || type == ChocoPyTokens.DEDENT) {
            previousToken = -1;
            tokenBeforePrevious = -1;
        } else {
            tokenBeforePrevious = previousToken;
            previousToken = emittedType;
        }
        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[emittedType], emittedType,
            left, right, value);
    }
    private Symbol virtual(int type) {
        ComplexSymbolFactory.Location loc = new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1);
        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[type], type, loc, loc, null);
    }
    private Symbol dedent() {
        ComplexSymbolFactory.Location left = new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1);
        ComplexSymbolFactory.Location right = new ComplexSymbolFactory.Location(yyline + 1, yycolumn);
        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[ChocoPyTokens.DEDENT],
            ChocoPyTokens.DEDENT, left, right, "");
    }
    private Symbol eofDedent() {
        ComplexSymbolFactory.Location location =
            new ComplexSymbolFactory.Location(yyline + 1, ++eofDedents);
        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[ChocoPyTokens.DEDENT],
            ChocoPyTokens.DEDENT, location, location, "");
    }
    private String decodedStringLiteral() {
        String raw = yytext();
        StringBuilder decoded = new StringBuilder(raw.length() - 2);
        for (int i = 1; i < raw.length() - 1; i++) {
            char ch = raw.charAt(i);
            if (ch != '\\') {
                decoded.append(ch);
                continue;
            }
            char escaped = raw.charAt(++i);
            switch (escaped) {
            case '\\': decoded.append('\\'); break;
            case '"': decoded.append('"'); break;
            case 'n': decoded.append('\n'); break;
            case 't': decoded.append('\t'); break;
            default: throw new IllegalStateException("Unexpected string escape: \\" + escaped);
            }
        }
        return decoded.toString();
    }
    private Symbol endToken() {
        ComplexSymbolFactory.Location left =
            new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1);
        ComplexSymbolFactory.Location right =
            new ComplexSymbolFactory.Location(yyline + 1, yycolumn);
        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[ChocoPyTokens.END_OF_INPUT],
            ChocoPyTokens.END_OF_INPUT, left, right, null);
    }
    private Symbol queued() { return pending.remove(0); }
    private Symbol token(int type) { return token(type, yytext()); }
    private Symbol token(int type, Object value) {
        if (!pending.isEmpty()) {
            yypushback(yylength());
            return queued();
        }
        if (atLineStart) {
            int current = indents.empty() ? 0 : indents.peek();
            if (pendingIndent > current) {
                indents.push(pendingIndent);
                pending.add(symbolFactory.newSymbol(
                    ChocoPyTokens.terminalNames[ChocoPyTokens.INDENT],
                    ChocoPyTokens.INDENT, indentLeft, indentRight, indentText));
            } else {
                if (pendingIndent < current && pendingIndent != 0
                        && !indents.contains(pendingIndent)) {
                    ComplexSymbolFactory.Location left = indentLeft == null
                        ? new ComplexSymbolFactory.Location(yyline + 1, 1) : indentLeft;
                    ComplexSymbolFactory.Location right = indentRight == null
                        ? left : indentRight;
                    pending.add(symbolFactory.newSymbol(
                        ChocoPyTokens.terminalNames[ChocoPyTokens.UNRECOGNIZED],
                        ChocoPyTokens.UNRECOGNIZED, left, right, "<bad indentation>"));
                }
                while (!indents.empty() && pendingIndent < indents.peek()) {
                    indents.pop();
                    pending.add(dedent());
                }
            }
            pendingIndent = 0;
            atLineStart = false;
            if (!pending.isEmpty()) {
                yypushback(yylength());
                return queued();
            }
        }
        return symbol(type, value);
    }
%}

WhiteSpace = [ \t]
LineBreak = \r\n|\r|\n
Identifier = [a-zA-Z_][a-zA-Z_0-9]*
IntegerLiteral = 0|[1-9][0-9]*
StringChar = [\x20-\x21\x23-\x5B\x5D-\x7E]|\\[\\\"nt]
StringLiteral = \"{StringChar}*\"
BadStringLiteral = \"([^\"\\\r\n]|\\.)*\"
%%

<YYINITIAL> {
  {LineBreak} {
    if (!atLineStart) {
      atLineStart = true;
      pendingIndent = 0;
      indentLeft = null;
      indentRight = null;
      indentText = "";
      return symbol(ChocoPyTokens.NEWLINE);
    }
    pendingIndent = 0;
    indentLeft = null;
    indentRight = null;
    indentText = "";
  }
  {WhiteSpace}+ {
    if (atLineStart) {
      if (pendingIndent == 0) {
        indentLeft = new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1);
        indentText = yytext();
      } else {
        indentText += yytext();
      }
      indentRight = new ComplexSymbolFactory.Location(yyline + 1, yycolumn + yylength());
      for (int i = 0; i < yytext().length(); i++) {
        pendingIndent += yytext().charAt(i) == '\t' ? 8 - (pendingIndent % 8) : 1;
      }
    }
  }
  "#"[^\r\n]* { /* comment */ }
  "and" { return token(ChocoPyTokens.AND); }
  "or" { return token(ChocoPyTokens.OR); }
  "not" { return token(ChocoPyTokens.NOT); }
  "is" { return token(ChocoPyTokens.IS); }
  "if" { return token(ChocoPyTokens.IF); }
  "else" { return token(ChocoPyTokens.ELSE); }
  "elif" { return token(ChocoPyTokens.ELIF); }
  "while" { return token(ChocoPyTokens.WHILE); }
  "for" { return token(ChocoPyTokens.FOR); }
  "in" { return token(ChocoPyTokens.IN); }
  "def" { return token(ChocoPyTokens.DEF); }
  "class" { return token(ChocoPyTokens.CLASS); }
  "return" { return token(ChocoPyTokens.RETURN); }
  "pass" { return token(ChocoPyTokens.PASS); }
  "global" { return token(ChocoPyTokens.GLOBAL); }
  "nonlocal" { return token(ChocoPyTokens.NONLOCAL); }
  "True" { return token(ChocoPyTokens.TRUE); }
  "False" { return token(ChocoPyTokens.FALSE); }
  "None" { return token(ChocoPyTokens.NONE); }
  "as" { return token(ChocoPyTokens.RESERVED); }
  "assert" { return token(ChocoPyTokens.RESERVED); }
  "async" { return token(ChocoPyTokens.RESERVED); }
  "await" { return token(ChocoPyTokens.RESERVED); }
  "break" { return token(ChocoPyTokens.RESERVED); }
  "continue" { return token(ChocoPyTokens.RESERVED); }
  "del" { return token(ChocoPyTokens.RESERVED); }
  "except" { return token(ChocoPyTokens.RESERVED); }
  "finally" { return token(ChocoPyTokens.RESERVED); }
  "from" { return token(ChocoPyTokens.RESERVED); }
  "import" { return token(ChocoPyTokens.RESERVED); }
  "lambda" { return token(ChocoPyTokens.RESERVED); }
  "raise" { return token(ChocoPyTokens.RESERVED); }
  "try" { return token(ChocoPyTokens.RESERVED); }
  "with" { return token(ChocoPyTokens.RESERVED); }
  "yield" { return token(ChocoPyTokens.RESERVED); }
  {IntegerLiteral} { try { return token(ChocoPyTokens.NUMBER, Integer.valueOf(yytext())); } catch (NumberFormatException e) { return token(ChocoPyTokens.UNRECOGNIZED); } }
  {StringLiteral} { return token(ChocoPyTokens.STRING, decodedStringLiteral()); }
  {BadStringLiteral} { return token(ChocoPyTokens.UNRECOGNIZED); }
  {Identifier} { return token(ChocoPyTokens.ID); }
  "==" { return token(ChocoPyTokens.EQ); }
  "->" { return token(ChocoPyTokens.ARROW); }
  "!=" { return token(ChocoPyTokens.NE); }
  "<=" { return token(ChocoPyTokens.LE); }
  ">=" { return token(ChocoPyTokens.GE); }
  "+" { return token(ChocoPyTokens.PLUS); }
  "-" { return token(ChocoPyTokens.MINUS); }
  "*" { return token(ChocoPyTokens.MULT); }
  "//" { return token(ChocoPyTokens.DIV); }
  "%" { return token(ChocoPyTokens.MOD); }
  "<" { return token(ChocoPyTokens.LT); }
  ">" { return token(ChocoPyTokens.GT); }
  "=" { return token(ChocoPyTokens.ASSIGN); }
  ":" { return token(ChocoPyTokens.COLON); }
  "," { return token(ChocoPyTokens.COMMA); }
  "." { return token(ChocoPyTokens.DOT); }
  "(" { return token(ChocoPyTokens.LPAREN); }
  ")" { return token(ChocoPyTokens.RPAREN); }
  "[" { return token(ChocoPyTokens.LBRACKET); }
  "]" { return token(ChocoPyTokens.RBRACKET); }
}
<<EOF>> {
  if (!pending.isEmpty()) return queued();
  if (!eofDone) {
    eofDone = true;
    if (!atLineStart) {
      atLineStart = true;
      pending.add(virtual(ChocoPyTokens.NEWLINE));
    }
    while (!indents.empty()) { indents.pop(); pending.add(eofDedent()); }
    pending.add(endToken());
    return queued();
  }
  return null;
}
[^] { return token(ChocoPyTokens.UNRECOGNIZED); }
