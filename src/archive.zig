//! Extract official Windows Node ZIPs without subprocess code-page conversion.
const std = @import("std");
const host = @import("host.zig");

fn reservedWindowsName(component: []const u8) bool {
    const dot = std.mem.indexOfScalar(u8, component, '.') orelse component.len;
    const stem = std.mem.trimEnd(u8, component[0..dot], " ");
    inline for (.{ "CON", "PRN", "AUX", "NUL", "CLOCK$" }) |name| {
        if (std.ascii.eqlIgnoreCase(stem, name)) return true;
    }
    return stem.len == 4 and stem[3] >= '1' and stem[3] <= '9' and
        (std.ascii.eqlIgnoreCase(stem[0..3], "COM") or std.ascii.eqlIgnoreCase(stem[0..3], "LPT"));
}

fn verifyExtracted(destination: std.Io.Dir, reader: *std.Io.File.Reader) !void {
    const io = host.io();
    var entries = try std.zip.Iterator.init(reader);
    var name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    while (try entries.next()) |entry| {
        const name = try entry.getFilename(reader, &name_buffer, .{});
        if (std.mem.endsWith(u8, name, "/")) continue;
        const output = try destination.openFile(io, name, .{ .follow_symlinks = false });
        defer output.close(io);
        const stat = try output.stat(io);
        if (stat.kind != .file) return error.InvalidArchiveFile;
        if (stat.size != entry.uncompressed_size) return error.ArchiveLengthMismatch;
        var read_buffer: [8192]u8 = undefined;
        var output_reader = output.reader(io, &read_buffer);
        var chunk: [8192]u8 = undefined;
        var crc = std.hash.Crc32.init();
        var actual_size: u64 = 0;
        while (true) {
            const len = try output_reader.interface.readSliceShort(&chunk);
            if (len == 0) break;
            actual_size += len;
            if (actual_size > entry.uncompressed_size) return error.ArchiveLengthMismatch;
            crc.update(chunk[0..len]);
        }
        if (actual_size != entry.uncompressed_size) return error.ArchiveLengthMismatch;
        if (crc.final() != entry.crc32) return error.ArchiveChecksumMismatch;
    }
}

