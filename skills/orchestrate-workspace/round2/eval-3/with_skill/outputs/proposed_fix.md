# Proposed Fix: Replace Hardcoded `apply_component()` Chain with Registration-Based Dispatch

## Problem

`World::apply_component()` in `engine/src/ecs/world.cpp:82-205` is a 120-line `if/else if` chain that dispatches JSON component data to the correct Flecs `entity.set<T>()` call based on string name matching. This is identified in PROGRESS.md's Known Issues section:

> `World::apply_component()` in `world.cpp:83-204` is a hardcoded if/else chain that won't scale with new component types

Every time a new component type is added to `components.h`, a developer must also add a corresponding branch to `apply_component()`. This violates the Open-Closed Principle and creates a maintenance burden that scales linearly with component count. It also contradicts the project's "everything is a mod" philosophy -- modders cannot define new component types without modifying engine C++ code.

## Current Code (Summary)

The 12 component types handled in the chain are:

| # | String Key | C++ Type | Lines |
|---|-----------|----------|-------|
| 1 | `"position"` | `components::Position` | 84-88 |
| 2 | `"movement"` | `components::Movement` | 90-93 |
| 3 | `"renderable"` | `components::Renderable` | 95-126 |
| 4 | `"agent_info"` | `components::AgentInfo` | 128-135 |
| 5 | `"needs"` | `components::Needs` | 137-144 |
| 6 | `"personality"` | `components::Personality` | 146-153 |
| 7 | `"inventory"` | `components::Inventory` | 155-166 |
| 8 | `"memory"` | `components::Memory` | 168-172 |
| 9 | `"relationships"` | `components::Relationships` | 174-176 |
| 10 | `"ai_state"` | `components::AIState` | 178-183 |
| 11 | `"resource_node"` | `components::ResourceNode` | 185-194 |
| 12 | `"terrain_info"` | `components::TerrainInfo` | 196-200 |

Each branch deserializes `nlohmann::json` into the appropriate struct and calls `entity.set<T>(value)`.

## Proposed Solution: Component Factory Registry

Replace the if/else chain with a `std::unordered_map` that maps string names to factory functions (type-erased callables). Each component type registers its own deserializer at initialization time. The `apply_component()` method becomes a simple table lookup.

### Design Goals

1. **Zero runtime cost increase** -- `std::unordered_map::find()` is O(1) amortized, same as the existing string comparison chain on average (actually faster for late-chain components like `terrain_info` which currently require 12 comparisons).
2. **Self-contained registration** -- each component's JSON deserialization logic lives with its registration, not in a monolithic function.
3. **Extensible** -- new components (including mod-defined ones, in the future) can register themselves without modifying `world.cpp`.
4. **No new dependencies** -- uses only `std::function`, `std::unordered_map`, and `nlohmann::json`, all already in the project.
5. **C++20 compatible** -- the project uses C++20 (`CMAKE_CXX_STANDARD 20`), so we can use designated initializers and other modern features.

### Architecture

```
World
  +-- component_factories_: unordered_map<string, ComponentFactory>
  |     "position"       -> [](entity, json) { ... entity.set(Position{...}); }
  |     "movement"       -> [](entity, json) { ... entity.set(Movement{...}); }
  |     "renderable"     -> [](entity, json) { ... entity.set(Renderable{...}); }
  |     ... (12 entries, extensible)
  |
  +-- register_component_factory(name, factory)   // public API
  +-- register_core_factories()                    // called from init()
  +-- apply_component(entity, name, data)          // now a 3-line lookup
```

## Proposed Code Changes

### File: `engine/include/wt/ecs/world.h`

