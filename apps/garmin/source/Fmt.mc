// Fmt — tiny formatting helpers shared by the views. Static-style (stateless)
// so there is nothing to allocate per frame.
module Fmt {

    // milliseconds -> "m:ss"
    function durMs(ms) {
        var total = (ms / 1000).toNumber();
        var m = total / 60;
        var s = total % 60;
        return m.toString() + ":" + (s < 10 ? "0" + s.toString() : s.toString());
    }

    // seconds -> "m:ss"
    function durSec(sec) {
        return durMs(sec * 1000);
    }

    // metres -> "123 m" (drops the decimal unless the pool is fractional)
    function dist(meters) {
        if (meters == null) { return "0 m"; }
        var whole = meters.toNumber();
        if ((meters - whole) == 0) {
            return whole.toString() + " m";
        }
        return meters.format("%.1f") + " m";
    }

    // pace seconds-per-100m -> "m:ss/100" or "--" when unknown
    function pace(secPer100) {
        if (secPer100 == null) { return "--"; }
        return durSec(secPer100.toNumber());
    }
}
