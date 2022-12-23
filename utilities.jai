/// Helpful utilities

/// Custom types
byte :: #type u8;
rune :: #type u32;
sint :: #type s64;
uint :: #type u64;
f32  :: #type float32;
f64  :: #type float64;

/// C binding types
/// The names of these types are meant to mirror
/// how they're written in C. That way it cuts
/// down on the number of changes needed when
/// binding code. They've been placed in a
/// struct to namespace the types.
C :: struct {
   // @Todo: Should I even handle 32bit since it's not a compilation target?
   #if OS == .WINDOWS {
      char                   :: #type u8;
      short                  :: #type s16;
      int                    :: #type s32;
      long                   :: #type s32;
      float                  :: #type float32;
      double                 :: #type float64;
      short_int              :: #type s16;
      long_long              :: #type s64;
      long_long_int          :: #type s64;
      unsigned_char          :: #type u8;
      unsigned_short         :: #type u16;
      unsigned_short_int     :: #type u16;
      unsigned               :: #type u32;
      unsigned_int           :: #type u32;
      unsigned_long          :: #type u32;
      unsigned_long_long     :: #type u64;
      unsigned_long_long_int :: #type u64;
      signed_char            :: #type s8;
      signed_short           :: #type s16;
      signed_short_int       :: #type s16;
      signed                 :: #type s32;
      signed_int             :: #type s32;
      signed_long            :: #type s32;
      signed_long_long       :: #type s64;
      signed_long_long_int   :: #type s64;
      size_t                 :: #type u64;
      intptr_t               :: #type s64;
      uintptr_t              :: #type u64;
      ptrdiff_t              :: #type u64;
      wchar_t                :: #type u16;
      long_double            :: #type float64;
      WORD                   :: #type u16;
      DWORD                  :: #type u32;
   }
   else #if OS == .LINUX {
      char                   :: #type u8;
      short                  :: #type s16;
      int                    :: #type s32;
      long                   :: #type s64;
      float                  :: #type float32;
      double                 :: #type float64;
      short_int              :: #type s16;
      long_long              :: #type s64;
      long_long_int          :: #type s64;
      unsigned_char          :: #type u8;
      unsigned_short         :: #type u16;
      unsigned_short_int     :: #type u16;
      unsigned               :: #type u32;
      unsigned_int           :: #type u32;
      unsigned_long          :: #type u64;
      unsigned_long_long     :: #type u64;
      unsigned_long_long_int :: #type u64;
      signed_char            :: #type s8;
      signed_short           :: #type s16;
      signed_short_int       :: #type s16;
      signed                 :: #type s32;
      signed_int             :: #type s32;
      signed_long            :: #type s64;
      signed_long_long       :: #type s64;
      signed_long_long_int   :: #type s64;
      size_t                 :: #type u64;
      intptr_t               :: #type s64;
      uintptr_t              :: #type u64;
      ptrdiff_t              :: #type u64;
      wchar_t                :: #type u32;
      ssize_t                :: #type s64;
      long_double            :: #type float64;
   }
   else #if OS == .MACOS {
      char                   :: #type u8;
      short                  :: #type s16;
      int                    :: #type s32;
      long                   :: #type s64;
      float                  :: #type float32;
      double                 :: #type float64;
      short_int              :: #type s16;
      long_long              :: #type s64;
      long_long_int          :: #type s64;
      unsigned_char          :: #type u8;
      unsigned_short         :: #type u16;
      unsigned_short_int     :: #type u16;
      unsigned               :: #type u32;
      unsigned_int           :: #type u32;
      unsigned_long          :: #type u64;
      unsigned_long_long     :: #type u64;
      unsigned_long_long_int :: #type u64;
      signed_char            :: #type s8;
      signed_short           :: #type s16;
      signed_short_int       :: #type s16;
      signed                 :: #type s32;
      signed_int             :: #type s32;
      signed_long            :: #type s64;
      signed_long_long       :: #type s64;
      signed_long_long_int   :: #type s64;
      size_t                 :: #type u64;
      intptr_t               :: #type s64;
      uintptr_t              :: #type u64;
      ptrdiff_t              :: #type u64;
      wchar_t                :: #type u32;
   }
   else {
      #run compiler_report(sprint("Unknown platform '%'! This may not compile...", OS), mode = .WARNING);
   }
}


