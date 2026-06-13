using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.System;

// MODE_SELECT: pick Swim or Kick. Monochrome, high-contrast, button-only.
// UP/DOWN toggles the highlight; START confirms.
class ModeSelectView extends WatchUi.View {

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

        dc.drawText(w / 2, h * 0.10, Graphics.FONT_SMALL,
            WatchUi.loadResource(Rez.Strings.AppName), Graphics.TEXT_JUSTIFY_CENTER);

        var swimSel = _c.modeHighlight().equals("swim");
        _drawOption(dc, w, h * 0.40, WatchUi.loadResource(Rez.Strings.ModeSwim), swimSel);
        _drawOption(dc, w, h * 0.62, WatchUi.loadResource(Rez.Strings.ModeKick), !swimSel);

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(w / 2, h * 0.85, Graphics.FONT_XTINY,
            WatchUi.loadResource(Rez.Strings.ModeSelectHint), Graphics.TEXT_JUSTIFY_CENTER);
    }

    private function _drawOption(dc, w, y, label, selected) {
        if (selected) {
            // Invert: filled bar with black text = the cursor (glanceable on MIP).
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.fillRectangle(w * 0.15, y - 18, w * 0.70, 36);
            dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_TRANSPARENT);
        } else {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        }
        dc.drawText(w / 2, y, Graphics.FONT_MEDIUM, label,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }
}
