/// Compile-time utilities

/// Runs 'entrypoint' at compile-time without generating an executable.
ct_run_in_bytecode :: (entrypoint: $PROC) #expand
#modify {
    info := cast(*Type_Info)PROC;
    if info.type != .PROCEDURE return false;
    return true;
}
{
   set_build_options_dc(.{ do_output = false });
   entrypoint();
}

/// Compiles the file this is #run in.
ct_compile_to_binary :: (binary_name: string, use_bin_dir := true) #expand {
    options: Build_Options_During_Compile;
    options.do_output              = true;
    options.write_added_strings    = false;
    options.output_executable_name = binary_name;

    if use_bin_dir {
        path := get_working_directory();
        path = join(path, "bin", separator = PLATFORM_SEPARATOR);

        assert(make_directory_if_it_does_not_exist(path));

        options.output_path = path;
    }

    set_build_options_dc(options);
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
            return "---;";
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
            assert(false, "Type '%' does not have a one value", T);
    }

    return "";
}

/// Returns the type 'iterator' returns when called over 'T'
// ct_return_type_of_iterator :: (type: $T, $iterator: Iterator) -> Type {
//     temp :: #run ct_non_zero_value_of(T);
//     for :iterator temp return type_of(it);
//     return void;
// }


#scope_file

#import "File";
#import "Basic";
#import "Compiler";
