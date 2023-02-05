/// Immediate mode tweening

/*
   Tweens are created by calling 'tween' in the update
   loop. It returns true (if the tween has finished) and
   a pointer to the Tween.

   The first time 'tween' is called, a new tween will be
   created and registered in the system.

   Example:
      x := 10;
      y := 0;

      while running {
         dt := delta_time_in_seconds();

         // Creates or updates a 3 second tween
         // from x (10) to x + 10 (20) using
         // the default easing (Quad, InOut).
         if tween(dt, 3, *x, x + 10) {
            print("X tween has finished!\n");
         }

         // Creates or updates a 10 second tween
         // from y (0) to y + 10 (y) using Linear
         // easing.
         if tween(dt, 10, *y, y + 10, .Linear, .In) {
            print("Y tween has finished!\n");
         }
      }

   Tweens can be reset like so. Looping is just resetting
   the tween after it has finished.

      // ...

      done, t := tween(dt, 2, *x, x + 10, .Quart, .In_Out);
      if done {
         // Reset and replay the tween next frame
         reset(t);
      }

   To properly loop tweens without snapping the value back
   to its initial position, 'reverse' can be called:

      // ...
      x := 10;
      loops := 0;

      done, t := tween(dt, 8, *x, x + 50);
      if done {
         loops += 1;

         if loops < 10 {
            reset(t); // Resets are explicit
            reverse(t);
         }
      }

   The above example will tween 'x' from its initial
   position (10) to 60 after 8 seconds, then will tween
   its final position (60) back to 10 (again after 8
   seconds). This will smoothly loop the position back
   and forth.

   Tweens can be delayed with the 'delay' parameter:

      // ...
      if tween(dt, 1, *x, x + 10, delay = 5) {
         print("This tween took 6 seconds to finish\n");
      }

   We can also tween structures. Any values in 'to' will
   be applied to 'from'.

      pos := Vector2.{ 10, 20 };
      if tween(dt, *pos, .{ 100, 50 }) {
         print("We've reached the right position!\n");
      }

   The underlying algorithm for will check the delta
   between 'from' and 'to', and tween any that are
   non-zero.

      pos := Vector3.{ x = 50, y = 20, z = 80 };
      if tween(dt, *pos, .{ x = 100, y = 200, z = pos.z }) {
         // Only 'x' and 'y' were modified in 'pos'.
         // 'z' was ignored because it had the same
         // value in 'from' and 'to'
      }

   To sequence tweens:

      pos := Vector2.{ 10, 20 };
      if tween(dt, *pos, .{ x = 100 }) {
         print("First move to the right\n");

         if tween(dt, *pos, .{ y = 50 }) {
            print("Then move down\n");

            if tween(dt, *pos, .{ x = 0, y = 0 }) {
               print("Then move back to 0, 0\n");
            }
         }
      }

   Because the library is meant to be lightweight,
   sequencing works like this out of the box. However, we
   can very easily improve things:

      pos := Vector2.{ 10, 20 };
      state: Tween_State;

      if state == {
         case .First;
            if tween(dt, *pos, .{ x = 100 }) {
               state = .Second;
            }

         case .Second;
            if tween(dt, *pos, .{ y = 50 }) {
               state = .Third;
            }

         case .Third;
            if tween(dt, *pos, .{ x = 0, y = 0 }) {
               print("All tweens have finished!\n");
            }
      }

   To reset the entire sequence, we can cache the pointers
   and reset them once our final tween has finished:

      // ...
      tweens: [Tween_State.Total_States]*Tween;

      if state == {
         // ...
         case .Third;
            done, t := tween(dt, *pos, .{ x = 0, y = 0, z = pos.z });
            tweens[cast(int)state] = t;

            if done {
               print("All tweens have finished!\n");

               state = .First;
               for tweens reset(it);
            }
      }

   A more advanced use case is to create tweens ahead of
   time and update them based on some logic. We can do
   this with 'make_tween' and 'update_tween':

      // ...
      sequence: [..]*Tween;
      array_add(*sequence, make_tween(5, *pos, .{ x = 10, y = 20,    z = pos.z }));
      array_add(*sequence, make_tween(3, *pos, .{ x = 50, y = 80,    z = pos.z }));
      array_add(*sequence, make_tween(2, *pos, .{ x = 90, y = pos.y, z = pos.z }));

      i := 0;
      if state == {
         case .First;
            if update_tween(sequence[i], dt) {
               i = i + 1 % sequence.count;
               state = .Second;
            }

         // ...

         case .Third;
            if update_tween(sequence[i], dt) {
               print("All tweens have finished!\n");

               for tween: sequence {
                  reset(tween);
                  reverse(tween);
               }

               i     = 0;
               state = .First;
            }
      }
*/

