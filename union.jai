/// Tagged unions with auto generated tags

Union :: struct(T: Type, TAG := s64) {
   #insert -> string {
      tag_info := type_info(TAG);
      if tag_info.type != .INTEGER {
         compiler_report("Union tag must be an integer!", loc = #location(TAG));
      }

      info := type_info(T);
      if info.type != .STRUCT {
         compiler_report("Only structs can be passed to Union!", loc = #location(T));
      }

      eb: String_Builder;
      ub: String_Builder;

      init: T;
      zero: T = ---;
      memset(*zero, 0, size_of(T));

      sinfo := cast(*Type_Info_Struct)info;
      for sinfo.members {
         if it.offset_into_constant_storage != -1 {
            compiler_report(sprint("Constant declarations are not allowed in unions!"), mode = .WARNING, loc = #location(T)); // @TEMP
            continue;
         }

         // @Note(Judah): Because we don't want to allow member
         // declarations with default values, we instantiate
         // the same struct twice, zeroing out one, and default
         // initializing the other. We then compare the memory
         // of each member to see if it was set in the initializer
         // and ignore it if it was.
         size := it.type.runtime_size;
         iptr := (cast(*u8)*init) + it.offset_in_bytes;
         zptr := (cast(*u8)*zero) + it.offset_in_bytes;
         if memcmp(iptr, zptr, size) != 0 {
            compiler_report(sprint("Declarations with default values are not allowed in unions!"), mode = .WARNING, loc = #location(T)); // @TEMP
            continue;
         }

         mt := get_type(it.type);
         print_to_builder(*eb, "\t%1; // _value.%1\n", it.name);
         print_to_builder(*ub, "\t%1: type_of(T.%1) = ---; // %\n", it.name, mt);
      }

      b: String_Builder;
      print_to_builder(*b, "tag: enum % {\n", TAG);
      append(*b, builder_to_string(*eb));
      append(*b, "};\n");

      append(*b, "using _value: union {\n");
      append(*b, builder_to_string(*ub));
      append(*b, "};\n");

      return builder_to_string(*b);
   }
}

set :: (u: *Union, $$tag: type_of(u.tag), value: $T) {
   u.tag = tag;

   #if is_constant(tag) {
      #insert -> string { return sprint("u.% = value;\n", tag); }
   }
   else {
      <<(cast(*T)*u._value) = value;
   }
}

set :: inline (u: *Union, value: $T) #expand {
   #insert -> string {
      pinfo := cast(*Type_Info_Pointer)type_info(type_of(u));
      info  := cast(*Type_Info_Struct)pinfo.pointer_to;
      einfo := cast(*Type_Info_Enum)info.members[0].type;
      sinfo := cast(*Type_Info_Struct)info.members[1].type;

      name: string;
      tinfo := type_info(T);
      for sinfo.members if it.type == tinfo {
         name = einfo.names[it_index];
      }

      if name.count <= 0 {
         compiler_report(sprint("Type '%' doesn't exist within union!", T), loc = #location(T));
         return "";
      }

      return sprint("set(u, .%, value);", name);
   }
}

#import "Basic";
