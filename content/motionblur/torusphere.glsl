
/*
Infinite speed motion blur using volume ray casting.

Blog post to go with it: https://www.osar.fr/notes/motionblur
*/

#extension GL_OES_standard_derivatives : enable
precision mediump float;
#define PI 3.14159265359

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote for interaction
uniform float cam_x; //dspnote param
uniform float cam_y; //dspnote param

// basic material, light and camera settings
#define DIFFUSE .9
#define SPEC .9
#define REFLECT .05
const vec3 lightDir = normalize(vec3(-5, -6, -1));
#define CAM_D 2.4
#define CAM_H .75

// marching iterations
#define ITER 40
#define SHADOW_ITER 20
// marching step, which depends on the size of the bounding sphere
float stepSz;
// torus shape ratio = minor radius / major radius
#define TOR_RATIO .38
// speed for: time remapping; ball transition into orbit; object rotation
#define TIMESCALE .015
#define RAD_SPEED 100.
const float RT_RAD_SPEED = sqrt(RAD_SPEED);
const float MAX_SPEED = floor(30./(TIMESCALE*PI*2.)+.5)*PI*2.;
// remapped time for large scale events
float T;
// cycle duration in remapped time
// it depends on the torus ratio because the radiuses zoom into each other
const float C = log((1. + TOR_RATIO) / TOR_RATIO);
const float D = C * .5;
// ball and torus speed, rotation and transformation matrix
float balSpeed, balRot, torSpeed, torRot;
mat2 balMat, torMat;
// ball and torus size and cycle progression
float balSz, torSz, balCycle, torCycle;
// ball and torus motion blur amplification
float balAmp, torAmp;
// torus minor and major radius, with squared version
vec2 tor, tor2;
// constants for torus angle and ball normals
float torCst, balCst;
// density and normity x-fades, ball orbit radius, cosmetic adjustments
float densXf, normXf, balOrbit, torNormSz, strobe;

// by Dave_Hoskins: https://www.shadertoy.com/view/4djSRW
float hash14(vec4 p4) {
	p4 = fract(p4  * vec4(.1031, .1030, .0973, .1099));
	p4 += dot(p4, p4.wzxy+33.33);
	return fract((p4.x + p4.y) * (p4.z + p4.w));
}

// by iq: https://iquilezles.org/articles/filterableprocedurals/
float filteredGrid(vec2 p, float scale, vec2 dpdx, vec2 dpdy) {
	float iscale = 1./scale;
	float N = 60.0*scale;
	p *= iscale;
	vec2 w = max(abs(dpdx), abs(dpdy))*iscale;
	vec2 a = p + 0.5*w;
	vec2 b = p - 0.5*w;
	vec2 i = (floor(a)+min(fract(a)*N,1.0)-
		floor(b)-min(fract(b)*N,1.0))/(N*w);
	return (1.0-i.x*.6)*(1.0-i.y*.6);
}

// by iq: https://iquilezles.org/articles/smin/
float smin(float a, float b, float k) {
	float h = max(k-abs(a-b), 0.0)/k;
	return min(a, b) - h*h*k*(1.0/4.0);
}

mat2 rot2d(float a) {
	float c = cos(a);
	float s = sin(a);
	return mat2(c, -s, s, c);
}

// 2-point sphere intersection
vec2 sphIntersect2(vec3 ro, vec3 rd, vec4 sph) {
	vec3 oc = ro - sph.xyz;
	float b = dot(oc, rd);
	float c = dot(oc, oc) - sph.w*sph.w;
	float h = b*b - c;
	if(h<0.0) return vec2(-1.0, -1.0);
	h = sqrt(h);
	return vec2(-b-h, -b+h);
}

// antiderivative of the cosine shutter function which is:
// (1-cos((x-t1) 2 PI / (t2-t1)))/(t2-t1) if t1<x<t2
// 0 otherwise
float iCosShutter(float x, float t1, float t2) {
	if (x < t1) return 0.;
	if (x > t2) return 1.;
	float d = 1./(t2 - t1);
	x -= t1;
	return x*d - sin(2.*PI*x*d)/(2.*PI);
}

// motion blurred density = integral of { object presence * window function }
float cosMotionBlur(float obj1, float obj2) {
	// Shutter time interval. Should include the frameStart, but it's
	// moved to the pixel coordinates for easier wrap management.
	float shut1 = -1./60.;
	float shut2 = 1./60.;
	// integral of the shutter function from obj1 to obj2
	return iCosShutter(obj2, shut1, shut2) - iCosShutter(obj1, shut1, shut2);
}

