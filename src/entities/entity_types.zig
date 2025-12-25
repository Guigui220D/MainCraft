pub const EntityType = enum(u8) {
    // TODO: the inanimate entities arent the same id group
    // Understand why tehre is a boat entity 41 and vehicle boat 1
    // Handle them differently
    item = 1,
    painting = 9,
    arrow = 10,
    snowball = 11,
    primed_tnt = 20,
    falling_sand = 21,
    minecart = 40,
    boat = 41,
    mob = 48,
    monster = 49,
    creeper = 50,
    skeleton = 51,
    giant = 53,
    zombie = 54,
    slime = 55,
    ghast = 56,
    pig_zombie = 57,
    pig = 90,
    sheep = 91,
    cow = 92,
    chicken = 93,
    squid = 94,
    wolf = 95,

    // Added by the client (not used in the original game)
    player = 255,

    _,
};
