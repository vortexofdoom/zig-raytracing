const interface = @import("interface");
const Interface = interface.Interface;
const SelfType = interface.SelfType;
const hit = @import("hit.zig");
const HitRecord = hit.HitRecord;
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Ray = @import("ray.zig");
const Rc = @import("rc.zig").RefCounted;
const rand = @import("util.zig").random;
const texture = @import("texture.zig");
const Texture = texture.Texture;
const Allocator = @import("std").mem.Allocator;

pub const Scatter = struct {
    attenuation: Vec3,
    ray: Ray,
};

pub const Material = struct {
    const IFace = Interface(struct {
        scatter: *const fn (*const SelfType, Ray, HitRecord) ?Scatter,
        deinit: *const fn (*const SelfType) void,
    }, interface.Storage.Owning);

    iface: IFace,
    ref_count: *usize,
    allocator: Allocator,

    pub fn init(obj: anytype, allocator: Allocator) !Material {
        const ref_count = try allocator.create(usize);
        ref_count.* = 1;
        return Material{
            .iface = try IFace.init(obj, allocator),
            .ref_count = ref_count,
            .allocator = allocator,
        };
    }

    pub fn strongRef(self: *const Material) Material {
        self.ref_count.* += 1;
        return Material{
            .iface = self.iface,
            .ref_count = self.ref_count,
        };
    }

    pub fn scatter(self: *const Material, ray: Ray, rec: HitRecord) ?Scatter {
        return self.iface.call("scatter", .{ ray, rec });
    }

    pub fn deinit(self: *const Material) void {
        self.ref_count.* -= 1;
        if (self.ref_count.* == 0) {
            self.iface.call("deinit", .{});
            self.iface.deinit();
            self.allocator.destroy(self.ref_count);
        }
    }
};

pub const Lambertian = struct {
    tex: Texture,

    pub fn scatter(self: *const Lambertian, in: Ray, rec: HitRecord) ?Scatter {
        var scatter_dir: Vec3 = rec.normal + vec3.randomUnitVec();
        // Catch degenerate scatter direction
        if (@reduce(.And, @abs(scatter_dir) < vec3.vec3s(1e-8))) scatter_dir = rec.normal;

        return Scatter{
            .attenuation = self.tex.value(rec.u, rec.v, rec.p),
            .ray = Ray{
                .origin = rec.p,
                .dir = scatter_dir,
                .time = in.time,
            },
        };
    }

    pub fn deinit(self: *const Lambertian) void {
        self.tex.deinit();
    }
};

pub const Metal = struct {
    albedo: Vec3,
    fuzz: f64,

    pub fn scatter(self: *const Metal, in: Ray, rec: HitRecord) ?Scatter {
        var reflected = vec3.reflect(in.dir, rec.normal);
        reflected = vec3.normalize(reflected) + vec3.vec3s(self.fuzz) * vec3.randomUnitVec();
        const out = Ray{ .origin = rec.p, .dir = reflected };
        return if (vec3.dot(out.dir, reflected) > 0.0) Scatter{
            .attenuation = self.albedo,
            .ray = Ray{
                .origin = rec.p,
                .dir = reflected,
                .time = in.time,
            },
        } else null;
    }

    pub fn deinit(_: *const Metal) void {}
};

pub const Dielectric = struct {
    refraction_idx: f64,

    pub fn scatter(self: *const Dielectric, in: Ray, rec: HitRecord) ?Scatter {
        const ri = if (rec.front) 1.0 / self.refraction_idx else self.refraction_idx;
        const unit_dir = vec3.normalize(in.dir);
        const cos_theta = @min(vec3.dot(-unit_dir, rec.normal), 1.0);
        const sin_theta = @sqrt(1.0 - cos_theta * cos_theta);
        const cant_refract = ri * sin_theta > 1.0;
        const dir = if (cant_refract or reflectance(cos_theta, ri) > rand())
            vec3.reflect(unit_dir, rec.normal)
        else
            vec3.refract(unit_dir, rec.normal, ri);
        return Scatter{
            .attenuation = vec3.vec3s(1.0),
            .ray = Ray{ .origin = rec.p, .dir = dir, .time = in.time },
        };
    }

    fn reflectance(cos: f64, refract_idx: f64) f64 {
        const r0 = (1.0 - refract_idx) / (1.0 + refract_idx);
        const r1 = r0 * r0;
        return r1 + (1.0 - r1) * @import("std").math.pow(f64, 1 - cos, 5);
    }

    pub fn deinit(_: *const Dielectric) void {}
};
