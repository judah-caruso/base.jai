#module_parameters(
    RUN_INTERNAL_TESTS := false
);

/// Custom Types
rune :: #type u32;
f32  :: #type float32;
f64  :: #type float64;

#load "base64.jai";
#load "bit-set.jai";
#load "color-print.jai";
#load "compile-time.jai";
#load "fixed-update.jai";
#load "iterators.jai";
#load "lexer.jai";
#load "maybe.jai";
#load "static-array.jai";
#load "testing.jai";
#load "ticker.jai";
#load "union.jai";
#load "utilities.jai";

#import "String";
#import "Basic";
#import "Unicode";
#import "Compiler";
#import "Program_Print";
