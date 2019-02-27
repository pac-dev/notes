/*
Visualization of sdf discontinuities under the recursive shell tiling.
*/

precision mediump float;
#define M_PI 3.1415926535897932384626433832795
#define AA 2

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote to generate sliders
uniform float twist; //dspnote param: 0 - 1.57

float shorten = 1.14;

// Inverse log-spherical map
vec3 ilogspherical(in vec3 p)
{
	float erho = exp(p.x);
	float sintheta = sin(p.y);
	return vec3(
		erho * sintheta * cos(p.z),
		erho * sintheta * sin(p.z),
		erho * cos(p.y)
	);
}

// Primitives from http://www.iquilezles.org/www/articles/distfunctions/distfunctions.htm
float sdBox( vec3 p, vec3 b )
{
	vec3 d = abs(p) - b;
	return min(max(d.x,max(d.y,d.z)),0.0) + length(max(d,0.0));
}

// Axis rotation taken from tdhooper
void pR(inout vec2 p, float a) {
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// density, its inverse, and the resulting zoom between each recursion level
float dens = 2.0;
float idens = 1.0/dens;
float stepZoom = exp(idens);

float layer(in vec3 p, in float twost)
{
	pR(p.xy, -twost);
	p.x = abs(p.x) - 1.25;
	float ret = sdBox(p, vec3(0.1));
	return ret;
}

float sdfScene(in vec3 pin)
{
	// Apply the forward log-spherical map (shell tiles -> box tiles)
	float erho = length(pin); // (Store e^rho for reuse)
	vec3 p = vec3(log(erho), acos(pin.z / length(pin)), atan(pin.y, pin.x));

	// Apply rho-translation, which yields zooming
	p.x -= iTime*0.2;

	// find the scaling factor for the current tile
	float xstep = floor(p.x*dens) + (iTime*0.2)*dens;
	
	// Turn tiled coordinates into single-tile coordinates
	p.x = fract(p.x*dens)*idens;

	// Apply inverse log-spherical map (box tile -> shell tile)
	p = ilogspherical(p);
	
	// Get distance to geometry in this and adjacent shells
	float ret = layer(p, xstep*twist);
	ret = min(ret, layer(p/stepZoom, (xstep+1.0)*twist)*stepZoom);

	// Compensate for scaling applied so far
	ret = ret * exp(xstep*0.5) / shorten;
	return ret;
}

float sdf(in vec3 p)
{
	float ret = sdfScene(p);
	ret = min(ret, p.z);
	return ret;
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

float aaFract(float x, float aa) { // aa: 0-1
	x = fract(x+aa*0.9);
	x += 1.0 - smoothstep(0.0, aa, x) - aa*0.5;
	return x;
}

vec3 distanceGradient(float d, float aa) {
	vec3 ret = vec3(aaFract(abs(d*3.0), aa));
	ret.x = 1. - smoothstep(-0.5*aa, 0.5*aa, d);
	ret *= exp(-1.0 * abs(d));
	return ret;
}

vec3 color(in vec3 p, in vec3 nor)
{
	if (abs(p.z)<0.0005)
		return distanceGradient(sdfScene(p)*12., 0.01);
	// Shell contents don't overlap, so we can color per-shell simply by
	// checking the rho value
	float rho = log(length(p)) - iTime*0.2;
	rho = floor(rho*dens);
	return vec3(
		abs(sin(rho*23.0))*0.3, 
		abs(sin(rho*13.0+7.0))*0.3, 
		abs(sin(rho*19.0+5.0))*0.03
	);
}

// Based on http://iquilezles.org/www/articles/raymarchingdf/raymarchingdf.htm
void main() {
	vec2 fragCoord = iUV*iRes;

	 // camera movement	
	float an = 0.1*iTime + 7.0;
	vec3 ro = vec3(1.0*cos(an), 0.5, 1.0*sin(an));
	vec3 ta = vec3( 0.0, 0.0, 0.0 );
	// camera matrix
	vec3 ww = normalize(ta - ro);
	vec3 uu = normalize(cross(ww,vec3(0.0,1.0,0.0)));
	vec3 vv = normalize(cross(uu,ww));

	vec3 bg = vec3(0.48, 0.48, 0.8);
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
		for( int i=0; i<60; i++ )
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
			col = color(pos, nor)*amb + color(pos, nor)*dif;
		}

		// fog
		col = mix(col, bg, smoothstep(20.0, 30.0, t));

		// gamma        
		col = sqrt( col );
		tot += col;
	#if AA>1
	}
	tot /= float(AA*AA);
	#endif

	gl_FragColor = vec4(tot, 1.0);
}
