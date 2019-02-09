//Anti-Aliasing Part Version v1.0
//From http://www.iryoku.com/smaa/

//This file is part of Basic Shader.
//Read LICENSE First at composite.fsh

//AA Properties
#define LOW    0
#define MEDIUM 1
#define HIGH   2
#define ULTRA  3

#define QUALITY MEDIUM //[LOW MEDIUM HIGH ULTRA]

#if QUALITY == LOW
#define SMAA_THRESHOLD 0.15
#define SMAA_MAX_SEARCH_STEPS 4
#define SMAA_DISABLE_DIAG_DETECTION
#define SMAA_DISABLE_CORNER_DETECTION
#elif QUALITY == MEDIUM
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 8
#define SMAA_DISABLE_DIAG_DETECTION
#define SMAA_DISABLE_CORNER_DETECTION
#elif QUALITY == HIGH
#define SMAA_THRESHOLD 0.1
#define SMAA_MAX_SEARCH_STEPS 16
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#define SMAA_CORNER_ROUNDING 25
#elif QUALITY == ULTRA
#define SMAA_THRESHOLD 0.05
#define SMAA_MAX_SEARCH_STEPS 32
#define SMAA_MAX_SEARCH_STEPS_DIAG 16
#define SMAA_CORNER_ROUNDING 25
#endif

#ifndef SMAA_THRESHOLD
#define SMAA_THRESHOLD 0.1
#endif

#ifndef SMAA_DEPTH_THRESHOLD
#define SMAA_DEPTH_THRESHOLD (0.1 * SMAA_THRESHOLD)
#endif

#ifndef SMAA_MAX_SEARCH_STEPS
#define SMAA_MAX_SEARCH_STEPS 16
#endif

#ifndef SMAA_MAX_SEARCH_STEPS_DIAG
#define SMAA_MAX_SEARCH_STEPS_DIAG 8
#endif

#ifndef SMAA_CORNER_ROUNDING
#define SMAA_CORNER_ROUNDING 25
#endif

#ifndef SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR
#define SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR 2.0
#endif

#ifndef SMAA_PREDICATION
#define SMAA_PREDICATION 0
#endif

#ifndef SMAA_PREDICATION_THRESHOLD
#define SMAA_PREDICATION_THRESHOLD 0.01
#endif

#ifndef SMAA_PREDICATION_SCALE
#define SMAA_PREDICATION_SCALE 2.0
#endif

#ifndef SMAA_PREDICATION_STRENGTH
#define SMAA_PREDICATION_STRENGTH 0.4
#endif

#ifndef SMAA_REPROJECTION
#define SMAA_REPROJECTION 0
#endif

#ifndef SMAA_REPROJECTION_WEIGHT_SCALE
#define SMAA_REPROJECTION_WEIGHT_SCALE 30.0
#endif

#ifndef SMAA_AREATEX_SELECT
#define SMAA_AREATEX_SELECT(sample) sample.rg
#endif

#ifndef SMAA_SEARCHTEX_SELECT
#define SMAA_SEARCHTEX_SELECT(sample) sample.r
#endif

#ifndef SMAA_DECODE_VELOCITY
#define SMAA_DECODE_VELOCITY(sample) sample.rg
#endif

#define SMAA_AREATEX_MAX_DISTANCE 16
#define SMAA_AREATEX_MAX_DISTANCE_DIAG 20
#define SMAA_AREATEX_PIXEL_SIZE (1.0 / vec2(160.0, 560.0))
#define SMAA_AREATEX_SUBTEX_SIZE (1.0 / 7.0)
#define SMAA_SEARCHTEX_SIZE vec2(66.0, 33.0)
#define SMAA_SEARCHTEX_PACKED_SIZE vec2(64.0, 16.0)
#define SMAA_CORNER_ROUNDING_NORM (float(SMAA_CORNER_ROUNDING) / 100.0)

