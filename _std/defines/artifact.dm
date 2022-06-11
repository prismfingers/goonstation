// Artifact stimuli. Add a define here if you create a new one.
#define ARTIFACT_SIMULUS_ELECTRICAL "electric"
#define ARTIFACT_STIMULUS_RADIOACTIVE "radioactive"
#define ARTIFACT_STIMULUS_FORCE "force"
#define ARTIFACT_STIMULUS_TEMPERATURE "temperature"
#define ARTIFACT_STIMULUS_SILICON_TOUCH "silitouch"
#define ARTIFACT_STIMULUS_CARBON_TOUCH "carbtouch"
#define ARTIFACT_STIMULUS_DATA "data"

// Stimulus requirement types
#define ARTIFACT_STIMULUS_AMOUNT_GEQ "greater than or equal to"
#define ARTIFACT_STIMULUS_AMOUNT_EXACT "equal to"
#define ARTIFACT_STIMULUS_AMOUNT_LEQ "less than or equal to"

// Results returned from artifact_fault_used
#define FAULT_RESULT_SUCCESS (0 << 1) //! everything's cool!
#define FAULT_RESULT_STOP	(1 << 1)  //! we gotta stop, artifact was destroyed or deactivated
#define FAULT_RESULT_INVALID (1 << 2) //! artifact can't do faults

// Returns for sending the activate/deactivate signal
/// Attempted to activate artifact, artifact was already activated
#define ARTIFACT_ALREADY_ACTIVATED  (0 << 1)
/// Attempted to activate artifact, artifact was activated successfully
#define ARTIFACT_NOW_ACTIVATED 		(1 << 1)
/// Artifact is unable to be activated at all
#define ARTIFACT_CANNOT_ACTIVATE	(2 << 1)

/// Attempted to activate artifact, artifact was already deactivated
#define ARTIFACT_ALREADY_DEACTIVATED (0 << 1)
/// Attempted to activate artifact, artifact was activated successfully
#define ARTIFACT_NOW_DEACTIVATED	 (1 << 1)
