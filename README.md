# Programming Assignment 1

[PA1 Specification]: https://studip.uni-passau.de/studip/dispatch.php/course/files?cid=1158ee3975665902d07585a824234cb1

[ChocoPy Language Manual and Reference]: https://studip.uni-passau.de/studip/dispatch.php/course/files?cid=1158ee3975665902d07585a824234cb1

Note: Users running Windows should replace the colon (`:`) with
a semicolon (`;`) in the classpath argument for
all commands listed below.

## Getting started

Run the following command to generate and compile your parser, and then run all the provided tests:

```bash
mvn clean package

java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s --test --dir src/test/data/pa1/sample/
```

In the starter code, only one test should pass. Your objective is to build a parser that passes all the provided tests and meets the assignment specifications.

To manually observe the output of your parser when run on a given input ChocoPy program, run the following command (replace the last argument to change the input file):

```bash
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=s src/test/data/pa1/sample/expr_plus.py
```

You can check the output produced by the staff-provided reference implementation on the same input file, as follows:

```bash
java -cp "chocopy-ref.jar:target/assignment.jar" chocopy.ChocoPy --pass=r src/test/data/pa1/sample/expr_plus.py
```

Try this with another input file as well, such as `src/test/data/pa1/sample/coverage.py`, to see what happens when the results disagree.

## Assignment specifications

See the [PA1 Specification][]
for a detailed specification of the assignment.

Refer to the [ChocoPy Language Manual and Reference][]
for the specification of the ChocoPy language.

## Submission write-up

(Students should edit this section with their write-up)

## Acknowledgments

This starter code is adapted from the work of the **ChocoPy team**
(see [this repository](https://github.com/cs164berkeley/pa1-chocopy-parser)). For more information, visit [ChocoPy.org](https://chocopy.org/).


