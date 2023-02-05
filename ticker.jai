/// A tick-based event system

/*
   Usage:
      some_events: Event_Handler;

   Events are added to the system via the 'register_event' procedure.

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

   Once events are registered, the tick loop can be executed with the
   'do_event_tick' procedure.

      do_event_tick(*some_events, frame_delta);

   This is typically called in an update loop (hence the delta parameter),
   however, it has a default value so ticks can be executed on their own.

   To change the duration of a tick, simply scale the dt parameter given to 'do_event_tick'.

   To change the tickrate of an event, 'set_tickrate' must be called on the return value of
   'register_event', manually setting the 'tick_rate' member could cause desyncs.

   Tick rates can have decimals (ie. a tick rate of 3.5 means every three and a half ticks).
   Because of this, the tick given in the event's procedure might not be what you expected.
   To fix this, 'round' can be used to normalize the tick so you don't have to deal with
   float precision (as much). This is also helpful for displaying the tick. You can also
   use formatFloat.
*/

Tick         :: #type float64;
Event_Proc   :: #type (current_tick: Tick, data: *void) -> (remove_after_fire: bool);
Cleanup_Proc :: #type (ending_tick: Tick,  data: *void);

Event_Handler :: struct(MAX_TICK := 100) {
   tick:   Tick;
   events: [..]Event_Data;
}

Event :: struct {
   cleaned:   bool;
   tick_rate: Tick;
   last_tick: Tick;
}

register_event :: (
   using handler: *Event_Handler,
   tick_rate:  Tick,
   event_proc: Event_Proc,
   event_data: *void = null,
   clean_proc: Cleanup_Proc = null
) -> *Event {
   assert(tick_rate <= MAX_TICK, "Tick rate % is larger than the maximum of %", tick_rate, MAX_TICK);

   event := array_add(*events);
   event.cleaned    = false;
   event.last_tick  = 0;
   event.tick_rate  = tick_rate;
   event.event_proc = event_proc;
   event.event_data = event_data;
   event.clean_proc = clean_proc;

   return *event.info;
}

/// 'do_event_tick' processes one tick within the system.
do_event_tick :: (using handler: *Event_Handler, dt: float64 = 1.0) -> Tick {
   tick += 1 * dt;

   for * event: events if !event.cleaned {
      diff := tick - event.last_tick;
      if diff >= event.tick_rate {
         needs_removal := event.event_proc(tick, event.event_data);
         if needs_removal {
            if event.clean_proc {
               event.clean_proc(tick, event.event_data);
            }

            event.cleaned   = true;
            event.last_tick = tick;
            continue;
         }

         event.last_tick = tick - abs(diff - event.tick_rate);
      }
   }

   tick_ran := tick;
   if tick > MAX_TICK {
      tick = 0;
      // @Todo(Judah): Can this be done in the above loop automatically?
      for * events if !it.cleaned then it.last_tick = 0;
   }

   return tick_ran;
}

/// 'set_tickrate' allows the tickrate for an event to be modified.
/// Note: this must be called rather than modifying the 'tick_rate'
/// member manually, as that may cause de-synced event firing.
set_tickrate :: (event: *Event, rate: Tick) {
   internal := get_interal(event);
   internal.tick_rate = rate;
   internal.last_tick = 0;
}

/// 'reset_event' re-enables an event within the system. Note,
/// because an event only disables after the cleanup procedure
/// has been called, this procedure allows the passing in of
/// new event data pointer.
reset_event :: (event: *Event, event_data: *void = null) {
   internal := get_interal(event);
   internal.cleaned   = false;
   internal.last_tick = 0;

   if event_data {
      internal.event_data = event_data;
   }
}

round :: inline (tick: Tick) -> Tick {
   return xx libc_trunc(xx tick * 4.0) / 4.0;
}


#scope_file

Event_Data :: struct {
   event_proc: Event_Proc;
   event_data: *void;
   clean_proc: Cleanup_Proc;
   using info: Event;
}

get_interal :: (event: *Event) -> *Event_Data #expand {
   return cast(*Event_Data)(cast(u64)event - #run (size_of(Event_Data) - size_of(Event)));
}

libc_trunc :: (value: float32) -> float32 #foreign libc_math "truncf";
libc_math  :: #system_library "libc";

#import "Math";
