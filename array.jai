append        :: array_add;
append_unique :: array_add_if_unique;

insert :: (a: *[..]$T, index: sint, value: T) #expand {
   array_insert_at(a, value, index);
}

insert :: (a: *[..]$T, index: sint) -> *T #must #expand {
   zero: T = ---;
   array_insert_at(a, zero, index);
   return *a.data[index];
}

Removal_Kind :: enum {
   Ordered;
   Unordered;
}

remove_by_index :: (a: *[..]$T, index: sint, $kind := Removal_Kind.Ordered) {
   #if kind == .Ordered {
      array_ordered_remove_by_index(a, index);
   } else {
      array_unordered_remove_by_index(a, index);
   }
}

remove_by_value :: (a: *[..]$T, value: T, $kind := Removal_Kind.Ordered) {
   #if kind == .Ordered {
      array_ordered_remove_by_value(a, value);
   } else {
      array_unordered_remove_by_value(a, value, true);
   }
}

remove_by_pointer :: (a: *[..]$T, ptr: *T, $kind := Removal_Kind.Ordered) {
   for 0..a.count - 1 if ptr == *a.data[it] {
      remove_by_index(a, it, kind);
      return;
   }
}

#scope_file

#if RUN_INTERNAL_TESTS #run {
   suite("Array", #code {
      test("append/append_unique", (t) => {
         foo: [..]sint;
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
         foo: [..]sint;
         insert(*foo, 0, 100);
         insert(*foo, 0, 200);
         insert(*foo, 1, 300);

         expect(t, len(foo) == 3);
         expect(t, foo[0] == 200);
         expect(t, foo[1] == 300);
         expect(t, foo[2] == 100);
      });

      test("remove_by_index", (t) => {
         foo: [..]sint;
         append(*foo, 1, 2, 3, 4);
         items := len(foo);

         remove_by_index(*foo, 1);
         expect(t, len(foo) == items - 1);

         expect(t, foo[0] == 1);
         expect(t, foo[1] == 3);
         expect(t, foo[2] == 4);
      });

      test("remove_by_value", (t) => {
         foo: [..]sint;
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
         foo: [..]sint;
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
 }