// Take a slice at depth y. In polar coordinates, at radius r,
// find the polar angle of the ball surface.
// Returns 0 if r is entirely outside the ball.
// Returns -1 if r is entirely inside the ball.
float ballPolarSurface(float r, float y) {
	float rad = balSz*balSz - y*y;
	if (rad <= 0.) return 0.;
	rad = sqrt(rad);
	if (r <= rad-balOrbit) return -1.;
	float div = (balOrbit*balOrbit+r*r-rad*rad)/(2.*r*balOrbit);
	if (abs(div) > 1.) return 0.;
	return acos(div);
}

// motion-blurred ball density
float ballDensity(vec3 p, float speed) {
    p.xz *= balMat;
	p.z = abs(p.z);
	vec2 pol = vec2(length(p.xz), atan(p.z, p.x));
	float bA = ballPolarSurface(pol.x, p.y);
	if (bA == -1.) return 1.;
	// Time interval for the object presence at this pixel.
	float obj1 = (pol.y-bA)/speed;
	float obj2 = (pol.y+bA)/speed;
	return cosMotionBlur(obj1, obj2);
}

// ball "normity", pseudo distance field to calculate normals
float ballNormity(vec3 p) {
    p.xz *= balMat;
	p.z = abs(p.z);
	vec2 pol = vec2(length(p.xz), atan(p.z, p.x));
	pol.y = max(0., pol.y-balCst);
	p.x = pol.x*cos(pol.y);
	p.z = pol.x*sin(pol.y);
	return length(p-vec3(balOrbit, 0., 0.))-balSz;
}

// Take a slice at depth z. In polar coordinates, at radius r,
// find the polar angle of the torus surface.
// Returns 0 if r is entirely outside the torus.
// Returns -1 if r is entirely inside the torus.
float spiricPolarSurface(float r, float z) {
	float r2 = r*r;
	float z2 = z*z;
	float sum = torCst-2.*tor2.x*z2-2.*tor2.x*r2-2.*tor2.y*z2+2.*tor2.y*r2+z2*z2+2.*z2*r2+r2*r2;
	if (sum < 0.) return -1.;
	float sq = sqrt(sum)/(2.*tor.y*r);
	if (abs(sq) > 1.) return 0.;
	return acos(sq);
}

// motion-blurred density of a half torus (a macaroni)
float halfTorusDensity(vec2 pol, float z, float speed) {
	float da = spiricPolarSurface(pol.x, z);
	if (da == 0.) return 0.;
	if (da == -1.) return 1.;
	// Time interval for the object presence at this pixel.
	float obj1 = (pol.y-da)/speed;
	float obj2 = (pol.y+da)/speed;
	return cosMotionBlur(obj1, obj2);
}

// motion-blurred torus density
float torusDensity(vec3 p3d, float speed) {
    p3d.xy *= torMat;
	vec2 pol = vec2(length(p3d.xy), atan(p3d.y, p3d.x));
	pol.y = mod(pol.y, PI*2.)-PI;
	float da = halfTorusDensity(pol, p3d.z, speed);
	pol.y = mod(pol.y + PI*2., PI*2.)-PI;
	float da2 = halfTorusDensity(pol, p3d.z, speed);
	if (da == 0. && da2 == 0.) return 0.;
	if (da == -1. || da2 == -1.) return 1.;
	return min(1., da+da2);
}

// torus "normity", pseudo distance field to calculate normals
float torusNormity(vec3 p, float speed) {
    p.xy *= torMat;
	float shell = abs(length(p)-tor.y)-tor.x*.3;
	vec2 q = vec2(length(p.xz)-tor.y,p.y);
	float torus = length(q)-tor.x;
	return -smin(speed*.002-torus, .1-shell, 0.1);
}

// combined density and normity
float density(vec3 p) {
	float ball = ballDensity(p, balSpeed)*balAmp;
	float torus = torusDensity(p, torSpeed)*torAmp;
    return mix(ball, torus, densXf);
}
float normity(vec3 p) {
    return mix(
		ballNormity(p),
    	torusNormity(p*torNormSz, torSpeed*.5),
		normXf);
}
vec3 getNormal(vec3 p) {
	float d = normity(p);
	vec2 e = vec2(.001, 0);
	vec3 n = d - vec3(
		normity(p-e.xyy),
		normity(p-e.yxy),
		normity(p-e.yyx));
	return normalize(n);
}

