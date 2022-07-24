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

to_array :: inline (args: ..$T) -> []T { return args; }

to_upper :: (r: rune) -> rune {
    if r >= #char "a" && r <= #char "z" ||
       r >= #char "A" && r <= #char "Z" {
           return to_upper(cast(u8)r);
   }

   return r;
}

to_string :: (r: rune) -> string {
    return character_utf32_to_utf8(r);
}

to_string :: (loc: Source_Code_Location) -> string {
    path := path_filename(loc.fully_pathed_filename);
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
    ending := ifx text.data[text.count - 1] == #char "s" then "'" else "s";
    return sprint("%0%", text, ending);
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


#scope_file

#if RUN_INTERNAL_TESTS #run {
    suite("Utilities", #code {
        test("pluralize", (t: *Test) {
            expect(t, pluralize("foo", 0)  == "foos");
            expect(t, pluralize("foo", 1)  == "foo");
            expect(t, pluralize("bars", 0) == "bars'");
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
    });
}
