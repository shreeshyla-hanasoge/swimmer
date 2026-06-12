// LapEngine — the accuracy core (design-rationale sections 1, 2, 3).
//
// The SINGLE source of distance in the whole app:
//     distance = confirmedLaps * poolLengthMeters
// Nothing else may compute distance. No strokes, no GPS, ever.
//
// Pure / device-free (caller passes a monotonic ms clock) so the maths is unit
// testable — see source/tests/LapEngineTest.mc. Memory-conscious: split
// durations are kept as a plain array of Numbers, appended once per wall touch.
class LapEngine {

    private var _poolLength;     // metres (Float), measured/configured
    private var _lapDebounceMs;  // ignore bouncy double-presses at the wall

    private var _splitsMs;       // Array<Number>: duration of each confirmed length
    private var _boundaryMs;     // ms timestamp of the last lap/segment boundary
    private var _lastLapMs;      // ms of last accepted lap (for debounce)
    private var _startMs;        // session start (ms)

    function initialize(poolLengthMeters, lapDebounceMs) {
        _poolLength = poolLengthMeters;
        _lapDebounceMs = lapDebounceMs;
        _splitsMs = [];
        _boundaryMs = 0;
        _lastLapMs = -100000;
        _startMs = 0;
    }

    function markStart(nowMs) {
        _startMs = nowMs;
        _boundaryMs = nowMs;
    }

    // Returning from REST into the next length: the rest time must NOT be counted
    // into the upcoming length's duration, so the boundary resets here.
    function markResume(nowMs) {
        _boundaryMs = nowMs;
    }

    // One completed length confirmed by a wall touch. Returns true if accepted.
    function confirmLap(nowMs) {
        if (nowMs - _lastLapMs < _lapDebounceMs) {
            return false;   // debounce: accidental/bouncy repeat
        }
        var dur = nowMs - _boundaryMs;
        if (dur < 0) { dur = 0; }
        _splitsMs.add(dur);
        _boundaryMs = nowMs;
        _lastLapMs = nowMs;
        return true;
    }

    function lapCount() { return _splitsMs.size(); }

    function distanceMeters() { return lapCount() * _poolLength; }

    function poolLength() { return _poolLength; }

    // Duration of the most recently completed length, ms (0 if none yet).
    function lastSplitMs() {
        var n = _splitsMs.size();
        return n > 0 ? _splitsMs[n - 1] : 0;
    }

    // Total swimming time (sum of length durations; rest is excluded by design).
    function movingTimeMs() {
        var t = 0;
        for (var i = 0; i < _splitsMs.size(); i += 1) { t += _splitsMs[i]; }
        return t;
    }

    // Pace as seconds per 100 m, derived only from confirmed distance & moving
    // time. Returns null until there is distance to divide by.
    function pacePer100Sec() {
        var dist = distanceMeters();
        if (dist <= 0) { return null; }
        var movingSec = movingTimeMs() / 1000.0;
        return (movingSec / (dist / 100.0));
    }

    // Snapshot for the sync payload (server/README.md contract).
    function splitsMs() { return _splitsMs; }
}
