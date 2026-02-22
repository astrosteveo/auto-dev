## PROGRESS.md (located at project root — move to .claude/PROGRESS.md for auto-injection)

# Project Progress

## Summary

Working Title is a Dwarf Fortress-inspired 2D life simulation engine built with C++20, Flecs ECS, SDL2, Lua/sol2, and nlohmann/json. Everything is data-driven and moddable — the base game ships as `data/base/`. The engine is past core infrastructure and into gameplay systems. Current focus: extending AI behavior with social memory. The main architectural concern is the hardcoded apply_component() chain in world.cpp.

## Architecture

```
engine/          Core systems (ECS, rendering, AI, pathfinding, events)
game/            Game loop, initialization
data/base/       Base mod (entities, actions, needs, traits, recipes)
tests/           Catch2 tests — 38 cases, 179 assertions, 9 files
```

12 component types, utility AI with consideration-based scoring, A* pathfinding, mod loader, event bus, Lua scripting bridge.

## In Progress

(none)

## Next Up

### Larger Features
1. **Social memory AI decisions** (I:3 U:4 E:3 = 2.33)
   Extend memory-informed AI to use social memory. `"social_memory"` consideration type: agents check Memory for `"social_interaction"` entries, recent positive interactions boost chat/share_food scoring for that agent, negative interactions reduce it. Recency-weighted like spatial memory.
   - Files: `utility_ai.cpp`, `social_system.cpp`, `data/base/actions/social_actions.json`
   - Depends on: memory-informed AI (completed)

### Deferred
2. **Building/placement system** (I:4 U:5 E:4 = 2.25)
   Placement mechanics, structure entity templates, tile modification. Multi-system effort.

3. **Save/load system** (I:3 U:4 E:4 = 1.75)
   Requires solving persistent entity ID problem first (Flecs runtime IDs need UUID component or mapping). Effectively blocked on an architectural decision.

## Known Issues

- `World::apply_component()` in world.cpp:83-204 is a hardcoded if/else chain dispatching 12 component types by string name. Won't scale with new component types. Needs registration-based dispatch.

## Completed

- Expanded test coverage (38 cases, 179 assertions, 9 subsystems)
- Memory-informed AI decisions (spatial memory consideration type)
- Entity selection/inspection UI (mouse input, tile inspection)
- Data-driven needs system (dynamic from mod data)
- Crafting system (recipe-based, data-driven)
- Death/lifecycle events
- Trait need_modifiers wiring
- Lua create_from_template stub
- Lua EventBus bridge (bidirectional)
- Duplicate entity name crash fix
- Social system (chat, share_food, social_interaction memories)
- Needs system (hunger, energy, social)
- Utility AI (consideration-based action scoring)
- A* pathfinding with tile costs
- Mod loader and data registry
- SDL2 renderer with tile map
- Flecs ECS integration
- Worldgen (perlin noise terrain)
- Event bus system
- Core engine loop

## Git State
Branch: master

### Recent commits
aed68ba Memory-informed AI decisions (spatial memory)
f3c2d91 Entity inspection / selection UI
b8e4a22 Data-driven needs (dynamic)
c71f3e8 Crafting system
d9a1b55 Mouse input + tile inspection
e4c8f67 Duplicate entity name crash fix
a2d7e89 Death/lifecycle events
b5f1c34 Trait need_modifiers wiring
c8e3a56 Lua create_from_template stub
d1f6b78 Lua EventBus bridge (bidirectional)

### Working tree
 M PROGRESS.md
 M tests/CMakeLists.txt
?? tests/test_clock.cpp
?? tests/test_data_registry.cpp
?? tests/test_pathfinding.cpp
?? tests/test_tile_map.cpp
?? tests/test_utility_ai.cpp

### Unstaged changes
 PROGRESS.md          | 8 +++--
 tests/CMakeLists.txt | 5 +++++
