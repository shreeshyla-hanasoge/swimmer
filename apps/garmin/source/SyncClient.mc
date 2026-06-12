using Toybox.Communications;
using Toybox.System;

// SyncClient — the SINGLE module behind which all networking lives (design-
// rationale section 7). Today it is a STUB: it builds the exact payload defined
// in server/README.md but does not transmit, so wiring the AWS backend later is
// a two-method change (fetchTodayPlan / postSession) and nothing else in the app
// is touched.
//
// Kept lean: builds the payload dictionary on demand, no retained buffers.
class SyncClient {

    // VERIFY before going live: real base URL + bearer token plumbing.
    private const BASE_URL = "https://api.swimcoach.example/v1";

    // Build the end-of-session payload (server/README.md POST /v1/sessions).
    // 'summary' is the dictionary assembled by SessionController.
    function buildSessionPayload(summary) {
        return {
            "version"             => 1,
            "clientSessionId"     => summary[:clientSessionId],
            "mode"                => summary[:mode],
            "poolLengthMeters"    => summary[:poolLengthMeters],
            "totalDistanceMeters" => summary[:totalDistanceMeters],
            "lapCount"            => summary[:lapCount],
            "movingTimeSec"       => summary[:movingTimeSec],
            "splits"              => summary[:splits],
            "breathingSets"       => summary[:breathingSets],
            "hrRecovery"          => summary[:hrRecovery]
        };
    }

    // STUB: would POST the payload once at end of session. Best-effort; never
    // blocks the workout (the watch keeps the data and may retry by
    // clientSessionId — see the idempotency note in server/README.md).
    function postSession(summary) {
        var payload = buildSessionPayload(summary);
        // ---- FUTURE (do not enable until backend exists) -------------------
        // if (Communications has :makeWebRequest) {
        //     Communications.makeWebRequest(
        //         BASE_URL + "/sessions", payload,
        //         { :method => Communications.HTTP_REQUEST_METHOD_POST,
        //           :headers => { "Content-Type" =>
        //               Communications.REQUEST_CONTENT_TYPE_JSON } },
        //         method(:onPost));
        // }
        // --------------------------------------------------------------------
        System.println("SyncClient(stub): would POST session " + payload["clientSessionId"]);
        return payload;   // returned so the UI/tests can inspect what would ship
    }

    // STUB: would GET /v1/plan/today and hand the plan back. Offline-first: the
    // app runs correctly when this returns null.
    function fetchTodayPlan() {
        // ---- FUTURE: Communications.makeWebRequest GET BASE_URL + "/plan/today"
        return null;
    }

    // function onPost(responseCode, data) { ... }  // FUTURE
}
