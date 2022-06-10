# godot-colyseus

Colyseus SDK for GODOT.

Try the online mode of this demo: [https://gsioteam.github.io/ActionGame/](https://gsioteam.github.io/ActionGame/)

## Usage 

```py
var client = colyseus.Client.new("ws://localhost:2567")
var promise = client.join_or_create(RoomState, "state_handler")
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

## Documentation

Totaly the API is same as [colyseus.js](https://github.com/colyseus/colyseus.js).
There are only two points to note.

### Schema 

Define a schema class only needs to inherit `colyseus.Schema` 
and implement the `define_fields` method.

```py
class RoomState extends colyseus.Schema:
  static func define_fields():
    return [
      colyseus.Field.new("players", colyseus.MAP, Player),
    ]
```

Get players by `state.players`. And the collection classes are 
defined in `godot_colyseus/lib/collections.gd`.

### Event Listener

Using `listen` method to observe the change of attrbites.
The structure of first argument `path` is like this
`path/to/attribue:action`. The path part can be empty like
`:replace`, that means listening this node.

Actions:

| Action      | Description | Arguments   |
| ----------- | ----------- | ----------- |
| add | A subobject is created or added to this schema object. | _on_add(current: Schema, new_value: any, key: String) |
| remove | A subobject is removed from this schema object. | _on_remove(current: Schema, old_value: any, key: String) |
| replace | A attrbite or element of this schema object is replaced. | _on_replace(current: Schema, new_value: any, key: String) |
| delete | The schema object which at the path is deleted. | _on_deleted(current: Schema) |
| create | The schema object which at the path is created. | _on_created(current: Schema) |
| change | The schema object which at the path is changed. | _on_changed(current: Schema) |
| clear | The schema object which at the path is cleared. | _on_clear(current: Schema) |

