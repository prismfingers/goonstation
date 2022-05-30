TYPEINFO(/datum/component/artifact)
	initialization_args = list(
		ARG_INFO("artifact_type", DATA_INPUT_TYPE, "What type of artifact should this component correspond to", /datum/artifact)
		ARG_INFO("scramble_appearance", DAATA_INPUT_BOOL, "Should we scramble this thing's name, appearance, and desc (like normal)?", null)
	)

/datum/component/artifact
	dupe_mode = COMPONENT_DUPE_UNIQUE // change this to allowed if we want to do multi-artifacts for. whatever goddamn reason
	/// atom typed version of parent
	var/atom/movable/artifact_atom
	/// Actual artifact datum
	var/datum/artifact/artifact


/datum/component/artifact/Initialize(var/artifact_type, var/scramble_appearance)
	if (!istype(parent, /atom/movable)) // No turf artifacts fuck you
		return COMPONENT_INCOMPATIBLE
	if (!ispath(artifact_type))
		stack_trace("/datum/component/artifact initialized with non-type thing as an artifact type: \[[artifact_type]\] (\ref[artifact_type])")

	src.artifact_atom = src.parent
	src.artifact = new artifact_type()

	// Setup actual origin
	var/datum/artifact_origin/real_origin = artifact_controls.get_origin_from_string(pick(A.validtypes))
	src.artifact.artitype = real_origin

	RegisterSignal(src.artifact_atom, COMSIG_PARENT_PRE_DISPOSING, .proc/artifact_destroyed)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_BLOB_ACT, .proc/artifact_blob_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_EX_ACT, .proc/artifact_ex_act)


	if (scramble_appearance)
		// Make this appear like an artifact

		// Origin we appear as- small chance to be different from the actual origin
		var/datum/artifact_origin/appearance_origin = artifact_controls.get_origin_from_string(AO.name)
		if (prob(real_origin.scramblechance))
			appearance_origin = null

		// If we nulled the appearance, pick a random one
		if (!istype(appearance_origin, /datum/artifact_origin/))
			var/list/all_origin_names = list()
			for (var/datum/artifact_origin/O in artifact_controls.artifact_origins)
				all_origin_names += O.name
			appearance_origin = artifact_controls.get_origin_from_string(pick(all_origin_names))

		var/name1 = pick(appearance_origin.adjectives)
		var/name2 = "thingy"
		if (isitem(src.parent))
			name2 = pick(appearance_origin.nouns_small)
		else
			name2 = pick(appearance_origin.nouns_large)

		src.artifact_atom.name = "[name1] [name2]"
		src.artifact_atom.real_name = "[name1] [name2]"
		src.artifact_atom.desc = "You have no idea what this thing is!"
		artifact.touch_descriptors |= real_origin.touch_descriptors

		src.icon_state = appearance_origin.name + "-[rand(1, appearance_origin.max_sprites)]"
		if (isitem(src))
			var/obj/item/I = src.artifact_atom
			I.item_state = appearance_origin.name

		src.artifact.fx_image = image(src.artifact_atom.icon, src.artifact_atom.icon_state + "fx")
		src.artifact.fx_image.color = rgb(rand(real_origin.fx_red_min, real_origin.fx_red_max), \
										  rand(real_origin.fx_green_min, real_origin.fx_green_max), \
										  rand(real_origin.fx_blue_min, real_origin.fx_blue_max))

		src.artifact.react_mpct[1] = real_origin.impact_reaction_one
		src.artifact.react_mpct[2] = real_origin.impact_reaction_two
		src.artifact.react_heat[1] = real_origin.heat_reaction_one
		src.artifact.activ_sound = pick(real_origin.activation_sounds)
		src.artifact.fault_types |= real_origin.fault_types - A.fault_blacklist
		src.artifact.internal_name = real_origin.generate_name()
		src.artifact.used_names[real_origin.type_name] = A.internal_name
		src.artifact.nofx = real_origin.nofx

		src.maybe_develop_fault(10)

		if (src.artifact.automatic_activation)
			src.artifact_activated()

		var/list/valid_triggers = A.validtriggers
		var/trigger_amount = rand(A.min_triggers,A.max_triggers)
		var/selection = null
		while (trigger_amount > 0)
			trigger_amount--
			selection = pick(valid_triggers)
			if (ispath(selection))
				var/datum/artifact_trigger/AT = new selection
				A.triggers += AT
				valid_triggers -= selection


		artifact_controls.artifacts += src

/datum/component/artifact/UnregisterFromParent()
	artifact_controls.artifacts -= src


/datum/component/artifact/proc/maybe_develop_fault(var/faultprob)
	// This proc is used for randomly giving an artifact a fault. It's usually used in the New() proc of an artifact so that
	// newly spawned artifacts have a chance of being faulty by default, though this can also be called whenever an artifact is
	// damaged or otherwise poorly handled, so you could potentially turn a good artifact into a dangerous piece of shit if you
	// abuse it too much.

	if (src.artifact.artitype.name == "eldritch")
		faultprob *= 2 // eldritch artifacts fucking hate you and are twice as likely to go faulty
	faultprob = clamp(faultprob, 0, 100)

	if (prob(faultprob) && length(src.artifact.fault_types))
		var/new_fault = weighted_pick(arc.artifact.fault_types)
		if (ispath(new_fault))
			var/datum/artifact_fault/F = new new_fault(A)
			F.holder = src.artifact
			src.artifact.faults += F
		else
			stack_trace("Didn't get a path from fault_types. Got \[[new_fault]\] instead.")

