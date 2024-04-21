const mem = @import("std").mem;

// TODO: This could be an interface so it can be more easily usable with other interfaces.
pub fn RefCounted(comptime T: type) type {
    return struct {
        const Self = @This();

        pub const TaggedData = struct {
            // TODO: Figure out a way to not have to separately allocate the data.
            data: T,
            ref_count: usize,
            allocator: mem.Allocator,
        };

        tagged_data_ptr: *TaggedData,

        pub fn init(allocator: mem.Allocator) !Self {
            const tagged_data_ptr = try allocator.create(TaggedData);

            tagged_data_ptr.* = TaggedData{
                .data = undefined,
                .ref_count = 1,
                .allocator = allocator,
            };

            return Self{
                .tagged_data_ptr = tagged_data_ptr,
            };
        }

        pub fn deinit(self: *const Self) void {
            const ptr = self.tagged_data_ptr;
            ptr.ref_count -= 1;
            if (ptr.ref_count == 0) {
                ptr.allocator.destroy(ptr);
            }
        }

        pub fn strongRef(self: *const Self) Self {
            self.tagged_data_ptr.ref_count += 1;
            return Self{
                .tagged_data_ptr = self.tagged_data_ptr,
            };
        }

        pub fn weakRef(self: *const Self) *T {
            return &self.tagged_data_ptr.data;
        }
    };
}
