/*
Inverse log-polar map applied to 2 dimensions of a 3D scene.

Uses a similar process to logpolar_polka.glsl. See the `sdf` function.
*/

precision mediump float;
#define M_PI 3.1415926535897932384626433832795
#define AA 2

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote to generate sliders
uniform float camera_y; //dspnote param: 0.5 - 3
uniform float rho_offset; //dspnote param: 0 - 10
uniform float density; //dspnote param: 5 - 50, 13
uniform float radius; //dspnote param: 0.05 - 1, 0.9

float height = 0.01;
float lpscale;

float sdf(in vec3 p3d)
{
	// Choose 2 dimensions and apply the forward log-polar map
	vec2 p = p3d.xz;
	float r = length(p);
	p = vec2(log(r), atan(p.y, p.x));

	// Scale everything so it will fit nicely in the ]-pi,pi] interval
	p *= lpscale;
	float mul = r/lpscale;

	// Apply rho-translation, which yields zooming
	p.x -= rho_offset + iTime*lpscale*0.23;
	
	// Turn tiled coordinates into single-tile coordinates
	p = mod(p, 2.0) - 1.0;

	// Get rounded cylinder distance, using the original Y coordinate shrunk
	// proportionally to the other dimensions
	return (length(vec3(p, max(0.0, p3d.y/mul))) - radius) * mul;
}

vec3 color(in vec3 p)
{
	vec3 top = vec3(0.3, 0.4, 0.5);
	vec3 ring = vec3(0.6, 0.04, 0.0);
	vec3 bottom = vec3(0.3, 0.3, 0.3);
	bottom = mix(vec3(0.0), bottom, min(1.0, -1.0/(p.y*20.0-1.0)));
	vec3 side = mix(bottom, ring, smoothstep(-height-0.001, -height, p.y));
	return mix(side, top, smoothstep(-0.01, 0.0, p.y));
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

// Based on http://iquilezles.org/www/articles/raymarchingdf/raymarchingdf.htm
void main() {
	lpscale = floor(density)/M_PI;
	vec2 fragCoord = iUV*iRes;

	 // camera movement	
	float an = 0.04*iTime;
	vec3 ro = vec3(1.0*cos(an), camera_y, 1.0*sin(an));
	vec3 ta = vec3( 0.0, 0.0, 0.0 );
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
		const float tmax = 10.0;
		float t = 0.0;
		for( int i=0; i<256; i++ )
		{
			vec3 pos = ro + t*rd;
			float h = sdf(pos);
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
			col = color(pos)*amb + color(pos)*dif;
		}

		// gamma        
		col = sqrt( col );
		tot += col;
	#if AA>1
	}
	tot /= float(AA*AA);
	#endif

	gl_FragColor = vec4(tot, 1.0);
}