```cpp
#pragma once
#include "flecs.h"
#include <nlohmann/json.hpp>
#include <functional>
#include <string>
#include <unordered_map>

namespace wt {

class DataRegistry; // forward declare

// Type alias for component factory functions.
// A factory takes a mutable entity reference and JSON data, and applies
// the deserialized component to the entity.
using ComponentFactory = std::function<void(flecs::entity&, const nlohmann::json&)>;

class World {
public:
    World();
    ~World();

    bool init();

    // Register a component type from a JSON schema (records name for template lookup)
    void register_component(const std::string& name, const nlohmann::json& schema);

    // Register a component factory for JSON -> ECS deserialization.
    // This is the extension point: call this to teach the world how to
    // deserialize a new component type from JSON entity templates.
    void register_component_factory(const std::string& name, ComponentFactory factory);

    // Create an entity from a data registry template
    flecs::entity create_entity(const std::string& template_name, const DataRegistry& registry);

    // Create a plain entity
    flecs::entity create_entity();

    // Register a system in the pipeline
    template<typename... Components, typename Func>
    void register_system(const std::string& name, flecs::entity_t phase, Func&& func);

    // Advance the world by one tick
    bool progress(float delta_time = 0.0f);

    // Access the raw Flecs world
    flecs::world& raw();
    const flecs::world& raw() const;

    void shutdown();

private:
    // Apply component data from JSON onto an entity (now dispatches via factory map)
    void apply_component(flecs::entity& entity, const std::string& name,
                         const nlohmann::json& data);

    // Register the 12 built-in component factories
    void register_core_factories();

    flecs::world world_;
    std::unordered_map<std::string, flecs::entity> component_map_;
    std::unordered_map<std::string, nlohmann::json> schema_map_;
    std::unordered_map<std::string, ComponentFactory> component_factories_;
    bool initialized_ = false;
};

// Template implementation
template<typename... Components, typename Func>
void World::register_system(const std::string& name, flecs::entity_t phase, Func&& func) {
    world_.system<Components...>(name.c_str())
        .kind(phase)
        .each(std::forward<Func>(func));
}

} // namespace wt
```

**Changes from current `world.h`:**
- Added `#include <functional>` for `std::function`.
- Added `ComponentFactory` type alias.
- Added `register_component_factory()` public method.
- Added `register_core_factories()` private method.
- Added `component_factories_` member map.
- `apply_component()` is unchanged in signature (still private, same params).

### File: `engine/src/ecs/world.cpp`

