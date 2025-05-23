/*
install nodejs
install @turf/turf and mapbox/cheap-ruler from mpm
then this should work

node test.js

it runs the tests, then output the 'definitive/correct/turf' results
these are used as the 'answers' in the perl tests
*/

import test from 'node:test';
import assert from 'node:assert/strict';
import CheapRuler from '../index.js';
import * as turf from '@turf/turf';
import {readFileSync} from 'fs';

const lines = JSON.parse(readFileSync(new URL('fixtures/lines.json', import.meta.url)));

const points = Array.prototype.concat.apply([], lines);

const ruler = new CheapRuler(32.8351);
const milesRuler = new CheapRuler(32.8351, 'miles');

function assertErr(actual, expected, maxErr, description) {
    if (isNaN(actual) || isNaN(expected)) assert.fail(`${description} produced NaN`);
    const err = Math.abs((actual - expected) / expected);
    if (err > maxErr) assert.fail(`${description}, err: ${err}`);
}

test('cheapRuler constructor', () => {
    assert.throws(() => {
        const ruler = new CheapRuler();
        ruler.distance(null, null);
    }, 'errors without latitude');
});

test('distance', () => {
	let e = 0;
	let a = 0;
    for (let i = 0; i < points.length - 1; i++) {
        const expected = turf.distance(turf.point(points[i]), turf.point(points[i + 1]));
		e += expected;
        const actual = ruler.distance(points[i], points[i + 1]);
        assertErr(expected, actual, 0.003, 'distance');
    }
    // distance within 0.3%
	console.warn( 'distance', e );
});

test('distance over dateline', () => {
    const p0 = [179.9, 32.7];
    const p1 = [-179.9, 32.9];
    const expected = turf.distance(turf.point(p0), turf.point(p1));
    const actual = ruler.distance(p0, p1);
	console.warn( 'dl distance', expected );
    assertErr(expected, actual, 0.001, 'distance');
    // distance within 0.1%
});

test('distance in miles', () => {
    const d = ruler.distance([30.5, 32.8351], [30.51, 32.8451]);
    const d2 = milesRuler.distance([30.5, 32.8351], [30.51, 32.8451]);

	console.warn(  'distance in miles', d2 );
    assertErr(d / d2, 1.609344, 1e-12, 'distance in miles');
    // distance in miles
});

test('bearing', () => {
	let bearing=[];
    for (let i = 0; i < points.length - 1; i++) {
        const expected = turf.bearing(turf.point(points[i]), turf.point(points[i + 1]));
        const actual = ruler.bearing(points[i], points[i + 1]);
		bearing.push( expected);
		console.warn( actual, expected);
        assertErr(expected, actual, 0.005, 'bearing');
    }
	console.info(JSON.stringify(bearing));
    // bearing within 0.05%
});

test('bearing over dateline', () => {
    const p0 = [179.9, 32.7];
    const p1 = [-179.9, 32.9];
    const expected = turf.bearing(turf.point(p0), turf.point(p1));
    const actual = ruler.bearing(p0, p1);
	console.warn( 'bearing over dateline', expected);
    assertErr(expected, actual, 0.005, 'bearing');
    // bearing within 0.5%
});

test('destination', () => {
	let dest = [];
    for (let i = 0; i < points.length; i++) {
        const bearing = (i % 360) - 180;
        const expected = turf.destination(turf.point(points[i]), 1.0, bearing, {units: 'kilometers'}).geometry.coordinates;
        const actual = ruler.destination(points[i], 1.0, bearing);
		dest.push( expected);
        assertErr(expected[0], actual[0], 1e-6, 'destination longitude');
        assertErr(expected[1], actual[1], 1e-6, 'destination latitude');
    }
		console.warn( 'destination', JSON.stringify(dest) );
});

test('lineDistance', () => {
	let linedist=[];
    for (let i = 0; i < lines.length; i++) {
        const expected = turf.length(turf.lineString(lines[i]));
        const actual = ruler.lineDistance(lines[i]);
		linedist.push( expected);
        assertErr(expected, actual, 0.003, 'lineDistance');
    }
	console.dir(linedist);
    // lineDistance within 0.3%
});

