// BreathingController — runs a vibration-guided breathing set from the spec.
//
// Two modes, ONE implementation (design-rationale section 6):
//   - HR-target mode: loops the protocol phases until HrMonitor says stop
//     (debounced HR <= target) or the hard cap fires.
//   - Fixed mode (end-of-session recovery): same phase loop, NO HR target,
//     ends after a fixed duration.
//
// Tick-driven by SessionController (which owns the single Timer) so there is no
// per-frame allocation here. Exposes glanceable display state for the view: the
// current phase word and a 0..1 ring scale that expands on inhale / contracts on
// exhale / holds during holds.
class BreathingController {

    private var _spec;
    private var _haptics;
    private var _hr;            // HrMonitor

    private var _phases;        // Array of {name,durationMs,haptic}
    private var _cycleMs;       // sum of phase durations
    private var _startMs;
    private var _phaseIdx;      // current phase index (-1 before first tick)
    private var _fixed;         // bool: fixed-duration (recovery) mode
    private var _durationMs;    // for fixed mode

    private var _hrSampleIntervalMs;
    private var _lastSampleMs;

    // ring animation
    private var _ringScale;     // 0..1
    private var _ringFrom;
    private var _ringTo;

    function initialize(spec, haptics, hrMonitor) {
        _spec = spec;
        _haptics = haptics;
        _hr = hrMonitor;
        _hrSampleIntervalMs = spec.hrSampleIntervalMs();
    }

    function startHrTarget(protocolKey, targetBpm, nowMs) {
        _begin(protocolKey, nowMs);
        _fixed = false;
        _hr.start(targetBpm, nowMs);
    }

    function startFixed(protocolKey, durationMs, nowMs) {
        _begin(protocolKey, nowMs);
        _fixed = true;
        _durationMs = durationMs;
        _hr.start(null, nowMs);   // no target; still records for recovery stat
    }

    private function _begin(protocolKey, nowMs) {
        _phases = _spec.protocolPhases(protocolKey);
        _cycleMs = 0;
        for (var i = 0; i < _phases.size(); i += 1) {
            _cycleMs += _phases[i]["durationMs"];
        }
        if (_cycleMs <= 0) { _cycleMs = 1; }
        _startMs = nowMs;
        _phaseIdx = -1;
        _lastSampleMs = -100000;
        _ringScale = 0.0;
        _ringFrom = 0.0;
        _ringTo = 0.0;
    }

    // Advance one tick. rawHr may be null (HR unavailable). Returns one of:
    //   :continue :targetMet :hardCap :durationDone
    function tick(nowMs, rawHr) {
        // 1) sample HR at the configured cadence (not every animation tick)
        if (nowMs - _lastSampleMs >= _hrSampleIntervalMs) {
            _hr.addSample(rawHr, nowMs);   // null is handled inside HrMonitor
            _lastSampleMs = nowMs;
        }

        // 2) figure out which phase we're in and fire haptics on entry
        var cyclePos = (nowMs - _startMs) % _cycleMs;
        var idx = 0;
        var acc = 0;
        for (var i = 0; i < _phases.size(); i += 1) {
            acc += _phases[i]["durationMs"];
            if (cyclePos < acc) { idx = i; break; }
        }
        if (idx != _phaseIdx) {
            _onPhaseEnter(idx);
        }

        // 3) animate the ring within the current phase
        var phaseStartAcc = 0;
        for (var j = 0; j < idx; j += 1) { phaseStartAcc += _phases[j]["durationMs"]; }
        var phaseDur = _phases[idx]["durationMs"];
        var frac = phaseDur > 0 ? (cyclePos - phaseStartAcc).toFloat() / phaseDur : 0.0;
        if (frac < 0.0) { frac = 0.0; } else if (frac > 1.0) { frac = 1.0; }
        _ringScale = _ringFrom + (_ringTo - _ringFrom) * frac;

        // 4) decide whether to stop
        if (_fixed) {
            if (nowMs - _startMs >= _durationMs) { return :durationDone; }
            return :continue;
        }
        return _hr.decision(nowMs);
    }

    private function _onPhaseEnter(idx) {
        _phaseIdx = idx;
        var name = _phases[idx]["name"];
        // ring targets: inhale -> full, exhale -> empty, hold -> stay put
        _ringFrom = _ringScale;
        if (name.equals("inhale")) {
            _ringTo = 1.0;
        } else if (name.equals("exhale")) {
            _ringTo = 0.0;
        } else {
            _ringTo = _ringScale;   // hold
        }
        // distinct haptic per phase transition (long / two-short / tap)
        _haptics.play(_spec.haptic(_phases[idx]["haptic"]));
    }

    // --- display state for BreathingView (no allocation) ---
    function phaseName() {
        if (_phaseIdx < 0) { return _phases[0]["name"]; }
        return _phases[_phaseIdx]["name"];
    }
    function ringScale() { return _ringScale; }           // 0..1
    function smoothedHr(nowMs) { return _hr.smoothedHr(nowMs); }
    function hrAvailable(nowMs) { return _hr.isHrAvailable(nowMs); }
    function target() { return _hr.target(); }
    function elapsedMs(nowMs) { return nowMs - _startMs; }

    // Fire the closing "boom" done-buzz (called by SessionController on stop).
    function doneBuzz() { _haptics.play(_spec.haptic("done")); }
}
