/// Iterator interface map, filter, collect utilities

/// If the parameter is constant, this allows iterators to be passed to procedures
Iterator :: #type (value: *$T, body: Code, flags: For_Flags);

/// Iterates over a string by rune. Declares 'it_offset' (offset to start of codepoint in string) in the body's scope.
iter_runes :: (to_iterate: *string, body: Code, flags: For_Flags) #expand {
    if !<<to_iterate then return;

    byte_index  := 0;
    byte_offset := 0;

    str   := <<to_iterate;
    width := str.data;
    while str.count {
        r, status := utf8_next_character(*str);
        if status != .CONVERSION_OK then break;

        `it        := r;
        `it_index  := byte_index;
        `it_offset := byte_offset;

        #insert body;

        byte_offset += str.data - width;
        width = str.data;

        byte_index += 1;
    }
}

/// Here for consistency.
iter_ascii :: (to_iterate: *string, body: Code, flags: For_Flags) #expand {
    if !<<to_iterate then return;

    i   := 0;
    str := <<to_iterate;
    while i < str.count {
        `it       := str.data[i];
        `it_index := it;

        #insert body;
        i += 1;
    }
}

/// Array utilities
collect :: (input: $I, output: *[..]$O, $iter: Iterator) #expand {
    for :iter input array_add(output, it);
}

map :: (input: []$I, proc: (I) -> $O) -> []O {
    output: [..]O;
    for input array_add(*output, proc(it));
    return output;
}

// @Todo: Remove the output parameter, have it return []O
map_iter :: (input: $I, output: *[..]$O, $iter: Iterator, proc: (O) -> $B) {
    for :iter input array_add(output, proc(it));
}

filter :: (input: []$I, proc: (I) -> bool) -> []I {
    output: [..]I;
    for input if proc(it) array_add(*output, it);
    return output;
}

filter_iter :: (input: $I, output: *[..]$O, $iter: Iterator, proc: (O) -> bool) {
    for :iter input if proc(it) array_add(output, it);
}
