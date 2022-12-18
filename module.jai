#module_parameters(
   RUN_INTERNAL_TESTS := false
);

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
c :: struct {
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

#load "allocators.jai";
#load "array.jai";
#load "base64.jai";
#load "bitset.jai";
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
