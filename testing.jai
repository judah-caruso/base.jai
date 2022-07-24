/// A compile-time testing module.
/// Below is a standard usage guide:
/*
    Testing is comprised of:
        - Suites: groups of tests under a single name
        - Test: a name and a test procedure

    Suites are declared like so:

        #run suite("my test suite", #code {
            // ...
        });

    Note, this *must* be run at compile-time.

    Tests within a suite are declared like so:

        #run suite("my test suite", #code {
            test("some test", (t: *Test) {
                // ...
            });
        });

    This module provides (at this time) one procedure
    to check correctness: 'expect'.

    'expect' is almost a drop-in replacement for 'assert'.
    The only noticeable differences are that it requires a
    '*Test' to be passed as its first parameter, and it
    can only be called within a test procedure.

        #run suite("my test suite", #code {
            test("some test", (t: *Test) {
                expect(t, 1 == 1, "1 was not equal to 1?");
                expect(t, 2 % 2 == 0);
            });
        });

    For more examples, take a look at the tests defined
    in other modules.
*/

Test :: struct {
    name:  string;
    suite: *Suite;
}

suite :: ($name: string, tests: Code, loc := #caller_location) #expand {
    suite(name, true, true, tests, loc);
}

suite :: ($name: string, $enabled: bool, $verbose: bool, tests: Code, loc := #caller_location) #expand {
    #if !enabled return;

    set_build_options_dc(.{ do_output = false });

    suite: Suite;
    suite.name     = name;
    suite.location = loc;

    #insert_internal tests;

    print(".. Group ");
    print_color("% ", suite.name, color = FOREGROUND_INTENSITY);

    test_word := pluralize("test", suite.tests.count);
    print_color("(% %)\n", suite.tests.count, test_word, color = FOREGROUND_BLUE);

    longest_name := 0;
    for suite.tests if it.name.count > longest_name {
        longest_name = it.name.count;
    }

    start := current_time_monotonic();

    for * suite.tests {
        suite.current = it;

        test: Test;
        test.name  = it.name;
        test.suite = *suite;

        dots: string;
        {
            builder: String_Builder;
            for 0..(longest_name - test.name.count) + 2 append(*builder, ".");
            dots = builder_to_string(*builder);
        }

        print("    Test ");
        print_color("%0% ", test.name, dots, color = FOREGROUND_INTENSITY);

        begin := current_time_monotonic();
        it.proc(*test);
        end := current_time_monotonic();

        it.duration_in_sec = to_float64_seconds(end - begin);

        if it.status == {
            case .Pass;
                suite.passed += 1;
                print_color("pass ", color = FOREGROUND_GREEN);

                #if verbose {
                    print_color("(took %s)", it.duration_in_sec, color = FOREGROUND_BLUE);
                }

            case .Fail;
                suite.failed += 1;
                print_color("fail ", color = FOREGROUND_RED);
                print("at ");
                print_color("%", to_string(it.location), color = FOREGROUND_INTENSITY);

                #if verbose {
                    print("\n");

                    builder: String_Builder;
                    root := compiler_get_nodes(it.original_expr);

                    proc := New(Code_Procedure_Call);
                    proc.kind = .PROCEDURE_CALL;

                    ident := New(Code_Ident);
                    ident.kind = .IDENT;
                    ident.name = it.last_call;

                    proc.procedure_expression = ident;

                    args: [1]Code_Argument;
                    args[0].expression = root;
                    proc.arguments_unsorted = args;

                    print_expression(*builder, proc);

                    expr_str := replace(builder_to_string(*builder), "%", "%%");

                    if it.error_message.count {
                        print("\t % ", it.error_message);
                        print_color("in ", color = FOREGROUND_INTENSITY);
                    }
                    else {
                        print("\t Failed call was ");
                    }

                    print_color(expr_str, color = FOREGROUND_RED);
                    print("\n");
                }
                else {
                    if it.error_message.count {
                        print(": %", it.error_message);
                    }
                }
        }

        print("\n");
    }

    end := current_time_monotonic();

    print(".. Group ");
    print_color("% ", suite.name, color = FOREGROUND_INTENSITY);

    if suite.failed {
        print_color("failed ", color = FOREGROUND_RED);
        print("%/% % ", suite.failed, suite.tests.count, test_word);
    }
    else {
        print_color("passed ", color = FOREGROUND_GREEN);
    }

    #if verbose {
        print_color("(took %s)", to_float64_seconds(end - start), color = FOREGROUND_BLUE);
    }

    print("\n\n");
}

test :: (name: string, proc: Test_Context.Proc, loc := #caller_location) #expand {
    test := array_add(*`suite.tests);
    test.name     = name;
    test.location = loc;
    test.proc     = proc;
}

expect :: (test: *Test, expr: Code, format_string := "", args: ..Any, loc := #caller_location) #expand {
    if !within_test(test) return;

    ctx := test.suite.current;
    if ctx.has_already_failed return;

    expr_as_bool := cast(bool)#insert expr;
    if expr_as_bool {
        ctx.status = .Pass;
    }
    else {
        ctx.status             = .Fail;
        ctx.last_call          = "expect";
        ctx.original_expr      = expr;
        ctx.has_already_failed = true;

        if format_string.count {
            ctx.error_message = sprint(format_string, ..args);
        }
    }
}

#scope_file

Test_Context :: struct {
    name:      string;
    location:  Source_Code_Location;
    proc:      Test_Context.Proc;

    last_call:          string;
    error_message:      string;
    original_expr:      Code;
    duration_in_sec:    float64;
    has_already_failed: bool;

    status: Test_Context.Status;

    Status :: enum {
        Pass;
        Fail;
    }

    Proc :: #type (*Test);
}

Suite :: struct {
    name:     string;
    location: Source_Code_Location;

    passed:  int;
    failed:  int;
    tests:   [..]Test_Context;
    current: *Test_Context;
}

within_test :: (test: *Test, loc := #caller_location) -> bool #expand {
    if !test || !test.suite.current {
        compiler_report("'expect' was called outside of a test!", loc = loc);
        return false;
    }

    return test.suite.current.status != .Fail;
}
