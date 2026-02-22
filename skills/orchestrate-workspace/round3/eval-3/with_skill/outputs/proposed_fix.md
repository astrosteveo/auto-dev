# Proposed Fix: Replace Hardcoded `apply_component()` Chain with Registration-Based Dispatch

## Problem

`World::apply_component()` in `engine/src/ecs/world.cpp:82-205` is a 120-line if/else chain mapping 12 string names to hardcoded C++ deserialization logic. Every new component type requires:

1. Adding a new `else if` branch to `apply_component()`
2. Recompiling `world.cpp`
3. Manually keeping the string dispatch in sync with `components.h`

This is called out as a known issue in PROGRESS.md: *"`World::apply_component()` in `world.cpp:83-204` is a hardcoded if/else chain that won't scale with new component types."*

The project's mod system already registers component schemas via `world.register_component(name, schema)` and stores them in `schema_map_`, but that data is never actually used during entity hydration. The if/else chain duplicates information that already exists in the schema files under `data/base/components/`.

## Design Goals

1. **Eliminate the if/else chain** -- one registration call per component type, with deserialization logic co-located with the component definition.
2. **Keep compile-time type safety** -- the C++ struct types and their Flecs registration remain statically typed. We are not proposing a fully dynamic/runtime component system (that would be a much larger effort requiring Flecs reflection APIs).
3. **Make adding a new component a single-point change** -- register it in `init()` with its deserializer, and the template hydration works automatically.
4. **Zero runtime overhead** -- `std::unordered_map` lookup replaces the if/else chain with identical or better performance (O(1) amortized vs O(n) worst-case).
5. **Backward compatible** -- entity template JSON format is unchanged. Mod JSON is unchanged. The `register_component(name, schema)` public API is preserved.

## Architecture

### Core Concept: Component Applicator Registry

Replace the monolithic `apply_component()` with a map of `std::function` applicators:

```
string name --> std::function<void(flecs::entity&, const json&)>
```

Each component type registers its own applicator -- a lambda that knows how to deserialize JSON into that specific C++ struct and call `entity.set()`. The `apply_component()` method becomes a simple map lookup + invoke.

### Files Changed

| File | Change |
|------|--------|
| `engine/include/wt/ecs/world.h` | Add `applicator_map_` member, add `register_applicator()` method |
| `engine/src/ecs/world.cpp` | Replace if/else chain with map lookup; move per-component logic into `init()` registrations |

No other files change. The public API is unchanged.

## Implementation

### world.h -- Add Applicator Infrastructure

```cpp
#pragma once
#include "flecs.h"
#include <nlohmann/json.hpp>
#include <functional>
#include <string>
#include <unordered_map>

namespace wt {

class DataRegistry; // forward declare

class World {
public:
    // Type alias for component applicator functions
    using ComponentApplicator = std::function<void(flecs::entity&, const nlohmann::json&)>;

    World();
    ~World();

    bool init();

    // Register a component type from a JSON schema (records name for template lookup)
    void register_component(const std::string& name, const nlohmann::json& schema);

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
    // Register an applicator function for a named component type.
    // Called during init() to wire up JSON -> C++ struct deserialization.
    void register_applicator(const std::string& name, ComponentApplicator applicator);

    // Apply component data from JSON onto an entity (now uses applicator_map_)
    void apply_component(flecs::entity& entity, const std::string& name,
                         const nlohmann::json& data);

    flecs::world world_;
    std::unordered_map<std::string, flecs::entity> component_map_;
    std::unordered_map<std::string, nlohmann::json> schema_map_;
    std::unordered_map<std::string, ComponentApplicator> applicator_map_;
    bool initialized_ = false;
};

// Template implementation (unchanged)
template<typename... Components, typename Func>
void World::register_system(const std::string& name, flecs::entity_t phase, Func&& func) {
    world_.system<Components...>(name.c_str())
        .kind(phase)
        .each(std::forward<Func>(func));
}

} // namespace wt
```

### world.cpp -- Full Replacement

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

