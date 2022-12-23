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
