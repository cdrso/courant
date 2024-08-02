const std = @import("std");

const MshElementType = enum(u8) {
    line_2 = 1,
    triangle_3 = 2,
    quadrangle_4 = 3,
};

const MshError = error{ InvalidFile, MissingValue, InvalidFormat, InvalidNodeTag, IncorrectNodeCount, InvalidElementType, InvalidElementTag, IncorrectElementCount };

const Node = struct { x: f64, y: f64, z: f64 };
// Saving an array of nodes inside the struct doesnt seem really data oriented...
// also its not even an array, its a pointer to the array wich is heap allocated, pretty bad.
// try to think of this in another way, this is object oriented slop
const Element = struct { element_type: MshElementType, nodes: []u32 };

const BUFFER_SIZE = 2 << 10;

/// Parses the nodes section of a .msh file
fn parseNodes(allocator: std.mem.Allocator, reader: anytype) ![]Node {
    // data should be processed while read, reading the whole section and then processing it seems pretty bad
    // also content is a dynamic array so even worse
    const content = try readSection(allocator, reader, "$Nodes", "$EndNodes");
    defer allocator.free(content);

    var it = std.mem.tokenizeScalar(u8, content, ' ');

    const numEntityBlocks = try parseNextUsize(&it);
    const numNodes = try parseNextUsize(&it);
    const minNodeTag = try parseNextUsize(&it);
    const maxNodeTag = try parseNextUsize(&it);

    var nodeArr = try allocator.alloc(Node, maxNodeTag + 1);
    errdefer allocator.free(nodeArr);

    var nodesProcessed: usize = 0;
    for (0..numEntityBlocks) |_| {
        _ = try parseNextUsize(&it); // entityDim
        _ = try parseNextUsize(&it); // entityTag
        _ = try parseNextUsize(&it); // parametric
        const numNodesInBlock = try parseNextUsize(&it);

        for (0..numNodesInBlock) |_| {
            const nodeTag = try parseNextUsize(&it);
            const x = try parseNextDouble(&it);
            const y = try parseNextDouble(&it);
            const z = try parseNextDouble(&it);

            if (nodeTag < minNodeTag or nodeTag > maxNodeTag) return MshError.InvalidNodeTag;
            nodeArr[nodeTag] = Node{ .x = x, .y = y, .z = z };
            nodesProcessed += 1;
        }
    }

    if (nodesProcessed != numNodes) return MshError.IncorrectNodeCount;

    return nodeArr;
}

// Same notes apply as before
fn parseElements(allocator: std.mem.Allocator, reader: anytype) ![]?Element {
    const content = try readSection(allocator, reader, "$Elements", "$EndElements");
    defer allocator.free(content);

    var it = std.mem.tokenizeScalar(u8, content, ' ');

    const numEntityBlocks = try parseNextUsize(&it);
    const numElements = try parseNextUsize(&it);
    const minElementTag = try parseNextUsize(&it);
    const maxElementTag = try parseNextUsize(&it);

    var elementArr = try allocator.alloc(?Element, maxElementTag + 1);
    errdefer allocator.free(elementArr);
    @memset(elementArr, null);

    var elementsProcessed: usize = 0;
    for (0..numEntityBlocks) |_| {
        _ = try parseNextInt(&it); // entityDim
        _ = try parseNextInt(&it); // entityTag
        const elementType = try parseElementType(&it);
        const numElementsInBlock = try parseNextUsize(&it);

        for (0..numElementsInBlock) |_| {
            const elementTag = try parseNextUsize(&it);
            if (elementTag < minElementTag or elementTag > maxElementTag) {
                return MshError.InvalidElementTag;
            }

            var nodes: []u32 = undefined;
            switch (elementType) {
                .line_2 => {
                    nodes = try allocator.alloc(u32, 2);
                    for (0..2) |i| nodes[i] = try parseNextInt(&it);
                },
                .triangle_3 => {
                    nodes = try allocator.alloc(u32, 3);
                    for (0..3) |i| nodes[i] = try parseNextInt(&it);
                },
                .quadrangle_4 => {
                    nodes = try allocator.alloc(u32, 4);
                    for (0..4) |i| nodes[i] = try parseNextInt(&it);
                },
            }
            errdefer allocator.free(nodes);

            elementArr[elementTag] = Element{
                .element_type = elementType,
                .nodes = nodes,
            };
            elementsProcessed += 1;
        }
    }

    if (elementsProcessed != numElements) return MshError.IncorrectElementCount;

    return elementArr;
}

// Trash
fn readSection(allocator: std.mem.Allocator, reader: anytype, startMarker: []const u8, endMarker: []const u8) ![]u8 {
    var content = std.ArrayList(u8).init(allocator);
    errdefer content.deinit();

    var buf: [BUFFER_SIZE]u8 = undefined;
    var in_section = false;

    while (try reader.readUntilDelimiterOrEof(&buf, '\n')) |line| {
        const trimmed = std.mem.trim(u8, line, &std.ascii.whitespace);
        if (std.mem.eql(u8, trimmed, startMarker)) {
            in_section = true;
            continue;
        }
        if (std.mem.eql(u8, trimmed, endMarker)) {
            break;
        }
        if (in_section) {
            try content.appendSlice(trimmed);
            try content.append(' ');
        }
    }

    return content.toOwnedSlice();
}

// inline or comptime??
inline fn parseNextInt(it: *std.mem.TokenIterator(u8, .scalar)) !u32 {
    return std.fmt.parseInt(u32, it.next() orelse return MshError.MissingValue, 10);
}

inline fn parseNextUsize(it: *std.mem.TokenIterator(u8, .scalar)) !usize {
    return std.fmt.parseInt(usize, it.next() orelse return MshError.MissingValue, 10);
}

inline fn parseNextDouble(it: *std.mem.TokenIterator(u8, .scalar)) !f64 {
    return std.fmt.parseFloat(f64, it.next() orelse return MshError.MissingValue);
}

inline fn parseElementType(it: *std.mem.TokenIterator(u8, .scalar)) !MshElementType {
    const typeInt = try parseNextInt(it);
    return std.meta.intToEnum(MshElementType, typeInt) catch return MshError.InvalidElementType;
}

/// Parses a .msh file
pub fn parseMsh() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var file = try std.fs.cwd().openFile("./mesh/lid_1.msh", .{});
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const stream = buf_reader.reader();

    const nodes = try parseNodes(allocator, &stream);
    defer allocator.free(nodes);

    const elements = try parseElements(allocator, &stream);
    defer {
        for (elements) |maybe_element| {
            if (maybe_element) |element| {
                allocator.free(element.nodes);
            }
        }
        allocator.free(elements);
    }
}
