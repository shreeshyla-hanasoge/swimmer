using Toybox.WatchUi;
using Toybox.Graphics;

// SUMMARY: end-of-session totals. Distance / laps / pace, plus the HR-recovery
// drop captured during the closing recovery phase. START or BACK = done (reset
// to MODE_SELECT). The sync payload has already been queued by the controller.
class SummaryView extends WatchUi.View {

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

        var lap = _c.lap();

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.08, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.SummaryTitle), Graphics.TEXT_JUSTIFY_CENTER);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.32, Graphics.FONT_NUMBER_MEDIUM,
            Fmt.dist(lap.distanceMeters()),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        _kv(dc, w * 0.25, h * 0.60, WatchUi.loadResource(Rez.Strings.LabelLaps),
            lap.lapCount().toString());
        _kv(dc, w * 0.75, h * 0.60, WatchUi.loadResource(Rez.Strings.LabelPace),
            Fmt.pace(lap.pacePer100Sec()));

        // HR recovery drop (bpm over the recovery window), if captured.
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.84, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.LabelHrDrop) + " " + _c.hrDropString(),
            Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _kv(dc, x, y, label, value) {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 18, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
