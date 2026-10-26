# PA1 presentation: speaker notes

Group 4: Omar Kamel and Malak Chaouch. Notes for each slide of PA1_Group4_Presentation.pdf.

## 1. A ChocoPy front-end: lexing and parsing

Omar opens. Introduce the group and the goal of PA1: turn ChocoPy source code into an abstract syntax tree in JSON, using JFlex for the scanner and CUP for an LALR(1) parser. We split the talk: Omar presents the lexer and the testing, Malak the grammar, the AST and error recovery.

## 2. From ChocoPy source to a JSON syntax tree

Omar. The pipeline has two generated components. JFlex turns our specification ChocoPy.jflex into the class ChocoPyLexer, which produces tokens. CUP turns ChocoPy.cup into an LALR(1) parser whose actions build the AST nodes from chocopy.common.astnodes. The driver prints the Program node as JSON. Results: all 33 sample tests pass, and on 11,329 programs our JSON is identical to the reference implementation, including every source location. CUP reports no conflicts: the ambiguities of the expression grammar are resolved by precedence declarations.

## 3. The lexer works in two states

Omar. Indentation is context-sensitive, so a single set of regular expressions is not enough. JFlex lexical states give us that context: YYINITIAL means we are at the beginning of a line, LINE_BODY that we are inside a logical line. The first real character of a line moves us to LINE_BODY, a line break returns NEWLINE and moves us back. Within a state JFlex applies maximal munch from the lecture: the longest match wins, and on a tie the rule written first. Therefore the keyword rules come before the identifier rule. The 16 Python keywords that ChocoPy reserves but does not use become one RESERVED token, which no grammar rule accepts. As the specification requires, the lexer never reports errors itself: anything else becomes UNRECOGNIZED.

## 4. Indentation: one rule, a stack and yypushback

Omar. This is the core of our answer to question 1 of the write-up. Blank and comment-only lines are matched together with their line break and ignored, so they never produce NEWLINE, INDENT or DEDENT. For every other line one rule matches the leading whitespace plus the first real character. We push that character back and compute the indentation; a tab goes to the next multiple of eight. Then we compare with the stack from the manual, which starts with 0. Deeper: push, one INDENT. Same: nothing. Shallower: we pop one level and return one DEDENT, but we push the whole whitespace back into the input. On the next call the same rule matches again and emits the next DEDENT, until the level is equal. So one line can produce several tokens without an extra token queue; this is the yypushback hint from the specification. At end of input the EOF rule closes the last line and all open blocks.

## 5. Example: the tokens of two nested blocks

Omar. This is the real output of our lexer, printed with java chocopy.pa1.ChocoPyLexer. Dots stand for spaces. Line 2 is deeper than 0, so we push 4 and emit INDENT; line 3 pushes 8. Lines 4 and 5 are blank or only a comment, so they produce nothing and do not change the stack, even though the comment is indented. On line 6 the level is 0: the rule pops 8 and returns a DEDENT, pushes the whitespace back, pops 4 and returns the second DEDENT, and on the third pass the level matches, so we switch to LINE_BODY and scan b. This is the same scheme as the indentation example in the lexing slides of the lecture.

## 6. Literals and the edge cases we checked

Omar. String literals are a sequence of printable ASCII characters 32 to 126 with four escapes. The token value is the text with the escapes applied. If that value has the syntax of an identifier, the token is IDSTRING, because the grammar accepts such strings as type names, for example self: "Book". A string with an illegal escape or character is matched as a whole by a second regular expression and returned as UNRECOGNIZED, exactly like the reference. Integers must fit into a signed 32-bit int. Our first version used Long.parseLong, and the mutation fuzzer produced 21474836472147483647, which crashed it; now we catch the NumberFormatException from Integer.parseInt and return UNRECOGNIZED. 007 is three tokens because a literal may only start with 0 if it is exactly 0. Then I hand over to Malak for the parser.

## 7. Expressions: ambiguous rules, precedences decide

Malak. For expressions we did not write one nonterminal per precedence level. We kept the short, ambiguous grammar of the manual, for example cexpr ::= cexpr PLUS cexpr, and let CUP resolve the conflicts with these declarations, taken from the precedence table in section 4.1 of the manual. This is the approach from the bottom-up parsing lecture: when the parser has cexpr PLUS cexpr on the stack and sees TIMES, the higher precedence of TIMES means shift; when it sees PLUS, left associativity means reduce. Comparisons are nonassoc, so a < b < c is an error at the second operator. Unary minus gets its own level with %prec UMINUS. We kept the expr/cexpr split of the manual: not, and, or and the conditional expression only take expr, so True == not False is a syntax error at not. The conditional expression is right associative, so a if b else c if d else e nests to the right.

## 8. Building the AST: elif and exact locations