#define SMAASampleLevelZero(tex, coord) texture2DLod(tex, coord, 0.0)
#define SMAASampleLevelZeroPoint(tex, coord) texture2DLod(tex, coord, 0.0)
#define SMAASampleLevelZeroOffset(tex, coord, offset) texture2DLodOffset(tex, coord, 0.0, offset)
#define SMAASample(tex, coord) texture2D(tex, coord)
#define SMAASamplePoint(tex, coord) texture2D(tex, coord)
#define SMAASampleOffset(tex, coord, offset) texture2D(tex, coord, offset)
#define lerp(a, b, t) mix(a, b, t)
#define saturate(a) clamp(a, 0.0, 1.0)
#define mad(a, b, c) (a * b + c)

vec4 SMAA_RT_METRICS = vec4(1.0 / viewWidth, 1.0 / viewHeight, viewWidth, viewHeight);

vec2 getAAEdge(vec2 texcoord) {

    vec2 threshold = vec2(SMAA_THRESHOLD, SMAA_THRESHOLD);

    // Calculate color deltas:
    vec4 delta;
    vec3 C = pow(texture2D(gcolor, texcoord).rgb, vec3(2.2f));

    vec3 Cleft = pow(texture2D(gcolor, offset[0].xy).rgb, vec3(2.2f));
    vec3 t = abs(C - Cleft);
    delta.x = max(max(t.r, t.g), t.b);

    vec3 Ctop  = pow(texture2D(gcolor, offset[0].zw).rgb, vec3(2.2f));
    t = abs(C - Ctop);
    delta.y = max(max(t.r, t.g), t.b);

    // We do the usual threshold:
    vec2 edges = step(threshold, delta.xy);

    // Then discard if there is no edge:
    if (dot(edges, vec2(1.0, 1.0)) == 0.0) return vec2(0.0f);

    // Calculate right and bottom deltas:
    vec3 Cright = pow(texture2D(gcolor, offset[1].xy).rgb, vec3(2.2f));
    t = abs(C - Cright);
    delta.z = max(max(t.r, t.g), t.b);

    vec3 Cbottom  = pow(texture2D(gcolor, offset[1].zw).rgb, vec3(2.2f));
    t = abs(C - Cbottom);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the maximum delta in the direct neighborhood:
    vec2 maxDelta = max(delta.xy, delta.zw);

    // Calculate left-left and top-top deltas:
    vec3 Cleftleft  = pow(texture2D(gcolor, offset[2].xy).rgb, vec3(2.2f));
    t = abs(C - Cleftleft);
    delta.z = max(max(t.r, t.g), t.b);

    vec3 Ctoptop = pow(texture2D(gcolor, offset[2].zw).rgb, vec3(2.2f));
    t = abs(C - Ctoptop);
    delta.w = max(max(t.r, t.g), t.b);

    // Calculate the final maximum delta:
    maxDelta = max(maxDelta.xy, delta.zw);
    float finalDelta = max(maxDelta.x, maxDelta.y);

    // Local contrast adaptation:
    edges.xy *= step(finalDelta, SMAA_LOCAL_CONTRAST_ADAPTATION_FACTOR * delta.xy);

    return edges;
    
}

#ifdef SMAA_Calc

vec2 SMAADecodeDiagBilinearAccess(vec2 e) {

    // Bilinear access for fetching 'e' have a 0.25 offset, and we are
    // interested in the R and G edges:
    //
    // +---G---+-------+
    // |   x o R   x   |
    // +-------+-------+
    //
    // Then, if one of these edge is enabled:
    //   Red:   (0.75 * X + 0.25 * 1) => 0.25 or 1.0
    //   Green: (0.75 * 1 + 0.25 * X) => 0.75 or 1.0
    //
    // This function will unpack the values (mad + mul + round):
    // wolframalpha.com: round(x * abs(5 * x - 5 * 0.75)) plot 0 to 1
	
    e.r = e.r * abs(5.0 * e.r - 5.0 * 0.75);
    return round(e);
	
}

vec4 SMAADecodeDiagBilinearAccess(vec4 e) {
    e.rb = e.rb * abs(5.0 * e.rb - 5.0 * 0.75);
    return round(e);
}

