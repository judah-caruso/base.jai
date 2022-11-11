/// Various utilities

// @Note(Judah): Because Jai's print_type_to_builder doesn't actually
// output the real type (just an approximation/verbose version), we
// can't rely on it to generate the cast expression (hence the ifs)
/// Better casting
as :: ($T: Type, expr: Code, $check := true, $truncate := false) -> T #expand {
    expr_str :: #run -> string {
        root := compiler_get_nodes(expr);

        builder: String_Builder;
        print_expression(*builder, root);

        return sprint("#insert expr /* % */;", builder_to_string(*builder));
    };

    #if !check {
        #if truncate then return cast,no_check,trunc(T)(#insert expr_str);
        else              return cast,no_check(T)(#insert expr_str);
    }
    else #if truncate {
        return cast,trunc(T)(#insert expr_str);
    }

    return cast(T)(#insert expr_str);
}

as_trunc :: ($T: Type, expr: Code) -> T #expand {
    return as(T, expr, truncate = true);
}

as_unsafe :: ($T: Type, expr: Code) -> T #expand {
    return as(T, expr, check = false);
}

transmute :: ($T: Type, expr: Code, loc := #caller_location) -> T #expand {
    value := expr;
    return <<as(*T, *value);
}

kilobyte :: (i: $T) -> T #expand {
    return 1024 * i;
}

megabyte :: (i: $T) -> T #expand {
    return 1024 * kilobyte(i);
}

gigabyte :: (i: $T) -> T #expand {
    return 1024 * megabyte(i);
}

to_array :: inline (args: ..$T) -> []T { return args; }

to_upper :: (r: rune) -> rune {
    if r >= #char "a" && r <= #char "z" ||
       r >= #char "A" && r <= #char "Z" {
           return to_upper(cast(u8)r);
   }

   return r;
}

/// String_View is a bounds checked string slice
String_View :: struct {
    #as value: string;
    max_length: int;
}

begin_view :: (str: string) -> String_View {
    view: String_View;
    view.value       = str;
    view.value.count = 0;
    view.max_length  = str.count;
    return view;
}

advance_view :: inline (view: *String_View, by := 1) {
    assert(view.value.count + by < view.max_length, "Attempt to advance view past maximum length: %", view.max_length);
    view.value.count += by;
}

end_view :: inline (view: String_View) -> string {
    return view;
}

to_string :: end_view;

operator== :: inline (lhs: String_View, rhs: String_View) -> bool {
    return lhs.max_length == rhs.max_length && lhs.value == rhs.value;
}

operator== :: inline (lhs: String_View, rhs: string) -> bool {
    return lhs.value == rhs;
}

to_string :: inline (r: rune) -> string {
    return character_utf32_to_utf8(r);
}

to_string :: inline (builder: *String_Builder) -> string {
    return builder_to_string(builder);
}

to_string :: (loc: Source_Code_Location, $full_path := false) -> string {
    #if full_path {
        path := loc.fully_pathed_filename;
    }
    else {
        path := path_filename(loc.fully_pathed_filename);
    }

    return sprint("%:%,%", path, loc.line_number, loc.character_number);
}

to_c_string :: (str: string, allocator: Allocator) -> *u8 {
    c_str: *u8 = alloc(str.count + 1, allocator);
    memcpy(c_str, str.data, str.count);
    c_str[str.count] = 0;
    return c_str;
}

join :: (values: ..rune, separator := "", $before_first := false, $after_last := false) -> string {
    builder: String_Builder;

    #if before_first append(*builder, separator);

    for values {
        append(*builder, to_string(it));
        if it_index append(*builder, separator);
    }

    #if after_last append(*builder, separator);

    return builder_to_string(*builder);
}

pluralize :: (text: string, number: int) -> string {
    if number == 1 return text;
    ending := ifx text.data[text.count - 1] == #char "s" then "" else "s";
    return sprint("%0%", text, ending);
}

contains :: (array: []$T, value: T) -> bool {
    for array if it == value return true;
    return false;
}

/// Allows a specific block of code to be called with a C context.
c_call :: (block: Code) #expand {
    ctx: Context;
    push_context ctx {
        #insert block;
    }
}

/// Equivalent of a 'do {} while(0)' that allows
/// early exiting via 'break' instead of 'return'.
verify :: (block: Code) #expand {
    for 0..0 #insert block;
}

