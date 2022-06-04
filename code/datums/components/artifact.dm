TYPEINFO(/datum/component/artifact)
	initialization_args = list(
		ARG_INFO("artifact_type", DATA_INPUT_TYPE, "What type of artifact should this component correspond to", /datum/artifact)
		ARG_INFO("scramble_appearance", DATA_INPUT_BOOL, "Should we scramble this thing's name, appearance, and desc (like normal)?", null)
	)

/datum/component/artifact
	dupe_mode = ALLOWED // I'm adding multi artifacts and nobody can stop me
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

	// Signal stuff
	RegisterSignal(src.artifact_atom, COMSIG_ATTACKBY, .proc/artifact_attackby)
	RegisterSignal(src.artifact_atom, COMSIG_PARENT_PRE_DISPOSING, .proc/artifact_destroyed)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_BLOB_ACT, .proc/artifact_blob_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_EX_ACT, .proc/artifact_ex_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_BLOB_ACT, .proc/artifact_blob_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_REAGENT_ACT, .proc/artifact_reagent_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_METEORHIT, .proc/artifact_meteorhit)


	// Make this appear like an artifact
	if (scramble_appearance)

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

		// Artifact-ize name
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

		//Artifact-ize sprite
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

		// Low chance to start with a fault
		src.maybe_develop_fault(10)

		// Activate automatically if we do that
		if (src.artifact.automatic_activation)
			src.artifact_activated()

		// Generate activation triggers
		if (!src.artifact.automatic_activation)
			var/list/valid_triggers = A.validtriggers
			var/trigger_amount = rand(A.min_triggers,A.max_triggers)
			var/selection = null
			while (trigger_amount > 0)
				trigger_amount--
				selection = pick(valid_triggers)
				if (ispath(selection))
					var/datum/artifact_trigger/trigger = new selection
					A.triggers += trigger
					valid_triggers -= selection


		// Finally, add to artifact controller so we can track it
		artifact_controls.artifacts += src

/datum/component/artifact/UnregisterFromParent()
	artifact_controls.artifacts -= src

/**
 * Proc called to possibly give an artifact a fault, depending on probability. Called in New() with a low probability, and also whenever you
 * damage an artifact too much.
 */
/datum/component/artifact/proc/maybe_develop_fault(var/faultprob)

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

/datum/component/artifact/proc/take_damage(var/damage)
	src.artifact.health -= damage
	src.artifact.health = min(A.health, 100)

	if (src.artifact.health <= 0)
		qdel(src.artifact_atom)

/// Called before the parent atom is deleted
/datum/component/artifact/proc/artifact_destroyed()
	var/turf/T = get_turf(src)
	if (istype(T, /turf/))
		T.visible_message("<span class='alert><b>[src] [src.artifact.artitype.destruction_message]</b></span>")

	src.remove_artifact_forms()
	src.artifact_deactivated()

	artifact_controls.artifacts -= src.artifact_atom

// This is for a tool/item artifact that you can use. If it has a fault, whoever is using it is basically rolling the dice
// every time the thing is used (a check to see if rand(1,faultcount) hits 1 most of the time) and if they're unlucky, the
// thing will deliver it's payload onto them.
// There's also no reason this can't be used whoever the artifact is being used *ON*, also!
// The cosmetic source is just to specify where the effect comes from in the visual message.
// So that you can make it come from something like a forcefield or bullet instead of the artifact itself!
/**
 * Activate an artifact fault, triggered ON the user. Handheld artifacts can activate a fault on the user or the target of something.
 * cosmeticSource is for messages; set it to something artifact adjacent to make the effect come from a forcefield, bullet, etc instead.
 */
/datum/component/artifact/proc/artifact_fault_used(mob/user, atom/cosmeticSource)

	if (!length(src.artifact.faults))
		return FAULT_RESULT_INVALID // no faults, so dont waste any more time
	if (!cosmeticSource)
		cosmeticSource = src
	var/halt = FALSE
	for (var/datum/artifact_fault/F in src.artifact.faults)
		if (prob(F.trigger_prob))
			if (F.halt_loop)
				halt = TRUE
			F.deploy(src, user, cosmeticSource)
		if (halt)
			return FAULT_RESULT_STOP
	return FAULT_RESULT_SUCCESS

