/// Custom allocators

/// This allocator makes sure no hidden allocations
/// occur by crashing the program on use.
make_crash_allocator :: () -> Allocator {
   return .{ crash_allocator_proc, null };
}

#scope_file

crash_allocator_proc :: (mode: Allocator_Mode, size: s64, old_size: s64, old_memory: *void, allocator_data: *void) -> *void {
   message: string;
   if mode == {
      case .ALLOCATE;
         message = sprint("Attempt to allocate % byte(s) using the crash allocator!", size);
      case .RESIZE;
         message = sprint("Attempt to resize (from % to % byte(s)) using the crash allocator!", old_size, size);
      case .FREE;
         message = sprint("Attempt to free % byte(s) using the crash allocator!", size);
   }

   assert(false, message);
   return null;
}

#import "Basic";