```cpp
#include "wt/ecs/world.h"
#include "wt/ecs/components.h"
#include "wt/mod/data_registry.h"
#include <spdlog/spdlog.h>

namespace wt {

World::World() = default;

World::~World() {
    if (initialized_) {
        shutdown();
    }
}

bool World::init() {
    if (initialized_) {
        spdlog::warn("World::init called on already-initialized world");
        return true;
    }

    // Register all core component types with Flecs
    world_.component<components::Position>();
    world_.component<components::Movement>();
    world_.component<components::Renderable>();
    world_.component<components::AgentInfo>();
    world_.component<components::Needs>();
    world_.component<components::Personality>();
    world_.component<components::Inventory>();
    world_.component<components::Memory>();
    world_.component<components::Relationships>();
    world_.component<components::AIState>();
    world_.component<components::ResourceNode>();
    world_.component<components::TerrainInfo>();

    // Register JSON -> component deserialization factories for all core types
    register_core_factories();

    initialized_ = true;
    spdlog::info("ECS World initialized with core components");
    return true;
}

void World::register_component(const std::string& name, const nlohmann::json& schema) {
    auto entity = world_.entity(name.c_str());
    component_map_[name] = entity;
    schema_map_[name] = schema;
    spdlog::debug("Registered component schema: {}", name);
}

void World::register_component_factory(const std::string& name, ComponentFactory factory) {
    if (component_factories_.contains(name)) {
        spdlog::warn("Overwriting component factory for '{}'", name);
    }
    component_factories_[name] = std::move(factory);
    spdlog::debug("Registered component factory: {}", name);
}

flecs::entity World::create_entity() {
    return world_.entity();
}

flecs::entity World::create_entity(const std::string& template_name,
                                   const DataRegistry& registry) {
    auto tmpl = registry.get("entities", template_name);
    if (!tmpl.has_value()) {
        spdlog::error("Entity template '{}' not found in registry", template_name);
        return world_.entity();
    }

    const auto& data = tmpl.value();
    auto entity = world_.entity();

    // Apply each component listed in the template
    if (data.contains("components") && data["components"].is_object()) {
        for (auto& [comp_name, comp_data] : data["components"].items()) {
            apply_component(entity, comp_name, comp_data);
        }
    }

    spdlog::debug("Created entity from template '{}'", template_name);
    return entity;
}

void World::apply_component(flecs::entity& entity, const std::string& name,
                            const nlohmann::json& data) {
    auto it = component_factories_.find(name);
    if (it != component_factories_.end()) {
        it->second(entity, data);
    } else {
        spdlog::warn("Unknown component '{}' in entity template, skipping", name);
    }
}

void World::register_core_factories() {
    // 1. Position
    register_component_factory("position", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Position pos;
        if (data.contains("x")) pos.x = data["x"].get<float>();
        if (data.contains("y")) pos.y = data["y"].get<float>();
        entity.set(pos);
    });

    // 2. Movement
    register_component_factory("movement", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Movement mov;
        if (data.contains("speed")) mov.speed = data["speed"].get<float>();
        entity.set(mov);
    });

    // 3. Renderable
    register_component_factory("renderable", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Renderable ren;
        if (data.contains("glyph")) {
            auto& g = data["glyph"];
            if (g.is_string()) {
                auto s = g.get<std::string>();
                if (!s.empty()) ren.glyph = static_cast<uint16_t>(s[0]);
            } else if (g.is_number()) {
                ren.glyph = g.get<uint16_t>();
            }
        }
        // Support both "fg": [r,g,b] array format and "fg_r"/"fg_g"/"fg_b" individual fields
        if (data.contains("fg") && data["fg"].is_array() && data["fg"].size() >= 3) {
            ren.fg_r = data["fg"][0].get<uint8_t>();
            ren.fg_g = data["fg"][1].get<uint8_t>();
            ren.fg_b = data["fg"][2].get<uint8_t>();
        } else {
            if (data.contains("fg_r")) ren.fg_r = data["fg_r"].get<uint8_t>();
            if (data.contains("fg_g")) ren.fg_g = data["fg_g"].get<uint8_t>();
            if (data.contains("fg_b")) ren.fg_b = data["fg_b"].get<uint8_t>();
        }
        if (data.contains("bg") && data["bg"].is_array() && data["bg"].size() >= 3) {
            ren.bg_r = data["bg"][0].get<uint8_t>();
            ren.bg_g = data["bg"][1].get<uint8_t>();
            ren.bg_b = data["bg"][2].get<uint8_t>();
        } else {
            if (data.contains("bg_r")) ren.bg_r = data["bg_r"].get<uint8_t>();
            if (data.contains("bg_g")) ren.bg_g = data["bg_g"].get<uint8_t>();
            if (data.contains("bg_b")) ren.bg_b = data["bg_b"].get<uint8_t>();
        }
        if (data.contains("layer")) ren.layer = data["layer"].get<int>();
        entity.set(ren);
    });

    // 4. AgentInfo
    register_component_factory("agent_info", [](flecs::entity& entity, const nlohmann::json& data) {
        components::AgentInfo info;
        if (data.contains("species")) info.species = data["species"].get<std::string>();
        if (data.contains("name")) info.name = data["name"].get<std::string>();
        if (data.contains("age_ticks")) info.age_ticks = data["age_ticks"].get<int>();
        if (data.contains("max_age_ticks"))
            info.max_age_ticks = data["max_age_ticks"].get<int>();
        entity.set(info);
    });

    // 5. Needs
    register_component_factory("needs", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Needs needs;
        for (auto& [key, val] : data.items()) {
            if (val.is_number()) {
                needs.set(key, val.get<float>());
            }
        }
        entity.set(needs);
    });

    // 6. Personality
    register_component_factory("personality", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Personality pers;
        if (data.contains("trait_ids") && data["trait_ids"].is_array()) {
            for (const auto& t : data["trait_ids"]) {
                pers.trait_ids.push_back(t.get<std::string>());
            }
        }
        entity.set(pers);
    });

    // 7. Inventory
    register_component_factory("inventory", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Inventory inv;
        if (data.contains("capacity")) inv.capacity = data["capacity"].get<int>();
        if (data.contains("items") && data["items"].is_array()) {
            for (const auto& item : data["items"]) {
                components::Inventory::Item it;
                if (item.contains("id")) it.id = item["id"].get<std::string>();
                if (item.contains("quantity")) it.quantity = item["quantity"].get<int>();
                inv.items.push_back(std::move(it));
            }
        }
        entity.set(inv);
    });

    // 8. Memory
    register_component_factory("memory", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Memory mem;
        if (data.contains("max_entries"))
            mem.max_entries = data["max_entries"].get<int>();
        entity.set(mem);
    });

    // 9. Relationships
    register_component_factory("relationships", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Relationships rel;
        // Currently no JSON fields to deserialize; just attach the default component
        (void)data;
        entity.set(rel);
    });

    // 10. AIState
    register_component_factory("ai_state", [](flecs::entity& entity, const nlohmann::json& data) {
        components::AIState ai;
        if (data.contains("current_action"))
            ai.current_action = data["current_action"].get<std::string>();
        if (data.contains("idle")) ai.idle = data["idle"].get<bool>();
        entity.set(ai);
    });

    // 11. ResourceNode
    register_component_factory("resource_node", [](flecs::entity& entity, const nlohmann::json& data) {
        components::ResourceNode res;
        if (data.contains("resource_type"))
            res.resource_type = data["resource_type"].get<std::string>();
        if (data.contains("quantity")) res.quantity = data["quantity"].get<int>();
        if (data.contains("max_quantity"))
            res.max_quantity = data["max_quantity"].get<int>();
        if (data.contains("regen_rate"))
            res.regen_rate = data["regen_rate"].get<float>();
        entity.set(res);
    });

    // 12. TerrainInfo
    register_component_factory("terrain_info", [](flecs::entity& entity, const nlohmann::json& data) {
        components::TerrainInfo ter;
        if (data.contains("terrain_id"))
            ter.terrain_id = data["terrain_id"].get<std::string>();
        entity.set(ter);
    });

    spdlog::debug("Registered {} core component factories", component_factories_.size());
}

bool World::progress(float delta_time) {
    return world_.progress(delta_time);
}

flecs::world& World::raw() {
    return world_;
}

const flecs::world& World::raw() const {
    return world_;
}

void World::shutdown() {
    if (!initialized_) return;
    component_map_.clear();
    component_factories_.clear();
    initialized_ = false;
    spdlog::info("ECS World shut down");
}

} // namespace wt
```

