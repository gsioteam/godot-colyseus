# godot-colyseus

Colyseus SDK for GODOT

## Usage 

```py
var client = colyseus.Client.new("ws://localhost:2567")
var promise = client.joinOrCreate(RoomState, "state_handler")
yield(promise, "completed")
if promise.get_state() == promise.State.Failed:
    print("Failed")
    return
var room: colyseus.Room = promise.get_result()
var state: RoomState = room.get_state()
state.listen('players:add').on(funcref(self, "_on_players_add"))
room.on_state_change.on(funcref(self, "_on_state"))
room.on_message("hello").on(funcref(self, "_on_message"))
```