pub fn extractNodeZip(allocator: std.mem.Allocator, archive_path: []const u8, install_path: []const u8, expected_root: []const u8) !void {
    const io = host.io();
    if (expected_root.len == 0 or std.mem.indexOfAny(u8, expected_root, "/\\:") != null or
        std.mem.eql(u8, expected_root, ".") or std.mem.eql(u8, expected_root, "..")) return error.InvalidArchiveRoot;
    const file = try std.Io.Dir.openFileAbsolute(io, archive_path, .{});
    defer file.close(io);
    var buffer: [8192]u8 = undefined;
    var reader = file.reader(io, &buffer);

    // Validate every name and the single distribution root before writing.
    var diagnostics: std.zip.Diagnostics = .{ .allocator = allocator };
    defer diagnostics.deinit();
    var seen: std.StringHashMapUnmanaged(void) = .empty;
    defer {
        var keys = seen.keyIterator();
        while (keys.next()) |key| allocator.free(key.*);
        seen.deinit(allocator);
    }
    var count: usize = 0;
    var total_size: u64 = 0;
    var total_name_bytes: usize = 0;
    var iterator = try std.zip.Iterator.init(&reader);
    var name_buffer: [std.fs.max_path_bytes]u8 = undefined;
    while (try iterator.next()) |entry| {
        count += 1;
        if (count > 100_000 or entry.uncompressed_size > 1024 * 1024 * 1024 - total_size) return error.ArchiveTooLarge;
        total_size += entry.uncompressed_size;
        if (entry.filename_len > 16 * 1024 * 1024 - total_name_bytes) return error.ArchiveTooLarge;
        total_name_bytes += entry.filename_len;
        const name = try entry.getFilename(&reader, &name_buffer, .{});
        // Reject Windows drive/ADS syntax and normalized alias components on
        // every host, so tests and production accept the same archives.
        if (std.mem.indexOfAny(u8, name, ":\\<>\"|?*") != null) return error.InvalidArchivePath;
        for (name) |c| if (c < 32) return error.InvalidArchivePath;
        const canonical = std.mem.trimEnd(u8, name, "/");
        var parts = std.mem.splitScalar(u8, canonical, '/');
        while (parts.next()) |part| {
            if (part.len == 0 or std.mem.eql(u8, part, ".") or std.mem.eql(u8, part, "..") or
                part[part.len - 1] == '.' or part[part.len - 1] == ' ' or reservedWindowsName(part)) return error.InvalidArchivePath;
        }
        const key = try allocator.dupe(u8, canonical);
        for (key) |*c| c.* = std.ascii.toLower(c.*);
        const result = seen.getOrPut(allocator, key) catch |err| {
            allocator.free(key);
            return err;
        };
        if (result.found_existing) {
            allocator.free(key);
            return error.DuplicateArchivePath;
        }
        try diagnostics.nextFilename(name);
    }
    if (!diagnostics.saw_first_file or !std.mem.eql(u8, diagnostics.root_dir, expected_root)) return error.UnexpectedArchiveRoot;

    const parent = std.fs.path.dirname(install_path) orelse return error.InvalidInstallPath;
    try std.Io.Dir.cwd().createDirPath(io, parent);
    var random: [16]u8 = undefined;
    std.Io.random(io, &random);
    const staging = try std.fmt.allocPrint(allocator, "{s}.staging-{x}", .{ install_path, random });
    defer allocator.free(staging);
    // Exclusive creation: never adopt or clean up someone else's directory.
    try std.Io.Dir.createDirAbsolute(io, staging, .default_dir);
    defer std.Io.Dir.cwd().deleteTree(io, staging) catch {};
    {
        var destination = try std.Io.Dir.openDirAbsolute(io, staging, .{});
        defer destination.close(io);
        try std.zip.extract(destination, &reader, .{});
        // Zig's verify_checksums option is unimplemented. Check every regular
        // output file ourselves, streaming CRC32/length before publication.
        try verifyExtracted(destination, &reader);
        var root = try destination.openDir(io, expected_root, .{});
        defer root.close(io);
        const node = try root.openFile(io, "node.exe", .{});
        defer node.close(io);
        if ((try node.stat(io)).kind != .file) return error.InvalidNodeBinary;
    }
    const extracted_root = try std.fs.path.join(allocator, &.{ staging, expected_root });
    defer allocator.free(extracted_root);
    // Move the whole validated distribution atomically, with all handles
    // closed, without replacing any existing installation (even if empty).
    try std.Io.Dir.cwd().renamePreserve(extracted_root, .cwd(), install_path, io);
}

const fixture = @import("archive_fixture.zig").bytes;

test "Windows Node ZIP extraction preserves Unicode paths and flattens layout" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "archive.zip", .data = &fixture });
    const base = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(base);
    const archive = try std.fs.path.join(allocator, &.{ base, "archive.zip" });
    defer allocator.free(archive);
    const destination = try std.fs.path.join(allocator, &.{ base, "中文 ‘node’" });
    defer allocator.free(destination);
    try extractNodeZip(allocator, archive, destination, "node-v22.14.0-win-x64");
    const node = try tmp.dir.readFileAlloc(io, "中文 ‘node’/node.exe", allocator, .limited(100));
    defer allocator.free(node);
    try std.testing.expectEqualStrings("fixture node", node);
    const npm = try tmp.dir.readFileAlloc(io, "中文 ‘node’/node_modules/npm/package.json", allocator, .limited(100));
    defer allocator.free(npm);
    try std.testing.expectEqualStrings("{\"version\":\"10.0.0\"}", npm);
    try std.testing.expectError(error.FileNotFound, tmp.dir.openDir(io, "中文 ‘node’/node-v22.14.0-win-x64", .{}));
}

test "Windows Node ZIP rejects a mismatched distribution root before extracting" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "archive.zip", .data = &fixture });
    const base = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(base);
    const archive = try std.fs.path.join(allocator, &.{ base, "archive.zip" });
    defer allocator.free(archive);
    const destination = try std.fs.path.join(allocator, &.{ base, "destination" });
    defer allocator.free(destination);
    try std.testing.expectError(error.UnexpectedArchiveRoot, extractNodeZip(allocator, archive, destination, "node-v20.0.0-win-x64"));
    try std.testing.expectError(error.FileNotFound, tmp.dir.openDir(io, "destination/node-v22.14.0-win-x64", .{}));
}

