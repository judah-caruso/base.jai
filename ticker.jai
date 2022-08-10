/// Ticker is a tick-based event system.

/*
   Usage:
      some_events: Tick_Event_Handler;

   Events are added to the system via the
   'register_event' procedure.
   
      register_event(*some_events, (tick: Tick, data: *void) -> bool {
         // ...
      });

   The following parameters can be given:
      - tick_rate: How often the event should be fired
      - event_proc: A procedure for the event
         This procedure needs 2 parameters:
            - tick: The current tick this event fired on
            - data: Data the event can use
         The procedure returns a boolean where:
            - true means to unregister the event from the system
            - false means the event is still active
      - event_data: A pointer to user data given to 'event_proc'
      - clean_proc: A procedure that'll fire when the event is unregistered
         This procedure has an almost identical signature to 'event_proc',
         the only difference is that it doesn't return a boolean.
      - clean_data: A pointer to user data given to 'clean_proc'

   Once events are registered, the tick loop can be executed with the 
   'do_event_tick' procedure.

      do_event_tick(*some_events, frame_delta);

   This is typically called in an update loop (hence the delta parameter),
   however, it has a default value so ticks can be executed on their own.

   To change the duration of a tick (outside of when it's called),
   a timescale can be set/reset using 'set_timescale' and 'reset_timescale'.

   Tick rates can have decimals (ie. a tick rate of 3.5 means every three and a half ticks).
   Because of this, the tick given in the event's procedure might not be what you expected.
   To fix this, 'round' can be used to normalize the tick so you don't have to deal with
   float precision (as much). This is also helpful for displaying the tick. You can also 
   use formatFloat.
*/

Tick :: #type f64;

Tick_Event_Proc   :: #type (current_tick: Tick, data: *void) -> (remove_after: bool);
Tick_Cleanup_Proc :: #type (ending_tick: Tick,  data: *void);

Tick_Event_Handler :: struct(MAX_TICK := 100, TIME_SCALE := 1.0) {
   tick: Tick;
   events: [..]Tick_Data;
   scale := TIME_SCALE;
}

Tick_Data :: struct {
   tick_rate:  Tick;
   event_proc: Tick_Event_Proc;
   event_data: *void;
   clean_proc: Tick_Cleanup_Proc;
   clean_data: *void;
   counter:    Tick;
}

register_event :: (
   using handler: *Tick_Event_Handler,
   tick_rate:  Tick,
   event_proc: Tick_Event_Proc,
   event_data: *void = null,
   clean_proc: Tick_Cleanup_Proc = null,
   clean_data: *void = null
) {
   assert(tick_rate < MAX_TICK, "Tick rate % is larger than the maximum of %", tick_rate, MAX_TICK);

   event := array_add(*events);
   event.tick_rate  = tick_rate;
   event.event_proc = event_proc;
   event.event_data = event_data;
   event.clean_proc = clean_proc;
   event.clean_data = clean_data;
}

set_timescale :: (using handler: *Tick_Event_Handler, timescale: float) {
   scale = timescale;
}

reset_timescale :: (using handler: *Tick_Event_Handler) {
   scale = TIME_SCALE;
}

do_event_tick :: (using handler: *Tick_Event_Handler, dt: float64 = 1.0) {
   tick += 1 * scale * dt;

   event_id := 0;
   while event_id < events.count {
      event    := *events[event_id];
      do_event := false;

      if event.counter >= event.tick_rate {
         do_event = true;
         event.counter = 0;
      }
      else {
         event.counter += 1 * scale * dt;
      }
      
      if do_event {
         needs_removal := event.event_proc(tick, event.event_data);
         if needs_removal {
            if event.clean_proc {
               event.clean_proc(tick, event.clean_data);
            }

            array_unordered_remove_by_index(*events, event_id);
            continue;
         }
      }

      event_id += 1;
   }

   if tick >= MAX_TICK then tick = 0;
}

round :: inline (tick: Tick) -> Tick {
   return xx libc_trunc(xx tick * 4.0) / 4.0;
}


#scope_file;

libc_trunc :: (value: float32) -> float32 #foreign libc_math "truncf";
libc_math  :: #foreign_system_library "libc";

