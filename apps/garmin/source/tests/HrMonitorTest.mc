using Toybox.Test;

// Unit tests for the HR auto-stop core (design-rationale section 5). HrMonitor is
// device-free: tests feed samples + an explicit ms clock and assert the decision.

function _cfg() {
    return {
        :smoothingWindowSamples => 5,
        :debounceMs => 4000,
        :hardCapMs => 120000,
        :staleSampleMs => 5000,
        :nullCountsAsBelow => false
    };
}

(:test)
function hr_smoothingAveragesRecentSamples(logger) {
    var m = new HrMonitor(_cfg());
    m.start(120, 0);
    m.addSample(150, 1000);
    m.addSample(160, 2000);
    m.addSample(140, 3000);
    // mean(150,160,140) = 150
    Test.assertEqualMessage(m.smoothedHr(3000), 150, "rolling average");
    return true;
}

(:test)
function hr_debounceRequiresSustainedBelow(logger) {
    var m = new HrMonitor(_cfg());
    m.start(130, 0);
    // Smoothed below target from t=1000 onward.
    m.addSample(120, 1000);
    Test.assertEqual(m.decision(1000), :continue);   // just dipped below
    m.addSample(121, 2000);
    Test.assertEqual(m.decision(2000), :continue);   // 1s below, < 4s
    m.addSample(119, 4000);
    Test.assertEqual(m.decision(4000), :continue);   // 3s below
    m.addSample(120, 5200);
    // 4.2s sustained below -> stop
    Test.assertEqualMessage(m.decision(5200), :targetMet, "sustained 4s below -> stop");
    return true;
}

(:test)
function hr_spikeAboveResetsDebounce(logger) {
    var m = new HrMonitor(_cfg());
    m.start(130, 0);
    m.addSample(120, 1000);
    m.decision(1000);
    m.addSample(120, 2000);
    m.decision(2000);
    // A high spike drags the smoothed average back above target -> reset.
    m.addSample(200, 3000);
    Test.assertEqualMessage(m.decision(3000), :continue, "above-target resets debounce");

    // Feed clean below samples once per second. With a 5-sample window the spike
    // lingers in the average until it is both evicted (sample #8 @ 8000) and
    // stale, so a *fresh* sustained-below period only accrues after that.
    var t = 4000;
    while (t <= 11000) {
        m.addSample(120, t);
        m.decision(t);
        t += 1000;
    }
    // belowSince begins at 8000 (spike gone); at 11000 only 3s have accrued.
    Test.assertEqualMessage(m.decision(11000), :continue, "fresh 4s below not yet accrued");
    m.addSample(120, 12000);
    Test.assertEqualMessage(m.decision(12000), :targetMet, "stops after fresh 4s below");
    return true;
}

(:test)
function hr_nullReadingsDoNotCountAsBelow(logger) {
    var m = new HrMonitor(_cfg());
    m.start(130, 0);
    m.addSample(120, 1000);            // below
    Test.assertEqual(m.decision(1000), :continue);
    m.addSample(null, 2000);           // dropped reading
    m.addSample(null, 3000);
    m.addSample(null, 4000);
    m.addSample(null, 5500);
    // Even though >4s elapsed since first below, the dropouts must NOT let it
    // stop on stale data. The last fresh sample (120 @1000) is now stale (>5s).
    Test.assertEqualMessage(m.decision(6100), :continue,
        "stale/null HR must never trigger a stop");
    return true;
}

(:test)
function hr_hardCapEndsAboveTarget(logger) {
    var m = new HrMonitor(_cfg());
    m.start(100, 0);
    // HR stays stubbornly above target the whole time.
    m.addSample(150, 1000);
    Test.assertEqual(m.decision(1000), :continue);
    m.addSample(150, 119000);
    Test.assertEqual(m.decision(119000), :continue);   // just under the cap
    m.addSample(150, 120500);
    Test.assertEqualMessage(m.decision(120500), :hardCap,
        "must release at the hard cap even above target");
    return true;
}

(:test)
function hr_noTargetNeverMeetsTargetButCaps(logger) {
    // Recovery mode: no HR target. Should never report :targetMet; only the cap.
    var m = new HrMonitor(_cfg());
    m.start(null, 0);
    m.addSample(80, 1000);
    Test.assertEqual(m.decision(1000), :continue);
    m.addSample(80, 121000);
    Test.assertEqualMessage(m.decision(121000), :hardCap, "no-target still respects cap");
    return true;
}
