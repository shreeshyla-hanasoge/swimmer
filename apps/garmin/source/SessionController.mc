using Toybox.WatchUi;
using Toybox.Activity;
using Toybox.ActivityRecording;
using Toybox.Application;
using Toybox.System;
using Toybox.Timer;
using Toybox.Math;

// SessionController — the brain that ties everything together and DRIVES THE
// STATE MACHINE FROM THE SPEC (packages/behavior-spec/state-machine.json, loaded
// via Spec). Transitions are looked up in data; only the effect implementations
// live in code. Owns the single Timer (no per-view timers), the LapEngine, the
// HrMonitor, the BreathingController, the recording session and the SyncClient.
class SessionController {

    private const TICK_MS = 100;

    private var _spec;
    private var _haptics;
    private var _lap;
    private var _hr;
    private var _breathing;
    private var _sync;

    private var _delegate;        // single reused InputRouter
    private var _timer;
    private var _state;           // current state name (string, from spec)

    private var _session;         // ActivityRecording.Session or null
    private var _mode;            // "swim" | "kick"
    private var _modeHighlight;   // mode-select cursor: "swim" | "kick"

    private var _recentHr;        // last non-null raw HR (for baseline/targets)
    private var _restStartMs;
    private var _resumeUntilMs;   // "Resuming 3..2..1" countdown end (ms), or 0
    private var _targetNotReached;

    // recovery / summary capture
    private var _recoveryStartBpm;
    private var _hrRecovery;      // dict or null
    private var _breathingSets;   // array for summary
    private var _curBreathingSet; // dict being filled
    private var _clientSessionId;

    function initialize() {
        _spec = new Spec();
        _haptics = new Haptics();
        _hr = new HrMonitor(_spec.autoStopConfig());
        _breathing = new BreathingController(_spec, _haptics, _hr);
        _sync = new SyncClient();
        _delegate = new InputRouter(self);
        _timer = new Timer.Timer();
        _state = _spec.initialState();
        _modeHighlight = "swim";
        _resetSessionData();
    }

    function start() {
        _timer.start(method(:onTick), TICK_MS, true);
    }

    function stop() {
        _timer.stop();
        if (_session != null && _session.isRecording()) {
            _session.discard();
        }
    }

    function initialView() { return [ _viewFor(_state), _delegate ]; }
    function delegate() { return _delegate; }
    function state() { return _state; }
    function mode() { return _mode; }
    function modeHighlight() { return _modeHighlight; }
    function lap() { return _lap; }
    function breathing() { return _breathing; }
    function spec() { return _spec; }
    function targetNotReached() { return _targetNotReached; }

    // ----- live values for views -----
    function recentHr() { return _recentHr; }
    function restElapsedMs() {
        return _restStartMs > 0 ? (System.getTimer() - _restStartMs) : 0;
    }
    // Resuming countdown seconds remaining (0 when not counting down).
    function resumeCountdown() {
        if (_resumeUntilMs <= 0) { return 0; }
        var rem = _resumeUntilMs - System.getTimer();
        if (rem <= 0) { return 0; }
        return (rem / 1000).toNumber() + 1;
    }

    // =====================================================================
    // Timer tick — samples HR and advances any running breathing set.
    // =====================================================================
    function onTick() {
        var now = System.getTimer();
        var hr = _readHr();
        if (hr != null) { _recentHr = hr; }

        if (_state.equals("BREATHING") || _state.equals("RECOVERY")) {
            var status = _breathing.tick(now, hr);
            if (status == :targetMet) {
                handleEvent("HR_TARGET_MET");
            } else if (status == :hardCap) {
                handleEvent("HARD_CAP");
            } else if (status == :durationDone) {
                handleEvent("DURATION_DONE");
            }
            WatchUi.requestUpdate();
        } else if (_resumeUntilMs > 0) {
            if (System.getTimer() >= _resumeUntilMs) { _resumeUntilMs = 0; }
            WatchUi.requestUpdate();
        } else if (_state.equals("REST") || _state.equals("ACTIVE")) {
            // Cheap 1 Hz refresh for the running rest/total clock.
            if (now % 1000 < TICK_MS) { WatchUi.requestUpdate(); }
        }
    }

