/*
Includes some SDF and raymarching functions by Inigo Quilez: http://iquilezles.org/
*/

precision mediump float;
#define M_PI 3.1415926535897932384626433832795
#define AA 2

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

float dtime;
float peak = 0.25;
float base_cubsz = 0.96;
float spiral_on = 0.;
float cola = 0.26; // 0.45
float colb = 0.65; // 0.9
float colz = 0.19; // 0.1
float shortrange = 0.22;
float shortmax = 1.5;

float camera_y = pow(sin(dtime*0.2), 3.)*0.2+0.7;
float spiral = step(0.5, spiral_on)*atan(3./4.);

// From http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdBox( vec3 p, vec3 b )
{
	vec3 d = abs(p) - b;
	return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

// Axis rotation taken from tdhooper
void pR(inout vec2 p, float a) {
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// spiked surface distance (h >= 0)
float sdSpike2D(vec2 p, float h)
{
	float d = p.y - (h*0.1)/(abs(p.x)+0.1);
	d = min(d, length(p - vec2(0, min(h, p.y))));
	float d2 = abs(p.x) - ((h*0.1)-0.1*p.y)/p.y;
	if (p.y<h && d>0.0)
		d = min(d, d2);
	return d;
}

// float density;
// float lpscale;
// float trans;
float abPos;
float densA;
float densB;
float scaleA;
float scaleB;

vec4 tile(in vec3 pin, out float cubsz)
{
	float erho = length(pin.xz);
	float lpscale = mix(scaleA, scaleB, smoothstep(0., 0.1, erho-abPos));
	vec3 p = vec3(
		log(erho), 
		(pin.y-peak*0.1/(erho+0.1))/erho, 
		atan(pin.z, pin.x)
	);
	p *= lpscale;
	//p.z -= p.x*0.5*flex_spiral;
	p.x -= dtime*2.0;

	// todo: approx sqrt from the existing log value
	float absrc = sin(sqrt(erho)-dtime*0.5-M_PI)*0.5+0.5;
	float cubrot = sin(p.x*0.3);
	cubrot = smoothstep(0.65, 0.85, absrc);
	cubsz = base_cubsz * (sin(p.x*0.1)*0.5+0.5) * 0.6 + 0.2;
	cubsz = mix(cubsz, 0.96, smoothstep(0.7, 1.0, absrc));

	pR(p.xz, spiral);
	p.xz = fract(p.xz*0.5) * 2.0 - 1.0;
	pR(p.xy, cubrot);
	return vec4(p, erho/lpscale);
}

float sdf(in vec3 pin)
{
	//todo don't do this twice
	float erho = length(pin.xz);
	float density = mix(densA, densB, smoothstep(0., 0.1, erho-abPos));
	float cubsz;
	vec4 tiled = tile(pin, cubsz);
	float ret = sdBox(tiled.xyz, vec3(cubsz));
	ret = ret*tiled.w;

	float pkofs = 3.3 * length(pin.xz) * cubsz / density;
	float pk = sdSpike2D(vec2(length(pin.xz), pin.y), peak) - pkofs;
	if (pk < 0.002) pk = ret;
	ret = min(ret, pk);

	float shorten = length(pin - vec3(0., 0.25, 0.));
	shorten = 1. + shortmax*(1.-smoothstep(0., shortrange, shorten));
	ret /= shorten;

	return ret;
}

vec3 colr(in vec3 pin)
{
	float a = cola;
	float b = colb;
	float z = colz;
	// float a = 0.6;
	// float b = 0.4;
	// float z = 0.;
	float cubsz;
	vec3 p = tile(pin, cubsz).xyz;
	if (p.x > abs(p.y) && p.x > abs(p.z)) return vec3(z,a,b);
	if (p.x < -abs(p.y) && p.x < -abs(p.z)) return vec3(z,b,a)*0.7;
	if (p.z > abs(p.x) && p.z > abs(p.y)) return vec3(z,a,a);
	if (p.z < -abs(p.x) && p.z < -abs(p.y)) return vec3(b*0.5,z,a);
	return vec3(b,b,a);
}

// Adapted from http://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
vec3 calcNormal(in vec3 pos)
{
	vec2 e = vec2(1.0,-1.0)*0.5773;
	const float eps = 0.0005;
	return normalize(
		e.xyy*sdf(pos + e.xyy*eps) + 
		e.yyx*sdf(pos + e.yyx*eps) + 
		e.yxy*sdf(pos + e.yxy*eps) + 
		e.xxx*sdf(pos + e.xxx*eps)
	);
}

float longStep = M_PI*4.;
float fullCycle = longStep*3.;

float densStep(float x)
{
	float fullMod = fract(x/fullCycle)*3.;
	if (fullMod > 2.) return 45.;
	else if (fullMod > 1.) return 25.;
	else return 15.;
}

// Based on http://iquilezles.org/www/articles/raymarchingdf/raymarchingdf.htm
void main() {
	dtime = iTime+1.8;
	float ltime = dtime + M_PI*6.3;
	abPos = smoothstep(0.45, 0.6, fract(ltime/longStep))*2.2-0.2;
	densA = densStep(ltime);
	densB = densStep(ltime-longStep);
	scaleA = floor(densA)/M_PI;
	scaleB = floor(densB)/M_PI;

	vec2 fragCoord = iUV*iRes;

	 // camera movement	
	vec3 ro = vec3(0., camera_y, 1.);
	vec3 ta = vec3(0.0, 0.0, 0.0);
	// camera matrix
	vec3 ww = normalize(ta - ro);
	vec3 uu = normalize(cross(ww,vec3(0.0,1.0,0.0)));
	vec3 vv = normalize(cross(uu,ww));

	vec3 tot = vec3(0.0);
	
	#if AA>1
	for(int m=0; m<AA; m++)
	for(int n=0; n<AA; n++)
	{
		// pixel coordinates
		vec2 o = vec2(float(m),float(n)) / float(AA) - 0.5;
		vec2 p = (-iRes.xy + 2.0*(fragCoord+o))/iRes.y;
		#else    
		vec2 p = (-iRes.xy + 2.0*fragCoord)/iRes.y;
		#endif

		// create view ray
		vec3 rd = normalize(p.x*uu + p.y*vv + 3.5*ww); // fov

		// raymarch
		const float tmax = 3.0;
		float t = 0.0;
		for(int i=0; i<256; i++)
		{
			vec3 pos = ro + t*rd;
			float h = sdf(pos);
			if( h<0.0001 || t>tmax ) break;
			t += h;
		}
	
		// shading/lighting	
		vec3 bg = vec3(0.1, 0.15, 0.2)*0.3;
		vec3 col = bg;
		if(t<tmax)
		{
			vec3 pos = ro + t*rd;
			vec3 nor = calcNormal(pos);
			float dif = clamp( dot(nor,vec3(0.57703)), 0.0, 1.0 );
			float amb = 0.5 + 0.5*dot(nor,vec3(0.0,1.0,0.0));
			col = colr(pos)*amb + colr(pos)*dif;
		}
		// fog
		col = mix(col, bg, smoothstep(2., 3., t));

		// gamma        
		col = sqrt(col);
		tot += col;
	#if AA>1
	}
	tot /= float(AA*AA);
	#endif

	gl_FragColor = vec4(tot, 1.0);
}