/// Called before the parent atom is deleted.
/datum/component/artifact/proc/artifact_destroyed()
	var/turf/T = get_turf(src)
	if (istype(T, /turf/))
		T.visible_message("<span class='alert><b>[src] [src.artifact.artitype.destruction_message]</b></span>")

	src.remove_artifact_forms()
	src.artifact_deactivated()

	//ArtifactLogs(usr, null, src, "destroyed", null, 0)

	artifact_controls.artifacts -= src.artifact_atom

/// Called when this artifact is activated
/datum/component/artifact/artifact_activated()
	if (src.artifact.activated)
		return TRUE
	if (src.artifact.triggers.len < 1 && !A.automatic_activation)
		return TRUE // can't activate these ones at all by design
	if (!src.artifact.may_activate(src.artifact_atom))
		return TRUE
	if (src.artifact.activ_sound)
		playsound(src.loc, src.artifact.activ_sound, 100, 1)
	if (src.artifact.activ_text)
		var/turf/T = get_turf(src.artifact_atom)
		if (T)
			T.visible_message("<b>[src.artifact_atom] [src.artifact.activ_text]</b>") //ZeWaka: Fix for null.visible_message()
	src.artifact.activated = TRUE
	if (src.artifact.nofx)
		src.artifact_atom.icon_state = src.artifact_atom.icon_state + "fx"
	else
		src.UpdateOverlays(src.artifact.fx_image, "activated")
	src.artifact.effect_activate(src)

/datum/component/artifact/proc/artifact_take_damage(var/dmg_amount)
	src.artifact_atom.health -= dmg_amount
	src.artifact_atom.health = clamp(artifact_atom.health, 0, 100)

	if (src.artifact_atom.health <= 0)
		qdel(src.artifact_atom)

/datum/component/artifact/proc/artifact_activated()

/datum/component/artifact/proc/artifact_blob_act(var/power)
	src.artifact_stimulus("force", power)
	src.artifact_stimulus("carbtouch", 1)

/datum/component/artifact/proc/artifact_ex_act(var/severity)
	switch(severity)
		if(1.0)
			src.artifact_stimulus("force", 200)
			src.artifact_stimulus("heat", 500)
		if(2.0)
			src.artifact_stimulus("force", 75)
			src.artifact_stimulus("heat", 450)
		if(3.0)
			src.artifact_stimulus("force", 25)
			src.artifact_stimulus("heat", 380)

/datum/component/artifact/proc/artifact_emp_act()
	src.artifact_stimulus("elec", 800)
	src.artifact_stimulus("radiate", 3)

/datum/component/artifact/proc/artifact_reagent_act(var/reagent_id, var/volume)
	switch(reagent_id)
		if("porktonium")
			src.artifact_stimulus("radiate", round(volume / 10))
			src.artifact_stimulus("carbtouch", round(volume / 5))
		if("synthflesh","blood","bloodc","meat_slurry") //not carbon, because it's about detecting *lifeforms*, not elements
			src.artifact_stimulus("carbtouch", round(volume / 5)) //require at least 5 units
		if("nanites","corruptnanites","goodnanites","flockdrone_fluid") //not silicon&friends for the same reason
			src.artifact_stimulus("silitouch", round(volume / 5)) //require at least 5 units
		if("radium")
			src.artifact_stimulus("radiate", round(volume / 10))
		if("uranium","polonium")
			src.artifact_stimulus("radiate", round(volume / 2))
		if("dna_mutagen","mutagen","omega_mutagen")
			if (A.artitype.name == "martian")
				ArtifactDevelopFault(80)
		if("phlogiston","el_diablo","thermite","thalmerite","argine")
			src.artifact_stimulus("heat", 310 + (volume * 5))
		if("napalm_goo","kerosene","ghostchilijuice")
			src.artifact_stimulus("heat", 310 + (volume * 10))
		if("infernite","foof","dbreath")
			src.artifact_stimulus("heat", 310 + (volume * 15))
		if("cryostylane")
			src.artifact_stimulus("heat", 310 - (volume * 10))
		if("freeze")
			src.artifact_stimulus("heat", 310 - (volume * 15))
		if("voltagen","energydrink")
			src.artifact_stimulus("elec", volume * 50)
		if("acid","acetic_acid")
			src.ArtifactTakeDamage(volume * 2)
		if("pacid","clacid","nitric_acid")
			src.ArtifactTakeDamage(volume * 10)
		if("george_melonium")
			var/random_stimulus = pick("heat","force","radiate","elec", "carbtouch", "silitouch")
			var/random_strength = 0
			switch(random_stimulus)
				if ("heat")
					random_strength = rand(200,400)
				if ("elec")
					random_strength = rand(5,5000)
				if ("force")
					random_strength = rand(3,30)
				if ("radiate")
					random_strength = rand(1,10)
				else // carbon and silicon touch
					random_strength = 1
			src.artifact_stimulus(random_stimulus, random_strength)


/datum/component/artifact/proc/artifact_stimulus()


