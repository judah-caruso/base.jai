base64_encode :: (data: []u8, $for_url := false, $with_padding := false) -> []u8, bool  {
   if !data.count return .[], false;

   encoded := NewArray(encoded_length(data.count, with_padding), u8, true, temporary_allocator);
   if !encoded.count return .[], false;

   #if for_url {
      ENCODING :: ENCODING_URL;
   } else {
      ENCODING :: ENCODING_STANDARD;
   }

   src_idx := 0;
   dst_idx := 0;
   src_max := (data.count / 3) * 3;
   while src_idx < src_max {
      value: u64;

      parts := cast(*u8)*value;
      <<(parts + 0) = xx data[src_idx + 2];
      <<(parts + 1) = xx data[src_idx + 1];
      <<(parts + 2) = xx data[src_idx + 0];

      encoded[dst_idx + 0] = ENCODING[value >> 18 & 0x3F];
      encoded[dst_idx + 1] = ENCODING[value >> 12 & 0x3F];
      encoded[dst_idx + 2] = ENCODING[value >>  6 & 0x3F];
      encoded[dst_idx + 3] = ENCODING[value       & 0x3F];

      src_idx += 3;
      dst_idx += 4;
   }

   remaining := data.count - src_idx;
   if !remaining then return encoded, true;

   value := (cast(u64)data[src_idx + 0]) << 16;
   if remaining == 2 {
      value |= (cast(u64)data[src_idx + 1]) << 8;
   }

   encoded[dst_idx + 0] = ENCODING[value >> 18 & 0x3F];
   encoded[dst_idx + 1] = ENCODING[value >> 12 & 0x3F];

   if remaining == {
      case 2;
         #if with_padding {
            encoded[dst_idx + 2] = PADDING_VALUE;
            encoded[dst_idx + 3] = PADDING_VALUE;
         }
      case 1;
         encoded[dst_idx + 2] = ENCODING[value >> 6 & 0x3F];
         #if with_padding {
            encoded[dst_idx + 3] = PADDING_VALUE;
         }
   }

   return encoded, true;
}

base64_encode :: (str: string, $for_url := false, $with_padding := false) -> []u8, bool {
   data: []u8 = ---;
   data.data  = str.data;
   data.count = str.count;

   encoded, ok := base64_encode(data, for_url, with_padding);
   return encoded, ok;
}

base64_decode :: (data: []u8) -> []u8, bool {
   if !data.count return .[], false;

   padding := 0;
   for < data.count - 1..0 if data[it] == PADDING_VALUE then padding += 1; else break;

   decoded := NewArray(((6 * data.count) / 8) - padding, u8, true, temporary_allocator);
   if !decoded.count return .[], false;

   lookup :: (c: u8) -> u8 #expand {
      if c >= #char "A" && c <= #char "Z" return c - #char "A";
      if c >= #char "a" && c <= #char "z" return c - 71;
      if c >= #char "0" && c <= #char "9" return c + 4;
      if c == #char "+" || c == #char "-" return 62;
      if c == #char "/" || c == #char "_" return 63;
      return 255;
   }

   a4_to_a3 :: () #expand {
      `a3[0] = (`a4[0] << 2) + ((`a4[1] & 0x30) >> 4);
      `a3[1] = ((`a4[1] & 0xF) << 4) + ((`a4[2] & 0x3C) >> 2);
      `a3[2] = ((`a4[2] & 0x3) << 6) + `a4[3];
   }

   a3: [3]u8;
   a4: [4]u8;

   i      := 0;
   offset := 0;

   for 0..data.count - 1 {
      chr := data[it];
      if chr == PADDING_VALUE break;

      a4[i] = chr;
      i += 1;

      if i == 4 {
         for 0..3 a4[it] = lookup(a4[it]);

         a4_to_a3();

         for 0..2 {
            <<cast(*u8)(decoded.data + offset) = a3[it];
            offset += 1;
         }

         i = 0;
      }
   }

   if i > 0 {
      for 0..3 a4[it] = lookup(a4[it]);

      a4_to_a3();

      for 0..i - 1 {
         <<cast(*u8)(decoded.data + offset + it) = a3[it];
      }
   }

   return decoded, true;
}

base64_decode :: inline (str: string) -> string, bool {
   data: []u8 = ---;
   data.data  = str.data;
   data.count = str.count;

   decoded, ok := base64_decode(data);
   return to_string(decoded), ok;
}

#scope_file;

encoded_length :: (count: int, with_padding := false) -> int {
   if with_padding then return (count + 2) / 3 * 4;
   return (count * 8 + 5) / 6;
}

PADDING_VALUE     :: #char "=";
ENCODING_URL      :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
ENCODING_STANDARD :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

#if RUN_INTERNAL_TESTS #run suite("Base64", #code {
   test("encodes", (t: *Test) {
      str :: "Hello, World";

      encoded, ok := base64_encode(str);
      expect(t, ok, "'%' did not properly encode!", str);

      encoded_str  := to_string(encoded);
      expected_str :: "SGVsbG8sIFdvcmxk";

      expect(t, encoded_str == expected_str, "Invalid result from encode! Wanted: '%', received: '%'", expected_str, encoded_str);
   });

   test("decodes", (t: *Test) {
      encoded_str :: "SGVsbG8sIFdvcmxk";

      decoded_str, ok := base64_decode(encoded_str);
      expect(t, ok, "'%' did not properly decode!", encoded_str);

      expected_str :: "Hello, World";
      expect(t, decoded_str == expected_str, "Invalid result from decode! Wanted: '%', received: '%'", expected_str, decoded_str);
   });

   test("encode/decode with padding", (t: *Test) {
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

   test("encode/decode basic structure", (t: *Test) {
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