void SMAAMovc(bvec2 cond, inout vec2 variable, vec2 value) {
    if (cond.x) variable.x = value.x;
    if (cond.y) variable.y = value.y;
}

void SMAAMovc(bvec4 cond, inout vec4 variable, vec4 value) {
    SMAAMovc(cond.xy, variable.xy, value.xy);
    SMAAMovc(cond.zw, variable.zw, value.zw);
}

vec2 SMAASearchDiag1(vec2 texcoord, vec2 dir, out vec2 e) {

    vec4 coord = vec4(texcoord, -1.0, 1.0);
    vec3 t = vec3(SMAA_RT_METRICS.xy, 1.0);
    while (coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) &&
           coord.w > 0.9) {
        coord.xyz = mad(t, vec3(dir, 1.0), coord.xyz);
        e = SMAASampleLevelZero(composite, coord.xy).rg;
        coord.w = dot(e, vec2(0.5, 0.5));
    }
    return coord.zw;
	
}

vec2 SMAASearchDiag2(vec2 texcoord, vec2 dir, out vec2 e) {

    vec4 coord = vec4(texcoord, -1.0, 1.0);
    coord.x += 0.25 * SMAA_RT_METRICS.x; // See @SearchDiag2Optimization
    vec3 t = vec3(SMAA_RT_METRICS.xy, 1.0);
	
    while (coord.z < float(SMAA_MAX_SEARCH_STEPS_DIAG - 1) &&
           coord.w > 0.9) {
        coord.xyz = mad(t, vec3(dir, 1.0), coord.xyz);

        // @SearchDiag2Optimization
        // Fetch both edges at once using bilinear filtering:
        e = SMAASampleLevelZero(composite, coord.xy).rg;
        e = SMAADecodeDiagBilinearAccess(e);

        // Non-optimized version:
        // e.g = SMAASampleLevelZero(composite, coord.xy).g;
        // e.r = SMAASampleLevelZeroOffset(composite, coord.xy, ivec2(1, 0)).r;

        coord.w = dot(e, vec2(0.5, 0.5));
    }
	
    return coord.zw;
	
}

vec2 SMAAAreaDiag(vec2 dist, vec2 e, float offset) {

    vec2 texcoord = mad(vec2(SMAA_AREATEX_MAX_DISTANCE_DIAG, SMAA_AREATEX_MAX_DISTANCE_DIAG), e, dist);

    // We do a scale and bias for mapping to texel space:
    texcoord = mad(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);

    // Diagonal areas are on the second half of the texture:
    texcoord.x += 0.5;

    // Move to proper place, according to the subpixel offset:
    texcoord.y += SMAA_AREATEX_SUBTEX_SIZE * offset;

    // Do it!
    return SMAA_AREATEX_SELECT(SMAASampleLevelZero(gaux3, texcoord));
	
}

