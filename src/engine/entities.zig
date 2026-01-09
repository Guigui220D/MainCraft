//! Root of the entities submodule

const std = @import("std");

pub const Entity = @import("entities/Entity.zig");
pub const EntityManager = @import("entities/EntityManager.zig");
pub const Types = @import("entities/entity_types.zig").EntityType;
pub const WatchableObject = @import("entities/WatchableObject.zig");
