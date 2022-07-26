/// Runs 'main' (or another procedure) at compile-time without generating an executable.
ct_run_in_bytecode :: ($entrypoint := "main") #expand {
   #import "Compiler";
   set_build_options_dc(.{ do_output = false });
   #insert -> string { return sprint("%();", entrypoint); }
}

/// Runs 'entrypoint' at compile-time without generating an executable.
ct_run_in_bytecode :: (entrypoint: $PROC)
#expand
#modify {
    info := cast(*Type_Info)PROC;
    if info.type != .PROCEDURE return false;
    return true;
}
{
   #import "Compiler";
   set_build_options_dc(.{ do_output = false });
   entrypoint();
}

/// Returns the zero-value of 'T'
ct_zero_value_of :: ($type: $T) -> string {
    return ct_zero_value_of(type_info(type));
}

ct_zero_value_of :: (info: *Type_Info) -> string {
    if info.type == {
        case .ENUM; #through;
        case .INTEGER;
            return "0;";
        case .FLOAT;
            return "0.0;";
        case .BOOL;
            return "false;";
        case .STRING;
            return "\"\";";
        case .STRUCT;
            return ".{};";
        case .ARRAY;
            return ".[];";

        case .POINTER;   #through;
        case .PROCEDURE;
            return "null;";

        case;
            assert(false, "Type % does not have a zero value", info.type);
    }

    return "";
}

/// Returns a context-sensitive non-zero value of 'T'
ct_non_zero_value_of :: ($type: $T) -> string {
    info := type_info(type);
    if info.type == {
        case .INTEGER;
            return "1;";
        case .FLOAT;
            return "1.0;";
        case .BOOL;
            return "true;";
        case .STRING;
            return "\" \";";
        case .STRUCT;
            return ".{};";
        case .ARRAY;
            array_info := cast(*Type_Info_Array)info;
            str := ct_zero_value_of(array_info.element_type);
            str.count -= 1;
            return sprint(".[ % ];", str);
        case .ENUM;
            enum_info := cast(*Type_Info_Enum)info;
            if enum_info.values.count <= 1 {
                return "1;";
            }
            else {
                return sprint("%;", enum_info.values[1]);
            }

        case;
            assert(false, "Type % does not have a one value", T);
    }

    return "";
}

/// Returns the type 'iterator' returns when called over 'T'
ct_return_type_of_iterator :: (type: $T, $iterator: Iterator) -> Type {
    temp :: #run ct_non_zero_value_of(T);
    for :iterator temp return type_of(it);
    return void;
}


#scope_file

#if RUN_INTERNAL_TESTS #run {
    suite("Compile-time", #code {
        test("ct_run_in_bytecode", (t: *Test) {
            #run ct_run_in_bytecode(() {
                assert(running_at_compile_time());
            });

            my_proc :: () {
                assert(running_at_compile_time());
            }

            #run ct_run_in_bytecode(my_proc);
        });

        test("ct_zero_value_of", (t: *Test) {
            a: int;
            az :: #insert #run ct_zero_value_of(int);
            expect(t, a == az, "a was % and az was %", a, az);

            b: float32;
            bz :: #insert #run ct_zero_value_of(float32);
            expect(t, b == bz, "b was % and bz was %", b, bz);

            c: float64;
            cz :: #insert #run ct_zero_value_of(float64);
            expect(t, c == cz, "c was % and cz was %", c, cz);

            d: bool;
            dz :: #insert #run ct_zero_value_of(bool);
            expect(t, d == dz, "d was % and dz was %", d, dz);

            e: string;
            ez :: #insert #run ct_zero_value_of(string);
            expect(t, e == ez, "e was % and ez was %", e, ez);

            f: *void;
            fz :: #insert #run ct_zero_value_of(*void);
            expect(t, f == fz, "f was % and fz was %", f, fz);

            g: ();
            gz :: #insert #run ct_zero_value_of(type_of(g));
            expect(t, g == gz, "g was % and gz was %", g, gz);
        });
    });
}
