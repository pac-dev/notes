/*
Left: Example scene, from a screen.
Right: reconstructed perceived image.
*/

precision mediump float;
#define PI 3.1415926535897932384626433832795

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote to generate sliders
uniform int video_motion_blur; //dspnote param: none | traditional | with_sine_shutter
uniform float object_speed; //dspnote param: 0 - 40, 10 (rad/s)
uniform float object_rot; //dspnote param

const float orbit = .2;
const float uRad = .1;
const float uniDensMul = 1.;
vec3 diskColor = vec3(.8, .9, 1.);
vec3 gridColor = vec3(.2, .2, .5);

void pR(inout vec2 p, float a) {
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// the cosine shutter function B is:
// t1<x<t2: (1-cos(x-t1) 2 PI / (t2-t1))/(t2-t1)
// otherwise 0
// this is the integral:
float iCosShutter(float x, float t1, float t2) {
	if (x < t1) return 0.;
	if (x > t2) return 1.;
	float d = 1./(t2 - t1);
	x -= t1;
	return x*d - sin(2.*PI*x*d)/(2.*PI);
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

float screenDiskTrad(vec2 p, float frameStart, float speed) {
	vec2 pol = vec2(length(p.xy), atan(p.y, p.x));
	pol.y = mod(pol.y + object_rot, PI*2.)-PI;
	float da = diskAngle(pol.x, uRad);
	if (da == 0.) return 0.;
	if (da == -1.) return 1.;

	// Time intervals for shutter and object presence at this pixel.
	// Note the shutter interval should include the frameStart, but it's
	// moved to the pixel coordinates for easier wrap management.
	float shut1 = -.5/60.;
	float shut2 = .5/60.;
	float obj1 = (pol.y-da)/speed;
	float obj2 = (pol.y+da)/speed;
	
	// the box shutter function is (shut1<t<shut2) ? 1/(shut2-shut1) : 0
	// the object presence function is (obj1<t<obj2) ? 1 : 0
	// find the integral of obj*shut
	// = definite integral of the shutter function from obj1 to obj2
	float l = max(shut1, obj1);
	float r = min(shut2, obj2);
	return max(0., (r-l)/(shut2-shut1));
}

float screenDiskCos(vec2 p, float frameStart, float speed) {
	vec2 pol = vec2(length(p.xy), atan(p.y, p.x));
	pol.y = mod(pol.y + object_rot, PI*2.)-PI;
	float da = diskAngle(pol.x, uRad);
	if (da == 0.) return 0.;
	if (da == -1.) return 1.;

	// Time intervals for shutter and object presence at this pixel.
	// Note the shutter interval should include the frameStart, but it's
	// moved to the pixel coordinates for easier wrap management.
	float shut1 = -1./60.;
	float shut2 = 1./60.;
	float obj1 = (pol.y-da)/speed;
	float obj2 = (pol.y+da)/speed;
	
	// integral of the shutter function from obj1 to obj2
	return iCosShutter(obj2, shut1, shut2) - iCosShutter(obj1, shut1, shut2);
}

void mainImage(inout vec4 fragColor, in vec2 fragCoord)
{
	vec2 ratio = vec2(iRes.x/iRes.y, 1.);
	vec2 p = fragCoord/iRes.xy-0.5;
	p *= ratio;
	float speed = max(.001, object_speed);
	
	float frameN = floor(iTime*60.);
	float frameAge = fract(iTime*60.);
	float frameStart = frameN/60.;
	float diskA = object_rot;
	vec2 diskC = vec2(-orbit, 0.);
	pR(diskC, object_rot);
	float diskAmt = 0.;
	if (video_motion_blur == 0) {
		diskAmt = 1.-smoothstep(uRad, uRad+1./iRes.y, length(p - diskC));
	} else if (video_motion_blur == 1) {
		diskAmt = screenDiskTrad(p, frameN/60., speed);
	} else if (video_motion_blur == 2) {
		diskAmt = screenDiskCos(p, frameN/60., speed);
	}
	vec2 gridP = abs(mod(p, .16) - vec2(.08));
	float gridAmt = 1.-smoothstep(.6/iRes.x, 1.6/iRes.x, gridP.x);
	gridAmt = max(gridAmt, 1.-smoothstep(.6/iRes.y, 1.6/iRes.y, gridP.y));
	vec3 col = vec3(0.);
	col = mix(col, gridColor, gridAmt);
	col = mix(col, diskColor, diskAmt);
	fragColor = vec4(col, 1.0);
}


void main(void)
{
	vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
	mainImage(color, gl_FragCoord.xy);
	gl_FragColor = color;
}
