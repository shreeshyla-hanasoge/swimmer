using Toybox.System;

// HrMonitor — the robust HR auto-stop core (design-rationale section 5).
//
// Deliberately has NO dependency on Activity/Sensor APIs: the caller feeds it
// raw samples (which may be null) together with a monotonic millisecond clock,
// and asks it for a decision. That keeps the smoothing / debounce / null /
// hard-cap logic fully unit-testable (see source/tests/HrMonitorTest.mc).
//
// Decision values:
//   :continue    keep breathing
//   :targetMet   smoothed HR stayed <= target for >= debounceMs  ("boom")
//   :hardCap     hit the absolute time ceiling above target       ("target not reached")
class HrMonitor {

    // --- config (from behavior-spec defaults.json) ---
    private var _window;          // smoothing window, samples
    private var _debounceMs;      // sustained-below requirement
    private var _hardCapMs;       // absolute ceiling
    private var _staleMs;         // a sample older than this => HR unavailable
    private var _nullBelow;       // do null readings count as below target? (spec: false)

    // --- fixed-size ring buffer (no per-sample allocation) ---
    private var _vals;            // Array<Number or Null>
    private var _times;           // Array<Number> ms
    private var _head;            // next write index
    private var _filled;          // count of valid entries (<= window)

    private var _target;          // bpm, or null for "no target" (recovery)
    private var _startMs;
    private var _belowSinceMs;    // when smoothed first went/stayed <= target, else null
    private var _lastFreshMs;     // last time we got a non-null sample
    private var _lastWasNull;     // was the most recent reading dropped/absent?

    function initialize(cfg) {
        _window     = cfg[:smoothingWindowSamples];
        _debounceMs = cfg[:debounceMs];
        _hardCapMs  = cfg[:hardCapMs];
        _staleMs    = cfg[:staleSampleMs];
        _nullBelow  = cfg[:nullCountsAsBelow];
        _vals  = new [_window];
        _times = new [_window];
        reset();
    }

    function reset() {
        for (var i = 0; i < _window; i += 1) { _vals[i] = null; _times[i] = 0; }
        _head = 0;
        _filled = 0;
        _target = null;
        _startMs = 0;
        _belowSinceMs = null;
        _lastFreshMs = -1;
        _lastWasNull = true;   // no data yet == not "below"
    }

    // targetBpm may be null (recovery / no-target mode).
    function start(targetBpm, nowMs) {
        reset();
        _target = targetBpm;
        _startMs = nowMs;
    }

    // Push one reading. rawHr may be null (dropped/absent — section 4).
    // Null readings are NOT stored as samples; they simply mean "no fresh data".
    function addSample(rawHr, nowMs) {
        if (rawHr != null && rawHr > 0) {
            _vals[_head] = rawHr;
            _times[_head] = nowMs;
            _head = (_head + 1) % _window;
            if (_filled < _window) { _filled += 1; }
            _lastFreshMs = nowMs;
            _lastWasNull = false;
        } else {
            // A dropped/absent reading: record that the latest data is missing so
            // the auto-stop debounce is reset (a dropout can never complete a stop).
            _lastWasNull = true;
        }
    }

    // Rolling average over fresh (non-stale) samples; null if none fresh.
    function smoothedHr(nowMs) {
        var sum = 0;
        var n = 0;
        for (var i = 0; i < _window; i += 1) {
            var v = _vals[i];
            if (v != null && (nowMs - _times[i]) <= _staleMs) {
                sum += v;
                n += 1;
            }
        }
        if (n == 0) { return null; }
        return (sum / n).toNumber();
    }

    function isHrAvailable(nowMs) {
        return _lastFreshMs >= 0 && (nowMs - _lastFreshMs) <= _staleMs;
    }

    function target() { return _target; }

    function elapsedMs(nowMs) { return nowMs - _startMs; }

    // The auto-stop decision. Robust by construction:
    //  - compares the SMOOTHED value, not raw
    //  - requires sustained-below for debounceMs (any miss resets the timer)
    //  - null / stale / above-target all RESET the debounce (never count as below)
    //  - hard cap fires regardless so the user is never trapped
    function decision(nowMs) {
        if (_target != null) {
            var sm = smoothedHr(nowMs);
            // "below" requires fresh, non-null data AND the most recent reading
            // present. A null/stale latest reading resets the debounce.
            var below = (sm != null) && isHrAvailable(nowMs) && !_lastWasNull && (sm <= _target);
            if (!below && _nullBelow && sm == null) {
                // Opt-in only; spec keeps this false so dropouts can't fake a stop.
                below = true;
            }
            if (below) {
                if (_belowSinceMs == null) { _belowSinceMs = nowMs; }
                if (nowMs - _belowSinceMs >= _debounceMs) {
                    return :targetMet;
                }
            } else {
                _belowSinceMs = null;   // reset debounce on any non-below sample
            }
        }
        if (nowMs - _startMs >= _hardCapMs) {
            return :hardCap;
        }
        return :continue;
    }
}
