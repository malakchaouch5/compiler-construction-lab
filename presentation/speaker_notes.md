# PA1 presentation: speaker notes

Group 4: Omar Kamel and Malak Chaouch. Notes for each slide of PA1_Group4_Presentation.pdf.

## 1. A ChocoPy front-end: lexing and parsing

Omar opens. Introduce the group and the goal of PA1: turn ChocoPy source code into an abstract syntax tree in JSON, using JFlex for the scanner and CUP for an LALR(1) parser. We split the talk: Omar presents the lexer and the testing, Malak the grammar, the AST and error recovery.

## 2. Four problems that took most of our time

Omar. Everyone built the same pipeline, so we skip it and go straight to the four problems that cost us the most time. One: the lexer must turn indentation into INDENT and DEDENT tokens, sometimes several for one line. Two: the hidden tests compare the full JSON, so every node needs the same location as in the reference. Three: after a syntax error the parser has to continue and still report the first error at the same token. Four: the local --test mode only checks where nodes start, not where they end, so we needed another way to know the output is right. The result: all 35 local tests pass, and on 11,329 programs our output is identical to the reference. At the end we show two known problems that we left in, and why. I start with the lexer, Malak explains the parser and error recovery, and I finish with testing.

## 3. Indentation: one rule, a stack and yypushback

Omar. This is the core of our answer to question 1 of the write-up. Blank and comment-only lines are matched together with their line break and ignored, so they never produce NEWLINE, INDENT or DEDENT. For every other line one rule matches the leading whitespace plus the first real character. We push that character back and compute the indentation; a tab goes to the next multiple of eight. Then we compare with the stack from the manual, which starts with 0. Deeper: push, one INDENT. Same: nothing. Shallower: we pop one level and return one DEDENT, but we push the whole whitespace back into the input. On the next call the same rule matches again and emits the next DEDENT, until the level is equal. So one line can produce several tokens without an extra token queue; this is the yypushback hint from the specification. At end of input the EOF rule closes the last line and all open blocks.

## 4. Example: the tokens of two nested blocks

Omar. This is the real output of our lexer, printed with java chocopy.pa1.ChocoPyLexer. Dots stand for spaces. Line 2 is deeper than 0, so we push 4 and emit INDENT; line 3 pushes 8. Lines 4 and 5 are blank or only a comment, so they produce nothing and do not change the stack, even though the comment is indented. On line 6 the level is 0: the rule pops 8 and returns a DEDENT, pushes the whitespace back, pops 4 and returns the second DEDENT, and on the third pass the level matches, so we switch to LINE_BODY and scan b. This is the same scheme as the indentation example in the lexing slides of the lecture.

## 5. Literals and the edge cases we checked

Omar. String literals are a sequence of printable ASCII characters 32 to 126 with four escapes. The token value is the text with the escapes applied. If that value has the syntax of an identifier, the token is IDSTRING, because the grammar accepts such strings as type names, for example self: "Book". A string with an illegal escape or character is matched as a whole by a second regular expression and returned as UNRECOGNIZED, exactly like the reference. Integers must fit into a signed 32-bit int. Our first version used Long.parseLong, and the mutation fuzzer produced 21474836472147483647, which crashed it; now we catch the NumberFormatException from Integer.parseInt and return UNRECOGNIZED. 007 is three tokens because a literal may only start with 0 if it is exactly 0. Then I hand over to Malak for the parser.

## 6. Precedence without a single conflict

Malak. The usual way is an ambiguous expression grammar plus a precedence table, and CUP resolves the conflicts. Instead, I wrote one nonterminal per precedence level of the table in the manual; on the slide the names are shortened. A level only refers to itself and to the next one. arith ::= arith PLUS term is left recursive, so 1 - 2 - 3 groups to the left, and TIMES is one level lower in term, so it binds tighter than PLUS. CUP reports no conflicts, even when all precedence declarations are deleted; only the unary minus uses %prec. The structure also gives the right errors for free: a comparison has arith on both sides, so a < b < c fails at the second operator, exactly where the reference fails. And not is above comparison, so True == not False fails at not.

## 7. Building the AST: elif and exact locations

Malak. Locations were the hardest part of the parser, because the hidden tests compare the full JSON. The AST has no elif node: an elif becomes an IfStmt that is the only statement of the else body. The problem is the end location. Both IfStmt nodes end at the DEDENT of the last block of the whole chain, and the outer rule has not seen that DEDENT yet when its own block ends. So the rest of the chain is parsed into the nonterminal if_tail, which returns a small helper object, IfTail, with the else body and the end of the last DEDENT, and every level copies that end. The other rules are on the bottom row: a node spans from its leftmost to its rightmost symbol, so parentheses count; a statement ends before its NEWLINE, but a function takes its end from the body, which includes the NEWLINE of its last statement; and if, while and for end at the DEDENT, which Omar's lexer places over the indentation of the next line, as the reference does.

## 8. Where does a Program start and end?

Malak. The Program node looks easy, but it has special cases. A file that contains only pass statements has an empty statement list, because pass creates no AST node, yet the reference still gives the Program a location: [1, 1, 1, 5] for a single pass. A comment line at the top does not count, so the program starts at the first real token, and an empty file gets zeros. Computing this from the declaration and statement lists cannot work when they are empty. So the parser overrides scan(), the method that hands every token from the lexer to the parser. It remembers where the first token that is not a NEWLINE starts, and where the last NEWLINE or DEDENT ends. The start_program rule then builds the Program node from these two positions and falls back to zeros for an empty file. The code on the slide is shortened; the real version also checks for EOF and the symbol type. With it, all 11,329 programs match the reference, including these three cases.

