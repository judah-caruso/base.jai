/// Simple Odin-like bitset

Bit_Set :: struct(T: Type)
#modify {
   info := cast(*Type_Info_Enum)T;
   if info.type != .ENUM {
      compiler_report("T must be an enum!", #location(T));
      return false;
   }

   if info.enum_type_flags & .FLAGS != 0 {
      return true;
   }

   #import "Compiler";
   compiler_report("T must be of type 'enum_flags'!", #location(T));
   return false;
}{
   values: T;
}

reset :: (set: *Bit_Set) {
   set.values = 0;
}

operator + :: (set: Bit_Set, value: set.T) -> Bit_Set(set.T) {
   s := set;
   s.values |= value;
   return s;
}

operator - :: (set: Bit_Set, value: set.T) -> Bit_Set(set.T) {
   s := set;
   s.values &= ~value;
   return s;
}

operator == :: inline (lhs: Bit_Set, rhs: Bit_Set) -> bool {
   return lhs.values == rhs.values;
}

operator == :: inline (lhs: Bit_Set, rhs: lhs.T) -> bool {
   return lhs.values == rhs;
}

operator [] :: inline (set: Bit_Set, value: set.T) -> bool {
   return set.values & value != 0;
}

operator []= :: inline (set: *Bit_Set, value: set.T, $$toggle: bool) {
   #if is_constant(toggle) {
      #if toggle set.values |= value;
      else       set.values &= ~value;
   } else {
      if  toggle set.values |= value;
      else       set.values &= ~value;
   }
}
