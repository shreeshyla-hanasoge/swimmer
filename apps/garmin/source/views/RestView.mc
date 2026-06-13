using Toybox.WatchUi;
using Toybox.Graphics;

// REST: at the wall. Running totals + rest clock. From here START pushes off into
// the next length, DOWN starts a breathing set, UP starts end-of-session
// recovery, long-press stops. After a breathing set the "RESUMING 3.2.1"
// countdown shows here, then it falls back to the totals.
class RestView extends WatchUi.View {

    private var _c;

    function initialize(controller) {
        View.initialize();
        _c = controller;
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        // The "boom" aftermath: Resuming 3 . 2 . 1 takes over the whole screen.
        var countdown = _c.resumeCountdown();
        if (countdown > 0) {
            _drawResuming(dc, w, h, countdown);
            return;
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.08, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.LabelRest), Graphics.TEXT_JUSTIFY_CENTER);

        if (_c.targetNotReached()) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(w / 2, h * 0.20, Graphics.FONT_XTINY,
                WatchUi.loadResource(Rez.Strings.TargetNotReached),
                Graphics.TEXT_JUSTIFY_CENTER);
        }

        var lap = _c.lap();

        // big rest clock
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.40, Graphics.FONT_NUMBER_MEDIUM,
            Fmt.durMs(_c.restElapsedMs()),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // totals row
        _kv(dc, w * 0.25, h * 0.66, WatchUi.loadResource(Rez.Strings.LabelDist),
            Fmt.dist(lap.distanceMeters()));
        _kv(dc, w * 0.75, h * 0.66, WatchUi.loadResource(Rez.Strings.LabelLaps),
            lap.lapCount().toString());

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.88, Graphics.FONT_XTINY,
            "DOWN breathe  UP recover", Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _drawResuming(dc, w, h, n) {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.28, Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.Resuming), Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.55, Graphics.FONT_NUMBER_THAI_HOT, n.toString(),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    private function _kv(dc, x, y, label, value) {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 18, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