    // =====================================================================
    // Event handling — looked up in the spec, then effects applied in code.
    // =====================================================================
    function handleEvent(event) {
        var t = _spec.transition(_state, event);
        if (t == null) { return false; }

        _applyEffects(t["effects"]);
        _state = t["target"];
        _runOnEnter(_state);
        WatchUi.switchToView(_viewFor(_state), _delegate, WatchUi.SLIDE_IMMEDIATE);
        return true;
    }

    private function _runOnEnter(stateName) {
        // onEnter effects are encoded per-state in the spec too.
        var onEnter = _spec.onEnterEffects(stateName);
        if (onEnter != null) { _applyEffects(onEnter); }
    }

    private function _applyEffects(effects) {
        if (effects == null) { return; }
        for (var i = 0; i < effects.size(); i += 1) {
            _applyEffect(effects[i]);
        }
    }

    // Interpret a single effect string from the spec. Unknown effects are
    // ignored so the spec can evolve without breaking an older client.
    private function _applyEffect(effect) {
        var name = effect;
        var arg = null;
        var colon = effect.find(":");
        if (colon != null) {
            name = effect.substring(0, colon);
            arg = effect.substring(colon + 1, effect.length());
        }

        if (name.equals("startSession")) {
            _startSession(arg);
        } else if (name.equals("confirmLap")) {
            _confirmLap();
        } else if (name.equals("markRestStart")) {
            _restStartMs = System.getTimer();
        } else if (name.equals("resumeRecording")) {
            _lap.markResume(System.getTimer());
            _restStartMs = 0;
            _targetNotReached = false;   // clear any prior banner on push-off
        } else if (name.equals("startBreathing")) {
            _startBreathing(arg);
        } else if (name.equals("doneBuzz")) {
            _breathing.doneBuzz();
        } else if (name.equals("resumingCountdown")) {
            _resumeUntilMs = System.getTimer() + _spec.resumingCountdownSec() * 1000;
        } else if (name.equals("recordBreathingSet")) {
            _finishBreathingSet(arg);            // arg = "hrTargetMet"
        } else if (name.equals("markTargetNotReached")) {
            _targetNotReached = true;
            _finishBreathingSet("hardCap");
        } else if (name.equals("abortBreathing")) {
            _finishBreathingSet("cancelled");
        } else if (name.equals("captureHrRecovery")) {
            _captureHrRecovery();
        } else if (name.equals("endSession")) {
            _endSession();
        } else if (name.equals("queueSyncPayload")) {
            _queueSync();
        } else if (name.equals("reset")) {
            _resetSessionData();
        } else if (name.equals("stopAnyRecording")) {
            if (_session != null && _session.isRecording()) { _session.discard(); }
            _session = null;
        }
        // No-ops handled elsewhere: showRestTotals / computeSummary /
        // captureBaselineHr (baseline = _recentHr captured in _startBreathing) /
        // beginBreathingLoop / beginRecoveryLoop / pauseRecording.
    }

    // ----- concrete effect implementations -----

    private function _startSession(modeArg) {
        _resetSessionData();
        _mode = modeArg;   // "swim" | "kick"
        var poolLen = _poolLength();
        _lap = new LapEngine(poolLen, _spec.lapDebounceMs());
        _lap.markStart(System.getTimer());

        // Build the recording session. Pool length is REQUIRED for lap swimming.
        // Kick uses a generic sub-sport so the watch does NOT run arm-stroke
        // detection (design-rationale section 3); we self-compute distance.
        var opts;
        if (_mode.equals("kick")) {
            opts = {
                :name => "SwimCoach Kick",
                :sport => Activity.SPORT_SWIMMING,
                // VERIFY exact constant name in your SDK (Activity.SUB_SPORT_GENERIC).
                // Goal: no stroke/SWOLF detection; distance is laps x poolLength only.
                :subSport => Activity.SUB_SPORT_GENERIC
            };
        } else {
            opts = {
                :name => "SwimCoach Swim",
                :sport => Activity.SPORT_SWIMMING,
                :subSport => Activity.SUB_SPORT_LAP_SWIMMING,
                :poolLength => poolLen   // metres; required for lap swimming
            };
        }
        if (ActivityRecording has :createSession) {
            _session = ActivityRecording.createSession(opts);
            _session.start();
        }
    }

