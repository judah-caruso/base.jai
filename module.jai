#module_parameters(
    RUN_INTERNAL_TESTS := false
);

/// Custom Types
rune :: #type u32;
f32  :: #type float32;
f64  :: #type float64;

#load "lexer.jai";
#load "union.jai";
#load "maybe.jai";
#load "base64.jai";
#load "ticker.jai";
#load "testing.jai";
#load "iterators.jai";
#load "utilities.jai";
#load "compile-time.jai";
#load "static-array.jai";
#load "fixed-update.jai";

#import "String";
#import "Basic";
#import "Unicode";
#import "Compiler";
#import "Program_Print";
#import "Print_Color";
