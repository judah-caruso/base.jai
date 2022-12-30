#run {
   suite("Allocators", #code {
      test("crash allocator", (t) => {
         ref := make_crash_allocator();

         old := context.allocator;
         context.allocator = make_crash_allocator();
         expect(t, context.allocator.proc == ref.proc);
         expect(t, context.allocator.data == null);

         context.allocator = old;
      });
   });

   suite("Array", #code {
      test("append/append_unique", (t) => {
         foo: [..]s64;
         append(*foo, 10, 20, 30);
         expect(t, len(foo) == 3);

         x := append(*foo);
         <<x = 50;

         expect(t, len(foo) == 4);
         expect(t, foo[len(foo) - 1] == <<x);

         append_unique(*foo, 10);
         expect(t, len(foo) == 4);
      });

      test("insert", (t) => {
         foo: [..]s64;
         insert(*foo, 0, 100);
         insert(*foo, 0, 200);
         insert(*foo, 1, 300);

         expect(t, len(foo) == 3);
         expect(t, foo[0] == 200);
         expect(t, foo[1] == 300);
         expect(t, foo[2] == 100);
      });

      test("remove_by_index", (t) => {
         foo: [..]s64;
         append(*foo, 1, 2, 3, 4);
         items := len(foo);

         remove_by_index(*foo, 1);
         expect(t, len(foo) == items - 1);

         expect(t, foo[0] == 1);
         expect(t, foo[1] == 3);
         expect(t, foo[2] == 4);
      });

      test("remove_by_value", (t) => {
         foo: [..]s64;
         append(*foo, 1, 2, 3, 4, 5, 5, 6);

         has :: (a: [..]$T, v: T) -> bool {
            for a if it == v return true;
            return false;
         }

         remove_by_value(*foo, 5);
         expect(t, has(foo, 5));

         remove_by_value(*foo, 5);
         expect(t, !has(foo, 5));
      });

      test("remove_by_pointer", (t) => {
         foo: [..]s64;
         append(*foo, 1, 1, 1, 1);

         x := insert(*foo, 2);
         <<x = 500;

         expect(t, len(foo) == 5);
         expect(t, foo[2] == 500);

         remove_by_pointer(*foo, x, .Unordered);
         expect(t, len(foo) == 4);

         sum := 0;
         for foo sum += it;

         expect(t, sum == len(foo), "sum was %, len was %", sum, len(foo));
      });
   });

   suite("Base64", #code {
      test("encodes", (t) => {
         str :: "Hello, World";

         encoded, ok := base64_encode(str);
         expect(t, ok, "'%' did not properly encode!", str);

         encoded_str  := to_string(encoded);
         expected_str :: "SGVsbG8sIFdvcmxk";

         expect(t, encoded_str == expected_str, "Invalid result from encode! Wanted: '%', received: '%'", expected_str, encoded_str);
      });

      test("decodes", (t) => {
         encoded_str :: "SGVsbG8sIFdvcmxk";

         decoded_str, ok := base64_decode(encoded_str);
         expect(t, ok, "'%' did not properly decode!", encoded_str);

         expected_str :: "Hello, World";
         expect(t, decoded_str == expected_str, "Invalid result from decode! Wanted: '%', received: '%'", expected_str, decoded_str);
      });

      test("encode/decode with padding", (t) => {
         first_decode, f_ok := base64_decode("VkdocGN5QnBjeUJ6YjIxbGRHaHBibWNnYlc5eVpTQmpiMjF3YkdWNExDQnBkQ0J6YUc5MWJHUWdhR0YyWlNCd1lXUmthVzVuUHc9PQ==");
         expect(t, f_ok, "First decode failed!");

         re_encode, r_ok := base64_encode(first_decode, with_padding = true);
         expect(t, r_ok, "Re-encode failed!");

         second_decode, s_ok := base64_decode(re_encode);
         expect(t, s_ok, "Second decode failed!");

         for 0..first_decode.count - 1 {
            expect(t, first_decode[it] == second_decode[it], "Decoded byte '%' did not match expected output", it);
         }
      });

      test("encode/decode basic structure", (t) => {
         Foo :: struct {
            first:  u64;
            second: u64;
            third:  u64;
            forth:  u64;
         }

         foo: Foo;
         foo.first  = 123;
         foo.second = 456;
         foo.third  = 789;
         foo.forth  = 100;

         enc_builder: String_Builder;
         print_to_builder(*enc_builder, "%,%,%,%", foo.first, foo.second, foo.third, foo.forth);

         encoded, e_ok := base64_encode(to_string(*enc_builder));
         expect(t, e_ok, "Encode of structure failed!");

         decoded, d_ok := base64_decode(encoded);
         expect(t, d_ok, "Decode of encoded structure failed!");

         parts := split(to_string(decoded), ",");
         expect(t, parts.count == 4, "Invalid number of parts after decode: %", parts.count);

         bar: Foo = ---;

         {
            ptr  := cast(*u8)*bar;
            info := <<cast(*Type_Info_Struct)type_info(Foo);

            for info.members {
               value, ok := parse_int(*parts[it_index], u64);
               expect(t, ok, "Integer parse of value % ('%') failed!", it_index, parts[it_index]);

               offset := cast(*u64)(ptr + it.offset_in_bytes);
               <<offset = value;
            }
         }

         expect(t, foo.first  == bar.first,  "Foo.first (%, %) didn't match between encoding/decoding!", foo.first, bar.first);
         expect(t, foo.second == bar.second, "Foo.second (%, %) didn't match between encoding/decoding!", foo.second, bar.second);
         expect(t, foo.third  == bar.third,  "Foo.third (%, %) didn't match between encoding/decoding!", foo.third, bar.third);
         expect(t, foo.forth  == bar.forth,  "Foo.forth (%, %) didn't match between encoding/decoding!", foo.forth, bar.forth);
      });
   });

   suite("Bit_Set", #code {
      Foo_Set :: Bit_Set(Foo);

      Foo :: enum_flags {
         A;
         B;
         C;
      }

      test("operators", (t: *Test) {
         foo: Foo_Set;
         foo += .A;
         foo += .B;

         expect(t, foo[.A]);
         expect(t, foo[.B]);

         foo -= .B;
         expect(t,  foo[.A]);
         expect(t, !foo[.B]);

         foo -= .A;
         foo += Foo.B;
         foo[.C] = true;

         expect(t, !foo[.A]);
         expect(t,  foo[.B]);
         expect(t,  foo[.C]);

         set := foo[.A] != foo[.B];

         foo[.A] = set;
         expect(t, foo[.A]);
         foo[.A] = !set;

         expect(t, foo == Foo.B | .C);
      });
   });

   suite("Compile-time", #code {
       test("ct_zero_value_of", (t) => {
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

       test("ct_non_zero_value_of", (t) => {
           a: int;
           an :: #insert #run ct_non_zero_value_of(int);
           expect(t, a != an, "a was % and an was %", a, an);

           b: float32;
           bn :: #insert #run ct_non_zero_value_of(float32);
           expect(t, b != bn, "b was % and bn was %", b, bn);

           c: float64;
           cn :: #insert #run ct_non_zero_value_of(float64);
           expect(t, c != cn, "c was % and cn was %", c, cn);

           d: bool;
           dn :: #insert #run ct_non_zero_value_of(bool);
           expect(t, d != dn, "d was % and dn was %", d, dn);

           e: string;
           en :: #insert #run ct_non_zero_value_of(string);
           expect(t, e != en, "e was % and en was %", e, en);
       });
   });

   suite("Fixed Update", #code {
      test("compiles", (t) => {
         fu: Fixed_Update;
         init(*fu);
         do_fixed_update(*fu, #code {});
      });
   });

   suite("Iterators", #code {
       test("filter", (t) => {
           numbers  := int.[ 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 ];
           filtered := filter(numbers, (num) => num % 2 == 0);
           expect(t, filtered.count == 7, "found too many numbers: % (%)", filtered, filtered.count);
       });

       test("collect", (t) => {
           str := "x안녕하세요x";

           runes: [..]rune;
           collect(str, *runes, iter_runes);
           expect(t, runes.count == 7, "runes had a count of %", runes.count);

           ascii := map(runes, (r) => r >= #char "a" && r <= #char "z");
           expect(t, ascii.count == 7);

           only_valid := filter(ascii, (r) => r);
           expect(t, only_valid.count == 2);
       });

       test("map", (t) => {
           array := int.[ 0, 1, 2, 3, 4, 5 ];
           multiplied := map(array, (n) => n * 2);
           expect(t, array.count == multiplied.count, "map returned array of differing size: % != %", array.count, multiplied.count);

           for multiplied {
               expect(t, it == array[it_index] * 2, "expected % to equal %", it, multiplied[it_index]);
           }
       });

       test("map_iter", (t) => {
           str := "hello, world! 안녕하세요~";

           runes: [..]rune;
           map_iter(str, *runes, iter_runes, to_upper);
           expect(t, runes.count == 20);

           runes2 := filter(runes, (r) => r >= #char "A" && r <= #char "Z");
           expect(t, runes2.count == runes.count - 10);
       });

       test("Static_Array", (t) => {
           static: Static_Array(10, int);
           array_add(*static, 1, 2, 3, 4);

           doubled := map(to_array(static), (n) => n * 2);
           for doubled expect(t, it == static[it_index] * 2, "%th value didn't match: % vs. %", it, static[it_index]);

           even := filter(doubled, (n) => n % 2 == 0);
           expect(t, static.count == even.count, "array counts don't match % vs. %", static.count, even.count);
       });
   });

   suite("Lexer", #code {
       test("empty", (t) => {
           lexer: Lexer;
           lexer.source = ". int { foo }";

           ok := lex(*lexer);
           expect(t, !ok, "empty lexer had no handlers and should've failed");
           expect(t, lexer.errors.count, "empty lexer failed but had no errors");
           expect(t, !lexer.tokens.count, "empty lexer should not produce tokens");
       });

       test("unicode", (t) => {
           lexer: Lexer;
           lexer.source = "hello, world 123 3.14";

           is_letter :: (r: rune) -> bool {
               return r >= #char "a" && r <= #char "z" ||
                      r >= #char "A" && r <= #char "Z";
           }

           is_number :: (r: rune) -> bool {
               return r >= #char "0" && r <= #char "9";
           }

           register_handler(*lexer, is_letter, (lexer: *$L) -> bool {
               identifier := capture_while(lexer, (chr) =>
                   is_letter(chr) ||
                   is_number(chr) ||
                   chr == #char "_"
               );

               if identifier.count <= 0 {
                   return false;
               }

               token := array_add(*lexer.tokens);
               token.kind    = .Identifier;
               token._string = identifier;
               return true;
           });

           register_handler(*lexer, is_number, (lexer: *$L) -> bool {
               number := capture_while(lexer, (chr) =>
                   is_number(chr)   ||
                   chr == #char "." ||
                   chr == #char "_"
               );

               if number.count <= 0 {
                   return false;
               }

               is_float := false;
               for :iter_runes number if it == #char "." {
                   is_float = true;
               }

               token := array_add(*lexer.tokens);
               if is_float {
                   token.kind = .Float;

                   _float, ok := parse_float(*number);
                   if !ok return false;

                   token._float = _float;
               }
               else {
                   token.kind = .Integer;

                   _int, ok := parse_int(*number);
                   if !ok return false;

                   token._int = _int;
               }

               return true;
           });

           register_handler(*lexer, (chr) => !is_whitespace(chr), (lexer: *$L) -> bool {
               token := array_add(*lexer.tokens);
               token.kind  = .Rune;
               token._rune = next_rune(lexer);
               return true;
           });

           expect(t, lex(*lexer), "lexing failed with these errors: %", lexer.errors);
           expect(t, lexer.tokens.count == 5, "lexing produced too many tokens: %", lexer.tokens.count);

           expect(t, lexer.tokens[0].kind    == .Identifier, "expected 0th token to be an Identifier, instead was %", lexer.tokens[0].kind);
           expect(t, lexer.tokens[0]._string == "hello", "expected 0th token to equal 'hello', instead was '%'", lexer.tokens[0]._string);

           expect(t, lexer.tokens[1].kind  == .Rune, "expected 1st token to be a Rune, instead was %", lexer.tokens[1].kind);
           expect(t, lexer.tokens[1]._rune == #char ",", "expected 1st token to equal ',', instead was '%'", to_string(lexer.tokens[1]._rune));

           expect(t, lexer.tokens[2].kind    == .Identifier, "expected 2nd token to be an Identifier, instead was %", lexer.tokens[2].kind);
           expect(t, lexer.tokens[2]._string == "world", "expected 2nd token to equal 'world', instead was '%'", lexer.tokens[2]._string);

           expect(t, lexer.tokens[3].kind == .Integer, "expected 3rd token to be an Integer, instead was %", lexer.tokens[3].kind);
           expect(t, lexer.tokens[3]._int == 123, "expected 3rd token to equal 123, instead was '%'", lexer.tokens[3]._int);

           expect(t, lexer.tokens[4].kind   == .Float, "expected 4th token to be a Float, instead was %", lexer.tokens[4].kind);
           expect(t, lexer.tokens[4]._float - 3.14 <= 0.1, "expected 4th token to approximately equal 3.14, instead was '%'", lexer.tokens[4]._float);
       });

       test("ascii", (t) => {
           is_letter :: (chr: u8) -> bool {
               return chr >= #char "a" && chr <= #char "z" ||
                      chr >= #char "A" && chr <= #char "Z";
           }

           is_number :: (chr: u8) -> bool {
               return chr >= #char "0" && chr <= #char "9";
           }

           Kind :: enum {
               None;
               Character;
               Identifier;
               Float;
               Integer;
           }

           Value :: union {
               _char:   u8;
               _string: string;
               _float:  float64;
               _int:    s64;
           }

           lexer: Lexer(TOKEN_VALUE = Value, TOKEN_KIND = Kind, UNICODE = false);
           lexer.source = "hello, world 123 3.14";

           register_handler(*lexer, is_letter, (lexer: *$L) -> bool {
               identifier := capture_while(lexer, (chr) =>
                   is_letter(chr) ||
                   is_number(chr) ||
                   chr == #char "_"
               );

               if identifier.count <= 0 {
                   return false;
               }

               token := array_add(*lexer.tokens);
               token.kind    = .Identifier;
               token._string = identifier;
               return true;
           });

           register_handler(*lexer, is_number, (lexer: *$L) -> bool {
               number := capture_while(lexer, (chr) =>
                   is_number(chr)   ||
                   chr == #char "." ||
                   chr == #char "_"
               );

               if number.count <= 0 {
                   return false;
               }

               is_float := false;
               for :iter_ascii number if it == #char "." {
                   is_float = true;
               }

               token := array_add(*lexer.tokens);
               if is_float {
                   token.kind = .Float;

                   _float, ok := parse_float(*number);
                   if !ok return false;

                   token._float = _float;
               }
               else {
                   token.kind = .Integer;

                   _int, ok := parse_int(*number);
                   if !ok return false;

                   token._int = _int;
               }

               return true;
           });

           register_handler(*lexer, (chr) => !is_whitespace(chr), (lexer: *$L) -> bool {
               token := array_add(*lexer.tokens);
               token.kind  = .Character;
               token._char = next_char(lexer);
               return true;
           });

           expect(t, lex(*lexer), "lexing failed with these errors: %", lexer.errors);
           expect(t, lexer.tokens.count == 5, "lexing produced too many tokens: %", lexer.tokens.count);

           expect(t, lexer.tokens[0].kind    == .Identifier, "expected 0th token to be an Identifier, instead was %", lexer.tokens[0].kind);
           expect(t, lexer.tokens[0]._string == "hello", "expected 0th token to equal 'hello', instead was '%'", lexer.tokens[0]._string);

           expect(t, lexer.tokens[1].kind  == .Character, "expected 1st token to be a Character, instead was %", lexer.tokens[1].kind);
           expect(t, lexer.tokens[1]._char == #char ",", "expected 1st token to equal ',', instead was '%'", to_string(lexer.tokens[1]._char));

           expect(t, lexer.tokens[2].kind    == .Identifier, "expected 2nd token to be an Identifier, instead was %", lexer.tokens[2].kind);
           expect(t, lexer.tokens[2]._string == "world", "expected 2nd token to equal 'world', instead was '%'", lexer.tokens[2]._string);

           expect(t, lexer.tokens[3].kind == .Integer, "expected 3rd token to be an Integer, instead was %", lexer.tokens[3].kind);
           expect(t, lexer.tokens[3]._int == 123, "expected 3rd token to equal 123, instead was '%'", lexer.tokens[3]._int);

           expect(t, lexer.tokens[4].kind   == .Float, "expected 4th token to be a Float, instead was %", lexer.tokens[4].kind);
           expect(t, lexer.tokens[4]._float - 3.14 <= 0.1, "expected 4th token to approximately equal 3.14, instead was '%'", lexer.tokens[4]._float);
       });
   });

   suite("Maybe", #code {
       test("some/none", (t) => {
           a: Maybe(int);
           a = some(10);

           expect(t, is_some(a), "expected 'a' to have a value!");
           expect(t, !is_none(a), "expected 'a' to have a value!");

           v := unwrap(*a);
           expect(t, v == 10, "expected 'v' to equal 10, instead equaled '%'", v);
       });

       test("returns maybe", (t) => {
           double_if_even :: (x: $T) -> Maybe(T) {
               if x % 2 == 0 {
                   return some(x * x);
               }

               return none(T);
           }

           expect(t, double_if_even(2) == .Some);
           expect(t, double_if_even(3) == .None);
       });

       test("sentinel value", (t) => {
           Valid_Index :: Maybe(int, -1);

           valid_index   :: (value: Valid_Index.T) -> Valid_Index #expand { return some(value, Valid_Index.SENTINEL); }
           invalid_index :: () -> Valid_Index #expand { return none(Valid_Index.T, Valid_Index.SENTINEL); }

           returns_index :: (ok: bool) -> Valid_Index {
               if !ok return invalid_index();
               return valid_index(1);
           }

           a := returns_index(true);
           b := returns_index(false);
           expect(t, a == .Some, "expected 'a' to have a value");
           expect(t, b == .None, "expected 'b' to not have a value");
       });
   });

   suite("Static Array", #code {
       test("dynamic api to static", (t) => {
           dynamic: [..]int;
           static:  Static_Array(10, int);

           for 0..static.CAPACITY - 1 {
               array_add(*dynamic, 10);
               array_add(*static, 10);

               expect(t, dynamic.count == static.count, "arrays had mismatched count: % vs. %", dynamic.count, static.count);
               expect(t, dynamic[it] == static[it], "%th elements didn't match (dyn: %, static: %)", it, dynamic[it], static[it]);
           }

           array_reset(*dynamic);
           array_reset(*static);
           expect(t, dynamic.count == static.count, "arrays had unmatched counts after reset: % vs. %", dynamic.count, static.count);
           for static expect(t, it == static.ZERO, "%th element wasn't zeroed out: %", it_index, it);
       });

       test("array_to_dynamic", (t) => {
           static: Static_Array(3, float64);
           for 0..static.CAPACITY - 1 {
               array_add(*static, 3.14 + it);
           }

           dynamic := array_to_dynamic(*static);
           for dynamic expect(t, it == static[it_index], "%th element was unmatched after dynamic conversion: % != %", it_index, it, static[it_index]);

           array_add(*dynamic, 3.14 * 2);
           expect(t, static.count != dynamic.count, "arrays had matching count after append: % vs. %", static.count, dynamic.count);
       });

       test("push/pop", (t) => {
           Command :: struct {
               tag:  Tag;
               args: [..]Argument;

               Tag :: enum {
                   Move;
                   Push;
                   Add;
                   Sub;
               }

               Argument :: Union(struct {
                   Register: u8;
                   Literal:  float32;
               });
           }

           static: Static_Array(16, Command);

           {
               cmd := push(*static);
               cmd.tag = .Move;

               loc := array_add(*cmd.args);
               set(loc, .Register, cast(u8)1);

               val := array_add(*cmd.args);
               set(val, .Literal, 100.0);
           }

           {
               cmd := push(*static);
               cmd.tag = .Add;

               loc := array_add(*cmd.args);
               set(loc, .Register, cast(u8)1);

               val := array_add(*cmd.args);
               set(val, .Literal, 1.0);
           }

           while static.count {
               cmd := pop(*static);
               // ...
           }

           expect(t, static.count == 0, "array still had count after pop: %", static.count);
       });

       test("operators", (t) => {
           arr: Static_Array(100, int);
           for arr arr[it_index] = it_index * it_index;
           for arr expect(t, arr[it_index] == it_index * it_index);
       });

       test("len/cap", (t) => {
           arr: Static_Array(5, int);
           expect(t, len(arr) == 0);
           expect(t, cap(arr) == 5);
       });
   });

   suite("Ticker", #code {
      test("updates", (t) => {
         ticker: Event_Handler;

         value := 0;
         test_event := register_event(*ticker, 1, (tick: Tick, data: *void) -> bool {
            v := cast(*int)data;
            <<v += 1;
            return false;
         }, *value);

         do_event_tick(*ticker);
         do_event_tick(*ticker);

         expect(t, value == 2, "Expected 'v' to equal '2' at 1t. Instead was '%'", value);

         set_tickrate(test_event, 2);
         expect(t, test_event.tick_rate == 2, "Expected tick_rate to be 2 after 'set_tickrate'. Instead was '%'", test_event.tick_rate);
         expect(t, !test_event.last_tick && !test_event.cleaned, "test_event had invalid data after 'set_tickrate'");

         ticker.tick = 0; // Needs to reset for testing purposes

         do_event_tick(*ticker);
         do_event_tick(*ticker);

         expect(t, value == 3, "Expected 'v' to equal '3' at 2t. Instead was '%'", value);

         ticker.tick = 0;
         set_tickrate(test_event, 10);

         for 1..20 {
            do_event_tick(*ticker);
         }

         expect(t, value == 5, "Expected 'v' to equal '5' after 20 ticks at 10t. Instead was '%'", value);
      });

      test("resets", (t) => {
         Foo :: struct {
            is_dead: bool;
         }

         ticker: Event_Handler;
         thing_to_be_cleaned: Foo;

         dead_tick :: (tick, data) => true;
         test_event := register_event(*ticker, 1, dead_tick, *thing_to_be_cleaned, (tick: Tick, data: *void) {
            foo := cast(*Foo)data;
            foo.is_dead = true;
         });

         do_event_tick(*ticker);

         expect(t, test_event.cleaned, "test_event wasn't cleaned after first tick!");
         expect(t, thing_to_be_cleaned.is_dead, "expected 'is_dead' to be true after clean!");

         ticker.tick = 0;

         new_thing: Foo;
         reset_event(test_event, *new_thing);

         set_tickrate(test_event, 2);

         do_event_tick(*ticker);

         expect(t, !new_thing.is_dead, "'is_dead' shouldn't be true until 2 ticks have passed!");

         do_event_tick(*ticker);

         expect(t, new_thing.is_dead, "expected 'is_dead' to be true after 2 ticks!");
      });
   });

   suite("Union", #code {
      test("primitive types", (t) => {
         u: Union(struct {
             A: s64;
             B: u8;
             C: float64;
         });

         set(*u, 35);
         expect(t, u.tag == .A, "tag was expected to be A, instead was %", u.tag);

         set(*u, cast(float64)3.14);
         expect(t, u.tag == .C, "tag was expected to be C, instead was %", u.tag);

         set(*u, cast(u8)255);
         expect(t, u.tag == .B, "tag was expected to be B, instead was %", u.tag);
      });

      test("struct types", (t) => {
         Foo :: struct { a: int; };
         Bar :: struct { b: int; };

         u: Union(struct {
             foo: Foo;
             bar: Bar;
         });

         set(*u, Foo.{ 10 });
         expect(t, u.tag == .foo, "tag was expected to be Foo, instead was %", u.tag);
         expect(t, u.foo.a == 10);

         set(*u, Bar.{ 20 });
         expect(t, u.tag == .bar, "tag was expected to be Bar, instead was %", u.tag);
         expect(t, u.bar.b == 20);
      });

      test("union of unions", (t) => {
         Base :: Union(struct {
            a: A;
            b: B;
            c: C;
            d: D;
         }, u8);

         A :: struct { a: int; };
         B :: struct { b: int; };
         C :: struct { c: int; };
         D :: struct {
             value: Union(struct {
                a: *A;
                b: *B;
                c: *C;
                d: *D;
             }, u16);
         };

         base: Base;

         {
             size := size_of(type_of(Base.tag));
             expect(t, size == 1, "Expected Base.tag to have a runtime size of 1, instead had %", size);
         }

         {
            size := size_of(type_of(D.value.tag));
            expect(t, size == 2, "Expected D.value.tag to have a runtime size of 2, instead had %", size);
         }

         set(*base, A.{ 10 });
         expect(t, base.tag == .a, "expected tag to be A, instead was %", base.tag);

         set(*base, B.{ -1 });
         expect(t, base.tag == .b, "expected type to be B, instead was %", base.tag);

         {
            d: D;
            set(*d.value, *C.{ 255 });
            set(*base, d);

            expect(t, base.tag == .d, "expected type to be D, instead was %", base.tag);
         }
      });
   });

   suite("Utilities", #code {
       test("as", (t) => {
           foo: float64 = 3.14;
           expect(t, type_of(as(*u64, *foo)) == *u64);
       });

       test("pluralize", (t) => {
           expect(t, pluralize("foo", 0)  == "foos");
           expect(t, pluralize("foo", 1)  == "foo");
           expect(t, pluralize("bars", 0) == "bars");
           expect(t, pluralize("bars", 1) == "bars");
       });

       test("name of procedure", (t) => {
           foo :: () -> string { return get_name_of_current_procedure(); }
           bar_baz :: () -> string { return get_name_of_current_procedure(); }

           expect(t, foo() == "foo");
           expect(t, bar_baz() == "bar_baz");

           no_name := get_name_of_current_procedure();
           expect(t, no_name == "proc", "unnamed procedure had name '%'", no_name);
       });

       test("verify block", (t) => {
           for 0..100 {
               value    := it;
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

       test("unicode peek/consume", (t) => {
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

       test("ascii peek/consume", (t) => {
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

       test("array peek/consume", (t) => {
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

       test("string view", (t) => {
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

       test("rune width", (t) => {
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

       test("rune append", (t) => {
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

       test("make_t", (t) => {
           A :: struct {
               x: int;
               y: []int;
               z: struct {
                   a: float32;
                   b: float64;
               };
           }

           init_a :: (a: *A)  {
               a.x   = 100;
               a.z.a = 3.14;
           }

           a1 := make(A);
           expect(t, a1.x       == 0);
           expect(t, a1.y.count == 0);
           expect(t, a1.z.a     == 0);
           expect(t, a1.z.b     == 0);

           a2 := make(A, init_a);
           expect(t, a2.x       == 100);
           expect(t, a2.y.count == 0);
           expect(t, a2.z.a     == 3.14);
           expect(t, a2.z.b     == 0);

           a3 := make(A, (a: *A) {
               a.z.b = 3.14;
           });

           expect(t, a3.x       == 0);
           expect(t, a3.y.count == 0);
           expect(t, a3.z.a     == 0);
           expect(t, a3.z.b     == 3.14);

           // Make sure anonymous types work
           foo := make(struct{
               bar := "hello";
               baz: float32;
               boz: [..]struct {
                   biz := "goodbyte";
               };
           });

           expect(t, foo.bar == "hello");
           expect(t, foo.baz == 0);
           expect(t, foo.boz.count == 0);

           array_add(*foo.boz, .{});
           expect(t, foo.boz[0].biz == "goodbyte");

           bar := make(struct {
               total:  int;
               values: [..]string;
           }, (b) => {
               array_add(*b.values, "hello");
               array_add(*b.values, "world");
               b.total = 2;
           });

           expect(t, bar.values.count == bar.total);
           expect(t, bar.values[0] == "hello");
           expect(t, bar.values[1] == "world");

           // Make sure primitive types work
           x := make(int);
           expect(t, x == 0);

           // Make sure lambdas work
           y := make(float32, (f) => { <<f = 0.5; });
           expect(t, y == 0.5);
       });

       test("make_slice", (t) => {
           arr1 := make([]int, 10);
           expect(t, arr1.data  != null);
           expect(t, arr1.count == 10);

           arr1[arr1.count - 1] = 500;
           arr1[arr1.count - 2] = 400;
           expect(t, arr1[arr1.count - 1] == 500);
           expect(t, arr1[arr1.count - 2] == 400);
       });

       test("make_dynamic_array", (t) => {
           arr1 := make([..]int, 10);
           expect(t, arr1.data      != null);
           expect(t, arr1.count     == 0);
           expect(t, arr1.allocated == 10);

           array_add(*arr1, 5, 6);
           expect(t, arr1[0]        == 5);
           expect(t, arr1[1]        == 6);
           expect(t, arr1.count     == 2);
           expect(t, arr1.allocated == 10);
       });

       test("len/cap", (t) => {
           slice: []int;
           expect(t, len(slice) == 0);
           expect(t, cap(slice) == 0);

           array: [5]int;
           expect(t, len(array) == 5);
           expect(t, cap(array) == 5);

           dyn: [..]int;
           expect(t, len(dyn) == 0);
           expect(t, cap(dyn) == 0);

           array_add(*dyn, 1);
           expect(t, len(dyn) == 1);
           expect(t, cap(dyn) % 2 == 0);
       });
   });
}

#import,file "module.jai";
