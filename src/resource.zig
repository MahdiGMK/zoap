const std = @import("std");
const pkt = @import("packet.zig");
const opt = @import("options.zig");
const codes = @import("codes.zig");

// TODO: Pass response writer.
pub const ResourceHandler = fn (req: *pkt.Request) void;

// Size for reply buffer
const REPLY_BUFSIZ = 256;

pub const Resource = struct {
    path: []const u8,
    handler: ResourceHandler,

    pub fn matchPath(self: Resource, path: []const u8) bool {
        return std.mem.eql(u8, self.path, path);
    }
};

pub const Dispatcher = struct {
    resources: []const Resource,
    rbuf: [REPLY_BUFSIZ]u8 = undefined,

    pub fn reply(self: *Dispatcher, req: *const pkt.Request, mt: pkt.Msg, code: codes.Code) !pkt.Response {
        return pkt.Response.reply(&self.rbuf, req, mt, code);
    }

    pub fn dispatch(self: *Dispatcher, req: *pkt.Request) !pkt.Response {
        const hdr = req.header;
        if (hdr.type == pkt.Msg.con) {
            // We are not able to process confirmable message presently
            // thus *always* answer those with a reset with NOT_IMPL.
            return self.reply(req, pkt.Msg.rst, codes.NOT_IMPL);
        }

        const path_opt = try req.findOption(opt.URIPath);
        const path = path_opt.value;

        for (self.resources) |res| {
            if (!res.matchPath(path))
                continue;

            res.handler(req);
            return self.reply(req, pkt.Msg.non, codes.CREATED);
        }

        return self.reply(req, pkt.Msg.non, codes.NOT_FOUND);
    }
};
