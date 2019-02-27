/*
Visualization of the field distortion caused by the log-polar map.

The scene is generated following the same steps as in logpolar_polka.glsl:
1. Apply the forward log-polar map to the current pixel coordinates
2. Use fract() to turn tiled coordinates into single-tile coordinates
3. Find the distance value to a disk centered on the origin
4. Turn distance value into color using fract palette

*/

precision mediump float;
#define M_PI 3.1415926535897932384626433832795

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// Parsed by dspnote to generate sliders
uniform float rho_offset; //dspnote param: 0 - 1

float scale = 6.0/M_PI;

vec2 logPolar(vec2 p) {
	p = vec2(log(length(p)), atan(p.y, p.x));
	return p;
}

// for visualization: smooth fract (from a comment by Shane)
float sFract(float x, float s) {
	float is = 1./s-0.99;
	x = fract(x);
	return min(x, x*(1.-x)*is)+s*0.5;
}

vec3 distanceGradient(float d, float aa) {
	vec3 ret = vec3(sFract(abs(d*3.0), aa));
	ret.x = 1. - smoothstep(-0.5*aa, 0.5*aa, d);
	ret *= exp(-1.0 * abs(d));
	return ret;
}

float disk(vec2 pos) {
	return length(pos) - 0.3;
}

float polka(vec2 p) {
	p *= scale;
	vec2 diskP = p - vec2(rho_offset, 0.0)*3.0;
	diskP = fract(diskP) * 2.0 - 1.0;
	return disk(diskP);
}

vec3 logPolarPolka(vec2 p) {
	p *= 1.5;
	vec2 lp = logPolar(p);
	float aa = length(lp - logPolar(p+1.0/iRes)) * 35.;
	if(aa>1.) aa = 1.;
	return distanceGradient(polka(lp), aa);
}

vec3 correctedPolka(vec2 p) {
	p *= 1.5;
	vec2 lp = logPolar(p);
	float aa = length(1.0/iRes) * 35.;
	return distanceGradient(polka(lp) * exp(lp.x), aa);
}

void main() {
	vec2 p = iUV*2.-1.;
	p.x *= iRes.x/iRes.y;
	vec2 quarter = vec2(iRes.x/iRes.y * 0.5, 0);
	vec3 ret;
	if (p.x < -0.01)
		ret = logPolarPolka(p + quarter);
	else if (p.x > 0.01)
		ret = correctedPolka(p - quarter);
	else
		ret = vec3(0.0);
	gl_FragColor = vec4(ret, 1.0);
}
