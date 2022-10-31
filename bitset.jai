/// Simple Odin-like bitset

Bit_Set :: struct(T: Type)
#modify {
   info := cast(*Type_Info_Enum)T;
   if info.type != .ENUM return false;

   if info.enum_type_flags & .FLAGS != 0 {
      return true;
   }

   #import "Compiler";
   compiler_report("T must be of type 'enum_flags'!", #location(T));
   return false;
}{
   values: T;
}

operator+ :: (set: Bit_Set, value: set.T) -> Bit_Set(set.T) {
   s := set;
   s.values |= value;
   return s;
}

operator- :: (set: Bit_Set, value: set.T) -> Bit_Set(set.T) {
   s := set;
   s.values &= ~value;
   return s;
}

operator== :: inline (lhs: Bit_Set, rhs: Bit_Set) -> bool {
   return lhs.values == rhs.values;
}

operator== :: inline (lhs: Bit_Set, rhs: lhs.T) -> bool {
   return lhs.values == rhs;
}

operator[] :: inline (set: Bit_Set, value: set.T) -> bool {
   return set.values & value != 0;
}

#if RUN_INTERNAL_TESTS #run {
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
         foo += Foo.B | .C;

         expect(t, !foo[.A]);
         expect(t,  foo[.B]);
         expect(t,  foo[.C]);

         expect(t, foo == Foo.B | .C);
      });
   });
}