/// Called when this artifact is activated
/datum/component/artifact/proc/artifact_activated()
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
			T.visible_message("<b>[src.artifact_atom] [src.artifact.activ_text]</b>")
	src.artifact.activated = TRUE
	if (src.artifact.nofx)
		src.artifact_atom.icon_state = src.artifact_atom.icon_state + "fx"
	else
		src.UpdateOverlays(src.artifact.fx_image, "activated")
	src.artifact.effect_activate(src.artifact_atom)

/// Called when this artifact is deactivated, whether automatically or through an activator key
/datum/component/artifact/proc/artifact_deactivated()
	if (!src.artifact.activated) // do not deactivate if already deactivated
		return
	if (A.deact_sound)
		playsound(src.artifact_atom.loc, A.deact_sound, 100, 1)
	if (A.deact_text)
		var/turf/T = get_turf(src.artifact_atom)
		T.visible_message("<b>[src] [src.artifact.deact_text]</b>")
	src.artifact.activated = FALSE
	if (src.artifact.nofx)
		src.artifact_atom.icon_state = src.artifact_atom.icon_state - "fx"
	else
		src.artifact_atom.UpdateOverlays(null, "activated")
	src.artifact.effect_deactivate(src.artifact_atom)


/// Called when someone pokes this artifact
/datum/component/artifact/proc/artifact_touched(mob/user)
	if (!in_interact_range(get_turf(src.artifact_atom), user))
		return
	if (isAI(user))
		return
	if (isobserver(user))
		return

	if (ishuman(user))
		var/mob/living/carbon/human/H = user
		var/obj/item/parts/arm = H.hand ? H.limbs.l_arm : H.limbs.r_arm
		if(istype(arm, /obj/item/parts/robot_parts))
			src.artifact_stimulus("silitouch", 1)
		else
			src.artifact_stimulus("carbtouch", 1)
	else if (iscarbon(user))
		src.artifact_stimulus("carbtouch", 1)
	else if (issilicon(user))
		src.artifact_stimulus("silitouch", 1)
	src.artifact_stimulus("force", 1)
	user.visible_message("<b>[user.name]</b> touches \the [src.artifact_atom].")
	if (istype(src.artifact, /datum/artifact))
		if (length(src.artifact.touch_descriptors))
			boutput(user, "[pick(src.artifact.touch_descriptors)]")
		else
			boutput(user, "You can't really tell how it feels.")
	if (src.artifact.activated)
		src.artifact.effect_touch(src, user)

