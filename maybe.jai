/// Rust-like optional type

Maybe :: struct(T: Type, SENTINEL: $S = void) {
    #if USES_SENTINEL {
        value: T = SENTINEL;
    } else {
        value:  T = ---;
        filled: bool;
    }

    USES_SENTINEL :: S != type_of(void);
}

Maybe_Tag :: enum {
    None;
    Some;
}

operator == :: (lhs: Maybe, rhs: Maybe_Tag) -> bool #expand {
    #if lhs.USES_SENTINEL {
        if lhs.value == lhs.SENTINEL return rhs == .None;
        return rhs == .Some;
    }
    else {
        if lhs.filled return rhs == .Some;
        return rhs == .None;
    }
}

operator == :: (lhs: Maybe, rhs: Maybe) -> bool #expand {
    #if lhs.USES_SENTINEL {
        return lhs.value == rhs.value;
    }
    else {
        return lhs.filled == rhs.filled && lhs.value == rhs.value;
    }
}

some :: (value: $T, $sentinel: $S = void) -> Maybe(T, sentinel) #expand {
    #if S == type_of(void) {
        v: Maybe(T) = ---;
        v.value  = value;
        v.filled = true;
    }
    else {
        v: Maybe(T, sentinel) = ---;
        v.value = value;
    }

    return v;
}

none :: ($T: Type, $sentinel: $S = void) -> Maybe(T, sentinel) #expand {
    v: Maybe(T, sentinel);
    return v;
}

unwrap :: (maybe: *Maybe) -> maybe.T #expand {
    return maybe.value;
}

is_some :: (maybe: Maybe) -> bool {
    #if maybe.USES_SENTINEL {
        return maybe.value != maybe.SENTINEL;
    }
    else {
        return maybe.filled;
    }
}

is_none :: (maybe: Maybe) -> bool {
    #if maybe.USES_SENTINEL {
        return maybe.value == maybe.SENTINEL;
    }
    else {
        return !maybe.filled;
    }
}

#if RUN_INTERNAL_TESTS #run {
    suite("Maybe", #code {
        test("some/none", (t) => {
            a: Maybe(int);
            a = some(10);

            expect(t, is_some(a), "expected 'a' to have a value!");
            expect(t, !is_none(a), "expected 'a' to have a value!");

            v := unwrap(*a);
            expect(t, v == 10, "expected 'v' to equal 10, instead equaled '%'", v);
        });

        test("returns maybe", (t) => {
            double_if_even :: (x: $T) -> Maybe(T) {
                if x % 2 == 0 {
                    return some(x * x);
                }

                return none(T);
            }

            expect(t, double_if_even(2) == .Some);
            expect(t, double_if_even(3) == .None);
        });

        test("sentinel value", (t) => {
            Valid_Index :: Maybe(int, -1);

            valid_index   :: (value: Valid_Index.T) -> Valid_Index #expand { return some(value, Valid_Index.SENTINEL); }
            invalid_index :: () -> Valid_Index #expand { return none(Valid_Index.T, Valid_Index.SENTINEL); }

            returns_index :: (ok: bool) -> Valid_Index {
                if !ok return invalid_index();
                return valid_index(1);
            }

            a := returns_index(true);
            b := returns_index(false);
            expect(t, a == .Some, "expected 'a' to have a value");
            expect(t, b == .None, "expected 'b' to not have a value");
        });
    });
}