Malak. The AST has one IfStmt kind with a single else body, so elif is syntactic sugar. Our rule else_part returns either the else block, or a list with exactly one nested IfStmt that starts at the elif keyword; the chain is built recursively. Locations were the most detailed part: the hidden tests compare the full JSON, so every location must match the reference. The rule is always: from the left end of the leftmost symbol to the right end of the rightmost symbol, using the CUP variables xleft and xright. Because we use the symbols and not the inner nodes, parentheses count. A statement node ends before its NEWLINE, but the CUP symbol of the statement includes it, and FuncDef and ClassDef take their end from that symbol. Compound statements end at the DEDENT of their block, and our lexer places each DEDENT over the indentation of the following line, as the reference does.

## 9. Three problems with the error symbol

Malak. This is our answer to question 2, the hardest part. When CUP meets an error it pops states until one can shift the error symbol, then skips input until it can continue. Our first version only had error NEWLINE in left-recursive lists. Problem 1: at the top level and in function bodies a declaration and a statement can start at the same position, so an error there could belong to either list; CUP reported shift/reduce conflicts on error, and an error on the very first token could not be recovered at all. We rewrote the bodies as right-recursive sequences: declarations, then statements. Now each position has exactly one rule that shifts error; before the first statement it belongs to the declarations, so declarations may still follow, as the specification requires. Problem 2: after a broken def or class header we skipped the line, but its indented body remained and produced follow-up errors. The second recovery rule parses that body and drops it, so real errors inside it are still reported. Problem 3: an LR parser can reduce a finished block only when the next token is a valid lookahead. If the next line starts with something like break, CUP popped the already shifted DEDENT and the parse failed at EOF. Every body now ends with the nonterminal dedent, which may absorb such a line, and the precedence of error over DEDENT tells CUP to prefer that shift. The grammar is in ChocoPy.cup, lines 232 to 296.

## 10. Result on our bad.py

Malak. bad.py contains twelve numbered syntax errors of different kinds: an expression where a literal is required, a parameter without a type, an error inside the body of that broken function, a class without a superclass, a bad member inside a class body, an assignment used as an expression, chained comparisons, an unknown character, not as an operand of ==, an unexpected indentation, a missing colon, and a reserved keyword as a name. Our parser reports all twelve, each exactly once and on the right line, and it keeps the correct declarations between them, such as y and origin, in the AST. The reference parser reports nineteen errors on the same file: several are follow-up errors at DEDENT tokens, and the errors on lines 12 and 25 are not reported at all. For grading only the position of the first error is compared, and there we match the reference on every one of more than eleven thousand invalid and valid programs, which is the next slide.

## 11. The reference parser as a test oracle

Omar. The provided test mode does not compare locations: an early version of our lexer put the last DEDENT one column off, and stmt_if.py still passed. Because the hidden tests compare the whole JSON, we built our own check. A small Java harness calls chocopy.reference.RefParser and our StudentParser in one JVM on every file, reading the file exactly like the driver does. For a valid program the full JSON trees must be equal; for an invalid one the first error must be at the same line and column, which is what the specification says is graded. Input: the 35 given tests, 99 edge cases we wrote, and 11,195 mutants generated by randomly deleting, inserting, duplicating or swapping tokens and changing indentation. All 11,329 comparisons succeed. The harness found real bugs in our code: Long.parseLong crashing on a twenty-digit literal, wrong columns of the DEDENT tokens at the end of the input, and the wrong start location of a program whose first statement is pass.

## 12. What we found in the reference and the material

Omar. The specification asks us to report bugs in the reference implementation and mistakes in the material. First, the reference lexer does not emit a NEWLINE at the end of input when the file has no final line break, although the manual says the end of input terminates the last line. You only see it when calling RefParser or the reference lexer directly, because the driver appends a line break to every file. Second, DEDENT tokens at the end of input get invented positions on a line after the file. We copy this behaviour, because our output is compared with the reference. Third, the message for an error at a DEDENT shows the text of the previous token. Fourth, the local test mode ignores locations. Finally two small mistakes in the specification and one in the manual. All of them are in the README with an input that shows the problem.

## 13. Who did what

Malak closes. Summarize: the lexer handles indentation with two states, a stack and yypushback; the parser uses an ambiguous expression grammar with precedences and builds the AST with exact locations; error recovery is conflict-free and reports each error once; and the result matches the reference on every program we tried. Each of us owned one part, but we reviewed all of it together, so either of us can answer questions about any file.

## 14. Where each part lives in the code

Backup slide for the questions. If the instructors ask about a part of the code, open the file at these lines. Both of us can answer for every row: Omar wrote the lexer rows and Malak the grammar rows, and we reviewed each other's code line by line before submitting.

## 15. Thank you. Questions?

Leave this slide up during the Q and A. If asked for a demo, run the two commands: the build, then the tests, which print 35 passed. Good demo inputs: src/test/data/pa1/student_contributed/bad.py with --pass=s to show the twelve errors, and the same file with --pass=r for the reference. For the token stream, run java -cp with the two jars and chocopy.pa1.ChocoPyLexer followed by a file name.
