using Toybox.WatchUi;

// InputRouter — the ONLY input delegate. It is deliberately "dumb": it maps the
// device-independent BehaviorDelegate callbacks (which Connect IQ already maps
// from the physical buttons per device) to abstract semantic intents, and lets
// SessionController translate those into spec events for the current state. This
// keeps button handling device-independent (design-rationale section 8) — the
// same router would work on a future touch device.
//
// Physical mapping on the Instinct 2X (5 buttons, no touch):
//   // VERIFY against the device: BehaviorDelegate routes the top-right START/GPS
//   // button to onSelect, the lower-right (BACK/LAP) to onBack, the left UP/DOWN
//   // to onPreviousPage/onNextPage, and a long-press to onMenu. Confirm these on
//   // hardware; adjust here only (the rest of the app is button-agnostic).
class InputRouter extends WatchUi.BehaviorDelegate {

    private var _c;   // SessionController

    function initialize(controller) {
        BehaviorDelegate.initialize();
        _c = controller;
    }

    // Primary action (START button): LAP / confirm / push-off / pick mode.
    function onSelect() {
        return _c.onPrimary();
    }

    // Back / lower-right: context-dependent (rest, cancel breathing, etc.).
    function onBack() {
        return _c.onBackBtn();
    }

    // Up / Down: secondary & tertiary actions (mode toggle, start breathing…).
    function onNextPage() {
        return _c.onSecondary();
    }
    function onPreviousPage() {
        return _c.onTertiary();
    }

    // Long-press menu: stop / end session.
    function onMenu() {
        return _c.onMenuBtn();
    }
}
