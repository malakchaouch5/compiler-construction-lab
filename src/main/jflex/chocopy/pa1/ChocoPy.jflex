package chocopy.pa1;
import java_cup.runtime.*;
import java.util.ArrayDeque;
import java.util.Deque;

%%

/*** Do not change the flags below unless you know what you are doing. ***/

%unicode
%line
%column

%class ChocoPyLexer
%public

%cupsym ChocoPyTokens
%cup
%cupdebug

%eofclose false

/*** Do not change the flags above unless you know what you are doing. ***/

/* The lexer works in two states:
 *   YYINITIAL  - we are at the beginning of a physical line and still have
 *                to decide whether the line is blank and how far it is
 *                indented (this is where INDENT/DEDENT tokens come from);
 *   LINE_BODY  - we are inside a logical line and produce ordinary tokens
 *                until the line break, which becomes a NEWLINE token. */
%state LINE_BODY

/* The following code section is copied verbatim to the
 * generated lexer class. */
%{
    /* The code below includes some convenience methods to create tokens
     * of a given type and optionally a value that the CUP parser can
     * understand. Specifically, a lot of the logic below deals with
     * embedded information about where in the source code a given token
     * was recognized, so that the parser can report errors accurately.
     * (It need not be modified for this project.) */

    /** Producer of token-related values for the parser. */
    final ComplexSymbolFactory symbolFactory = new ComplexSymbolFactory();

    /** Return a terminal symbol of syntactic category TYPE and no
     *  semantic value at the current source location. */
    private Symbol symbol(int type) {
        return symbol(type, yytext());
    }

    /** Return a terminal symbol of syntactic category TYPE and semantic
     *  value VALUE at the current source location. */
    private Symbol symbol(int type, Object value) {
        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[type], type,
            new ComplexSymbolFactory.Location(yyline + 1, yycolumn + 1),
            new ComplexSymbolFactory.Location(yyline + 1,yycolumn + yylength()),
            value);
    }

    /** Return a terminal symbol of syntactic category TYPE with semantic
     *  value VALUE that spans the columns FIRSTCOLUMN..LASTCOLUMN
     *  (1-based, inclusive) of the current line. Used for the
     *  INDENT/DEDENT tokens, whose extent is the leading whitespace of a
     *  line rather than the text matched by the current rule. */
    private Symbol symbolInLine(int type, Object value,
                                int firstColumn, int lastColumn) {
        return symbolFactory.newSymbol(ChocoPyTokens.terminalNames[type], type,
            new ComplexSymbolFactory.Location(yyline + 1, firstColumn),
            new ComplexSymbolFactory.Location(yyline + 1, lastColumn),
            value);
    }

    /* ---------------------------------------------------------------
     * Indentation handling (Section 3.1.5 of the ChocoPy reference).
     * --------------------------------------------------------------- */

    /** Tab stops are every TAB_WIDTH columns, as in Python and Unix. */
    private static final int TAB_WIDTH = 8;

    /** Indentation levels of the enclosing blocks.  The bottom element is
     *  always 0 and the levels strictly increase towards the top. */
    private final Deque<Integer> indentStack = new ArrayDeque<>();
    {
        indentStack.push(0);
    }

    /** Number of DEDENT tokens emitted so far at the end of the input. */
    private int eofDedents = 0;

    /** Return the indentation level of the whitespace WS, where a tab
     *  advances to the next multiple of TAB_WIDTH and a space counts as 1. */
    private static int indentationOf(String ws) {
        int width = 0;
        for (int i = 0; i < ws.length(); i++) {
            if (ws.charAt(i) == '\t') {
                width += TAB_WIDTH - (width % TAB_WIDTH);
            } else {
                width += 1;
            }
        }
        return width;
    }

    /* ---------------------------------------------------------------
     * Literals.
     * --------------------------------------------------------------- */

    /** Return the value of the string literal LITERAL (including its
     *  surrounding quotes) with the escape sequences \" \n \t \\ applied.
     *  The lexical rule guarantees that no other escapes occur. */
    private static String unescape(String literal) {
        StringBuilder value = new StringBuilder();
        for (int i = 1; i < literal.length() - 1; i++) {
            char c = literal.charAt(i);
            if (c == '\\') {
                i += 1;
                switch (literal.charAt(i)) {
                    case 'n':  value.append('\n'); break;
                    case 't':  value.append('\t'); break;
                    default:   value.append(literal.charAt(i)); /* \" or \\ */
                }
            } else {
                value.append(c);
            }
        }
        return value.toString();
    }

    /** Return true iff S has the syntax of an identifier, which makes a
     *  string literal containing S usable as a class name (IDSTRING). */
    private static boolean isIdentifier(String s) {
        return s.matches("[a-zA-Z_][a-zA-Z_0-9]*");
    }
