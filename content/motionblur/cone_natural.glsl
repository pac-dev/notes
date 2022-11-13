/*
Left: Example scene, assumed to be natural and continuous.
Right: reconstructed perceived image.
*/

precision mediump float;
#define PI 3.1415926535897932384626433832795

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote to generate sliders
uniform float time; //dspnote param: 0 - 0.1 (s)
uniform float object_speed; //dspnote param: 0 - 40, 10 (rad/s)

const float orbit = .2;
const float uRad = .1;
const float uniDensMul = 1.;
vec3 diskColor = vec3(.8, .9, 1.);
vec3 dashColor = vec3(1., .2, .2);
vec3 vBarColor = vec3(.9, .9, .9);

// the model weighting function is
// W(x) = -a e^(-e^(a x + b) + a x + b)
// with a=-50 and b=2.5

// integral of W from -inf to x:
float weight_to_x(float x) {
	return exp(-exp(-50.*x+2.5));
}

// integral of W from l to r:
float weight_lr(float l, float r) {
	return weight_to_x(r) - weight_to_x(l);
}

// In polar coordinates, at radius posR, find the angle of the disk surface.
// Returns 0 if posR is entirely outside the disk.
// Returns -1 if posR is entirely inside the disk.
float diskAngle(float posR, float diskR) {
	if (diskR <= 0.) return 0.;
	if (posR <= diskR-orbit) return -1.;
	float div = (orbit*orbit+posR*posR-diskR*diskR)/(2.*posR*orbit);
	if (abs(div) > 1.) return 0.;
	return acos(div);
}

float photoDisk(vec2 pol, float speed) {
	float da = diskAngle(pol.x, uRad);
	if (da == -1.) return 1.;
	// where does the disk occur in this pixel's past?
	// assuming:
	//	- the current pixel is at 0 rad
	//	- the disk currently covers 1 rad to 2 rad
	//	- the disk is moving at 3 rad/sec
	// Then the disk was present from -1/3 sec to -2/3 sec.
	// Integrate the weighting function over this time interval.
	float ret = weight_lr(-(da-pol.y)/speed, -(-da-pol.y)/speed);
	return ret;
}

float dash(vec2 pol, float lol) {
	vec2 p = vec2(pol.x*cos(pol.y), pol.x*sin(pol.y));
	p -=  vec2(orbit, 0.);
	vec2 pol2 = vec2(length(p.xy), atan(p.y, p.x)-lol);
	float line = 1. - smoothstep(1., 2., abs(pol2.x - uRad)*iRes.y);
	line *= smoothstep(.05, .07, abs(mod(pol2.y/PI, .2)-.1));
	return line;
}

void mainImage(inout vec4 fragColor, in vec2 fragCoord)
{
	vec2 ratio = vec2(iRes.x/iRes.y, 1.);
	vec2 p = fragCoord/iRes.xy-0.5;
	vec2 p2 = ratio * vec2(mod(p.x, .5)-.25, p.y);
	p *= ratio;
	float speed = max(.001, object_speed);
	float rot = time*speed - PI + 1.;
	if (p.x < 0.) speed = 0.;
	
	vec2 pol = vec2(length(p2.xy), atan(p2.y, p2.x));
	pol.y = mod(pol.y + rot, PI * 2.)-1.;
	vec3 col = vec3(0.);
	col = mix(col, diskColor, photoDisk(pol, max(.1, speed)));
	if (p.x > 0.) col = mix(col, dashColor, dash(pol, rot));
	col = mix(col, vBarColor, 1. - smoothstep(3., 4., abs(p.x*iRes.x)));

	fragColor = vec4(col, 1.0);
}


void main(void)
{
	vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
	mainImage(color, gl_FragCoord.xy);
	gl_FragColor = color;
}
