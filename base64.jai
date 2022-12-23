/// Simple base64 encoder/decoder

base64_encode :: (data: []u8, $for_url := false, $with_padding := false, allocator := context.allocator) -> []u8, bool  {
   if !data.count return .[], false;

   encoded := NewArray(encoded_length(data.count, with_padding), u8, true, allocator);
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

base64_encode :: (str: string, $for_url := false, $with_padding := false, allocator := context.allocator) -> []u8, bool {
   data: []u8 = ---;
   data.data  = str.data;
   data.count = str.count;

   encoded, ok := base64_encode(data, for_url, with_padding, allocator);
   return encoded, ok;
}

// @Todo(Judah): There's a bug that I'm not going to
// fix since I haven't used this in a real project yet.

base64_decode :: (data: []u8, allocator := context.allocator) -> []u8, bool {
   if !data.count return .[], false;

   padding := 0;
   for < data.count - 1..0 if data[it] == PADDING_VALUE then padding += 1; else break;

   decoded := NewArray(((6 * data.count) / 8) - padding, u8, true, allocator);
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

base64_decode :: inline (str: string, allocator := context.allocator) -> string, bool {
   data: []u8 = ---;
   data.data  = str.data;
   data.count = str.count;

   decoded, ok := base64_decode(data, allocator);
   dec: string = ---;
   dec.data  = decoded.data;
   dec.count = decoded.count;
   return dec, ok;
}

#scope_file

encoded_length :: (count: int, with_padding := false) -> int {
   if with_padding then return (count + 2) / 3 * 4;
   return (count * 8 + 5) / 6;
}

PADDING_VALUE     :: #char "=";
ENCODING_URL      :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
ENCODING_STANDARD :: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

#import "Basic";
