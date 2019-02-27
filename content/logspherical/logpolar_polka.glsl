/*
Inverse log-polar map applied to a grid polka dots.

In traditional 3D, the steps to do this would be:
1. Define the geometry for a polka dot
2. Apply a regular tiling
3. Apply the inverse log-polar map

Since this is a fragment shader, all steps are reversed and applied in reverse
order:
1. Apply the forward log-polar map to the current pixel coordinates
2. Use fract() to turn tiled coordinates into single-tile coordinates
3. Return color using the equation for a disk centered on the origin
*/

precision mediump float;
#define M_PI 3.1415926535897932384626433832795

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote to generate sliders
uniform float rho_offset; //dspnote param: 0 - 1
uniform float theta_offset; //dspnote param: 0 - 1

float scale = 6.0/M_PI;
vec3 diskColor = vec3(0.4, 0.4, 0.3);
vec3 hBarColor = vec3(0.2, 1.0, 0.2);
vec3 vBarColor = vec3(1.0, 0.2, 0.2);

vec2 logPolar(vec2 p) {
	p = vec2(log(length(p)), atan(p.y, p.x));
	return p;
}

float line(float pos, float aaSize) {
	return smoothstep(-1.3*aaSize, -0.5*aaSize, pos) - 
		smoothstep(0.5*aaSize, 1.3*aaSize, pos);
}

float disk(vec2 pos, float aaSize) {
	return 1.0-smoothstep(0.3-aaSize, 0.3+aaSize, length(pos));
}

vec3 polka(vec2 p, float aaSize) {
	p *= scale;
	vec2 diskP = p - vec2(rho_offset, theta_offset)*3.0;
	diskP = fract(diskP) * 2.0 - 1.0;
	vec3 ret = vec3(1.0);
	ret = mix(ret, diskColor, disk(diskP, aaSize));
	ret = mix(ret, hBarColor, line(p.x, aaSize));
	ret = mix(ret, vBarColor, line(p.y, aaSize));
	return ret;
}

vec3 cartesianPolka(vec2 p) {
	p *= 4.0;
	float aaSize = length(1.0/iRes)*14.0;
	vec3 ret = polka(p, aaSize);
	if (p.y > M_PI || p.y < 0.0-M_PI)
		ret *= 0.6;
	return ret;
}

vec3 logPolarPolka(vec2 p) {
	p *= 1.5;
	float aaSize = length(logPolar(p) - logPolar(p+1.0/iRes)) * 3.5;
	return polka(logPolar(p), aaSize);
}

void main() {
	vec2 p = iUV*2.-1.;
	p.x *= iRes.x/iRes.y;
	vec2 quarter = vec2(iRes.x/iRes.y * 0.5, 0);
	vec3 ret;
	if (p.x < 0.0)
		ret = cartesianPolka(p + quarter);
	else
		ret = logPolarPolka(p - quarter);
	gl_FragColor = vec4(ret, 1.0);
}