vec2 SMAACalculateDiagWeights(vec2 texcoord, vec2 e, vec4 subsampleIndices) {

    vec2 weights = vec2(0.0, 0.0);

    // Search for the line ends:
    vec4 d;
    vec2 end;
    if (e.r > 0.0) {
        d.xz = SMAASearchDiag1(texcoord, vec2(-1.0,  1.0), end);
        d.x += float(end.y > 0.9);
    } else
        d.xz = vec2(0.0, 0.0);
    d.yw = SMAASearchDiag1(texcoord, vec2(1.0, -1.0), end);

    
    if (d.x + d.y > 2.0) { // d.x + d.y + 1 > 3
        // Fetch the crossing edges:
        vec4 coords = mad(vec4(-d.x + 0.25, d.x, d.y, -d.y - 0.25), SMAA_RT_METRICS.xyxy, texcoord.xyxy);
        vec4 c;
        c.xy = SMAASampleLevelZeroOffset(composite, coords.xy, ivec2(-1,  0)).rg;
        c.zw = SMAASampleLevelZeroOffset(composite, coords.zw, ivec2( 1,  0)).rg;
        c.yxwz = SMAADecodeDiagBilinearAccess(c.xyzw);

        // Merge crossing edges at each side into a single value:
        vec2 cc = mad(vec2(2.0, 2.0), c.xz, c.yw);

        // Remove the crossing edge if we didn't found the end of the line:
        SMAAMovc(bvec2(step(0.9, d.zw)), cc, vec2(0.0, 0.0));

        // Fetch the areas for this line:
        weights += SMAAAreaDiag(d.xy, cc, subsampleIndices.z);
    }

    // Search for the line ends:
    d.xz = SMAASearchDiag2(texcoord, vec2(-1.0, -1.0), end);
    if (SMAASampleLevelZeroOffset(composite, texcoord, ivec2(1, 0)).r > 0.0) {
        d.yw = SMAASearchDiag2(texcoord, vec2(1.0, 1.0), end);
        d.y += float(end.y > 0.9);
    } else
        d.yw = vec2(0.0, 0.0);

    
    if (d.x + d.y > 2.0) { // d.x + d.y + 1 > 3
        // Fetch the crossing edges:
        vec4 coords = mad(vec4(-d.x, -d.x, d.y, d.y), SMAA_RT_METRICS.xyxy, texcoord.xyxy);
        vec4 c;
        c.x  = SMAASampleLevelZeroOffset(composite, coords.xy, ivec2(-1,  0)).g;
        c.y  = SMAASampleLevelZeroOffset(composite, coords.xy, ivec2( 0, -1)).r;
        c.zw = SMAASampleLevelZeroOffset(composite, coords.zw, ivec2( 1,  0)).gr;
        vec2 cc = mad(vec2(2.0, 2.0), c.xz, c.yw);

        // Remove the crossing edge if we didn't found the end of the line:
        SMAAMovc(bvec2(step(0.9, d.zw)), cc, vec2(0.0, 0.0));

        // Fetch the areas for this line:
        weights += SMAAAreaDiag(d.xy, cc, subsampleIndices.w).gr;
    }

    return weights;
	
}

float SMAASearchLength(vec2 e, float offset) {

    // The texture is flipped vertically, with left and right cases taking half
    // of the space horizontally:
    vec2 scale = SMAA_SEARCHTEX_SIZE * vec2(0.5, -1.0);
    vec2 bias = SMAA_SEARCHTEX_SIZE * vec2(offset, 1.0);

    // Scale and bias to access texel centers:
    scale += vec2(-1.0,  1.0);
    bias  += vec2( 0.5, -0.5);

    // Convert from pixel coordinates to texcoords:
    // (We use SMAA_SEARCHTEX_PACKED_SIZE because the texture is cropped)
    scale *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;
    bias *= 1.0 / SMAA_SEARCHTEX_PACKED_SIZE;

    // Lookup the search texture:
    return SMAA_SEARCHTEX_SELECT(SMAASampleLevelZero(gaux4, mad(scale, e, bias)));
	
}

float SMAASearchXLeft(vec2 texcoord, float end) {

    vec2 e = vec2(0.0, 1.0);
    while (texcoord.x > end && 
           e.g > 0.8281 && // Is there some edge not activated?
           e.r == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(composite, texcoord).rg;
        texcoord = mad(-vec2(2.0, 0.0), SMAA_RT_METRICS.xy, texcoord);
    }

    float offset = mad(-(255.0 / 127.0), SMAASearchLength(e, 0.0), 3.25);
    return mad(SMAA_RT_METRICS.x, offset, texcoord.x);

}

