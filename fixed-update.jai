/// Locked timestep update loop

/*
   Usage:
      loop: Fixed_Update;
      init(*loop);

   Fixed_Update is expected to be put inside
   your main while loop.

      while true {
         do_fixed_update(*loop, #code {
            // Update code in here
         });
      }
*/

Fixed_Update :: struct(TIMESTEP: float64 = 0.01, MAX_FRAME_TIME := 0.25) {
   accumulator: float64;
   last_frame:  float64;
}

init :: (using fu: *Fixed_Update) {
   accumulator = 0;
   last_frame  = hi_res_time_in_seconds();
}

do_fixed_update :: (using fu: *Fixed_Update, body: Code) #expand {
   this_frame  := hi_res_time_in_seconds();
   `frame_time := this_frame - last_frame;

   if frame_time > MAX_FRAME_TIME {
      frame_time = MAX_FRAME_TIME;
   }

   last_frame   = this_frame;
   accumulator += frame_time;

   `dt :: TIMESTEP;
   while accumulator >= TIMESTEP {
      #insert body;
      accumulator -= TIMESTEP;
   }
}

hi_res_time_in_seconds :: inline () -> float64 {
   return to_float64_seconds(current_time_monotonic());
}


#scope_file

#import "Basic";

