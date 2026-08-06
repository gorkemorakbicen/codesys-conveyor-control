(*
===============================================================================
FB_JamDetector
===============================================================================
*)

(*
===============================================================================
DECLARATION
===============================================================================
*)


FUNCTION_BLOCK FB_JamDetector
VAR_INPUT
    xEnable       : BOOL;
	xResetJam     : BOOL;
    xEntrySensor  : BOOL;
    xExitSensor   : BOOL;
    tTimeout      : TIME := T#10S;
END_VAR

VAR_OUTPUT
    xJamDetected      : BOOL;
    xProductInTransit : BOOL;
END_VAR

VAR
    fbEntryTrig : R_TRIG;
    fbExitTrig  : R_TRIG;
    tonJam      : TON;
END_VAR


(*
===============================================================================
IMPLEMENTATION
===============================================================================
*)


// Rising edge detection for sensors
fbEntryTrig(CLK := xEntrySensor);
fbExitTrig(CLK := xExitSensor);

// Sensor events are processed only while
// conveyor operation is confirmed.
IF xEnable THEN
	
    // Product entered the conveyor
    IF fbEntryTrig.Q AND NOT xProductInTransit THEN
        xProductInTransit := TRUE;
    END_IF;

    // Product reached the exit sensor
    IF fbExitTrig.Q AND xProductInTransit THEN
        xProductInTransit := FALSE;
    END_IF;
	
END_IF;

// Clear only the latched jam fault.
// Product tracking remains unchanged.
IF xResetJam THEN
    xJamDetected := FALSE;
END_IF;


// Jam supervision timer
tonJam(
    IN := xEnable AND xProductInTransit AND NOT xResetJam AND NOT xJamDetected,
    PT := tTimeout
);


// Timeout reached -> jam detected
IF tonJam.Q THEN
    xJamDetected := TRUE;
END_IF;