    private function _confirmLap() {
        var accepted = _lap.confirmLap(System.getTimer());
        if (accepted && _session != null && _session.isRecording()) {
            // Mark a FIT lap at each confirmed wall touch.
            _session.addLap();
        }
    }

    private function _startBreathing(modeArg) {
        var protocol = _protocolKey();
        var now = System.getTimer();
        _curBreathingSet = {
            "protocol" => protocol,
            "baselineHrBpm" => _recentHr,
            "targetHrBpm" => null,
            "endReason" => null
        };
        _targetNotReached = false;

        if (modeArg != null && modeArg.equals("fixedDuration")) {
            // End-of-session recovery: no HR target, fixed duration.
            _recoveryStartBpm = _recentHr;
            _breathing.startFixed(protocol, _recoveryDurationMs(), now);
        } else {
            // HR target = end-of-set HR - offset, clamped to the floor. If HR is
            // unavailable (baseline null), run with no target -> hard cap + hint.
            var target = null;
            if (_recentHr != null) {
                target = _recentHr - _hrOffset();
                var floor = _spec.hrAbsoluteFloorBpm();
                if (target < floor) { target = floor; }
            }
            _curBreathingSet["targetHrBpm"] = target;
            _breathing.startHrTarget(protocol, target, now);
        }
    }

    private function _finishBreathingSet(reason) {
        if (_curBreathingSet != null) {
            _curBreathingSet["endReason"] = reason;
            _curBreathingSet["durationSec"] =
                (_breathing.elapsedMs(System.getTimer()) / 1000).toNumber();
            _breathingSets.add(_curBreathingSet);
            _curBreathingSet = null;
        }
    }

    private function _captureHrRecovery() {
        var endBpm = _recentHr;
        if (_recoveryStartBpm != null && endBpm != null) {
            _hrRecovery = {
                "windowSec" => _spec.hrRecoveryWindowSec(),
                "startBpm" => _recoveryStartBpm,
                "endBpm" => endBpm,
                "dropBpm" => _recoveryStartBpm - endBpm
            };
        }
        // recovery is the closing of a breathing loop, record it as a set too
        if (_curBreathingSet != null) { _finishBreathingSet("recovery"); }
    }

    private function _endSession() {
        if (_session != null) {
            if (_session.isRecording()) { _session.stop(); }
            _session.save();
            _session = null;
        }
    }

    private function _queueSync() {
        // Build the summary (server/README.md contract) and hand it to the
        // single networking module. Stub today; best-effort, never blocks.
        var summary = {
            :clientSessionId => _clientSessionId,
            :mode => _mode,
            :poolLengthMeters => _lap.poolLength(),
            :totalDistanceMeters => _lap.distanceMeters(),
            :lapCount => _lap.lapCount(),
            :movingTimeSec => (_lap.movingTimeMs() / 1000).toNumber(),
            :splits => _splitSummaries(),
            :breathingSets => _breathingSets,
            :hrRecovery => _hrRecovery
        };
        _sync.postSession(summary);
    }

    private function _splitSummaries() {
        var out = [];
        var s = _lap.splitsMs();
        for (var i = 0; i < s.size(); i += 1) {
            out.add({
                "index" => i + 1,
                "distanceMeters" => _lap.poolLength(),
                "durationSec" => (s[i] / 1000).toNumber()
            });
        }
        return out;
    }

    private function _resetSessionData() {
        _mode = "swim";
        _lap = new LapEngine(_poolLength(), _spec.lapDebounceMs());
        _recentHr = null;
        _restStartMs = 0;
        _resumeUntilMs = 0;
        _targetNotReached = false;
        _recoveryStartBpm = null;
        _hrRecovery = null;
        _breathingSets = [];
        _curBreathingSet = null;
        _clientSessionId = "cs-" + System.getTimer().toString() + "-" + Math.rand().toString();
    }