%}

/* Macros (regexes used in rules below) */

WhiteSpace = [ \t]
LineBreak  = \r|\n|\r\n
Comment    = "#" [^\r\n]*

IntegerLiteral = 0 | [1-9][0-9]*
Identifier     = [a-zA-Z_][a-zA-Z_0-9]*

/* Printable ASCII (32-126) except the double quote and the backslash,
 * plus the four legal escape sequences. */
StringChar      = [\x20-\x21\x23-\x5B\x5D-\x7E] | \\[\"nt\\]
StringLiteral   = \" {StringChar}* \"

/* Anything that looks like a string literal on a single line but contains
 * an illegal character or escape sequence.  It is matched as a whole so
 * that the lexer can resynchronise after it. */
BadStringLiteral = \" ([^\"\\\r\n] | \\[^\r\n])* \"

%%


/* ===================================================================
 * Beginning of a physical line: blank lines and indentation.
 * =================================================================== */
<YYINITIAL> {

  /* Lines containing only whitespace and/or a comment are ignored
   * entirely (Section 3.1.4): no NEWLINE, INDENT or DEDENT. */
  {WhiteSpace}* {Comment}? {LineBreak}  { /* ignore */ }

  /* The same for a last line that has no line break before EOF. */
  {WhiteSpace}+ | {WhiteSpace}* {Comment} { /* ignore */ }

  /* Leading whitespace of a logical line, followed by its first
   * character.  Compare the indentation with the top of the stack. */
  {WhiteSpace}* [^ \t\r\n#] {
      yypushback(1);                       /* keep the first real char */
      int indentation = indentationOf(yytext());
      int width = yylength();

      if (indentation > indentStack.peek()) {
          indentStack.push(indentation);
          yybegin(LINE_BODY);
          return symbolInLine(ChocoPyTokens.INDENT, yytext(), 1, width);
      }
      if (indentation < indentStack.peek()) {
          /* Close one block per call: re-scan the same whitespace so that
           * this rule fires again until the level matches the stack. */
          indentStack.pop();
          yypushback(width);
          return symbolInLine(ChocoPyTokens.DEDENT, "", 1, width);
      }
      yybegin(LINE_BODY);                  /* same level: no token */
  }
}


/* ===================================================================
 * Inside a logical line.
 * =================================================================== */
<LINE_BODY> {

  /* End of the logical line. */
  {LineBreak}                 { yybegin(YYINITIAL);
                                return symbol(ChocoPyTokens.NEWLINE); }

  /* Whitespace between tokens and comments are skipped. */
  {WhiteSpace}+               { /* ignore */ }
  {Comment}                   { /* ignore */ }

  /* Keywords that are used by the ChocoPy grammar. */
  "and"                       { return symbol(ChocoPyTokens.AND); }
  "class"                     { return symbol(ChocoPyTokens.CLASS); }
  "def"                       { return symbol(ChocoPyTokens.DEF); }
  "elif"                      { return symbol(ChocoPyTokens.ELIF); }
  "else"                      { return symbol(ChocoPyTokens.ELSE); }
  "False"                     { return symbol(ChocoPyTokens.FALSE, false); }
  "for"                       { return symbol(ChocoPyTokens.FOR); }
  "global"                    { return symbol(ChocoPyTokens.GLOBAL); }
  "if"                        { return symbol(ChocoPyTokens.IF); }
  "in"                        { return symbol(ChocoPyTokens.IN); }
  "is"                        { return symbol(ChocoPyTokens.IS); }
  "None"                      { return symbol(ChocoPyTokens.NONE); }
  "nonlocal"                  { return symbol(ChocoPyTokens.NONLOCAL); }
  "not"                       { return symbol(ChocoPyTokens.NOT); }
  "or"                        { return symbol(ChocoPyTokens.OR); }
  "pass"                      { return symbol(ChocoPyTokens.PASS); }
  "return"                    { return symbol(ChocoPyTokens.RETURN); }
  "True"                      { return symbol(ChocoPyTokens.TRUE, true); }
  "while"                     { return symbol(ChocoPyTokens.WHILE); }

  /* Python keywords that ChocoPy reserves but does not use.  They are
   * not identifiers, and no grammar rule accepts them. */
  "as" | "assert" | "async" | "await" | "break" | "continue" | "del"
  | "except" | "finally" | "from" | "import" | "lambda" | "raise"
  | "try" | "with" | "yield"  { return symbol(ChocoPyTokens.RESERVED); }

  /* Identifiers (after the keywords, so that keywords win ties). */
  {Identifier}                { return symbol(ChocoPyTokens.IDENTIFIER, yytext()); }

  /* Integer literals must fit in a signed 32-bit int (Section 3.4.2). */
  {IntegerLiteral}            {
      try {
          return symbol(ChocoPyTokens.INTEGER, Integer.parseInt(yytext()));
      } catch (NumberFormatException tooLarge) {
          return symbol(ChocoPyTokens.UNRECOGNIZED);
      }
  }

  /* String literals.  Strings whose contents look like an identifier
   * may also be used as type names, hence the separate IDSTRING. */
  {StringLiteral}             {
      String value = unescape(yytext());
      return symbol(isIdentifier(value) ? ChocoPyTokens.IDSTRING
                                        : ChocoPyTokens.STRING, value);
  }
  {BadStringLiteral}          { return symbol(ChocoPyTokens.UNRECOGNIZED); }

  /* Operators. */
  "+"                         { return symbol(ChocoPyTokens.PLUS); }
  "-"                         { return symbol(ChocoPyTokens.MINUS); }
  "*"                         { return symbol(ChocoPyTokens.TIMES); }
  "//"                        { return symbol(ChocoPyTokens.IDIV); }
  "%"                         { return symbol(ChocoPyTokens.MOD); }
  "<"                         { return symbol(ChocoPyTokens.LT); }
  ">"                         { return symbol(ChocoPyTokens.GT); }
  "<="                        { return symbol(ChocoPyTokens.LEQ); }
  ">="                        { return symbol(ChocoPyTokens.GEQ); }
  "=="                        { return symbol(ChocoPyTokens.EQEQ); }
  "!="                        { return symbol(ChocoPyTokens.NEQ); }
  "="                         { return symbol(ChocoPyTokens.EQ); }

  /* Delimiters. */
  "("                         { return symbol(ChocoPyTokens.LPAREN); }
  ")"                         { return symbol(ChocoPyTokens.RPAREN); }
  "["                         { return symbol(ChocoPyTokens.LINDEX); }
  "]"                         { return symbol(ChocoPyTokens.RINDEX); }
  ","                         { return symbol(ChocoPyTokens.COMMA); }
  ":"                         { return symbol(ChocoPyTokens.COLON); }
  "."                         { return symbol(ChocoPyTokens.DOT); }
  "->"                        { return symbol(ChocoPyTokens.ARROW); }
}

/* End of input: terminate the last logical line if the file does not end
 * with a line break, then close every open block, then report EOF. */
<<EOF>>                       {
      if (yystate() == LINE_BODY) {
          yybegin(YYINITIAL);
          return symbolInLine(ChocoPyTokens.NEWLINE, "",
                              yycolumn + 1, yycolumn + 1);
      }
      if (indentStack.peek() > 0) {
          /* The k-th DEDENT at the end of input is placed at column k of
           * the line after the last one, as the reference parser does. */
          indentStack.pop();
          eofDedents += 1;
          return symbolInLine(ChocoPyTokens.DEDENT, "",
                              eofDedents, eofDedents);
      }
      return symbol(ChocoPyTokens.EOF);
  }

/* Error fallback: the lexer never fails, it hands an UNRECOGNIZED token
 * to the parser, which has no rule for it and reports a syntax error. */
[^]                           { return symbol(ChocoPyTokens.UNRECOGNIZED); }
