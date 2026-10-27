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

class Counter(object):
    value: int = 0

    def set_value(self: "Counter", new_value: int) -> int:
        self.value = new_value
        return self.value

count: int = 0
values = [1, 2, 3]
c = Counter()
c.set_value(total(values))
count = c.value
print(count, not False and True or None is None)
