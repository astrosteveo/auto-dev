# Proposed Fix: Refactor apply_component() to Hydrator Registry

## Problem

`World::apply_component()` in `engine/src/ecs/world.cpp` (lines 82-204) is a 122-line hardcoded if/else chain dispatching on component name strings. Adding a new component requires manually adding a branch. This does not scale and conflicts with the project's data-driven, "everything is a mod" philosophy.

## Solution: Component Hydrator Registry

Replace the if/else chain with a map of named hydrator functions registered at initialization.

### Changes to `engine/include/wt/ecs/world.h`

Add the hydrator type and registry:

```cpp
#pragma once
#include "flecs.h"
#include <nlohmann/json.hpp>
#include <functional>
#include <string>
#include <unordered_map>

namespace wt {

class DataRegistry;

/// A hydrator deserializes JSON data into a specific component type
/// and sets it on the given entity.
using ComponentHydrator = std::function<void(flecs::entity&, const nlohmann::json&)>;

class World {
public:
    World();
    ~World();

    bool init();

    void register_component(const std::string& name, const nlohmann::json& schema);

    /// Register a hydrator for a component type. This both registers the
    /// component with Flecs and stores the JSON->component deserializer.
    /// Can be called by mods to add custom component types.
    template<typename T>
    void register_hydrator(const std::string& name, ComponentHydrator hydrator);

    flecs::entity create_entity(const std::string& template_name, const DataRegistry& registry);
    flecs::entity create_entity();

    template<typename... Components, typename Func>
    void register_system(const std::string& name, flecs::entity_t phase, Func&& func);

    bool progress(float delta_time = 0.0f);

    flecs::world& raw();
    const flecs::world& raw() const;

    void shutdown();

private:
    void apply_component(flecs::entity& entity, const std::string& name,
                         const nlohmann::json& data);

    flecs::world world_;
    std::unordered_map<std::string, ComponentHydrator> hydrators_;
    std::unordered_map<std::string, nlohmann::json> schema_map_;
    bool initialized_ = false;
};

// Template implementations
template<typename T>
void World::register_hydrator(const std::string& name, ComponentHydrator hydrator) {
    world_.component<T>();
    hydrators_[name] = std::move(hydrator);
}

template<typename... Components, typename Func>
void World::register_system(const std::string& name, flecs::entity_t phase, Func&& func) {
    world_.system<Components...>(name.c_str())
        .kind(phase)
        .each(std::forward<Func>(func));
}

} // namespace wt
```

### Changes to `engine/src/ecs/world.cpp`