float SMAASearchXRight(vec2 texcoord, float end) {

    vec2 e = vec2(0.0, 1.0);
    while (texcoord.x < end && 
           e.g > 0.8281 && // Is there some edge not activated?
           e.r == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(composite, texcoord).rg;
        texcoord = mad(vec2(2.0, 0.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(e, 0.5), 3.25);
    return mad(-SMAA_RT_METRICS.x, offset, texcoord.x);
	
}

float SMAASearchYUp(vec2 texcoord, float end) {

    vec2 e = vec2(1.0, 0.0);
    while (texcoord.y > end && 
           e.r > 0.8281 && // Is there some edge not activated?
           e.g == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(composite, texcoord).rg;
        texcoord = mad(-vec2(0.0, 2.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(e.gr, 0.0), 3.25);
    return mad(SMAA_RT_METRICS.y, offset, texcoord.y);
	
}

float SMAASearchYDown(vec2 texcoord, float end) {

    vec2 e = vec2(1.0, 0.0);
    while (texcoord.y < end && 
           e.r > 0.8281 && // Is there some edge not activated?
           e.g == 0.0) { // Or is there a crossing edge that breaks the line?
        e = SMAASampleLevelZero(composite, texcoord).rg;
        texcoord = mad(vec2(0.0, 2.0), SMAA_RT_METRICS.xy, texcoord);
    }
    float offset = mad(-(255.0 / 127.0), SMAASearchLength(e.gr, 0.5), 3.25);
    return mad(-SMAA_RT_METRICS.y, offset, texcoord.y);
	
}

vec2 SMAAArea(vec2 dist, float e1, float e2, float offset) {

    // Rounding prevents precision errors of bilinear filtering:
    vec2 texcoord = mad(vec2(SMAA_AREATEX_MAX_DISTANCE, SMAA_AREATEX_MAX_DISTANCE), round(4.0 * vec2(e1, e2)), dist);
    
    // We do a scale and bias for mapping to texel space:
    texcoord = mad(SMAA_AREATEX_PIXEL_SIZE, texcoord, 0.5 * SMAA_AREATEX_PIXEL_SIZE);

    // Move to proper place, according to the subpixel offset:
    texcoord.y = mad(SMAA_AREATEX_SUBTEX_SIZE, offset, texcoord.y);

    // Do it!
    return SMAA_AREATEX_SELECT(SMAASampleLevelZero(gaux3, texcoord));
	
}

void SMAADetectHorizontalCornerPattern(inout vec2 weights, vec4 texcoord, vec2 d) {

    #if !defined(SMAA_DISABLE_CORNER_DETECTION)
	
		vec2 leftRight = step(d.xy, d.yx);
		vec2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;
			 rounding /= leftRight.x + leftRight.y; // Reduce blending for pixels in the center of a line.

		vec2 factor = vec2(1.0, 1.0);
			 factor.x -= rounding.x * SMAASampleLevelZeroOffset(composite, texcoord.xy, ivec2(0,  1)).r;
			 factor.x -= rounding.y * SMAASampleLevelZeroOffset(composite, texcoord.zw, ivec2(1,  1)).r;
			 factor.y -= rounding.x * SMAASampleLevelZeroOffset(composite, texcoord.xy, ivec2(0, -2)).r;
			 factor.y -= rounding.y * SMAASampleLevelZeroOffset(composite, texcoord.zw, ivec2(1, -2)).r;

		weights *= saturate(factor);
		
    #endif
	
}

void SMAADetectVerticalCornerPattern(inout vec2 weights, vec4 texcoord, vec2 d) {

    #if !defined(SMAA_DISABLE_CORNER_DETECTION)
	
		vec2 leftRight = step(d.xy, d.yx);
		vec2 rounding = (1.0 - SMAA_CORNER_ROUNDING_NORM) * leftRight;
			 rounding /= leftRight.x + leftRight.y;

		vec2 factor = vec2(1.0, 1.0);
			 factor.x -= rounding.x * SMAASampleLevelZeroOffset(composite, texcoord.xy, ivec2( 1, 0)).g;
			 factor.x -= rounding.y * SMAASampleLevelZeroOffset(composite, texcoord.zw, ivec2( 1, 1)).g;
			 factor.y -= rounding.x * SMAASampleLevelZeroOffset(composite, texcoord.xy, ivec2(-2, 0)).g;
			 factor.y -= rounding.y * SMAASampleLevelZeroOffset(composite, texcoord.zw, ivec2(-2, 1)).g;

		weights *= saturate(factor);
	
    #endif
	
}

vec4 getAABlendingTex(vec2 texcoord, vec2 pixcoord, vec4 subsampleIndices) {

    vec4 weights = vec4(0.0, 0.0, 0.0, 0.0);
    vec2 e = SMAASample(composite, texcoord).rg;

    if (e.g > 0.0) { // Edge at north
	
        #if !defined(SMAA_DISABLE_DIAG_DETECTION)
		
        // Diagonals have both north and west edges, so searching for them in
        // one of the boundaries is enough.
			weights.rg = SMAACalculateDiagWeights(texcoord, e, subsampleIndices);

        // We give priority to diagonals, so if we find a diagonal we skip 
        // horizontal/vertical processing.
			if (weights.r == -weights.g) { // weights.r + weights.g == 0.0
			
        #endif

        vec2 d;

        // Find the distance to the left:
        vec3  coords;
			  coords.x = SMAASearchXLeft(offset[0].xy, offset[2].x);
			  coords.y = offset[1].y; // offset[1].y = texcoord.y - 0.25 * SMAA_RT_METRICS.y (@CROSSING_OFFSET)
        d.x = coords.x;

        // Now fetch the left crossing edges, two at a time using bilinear
        // filtering. Sampling at -0.25 (see @CROSSING_OFFSET) enables to
        // discern what value each edge has:
        float e1 = SMAASampleLevelZero(composite, coords.xy).r;

        // Find the distance to the right:
        coords.z = SMAASearchXRight(offset[0].zw, offset[2].y);
        d.y = coords.z;

        // We want the distances to be in pixel units (doing this here allow to
        // better interleave arithmetic and memory accesses):
        d = abs(round(mad(SMAA_RT_METRICS.zz, d, -pixcoord.xx)));

        // SMAAArea below needs a sqrt, as the areas texture is compressed
        // quadratically:
        vec2 sqrt_d = sqrt(d);

        // Fetch the right crossing edges:
        float e2 = SMAASampleLevelZeroOffset(composite, coords.zy, ivec2(1, 0)).r;

        // Ok, we know how this pattern looks like, now it is time for getting
        // the actual area:
        weights.rg = SMAAArea(sqrt_d, e1, e2, subsampleIndices.y);

        // Fix corners:
        coords.y = texcoord.y;
        SMAADetectHorizontalCornerPattern(weights.rg, coords.xyzy, d);

        #if !defined(SMAA_DISABLE_DIAG_DETECTION)
        } else
            e.r = 0.0; // Skip vertical processing.
        #endif
		
    }

    if (e.r > 0.0) { // Edge at west
	
        vec2 d;

        // Find the distance to the top:
        vec3  coords;
			  coords.y = SMAASearchYUp(offset[1].xy, offset[2].z);
			  coords.x = offset[0].x; // offset[1].x = texcoord.x - 0.25 * SMAA_RT_METRICS.x;
        d.x = coords.y;

        // Fetch the top crossing edges:
        float e1 = SMAASampleLevelZero(composite, coords.xy).g;

        // Find the distance to the bottom:
        coords.z = SMAASearchYDown(offset[1].zw, offset[2].w);
        d.y = coords.z;

        // We want the distances to be in pixel units:
        d = abs(round(mad(SMAA_RT_METRICS.ww, d, -pixcoord.yy)));

        // SMAAArea below needs a sqrt, as the areas texture is compressed 
        // quadratically:
        vec2 sqrt_d = sqrt(d);

        // Fetch the bottom crossing edges:
        float e2 = SMAASampleLevelZeroOffset(composite, coords.xz, ivec2(0, 1)).g;

        // Get the area for this direction:
        weights.ba = SMAAArea(sqrt_d, e1, e2, subsampleIndices.x);

        // Fix corners:
        coords.x = texcoord.x;
        SMAADetectVerticalCornerPattern(weights.ba, coords.xyxz, d);
		
    }

    return weights;
	
}

#endif
