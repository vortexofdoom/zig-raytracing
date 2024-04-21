const interface = @import("interface");
const Interface = interface.Interface;
const SelfType = interface.SelfType;
const hit = @import("hit.zig");
const HitRecord = hit.HitRecord;
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Ray = @import("ray.zig");
const Rc = @import("rc.zig").RefCounted;

pub const Scatter = struct {
    attenuation: Vec3,
    ray: Ray,
};

pub const Material = struct {
    const IFace = Interface(struct {
        scatter: *const fn (*const SelfType, Ray, HitRecord) ?Scatter,
    }, interface.Storage.Owning);

    iface: IFace,

    pub fn init(obj: anytype, allocator: @import("std").mem.Allocator) !Rc(Material) {
        const rc = try Rc(Material).init(allocator);
        rc.tagged_data_ptr.data =  Material{
            .iface = try IFace.init(obj, allocator),
        };
        return rc;
    }

    pub fn scatter(self: *const Material, ray: Ray, rec: HitRecord) ?Scatter {
        defer rec.mat.deinit();
        return self.iface.call("scatter", .{ ray, rec });
    }

    pub fn deinit(self: *const Material) void {
        self.iface.deinit();
    }
};

pub const Lambertian = struct {
    albedo: Vec3,

    pub fn scatter(self: *const Lambertian, _: Ray, rec: HitRecord) ?Scatter {
        var scatter_dir: Vec3 = rec.normal + vec3.randomUnitVec();
        // Catch degenerate scatter direction
        if (@reduce(.And, @abs(scatter_dir) < vec3.vec3s(1e-8))) scatter_dir = rec.normal;

        return Scatter {
            .ray = Ray{.origin = rec.p, .dir = scatter_dir},
            .attenuation = self.albedo,
        };
    }
};

pub const Metal = struct {
    albedo: Vec3,
    fuzz: f64,

    pub fn scatter(self: *const Metal, in: Ray, rec: HitRecord) ?Scatter {
        var reflected = vec3.reflect(in.dir, rec.normal);
        reflected = vec3.normalize(reflected) + vec3.vec3s(self.fuzz) * vec3.randomUnitVec();
        const out = Ray{.origin = rec.p, .dir = reflected};
        return if (vec3.dot(out.dir, reflected) > 0.0) Scatter {
            .ray = Ray{.origin = rec.p, .dir = reflected},
            .attenuation = self.albedo,
        } else null;
    }
};
