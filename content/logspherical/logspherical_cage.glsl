/*
Inverse log-spherical map applied to a 3D grid of cylinders.

Similar to the 2D version, let's first draft out the theoretical steps needed
to create this scene in traditional 3D:
1. Define the geometry for a cross made of two cylinders
2. Apply a regular tiling, resulting in a repeated grid of cylinders
3. Apply the inverse log-spherical map

And reverse all the steps to create a distance function:
1. Apply the forward log-spherical map to the current 3D coordinates
2. Use fract() to turn tiled coordinates into single-tile coordinates
3. Return distance using the equation for a cross of cylinders

This distance function is then used with raymarching.
*/

precision mediump float;
#define M_PI 3.1415926535897932384626433832795
#define AA 2

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote to generate sliders
uniform float thickness; //dspnote param: 0.01 - 0.1
uniform float density; //dspnote param: 6 - 16, 8
uniform float rho_offset; //dspnote param: 0 - 10
uniform float camera_y; //dspnote param: 0.5 - 2

float shorten = 1.26;
float height = 0.01;
float lpscale = floor(density)/M_PI;

float map(in vec3 p)
{
	// Apply the forward log-spherical map
	float r = length(p);
	p = vec3(log(r), acos(p.z / length(p)), atan(p.y, p.x));

	// Get a scaling factor to compensate for pinching at the poles
	// (there's probably a better way of doing this)
	float xshrink = 1.0/(abs(p.y-M_PI)) + 1.0/(abs(p.y)) - 1.0/M_PI;

	// scale to fit in the ]-pi,pi] interval
	p *= lpscale;

	// Apply rho-translation, which yields zooming
	p.x -= rho_offset + iTime;
	
	// Turn tiled coordinates into single-tile coordinates
	p = fract(p*0.5) * 2.0 - 1.0;
	p.x *= xshrink;

	// Get cylinder distance
	float ret = length(p.xz) - thickness;
	ret = min(ret, length(p.xy) - thickness);

	// Compensate for all the scaling that's been applied so far
	float mul = r/lpscale/xshrink;
	return ret * mul / shorten;
}

vec3 color(in vec3 pos, in vec3 nor)
{
	return vec3(0.5, 0.5, 0.7);
}

// Adapted from http://iquilezles.org/www/articles/normalsSDF/normalsSDF.htm
vec3 calcNormal(in vec3 pos)
{
	vec2 e = vec2(1.0,-1.0)*0.5773;
	const float eps = 0.0005;
	return normalize(
		e.xyy*map(pos + e.xyy*eps) + 
		e.yyx*map(pos + e.yyx*eps) + 
		e.yxy*map(pos + e.yxy*eps) + 
		e.xxx*map(pos + e.xxx*eps)
	);
}

// Based on http://iquilezles.org/www/articles/raymarchingdf/raymarchingdf.htm
void main() {
	vec2 fragCoord = iUV*iRes;

	 // camera movement	
	float an = 0.1*iTime + 7.0;
	vec3 ro = vec3(1.0*cos(an), camera_y, 1.0*sin(an));
	vec3 ta = vec3( 0.0, 0.0, 0.0 );
	// camera matrix
	vec3 ww = normalize(ta - ro);
	vec3 uu = normalize(cross(ww,vec3(0.0,1.0,0.0)));
	vec3 vv = normalize(cross(uu,ww));

	vec3 bg = vec3(0.1, 0.15, 0.2)*0.3;
	vec3 tot = bg;
	
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
		const float tmax = 3.5;
		float t = 0.0;
		for( int i=0; i<80; i++ )
		{
			vec3 pos = ro + t*rd;
			float h = map(pos);
			if( h<0.0001 || t>tmax ) break;
			t += h;
		}
	
		// shading/lighting	
		vec3 col = vec3(0.0);
		if( t<tmax )
		{
			vec3 pos = ro + t*rd;
			vec3 nor = calcNormal(pos);
			float dif = clamp( dot(nor,vec3(0.57703)), 0.0, 1.0 );
			float amb = 0.5 + 0.5*dot(nor,vec3(0.0,1.0,0.0));
			col = color(pos, nor)*amb + color(pos, nor)*dif;
		}

		// fog
		col = mix(col, bg, smoothstep(camera_y-0.2, camera_y+1.5, t));

		// gamma        
		col = sqrt( col );
		tot += col;
	#if AA>1
	}
	tot /= float(AA*AA);
	#endif

	gl_FragColor = vec4(tot, 1.0);
}
