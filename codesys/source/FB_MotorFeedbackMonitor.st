(*
===============================================================================
FB_MotorFeedbackMonitor
===============================================================================
*)

(*
===============================================================================
DECLARATION
===============================================================================
*)


FUNCTION_BLOCK FB_MotorFeedbackMonitor
VAR_INPUT
    xMotorCommand  : BOOL;
    xMotorFeedback : BOOL;
    tTimeout       : TIME;
END_VAR
VAR_OUTPUT
	xError : BOOL;
END_VAR
VAR
	tonFeedback : TON;
END_VAR


(*
===============================================================================
IMPLEMENTATION
===============================================================================
*)


// Timer runs only when monitoring is enabled,
// motor command is active,
// but motor feedback is still missing.
tonFeedback(
    IN := xMotorCommand AND NOT xMotorFeedback,
    PT := tTimeout
);

// Error becomes TRUE when timeout is reached.
xError := tonFeedback.Q;