Ease :: enum {
   Linear;
   Quad;
   Cubic;
   Quart;
   Quint;
   Expo;
   Sine;
   Circ;
   Back;
   Elastic;
}

Transition :: enum {
   In;
   Out;
   In_Out;
}

Tween :: struct {
   ease:       Ease;
   transition: Transition;
   rate:       float;
   progress:   float;
   delay:      float;
   done:       bool;
}

tween :: (dt: float, time_sec: float, from: *$T, to: T, ease := Ease.Quart, transition := Transition.In_Out, delay: float = 0, id: s64 = 0, loc := #caller_location)  -> bool, *Tween {
   hash  := get_hash_for_tween(loc, id);
   state := make_tween(time_sec, from, to, ease, transition, delay, id, loc);
   return update_tween(state, dt), state;
}

make_tween :: (time_sec: float, from: *$T, to: T, ease := Ease.Quart, transition := Transition.In_Out, delay: float = 0, id: s64 = 0, loc := #caller_location) -> *Tween {
   if !context.tween_manager.initialized init_tween_manager();

   hash  := get_hash_for_tween(loc, id);
   state := find_or_create_tween(hash, time_sec, from, to, ease, transition, delay);
   return state;
}

update_tween :: (tween: *Tween, dt: float) -> (done: bool) {
   // Early out for null/deleted tweens
   if !tween || !tween_is_managed(tween) return false;

   if tween.done return true;

   state := cast(*Tween_State)tween;

   if state.delay > 0 {
      state.delay -= dt;
      return false;
   }

   state.progress += state.rate * dt;
   if state.progress >= 1 {
      state.done = true;
      return true;
   }

   // The tween is still in progress
   p := do_tween_step(state.ease, state.transition, state.progress);
   for state.tweenable_values {
      <<it.value = it.from + p * it.delta;
   }

   return false;
}

reset :: (tween: *Tween) {
   if !tween return;

   state := cast(*Tween_State)tween;
   tween.done     = false;
   tween.delay    = state.initial_delay;
   tween.progress = 0;
}

reverse :: (tween: *Tween) {
   if !tween return;

   state := cast(*Tween_State)tween;
   for * state.tweenable_values {
      tmp := it.from;
      it.from  = it.to;
      it.to    = tmp;
      it.delta = -it.delta;
   }
}

delete :: (tween: *Tween) {
   if !tween return;

   removed: bool;
   state := <<cast(*Tween_State)tween;

   removed, state = table_remove(*context.tween_manager.tweens, state.hash);
   if removed array_free(state.tweenable_values);
}

init_tween_manager :: (allocator := context.allocator) {
   manager := *context.tween_manager;

   manager.initialized      = true;
   manager.tweens.allocator = allocator;
}

deinit_tween_manager :: () {
   manager := *context.tween_manager;

   for manager.tweens array_free(it.tweenable_values);
   deinit(*manager.tweens);

   manager.initialized = false;
}

// Generate 'do_tween_step' from the Ease enum and EASING_FUNCTIONS array.
#insert -> string {
   info := cast(*Type_Info_Enum)Ease;
   b: String_Builder;

   print_to_builder(*b, "do_tween_step :: (ease: Ease, transition: Transition, progress: float) -> float {\n");
   append(*b, "\tp := progress;\n");
   append(*b, "\tif ease == {\n");

   for info.names {
      func := EASING_FUNCTIONS[it_index];

      print_to_builder(*b, #string END
      case .%1; if transition == {
         case .In;
            return %2;

         case .Out;
            p = 1 - p;
            return 1 - (%2);

         case .In_Out;
            p *= 2;
            if p < 1 {
               return 0.5 * (%2);
            }

            p = 2 - p;
            return 0.5 * (1 - (%2)) + 0.5;
      }
      END, it, func);
   }

   append(*b, "\t}\n\treturn p;\n}\n");

   return builder_to_string(*b);
}

#scope_file;

