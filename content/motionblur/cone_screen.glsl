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
uniform float time; //dspnote param: 0 - 0.1 (s)
uniform float object_speed; //dspnote param: 0 - 40, 10 (rad/s)

const float orbit = .2;
const float uRad = .1;
const float uniDensMul = 1.;
vec3 diskColor = vec3(.8, .9, 1.);
vec3 dashColor = vec3(1., .2, .2);
vec3 vBarColor = vec3(.9, .9, .9);

void pR(inout vec2 p, float a) {
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

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

float photoDiskNoBlur(vec2 p, float diskA, float frameStart) {
	vec2 diskC = vec2(-orbit, 0.);
	pR(diskC, frameStart*object_speed);
	float amt = 1.-smoothstep(uRad, uRad+1./iRes.y, length(p - diskC));

	// What time interval did this frame occur in?
	// Integrate the weighting function over this time interval.
	float ret = amt*weight_lr(time-frameStart, time-frameStart+1./60.);
	return ret;
}

float diskNoBlur(vec2 p, vec2 diskC, float frameN, float speed, bool screen) {
	float diskTot = 0.;
	if (screen) {
		diskTot = 1.-smoothstep(uRad, uRad+1./iRes.y, length(p - diskC));
	} else {
		for (int i=0; i<10; i++) {
			float frame2N = frameN - float(i);
			float frame2Start = frame2N/60.;
			float diskA2 = frame2Start*speed;
			diskTot += photoDiskNoBlur(p, diskA2, frame2Start);
		}
	}
	return diskTot;
}

float screenDiskTrad(vec2 p, float frameStart, float speed) {
	vec2 pol = vec2(length(p.xy), atan(p.y, p.x));
	pol.y = mod(pol.y + frameStart*speed, PI*2.)-PI;
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

float photoDiskTrad(vec2 p, float diskA, float frameStart) {
	vec2 diskC = vec2(-orbit, 0.);
	pR(diskC, frameStart*object_speed);
	float amt = screenDiskTrad(p, frameStart, max(.001, object_speed));

	// What time interval did this frame occur in?
	// Integrate the weighting function over this time interval.
	float ret = amt*weight_lr(time-frameStart, time-frameStart+1./60.);
	return ret;
}

float diskTradBlur(vec2 p, vec2 diskC, float frameN, float speed, bool screen) {
	float diskTot = 0.;
	if (screen) {
		diskTot = screenDiskTrad(p, frameN/60., speed);
	} else {
		for (int i=0; i<10; i++) {
			float frame2N = frameN - float(i);
			float frame2Start = frame2N/60.;
			float diskA2 = frame2Start*speed;
			diskTot += photoDiskTrad(p, diskA2, frame2Start);
		}
	}
	return diskTot;
}

float screenDiskCos(vec2 p, float frameStart, float speed) {
	vec2 pol = vec2(length(p.xy), atan(p.y, p.x));
	pol.y = mod(pol.y + frameStart*speed, PI*2.)-PI;
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

float photoDiskCos(vec2 p, float diskA, float frameStart) {
	vec2 diskC = vec2(-orbit, 0.);
	pR(diskC, frameStart*object_speed);
	float amt = screenDiskCos(p, frameStart, max(.001, object_speed));

	// What time interval did this frame occur in?
	// Integrate the weighting function over this time interval.
	float ret = amt*weight_lr(time-frameStart, time-frameStart+1./60.);
	return ret;
}

float diskCosBlur(vec2 p, vec2 diskC, float frameN, float speed, bool screen) {
	float diskTot = 0.;
	if (screen) {
		diskTot = screenDiskCos(p, frameN/60., speed);
	} else {
		for (int i=0; i<10; i++) {
			float frame2N = frameN - float(i);
			float frame2Start = frame2N/60.;
			float diskA2 = frame2Start*speed;
			diskTot += photoDiskCos(p, diskA2, frame2Start);
		}
	}
	return diskTot;
}

float dash(vec2 p) {
	vec2 pol = vec2(length(p), atan(p.y, p.x));
	float line = 1. - smoothstep(1., 2., abs(pol.x - uRad)*iRes.y);
	line *= smoothstep(.05, .07, abs(mod(pol.y/PI, .2)-.1));
	return line;
}

void mainImage(inout vec4 fragColor, in vec2 fragCoord)
{
	vec2 ratio = vec2(iRes.x/iRes.y, 1.);
	vec2 p = fragCoord/iRes.xy-0.5;
	vec2 p2 = ratio * vec2(mod(p.x, .5)-.25, p.y);
	p *= ratio;
	float speed = max(.001, object_speed);
	
	float frameN = floor(time*60.);
	float frameAge = fract(time*60.);
	float frameStart = frameN/60.;
	float diskA = frameStart*speed;
	vec2 diskC = vec2(-orbit, 0.);
	pR(diskC, frameStart*speed);
	float diskAmt = 0.;
	if (video_motion_blur == 0) {
		diskAmt = diskNoBlur(p2, diskC, frameN, speed, p.x < 0.);
	} else if (video_motion_blur == 1) {
		diskAmt = diskTradBlur(p2, diskC, frameN, speed, p.x < 0.);
	} else if (video_motion_blur == 2) {
		diskAmt = diskCosBlur(p2, diskC, frameN, speed, p.x < 0.);
	}
	vec3 col = vec3(0.);
	col = mix(col, diskColor, diskAmt);
	if (p.x > 0.) col = mix(col, dashColor, dash(p2 - diskC));
	col = mix(col, vBarColor, 1. - smoothstep(3., 4., abs(p.x*iRes.x)));

	fragColor = vec4(col, 1.0);
}


void main(void)
{
	vec4 color = vec4(0.0, 0.0, 0.0, 1.0);
	mainImage(color, gl_FragCoord.xy);
	gl_FragColor = color;
}