/// Called when someone hits this with an item
/datum/component/artifact/proc/artifact_attackby(var/artifact_atom, var/obj/item/I, var/mob/attacker)

	. = FALSE

	if (isrobot(user))
		src.artifact_stimulus("silitouch", 1)

	//// ---- BEGIN SHIT I AM NOT FIXING RN ----
	if (istype(W,/obj/item/artifact/activator_key))
		var/obj/item/artifact/activator_key/ACT = W
		if (!src.ArtifactSanityCheck())
			return
		if (!W.ArtifactSanityCheck())
			return
		var/datum/artifact/A = src.artifact
		var/datum/artifact/activator_key/K = ACT.artifact

		if (K.activated)
			if (K.universal || A.artitype == K.artitype)
				if (K.activator && !A.activated)
					src.ArtifactActivated()
					if(K.corrupting && A.faults.len < 10) // there's only so much corrupting you can do ok
						for(var/i=1,i<rand(1,3),i++)
							src.ArtifactDevelopFault(100)
				else if (A.activated)
					src.ArtifactDeactivated()
	//// ---- END SHIT ----

	if (isweldingtool(I))
		if (W:try_weld(user, 0, -1, 0, 1))
			src.artifact_stimulus("heat", 800)
			src.visible_message("<span class='alert'>[user.name] burns the artifact with [W]!</span>")
			return

	if (istype(I, /obj/item/device/light/zippo))
		var/obj/item/device/light/zippo/ZIP = W
		if (ZIP.on)
			src.artifact_stimulus("heat", 400)
			src.visible_message("<span class='alert'>[user.name] burns the artifact with [ZIP]!</span>")
			return

	if(istype(I, /obj/item/device/igniter))
		src.artifact_stimulus("elec", 700)
		src.artifact_stimulus("heat", 385)
		src.visible_message("<span class='alert'>[user.name] sparks against \the [src] with \the [igniter]!</span>")

	if (istype(i, /obj/item/robodefibrillator))
		var/obj/item/robodefibrillator/R = I
		if (R.do_the_shocky_thing(user))
			src.artifact_stimulus("elec", 2500)
			src.visible_message("<span class='alert'>[user.name] shocks \the [src] with \the [R]!</span>")
			return

	if(istype(I, /obj/item/baton))
		var/obj/item/baton/BAT = i
		if (BAT.can_stun(1, user))
			src.artifact_stimulus("force", BAT.force)
			src.artifact_stimulus("elec", 1500)
			playsound(src.loc, "sound/impact_sounds/Energy_Hit_3.ogg", 100, 1)
			src.visible_message("<span class='alert'>[user.name] zaps the artifact with [BAT]!</span>")
			BAT.process_charges(-1, user)
			return

	if(istype(I, /obj/item/device/flyswatter))
		src.artifact_stimulus("elec", 1500)
		src.visible_message("<span class='alert'>[user.name] shocks \the [src] with \the [swatter]!</span>")
		return

	if(ispulsingtool(W))
		src.artifact_stimulus("elec", 1000)
		src.visible_message("<span class='alert'>[user.name] shocks \the [src] with \the [W]!</span>")
		return

	if (istype(W,/obj/item/parts/robot_parts))
		var/obj/item/parts/robot_parts/THISPART = W
		src.visible_message("<b>[user.name]</b> presses \the [THISPART] against \the [src].</span>")
		src.artifact_stimulus("silitouch", 1)
		return

	if (istype(W, /obj/item/parts/human_parts))
		var/obj/item/parts/human_parts/THISPART = W
		src.visible_message("<b>[user.name]</b> smooshes \the [THISPART] against \the [src].</span>")
		src.artifact_stimulus("carbtouch", 1)
		return 0

	if (istype(W, /obj/item/grab))
		var/obj/item/grab/grabobj = W
		if (ismob(grabobj.affecting))
			if (grabobj.state < GRAB_STRONG)
				// Not a strong grip so just smoosh em into it
				// generally speaking only humans and the like can be grabbed so whatev
				if (istype(grabobj.affecting, /mob/living/carbon))
					src.visible_message("<b>[user]</b> gently presses [grabobj.affecting] against \the [src].")
					src.artifact_stimulus("carbtouch", 1)
				return

			var/mob/M = GRAB.affecting
			var/mob/A = GRAB.assailant
			if (BOUNDS_DIST(src.loc, M.loc) > 0)
				return
			src.visible_message("<strong class='combat'>[A] shoves [M] against \the [src]!</strong>")
			logTheThing("combat", A, M, "forces [constructTarget(M,"combat")] to touch \an ([src.type]) artifact at [log_loc(src)].")
			src.ArtifactTouched(M)
			return

	if (istype(W, /obj/item/circuitboard))
		var/obj/item/circuitboard/board = W
		src.visible_message("<b>[user.name]</b> offers the [board] to the artifact.</span>")
		src.artifact_stimulus("data", 1)
		return

	if (istype(W, /obj/item/disk/data))
		var/obj/item/disk/data/datadisk = W
		src.visible_message("<b>[user.name]</b> offers the [datadisk] to the artifact.</span>")
		src.artifact_stimulus("data", 1)
		return

	if (W.force)
		src.artifact_stimulus("force", W.force)

	// TODO refactor this shit into a usable state
	src.ArtifactHitWith(W, user)
	return TRUE


/// Called when a blob hits this artifact
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

