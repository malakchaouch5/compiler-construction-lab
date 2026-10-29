# PA1 presentation: speaker notes

Group 4: Omar Kamel and Malak Chaouch. Notes for each slide of PA1_Group4_Presentation.pdf.

## 1. A ChocoPy front-end: lexing and parsing

Omar opens. Introduce the group and the goal of PA1: turn ChocoPy source code into an abstract syntax tree in JSON, using JFlex for the scanner and CUP for an LALR(1) parser. We split the talk: Omar presents the lexer and the testing, Malak the grammar, the AST and error recovery.

## 2. From ChocoPy source to a JSON syntax tree

Omar. The pipeline has two generated components. JFlex turns our specification ChocoPy.jflex into the class ChocoPyLexer, which produces tokens. CUP turns ChocoPy.cup into an LALR(1) parser whose actions build the AST nodes from chocopy.common.astnodes. The driver prints the Program node as JSON. Results: all 33 sample tests pass, and on 11,329 programs our JSON is identical to the reference implementation, including every source location. CUP reports no conflicts: the expression grammar has one rule per precedence level, so it is not ambiguous.

## 3. The lexer works in two states

Omar. Indentation is context-sensitive, so a single set of regular expressions is not enough. JFlex lexical states give us that context: YYINITIAL means we are at the beginning of a line, LINE_BODY that we are inside a logical line. The first real character of a line moves us to LINE_BODY, a line break returns NEWLINE and moves us back. Within a state JFlex applies maximal munch from the lecture: the longest match wins, and on a tie the rule written first. Therefore the keyword rules come before the identifier rule. The 16 Python keywords that ChocoPy reserves but does not use become one RESERVED token, which no grammar rule accepts. As the specification requires, the lexer never reports errors itself: anything else becomes UNRECOGNIZED.

## 4. Indentation: one rule, a stack and yypushback

Omar. This is the core of our answer to question 1 of the write-up. Blank and comment-only lines are matched together with their line break and ignored, so they never produce NEWLINE, INDENT or DEDENT. For every other line one rule matches the leading whitespace plus the first real character. We push that character back and compute the indentation; a tab goes to the next multiple of eight. Then we compare with the stack from the manual, which starts with 0. Deeper: push, one INDENT. Same: nothing. Shallower: we pop one level and return one DEDENT, but we push the whole whitespace back into the input. On the next call the same rule matches again and emits the next DEDENT, until the level is equal. So one line can produce several tokens without an extra token queue; this is the yypushback hint from the specification. At end of input the EOF rule closes the last line and all open blocks.

## 5. Example: the tokens of two nested blocks

Omar. This is the real output of our lexer, printed with java chocopy.pa1.ChocoPyLexer. Dots stand for spaces. Line 2 is deeper than 0, so we push 4 and emit INDENT; line 3 pushes 8. Lines 4 and 5 are blank or only a comment, so they produce nothing and do not change the stack, even though the comment is indented. On line 6 the level is 0: the rule pops 8 and returns a DEDENT, pushes the whitespace back, pops 4 and returns the second DEDENT, and on the third pass the level matches, so we switch to LINE_BODY and scan b. This is the same scheme as the indentation example in the lexing slides of the lecture.

## 6. Literals and the edge cases we checked

Omar. String literals are a sequence of printable ASCII characters 32 to 126 with four escapes. The token value is the text with the escapes applied. If that value has the syntax of an identifier, the token is IDSTRING, because the grammar accepts such strings as type names, for example self: "Book". A string with an illegal escape or character is matched as a whole by a second regular expression and returned as UNRECOGNIZED, exactly like the reference. Integers must fit into a signed 32-bit int. Our first version used Long.parseLong, and the mutation fuzzer produced 21474836472147483647, which crashed it; now we catch the NumberFormatException from Integer.parseInt and return UNRECOGNIZED. 007 is three tokens because a literal may only start with 0 if it is exactly 0. Then I hand over to Malak for the parser.

## 7. Expressions: one rule per precedence level

Malak. For expressions I wrote one nonterminal per precedence level of the table in section 4.1 of the manual, from expression at the top down to postfix and atom. A level only refers to itself and to the next level: arithmetic ::= arithmetic PLUS term is left recursive, so 1 - 2 - 3 groups to the left, and TIMES lives one level lower in term, so it binds tighter than PLUS. This is the second approach from the bottom-up parsing lecture: instead of an ambiguous grammar with a precedence table, the grammar itself is unambiguous. CUP reports no conflicts, and it still reports none if all precedence declarations are deleted; only the %prec UMINUS on the unary minus rule uses one. Comparisons are written as arithmetic LT arithmetic, so a second comparison operator cannot follow and a < b < c is an error at the second operator. not is above comparison, so True == not False is an error at not. The conditional expression has a conditional_expression on both sides of else, so a if b else c if d else e nests to the right.

## 8. Building the AST: elif and exact locations

