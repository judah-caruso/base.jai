/// This allocator simply crashes the program when used.
/// It is used to make sure no hidden allocations occur.
make_crash_allocator :: () -> Allocator {
   return .{ crash_allocator_proc, null };
}

#scope_file;

crash_allocator_proc :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
   message: string;
   if mode == {
      case .ALLOCATE;
         message = tprint("Attempt to allocate % byte(s) using the crash allocator!", size);
      case .RESIZE;
         message = tprint("Attempt to resize (from % to % byte(s)) using the crash allocator!", old_size, size);
      case .FREE;
         message = tprint("Attempt to free % byte(s) using the crash allocator!", size);
   }

   assert(false, message);
   return null;
}

#if RUN_INTERNAL_TESTS #run {
   suite("Allocators", #code {
      test("crash allocator", (t) => {
         ref := make_crash_allocator();

         context.allocator = make_crash_allocator();
         expect(t, context.allocator.proc == ref.proc);
         expect(t, context.allocator.data == null);
      });
   });
}