test('area', () => {
	let area=[];
    for (let i = 0; i < lines.length; i++) {
		area[ i ] = '';
        if (lines[i].length < 3) continue;
        const poly = turf.polygon([lines[i].concat([lines[i][0]])]);
        const expected = turf.area(poly) / 1e6;
        const actual = ruler.area([lines[i]]);
		area[ i ] = expected;
        assertErr(expected, actual, 0.003, 'area');
    }
	console.info('area');
	console.info(JSON.stringify( area));
    // area within 0.3%
});

test('along', () => {
	let test_d=[], test_e=[];
    for (let i = 0; i < lines.length; i++) {
        const line = turf.lineString(lines[i]);
        const dist = turf.length(line) / 2;
        const expected = turf.along(line, dist, {units: 'kilometers'}).geometry.coordinates;
        const actual = ruler.along(lines[i], dist);
		test_d.push(dist);
		test_e.push(expected);
        assertErr(expected[0], actual[0], 1e-6, 'along longitude');
        assertErr(expected[1], actual[1], 1e-6, 'along latitude');
    }
	console.info('along');
	console.info(JSON.stringify( test_d));
	console.info(JSON.stringify( test_e));
    // along point within 1e-6
});

test('along with dist <= 0', () => {
    assert.deepEqual(ruler.along(lines[0], -5), lines[0][0], 'first point');
});

test('along with dist > length', () => {
    assert.deepEqual(ruler.along(lines[0], 1000), lines[0][lines[0].length - 1], 'last point');
});

test('along over dateline', () => {
    const line = [[179.9, 32.7], [-179.9, 32.9]];
    const turfLine = turf.lineString(line);
    const dist = turf.length(turfLine) / 3;
    const expected = turf.along(turfLine, dist).geometry.coordinates;
    const actual = ruler.along(line, dist);

	console.warn( 'along dl');
	console.warn( dist)
	console.warn( actual)

    assert.ok(ruler.distance(expected, actual) < 0.02);
});

test('pointOnLine', () => {
    // not Turf comparison because pointOnLine is bugged https://github.com/Turfjs/turf/issues/344
    const line = [[-77.031669, 38.878605], [-77.029609, 38.881946]];
    const result = ruler.pointOnLine(line, [-77.034076, 38.882017]);

    assert.deepEqual(result, {point: [-77.03052689033436, 38.880457324462576], index: 0, t: 0.5544221677861756}, 'pointOnLine');

    assert.equal(ruler.pointOnLine(line, [-80, 38]).t, 0, 't is not less than 0');
    assert.equal(ruler.pointOnLine(line, [-75, 38]).t, 1, 't is not bigger than 1');

});

test('pointOnLine over dateline', () => {
    const line = [[179.9, 32.7], [-179.9, 32.9]];
    const actual = ruler.pointOnLine(line, [180, 32.7]);
    assert.deepEqual(actual.point, [179.9416136283502, 32.7416136283502]);
});

test('pointToSegmentDistance', () => {
    const p = [-77.034076, 38.882017];
    const p0 = [-77.031669, 38.878605];
    const p1 = [-77.029609, 38.881946];
    const distance = ruler.pointToSegmentDistance(p, p0, p1);
    assert.equal(distance, 0.37461484020420416);
});

test('lineSlice', () => {
	let lineslice=[];
    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];
        const dist = ruler.lineDistance(line);
        const start = ruler.along(line, dist * 0.3);
        const stop = ruler.along(line, dist * 0.7);

		const clean_line = turf.cleanCoords( turf.lineString(line) );
        const expected = ruler.lineDistance(turf.lineSlice(
            turf.point(start), turf.point(stop), clean_line).geometry.coordinates);

		lineslice.push( expected);
        const actual = ruler.lineDistance(ruler.lineSlice(start, stop, line));

        assertErr(expected, actual, 1e-5, 'lineSlice length');
    }
	console.warn('lineslice');
	console.warn(JSON.stringify(lineslice));
    // lineSlice length within 1e-5
});