## What Changed and Why

### 1. `apply_component()` -- from 120 lines to 6

**Before:**
```cpp
void World::apply_component(flecs::entity& entity, const std::string& name,
                            const nlohmann::json& data) {
    if (name == "position") {
        // ... 8 lines ...
    } else if (name == "movement") {
        // ... 6 lines ...
    } else if (name == "renderable") {
        // ... 34 lines ...
    }
    // ... 8 more branches ...
    else {
        spdlog::warn("Unknown component '{}' in entity template, skipping", name);
    }
}
```

**After:**
```cpp
void World::apply_component(flecs::entity& entity, const std::string& name,
                            const nlohmann::json& data) {
    auto it = component_factories_.find(name);
    if (it != component_factories_.end()) {
        it->second(entity, data);
    } else {
        spdlog::warn("Unknown component '{}' in entity template, skipping", name);
    }
}
```

The dispatch logic is now a hash map lookup. The deserialization logic for each component has not changed -- it has simply moved into lambda closures registered in `register_core_factories()`.

### 2. New public API: `register_component_factory()`

```cpp
void register_component_factory(const std::string& name, ComponentFactory factory);
```

This is the extension point. Future component types -- whether added to the engine or defined by mods via Lua/sol2 -- can register their deserializers at runtime without modifying `world.cpp`. For example, a future Lua-side mod could call:

```lua
-- Hypothetical future mod API
world.register_component_factory("custom_behavior", function(entity, data)
    ecs.set(entity, "custom_behavior", { mode = data.mode or "default" })
end)
```

### 3. `register_core_factories()` -- self-documenting initialization

Called from `init()` after Flecs component registration. All 12 built-in component factories are registered here, each as a clearly labeled block. Adding a 13th component means adding one `register_component_factory()` call -- no structural changes.

### 4. Behavioral parity

The deserialization logic inside each factory lambda is **byte-for-byte identical** to the original if/else branches. This is deliberate: the refactor changes structure, not behavior. Every JSON field, every type conversion, every default value is preserved. The `spdlog::warn` for unknown components is preserved. The iteration over template `"components"` in `create_entity()` is untouched.

## Risk Assessment

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| `std::function` overhead vs. direct calls | Low -- one virtual call per component per entity creation; entity creation is not a hot path | Profile if concerned; could use function pointers instead of `std::function` |
| Factory registration order matters | None -- map is unordered, lookup is by key | No action needed |
| Thread safety of factory map | Low -- map is populated in `init()` before any multithreaded access | Document that `register_component_factory()` should only be called during init |
| Regression in JSON parsing | Low -- logic is identical, just relocated | Existing 38 Catch2 tests cover entity creation paths |

## Testing Strategy

1. **Existing tests pass unchanged.** The 38 Catch2 tests (179 assertions) already exercise entity creation from JSON templates, which internally calls `apply_component()`. Since the deserialization logic is identical, all tests should pass without modification.

2. **Add a new test for factory extensibility.** Register a custom factory for a test-only component, create an entity from a template that includes it, and verify it was applied:

```cpp
TEST_CASE("Custom component factory registration", "[world]") {
    wt::World world;
    world.init();

    struct TestTag { int value = 0; };
    world.raw().component<TestTag>();

    world.register_component_factory("test_tag",
        [](flecs::entity& e, const nlohmann::json& data) {
            TestTag tag;
            if (data.contains("value")) tag.value = data["value"].get<int>();
            e.set(tag);
        });

    // Create entity manually and apply via the factory
    auto entity = world.create_entity();
    nlohmann::json data = {{"value", 42}};
    // Note: apply_component is private, so test via create_entity with a mock registry,
    // or make a public apply_component_for_test wrapper.
    // Alternative: test via the DataRegistry path with a synthetic template.
}
```

3. **Verify factory override warning.** Register a factory for "position" twice and check that spdlog emits the warning.

## Files Modified

| File | Change |
|------|--------|
| `engine/include/wt/ecs/world.h` | Add `ComponentFactory` alias, `register_component_factory()`, `register_core_factories()`, `component_factories_` member |
| `engine/src/ecs/world.cpp` | Replace `apply_component()` body with map lookup; add `register_component_factory()` and `register_core_factories()` implementations; clear factories in `shutdown()` |

No other files need changes. The `apply_component()` signature and visibility are unchanged, so all existing callers (only `create_entity()` within the same class) continue to work.

## Future Work

This refactor opens the door for:

1. **Lua-registered component factories** -- the `script_engine.cpp` sol2 bindings could expose `register_component_factory()` so mods can define entirely new component types in Lua without touching C++.
2. **Schema validation** -- the existing `schema_map_` could be wired into factory registration so that each factory validates its JSON input against a schema before deserializing.
3. **Component removal from templates** -- a factory could support a `"_remove": true` flag to strip a component during template application, useful for template inheritance/override patterns.