/// Called when this artifact is hit by an EMP
/datum/component/artifact/proc/artifact_emp_act()
	src.artifact_stimulus("elec", 800)
	src.artifact_stimulus("radiate", 3)

/// Called when a meteor or other very heavy thing (high throwforce object, certain critters) impacts this artifact
/datum/component/artifact/proc/artifact_meteorhit()
	src.artifact_stimulus("force", 100)

/// Called when a reagent is applied to an artifact, such as via smoke or beaker splash.
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
			src.artifact_take_damage(volume * 2)
		if("pacid","clacid","nitric_acid")
			src.artifact_take_damage(volume * 10)
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

/**
 * Proc which handles artifacts recieving stimuli, and doing things with those stimuli (usually either breaking or activating).
 * stimtype: type of stimulus
 */
/datum/component/artifact/proc/artifact_stimulus(var/stimtype, var/strength)
	if (!stimtype || !strength)
		stack_trace("artifact_stimulus on component/artifact called without a specified [stimtype ? "strength" : "stimulus"]. Parent atom: \ref[src.parent]")
	var/turf/T = get_turf(src.artifact_atom)

	// Possible stimuli = force, elec, radiate, heat
	switch(src.artifact.artitype.name)
		if("martian") // biotech, so anything that'd probably kill a living thing works on them too
			if(stimtype == "force")
				if (strength >= 30)
					T.visible_message("<span class='alert'>[src] bruises from the impact!</span>")
					playsound(src.loc, "sound/impact_sounds/Slimy_Hit_3.ogg", 100, 1)
					ArtifactDevelopFault(33)
					src.artifact_take_damage(strength / 1.5)
			if(stimtype == "elec")
				if (strength >= 3000) // max you can get from the electrobox is 5000
					T.visible_message("<span class='alert'>[src] seems to quiver in pain!</span>")
					src.artifact_take_damage(strength / 1000)
			if(stimtype == "radiate")
				if (strength >= 6)
					artifact_develop_fault(strength * 10 - 20) // 40% at 6, 80% at 10
					src.artifact_take_damage(strength * 1.25)
		if("wizard") // these are big crystals, thus you probably shouldn't smack them around too hard!
			if(stimtype == "force")
				if (strength >= 20)
					T.visible_message("<span class='alert'>[src] cracks and splinters!</span>")
					playsound(src.loc, "sound/impact_sounds/Glass_Shards_Hit_1.ogg", 100, 1)
					ArtifactDevelopFault(80)
					src.artifact_take_damage(strength * 1.5)

	if (!src || !A)
		return

	if (!A.activated)
		for (var/datum/artifact_trigger/trigger in src.artifact.triggers)
			if (trigger.stimulus_required == stimtype)
				if (trigger.do_amount_check)
					if (trigger.stimulus_type == ARTIFACT_STIMULUS_AMOUNT_GEQ && strength >= trigger.stimulus_amount)
						src.ArtifactActivated()
					else if (trigger.stimulus_type == ARTIFACT_STIMULUS_AMOUNT_EXACT && strength <= trigger.stimulus_amount)
						src.ArtifactActivated()
					else if (trigger.stimulus_type == ARTIFACT_STIMULUS_AMOUNT_LEQ && strength == trigger.stimulus_amount)
						src.ArtifactActivated()
					else
						if (istext(A.hint_text))
							if (strength >= trigger.stimulus_amount - trigger.hint_range && strength <= trigger.stimulus_amount + trigger.hint_range)
								if (prob(trigger.hint_prob))
									T.visible_message("<b>[src]</b> [A.hint_text]")
				else
					src.ArtifactActivated()


/// Removes all artifact forms attached to this and makes them fall to the floor
/// Because artifacts often like to disappear in mysterious ways
/datum/component/artifact/proc/remove_artifact_forms()
	var/removed = 0
	for(var/obj/item/sticker/postit/artifact_paper/AP in src.artifact_atom.vis_contents)
		AP.remove_from_attached()
		removed++
	if(removed == 1)
		src.visible_message("The artifact form that was attached falls to the ground.")
	else if(removed > 1)
		src.visible_message("All the artifact forms that were attached fall to the ground.")