// Because we're raycasting translucent stuff, this is called up to 28x per px
// so let's keep it short
vec3 material(vec3 normal, vec3 rayDir) {
	float diff = max(dot(normal, -lightDir), .05);
	vec3 reflectDir = -lightDir - 2.*normal * dot(-lightDir, normal);
	float spec = max(dot(rayDir, reflectDir), 0.);
	return vec3(.8,.9,1.) * (diff * DIFFUSE + spec * REFLECT);
}

// render torusphere by volume raycasting
vec4 march(vec3 ro, vec3 rd, float marchPos, float marchBack) {
	float totMul = strobe*stepSz/0.05;
	vec4 col = vec4(0.);
	marchPos -= stepSz * hash14(vec4(rd*4000., iTime*100.));
	int nMats = 0;
	for(int i=0; i<ITER; i++) {
		vec3 pos = ro + rd * marchPos;
		float d = clamp(density(pos)*totMul, 0., 1.);
		if(d > .002) {
			d = d*d*.5;
			float a2 = (1.-col.a)*d;
			vec3 n = getNormal(pos);
			col += vec4(material(n, rd)*a2, a2);
			if (col.a > 0.95) break;
			if (nMats++ > 28) break;
		}
		marchPos += stepSz;
		if (marchPos > marchBack) break;
	}
	if (col.a > 0.) col.rgb /= col.a;
	return col;
}

// render ground shadow by volume raycasting without material
float shadowMarch(vec3 ro, vec3 rd, float marchPos, float marchBack) {
	float ret = 0.;
	float shadowStep = stepSz*2.;
	float totMul = .47*strobe*shadowStep/0.05;
	marchPos -= shadowStep * hash14(vec4(ro*4000., iTime*100.));
	for(int i=0; i<SHADOW_ITER; i++) {
		vec3 pos = ro + rd * marchPos;
		float d = clamp(density(pos)*totMul, 0., 1.);
		if(d > .002) {
			d = d*d*.9;
			ret += (1.-ret)*d;
			if (ret > 0.95) break;
		}
		marchPos += shadowStep;
		if (marchPos > marchBack) break;
	}
	return min(1., ret);
}

// very inefficiently speed up the boring parts
float retime(float t) {
	t *= TIMESCALE;
	float s = .5+1.7*t*PI*2./D;
	s = sin(s+sin(s+sin(s+sin(s)*0.3)*0.5)*0.75);
	return s*.06+t*1.7;
}

// ball<->torus crossfade used separately by density and normity
float getXf(float x) {
	x = (abs(mod(x-(D/4.), C)-D)/D-.5)*2.+.5;
	// return smoothstep(0, 1, x)
	x = 2.*clamp(x, 0., 1.)-1.;
	return .5+x/(x*x+1.);
}

// The entire scene is necessarily zooming out. The ground texture deals with
// that by crossfading different scales.
const float GRID_CYCLE = log(64.);
vec3 grid(vec2 pt, vec2 dx, vec2 dy, float phase, float t) {
	float freq = exp(-mod(t+GRID_CYCLE*phase, GRID_CYCLE))*7.;
	float amp = cos(PI*2.*phase+t*PI*2./GRID_CYCLE)*-.5+.5;
	float g = filteredGrid(pt, freq, dx, dy)*amp;
	return vec3(g,g,g);
}

