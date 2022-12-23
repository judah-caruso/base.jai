/// Tagged unions

Union :: struct(TYPES: ..Type) {
   type:   Type;
   memory: [#run get_largest_type(TYPES)]u8;

   type_belongs :: (T: Type) -> bool {
      for type: TYPES if type == T then return true;
      return false;
   }
}

is_a :: inline (using u: *Union, $T: Type) -> bool {
   return type == T;
}

as :: inline (using u: *Union, $T: Type) -> *T {
   return as(*T, memory.data);
}

unwrap :: (using u: *Union) -> Type, *void {
   return type, memory.data;
}

set :: (using u: *Union, value: $T) {
   #assert(type_belongs(T));

   type = T;
   (<<cast(*T)memory.data) = value;
}

get :: (using u: *Union, $T: Type) -> *T, bool {
   #assert(type_belongs(T));

   if type == T then return cast(*T)memory.data, true;
   return null, false;
}


#scope_file

get_largest_type :: (types: []Type) -> s64 {
   largest := 0;

   for T: types {
      info := type_info(type_of(T));
      if info.runtime_size > largest then largest = info.runtime_size;
   }

   return largest;
}
