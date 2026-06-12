using Toybox.WatchUi;
using Toybox.Graphics;

// ACTIVE: recording. Big distance, plus laps / last split / pace per 100.
// Identical metric set for swim and kick — NO stroke/SWOLF fields ever (design-
// rationale section 3). START = LAP, BACK = rest, long-press = stop.
class ActiveView extends WatchUi.View {

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

        // mode banner
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var modeStr = _c.mode().equals("kick")
            ? WatchUi.loadResource(Rez.Strings.ModeKick)
            : WatchUi.loadResource(Rez.Strings.ModeSwim);
        dc.drawText(w / 2, h * 0.08, Graphics.FONT_XTINY, modeStr, Graphics.TEXT_JUSTIFY_CENTER);

        // big distance (the number that matters)
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.34, Graphics.FONT_NUMBER_MEDIUM,
            Fmt.dist(lap.distanceMeters()),
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);

        // secondary row: laps  |  last  |  /100 pace
        _kv(dc, w * 0.20, h * 0.66, WatchUi.loadResource(Rez.Strings.LabelLaps),
            lap.lapCount().toString());
        _kv(dc, w * 0.50, h * 0.66, WatchUi.loadResource(Rez.Strings.LabelLast),
            Fmt.durMs(lap.lastSplitMs()));
        _kv(dc, w * 0.80, h * 0.66, WatchUi.loadResource(Rez.Strings.LabelPace),
            Fmt.pace(lap.pacePer100Sec()));
    }

    private function _kv(dc, x, y, label, value) {
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y, Graphics.FONT_XTINY, label, Graphics.TEXT_JUSTIFY_CENTER);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, y + 18, Graphics.FONT_TINY, value, Graphics.TEXT_JUSTIFY_CENTER);
    }
}
