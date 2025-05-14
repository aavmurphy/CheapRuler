# CheapRuler

A collection of very fast approximations to common geodesic measurements. Useful for performance-sensitive code that measures things on a city scale (less than 500km, not near the poles). Can be an order of magnitude faster than Haversine based methods.

A Perl port of Mapbox's cheap-ruler https://github.com/mapbox/cheap-ruler

Very fast as they use just 1 trig function per call.

The Maths model is based upon the Earth's actual shape (a squashed sphere). For 'city' scale work, it is more accurate than
the Haversine formulae (which uses several trig calls based upon a spherical Earth). The Cheap\_Ruler Github page explains it better!

## Hompage

https://github.com/aavmurphy/CheapRuler

head2 Usage

This module uses "geojson" style GPS geometrys. Points are \[lon, lat\]. Polygons are a series of rings. The first ring is exterior and clockwise. Subsequent rings are interior (holes) and anticlockwise. 

The latitude (lat) parameter passed to the constructor should be the 'middle' of the lat's used.

Some methods have units, e.g. "expand a bounding box by 10 meters/miles/kilometers". The default 'units' are 'kilometers', you may which to use 'meters'.

Data is passed / retured as arrayrefs, e.g. $p =  \[ 0.1, 54.1 \];

\#head2 Examples

In the examples below, $p is a point, $a and $b are a line segment.

$p = \[ -1, 57 \];

$a =  \[0.1, 54.1\];
$b =  \[0.2, 54.2\];

$ruler = Cheap::Ruler->new( ( 54.1 + 54.2 )/2, 'meters' ); # so the 'units' below are meters

$distance = $ruler->distance( $a, $b ); # return meters

$bearing = $ruler->bearing( $a, $b ); # returns degrees

$point = $ruler->destination( $a, 1000, 90); # returns a new point, 1000 units away at 90 degrees

$point = $ruler->offset( $p, 100, 200 ); # returns a point 100 units east, 200 units north

$distance = $ruler->lineDistance( ( $p, $a, $b ) ); # length of the line

$area = $ruler->area( (
		\[-67.031, 50.458\], \[-67.031, 50.534\], \[-66.929, 50.534\], \[-66.929, 50.458\], \[-67.031, 50.458\]
		) ); # area of a polygon

$point = $ruler->along( ( \[-67.031, 50.458\], \[-67.031, 50.534\], \[-66.929, 50.534\] ), 2.5); # returs a point 2.5 units along the line

$distance = $ruler->pointToSegmentDistance( $p, $a, $b ); # distance from point to a 2 point line segment 

### fromTile( $y, $z, $units='kilometers' )

Creates a ruler object from Google web mercator tile coordinates (y and z). That's correct, not x.

$ruler = CheapRuler::fromTile( 11041, 15, 'meters');

### units()

Multipliers for converting between units.

example : convert 50 meters to yards

50 \* CheapRuler::units()->{yards} / CheapRuler::units()->{meters};

## new( $lat, $units='kilometers' )

Create a ruler instance for very fast approximations to common geodesic measurements around a certain latitude.

param latitude

param (optional) {key of %FACTORS}

ruler = CheapRuler(35.05, 'miles');

## distance( $a, $b )

Given two points of the form \[longitude, latitude\], returns the distance.

param a, point \[longitude, latitude\]

param b, point \[longitude, latitude\]

returns distance (in chosen units)

$distance = $ruler->distance(\[30.5, 50.5\], \[30.51, 50.49\]);

## bearing( $a, $b )

        Returns the bearing between two points in degrees
        
        param a, point [longitude, latitude]

        param b, point [longitude, latitude]

        returns bearing (degrees)
        
        bearing = ruler->bearing([30.5, 50.5], [30.51, 50.49]);

## destination( $point, $distance, $bearing)

Returns a new point given distance and bearing from the starting point.

param p point \[longitude, latitude\]

param dist distance in chosen units

param bearing (degrees)

returns point \[longitude, latitude\]

$point = ruler->destination(\[30.5, 50.5\], 0.1, 90);

## offset( $point, dx, dy ) 

Returns a new point given easting and northing offsets (in ruler units) from the starting point.

param point, \[longitude, latitude\]

param dx, easting, in ruler units