void World::register_applicator(const std::string& name, ComponentApplicator applicator) {
    applicator_map_[name] = std::move(applicator);
    spdlog::debug("Registered component applicator: {}", name);
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

    // ------------------------------------------------------------------
    // Register component applicators: JSON -> C++ struct deserialization
    // ------------------------------------------------------------------
    // Each applicator is a self-contained lambda that knows how to read
    // its component's JSON format and call entity.set(). Adding a new
    // component type requires adding one register_applicator() call here
    // (alongside the world_.component<T>() call above).
    // ------------------------------------------------------------------

    // 1. Position
    register_applicator("position", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Position pos;
        if (data.contains("x")) pos.x = data["x"].get<float>();
        if (data.contains("y")) pos.y = data["y"].get<float>();
        entity.set(pos);
    });

    // 2. Movement
    register_applicator("movement", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Movement mov;
        if (data.contains("speed")) mov.speed = data["speed"].get<float>();
        entity.set(mov);
    });

    // 3. Renderable
    register_applicator("renderable", [](flecs::entity& entity, const nlohmann::json& data) {
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
    register_applicator("agent_info", [](flecs::entity& entity, const nlohmann::json& data) {
        components::AgentInfo info;
        if (data.contains("species")) info.species = data["species"].get<std::string>();
        if (data.contains("name")) info.name = data["name"].get<std::string>();
        if (data.contains("age_ticks")) info.age_ticks = data["age_ticks"].get<int>();
        if (data.contains("max_age_ticks"))
            info.max_age_ticks = data["max_age_ticks"].get<int>();
        entity.set(info);
    });

    // 5. Needs (dynamic map-based)
    register_applicator("needs", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Needs needs;
        for (auto& [key, val] : data.items()) {
            if (val.is_number()) {
                needs.set(key, val.get<float>());
            }
        }
        entity.set(needs);
    });

    // 6. Personality
    register_applicator("personality", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Personality pers;
        if (data.contains("trait_ids") && data["trait_ids"].is_array()) {
            for (const auto& t : data["trait_ids"]) {
                pers.trait_ids.push_back(t.get<std::string>());
            }
        }
        entity.set(pers);
    });

    // 7. Inventory
    register_applicator("inventory", [](flecs::entity& entity, const nlohmann::json& data) {
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
    register_applicator("memory", [](flecs::entity& entity, const nlohmann::json& data) {
        components::Memory mem;
        if (data.contains("max_entries"))
            mem.max_entries = data["max_entries"].get<int>();
        entity.set(mem);
    });

    // 9. Relationships
    register_applicator("relationships", [](flecs::entity& entity, const nlohmann::json& /*data*/) {
        components::Relationships rel;
        entity.set(rel);
    });

    // 10. AIState
    register_applicator("ai_state", [](flecs::entity& entity, const nlohmann::json& data) {
        components::AIState ai;
        if (data.contains("current_action"))
            ai.current_action = data["current_action"].get<std::string>();
        if (data.contains("idle")) ai.idle = data["idle"].get<bool>();
        entity.set(ai);
    });

    // 11. ResourceNode
    register_applicator("resource_node", [](flecs::entity& entity, const nlohmann::json& data) {
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
    register_applicator("terrain_info", [](flecs::entity& entity, const nlohmann::json& data) {
        components::TerrainInfo ter;
        if (data.contains("terrain_id"))
            ter.terrain_id = data["terrain_id"].get<std::string>();
        entity.set(ter);
    });

    initialized_ = true;
    spdlog::info("ECS World initialized with {} component applicators", applicator_map_.size());
    return true;
}

void World::register_component(const std::string& name, const nlohmann::json& schema) {
    auto entity = world_.entity(name.c_str());
    component_map_[name] = entity;
    schema_map_[name] = schema;
    spdlog::debug("Registered component schema: {}", name);
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
    auto it = applicator_map_.find(name);
    if (it != applicator_map_.end()) {
        it->second(entity, data);
    } else {
        spdlog::warn("Unknown component '{}' in entity template, skipping", name);
    }
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
    applicator_map_.clear();
    initialized_ = false;
    spdlog::info("ECS World shut down");
}

} // namespace wt
```

## What Changes and What Stays the Same

### Changed

| Aspect | Before | After |
|--------|--------|-------|
| `apply_component()` body | 120-line if/else chain | 6-line map lookup |
| Adding a new component | Edit `apply_component()` + `init()` | Edit `init()` only |
| Component deserialization location | Buried in if/else branches | Named, self-documenting lambdas in `init()` |
| `world.h` private members | 3 maps | 4 maps (+ `applicator_map_`) |
| `world.h` public types | None | `ComponentApplicator` type alias |
| `shutdown()` | Clears `component_map_` | Clears `component_map_` + `applicator_map_` |

### Unchanged

| Aspect | Detail |
|--------|--------|
| Entity template JSON format | Identical -- `{"components": {"position": {"x": 5}, ...}}` |
| Mod JSON schemas | Identical -- `data/base/components/*.json` |
| `register_component()` public API | Identical signature and behavior |
| `create_entity()` public API | Identical signature and behavior |
| Flecs component registration | Same `world_.component<T>()` calls |
| All other files | Zero changes outside `world.h` and `world.cpp` |
| Deserialization logic per component | Byte-for-byte identical -- just moved into lambdas |

## Why This Approach (and Not Alternatives)

### Alternative 1: Flecs Reflection / Meta API

Flecs has a reflection system (`flecs::meta`) that can describe component fields at runtime and supports automatic JSON deserialization. This would eliminate per-component deserialization code entirely.

**Why not:** The project uses C++20 with Flecs's C++ API. Flecs's meta reflection requires either C-style component descriptions or the experimental `FLECS_META` macros. Adopting it would require restructuring every component struct, changing the build setup, and creating a dependency on an experimental Flecs feature. The project has 12 components today -- the applicator map handles this cleanly. If the project grows to 50+ components, Flecs reflection becomes worth the migration cost. At 12, it is over-engineering.

### Alternative 2: nlohmann::json `from_json()` ADL

Define `from_json(const json&, Position&)` for each component, then use `data.get<Position>()`. This is idiomatic nlohmann/json.

**Why not in isolation:** This solves deserialization but not dispatch. You still need something to map the string `"position"` to `data.get<Position>()`. The applicator map is that dispatch layer. However, the two approaches compose well -- a future iteration could extract the lambda bodies into `from_json()` overloads:

```cpp
register_applicator("position", [](flecs::entity& e, const json& d) {
    e.set(d.get<components::Position>());
});
```

This is a natural next step but does not need to happen in this change.

### Alternative 3: Macro-Based Auto-Registration

Define a macro like `REGISTER_COMPONENT(Position, "position")` that generates both the Flecs registration and the applicator registration.

**Why not:** Macros add indirection and complexity. The project uses `-Werror` and values readability. With only 12 components, explicit registration is clearer and easier to debug. Macros become worthwhile at scale (30+ components); at 12, they reduce readability without meaningful benefit.

## Testing Strategy

The existing test suite (38 tests, 179 assertions) covers entity creation from templates indirectly through multiple subsystems. The refactoring preserves identical behavior, so all existing tests should pass without modification.

**Recommended additional test (new file: `tests/test_world.cpp`):**

```cpp
#include <catch2/catch_test_macros.hpp>
#include "wt/ecs/world.h"
#include "wt/ecs/components.h"
#include "wt/mod/data_registry.h"

TEST_CASE("World creates entity from template with all components", "[world]") {
    wt::World world;
    REQUIRE(world.init());

    wt::DataRegistry registry;
    nlohmann::json settler = {
        {"name", "test_settler"},
        {"components", {
            {"position", {{"x", 5.0f}, {"y", 10.0f}}},
            {"movement", {{"speed", 2.0f}}},
            {"renderable", {{"glyph", "@"}, {"fg", {255, 200, 100}}, {"layer", 2}}},
            {"agent_info", {{"species", "human"}, {"name", "Test"}}},
            {"needs", {{"hunger", 80.0f}, {"thirst", 70.0f}}},
            {"personality", {{"trait_ids", {"brave", "kind"}}}},
            {"inventory", {{"capacity", 15}}},
            {"memory", {{"max_entries", 50}}},
            {"relationships", nlohmann::json::object()},
            {"ai_state", {{"idle", true}}},
            {"resource_node", {{"resource_type", "wood"}, {"quantity", 25}}},
            {"terrain_info", {{"terrain_id", "grass"}}}
        }}
    };
    registry.set("entities", "test_settler", settler);

    auto entity = world.create_entity("test_settler", registry);
    REQUIRE(entity.is_valid());

    SECTION("Position is hydrated") {
        auto* pos = entity.get<wt::components::Position>();
        REQUIRE(pos != nullptr);
        CHECK(pos->x == 5.0f);
        CHECK(pos->y == 10.0f);
    }

    SECTION("Movement is hydrated") {
        auto* mov = entity.get<wt::components::Movement>();
        REQUIRE(mov != nullptr);
        CHECK(mov->speed == 2.0f);
    }

    SECTION("Renderable is hydrated") {
        auto* ren = entity.get<wt::components::Renderable>();
        REQUIRE(ren != nullptr);
        CHECK(ren->glyph == static_cast<uint16_t>('@'));
        CHECK(ren->fg_r == 255);
        CHECK(ren->fg_g == 200);
        CHECK(ren->fg_b == 100);
        CHECK(ren->layer == 2);
    }

    SECTION("AgentInfo is hydrated") {
        auto* info = entity.get<wt::components::AgentInfo>();
        REQUIRE(info != nullptr);
        CHECK(info->species == "human");
        CHECK(info->name == "Test");
    }

    SECTION("Needs is hydrated") {
        auto* needs = entity.get<wt::components::Needs>();
        REQUIRE(needs != nullptr);
        CHECK(needs->get("hunger") == 80.0f);
        CHECK(needs->get("thirst") == 70.0f);
    }

    SECTION("Personality is hydrated") {
        auto* pers = entity.get<wt::components::Personality>();
        REQUIRE(pers != nullptr);
        REQUIRE(pers->trait_ids.size() == 2);
        CHECK(pers->trait_ids[0] == "brave");
        CHECK(pers->trait_ids[1] == "kind");
    }

    SECTION("Inventory is hydrated") {
        auto* inv = entity.get<wt::components::Inventory>();
        REQUIRE(inv != nullptr);
        CHECK(inv->capacity == 15);
    }

    SECTION("Memory is hydrated") {
        auto* mem = entity.get<wt::components::Memory>();
        REQUIRE(mem != nullptr);
        CHECK(mem->max_entries == 50);
    }

    SECTION("Relationships is hydrated") {
        auto* rel = entity.get<wt::components::Relationships>();
        REQUIRE(rel != nullptr);
        CHECK(rel->bonds.empty());
    }

    SECTION("AIState is hydrated") {
        auto* ai = entity.get<wt::components::AIState>();
        REQUIRE(ai != nullptr);
        CHECK(ai->idle == true);
    }

    SECTION("ResourceNode is hydrated") {
        auto* res = entity.get<wt::components::ResourceNode>();
        REQUIRE(res != nullptr);
        CHECK(res->resource_type == "wood");
        CHECK(res->quantity == 25);
    }

    SECTION("TerrainInfo is hydrated") {
        auto* ter = entity.get<wt::components::TerrainInfo>();
        REQUIRE(ter != nullptr);
        CHECK(ter->terrain_id == "grass");
    }
}

TEST_CASE("World logs warning for unknown component", "[world]") {
    wt::World world;
    REQUIRE(world.init());

    wt::DataRegistry registry;
    nlohmann::json tmpl = {
        {"name", "test"},
        {"components", {
            {"nonexistent_component", {{"foo", "bar"}}}
        }}
    };
    registry.set("entities", "test", tmpl);

    // Should not crash, just log a warning
    auto entity = world.create_entity("test", registry);
    REQUIRE(entity.is_valid());
}
```

## Migration Steps

1. **Apply changes to `world.h`** -- add `ComponentApplicator` alias, `applicator_map_` member, and `register_applicator()` private method.
2. **Apply changes to `world.cpp`** -- move each if/else branch into a `register_applicator()` call in `init()`, replace `apply_component()` body with map lookup, clear `applicator_map_` in `shutdown()`.
3. **Build** -- `cmake --build build` with `-Werror` (the project uses this in Debug).
4. **Run existing tests** -- all 38 tests / 179 assertions should pass unchanged.
5. **Add `test_world.cpp`** -- optional but recommended to directly test the applicator dispatch.
6. **Remove the Known Issues entry** from PROGRESS.md.

## Future Extension: Mod-Provided Custom Components

The applicator map design opens a path toward mod-provided custom components without C++ changes. A future iteration could:

1. Extend `register_component()` to accept an optional applicator (or generate one from the schema).
2. Use the existing `schema_map_` field definitions (`type`, `default`) to auto-generate generic applicators for simple components (flat structs with string/int/float fields).
3. For complex components (nested structs, vectors, custom logic), keep explicit applicator registration.

This is not part of the current proposal but the architecture supports it cleanly.

## Summary

This is a mechanical refactoring -- zero behavioral changes, zero API changes, zero JSON format changes. The if/else chain becomes a map lookup. The deserialization logic moves from anonymous branches into named, self-documenting lambdas registered alongside their Flecs component types. The result is easier to extend, easier to read, and impossible to get out of sync (if you forget to register an applicator, you get a clear warning log instead of a silent skip buried in a 120-line chain).
