# Valid ChocoPy sample covering literals, expressions, declarations, functions,
# classes, assignments, method calls, and compound statements.
def total(items: [int]) -> int:
    result: int = 0
    for item in items:
        if item > 0:
            result = result + item
        else:
            result = result - item
    return result

def arithmetic(a: int, b: int) -> [int]:
    results: [int] = None
    results = [a + b, a - b, a * b, a // b, a % b, -a, - -b]
    return results + [(a + b) * (a - b) // 2]

def compare(a: int, b: int) -> [bool]:
    relations: [bool] = None
    relations = [a == b, a != b, a < b, a > b, a <= b, a >= b]
    return relations + [a is b, not a == b, a < b or a > b and a != 0]

class Counter(object):
    value: int = 0

    def set_value(self: "Counter", new_value: int) -> int:
        self.value = new_value
        return self.value

class Book(object):
    title: str = ""
    pages: int = 0
    borrowed: bool = False
    next: "Book" = None

    def describe(self: "Book") -> str:
        if self.borrowed:
            return self.title + " (borrowed)"
        else:
            return self.title

    def is_long(self: "Book", threshold: int) -> bool:
        return self.pages > threshold and not self.borrowed

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

    for book in books:
        add(book)
    count = count + seen
    return total

def report(message: str):
    if debug:
        print(message)

count: int = 0
debug: bool = False
verbose: bool = True
title: str = "Library"
quote: str = "She said \"hi\"\tand left\\\n"
owner: object = None
shelf: [int] = None
grid: [[int]] = None
books: [Book] = None
b: Book = None
relations: [bool] = None
result: int = 0
limit: int = 2147483647

values = [1, 2, 3]
c = Counter()
c.set_value(total(values))
count = c.value
print(count, not False and True or None is None)

b = Book()
b.title = "Compilers"
b.pages = limit
b.borrowed = False
b.next = Book()
b.next.title = "Dragon"
books = [b, b.next]

shelf = [1, 2, 3]
grid = [[1, 2], [3, 4], []]
result = b.pages = shelf[0] = grid[1][0] = 7
result = 1 if result > 5 else 2 if result > 3 else 3
verbose = not debug and (result >= 0 or count < 0)
owner = None if verbose else b

if result < 0:
    report("negative")
elif result == 0:
    report("zero")
elif result > 100:
    pass
else:
    while count < len(shelf):
        if shelf[count] % 2 == 0:
            report("even")
        count = count + 1

for item in arithmetic(17, 5):
    print(item)
for relation in compare(1, 2):
    print(relation)

title = b.next.describe()
print(books[1].is_long(100))
print(total_pages(books))
print(compare(1, 2)[6])
print(title + quote)
