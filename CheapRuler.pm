package CheapRuler;

# how to update README.md
#	pod2markdown CheapRuler.pm > README.md

=head1 CheapRuler

A collection of very fast approximations to common geodesic measurements. Useful for performance-sensitive code that measures things on a city scale (less than 500km, not near the poles). Can be an order of magnitude faster than Haversine based methods.

A Perl port of Mapbox's cheap-ruler https://github.com/mapbox/cheap-ruler

Very fast as they use just 1 trig function per call.

The Maths model is based upon the Earth's actual shape (a squashed sphere). For 'city' scale work, it is more accurate than
the Haversine formulae (which uses several trig calls based upon a spherical Earth). The Cheap_Ruler Github page explains it better!

Homepage : https://github.com/aavmurphy/CheapRuler

Note:

  it is based on geojson style GPS geometry, so points are [lon, lat].

  a polygon is a series of rings. The first ring is exterior and clockwise. Subsequent rings are interior (holes) and anticlockwise. 


=head2 Usage

The latitude (lat) parameter passed to the conructor should be the 'middle' of the lat's used.

Some methods have units, e.g. "expand a bounding box by 10 meters/miles/kilometers". The default 'units' are 'kilometers', you may which to use 'meters'.

Data is passed / retured as arrayrefs, e.g. $p =  [ 0.1, 54.1 ];

In the examples below, $p is a point, $a and $b are a line segment.

$p = [ -1, 57 ];

$a =  [0.1, 54.1];
$b =  [0.2, 54.2];

$ruler = Cheap::Ruler->new( ( 54.1 + 54.2 )/2, 'meters' ); # so the 'units' below are meters

$distance = $ruler->distance( $a, $b ); # return meters

$bearing = $ruler->bearing( $a, $b ); # returns degrees

$point = $ruler->destination( $a, 1000, 90); # returns a new point, 1000 units away at 90 degrees

$point = $ruler->offset( $p, 100, 200 ); # returns a point 100 units east, 200 units north

$distance = $ruler->lineDistance( ( $p, $a, $b ) ); # length of the line

$area = $ruler->area( (
		[-67.031, 50.458], [-67.031, 50.534], [-66.929, 50.534], [-66.929, 50.458], [-67.031, 50.458]
		) ); # area of a polygon

$point = $ruler->along( ( [-67.031, 50.458], [-67.031, 50.534], [-66.929, 50.534] ), 2.5); # returs a point 2.5 units along the line

$distance = $ruler->pointToSegmentDistance( $p, $a, $b ); # distance from point to a 2 point line segment 

=cut

use strict;
use warnings;
use experimental 'signatures';
use Math::Trig;
use Data::Dumper;


our %FACTORS = (
    kilometers	=> 1,
    miles		=> 1000 / 1609.344,
    nauticalmiles => 1000 / 1852,
    meters		=> 1000,
    metres		=> 1000,
    yards		=> 1000 / 0.9144,
    feet		=> 1000 / 0.3048,
    inches		=> 1000 / 0.0254
	);

# Values that define WGS84 ellipsoid model of the Earth

our $RE		= 6378.137; # equatorial radius
our $FE		= 1 / 298.257223563; # flattening

our $E2		= $FE * (2 - $FE);
our $RAD	= pi / 180; # from Math::Trig

 #
 # A collection of very fast approximations to common geodesic measurements. Useful for performance-sensitive code that measures things on a city scale.
 #


=head2 fromTile

Creates a ruler object from Google web mercator tile coordinates (y and z).

ruler = CheapRuler::fromTile( 11041, 15, 'meters');

=cut

sub fromTile( $y, $z, $units='kilometers') {
        my $n	= pi * (1 - 2 * ($y + 0.5) / ( 2**$z ));
        my $lat	= atan(0.5 * ( exp($n) - exp(-$n) )) / $RAD;

        return CheapRuler->new($lat, $units);
    }

=head2 units

Multipliers for converting between units.
 
example : convert 50 meters to yards

50 * CheapRuler::units()->{yards} / CheapRuler::units()->{meters};

=cut

sub units() {
	return { %FACTORS };
	}

=head2 new( $lat, $units='meters' )

Create a ruler instance for very fast approximations to common geodesic measurements around a certain latitude.

param latitude

param (optional) {key of %FACTORS}
 
ruler = CheapRuler(35.05, 'miles');

=cut

