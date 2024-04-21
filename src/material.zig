const interface = @import("interface");
const Interface = interface.Interface;
const SelfType = interface.SelfType;
const hit = @import("hit.zig");
const HitRecord = hit.HitRecord;
const vec3 = @import("vec3.zig");
const Vec3 = vec3.Vec3;
const Ray = @import("ray.zig");
const Rc = @import("rc.zig").RefCounted;
const rand = @import("util.zig").rand;

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
            .ray = Ray{.origin = rec.p, .dir = dir},
        };
    }

    fn reflectance(cos: f64, refract_idx: f64) f64 {
        const r0 = (1.0 - refract_idx) / (1.0 + refract_idx);
        const r1 = r0 * r0;
        return r1 + (1.0 - r1) * @import("std").math.pow(f64, 1 - cos, 5);
    }
};
