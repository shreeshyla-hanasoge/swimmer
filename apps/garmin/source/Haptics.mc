using Toybox.Attention;
using Toybox.System;

// Haptics — maps the spec's symbolic haptic descriptors to the device vibration
// API. The FELT pattern is the cross-platform contract; this module is the
// Garmin translation of it (design-rationale section 8: haptics are the primary
// breathing guide, the visual ring is backup).
//
// Every call is guarded twice: the device must support vibration AND the user's
// `vibrateOn` device setting must be enabled (per the prompt's vibrateOn guard).
class Haptics {

    // descriptor: { "pulses", "dutyCycle", "lengthMs", "gapMs" } from Spec.haptic(...)
    function play(descriptor) {
        if (descriptor == null) { return; }
        if (!_enabled()) { return; }

        var pulses = descriptor["pulses"];
        var duty   = descriptor["dutyCycle"];
        var len    = descriptor["lengthMs"];
        var gap    = descriptor["gapMs"];
        if (pulses == null || pulses < 1) { pulses = 1; }
        if (duty == null) { duty = 50; }
        if (len == null) { len = 200; }
        if (gap == null) { gap = 100; }

        // Attention.vibrate takes an Array of up to 8 VibeProfile(dutyCycle 0-100,
        // lengthMs). We interleave silent gaps as zero-duty profiles so multi-
        // pulse cues (e.g. "two short" for exhale) are clearly distinct.
        var profiles = [];
        for (var i = 0; i < pulses && profiles.size() < 8; i += 1) {
            profiles.add(new Attention.VibeProfile(duty, len));
            if (i < pulses - 1 && profiles.size() < 8 && gap > 0) {
                profiles.add(new Attention.VibeProfile(0, gap));
            }
        }
        Attention.vibrate(profiles);
    }

    private function _enabled() {
        // `Attention has :vibrate` guards devices/sim without haptics.
        if (!(Attention has :vibrate)) { return false; }
        var ds = System.getDeviceSettings();
        // vibrateOn reflects the user's device-level vibration toggle.
        if (ds != null && (ds has :vibrateOn) && ds.vibrateOn == false) {
            return false;
        }
        return true;
    }
}
