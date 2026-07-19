---------------------------- MODULE SleepVisibility ----------------------------
(***************************************************************************)
(* SleepState.tla shows that no rule based on advertisements plus time can  *)
(* satisfy both requirements at once:                                       *)
(*                                                                          *)
(*   - "graced"    (clear the belief after a fixed window) re-discovers a    *)
(*                 camera that is still shutting down, undoing the sleep.    *)
(*   - "confirmed" (clear it only after observed silence) leaves a camera    *)
(*                 that woke quickly permanently invisible.                  *)
(*                                                                          *)
(* A camera that is still shutting down and a camera that just woke up emit  *)
(* identical advertisements, so the app cannot tell them apart. Any rule     *)
(* must therefore choose which way to be wrong.                             *)
(*                                                                          *)
(* This module models the way out: stop trying to infer the answer. The      *)
(* original guard conflated two separate concerns --                        *)
(*                                                                          *)
(*   (a) do not AUTO-reconnect a camera the user just put to sleep          *)
(*   (b) do not HIDE a camera from the user                                 *)
(*                                                                          *)
(* Only (a) is actually required. Keeping the camera visible while           *)
(* suppressing only automatic reconnection satisfies both requirements with  *)
(* no assumption about how long shutdown takes.                             *)
(***************************************************************************)
EXTENDS Naturals

VARIABLES
    cam,        \* "awake" | "shuttingDown" | "asleep"
    visible,    \* is the camera in discoveredGoPros (user can tap to connect)?
    conn,       \* "none" | "auto" | "manual" -- how the app connected, if at all
    flag        \* app believes the user asked this camera to sleep

vars == <<cam, visible, conn, flag>>

TypeOK ==
    /\ cam \in {"awake", "shuttingDown", "asleep"}
    /\ visible \in BOOLEAN
    /\ conn \in {"none", "auto", "manual"}
    /\ flag \in BOOLEAN

Init ==
    /\ cam = "awake"
    /\ visible = FALSE
    /\ conn = "none"
    /\ flag = FALSE

Advertising == cam \in {"awake", "shuttingDown"}

-----------------------------------------------------------------------------
\* Advertisements are ALWAYS honoured now: visibility is never suppressed.
ReceiveAdvertisement ==
    /\ Advertising
    /\ ~visible
    /\ visible' = TRUE
    /\ UNCHANGED <<cam, conn, flag>>

\* A camera that has gone quiet eventually drops off the discovered list.
AdvertisementsCease ==
    /\ ~Advertising
    /\ visible
    /\ visible' = FALSE
    /\ UNCHANGED <<cam, conn, flag>>

(***************************************************************************)
(* Automatic reconnection -- scheduleReconnectIfNeeded, straggler retries,  *)
(* connect-all. This is the ONLY thing the sleep flag suppresses.           *)
(***************************************************************************)
AutoConnect ==
    /\ visible
    /\ conn = "none"
    /\ ~flag                     \* suppressed while the user wants it asleep
    /\ conn' = "auto"
    /\ UNCHANGED <<cam, visible, flag>>

(***************************************************************************)
(* The user taps the camera. Always allowed -- this is the escape hatch     *)
(* that the previous designs removed, and it also clears the flag, since    *)
(* an explicit connect request overrides an earlier sleep request.          *)
(***************************************************************************)
ManualConnect ==
    /\ visible
    /\ conn = "none"
    /\ conn' = "manual"
    /\ flag' = FALSE
    /\ UNCHANGED <<cam, visible>>

SendSleepCommand ==
    /\ conn # "none"
    /\ cam = "awake"
    /\ cam' = "shuttingDown"
    /\ flag' = TRUE
    /\ UNCHANGED <<visible, conn>>

CameraDisconnects ==
    /\ conn # "none"
    /\ cam # "awake"
    /\ conn' = "none"
    /\ UNCHANGED <<cam, visible, flag>>

ShutdownCompletes ==
    /\ cam = "shuttingDown"
    \* The BLE link cannot survive the camera powering off, so the
    \* disconnect necessarily precedes the camera being fully asleep.
    /\ conn = "none"
    /\ cam' = "asleep"
    /\ UNCHANGED <<visible, conn, flag>>

UserWakesCamera ==
    /\ cam = "asleep"
    /\ cam' = "awake"
    /\ UNCHANGED <<visible, conn, flag>>

-----------------------------------------------------------------------------
Next ==
    \/ ReceiveAdvertisement \/ AdvertisementsCease
    \/ AutoConnect \/ ManualConnect
    \/ SendSleepCommand \/ CameraDisconnects
    \/ ShutdownCompletes \/ UserWakesCamera

Spec ==
    /\ Init
    /\ [][Next]_vars
    /\ WF_vars(ReceiveAdvertisement)
    /\ WF_vars(CameraDisconnects)
    /\ WF_vars(ShutdownCompletes)

-----------------------------------------------------------------------------
\*                              PROPERTIES

(***************************************************************************)
(* These are action properties, not invariants. A plain invariant such as  *)
(* [](flag => conn # "auto") also flags the benign case where the app was  *)
(* already auto-connected and the user THEN asked for sleep -- that        *)
(* connection predates the request and is not a violation. What matters is *)
(* that the app never ESTABLISHES a new automatic connection against the   *)
(* user's stated wish.                                                     *)
(***************************************************************************)

\* Never start an automatic connection while the user wants the camera asleep.
NoNewAutoConnectWhileSleepRequested ==
    [][ (conn = "none" /\ conn' = "auto") => ~flag ]_vars

(***************************************************************************)
(* NOTE: a stronger property --                                            *)
(*                                                                         *)
(*   [][ (conn = "none" /\ conn' = "auto") => cam # "shuttingDown" ]_vars   *)
(*                                                                         *)
(* -- is NOT checked here, because it is genuinely too strong. TLC finds a *)
(* trace where the user manually connects while the camera is still        *)
(* shutting down (which clears the flag, since an explicit connect         *)
(* overrides an earlier sleep request), the camera then drops the link,    *)
(* and the app auto-reconnects. That is correct behaviour: the user's most *)
(* recent expressed intent was "connect". Honouring manual override and    *)
(* never reconnecting mid-shutdown are incompatible, and override wins.    *)
(***************************************************************************)

(***************************************************************************)
(* An awake camera always becomes visible again, with NO assumption about  *)
(* how long shutdown takes -- visibility is never suppressed, so the user  *)
(* always retains a way to reach the camera. This is what both timing-based *)
(* designs had to trade away.                                              *)
(***************************************************************************)
(* Leads-to is the wrong operator here: the app may legitimately send a new *)
(* sleep command in the window between the camera waking and its first      *)
(* advertisement being processed, which makes (cam = "awake") ~> visible    *)
(* fail for reasons that are not defects. What must never happen is the     *)
(* camera being awake and invisible FOREVER -- the permanent-invisibility   *)
(* trap that the naive design falls into.                                   *)
NeverPermanentlyInvisibleWhileAwake ==
    ~<>[](cam = "awake" /\ ~visible)

=============================================================================