sub   new ( $class, $lat, $units='kilometers' ) {
       croak( 'No latitude given.') if ! defined $lat; 
       croak( "Unknown unit $units. Use one of: " + join( ', ', keys(%FACTORS) ) ) if $units && ! $FACTORS{ $units };

		my $self = bless {};

        # Curvature formulas from https://en.wikipedia.org/wiki/Earth_radius#Meridional
        my $m		= $RAD * $RE * ( $units ? $FACTORS{ $units } : 1 );
        my $coslat	= cos( $lat * $RAD );
        my $w2		= 1 / (1 - $E2 * (1 - $coslat**2) );
        my $w		= sqrt($w2);

        # multipliers for converting longitude and latitude degrees into distance
        $self->{kx} = $m * $w * $coslat;        # based on normal radius of curvature
        $self->{ky} = $m * $w * $w2 * (1 - $E2); # based on meridonal radius of curvature
		
		return $self;
		}

=head2 distance( $a, $b )

Given two points of the form [longitude, latitude], returns the distance.

param a, point [longitude, latitude]

param b, point [longitude, latitude]

returns distance (in chosen units)

$distance = $ruler->distance([30.5, 50.5], [30.51, 50.49]);

=cut

sub distance( $self, $a, $b) {

        my $dx = &wrap( $a->[0] - $b->[0]) * $self->{kx};
        my $dy = ( $a->[1] - $b->[1]) * $self->{ky};
        return sqrt( $dx * $dx + $dy * $dy);
    }

=head2 bearing( $a, $b )

	Returns the bearing between two points in degrees
	
	param a, point [longitude, latitude]

	param b, point [longitude, latitude]

	returns bearing (degrees)
	
	bearing = ruler->bearing([30.5, 50.5], [30.51, 50.49]);
=cut

sub bearing($self, $a, $b) {
	my $dx = &wrap($b->[0] - $a->[0]) * $self->{kx};
	my $dy = ($b->[1] - $a->[1]) * $self->{ky};
	return atan2($dx, $dy) / $RAD;
    }

=head2 destination( $point, $distance, $bearing)

Returns a new point given distance and bearing from the starting point.

param p point [longitude, latitude]
param dist distance in chosen units
param bearing (degrees)

returns point [longitude, latitude]
	
$point = ruler->destination([30.5, 50.5], 0.1, 90);
=cut

sub destination( $self, $p, $dist, $bearing) {
        my $a = $bearing * $RAD;
        return $self->offset(
			$p,
            sin($a) * $dist,
            cos($a) * $dist,
			);
    }

=head2 offset( $point, dx, dy ) 
     
Returns a new point given easting and northing offsets (in ruler units) from the starting point.
   
param point, [longitude, latitude]
param dx, easting, in ruler units
param dy, northing, in ruler units

returns point [longitude, latitude]

$point = ruler.offset([30.5, 50.5], 10, 10);
=cut

sub offset( $self, $p, $dx, $dy) {
	return [
		$p->[0] + $dx / $self->{kx},
		$p->[1] + $dy / $self->{ky},
		];
	}
 
=head2 lineDistance ( points )

Given a line (an array of points), returns the total line distance.

param points, listref of points, where a point is [longitude, latitude]

returns number, total line distance in 'ruler' units

$length = ruler->lineDistance([
	[-67.031, 50.458], [-67.031, 50.534],
	[-66.929, 50.534], [-66.929, 50.458]
	]);
=cut

sub lineDistance( $self, $points ) {
	my $total = 0;
	foreach my $i ( 0 .. $#{ $points } - 1 ) {
		$total += $self->distance( $points->[ $i ], $points->[ $i + 1 ] );
		}
	return $total;
	}

=head2 area( $polygon )

Given a polygon (an array of rings, where each ring is an array of points), returns the area.
	
param $polygon, a list-ref of rings, where a ring is a list of points [lon,lat], 1st ring is outer, 2nd+ rings are inner (holes)

returns $number, area value in the specified 'ruler' units (square kilometers by default)
	
$area = $ruler->area([[
	[-67.031, 50.458], [-67.031, 50.534], [-66.929, 50.534], [-66.929, 50.458], [-67.031, 50.458]
	]]);
=cut

