/obj/item/artifact/activator_key
	// can activate any artifact simply by smacking it. very very rare
	name = "artifact activator key"
	associated_datum = /datum/artifact/activator_key

/datum/artifact/activator_key
	associated_object = /obj/item/artifact/activator_key
	type_name = "Activator Key"
	type_size = ARTIFACT_SIZE_MEDIUM
	rarity_weight = 200
	validtypes = list("ancient","martian","wizard","eldritch","precursor")
	automatic_activation = 1
	react_xray = list(12,80,95,8,"COMPLEX")
	examine_hint = "It kinda looks like it's supposed to be inserted into something."
	var/universal = FALSE //! Normally it only activates its own type, but sometimes it can do all
	var/corrupting = FALSE //! Generates faults in activated artifacts

	post_setup()
		. = ..()
		if (prob(33))
			src.universal = TRUE
		if (src.artitype.name == "eldritch")
			src.corrupting = TRUE

	effect_afterattack(mob/living/user, atom/A)
		if (..()) // range check
			return

		/*
		*	Yes, this is awful. But the previous implementation (basically handling activator key behavior in the attackby() of artifacts.
		*	with the proc defined on /obj.) was even more awful and this is already a large refactor so I'm going with a way that Works, and I'll find
		*   a Good Way That Works later.
		*	No but seriously though these used to be dummy objects basically. Artifacts just typechecked and then activated when slapped with one.
		*/
		var/list/artifact_comps = A.GetComponents(/datum/component/artifact)
		for (var/datum/component/artifact/comp in artifact_comps)
			if (comp.artifact.artitype.name == src.artitype.name || src.universal)
				if (comp.artifact.activated)
					comp.artifact_deactivated()
				else
					comp.artifact_activated()

			if(src.corrupting && length(comp.artifact.faults) < 10) // there's only so much corrupting you can do ok
				for(var/i = 1, i < rand(1, 3), i++)
					SEND_SIGNAL(A, COMSIG_ARTIFACT_DEVELOP_FAULT, 100)