test('lineSliceAlong', () => {
	let lsa=[];
    for (let i = 0; i < lines.length; i++) {
		lsa[ i ] = '';
        if (i === 46) continue; // skip due to Turf bug https://github.com/Turfjs/turf/issues/351

        const line = lines[i];
        const dist = ruler.lineDistance(line);
        const start = ruler.along(line, dist * 0.3);
        const stop = ruler.along(line, dist * 0.7);

        const expected = ruler.lineDistance(turf.lineSlice(
            turf.point(start), turf.point(stop), turf.cleanCoords( turf.lineString(line) ) ).geometry.coordinates);
        const actual = ruler.lineDistance(ruler.lineSliceAlong(dist * 0.3, dist * 0.7, line));

		lsa[ i ] = expected;
        assertErr(expected, actual, 1e-5, 'lineSliceAlong length');
    }
	console.warn('lineslicealong');
	console.warn(JSON.stringify(lsa));
    // lineSliceAlong length within 1e-5
});

test('lineSlice reverse', () => {
    const line = lines[0];
    const dist = ruler.lineDistance(line);
    const start = ruler.along(line, dist * 0.7);
    const stop = ruler.along(line, dist * 0.3);
    const actual = ruler.lineDistance(ruler.lineSlice(start, stop, line));
    assert.equal(actual, 0.018676476689649835, 'lineSlice reversed length');
});

test('bufferPoint', () => {
	let bufferpoint=[];
    for (let i = 0; i < points.length; i++) {
        const expected = turfPointBuffer(points[i], 0.1);
        const actual = milesRuler.bufferPoint(points[i], 0.1);
        assertErr(expected[0], actual[0], 2e-7, 'bufferPoint west');
        assertErr(expected[1], actual[1], 2e-7, 'bufferPoint east');
        assertErr(expected[2], actual[2], 2e-7, 'bufferPoint south');
        assertErr(expected[3], actual[3], 2e-7, 'bufferPoint north');
		bufferpoint.push(expected);
    }
    // point buffer error within 2e-7
	console.warn('bufferpoint');
	console.warn(JSON.stringify(bufferpoint));
});

test('bufferBBox', () => {
    const bbox = [30, 38, 40, 39];
    const bbox2 = ruler.bufferBBox(bbox, 1);
    assert.deepEqual(bbox2, [29.989319282570946, 37.99098299160844, 40.010680717429054, 39.00901700839156], 'bufferBBox');
});

test('insideBBox', () => {
    const bbox = [30, 38, 40, 39];
    assert.ok(ruler.insideBBox([35, 38.5], bbox), 'insideBBox inside');
    assert.ok(!ruler.insideBBox([45, 45], bbox), 'insideBBox outside');
});

test('insideBBox over dateline', () => {
    assert.ok(ruler.insideBBox([180, 32.8], [179.9, 32.7, -179.9, 32.9]));
});

test('cheapRuler.fromTile', () => {
    const ruler1 = new CheapRuler(50.5);
    const ruler2 = CheapRuler.fromTile(11041, 15);

    const p1 = [30.5, 50.5];
    const p2 = [30.51, 50.51];

    assertErr(ruler1.distance(p1, p2), ruler2.distance(p1, p2), 2e-5, 'cheapRuler.fromTile distance');

});

test('cheapRuler.units', () => {
    assert.equal(CheapRuler.units.kilometers, 1);
});

function turfPointBuffer(p, distance) {
    const dist = Math.sqrt(2) * distance;
    const pt = turf.point(p);
    const sw = turf.destination(pt, dist, -135, {units: 'miles'});
    const ne = turf.destination(pt, dist, 45, {units: 'miles'});
    return sw.geometry.coordinates.concat(ne.geometry.coordinates);
}
