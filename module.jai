#module_parameters(
    RUN_INTERNAL_TESTS := false
);

/// Custom Types
rune :: #type u32;

#load "union.jai";
#load "testing.jai";
#load "iterators.jai";
#load "utilities.jai";
#load "compile-time.jai";
#load "static-array.jai";

#import "String";
#import "Basic";
#import "Unicode";
#import "Compiler";
#import "Program_Print";
#import "Print_Color";
