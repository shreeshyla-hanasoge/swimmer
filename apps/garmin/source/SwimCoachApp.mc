using Toybox.Application;
using Toybox.WatchUi;

// SwimCoachApp — Connect IQ application entry point. Intentionally tiny: it
// constructs the SessionController (which owns all behaviour) and hands the
// initial view to the framework. Everything testable lives outside the App.
class SwimCoachApp extends Application.AppBase {

    private var _controller;

    function initialize() {
        AppBase.initialize();
    }

    function onStart(state) {
        _controller = new SessionController();
        _controller.start();
    }

    function onStop(state) {
        if (_controller != null) {
            _controller.stop();
        }
    }

    // Initial view + input delegate for the MODE_SELECT state.
    function getInitialView() {
        return _controller.initialView();
    }

    // Re-read settings live when the user changes them in Connect IQ.
    function onSettingsChanged() {
        WatchUi.requestUpdate();
    }
}
