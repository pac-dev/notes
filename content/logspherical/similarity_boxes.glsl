/*
Log-spherical scene with preservation of shapes (similarity).

As before, let's first imagine the theoretical steps needed to create this
scene in traditional 3D:
1. Define geometry within the limits of a spherical shell, our prototile
2. Apply the forward log-spherical map, giving a deformed rectangular prototile
3. Apply a regular tiling on the prototile
4. Apply the inverse log-spherical map, bending the tiles back into shells

And reverse all the steps to create a distance function:
1. Apply the forward log-spherical map to the current 3D coordinates
2. Use fract() to turn tiled coordinates into single-tile coordinates
3. Apply the inverse log-spherical map to the coordinates
4. Return distance for a prototile

More details in sdf().
*/

precision mediump float;
#define M_PI 3.1415926535897932384626433832795
#define AA 2

// Inputs
varying vec2 iUV;
uniform float iTime;
uniform vec2 iRes;

// These lines are parsed by dspnote to generate sliders
uniform float density; //dspnote param: 1 - 5, 2
uniform float side; //dspnote param: 0.2 - 0.6, 0.5
uniform float twist; //dspnote param: 0 - 1

float shorten = 1.14;
float dens, idens, stepZoom;

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

float sdCappedCylinder( vec3 p, vec2 h )
{
	vec2 d = abs(vec2(length(p.xz),p.y)) - h;
	return min(max(d.x,d.y),0.0) + length(max(d,0.0));
}

float sdCone( vec3 p, vec2 c )
{
	// c must be normalized
	float q = length(p.xz);
	return dot(c,vec2(q,p.y));
}

// Axis rotation taken from tdhooper
void pR(inout vec2 p, float a) {
	p = cos(a)*p + sin(a)*vec2(p.y, -p.x);
}

// Object placement depends on the density and is lazily hardcoded.
// Objects should be inside the spherical shell reference tile
// (ie. between its inner and outer spheres)
vec2 hiddenConeBottom = normalize(vec2(1.0, 0.55));
vec2 hiddenConeSides;
vec3 floorPos = vec3(0.0, 1.125, 0.0);

float layer(in vec3 p, in float twost)
{
	float ret = sdCappedCylinder(p+floorPos, vec2(0.6, 0.03));
	pR(p.yz, twost);
	p.x = abs(p.x) - 1.25;
	ret = min(ret, sdBox(p, vec3(side)));
	ret = max(-sdBox(p, vec3(side*2.0, side*0.9, side*0.9 )), ret);
	return ret;
}

float sdf(in vec3 pin)
{
	// Apply the forward log-spherical map (shell tiles -> box tiles)
	float r = length(pin);
	vec3 p = vec3(log(r), acos(pin.z / length(pin)), atan(pin.y, pin.x));

	// Apply rho-translation, which yields zooming
	p.x -= iTime*0.2;

	// find the scaling factor for the current tile
	float xstep = floor(p.x*dens) + (iTime*0.2)*dens;
	
	// Turn tiled coordinates into single-tile coordinates
	p.x = mod(p.x, idens);

	// Apply inverse log-spherical map (box tile -> shell tile)
	p = ilogspherical(p);
	
	// Get distance to geometry in this and adjacent shells
	float ret = layer(p, xstep*twist);
	ret = min(ret, layer(p/stepZoom, (xstep+1.0)*twist)*stepZoom);

	// Compensate for scaling applied so far
	ret = ret * exp(xstep*idens) / shorten;
	
	// Compensate for discontinuities in the field by adding some hidden
	// geometry to bring rays into the right shells
	float co = sdCone(pin, hiddenConeBottom);
	if (co < 0.015) co = ret;
	ret = min(ret, co);
	pin.x = -abs(pin.x);
	co = sdCone(pin.yxz, hiddenConeSides);
	if (co < 0.015) co = ret;
	ret = min(ret, co);

	return ret;
}

vec3 step2color(in float s)
{
	return vec3(
		abs(sin(s*23.0))*0.3, 
		abs(sin(s*13.0+7.0))*0.3, 
		abs(sin(s*19.0+5.0))*0.03
	);
}

vec3 color(in vec3 p)
{
	// If shell contents don't overlap, 
	// we can color per-shell by simply checking the rho value
	/*
	float rho = log(length(p)) - iTime*0.2;
	rho = floor(rho*dens);
	return vec3(
		abs(sin(x*23.0))*0.3, 
		abs(sin(x*13.0+7.0))*0.3, 
		abs(sin(x*19.0+5.0))*0.03
	);
	*/

	// If shell contents do overlap, we need to repeat a lot of sdf() ops
	float r = length(p);
	p = vec3(log(r), acos(p.z / r), atan(p.y, p.x));
	p.x -= iTime*0.2;
	float ofs = (iTime*0.2)*dens;
	float xstep = floor(p.x*dens) + ofs;
	p.x = fract(p.x*dens)*idens;
	p = ilogspherical(p);
	float sdf = layer(p, xstep*twist);
	if (sdf < 0.03) return step2color(xstep-ofs);
	sdf = min(sdf, layer(p/stepZoom, (xstep+1.0)*twist)*stepZoom);
	if (sdf < 0.03) return step2color(xstep+1.0-ofs);
	return vec3(0.);
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

	// inverse density, and the resulting zoom between each recursion level
	dens = density;
	idens = 1.0/dens;
	stepZoom = exp(idens);
	hiddenConeSides = normalize(vec2(1.0, side * 1.3));

	vec2 fragCoord = iUV*iRes;

	 // camera movement	
	float an = 0.1*iTime + 7.0;
	float cy = 1.+sin(an*2.+1.6)*0.8;
	vec3 ro = vec3(1.0*cos(an), cy, 1.0*sin(an));
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
			col = color(pos)*amb + color(pos)*dif;
		}

		// fog
		col = mix(col, bg, smoothstep(0.55+cy, 1.5+cy, t));

		// gamma        
		col = sqrt( col );
		tot += col;
	#if AA>1
	}
	tot /= float(AA*AA);
	#endif

	gl_FragColor = vec4(tot, 1.0);
}