Tween_State :: struct {
   #as using tween: Tween;

   hash:          u64;
   initial_delay: float;

   value:            *void;
   tweenable_values: [..]Tweenable;

   Tweenable :: struct {
      to:    float;
      from:  float;
      delta: float;
      value: *float;
   }
}

#add_context tween_manager: struct {
   tweens:      Table(u64, Tween_State);
   initialized: bool;
};

tween_is_managed :: (tween: *Tween) -> bool {
   state := cast(*Tween_State)tween;
   _, exists := table_find(*context.tween_manager.tweens, state.hash);
   return exists;
}

find_or_create_tween :: (hash: u64, time_sec: float, from: *$T, to: T, ease: Ease, transition: Transition, delay: float) -> *Tween_State
#modify {
   info := cast(*Type_Info)T;
   if info.type != .STRUCT && info.type != .FLOAT {
      compiler_report(tprint("% is not a tweenable type!", T));
      return false;
   }

   return true;
}
{
   manager := *context.tween_manager.tweens;
   tween   := table_find_pointer(manager, hash);
   if !tween {
      rate: float;
      if time_sec > 0 {
         rate = 1 / time_sec;
      }

      tween = table_add(manager, hash, .{
         hash = hash,

         ease       = ease,
         transition = transition,
         rate       = rate,

         value = from,

         delay         = delay,
         initial_delay = delay,
      });

      // Calculate deltas and add any non-zero to tweenable_values.
      // This is an array of values we should update every frame.
      // @Todo(Judah): Pre-calculate deltas and call array_reserve?
      tween.tweenable_values.allocator = context.tween_manager.tweens.allocator;

      #insert -> string {
         member_is_tweenable :: (info: Type_Info_Struct_Member) -> bool {
            return info.type.type == .FLOAT && info.offset_into_constant_storage == -1;
         }

         b: String_Builder;

         info           := cast(*Type_Info)T;
         current_offset := -1;

         if info.type == .STRUCT {
            sinfo := cast(*Type_Info_Struct)info;
            for sinfo.members if member_is_tweenable(it) {
               // Don't try to tween any #place'd members.
               if it.offset_in_bytes <= current_offset continue;
               current_offset = it.offset_in_bytes;

               print_to_builder(*b, #string END
                  delta_%1 := to.%1 - from.%1;
                  if delta_%1 != 0 {
                     array_add(*tween.tweenable_values, .{
                        to    = to.%1,
                        from  = from.%1,
                        delta = delta_%1,
                        value = *from.%1,
                     });
                  }
               END, it.name);
            }
         }
         else if info.type == .FLOAT {
            print_to_builder(*b, #string END
               delta := to - <<from;
               if delta != 0 {
                  array_add(*tween.tweenable_values, .{
                     to    = to,
                     from  = <<from,
                     delta = delta,
                     value = from,
                  });
               }
            END);
         }

         return builder_to_string(*b);
      }
   }

   return tween;
}

EASING_FUNCTIONS :: string.[
   "p",                                                             // Linear
   "p * p",                                                         // Quad
   "p * p * p",                                                     // Cubic
   "p * p * p * p",                                                 // Quart
   "p * p * p * p * p",                                             // Quint
   "pow(2, 10 * (p - 1))",                                          // Expo
   "-cos(p * (PI * 0.5)) + 1",                                      // Sine
   "-(sqrt(1 - (p * p)) - 1)",                                      // Circ
   "p * p * (2.7 * p - 1.7)",                                       // Back
   "-pow(2, 10 * p - 10) * sin((p * 10 - 10.75) * ((2 * PI) / 3))", // Elastic
];

// Yoinked from GetRect
KNUTH_GOLDEN_RATIO_64 :: 11400714819323198485;

get_hash_for_tween :: (loc: Source_Code_Location, identifier: s64) -> u64 {
   Hash :: #import "Hash";

   // Maybe we should hash the filename pointer in order to better prevent collisions.
   name_hash := Hash.djb2_hash(loc.fully_pathed_filename);
   line_hash := Hash.knuth_hash(cast,no_check(u64) loc.line_number);
   identifier_hash := Hash.knuth_hash(cast,no_check(u64) identifier);

   result := combine_hashes(name_hash, combine_hashes(line_hash, identifier_hash));
   return result;
}

combine_hashes :: (a: u64, b: u64) -> u64 {
   return a * KNUTH_GOLDEN_RATIO_64 + b;
}

#import "Math";
#import "Basic";
#import "Compiler";
#import "Hash_Table";