## 9. A broken line costs only that line

Malak. Without error rules, CUP stops at the first syntax error and checks nothing after it. When CUP meets an error and a rule with the special token error exists, it pops states from its stack until one can shift error, then skips input until the token after error fits, and continues. All my recovery rules end with NEWLINE, so a broken line is skipped up to its end. In the first example, x = 1 + ends without a right operand, so the error is at the NEWLINE in column 8; the line is dropped, and y = 2 is parsed as usual. In the second example, the member y = 2 has no type, which is an error at the equals sign. The rule class_decl_list error NEWLINE skips only that line, so the class keeps its members x and z. For both files our parser gives exactly the same error and the same AST as the reference. The rules are on lines 190 to 193 and 266 of ChocoPy.cup.

## 10. A broken header: still check the body

Malak. Headers were the harder case. In def f(a: int, b) -> int: the parameter b has no type, so the error is at the closing parenthesis in column 16. If the recovery only skipped the header line, the parser would then see an INDENT that fits nowhere, and recovering from that would skip the first line of the body together with the error in it. So the rule for a broken header is DEF error NEWLINE INDENT function_body DEDENT: it skips the rest of the header line and then parses the body with the normal function_body rule. That is why the second error, return a + without a right operand, is still found at line 2, column 15. After the body, the function is dropped, because a FuncDef without a valid header cannot be built, and print(1) after it is parsed normally. Broken class headers work the same way with class_decl_list. Our parser and the reference report exactly these two errors for this file. The rules are on lines 174 and 208 of ChocoPy.cup.

## 11. Result on our bad.py

Malak. This is my bad.py. It starts with two broken print calls, and the declarations after them are errors already because of their position: in ChocoPy all declarations must come before the first statement. The first error, 3:11, is the one the hidden tests compare, and it is the same as in the reference. Our parser reports nine errors, and the reference reports every one of them too, but it reports seventeen in total. Omar explains this difference at the end. The rest of the file shows recovery inside statements: a chained comparison, an unknown character, not as an operand of ==, and a while without a colon are each reported on their own line, and the valid print calls between them stay in the AST.

## 12. The reference parser as a test oracle

Omar. The provided test mode only compares where nodes start, not where they end: an early version of our lexer put the last DEDENT one column off, and stmt_if.py still passed. Because the hidden tests compare the whole JSON, we built our own check. A small Java harness calls chocopy.reference.RefParser and our StudentParser in one JVM on every file, reading the file exactly like the driver does. For a valid program the full JSON trees must be equal; for an invalid one the first error must be at the same line and column, which is what the specification says is graded. Input: the 35 given tests, 99 edge cases we wrote, and 11,195 mutants generated by randomly deleting, inserting, duplicating or swapping tokens and changing indentation. All 11,329 comparisons succeed. The harness found real bugs in our code: Long.parseLong crashing on a twenty-digit literal, wrong columns of the DEDENT tokens at the end of the input, and in the parser, global and nonlocal declarations accepted outside functions and a parameter list starting with a comma.

## 13. What we found in the reference and the material

Omar. The specification asks us to report bugs in the reference implementation and mistakes in the material. First, the reference lexer does not emit a NEWLINE at the end of input when the file has no final line break, although the manual says the end of input terminates the last line. You only see it when calling RefParser or the reference lexer directly, because the driver appends a line break to every file. Second, the message for an error at a DEDENT shows the text of the previous token. Third, the local test mode checks where nodes start but ignores where they end. Finally two small mistakes in the specification and one in the manual. All of them are in the README with an input that shows the problem. The invented DEDENT positions at the end of input come on the next slide.

## 14. Two problems we left in, and why

Omar. Two things are not as they should be, and we left both in on purpose. First, after the first error we report fewer errors than the reference: nine against seventeen on bad.py, and all nine are in the reference list. The reason is in CUP: after it recovers from an error, it only reports a new error once three tokens have been parsed, which is the method error_sync_size, and we kept the default. The reference also reports the DEDENT after each broken block. Only the first error is graded, and it matches on every program; our harness also checks only the first error, so the rest of the list is untested. Second, at the end of the input the reference places the k-th DEDENT at column k of a line after the file, so a four-line program can end at line 5. That is wrong, but our output is compared with the reference, so we produce the same position, and we report it as a bug in the README.

## 15. Who did what

Malak closes. Summarize: the lexer handles indentation with two states, a stack and yypushback; the parser has one rule per precedence level and builds the AST with exact locations; error recovery skips a broken line or header and keeps parsing; and the result matches the reference on every program we tried. Each of us owned one part, but we reviewed all of it together, so either of us can answer questions about any file.

## 16. Where each part lives in the code

Backup slide for the questions. If the instructors ask about a part of the code, open the file at these lines. Both of us can answer for every row: Omar wrote the lexer rows and Malak the grammar rows, and we reviewed each other's code line by line before submitting. The error rules are on lines 174, 190-193, 208 and 266 of ChocoPy.cup.

## 17. Thank you. Questions?

Leave this slide up during the Q and A. If asked for a demo, run the two commands: the build, then the tests, which print 35 passed. Good demo inputs: src/test/data/pa1/student_contributed/bad.py with --pass=s to show our error messages, and the same file with --pass=r for the reference. For the token stream, run java -cp with the two jars and chocopy.pa1.ChocoPyLexer followed by a file name.
