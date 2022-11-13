/*
Motion-blurred spiric section.
*/

precision mediump float;
#define PI 3.1415926535897932384626433832795

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote to generate sliders
uniform int video_motion_blur; //dspnote param: traditional | with_sine_shutter
uniform float minor_radius; //dspnote param: 0.01 - 0.5, 0.2
uniform float major_radius; //dspnote param: 0.01 - 0.5, 0.3
uniform float slice_position; //dspnote param: -1 - 1, 0.1
uniform float rotation_speed; //dspnote param: 0 - 300, 10 (rad/s)

const float time = 0.;

// torus minor and major radius, squared and combined
vec2 tor, tor2;
float torCst;

// the cosine shutter function is:
// (1-cos((x-t1) 2 PI / (t2-t1)))/(t2-t1) if t1<x<t2
// 0 otherwise
// this is the integral:
float iCosShutter(float x, float t1, float t2) {
	if (x < t1) return 0.;
	if (x > t2) return 1.;
	float d = 1./(t2 - t1);
	x -= t1;
	return x*d - sin(2.*PI*x*d)/(2.*PI);
}

// Within the slice at position z, in polar coordinates at radius r,
// find the angle of the torus surface.
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

float tradMotionBlur(float obj1, float obj2) {
	// Shutter time interval. Should include the frameStart, but it's
	// moved to the pixel coordinates for easier wrap management.
	float shut1 = -.5/60.;
	float shut2 = .5/60.;
	
	// the box shutter function is (shut1<t<shut2) ? 1/(shut2-shut1) : 0
	// the object presence function is (obj1<t<obj2) ? 1 : 0
	// find the integral of obj*shut
	// = definite integral of the shutter function from obj1 to obj2
	float l = max(shut1, obj1);
	float r = min(shut2, obj2);
	return max(0., (r-l)/(shut2-shut1));
}

float cosMotionBlur(float obj1, float obj2) {
	// Shutter time interval. Should include the frameStart, but it's
	// moved to the pixel coordinates for easier wrap management.
	float shut1 = -.5/60.;
	float shut2 = .5/60.;
	
	// integral of the shutter function from obj1 to obj2
	return iCosShutter(obj2, shut1, shut2) - iCosShutter(obj1, shut1, shut2);
}

float halfTorusDensity(vec2 pol, float z, float speed) {
	float da = spiricPolarSurface(pol.x, z);
	if (da == 0.) return 0.;
	if (da == -1.) return 1.;

	// Time interval for the object presence at this pixel.
	float obj1 = (pol.y-da)/speed;
	float obj2 = (pol.y+da)/speed;
	if (video_motion_blur==1) return cosMotionBlur(obj1, obj2);
	else return tradMotionBlur(obj1, obj2);
}

float torusDensity(vec3 p3d, float frameStart, float speed) {
	vec2 pol = vec2(length(p3d.xy), atan(p3d.y, p3d.x));
	pol.y = mod(pol.y + frameStart*speed, PI*2.)-PI;
	float da = halfTorusDensity(pol, p3d.z, speed);
	pol.y = mod(pol.y + PI*2., PI*2.)-PI;
	float da2 = halfTorusDensity(pol, p3d.z, speed);
	if (da == 0. && da2 == 0.) return 0.;
	if (da == -1. || da2 == -1.) return 1.;
	return min(1., da+da2);
}

void mainImage(inout vec4 fragColor, in vec2 fragCoord)
{
	vec2 ratio = vec2(iRes.x/iRes.y, 1.);
	vec2 p = fragCoord/iRes.xy-0.5;
	p *= ratio;

	tor = vec2(minor_radius, major_radius);
	tor2 = tor*tor;
	// precalculate constant for the spiric angle
	torCst = tor2.x*tor2.x + tor2.y*tor2.y - 2.*tor2.x*tor2.y;

	float frameN = floor(time*60.);
	float frameStart = frameN/60.;
	vec3 col = vec3(torusDensity(vec3(p, slice_position), frameStart, max(.001, rotation_speed)));

	fragColor = vec4(col, 1.0);
}


void main(void)
{
	vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
	mainImage(color, gl_FragCoord.xy);
	gl_FragColor = color;
}