test "malicious Windows ZIP paths are rejected before writes" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();
    const base = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(base);
    const archive = try std.fs.path.join(allocator, &.{ base, "bad.zip" });
    defer allocator.free(archive);
    const destination = try std.fs.path.join(allocator, &.{ base, "destination" });
    defer allocator.free(destination);
    const fixtures = @import("archive_fixture.zig");
    const cases = .{
        .{ &fixtures.traversal, error.ZipBadFilename },
        .{ &fixtures.drive, error.InvalidArchivePath },
        .{ &fixtures.duplicate, error.DuplicateArchivePath },
        .{ &fixtures.reserved, error.InvalidArchivePath },
    };
    inline for (cases) |case| {
        try tmp.dir.writeFile(io, .{ .sub_path = "bad.zip", .data = case[0] });
        try std.testing.expectError(case[1], extractNodeZip(allocator, archive, destination, "node-v22.14.0-win-x64"));
    }
    try std.testing.expectError(error.FileNotFound, tmp.dir.openDir(io, "destination", .{}));
    try std.testing.expectError(error.FileNotFound, tmp.dir.openFile(io, "escaped", .{}));
}

test "Node ZIP extraction preserves an existing destination and cleans staging" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    try tmp.dir.writeFile(io, .{ .sub_path = "archive.zip", .data = &fixture });
    try tmp.dir.createDir(io, "destination", .default_dir);
    try tmp.dir.writeFile(io, .{ .sub_path = "destination/keep", .data = "keep" });
    const base = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(base);
    const archive = try std.fs.path.join(allocator, &.{ base, "archive.zip" });
    defer allocator.free(archive);
    const destination = try std.fs.path.join(allocator, &.{ base, "destination" });
    defer allocator.free(destination);
    if (extractNodeZip(allocator, archive, destination, "node-v22.14.0-win-x64")) {
        return error.ExpectedDestinationConflict;
    } else |err| switch (err) {
        error.PathAlreadyExists, error.AccessDenied => {},
        else => return err,
    }
    const kept = try tmp.dir.readFileAlloc(io, "destination/keep", allocator, .limited(100));
    defer allocator.free(kept);
    try std.testing.expectEqualStrings("keep", kept);
    var entries = tmp.dir.iterate();
    while (try entries.next(io)) |entry| {
        try std.testing.expect(std.mem.indexOf(u8, entry.name, ".staging-") == null);
    }
}

test "corrupt ZIP payload is rejected and staging is cleaned" {
    const allocator = std.testing.allocator;
    const io = std.testing.io;
    var tmp = std.testing.tmpDir(.{ .iterate = true });
    defer tmp.cleanup();
    var corrupt = fixture;
    const payload_at = std.mem.indexOf(u8, &corrupt, "fixture node").?;
    corrupt[payload_at] ^= 1; // Preserve both central and local CRC metadata.
    try tmp.dir.writeFile(io, .{ .sub_path = "bad.zip", .data = &corrupt });
    const base = try tmp.dir.realPathFileAlloc(io, ".", allocator);
    defer allocator.free(base);
    const archive = try std.fs.path.join(allocator, &.{ base, "bad.zip" });
    defer allocator.free(archive);
    const destination = try std.fs.path.join(allocator, &.{ base, "destination" });
    defer allocator.free(destination);
    try std.testing.expectError(error.ArchiveChecksumMismatch, extractNodeZip(allocator, archive, destination, "node-v22.14.0-win-x64"));
    try std.testing.expectError(error.FileNotFound, tmp.dir.openDir(io, "destination", .{}));
    var entries = tmp.dir.iterate();
    while (try entries.next(io)) |entry| try std.testing.expect(std.mem.indexOf(u8, entry.name, ".staging-") == null);
}

test "reserved Windows device stems are rejected before extension" {
    inline for (.{ "con", "PRN.txt", "aux", "NUL.json", "com1.log", "COM9", "lpt1", "LPT9.txt", "CLOCK$", "con .txt" }) |name| {
        try std.testing.expect(reservedWindowsName(name));
    }
    inline for (.{ "console.js", "company", "com10.txt", "file.txt" }) |name| {
        try std.testing.expect(!reservedWindowsName(name));
    }
}