    // =====================================================================
    // Semantic button intents from InputRouter, mapped to spec events per state.
    // Returning true consumes the press; false lets the system handle it
    // (e.g. BACK in MODE_SELECT exits the app).
    // =====================================================================
    function onPrimary() {        // START button
        if (_state.equals("MODE_SELECT")) {
            return handleEvent(_modeHighlight.equals("kick") ? "SELECT_KICK" : "SELECT_SWIM");
        } else if (_state.equals("ACTIVE")) {
            return handleEvent("LAP");
        } else if (_state.equals("REST")) {
            return handleEvent("LAP");          // push off into next length
        } else if (_state.equals("SUMMARY")) {
            return handleEvent("DONE");
        }
        return false;
    }

    function onSecondary() {      // DOWN
        if (_state.equals("MODE_SELECT")) { toggleMode(); return true; }
        if (_state.equals("REST")) { return handleEvent("BREATHE"); }
        return false;
    }

    function onTertiary() {       // UP
        if (_state.equals("MODE_SELECT")) { toggleMode(); return true; }
        if (_state.equals("REST")) { return handleEvent("RECOVER"); }
        return false;
    }

    function onBackBtn() {        // BACK / lower-right
        if (_state.equals("ACTIVE")) { return handleEvent("REST"); }
        if (_state.equals("REST")) { return handleEvent("STOP"); }
        if (_state.equals("BREATHING") || _state.equals("RECOVERY")) { return handleEvent("CANCEL"); }
        if (_state.equals("SUMMARY")) { return handleEvent("DONE"); }
        return false;            // MODE_SELECT: let the system exit the app
    }

    function onMenuBtn() {        // long-press menu
        if (_state.equals("ACTIVE") || _state.equals("REST")) { return handleEvent("STOP"); }
        return false;
    }

    // HR-recovery drop for the summary screen ("-32" bpm), or "--" if not captured.
    function hrDropString() {
        if (_hrRecovery != null && _hrRecovery["dropBpm"] != null) {
            return "-" + _hrRecovery["dropBpm"].toString();
        }
        return "--";
    }

    // ----- mode-select cursor (UI only, not a spec transition) -----
    function toggleMode() {
        _modeHighlight = _modeHighlight.equals("swim") ? "kick" : "swim";
        WatchUi.requestUpdate();
    }

    // ----- helpers -----
    private function _readHr() {
        var info = Activity.getActivityInfo();
        if (info != null && (info has :currentHeartRate) && info.currentHeartRate != null) {
            return info.currentHeartRate;   // may legitimately be absent (section 4)
        }
        return null;
    }

    private function _viewFor(stateName) {
        if (stateName.equals("MODE_SELECT")) { return new ModeSelectView(self); }
        if (stateName.equals("ACTIVE")) { return new ActiveView(self); }
        if (stateName.equals("REST")) { return new RestView(self); }
        if (stateName.equals("BREATHING")) { return new BreathingView(self); }
        if (stateName.equals("RECOVERY")) { return new BreathingView(self); } // same UI, no target
        if (stateName.equals("SUMMARY")) { return new SummaryView(self); }
        return new ModeSelectView(self);
    }

    // settings (property override -> spec default)
    private function _prop(key, fallback) {
        if (Application has :Properties) {
            var v = Application.Properties.getValue(key);
            if (v != null) { return v; }
        }
        return fallback;
    }
    private function _poolLength() { return _prop("poolLengthMeters", _spec.defaultPoolLengthMeters()); }
    private function _hrOffset() { return _prop("hrTargetOffsetBpm", _spec.hrTargetOffsetBpm()); }
    private function _protocolKey() { return _prop("breathingProtocol", _spec.defaultProtocolKey()); }
    private function _recoveryDurationMs() {
        return _prop("recoveryDurationSec", _spec.recoveryDurationMs() / 1000) * 1000;
    }
}