sub area( $self, $polygon ) {
		my $sum = 0;

		foreach my $i ( 0 .. $#{ $polygon } ) {
			my @ring = @{ $polygon->[ $i ] };
			
			for ( my ( $j, $len, $k ) = ( 0, scalar( @ring ), $#ring ); $j < $len; $k = $j++) {
					$sum += &wrap( $ring[$j]->[0] - $ring[$k]->[0]) * ( $ring[$j]->[1] + $ring[$k]->[1]) * ( $i ? -1 : 1 );
				}
			}

		return ( abs( $sum ) / 2 ) * $self->{kx} * $self->{ky};
		}

=head2 along( $line, $distance)

	Returns the point at a specified distance along the line.

	param $line, a list-ref of points of [lon, lat]
	param $dist, distance in ruler units

	returns $point, a list-ref [lon, lat]
	
	point = ruler->along(
		[ [-67.031, 50.458], [-67.031, 50.534], [-66.929, 50.534] ],
		2.5);
=cut

sub along( $self, $line, $dist ) {
	my $sum = 0;

	return $line->[0] if $dist <= 0 ;

	for (my $i = 0; $i < $#{ $line }; $i++) {
		my $p0 = $line->[$i];
		my $p1 = $line->[$i + 1];
		my $d = $self->distance($p0, $p1);
		$sum += $d;
		return &interpolate( $p0, $p1, ( $dist - ($sum - $d)) / $d ) if $sum > $dist;
		}

	return $line->[ $#{ $line } ];
	}

=head2 pointToSegmentDistance( $p, $a, $b )

	Returns the distance from a point `p` to a line segment `a` to `b`.

	param p, point, [longitude, latitude]
	param a, segment point 1, [longitude, latitude]
	param b, segment point 2, [longitude, latitude]

	returns distance (in ruler units)
    
	let distance = $ruler->pointToSegmentDistance([-67.04, 50.5], [-67.05, 50.57], [-67.03, 50.54]);
=cut

sub pointToSegmentDistance( $self, $p, $a, $b) {
	my $x = $a->[0];
	my $y = $a->[1];
	my $dx = &wrap( $b->[0] - $x) * $self->{kx};
	my $dy = ($b->[1] - $y) * $self->{ky};

	if ( $dx != 0 || $dy != 0) {
		my $t = ( &wrap( $p->[0] - $x) * $self->{kx} * $dx + ( $p->[1] - $y) * $self->{ky} * $dy) / ($dx**2 + $dy**2);

		if ($t > 1) {
			$x = $b->[0];
			$y = $b->[1];
			}
		elsif ( $t > 0) {
			$x += ($dx / $self->{kx}) * $t;
			$y += ($dy / $self->{ky}) * $t;
			}
	}

	$dx = &wrap($p->[0] - $x) * $self->{kx};
	$dy = ($p->[1] - $y) * $self->{ky};

	return sqrt($dx**2 + $dy**2);
}

=head2 pointOnLine( $line, $p )

Returns an object of the form {point, index, t}, where

	point is closest point on the line from the given point,

	index is the start index of the segment with the closest point,

	t is a parameter from 0 to 1 that indicates where the closest point is on that segment.

param $line, lisreft of points of [lon, lat]
param $p, point of [longitude, latitude]

returns { point : [lon, lat], index, t }}

$info = ruler->pointOnLine( line, [-67.04, 50.5])
=cut

sub pointOnLine( $self, $line, $p) {
	my $minDist = "infinity";
	my $minX = $line->[0][0];
	my $minY = $line->[0][1];
	my $minI = 0;
	my $minT = 0;

	for ( my $i = 0; $i < $#{ $line }; $i++) {

		my $x = $line->[$i][0];
		my $y = $line->[$i][1];
		my $dx = &wrap( $line->[$i + 1][0] - $x) * $self->{kx};
		my $dy = ($line->[$i + 1][1] - $y) * $self->{ky};
		my $t = 0;

		if ($dx != 0 || $dy != 0) {
			$t = ( &wrap($p->[0] - $x) * $self->{kx} * $dx + ($p->[1] - $y) * $self->{ky} * $dy) / ($dx**2 + $dy**2);

			if ($t > 1) {
				$x = $line->[$i + 1][0];
				$y = $line->[$i + 1][1];

			} elsif ($t > 0) {
				$x += ($dx / $self->{kx}) * $t;
				$y += ($dy / $self->{ky}) * $t;
			}
		}

		$dx = wrap($p->[0] - $x) * $self->{kx};
		$dy = ($p->[1] - $y) * $self->{ky};

		my $sqDist = $dx**2 + $dy**2;
		if ( $minDist eq 'infinity' || $sqDist < $minDist) {
			$minDist = $sqDist;
			$minX = $x;
			$minY = $y;
			$minI = $i;
			$minT = $t;
		}
	}

	# Math::max(0, Math::min(1, $minT));
	my $min = 1 < $minT ? 1 : $minT;
	my $max = 0 > $min ? 0 : $min;

	return {
		point	=> [$minX,$minY],
		index	=> $minI,
		t		=> $max,
		};
	}

=head2 lineSlice( $start, $stop, $line )

Returns a part of the given line between the start and the stop points (or their closest points on the line).

param start, point [longitude, latitude]

param stop, point [longitude, latitude]

param line, arrayref of points of [lon,lat]

@returns {[number, number][]} line part of a line

$line_slice = $ruler->lineSlice([-67.04, 50.5], [-67.05, 50.56], $line);
=cut

sub lineSlice($self, $start, $stop, $line) {
	my $p1 = $self->pointOnLine($line,$start);
	my $p2 = $self->pointOnLine($line,$stop);

	if ( $p1->{index} > $p2->{index} || ( $p1->{index} == $p2->{index} && $p1->{t} > $p2->{t} )) {
		my $tmp = $p1;
		$p1 = $p2;
		$p2 = $tmp;
		}

	my @slice = ( $p1->{point} );

	my $l = $p1->{index} + 1;
	my $r = $p2->{index};
	
	if ( ( ! &equals( $line->[1], $slice[0]) ) && ( $l <= $r ) ) {
		push @slice, $line->[$l];
		}

	for (my $i = $l + 1; $i <= $r; $i++) {
		push @slice, $line->[$i];
		}

	if ( ! &equals( $line->[$r], $p2->{point} )) {
		push @slice, $p2->{point};
		}

	return [ @slice ];
	}

=head2 lineSliceAlong( $start, $stop, $line )

Returns a part of the given line between the start and the stop points indicated by distance (in 'units') along the line.

param start, distance, in ruler units
param stop stop, distance, in ruler units
param line, listref of points
returns line_slice, listref of points, part of a line

$line_slice = $ruler->lineSliceAlong(10, 20, $line);

=cut

sub lineSliceAlong( $self, $start, $stop, $line) {
	my $sum = 0;
	my @slice = ();

	for (my $i = 0; $i < $#{ $line }; $i++) {
		my $p0 = $line->[$i];
		my $p1 = $line->[$i + 1];
		my $d = $self->distance($p0, $p1);

		$sum += $d;

		if ($sum > $start && ( scalar @slice ) == 0) {
			push @slice, &interpolate($p0, $p1, ($start - ($sum - $d)) / $d);
			}

		if ($sum >= $stop) {
			push @slice, &interpolate($p0, $p1, ($stop - ($sum - $d)) / $d);
			return [ @slice ];
			}

		if ($sum > $start) { push @slice, $p1 };
		}

	return [ @slice ];
	}

=head2 bufferPoint( point, buffer_distance )

Given a point, returns a bounding box object ([w, s, e, n]) created from the given point buffered by a given distance.
 
param {[number, number]} p point [longitude, latitude]

param {number} buffer, a distance in ruler units

returns bbox, listref, [w, s, e, n]

my $bbox = $ruler.bufferPoint([30.5, 50.5], 0.01);
 
=cut

sub bufferPoint( $self, $p, $buffer) {
	my $v = $buffer / $self->{ky};
	my $h = $buffer / $self->{kx};
	return [
		$p->[0] - $h,
		$p->[1] - $v,
		$p->[0] + $h,
		$p->[1] + $v
		];
	}

=head2 bufferBBox( $bbox, $buffer )

Given a bounding box, returns the box buffered by a given distance.

param bbox, listref of [w, s, e, n]

param buffer, distance in ruler units

returns bbox, listref, [w, s, e, n]

my $bbox = ruler->bufferBBox([30.5, 50.5, 31, 51], 0.2);

=cut

sub bufferBBox( $self, $bbox, $buffer) {
        my $v = $buffer / $self->{ky};
        my $h = $buffer / $self->{kx};
        return [
            $bbox->[0] - $h,
            $bbox->[1] - $v,
            $bbox->[2] + $h,
            $bbox->[3] + $v,
        ];
    }

=head2 insideBBox( $point, $bbox )

Returns true (1) if the given point is inside in the given bounding box, otherwise false (0).

param p point [longitude, latitude]

param bbox, listref [w, s, e, n]

returns 0 or 1 (boolean)

my $inside = $ruler->insideBBox([30.5, 50.5], [30, 50, 31, 51]);
=cut

sub insideBBox( $self, $p, $bbox) {
	return &wrap( $p->[0] - $bbox->[0]) >= 0 &&
		   &wrap( $p->[0] - $bbox->[2]) <= 0 &&
		   $p->[1] >= $bbox->[1] &&
		   $p->[1] <= $bbox->[3];
	}

# equals ( $a, $b ) - tests if 2 points are equal, private
#
# 	param a, point, ( lon, lat )
# 	param b, point, ( lon, lat )
#

sub equals($a, $b) {
    return ( $a->[0] == $b->[0] && $a->[1] == $b->[1] ) ? 1 : 0;
	}

# interpolate ( $a, $b, $t ) - returns point along a line segment from a to b, private
#
#	param a, point, [lon, lat]
#	param b, point, [lon, lat]
# 	param t, ratio of way along the line segment
#
# returns p, point [ lon, lat]

sub interpolate($a, $b, $t) {
    my $dx = &wrap($b->[0] - $a->[0]);
    my $dy = $b->[1] - $a->[1];
    return [
        $a->[0] + $dx * $t,
        $a->[1] + $dy * $t
		];
	}

#
# normalize a degree value into [-180..180] range
#	param degrees
# 
sub wrap( $deg) {
	
    while ( $deg < -180) { $deg += 360; }
    while ( $deg > 180)  { $deg -= 360; }

    return $deg;
	}