Malak. The AST has one IfStmt kind with a single else body, so elif is syntactic sugar: an elif becomes an IfStmt that is the only statement of the else body. The hard part was the end location. Both IfStmt nodes end at the DEDENT of the last block of the whole chain, and the outer rule has not seen that DEDENT when its own block ends. So the rest of the chain is parsed into the nonterminal if_tail, which returns a small helper object, IfTail, with the else body and the end location of the last DEDENT, and every level copies that end. Locations were the most detailed part of the parser and my answer to question 2: the hidden tests compare the full JSON, so every location must match the reference. The basic rule is from the left end of the leftmost symbol to the right end of the rightmost symbol, using the CUP variables xleft and xright, so parentheses count. A statement node ends before its NEWLINE, but a FuncDef takes its end from the function body symbol, which includes the NEWLINE of the last statement. Compound statements end at the DEDENT of their block, and Omar's lexer places each DEDENT over the indentation of the following line, as the reference does.

## 9. Error recovery with the error symbol

Malak. When CUP meets a syntax error it pops states from its stack until one can shift the special token error, then skips input until the token after error fits, and continues. All my recovery rules end with NEWLINE, so a broken line is skipped up to its end. First, statements: statement ::= error NEWLINE means that a bad statement costs only its own line; the next statement is parsed normally, and the broken one produces no AST node. Second, function headers: in def f(a, b) -> int: the parameter b has no type. Skipping to the NEWLINE would leave the indented body, which does not fit anywhere and causes follow-up errors. The rule DEF error NEWLINE INDENT function_body DEDENT still parses the body, so a real error inside it is reported too, and then the function is dropped. Third, classes: a wrong member line such as y = 1 without a type is skipped by class_decl_list error NEWLINE, and the other members stay; a broken class header works like a broken function header. The specification requires that the first error is reported at the same token as in the reference parser, and it is, on every one of the more than eleven thousand programs we compared. After the first error our parser reports fewer follow-up errors than the reference.

## 10. Result on our bad.py

Malak. This is my bad.py. It starts with two broken print calls, and after that come declarations: a variable, a function with an untyped parameter, and a class with a member that has no type. In ChocoPy all declarations must come before the first statement, so each of these declarations is itself a syntax error, and that is what both parsers report: line 11 at the colon of value. The first error, 3:11, is the one the hidden tests compare, and it is the same as in the reference. Our parser reports nine errors in total, and the reference reports every one of them too. The reference reports seventeen: it also complains about the DEDENT at the end of each block and about the second token of some declarations. Ours reports fewer because CUP, after recovering from an error, only reports the next error once it has parsed a few tokens successfully. The rest of the file shows recovery inside statements: a chained comparison, an unknown character, not as an operand of ==, and a while without a colon are each reported on their own line, and the valid print calls between them stay in the AST.

## 11. The reference parser as a test oracle

Omar. The provided test mode does not compare locations: an early version of our lexer put the last DEDENT one column off, and stmt_if.py still passed. Because the hidden tests compare the whole JSON, we built our own check. A small Java harness calls chocopy.reference.RefParser and our StudentParser in one JVM on every file, reading the file exactly like the driver does. For a valid program the full JSON trees must be equal; for an invalid one the first error must be at the same line and column, which is what the specification says is graded. Input: the 35 given tests, 99 edge cases we wrote, and 11,195 mutants generated by randomly deleting, inserting, duplicating or swapping tokens and changing indentation. All 11,329 comparisons succeed. The harness found real bugs in our code: Long.parseLong crashing on a twenty-digit literal, wrong columns of the DEDENT tokens at the end of the input, and in the parser, global and nonlocal declarations accepted outside functions and a parameter list starting with a comma.

## 12. What we found in the reference and the material

Omar. The specification asks us to report bugs in the reference implementation and mistakes in the material. First, the reference lexer does not emit a NEWLINE at the end of input when the file has no final line break, although the manual says the end of input terminates the last line. You only see it when calling RefParser or the reference lexer directly, because the driver appends a line break to every file. Second, DEDENT tokens at the end of input get invented positions on a line after the file. We copy this behaviour, because our output is compared with the reference. Third, the message for an error at a DEDENT shows the text of the previous token. Fourth, the local test mode ignores locations. Finally two small mistakes in the specification and one in the manual. All of them are in the README with an input that shows the problem.

## 13. Who did what

Malak closes. Summarize: the lexer handles indentation with two states, a stack and yypushback; the parser has one rule per precedence level and builds the AST with exact locations; error recovery skips a broken line or header and keeps parsing; and the result matches the reference on every program we tried. Each of us owned one part, but we reviewed all of it together, so either of us can answer questions about any file.

## 14. Where each part lives in the code

Backup slide for the questions. If the instructors ask about a part of the code, open the file at these lines. Both of us can answer for every row: Omar wrote the lexer rows and Malak the grammar rows, and we reviewed each other's code line by line before submitting. The error rules are on lines 174, 190-193, 208 and 266 of ChocoPy.cup.

## 15. Thank you. Questions?

Leave this slide up during the Q and A. If asked for a demo, run the two commands: the build, then the tests, which print 35 passed. Good demo inputs: src/test/data/pa1/student_contributed/bad.py with --pass=s to show our error messages, and the same file with --pass=r for the reference. For the token stream, run java -cp with the two jars and chocopy.pa1.ChocoPyLexer followed by a file name.