Replace the `init()` function body to register hydrators instead of just calling `world_.component<T>()`, and replace the `apply_component()` body with a lookup:

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

    // Register hydrators for all core component types.
    // Each hydrator both registers the C++ type with Flecs and provides
    // the JSON -> component deserialization logic.

    register_hydrator<components::Position>("position",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::Position pos;
            if (data.contains("x")) pos.x = data["x"].get<float>();
            if (data.contains("y")) pos.y = data["y"].get<float>();
            e.set(pos);
        });

    register_hydrator<components::Movement>("movement",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::Movement mov;
            if (data.contains("speed")) mov.speed = data["speed"].get<float>();
            e.set(mov);
        });

    register_hydrator<components::Renderable>("renderable",
        [](flecs::entity& e, const nlohmann::json& data) {
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
            e.set(ren);
        });

    register_hydrator<components::AgentInfo>("agent_info",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::AgentInfo info;
            if (data.contains("species")) info.species = data["species"].get<std::string>();
            if (data.contains("name")) info.name = data["name"].get<std::string>();
            if (data.contains("age_ticks")) info.age_ticks = data["age_ticks"].get<int>();
            if (data.contains("max_age_ticks"))
                info.max_age_ticks = data["max_age_ticks"].get<int>();
            e.set(info);
        });

    register_hydrator<components::Needs>("needs",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::Needs needs;
            for (auto& [key, val] : data.items()) {
                if (val.is_number()) {
                    needs.set(key, val.get<float>());
                }
            }
            e.set(needs);
        });

    register_hydrator<components::Personality>("personality",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::Personality pers;
            if (data.contains("trait_ids") && data["trait_ids"].is_array()) {
                for (const auto& t : data["trait_ids"]) {
                    pers.trait_ids.push_back(t.get<std::string>());
                }
            }
            e.set(pers);
        });

    register_hydrator<components::Inventory>("inventory",
        [](flecs::entity& e, const nlohmann::json& data) {
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
            e.set(inv);
        });

    register_hydrator<components::Memory>("memory",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::Memory mem;
            if (data.contains("max_entries"))
                mem.max_entries = data["max_entries"].get<int>();
            e.set(mem);
        });

    register_hydrator<components::Relationships>("relationships",
        [](flecs::entity& e, const nlohmann::json& /*data*/) {
            components::Relationships rel;
            e.set(rel);
        });

    register_hydrator<components::AIState>("ai_state",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::AIState ai;
            if (data.contains("current_action"))
                ai.current_action = data["current_action"].get<std::string>();
            if (data.contains("idle")) ai.idle = data["idle"].get<bool>();
            e.set(ai);
        });

    register_hydrator<components::ResourceNode>("resource_node",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::ResourceNode res;
            if (data.contains("resource_type"))
                res.resource_type = data["resource_type"].get<std::string>();
            if (data.contains("quantity")) res.quantity = data["quantity"].get<int>();
            if (data.contains("max_quantity"))
                res.max_quantity = data["max_quantity"].get<int>();
            if (data.contains("regen_rate"))
                res.regen_rate = data["regen_rate"].get<float>();
            e.set(res);
        });

    register_hydrator<components::TerrainInfo>("terrain_info",
        [](flecs::entity& e, const nlohmann::json& data) {
            components::TerrainInfo ter;
            if (data.contains("terrain_id"))
                ter.terrain_id = data["terrain_id"].get<std::string>();
            e.set(ter);
        });

    initialized_ = true;
    spdlog::info("ECS World initialized with {} component hydrators", hydrators_.size());
    return true;
}

// ... (register_component, create_entity methods unchanged) ...

void World::apply_component(flecs::entity& entity, const std::string& name,
                            const nlohmann::json& data) {
    auto it = hydrators_.find(name);
    if (it != hydrators_.end()) {
        it->second(entity, data);
    } else {
        spdlog::warn("Unknown component '{}' in entity template, skipping", name);
    }
}

// ... (progress, raw, shutdown unchanged) ...

} // namespace wt
```

### What Changes

| Aspect | Before | After |
|--------|--------|-------|
| `apply_component()` body | 122 lines, 12 if/else branches | 6 lines, map lookup |
| Adding a new component | Edit 3 places (components.h, init(), apply_component()) | Edit 2 places (components.h, init() -- hydrator is inline) |
| Mod-defined components | Impossible | Possible via public `register_hydrator()` |
| `component_map_` member | Populated but unused | Removed (replaced by `hydrators_`) |
| Runtime behavior | Identical | Identical (same deserialization logic) |

### Files Affected
- `engine/include/wt/ecs/world.h` -- add `ComponentHydrator` alias, `hydrators_` member, `register_hydrator()` template method; remove `component_map_`
- `engine/src/ecs/world.cpp` -- restructure `init()` to use `register_hydrator()`, simplify `apply_component()` to lookup; remove `component_map_` usage in `register_component()` and `shutdown()`

### Risk Assessment
- **Low risk**: This is a mechanical refactoring. Each hydrator lambda contains the exact same code from the if/else branch. No logic changes.
- **Test coverage**: 38 existing tests (179 assertions) cover entity creation paths and component behavior. These would catch regressions.
- **Performance**: `apply_component()` is called during entity creation only (not per-frame). The `unordered_map` lookup is O(1) vs the worst-case O(12) string comparisons in the if/else chain -- slightly better or equivalent.

### Future Extensions
Once the hydrator registry is in place:
1. **Mod-registered components**: Lua mods could call `register_hydrator()` to define custom component types that store data in a generic `ModComponent` struct or Flecs `std::any` tag.
2. **Schema validation**: The existing `schema_map_` could be used to validate JSON data before passing it to the hydrator, providing better error messages for malformed templates.
3. **Automatic serialization**: A companion "dehydrator" registry could serialize components back to JSON, enabling the planned save/load system.
