for (chunk.blocks, 0..) |id, i| {
        if (id == 0)
            continue;

        const y: i32 = @intCast(i % 128);
        const z: i32 = @intCast(i / 128 % 16);
        const x: i32 = @intCast(i / (128 * 16));
        const block = coord.Block{ .x = x, .y = y, .z = z };

        // Get vertices of face using block coords
        const a = getVertexIndexFromBlockCoords(block, true, false, false);
        const b = getVertexIndexFromBlockCoords(block, true, false, true);
        const c = getVertexIndexFromBlockCoords(block, true, true, false);
        const d = getVertexIndexFromBlockCoords(block, true, true, true);

        // Add the two triangles
        try indices.appendSlice(rl.mem, &.{
            // Triangle 1
            a,
            b,
            d,
            // Triangle 2
            a,
            d,
            c,
        });

        try normals.appendSlice(rl.mem, &.{
            // Triangle 1
            0,
            1,
            0,
            // Triangle 2
            0,
            1,
            0,
        });

        try texcoords.appendNTimes(rl.mem, 0.0, 6);

        try colors.appendSlice(rl.mem, &.{ 255, 0, 0, 255 });
        try colors.appendSlice(rl.mem, &.{ 0, 255, 0, 255 });
        try colors.appendSlice(rl.mem, &.{ 0, 0, 255, 255 });
        try colors.appendSlice(rl.mem, &.{ 255, 255, 0, 255 });
        try colors.appendSlice(rl.mem, &.{ 255, 0, 255, 255 });
        try colors.appendSlice(rl.mem, &.{ 0, 255, 255, 255 });
    }