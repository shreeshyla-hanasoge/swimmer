using Toybox.WatchUi;
using Toybox.Application;

// Spec — loads the behavior-spec JSON resources (the synced copy of
// packages/behavior-spec) and exposes typed, fallback-guarded accessors.
//
// This is what makes the Garmin app DATA-DRIVEN: timings, thresholds, haptics
// and the state machine all come from JSON, not from hardcoded constants. If a
// device can't load JSON resources (older API), every accessor falls back to a
// safe embedded default so the app still runs correctly.
//
// Loaded once at startup and cached (memory: small dictionaries, read-only).
class Spec {

    private var _defaults;     // Dictionary or null
    private var _breathing;    // Dictionary or null
    private var _stateMachine; // Dictionary or null

    function initialize() {
        // Rez.JsonData members are compile-time resource ids and must be
        // referenced literally (they are not a runtime-indexable dictionary).
        // Each is guarded so a device without JSON-resource support (or a
        // missing id) falls back to the embedded defaults below.
        if (Rez has :JsonData) {
            if (Rez.JsonData has :SpecDefaults) {
                _defaults = WatchUi.loadResource(Rez.JsonData.SpecDefaults);
            }
            if (Rez.JsonData has :SpecBreathing) {
                _breathing = WatchUi.loadResource(Rez.JsonData.SpecBreathing);
            }
            if (Rez.JsonData has :SpecStateMachine) {
                _stateMachine = WatchUi.loadResource(Rez.JsonData.SpecStateMachine);
            }
        }
    }

    // --- defaults.json (with embedded fallbacks matching the JSON) ---

    private function _d(section, key, fallback) {
        if (_defaults != null) {
            var s = _defaults[section];
            if (s != null && s[key] != null) { return s[key]; }
        }
        return fallback;
    }

    // Returns the autoStop config in the shape HrMonitor expects.
    function autoStopConfig() {
        return {
            :smoothingWindowSamples => _d("heartRate", "smoothingWindowSamples", 5),
            :debounceMs             => _d("autoStop", "debounceMs", 4000),
            :hardCapMs              => _d("autoStop", "hardCapMs", 120000),
            :staleSampleMs          => _d("autoStop", "staleSampleMs", 5000),
            :nullCountsAsBelow      => _d("autoStop", "nullCountsAsBelow", false)
        };
    }

    function hrTargetOffsetBpm() { return _d("heartRate", "targetOffsetBpm", 25); }
    function hrAbsoluteFloorBpm() { return _d("heartRate", "absoluteFloorBpm", 60); }
    function hrSampleIntervalMs() { return _d("heartRate", "sampleIntervalMs", 1000); }
    function hrRecoveryWindowSec() { return _d("heartRate", "recoveryWindowSec", 60); }

    function defaultPoolLengthMeters() { return _d("pool", "lengthMeters", 25.0); }
    function lapDebounceMs() { return _d("ui", "lapDebounceMs", 600); }
    function resumingCountdownSec() { return _d("ui", "resumingCountdownSec", 3); }
    function recoveryDurationMs() { return _d("breathing", "recoveryDurationMs", 60000); }
    function defaultProtocolKey() { return _d("breathing", "defaultProtocol", "box"); }

    // --- breathing-protocols.json ---

    // Returns the phases array for a protocol key, each entry a dictionary
    // { "name", "durationMs", "haptic" }. Falls back to box 4-4-4-4.
    function protocolPhases(key) {
        if (_breathing != null) {
            var protos = _breathing["protocols"];
            if (protos != null && protos[key] != null && protos[key]["phases"] != null) {
                return protos[key]["phases"];
            }
        }
        return [
            { "name" => "inhale", "durationMs" => 4000, "haptic" => "inhale" },
            { "name" => "hold",   "durationMs" => 4000, "haptic" => "hold" },
            { "name" => "exhale", "durationMs" => 4000, "haptic" => "exhale" },
            { "name" => "hold",   "durationMs" => 4000, "haptic" => "hold" }
        ];
    }

    // Symbolic haptic descriptor for a cue name (inhale/exhale/hold/done).
    function haptic(name) {
        if (_breathing != null) {
            var h = _breathing["haptics"];
            if (h != null && h[name] != null) { return h[name]; }
        }
        // Conservative fallbacks (dutyCycle, lengthMs, pulses, gapMs).
        var fb = {
            "inhale" => { "pulses" => 1, "dutyCycle" => 75, "lengthMs" => 800, "gapMs" => 0 },
            "exhale" => { "pulses" => 2, "dutyCycle" => 60, "lengthMs" => 180, "gapMs" => 120 },
            "hold"   => { "pulses" => 1, "dutyCycle" => 40, "lengthMs" => 120, "gapMs" => 0 },
            "done"   => { "pulses" => 3, "dutyCycle" => 90, "lengthMs" => 250, "gapMs" => 120 }
        };
        return fb[name];
    }

    // --- state-machine.json ---

    // Resolve a transition for (stateName, eventName). Returns a dictionary with
    // "target" and "effects" (array), or null if the event is not valid here.
    function transition(stateName, eventName) {
        if (_stateMachine != null) {
            var states = _stateMachine["states"];
            if (states != null && states[stateName] != null) {
                var trans = states[stateName]["transitions"];
                if (trans != null) {
                    for (var i = 0; i < trans.size(); i += 1) {
                        if (trans[i]["event"].equals(eventName)) {
                            return trans[i];
                        }
                    }
                }
            }
        }
        return null;
    }

    // onEnter effects array for a state (or null). Lets SessionController run a
    // state's entry side-effects straight from the spec.
    function onEnterEffects(stateName) {
        if (_stateMachine != null) {
            var states = _stateMachine["states"];
            if (states != null && states[stateName] != null) {
                return states[stateName]["onEnter"];
            }
        }
        return null;
    }

    function initialState() {
        if (_stateMachine != null && _stateMachine["initial"] != null) {
            return _stateMachine["initial"];
        }
        return "MODE_SELECT";
    }
}
