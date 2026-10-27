# Invalid syntax examples on separate lines, with valid statements to exercise
# parser recovery after each error.
print(1 + )
print(2)

print(3 + )

print(4)

# Variable initializers must be literals, not expressions.
value: int = 1 + 2
after_initializer_error: int = 3

# Function header errors should not prevent later top-level statements.
def broken(a: int, b) -> int:
    local: int = a
    return a + b
print(5)

# Class bodies should recover after an invalid member.
class Pair(object):
    first: int = 0
    second = 1
    third: int = 2
after_class_error: int = 6

# Chained comparisons are not allowed.
if 1 < value < 3:
    print(value)
print(7)

# Unknown characters and an invalid logical-operator combination are errors.
value = value && 1
print(True == not False)
print(9)

# A missing colon in a compound statement should recover at the next line.
while value > 0
    value = value - 1
print(10)