get_name_of_current_procedure :: () -> string {
    if !context.stack_trace || !context.stack_trace.info return "";
    return context.stack_trace.info.name;
}

/// It might seem like these should be in 'lexer.jai',
/// however, that uses its own consume/peek procs, and
/// I don't want that module to be a requirement if you
/// just want basic consume/peek functionality.

/// Unicode character peeking/consuming
// @Todo: Don't rely on character_utf8_to_utf32.
peek_rune :: (src: string) -> rune, bool, int {
    if !src.count return 0, false, 0;

    rune, width, status := character_utf8_to_utf32(src.data, src.count);
    if status != .CONVERSION_OK return 0, false, 0;

    return rune, true, width;
}

consume_rune :: (src: *string) -> rune, bool, int {
    if !src || !src.count return 0, false, 0;

    rune, width, status := character_utf8_to_utf32(src.data, src.count);
    if status != .CONVERSION_OK return 0, false, 0;

    src.data  += width;
    src.count -= width;

    return rune, true, width;
}

rune_width :: (r: rune) -> int {
    if r < 0 return -1;

    if r <= 0x7F  return 1;
    if r <= 0x7FF return 2;

    if r >= 0xD800 &&
       r <= 0xDFFF return -1;

    if r <= 0xFFFF   return 3;
    if r <= 0x10FFFF return 4;

    return -1;
}

// @Todo: Remove the 'to_string' call when we update 'consume/peek_rune'
append :: inline (builder: *String_Builder, r: rune) {
    append(builder, to_string(r));
}


/// ASCII character peeking/consuming
peek_char :: (src: string) -> u8, bool {
    if !src.count return 0, false;
    return src.data[0], true;
}

consume_char :: (src: *string) -> u8, bool {
    if !src || !src.count return 0, false;

    chr := src.data[0];
    src.count -= 1;
    src.data  += 1;

    return chr, true;
}


/// Array peeking
peek_array :: (src: []$T) -> T, bool {
    _: T = ---;
    if !src.count return _, false;
    return src.data[0], true;
}

consume_array :: (src: *[]$T) -> T, bool {
    _: T = ---;
    if !src || !src.count return _, false;

    value := src.data[0];
    src.count -= 1;
    src.data  += 1;

    return value, true;
}


#scope_file

