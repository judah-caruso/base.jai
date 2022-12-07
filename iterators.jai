/// Iterator interface with functional-style utilities (I have never used this)

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


#scope_file

#if RUN_INTERNAL_TESTS #run {
    suite("Iterators", #code {
        test("filter", (t) => {
            numbers  := int.[ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 ];
            filtered := filter(numbers, (num) => num % 2 == 0);
            expect(t, filtered.count == 7, "found too many numbers: % (%)", filtered, filtered.count);
        });

        test("collect", (t) => {
            str := "x안녕하세요x";

            runes: [..]rune;
            collect(str, *runes, iter_runes);
            expect(t, runes.count == 7, "runes had a count of %", runes.count);

            ascii := map(runes, (r) => r >= #char "a" && r <= #char "z");
            expect(t, ascii.count == 7);

            only_valid := filter(ascii, (r) => r);
            expect(t, only_valid.count == 2);
        });

        test("map", (t) => {
            array := int.[ 0, 1, 2, 3, 4, 5 ];
            multiplied := map(array, (n) => n * 2);
            expect(t, array.count == multiplied.count, "map returned array of differing size: % != %", array.count, multiplied.count);

            for multiplied {
                expect(t, it == array[it_index] * 2, "expected % to equal %", it, multiplied[it_index]);
            }
        });

        test("map_iter", (t) => {
            str := "hello, world! 안녕하세요~";

            runes: [..]rune;
            map_iter(str, *runes, iter_runes, to_upper);
            expect(t, runes.count == 20);

            runes2 := filter(runes, (r) => r >= #char "A" && r <= #char "Z");
            expect(t, runes2.count == runes.count - 10);
        });

        test("Static_Array", (t) => {
            static: Static_Array(10, int);
            array_add(*static, 1, 2, 3, 4);

            doubled := map(to_array(static), (n) => n * 2);
            for doubled expect(t, it == static[it_index] * 2, "%th value didn't match: % vs. %", it, static[it_index]);

            even := filter(doubled, (n) => n % 2 == 0);
            expect(t, static.count == even.count, "array counts don't match % vs. %", static.count, even.count);
        });
    });
}