/// Various utilities

/// Better casting
// @Note(Judah): Because Jai's print_type_to_builder doesn't actually
// output the real type (just an approximation/verbose version), we
// can't rely on it to generate the cast expression (hence the ifs)
as :: ($T: Type, expr: Code, $check := true, $truncate := false) -> T #expand {
    // expr_str :: #run -> string {
    //     root := compiler_get_nodes(expr);
    //     builder: String_Builder;
    //     print_expression(*builder, root);
    //     return sprint("#insert expr /* as(%, %) */;", T, builder_to_string(*builder));
    // };

    #if !check {
        #if truncate then return cast,no_check,trunc(T)(#insert expr);
        else              return cast,no_check(T)(#insert expr);
    }
    else #if truncate {
        return cast,trunc(T)(#insert expr);
    }

    return cast(T)(#insert expr);
}

as_trunc :: ($T: Type, expr: Code) -> T #expand {
    return as(T, expr, truncate = true);
}

as_unsafe :: ($T: Type, expr: Code) -> T #expand {
    return as(T, expr, check = false);
}

transmute :: ($T: Type, expr: Code) -> T #expand {
    value := expr;
    return <<as(*T, *value);
}

/// Make a non-array type
// @Note(Judah): Not sure why making custom_init a partial bake works, bug?
make :: ($T: Type, $$custom_init: (*T) = null) -> T #modify {
    info := cast(*Type_Info)T;
    if info.type == .ARRAY {
        compiler_report(sprint("make_t is not valid on %", T));
        return false;
    }

    return true;
}{
    val: T = ---;

    ini :: initializer_of(T);
    #if ini inline ini(*val);
    else    memset(*val, 0, size_of(T));
    #if custom_init inline custom_init(*val);

    return val;
}

/// Make a slice type
make :: ($T: Type, $count := 0, allocator := context.allocator) -> []T #modify {
    info := cast(*Type_Info)T;
    if info.type != .ARRAY {
        compiler_report(sprint("make_slice expects % to be []T", T));
        return false;
    }

    arr := cast(*Type_Info_Array)info;
    if arr.array_type != .VIEW {
        compiler_report(sprint("make_slice expects % to be []T", T));
        return false;
    }

    T = get_type(arr.element_type);
    return true;
}{
    arr := NewArray(count, T, allocator = allocator);
    return arr;
}

/// Make a dynamic array type
make :: ($T: Type, $count := 0, allocator := context.allocator) -> T #modify {
    info := cast(*Type_Info)T;
    if info.type != .ARRAY {
        compiler_report(sprint("make_dynamic_array expects % to be [..]T", T));
        return false;
    }

    arr := cast(*Type_Info_Array)info;
    if arr.array_type != .RESIZABLE {
        compiler_report(sprint("make_dynamic_array expects % to be [..]T", T));
        return false;
    }

    return true;
} {
    dyn: T;
    dyn.allocator = allocator;
    #if count > 0 array_reserve(*dyn, count);
    return dyn;
}

new :: ($T: Type, allocator := context.allocator) -> *T {
    return inline New(T, allocator = allocator);
}

len :: (slice: []$T) -> int #expand { return slice.count; }
cap :: (slice: []$T) -> int #expand { return slice.count; }

len :: (dyn: [..]$T) -> int #expand { return dyn.count;     }
cap :: (dyn: [..]$T) -> int #expand { return dyn.allocated; }

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

// @Todo(Judah): We shouldn't need to call 'to_string' just to append a rune
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

#import "Basic";
#import "String";
#import "Unicode";
#import "Compiler";
