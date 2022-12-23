/// Utilities for dynamic arrays.

append        :: array_add;
append_unique :: array_add_if_unique;

insert :: (a: *[..]$T, index: s64, value: T) #expand {
   array_insert_at(a, value, index);
}

insert :: (a: *[..]$T, index: s64) -> *T #must #expand {
   zero: T = ---;
   array_insert_at(a, zero, index);
   return *a.data[index];
}

Removal_Kind :: enum {
   Ordered;
   Unordered;
}

remove_by_index :: (a: *[..]$T, index: s64, $kind := Removal_Kind.Ordered) {
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

#import "Basic";
