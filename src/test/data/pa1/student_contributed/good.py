# A small library system that exercises (almost) every syntax rule of
# ChocoPy. This file must parse without any error.

# Global variable definitions with every kind of literal and type.
count: int = 0
limit: int = 2147483647
debug: bool = False
verbose: bool = True
title: str = "Library"
quote: str = "She said \"hi\"\tand left\\\n"
owner: object = None
shelf: [int] = None
grid: [[int]] = None
names: [str] = None
first: "Book" = None


# A class whose body is only `pass`.
class Item(object):
    pass


# A class with attributes and methods, and a forward reference ("Book").
class Book(Item):
    title: str = ""
    pages: int = 0
    borrowed: bool = False
    next: "Book" = None

    def __init__(self: "Book"):
        pass

    def describe(self: "Book") -> str:
        if self.borrowed:
            return self.title + " (borrowed)"
        else:
            return self.title

    def is_long(self: "Book", threshold: int) -> bool:
        return self.pages > threshold and not self.borrowed


# A function with nested functions, global and nonlocal declarations.
def total_pages(books: [Book]) -> int:
    global count
    total: int = 0
    seen: int = 0

    def add(book: Book) -> object:
        nonlocal total
        nonlocal seen
        total = total + book.pages
        seen = seen + 1
        return

    for b in books:
        add(b)
    count = count + seen
    return total


# A function without a return type.
def report(message: str):
    if debug:
        print(message)


# Every operator, in a single function.
def arithmetic(a: int, b: int) -> [int]:
    results: [int] = None
    results = [a + b, a - b, a * b, a // b, a % b, -a, - -b]
    results = results + [(a + b) * (a - b) // 2]
    return results


def compare(a: int, b: int) -> [bool]:
    # ChocoPy has no implicit line joining, so a list stays on one line.
    relations: [bool] = None
    relations = [a == b, a != b, a < b, a > b, a <= b, a >= b]
    return relations + [a is b, not a == b, a < b or a > b and a != 0]


x: int = 0
y: int = 10
b: Book = None
books: [Book] = None
i: int = 0
s: str = "abc"
c: str = ""
z: object = None
w: object = None

# Constructors, attribute assignment and method calls.
b = Book()
b.title = "Compilers"
b.pages = 1009
b.next = Book()
b.next.title = "Dragon"
books = [b, b.next]
first = books[0]

# Chained assignment to a variable, an attribute and a list element.
shelf = [1, 2, 3]
grid = [[1, 2], [3, 4], []]
x = b.pages = shelf[0] = grid[1][0] = 7

# Conditional expressions (right associative) and logical operators.
y = 1 if x > 5 else 2 if x > 3 else 3
verbose = not debug and (x >= 0 or y < 0)
z = None if verbose else b

# if / elif / else, nested blocks, while and for loops.
if x < 0:
    report("negative")
elif x == 0:
    report("zero")
elif x > 100:
    pass
else:
    while i < len(shelf):
        if shelf[i] % 2 == 0:
            report("even")
        i = i + 1

for c in s:
    print(c)

for x in arithmetic(17, 5):
    print(x)

# Indexing a string literal, calling methods on call results.
c = "hello"[1]
print(b.next.describe())
print(books[1].is_long(100))
print(total_pages(books))
print(compare(1, 2)[6])

# Blank lines and comments between statements are ignored.

        # even when they are indented
print(title + quote)
