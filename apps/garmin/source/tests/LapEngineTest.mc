using Toybox.Test;

// Unit tests for the accuracy core. LapEngine is device-free (caller passes a ms
// clock), so these run purely in the test VM.
//
// Run: monkeyc -f monkey.jungle -d instinct2x --unit-test -o bin/SwimCoachTest.prg -y <key>
//      monkeydo bin/SwimCoachTest.prg instinct2x -t

(:test)
function lapEngine_distanceIsLapsTimesPoolLength(logger) {
    var e = new LapEngine(25.0, 0);   // 25 m pool, no debounce for the test
    e.markStart(0);
    e.confirmLap(30000);   // 1
    e.confirmLap(60000);   // 2
    e.confirmLap(95000);   // 3
    Test.assertEqual(e.lapCount(), 3);
    Test.assertEqualMessage(e.distanceMeters(), 75.0, "3 x 25 m must be 75 m");
    return true;
}

(:test)
function lapEngine_fractionalPoolLength(logger) {
    var e = new LapEngine(18.5, 0);
    e.markStart(0);
    e.confirmLap(20000);
    e.confirmLap(40000);
    Test.assertEqualMessage(e.distanceMeters(), 37.0, "2 x 18.5 m must be 37 m");
    return true;
}

(:test)
function lapEngine_debounceIgnoresBouncyPress(logger) {
    var e = new LapEngine(25.0, 600);
    e.markStart(0);
    Test.assert(e.confirmLap(1000));        // accepted
    Test.assert(!e.confirmLap(1300));       // 300ms later -> bounced, ignored
    Test.assert(e.confirmLap(2000));        // 700ms later -> accepted
    Test.assertEqualMessage(e.lapCount(), 2, "bouncy mid-press must not count");
    return true;
}

(:test)
function lapEngine_lastSplitAndPace(logger) {
    var e = new LapEngine(25.0, 0);
    e.markStart(0);
    e.confirmLap(30000);   // 30s length
    e.confirmLap(70000);   // 40s length
    Test.assertEqualMessage(e.lastSplitMs(), 40000, "last split = 40s");
    // 50 m in 70s moving -> pace per 100 m = 140s
    Test.assertEqualMessage(e.pacePer100Sec().toNumber(), 140, "pace per 100m");
    return true;
}

(:test)
function lapEngine_restNotCountedIntoNextLength(logger) {
    var e = new LapEngine(25.0, 0);
    e.markStart(0);
    e.confirmLap(30000);   // length 1: 30s
    // ... 20s of rest happens here ...
    e.markResume(50000);   // push off; rest must not inflate the next split
    e.confirmLap(80000);   // length 2: 30s (80000-50000), not 50s
    Test.assertEqualMessage(e.lastSplitMs(), 30000, "rest excluded from split");
    Test.assertEqualMessage(e.movingTimeMs(), 60000, "moving time excludes rest");
    return true;
}
