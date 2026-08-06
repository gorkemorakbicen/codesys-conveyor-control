(*
===============================================================================
PLC_PRG
===============================================================================
*)

(*
===============================================================================
DECLARATION
===============================================================================
*)


PROGRAM PLC_PRG
VAR
    // Input and output structures
    stIn  : ST_ConveyorInputs;
    stOut : ST_ConveyorOutputs;

    // State and fault information
    eState : E_ConveyorState := E_ConveyorState.STOPPED;
    eFault : E_FaultCode := E_FaultCode.NO_FAULT;
	
	// Function block instances
    fbMotorFeedbackMonitor : FB_MotorFeedbackMonitor;
	fbJamDetector          : FB_JamDetector;

    // Temporary internal fault signals
    xMotorFeedbackError : BOOL;
    xJamDetected        : BOOL;
	xProductInTransit   : BOOL;
	
	xMotorCommandRequest : BOOL;

    // Rising edge detection for operator buttons
    fbStartTrig : R_TRIG;
    fbStopTrig  : R_TRIG;
    fbResetTrig : R_TRIG;

    xStartPulse : BOOL;
    xStopPulse  : BOOL;
    xResetPulse : BOOL;
	
	xJamFaultActive           : BOOL;
	xMotorFeedbackFaultActive : BOOL;
	xEmergencyStopFaultActive : BOOL;
END_VAR


(*
===============================================================================
IMPLEMENTATION
===============================================================================
*)


// ---------------------------------------------------------
// 1. Rising edge detection for buttons
// ---------------------------------------------------------

fbStartTrig(CLK := stIn.xStartButton);
fbStopTrig(CLK := stIn.xStopButton);
fbResetTrig(CLK := stIn.xResetButton);

xStartPulse := fbStartTrig.Q;
xStopPulse  := fbStopTrig.Q;
xResetPulse := fbResetTrig.Q;


// ---------------------------------------------------------
// 2. Global emergency stop check
// ---------------------------------------------------------

IF stIn.xEmergencyStop THEN
    eFault := E_FaultCode.EMERGENCY_STOP;
    eState := E_ConveyorState.FAULT;
END_IF;


// ---------------------------------------------------------
// 3. Motor command request
// ---------------------------------------------------------
// The motor is commanded during STARTING and RUNNING.

xMotorCommandRequest :=
    (
        (eState = E_ConveyorState.STARTING)
        OR
        (eState = E_ConveyorState.RUNNING)
    )
    AND NOT stIn.xEmergencyStop;


// ---------------------------------------------------------
// 4. Motor feedback supervision
// ---------------------------------------------------------
// The FB is called every scan.
// Feedback is expected only while a motor command exists.

fbMotorFeedbackMonitor(
    xMotorCommand  := xMotorCommandRequest,
    xMotorFeedback := stIn.xMotorFeedback,
    tTimeout       := T#5S
);

xMotorFeedbackError := fbMotorFeedbackMonitor.xError;


// ---------------------------------------------------------
// 5. Jam detection
// ---------------------------------------------------------
// Jam monitoring starts only after motor operation
// has been confirmed and the state is RUNNING.

fbJamDetector(
    xEnable :=
        (eState = E_ConveyorState.RUNNING)
        AND stIn.xMotorFeedback
        AND NOT xMotorFeedbackError,

    xResetJam :=
        xResetPulse
        AND (eState = E_ConveyorState.FAULT)
		AND NOT stIn.xEmergencyStop,

    xEntrySensor := stIn.xEntrySensor,
    xExitSensor  := stIn.xExitSensor,
    tTimeout     := T#10S
);

xJamDetected      := fbJamDetector.xJamDetected;
xProductInTransit := fbJamDetector.xProductInTransit;


// ---------------------------------------------------------
// 6. Main state transition logic
// ---------------------------------------------------------

CASE eState OF

    E_ConveyorState.STOPPED:

        IF xStartPulse AND NOT stIn.xEmergencyStop THEN
            eFault := E_FaultCode.NO_FAULT;
            eState := E_ConveyorState.STARTING;
        END_IF;


    E_ConveyorState.STARTING:

        // Stop allows the operator to cancel startup normally.
        IF xStopPulse THEN
            eFault := E_FaultCode.NO_FAULT;
            eState := E_ConveyorState.STOPPED;

        // Motor command was given, but feedback did not arrive.
        ELSIF xMotorFeedbackError THEN
            eFault := E_FaultCode.MOTOR_FEEDBACK_ERROR;
            eState := E_ConveyorState.FAULT;

        // Motor operation has been confirmed.
        ELSIF stIn.xMotorFeedback THEN
            eFault := E_FaultCode.NO_FAULT;
            eState := E_ConveyorState.RUNNING;
        END_IF;


    E_ConveyorState.RUNNING:

		IF xMotorFeedbackError THEN
			eFault := E_FaultCode.MOTOR_FEEDBACK_ERROR;
			eState := E_ConveyorState.FAULT;
	
		ELSIF xJamDetected THEN
			eFault := E_FaultCode.JAM_DETECTED;
			eState := E_ConveyorState.FAULT;
	
		ELSIF xStopPulse THEN
			eFault := E_FaultCode.NO_FAULT;
			eState := E_ConveyorState.STOPPED;
	
		// Motor command continues, but feedback is no longer confirmed.
		ELSIF NOT stIn.xMotorFeedback THEN
			eState := E_ConveyorState.STARTING;
		END_IF;


    E_ConveyorState.FAULT:

        IF xResetPulse AND NOT stIn.xEmergencyStop THEN
            eFault := E_FaultCode.NO_FAULT;
            eState := E_ConveyorState.STOPPED;
        END_IF;

END_CASE;


// ---------------------------------------------------------
// 7. Output assignment according to final state
// ---------------------------------------------------------

CASE eState OF

    E_ConveyorState.STOPPED:

        stOut.xMotorCommand := FALSE;
        stOut.xFaultLamp    := FALSE;
        stOut.xRunningLamp  := FALSE;


    E_ConveyorState.STARTING:

        // Motor command is active, but operation
        // has not yet been confirmed.
        stOut.xMotorCommand := TRUE;
        stOut.xFaultLamp    := FALSE;
        stOut.xRunningLamp  := FALSE;


    E_ConveyorState.RUNNING:

        // Motor feedback has been confirmed.
        stOut.xMotorCommand := TRUE;
        stOut.xFaultLamp    := FALSE;
        stOut.xRunningLamp  := stIn.xMotorFeedback;


    E_ConveyorState.FAULT:

        stOut.xMotorCommand := FALSE;
        stOut.xFaultLamp    := TRUE;
        stOut.xRunningLamp  := FALSE;
		
		ELSE
	
			// Safe outputs for an unexpected state value
			stOut.xMotorCommand := FALSE;
			stOut.xFaultLamp    := TRUE;
			stOut.xRunningLamp  := FALSE;

END_CASE;


// ---------------------------------------------------------
// 8. Latched fault indicators for visualization
// ---------------------------------------------------------

xJamFaultActive :=
    (eFault = E_FaultCode.JAM_DETECTED);

xMotorFeedbackFaultActive :=
    (eFault = E_FaultCode.MOTOR_FEEDBACK_ERROR);

xEmergencyStopFaultActive :=
    (eFault = E_FaultCode.EMERGENCY_STOP);

