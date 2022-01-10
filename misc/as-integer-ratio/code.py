from math import floor


def as_integer_ratio(f: float) -> tuple[int, int]:
    """
    Represents a floating point number as a ratio of two integers.

    .. seealso::
     - `Proof <https://github.com/Prometheus3375/lua-std/blob/main/misc/as-integer-ratio/proof.md>`_
     - `Inspiration <https://groups.google.com/g/sci.math/c/8nqj1x7xmWg/m/umKDlL4N8xgJ>`_
    """
    mul = 1 if f >= 0 else -1
    x = f = abs(f)

    ai = floor(x)
    n1, d1 = ai, 1  # current ratio
    n0, d0 = 1, 0  # previous ratio

    while n1 != f * d1:
        x = 1 / (x - ai)  # next x
        ai = floor(x)

        n1, n0 = n1 * ai + n0, n1  # next numerator
        d1, d0 = d1 * ai + d0, d1  # next denominator

    return mul * n1, d1


if __name__ == '__main__':
    import math

    print(as_integer_ratio(0.1))
    print(as_integer_ratio(0.3))
    print(as_integer_ratio(0.33333333))
    print(as_integer_ratio(math.pi))