param dy, northing, in ruler units

returns point \[longitude, latitude\]

$point = ruler.offset(\[30.5, 50.5\], 10, 10);

## lineDistance ( $points )

Given a line (an array of points), returns the total line distance.

param points, listref of points, where a point is \[longitude, latitude\]

returns number, total line distance in 'ruler' units

$length = ruler->lineDistance(\[
	\[-67.031, 50.458\], \[-67.031, 50.534\],
	\[-66.929, 50.534\], \[-66.929, 50.458\]
	\]);

## area( $polygon )

Given a polygon (an array of rings, where each ring is an array of points), returns the area.

param $polygon, a list-ref of rings, where a ring is a list of points \[lon,lat\], 1st ring is outer, 2nd+ rings are inner (holes)

returns $number, area value in the specified 'ruler' units (square kilometers by default)

$area = $ruler->area(\[\[
	\[-67.031, 50.458\], \[-67.031, 50.534\], \[-66.929, 50.534\], \[-66.929, 50.458\], \[-67.031, 50.458\]
	\]\]);

## along( $line, $distance)

Returns the point at a specified distance along the line.

param $line, a list-ref of points of \[lon, lat\]

param $dist, distance in ruler units

returns $point, a list-ref \[lon, lat\]

point = ruler->along(
	\[ \[-67.031, 50.458\], \[-67.031, 50.534\], \[-66.929, 50.534\] \],
	2.5);

## pointToSegmentDistance( $p, $a, $b )

Returns the distance from a point \`p\` to a line segment \`a\` to \`b\`.

param p, point, \[longitude, latitude\]

param a, segment point 1, \[longitude, latitude\]

param b, segment point 2, \[longitude, latitude\]

returns distance (in ruler units)

let distance = $ruler->pointToSegmentDistance(\[-67.04, 50.5\], \[-67.05, 50.57\], \[-67.03, 50.54\]);

## pointOnLine( $line, $p )

Returns an object of the form {point, index, t}, where

point is closest point on the line from the given point,

index is the start index of the segment with the closest point,

t is a parameter from 0 to 1 that indicates where the closest point is on that segment.

param $line, lisreft of points of \[lon, lat\]
param $p, point of \[longitude, latitude\]

returns { point : \[lon, lat\], index, t }}

$info = ruler->pointOnLine( line, \[-67.04, 50.5\])

## lineSlice( $start, $stop, $line )

Returns a part of the given line between the start and the stop points (or their closest points on the line).

param start, point \[longitude, latitude\]

param stop, point \[longitude, latitude\]

param line, arrayref of points of \[lon,lat\]

@returns {\[number, number\]\[\]} line part of a line

$line\_slice = $ruler->lineSlice(\[-67.04, 50.5\], \[-67.05, 50.56\], $line);

## lineSliceAlong( $start, $stop, $line )

Returns a part of the given line between the start and the stop points indicated by distance (in 'units') along the line.

param start, distance, in ruler units

param stop stop, distance, in ruler units

param line, listref of points

returns line\_slice, listref of points, part of a line

$line\_slice = $ruler->lineSliceAlong(10, 20, $line);

## bufferPoint( point, buffer\_distance )

Given a point, returns a bounding box object (\[w, s, e, n\]) created from the given point buffered by a given distance.

param {\[number, number\]} p point \[longitude, latitude\]

param {number} buffer, a distance in ruler units

returns bbox, listref, \[w, s, e, n\]

my $bbox = $ruler.bufferPoint(\[30.5, 50.5\], 0.01);

## bufferBBox( $bbox, $buffer )

Given a bounding box, returns the box buffered by a given distance.

param bbox, listref of \[w, s, e, n\]

param buffer, distance in ruler units

returns bbox, listref, \[w, s, e, n\]

my $bbox = ruler->bufferBBox(\[30.5, 50.5, 31, 51\], 0.2);

## insideBBox( $point, $bbox )

Returns true (1) if the given point is inside in the given bounding box, otherwise false (0).

param p point \[longitude, latitude\]

param bbox, listref \[w, s, e, n\]

returns 0 or 1 (boolean)

my $inside = $ruler->insideBBox(\[30.5, 50.5\], \[30, 50, 31, 51\]);