#if RUN_INTERNAL_TESTS #run {
    suite("Utilities", #code {
        test("pluralize", (t: *Test) {
            expect(t, pluralize("foo", 0)  == "foos");
            expect(t, pluralize("foo", 1)  == "foo");
            expect(t, pluralize("bars", 0) == "bars");
            expect(t, pluralize("bars", 1) == "bars");
        });

        test("name of procedure", (t: *Test) {
            foo :: () -> string { return get_name_of_current_procedure(); }
            bar_baz :: () -> string { return get_name_of_current_procedure(); }

            expect(t, foo() == "foo");
            expect(t, bar_baz() == "bar_baz");

            no_name := get_name_of_current_procedure();
            expect(t, no_name == "proc", "unnamed procedure had name '%'", no_name);
        });

        test("verify block", (t: *Test) {
            #import "Random";

            random_seed(cast(u64)to_nanoseconds(current_time_monotonic()));

            for 0..100 {
                value    := cast(int)random_get_within_range(0, 100);
                is_valid := false;

                verify(#code {
                    if value >= 50    break;
                    if value % 2 != 0 break;
                    is_valid = true;
                });

                if is_valid {
                    expect(t, value % 2 == 0, "valid value wasn't in range: %", value);
                }
                else {
                    expect(t, value >= 50 || value % 2 != 0, "invalid value was in valid range: %", value);
                }
            }
        });

        test("unicode peek/consume", (t: *Test) {
            str := "\n\r안녕하세요\n이것은 시험이다~\n";
            copy := str;

            i := 0;
            while copy.count {
                original, width, status := character_utf8_to_utf32(str.data, str.count);
                expect(t, status == .CONVERSION_OK);

                r, ok := peek_rune(copy);
                expect(t, ok, "rune peek (at %) returned nothing!", i);

                expect(t, r == original, "peeked '%' (at index %) was expected to be '%'", r, i, original);

                r, ok = consume_rune(*copy);
                expect(t, ok, "unable to consume value %!", i);

                expect(t, r == original, "consumed '%' (at index %) was expected to be '%'", r, i, original);

                i += 1;
                str.data  += width;
                str.count -= width;
            }
        });

        test("ascii peek/consume", (t: *Test) {
            str := "\n\rHello, World!\nThis is a test\n";
            copy := str;

            i := 0;
            while copy.count {
                chr, ok := peek_char(copy);
                expect(t, ok, "character peek (at %) returned nothing!", i);

                expect(t, chr == str.data[i], "peeked '%' (at index %) was expected to be '%'", chr, i, str.data[i]);

                chr, ok = consume_char(*copy);
                expect(t, ok, "unable to consume value %!", i);

                expect(t, chr == str.data[i], "consumed '%' (at index %) was expected to be '%'", chr, i, str.data[i]);
                i += 1;
            }
        });

        test("array peek/consume", (t: *Test) {
            str_values := string.[ "1", "2", "3", "4", "5" ];
            str_copies : []string = str_values;

            i := 0;
            while str_copies.count {
                str, ok := peek_array(str_copies);
                expect(t, ok, "peek on array (at %) returned nothing!", i);

                expect(t, str == str_values[i], "peeked '%' (at index %) was expected to be '%'", str, i, str_values[i]);

                str, ok = consume_array(*str_copies);
                expect(t, ok, "unable to consume value %!", i);

                expect(t, str == str_values[i], "consumed '%' (at index %) was expected to be '%'", str, i, str_values[i]);

                i += 1;
            }

            Foo :: struct {
                value: int;
            }

            custom_values: [..]Foo;
            array_add(*custom_values, .{ 1 });
            array_add(*custom_values, .{ 2 });
            array_add(*custom_values, .{ 3 });
            array_add(*custom_values, .{ 4 });
            array_add(*custom_values, .{ 5 });

            custom_copies: []Foo = custom_values;

            i = 0;
            while i < custom_copies.count {
                foo, ok := peek_array(custom_copies);
                expect(t, ok, "peek on array (at %) returned nothing!", i);

                expect(t, foo.value == custom_values[i].value, "peeked '%' (at index %) was expected to be '%'", foo.value, i, custom_values[i].value);

                foo, ok = consume_array(*custom_copies);
                expect(t, ok, "unable to consume value %!", i);

                expect(t, foo.value == custom_values[i].value, "consumed '%' (at index %) was expected to be '%'", foo.value, i, custom_values[i].value);

                i += 1;
            }
        });

        test("string view", (t: *Test) {
            str := "안녕하세요\n이것은 시험이다~\n";
            copy := str;

            view_a := begin_view(copy);
            while copy.count {
                chr, ok, width := peek_rune(copy);
                if !ok || chr == #char "\n" break;

                advance_view(*view_a, width);
                consume_rune(*copy);
            }

            output_a := end_view(view_a);
            expect(t, view_a   == "안녕하세요"); // Verify operator overload works as expected
            expect(t, output_a == "안녕하세요");

            consume_rune(*copy); // Skip '\n'

            view_b := begin_view(copy);
            while copy.count {
                chr, ok, width := peek_rune(copy);
                if !ok || chr == #char " " break;

                advance_view(*view_b, width);
                consume_rune(*copy);
            }

            output_b := end_view(view_b);
            expect(t, view_b   == "이것은");
            expect(t, output_b == "이것은");

            expect(t, view_a   != view_b);
            expect(t, output_a != output_b);
        });

        test("rune width", (t: *Test) {
            tests := (struct { value: rune; expected: int; }).[
                .{ 0, 1 },
                .{ #char "a", 1 },
                .{ #char "é", 2 },
                .{ #char "ㅋ", 3 },
                .{ 0x10FFFF, 4 },
                .{ 0xD800, -1 },
                .{ 0xDFFF, -1 },
                .{ 0x10FFFF + 1, -1 },
            ];

            for tests {
                width := rune_width(it.value);
                expect(t, width == it.expected,
                    "rune '%' should have a width of %, instead was %",
                    to_string(it.value),
                    it.expected,
                    width,
                );
            }
        });

        test("rune append", (t: *Test) {
            str := "안녕하세요 :)";

            builder: String_Builder;

            copy := str;
            while copy.count {
                r, ok := consume_rune(*copy);
                if !ok break;
                append(*builder, r);
            }

            out := to_string(*builder);
            expect(t, out == str, "expected '%' to equal '%'", out, str);
        });
    });
}
