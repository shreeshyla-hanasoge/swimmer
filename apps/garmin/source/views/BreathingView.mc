using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

// BREATHING (and RECOVERY): the minimal HR-first screen. A large live HR number
// fills the centre; a single ring expands on inhale and contracts on exhale as
// the breathing cue. The HAPTICS are the primary guide — this visual is backup,
// and is trivially strippable to HR-only. Monochrome, no allocation per frame.
//
// When HR is unavailable (design-rationale section 4) we show "HR --" plus a
// one-line setup hint instead of a fake number; the set still runs on its cap.
class BreathingView extends WatchUi.View {

    private var _c;

    function initialize(controller) {
        View.initialize();
        _c = controller;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;
        var cy = h / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        var now = System.getTimer();
        var breathing = _c.breathing();
        var recovery = _c.state().equals("RECOVERY");

        // --- breathing ring (backup cue) ---
        var maxR = (w < h ? w : h) * 0.46;
        var minR = maxR * 0.30;
        var r = minR + (maxR - minR) * breathing.ringScale();
        dc.setPenWidth(4);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, maxR);            // outer reference
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);               // live, breathing ring
        dc.setPenWidth(1);

        // --- top label: phase word, or RECOVERY ---
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var top = recovery
            ? WatchUi.loadResource(Rez.Strings.Recovery)
            : _phaseWord(breathing.phaseName());
        dc.drawText(cx, h * 0.14, Graphics.FONT_XTINY, top, Graphics.TEXT_JUSTIFY_CENTER);

        // --- centre: the big live HR (the thing you glance at) ---
        if (breathing.hrAvailable(now)) {
            var hr = breathing.smoothedHr(now);
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 6, Graphics.FONT_NUMBER_HOT,
                hr != null ? hr.toString() : "--",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            var tgt = breathing.target();
            var sub = tgt != null
                ? (WatchUi.loadResource(Rez.Strings.LabelTarget) + " " + tgt.toString())
                : WatchUi.loadResource(Rez.Strings.LabelBpm);
            dc.drawText(cx, h * 0.74, Graphics.FONT_XTINY, sub, Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            // HR unavailable: honest "--" + setup hint, never a fabricated value.
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, cy - 6, Graphics.FONT_NUMBER_MEDIUM,
                WatchUi.loadResource(Rez.Strings.HrUnavailable),
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, h * 0.78, Graphics.FONT_XTINY,
                WatchUi.loadResource(Rez.Strings.HrSetupHint), Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    private function _phaseWord(name) {
        if (name.equals("inhale")) { return WatchUi.loadResource(Rez.Strings.PhaseInhale); }
        if (name.equals("exhale")) { return WatchUi.loadResource(Rez.Strings.PhaseExhale); }
        return WatchUi.loadResource(Rez.Strings.PhaseHold);
    }
}