void mainImage(inout vec4 fragColor, in vec2 fragCoord) {
	// set all the globals...
	T = retime(iTime+25.); // consider a modulo here
	balCycle = mod(T, C);
	torCycle = mod(T+D, C);

	// size of the bounding sphere for marching and step size
	float boundSz = exp(-min(torCycle, 5.*(C-mod(T-D, C))));
	stepSz = boundSz/20.;

	// the ball/torus appear constant size and the camera appears to zoom out
	// in the code the camera distance is fixed and the objects are shrinking
	balSz = exp(-balCycle-D);
	torSz = exp(-torCycle);

	// the rotation is (theoretically) the integral of the speed, we need both
	balSpeed = .04*MAX_SPEED*(cos(T*PI*2./C)+1.);
	torSpeed = .04*MAX_SPEED*(cos((T+D)*PI*2./C)+1.);
	balRot = MAX_SPEED*(sin(T*PI*2./C)/(PI*2./C)+T)/C;
	torRot = MAX_SPEED*(sin((T+D)*PI*2./C)/(PI*2./C)+T)/C;
	if (balCycle<D) {
		balRot = MAX_SPEED*(floor(T/C+.5)*C+D)/C;
		balSpeed = 0.;
	}
	if (torCycle<D) {
		torRot = MAX_SPEED*(floor((T+D)/C+.5)*C)/C;
		torSpeed = 0.;
	}
	balMat = rot2d(balRot);
	torMat = rot2d(torRot);

	// torus minor and major radius and their squares
	tor = vec2(torSz/(1.+1./TOR_RATIO), torSz/(1.+TOR_RATIO));
	tor2 = tor*tor;

	// precalculate constants for the spiric angle and ball normals
	torCst = tor2.x*tor2.x + tor2.y*tor2.y - 2.*tor2.x*tor2.y;
	balCst = 2.*balSpeed*smoothstep(30., 40., balSpeed);
	float bx = balCst*.037;
	balCst = (balCst+bx*bx*bx)*.004;

	// ball's orbital radius
	balOrbit = clamp(balCycle-D, 0., 2.*RT_RAD_SPEED/RAD_SPEED)-RT_RAD_SPEED/RAD_SPEED;
	balOrbit = .5+RT_RAD_SPEED*balOrbit/(balOrbit*balOrbit*RAD_SPEED+1.);
	balOrbit *= tor.y;

	// ball<->torus crossfade: the normity precedes the density slightly
	// this smoothens the max speed -> zero speed illusion
	densXf = getXf(T);
	normXf = getXf(T+0.06);

	// motion blur amplification is what makes this work
	balAmp = 1.+balSpeed*balSpeed*.00013;
	torAmp = 1.5+torSpeed*torSpeed*.00015;
	torNormSz = max(1., 8.*(torCycle-.76));

    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv = fragCoord/iRes.xy;

	// the strobe effect simulates overlap between fast spin and slow spin
	strobe = 1.-.1*(sin(iTime*83.+PI*smoothstep(.4, .6, uv.x))+1.)*(sin(2.2+T*PI*2./D)+1.)*.5;

	// camera
	float side = cos(CAM_H+cam_y)*CAM_D;
	float camT = iTime*0.05+PI*.75+cam_x;
	vec3 ro = vec3(sin(camT)*side, sin(CAM_H+cam_y)*CAM_D, cos(camT)*side); // camera position (ray origin)
	vec3 ta = vec3(0., 0., 0.); // camera target
	vec3 ww = normalize(ta - ro);
	vec3 uu = normalize(cross(ww,vec3(0.0,1.0,0.0)));
	vec3 vv = normalize(cross(uu,ww));
	vec2 p = (-iRes.xy + 2.0*fragCoord)/iRes.y;
	vec3 rd = normalize(p.x*uu + p.y*vv + 2.*ww);

	// this starting color taints the entire scene (unintentional but why not)
	vec3 col = vec3(0.33, 0.18, 0.1);

	// the ground plane
	if (rd.y < 0.) {
		vec3 groundPt = ro + rd*(-(ro.y+.8) / rd.y);
		vec2 g2d = groundPt.xz;
		vec2 dx = dFdx(g2d);
		vec2 dy = dFdy(g2d);
		// the ground texture zooms out by crossfading different scales
		col += grid(g2d, dx, dy, 0., T)/3.;
		col += grid(g2d, dx, dy, 1./3., T)/3.;
		col += grid(g2d, dx, dy, 2./3., T)/3.;
		float sqDist = dot(g2d, g2d);
		col *= 2./(sqDist*.5*1.5+1.)-1.2/(sqDist*1.5*1.5+1.);
		// are we in the shadow of the bounding sphere?
		vec2 sphInter = sphIntersect2(groundPt, -lightDir, vec4(0.,0.,0.,boundSz));
		if (sphInter != vec2(-1., -1.)) {
			// march the torusphere to draw the shadow
			float shad = shadowMarch(groundPt, -lightDir, sphInter.x, sphInter.y);
			col *= 1.-shad*.7;
		}
	}

	// the sky (only visible in interactive version)
	float up = dot(rd, vec3(0.,1.,0.));
	col = mix(col, vec3(0.33, 0.18, 0.1)*.7, 1.-smoothstep(0., .02, abs(up)+.003));
	col = mix(col, vec3(0.,0.,.1), smoothstep(0., .5, up));

	// finally render the torusphere
	vec2 sphInter = sphIntersect2(ro, rd, vec4(0.,0.,0.,boundSz));
	if (sphInter != vec2(-1., -1.)) {
		vec4 ts = march(ro, rd, sphInter.x, sphInter.y);
		col = mix(col, ts.rgb, ts.a);
	}
    fragColor = vec4(col, 1.);
}

void main(void)
{
	vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
	mainImage(color, gl_FragCoord.xy);
	gl_FragColor = color;
}
