/// This allocator simply crashes the program when used.
/// It is used to make sure no hidden allocations occur.
make_crash_allocator :: () -> Allocator {
   return .{ crash_allocator_proc, null };
}

#scope_file;

crash_allocator_proc :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
   if mode == {
      case .ALLOCATE;
         log("Attempt to allocate % % using the crash allocator!", size, pluralize("byte", size));
      case .RESIZE;
         log("Attempt to resize (from % to % %) using the crash allocator!", old_size, size, pluralize("byte", size));
      case .FREE;
         log("Attempt to free % % using the crash allocator!", size, pluralize("byte", size));
   }

   assert(false);
   return null;
}

#if RUN_INTERNAL_TESTS #run {
   suite("Allocators", #code {
      test("crash allocator", (t: *Test) {
         ref := make_crash_allocator();

         context.allocator = make_crash_allocator();
         expect(t, context.allocator.proc == ref.proc);
         expect(t, context.allocator.data == null);
      });
   });
}