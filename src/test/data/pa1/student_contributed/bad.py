# Each numbered line below contains one syntax error.  The parser must
# report every one of them and recover after each, so that the correct
# declarations and statements in between are still parsed.

# 1. Variable definitions only accept literals, not expressions.
x: int = 1 + 2
y: int = 3

# 2. A parameter without a type annotation breaks the function header;
#    the body is still parsed and the error inside it is reported (3).
def add(a: int, b) -> int:
    z: int = a
    return a + b

# 4. A class needs a superclass in parentheses.
class Point:
    x: int = 0

# The parser has recovered: this declaration is accepted.
origin: int = 0

# 5. A class body with an invalid member in the middle.
class Pair(object):
    first: int = 0
    second = 1
    third: int = 2

# 6. An assignment cannot be used as an expression.
x = (y = 2)
print(x)

# 7. Comparison operators are not associative.
if 1 < x < 3:
    print(x)

# 8. Unknown operator characters are reported as UNRECOGNIZED tokens.
x = x && y

# 9. `not` cannot be an operand of `==` without parentheses.
print(True == not False)

# 10. An unexpected indentation.
x = 1
    y = 2

# 11. A missing colon after a while condition.
while x > 0
    x = x - 1

# 12. Reserved Python keywords cannot be used as names.
lambda = 3

print("done")
