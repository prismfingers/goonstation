/*//////////////////////////////////////////

----- OVERVIEW OF SYSTEM (IN THEORY, THERE'S A LOT TO IMPLEMENT) -----
Artifact objects (now atoms technically) are very dumb. In fact, many artifacts without a need for special handling can probably use the `/obj/artifact/` and
`/obj/item/artifact` types, with whatever datum added. They exist for people to interact with them, and to apply effects to the world. They
pass a bunch of signals over to the artifact component. They don't get to see artifact datums at all, ever.

Artifact datums are basically the same as before. They handle all the specific artifact behavior, origin stuff, etc.
They still get to know about the artifact object, as we first pick a datum, and then spawn whatever type that artifact wants.
We allow datums to specify the type of object they want to spawn because we don't want to end up with shit like a power cell datum with a non-power-cell
artifact. This also goes for admin-spawns- artifact datums should report a failure and delete themselves (and by extension, the component, but the compo-
nent will handle that) if the atom type is incompatible.

The artifact component acts as a middle-man between the atom and the datum. When signals are sent to the atom, the component grabs those and does
generic artifact processing like converting an explosion into a force stimulus and applying it to the datum. The component also handles setup of artifact
appearance, name, etc.- basically any generic artifact behavior is done here, leaving the specific types to the datum.

Because we're a component, all the things acting on artifacts now have to be sent via signals. This is a pain in the ass. For some (blob_act, meteorhit),
I used wrapper procs; for others (ex_act) which are often used in cases where the signal shouldn't be sent, I just added the signal send to the main place
where the signal should be applied (e.g. for ex_act, in the explosion processing code).
I'm not happy about all this, but I think it's a necessary evil.

Having a component makes the types way, way better for artifact objects, and we can straight up remove a bunch of them. However, there are some annoying cases-
a big one is activator keys, which were previously super simple (if (thing.artifact) thing.artifact.activate). Either need to make a special signal for them
or do some jank with return values.

It's all kind of like an evil MVC I suppose.

P.S.
This also involves a lot of general de-janking because the old artifact system was bad and also there's a lot of lingering oldcode which is passing
extraneous arguments, using `.len`, etc etc. Luckily we can mass-delete a lot of it, but some general refactoring will also have to be done outside of
the component conversion

--------------------MASTER TODO---------------------
[Copy pasted from an old notepad doc so some of this might be outdated]

artifact procs DONE
signal passthrough DONE
remove all obj-datum associations VARS REMOVED, OVERRIDES REMAIN FOR ORGANIZATION
make activator keys less shit DONE
make activator keys even less shit because my impl sucks
add effect_afterattack to artifacts DONE
figure out how to do examine hints DONE
implement defines DONE?
rework mob_flip_inside? DONE
remove dumb args from art datums
figure out a sane way to make sure effect_afterattack is consistently called (pixelaction signal?)
move all obj/artifact/machinery off those types

LATER
mass rename ArtifactStimulus etc
Artifact process so no machine loop shit
rework touch descriptors for this framework
remove all var-copying from appearance to artifact datum; just query appearance
add better logging
move ArtifactDestroyed calls to qdel()
make sure forms work
singleton arti origins
typeinfo arti origin lists
remove `src` arg from effect_activate
improve baton-artifact interaction
remove artifact arguments from effect_activate and effect_deactivate
retrofit spawn_artifact

FEATURES
Multi artifacts (?) [might leave this for later if it needs some extra consideration]
Mob artifact demo


GENERAL FLOW
1. Maintain obj artifact types mostly, but with less code duplication
2. Art datum types specify the atom type they want in New() when adding component (not a var)
3. Most behavior goes in component; objs are very lightweight


IMPACT PAD
Make stand-up pad set density of items to 1 (so you can shoot/hit them) I guess? hacky but eh

*//////////////////////////////////////////
TYPEINFO(/datum/component/artifact)
	initialization_args = list(
		ARG_INFO("artifact_type", DATA_INPUT_TYPE, "What type of artifact should this component correspond to", /datum/artifact),
		ARG_INFO("scramble_appearance", DATA_INPUT_BOOL, "Should we scramble this thing's name, appearance, and desc (like normal)?", TRUE),
		ARG_INFO("forceartiorigin", DATA_INPUT_TEXT, "Should we force this artifact to be a specific origin? Warning: will potentially create unusual artifacts if a type is also specified. Can also be a list.", null)
	)

/**
 * A component to interface between movable atoms which are "artifacts" and their actual artifact datums.
 * Individual artifact behaviors are handled in the artifact datum, but operations such as appearance setup, preocessing stimuli,
 * adding and activating faults, and activating and deactivating the artifact are all handled here.
 */
/datum/component/artifact
	dupe_mode = COMPONENT_DUPE_ALLOWED // I'm adding multi artifacts and nobody can stop me
	/// atom typed version of parent, traditionally /obj. The actual, on-map object which people interact with.
	var/atom/movable/artifact_atom
	/// Artifact datum, which handles all artifact behavior behind the scenes.
	var/datum/artifact/artifact


/datum/component/artifact/Initialize(var/artifact_type, var/scramble_appearance, var/forceartiorigin)

	if (!istype(parent, /atom/movable)) // No turf artifacts fuck you
		return COMPONENT_INCOMPATIBLE
	if (!ispath(artifact_type))
		stack_trace("/datum/component/artifact initialized with non-type thing as an artifact type: \[[artifact_type]\] (\ref[artifact_type])")

	src.artifact_atom = src.parent
	src.artifact = new artifact_type()
	src.artifact.holder = src.artifact_atom

	// Signal stuff
	// attack_x (people poking/hitting artifact)
	RegisterSignal(src.artifact_atom, COMSIG_ATTACKBY, .proc/artifact_attackby)
	RegisterSignal(src.artifact_atom, COMSIG_ATTACKHAND, .proc/artifact_attack_hand)

	// etc_act (artifact being acted on by explosions, blob, meteor, etc)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_BLOB_ACT, .proc/artifact_blob_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_EX_ACT, .proc/artifact_ex_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_HITBY_PROJ, .proc/artifact_bullet_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_REAGENT_ACT, .proc/artifact_reagent_act)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_METEORHIT, .proc/artifact_meteorhit)

	// Misc
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_EXAMINE, .proc/examine_hint)
	RegisterSignal(src.artifact_atom, COMSIG_OBJ_FLIP_INSIDE, .proc/artifact_mob_flip_inside)
	RegisterSignal(src.artifact_atom, COMSIG_ATOM_HITBY_THROWN, .proc/artifact_hitby)

	// Artifact specific
	RegisterSignal(src.artifact_atom, COMSIG_ARTIFACT_FAULT_USED, .proc/artifact_fault_used)
	RegisterSignal(src.artifact_atom, COMSIG_ARTIFACT_DEVELOP_FAULT, .proc/maybe_develop_fault)
	RegisterSignal(src.artifact_atom, COMSIG_ARTIFACT_ACTIVATE, .proc/artifact_activated)
	RegisterSignal(src.artifact_atom, COMSIG_ARTIFACT_TAKE_DAMAGE, .proc/artifact_take_damage)

	// Clean up artifact/drop stuff on parent deletion
	RegisterSignal(src.artifact_atom, COMSIG_PARENT_PRE_DISPOSING, .proc/artifact_destroyed)

	// Stuff only relevant to artifact items
	if (isitem(src.artifact_atom))
		RegisterSignal(src.artifact_atom, COMSIG_ITEM_ATTACK_PRE, .proc/artifact_attack)
		RegisterSignal(src.artifact_atom, COMSIG_ITEM_AFTERATTACK, .proc/artifact_afterattack)

	if (forceartiorigin)
		src.artifact.validtypes = forceartiorigin

	// Setup actual origin
	var/datum/artifact_origin/real_origin = global.artifact_controls.get_origin_from_string(pick(src.artifact.validtypes))
	src.artifact.artitype = real_origin

	// Make this appear like an artifact
	if (scramble_appearance)

		// Origin we appear as- small chance to be different from the actual origin
		var/datum/artifact_origin/appearance_origin = real_origin
		if (prob(real_origin.scramblechance))
			appearance_origin = null

		// If we nulled the appearance, pick a random one
		if (!istype(appearance_origin, /datum/artifact_origin/))
			appearance_origin = global.artifact_controls.get_origin_from_string(pick(global.artifact_controls.artifact_origin_names))

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
		src.artifact_atom.icon_state = appearance_origin.name + "-[rand(1, appearance_origin.max_sprites)]"
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
		src.artifact.fault_types |= real_origin.fault_types - src.artifact.fault_blacklist
		src.artifact.internal_name = real_origin.generate_name()
		src.artifact.used_names[real_origin.type_name] = src.artifact.internal_name
		src.artifact.nofx = real_origin.nofx

		// Low chance to start with a fault
		src.maybe_develop_fault(src.artifact_atom, 10)

		// Activate automatically if we do that
		if (src.artifact.automatic_activation)
			src.artifact_activated()

		// Generate activation triggers
		if (!src.artifact.automatic_activation)
			var/list/valid_triggers = src.artifact.validtriggers
			var/trigger_amount = rand(src.artifact.min_triggers, src.artifact.max_triggers)
			var/selection = null
			while (trigger_amount > 0)
				trigger_amount--
				selection = pick(valid_triggers)
				if (ispath(selection))
					var/datum/artifact_trigger/trigger = new selection
					src.artifact.triggers += trigger
					valid_triggers -= selection


		// Finally, add to artifact controller so we can track it and run the artifact's setup
		global.artifact_controls.artifacts += src.artifact_atom
		src.artifact.post_setup()

/datum/component/artifact/UnregisterFromParent()
	global.artifact_controls.artifacts -= src.artifact_atom
	UnregisterSignal(artifact_atom, list(COMSIG_ATTACKBY, COMSIG_ATTACKHAND, COMSIG_ATOM_BLOB_ACT,
											COMSIG_ATOM_EX_ACT, COMSIG_ATOM_HITBY_PROJ, COMSIG_ATOM_REAGENT_ACT,
											COMSIG_ATOM_METEORHIT, COMSIG_OBJ_FLIP_INSIDE, COMSIG_ARTIFACT_FAULT_USED,
											COMSIG_ATOM_EXAMINE, COMSIG_PARENT_PRE_DISPOSING, COMSIG_ITEM_ATTACK_PRE,
											COMSIG_ITEM_AFTERATTACK, COMSIG_ATOM_HITBY_THROWN))

/**
 * Proc called to possibly give an artifact a fault, depending on probability. Called in New() with a low probability, and also whenever you
 * damage an artifact too much.
 */
/datum/component/artifact/proc/maybe_develop_fault(atom/movable/artifact, faultprob)

	if (src.artifact.artitype.name == "eldritch")
		faultprob *= 2 // eldritch artifacts fucking hate you and are twice as likely to go faulty
	faultprob = clamp(faultprob, 0, 100)

	if (prob(faultprob) && length(src.artifact.fault_types))
		var/new_fault = weighted_pick(src.artifact.fault_types)
		if (ispath(new_fault))
			var/datum/artifact_fault/F = new new_fault(src.artifact)
			F.holder = src.artifact
			src.artifact.faults += F
		else
			stack_trace("Didn't get a path from fault_types for artifact [src.artifact.type]. Got \[[new_fault]\] instead.")

/datum/component/artifact/proc/artifact_mob_flip_inside(mob/flipper)
	src.artifact_take_damage(damage = rand(5, 20))
	flipper.visible_message("<span class='alert'>\the [src.artifact_atom] seems to be a bit more damaged!</span>")

/datum/component/artifact/proc/artifact_take_damage(artifact, damage = 0)
	src.artifact.health -= damage
	src.artifact.health = min(src.artifact.health, 100)

	if (src.artifact.health <= 0)
		qdel(src.artifact_atom)

/// Called when we examine the artifact (atom). Appends the artifact (datum) examine hint.
/datum/component/artifact/proc/examine_hint(atom/movable/artifact, mob/examiner, list/lines)
	lines += src.artifact.examine_hint

/// Called before the parent atom is deleted. DO NOT CALL THIS SHIT JUST DELETE THE THING PARENT ATOM
/datum/component/artifact/proc/artifact_destroyed()

	src.artifact_atom.visible_message("<span class='alert><b>[src.artifact_atom] [src.artifact.artitype.destruction_message]!</b></span>")

	src.remove_artifact_forms()
	src.artifact_deactivated()
	src.artifact.effect_destroyed()

	global.artifact_controls.artifacts -= src.artifact_atom

	qdel(src.artifact)


/**
 * Activate an artifact fault, triggered ON the user. Handheld artifacts can activate a fault on the user or the target of something.
 * cosmeticSource is for messages; set it to something artifact adjacent to make the effect come from a forcefield, bullet, etc instead.
 */
/datum/component/artifact/proc/artifact_fault_used(atom/movable/artifact, mob/user, atom/cosmeticSource)

	if (!length(src.artifact.faults))
		return FAULT_RESULT_INVALID // no faults, so dont waste any more time
	if (!cosmeticSource)
		cosmeticSource = src.artifact_atom
	var/halt = FALSE
	for (var/datum/artifact_fault/F in src.artifact.faults)
		if (prob(F.trigger_prob))
			if (F.halt_loop)
				halt = TRUE
			F.deploy(src.artifact_atom, user, cosmeticSource)
		if (halt)
			return FAULT_RESULT_STOP
	return FAULT_RESULT_SUCCESS

/// Called to activate this artifact and start applying whatever effects it has
/datum/component/artifact/proc/artifact_activated()
	if (src.artifact.activated)
		return ARTIFACT_ALREADY_ACTIVATED
	if (src.artifact.triggers.len < 1 && !src.artifact.automatic_activation)
		return ARTIFACT_CANNOT_ACTIVATE
	if (!src.artifact.may_activate(src.artifact_atom))
		return ARTIFACT_CANNOT_ACTIVATE
	if (src.artifact.activ_sound)
		playsound(src.artifact_atom.loc, src.artifact.activ_sound, 100, TRUE)
	if (src.artifact.activ_text)
			src.artifact_atom.visible_message("<b>[src.artifact_atom] [src.artifact.activ_text]</b>")
	src.artifact.activated = TRUE
	if (src.artifact.nofx)
		src.artifact_atom.icon_state = src.artifact_atom.icon_state + "fx"
	else
		src.artifact_atom.UpdateOverlays(src.artifact.fx_image, "activated")
	src.artifact.effect_activate()
	return ARTIFACT_NOW_ACTIVATED

/// Called to deactivate this artifact, whether automatically or through an activator key
/datum/component/artifact/proc/artifact_deactivated()
	if (!src.artifact.activated) // do not deactivate if already deactivated
		return ARTIFACT_ALREADY_DEACTIVATED
	if (src.artifact.deact_sound)
		playsound(src.artifact_atom.loc, src.artifact.deact_sound, 100, 1)
	if (src.artifact.deact_text)
		src.artifact_atom.visible_message("<b>[src.artifact_atom] [src.artifact.deact_text]</b>")
	src.artifact.activated = FALSE
	if (src.artifact.nofx)
		src.artifact_atom.icon_state = src.artifact_atom.icon_state - "fx"
	else
		src.artifact_atom.UpdateOverlays(null, "activated")
	src.artifact.effect_deactivate()
	return ARTIFACT_NOW_DEACTIVATED

/// Called when someone hits another mob with this artifact (only relevant to artifact items)
/datum/component/artifact/proc/artifact_attack(obj/item/weapon, mob/target, mob/user)
	if (src.artifact.activated)
		src.artifact_fault_used(user)
		src.artifact_fault_used(target)
		src.artifact.effect_melee_attack(weapon, user, target)

/// Called when someone clicks pretty much anything with an artifact. For certain objects (telewands etc), called on ranged clicks too.
/// Currently just passes the attack to the artifact datum. First two args are unused.
/datum/component/artifact/proc/artifact_afterattack(artifact, also_the_artifact, atom/target, mob/user)
	src.artifact.effect_afterattack(user, target)

/// Called when someone pokes this artifact, or is shoved into it
/datum/component/artifact/proc/artifact_attack_hand(mob/user)
	user.lastattacked = src.artifact_atom // no spam
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


// TODO make this use signals on the relevant items.
/// Called when someone hits this with an item
/// Returns FALSE if we did something special to the artifact, TRUE if we just smacked it like normal.
/datum/component/artifact/proc/artifact_attackby(var/artifact_atom, var/obj/item/I, var/mob/attacker)

	. = FALSE
	attacker.lastattacked = src.artifact_atom // no spam

	if (isrobot(attacker))
		src.artifact_stimulus("silitouch", 1)

	if (isweldingtool(I))
		var/obj/item/weldingtool/welder = I
		if (welder.try_weld(attacker, 0, -1, FALSE, TRUE))
			src.artifact_stimulus("heat", 800)
			src.artifact_atom.visible_message("<span class='alert'>[attacker] burns \the [src.artifact_atom] with [I]!</span>")
			return

	if (istype(I, /obj/item/device/light/zippo))
		var/obj/item/device/light/zippo/ZIP = I
		if (ZIP.on)
			src.artifact_stimulus("heat", 400)
			src.artifact_atom.visible_message("<span class='alert'>[attacker] burns \the [src.artifact_atom] with [ZIP]!</span>")
			return

	if(istype(I, /obj/item/device/igniter))
		src.artifact_stimulus("elec", 700)
		src.artifact_stimulus("heat", 385)
		src.artifact_atom.visible_message("<span class='alert'>[attacker] sparks against \the [src.artifact_atom] with \the [I]!</span>")

	if (istype(I, /obj/item/robodefibrillator))
		var/obj/item/robodefibrillator/R = I
		if (R.do_the_shocky_thing(attacker))
			src.artifact_stimulus("elec", 2500)
			src.artifact_atom.visible_message("<span class='alert'>[attacker] shocks \the [src.artifact_atom] with \the [R]!</span>")
			return

	if(istype(I, /obj/item/baton))
		var/obj/item/baton/BAT = I
		if (BAT.can_stun(1, attacker))
			src.artifact_stimulus("force", BAT.force)
			src.artifact_stimulus("elec", 1500)
			playsound(src.artifact_atom.loc, "sound/impact_sounds/Energy_Hit_3.ogg", 100, 1)
			src.artifact_atom.visible_message("<span class='alert'>[attacker] zaps \the [src.artifact_atom] with [BAT]!</span>")
			BAT.process_charges(-1,attacker)
			return

	if(istype(I, /obj/item/device/flyswatter))
		src.artifact_stimulus("elec", 1500)
		src.artifact_atom.visible_message("<span class='alert'>[attacker] shocks \the [src.artifact_atom] with \the [I]!</span>")
		return

	if(ispulsingtool(I))
		src.artifact_stimulus("elec", 1000)
		src.artifact_atom.visible_message("<span class='alert'>[attacker] shocks \the [src.artifact_atom] with \the [I]!</span>")
		return

	if (istype(I, /obj/item/parts/robot_parts))
		var/obj/item/parts/robot_parts/part = I
		src.artifact_atom.visible_message("<b>[attacker]</b> presses \the [part] against \the [src.artifact_atom].</span>")
		src.artifact_stimulus("silitouch", 1)
		return

	if (istype(I, /obj/item/parts/human_parts))
		var/obj/item/parts/human_parts/part = I
		src.artifact_atom.visible_message("<b>[attacker]</b> smooshes \the [part] against \the [src.artifact_atom].</span>")
		src.artifact_stimulus("carbtouch", 1)
		return

	if (istype(I, /obj/item/grab))
		var/obj/item/grab/G = I
		if (ismob(G.affecting))
			if (G.state < GRAB_STRONG)
				// Not a strong grip so just smoosh em into it
				// generally speaking only humans and the like can be grabbed so whatev
				if (istype(G.affecting, /mob/living/carbon))
					src.artifact_atom.visible_message("<b>[attacker]</b> gently presses [G.affecting] against \the [src].")
					src.artifact_stimulus("carbtouch", 1)
				return

			var/mob/M = G.affecting
			var/mob/A = G.assailant
			src.artifact_atom.visible_message("<strong class='combat'>[A] shoves [M] against \the [src.artifact_atom]!</strong>")
			logTheThing("combat", A, M, "forces [constructTarget(M,"combat")] to touch \an ([src.type]) artifact at [log_loc(src)].")
			src.artifact_attack_hand(M)
			return

	if (istype(I, /obj/item/circuitboard))
		var/obj/item/circuitboard/board = I
		src.artifact_atom.visible_message("<b>[attacker]</b> offers the [board] to \the [src.artifact_atom].</span>")
		src.artifact_stimulus("data", 1)
		return

	if (istype(I, /obj/item/disk/data))
		var/obj/item/disk/data/datadisk = I
		src.artifact_atom.visible_message("<b>[attacker]</b> offers the [datadisk] to \the [src.artifact_atom].</span>")
		src.artifact_stimulus("data", 1)
		return

	if (I.force)
		src.artifact_stimulus("force", I.force)

	src.artifact.effect_attacked_by(I, attacker)
	return TRUE


/// Called when a blob hits this artifact
/datum/component/artifact/proc/artifact_blob_act(var/power)
	src.artifact_stimulus("force", power)
	src.artifact_stimulus("carbtouch", 1)

/// Called when an explosion hits this artifact
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

/// Called when a projectile impacts this artifact
/datum/component/artifact/proc/artifact_bullet_act(obj/projectile/shot)
	switch (shot.proj_data.damage_type)
		if(D_KINETIC,D_PIERCING,D_SLASHING)
			var/obj/machinery/networked/test_apparatus/impact_pad/pad = locate() in get_turf(src.artifact_atom)
			pad?.impactpad_senseforce(src.artifact, shot)
			src.artifact_stimulus("force", shot.power)
		if(D_ENERGY)
			src.artifact_stimulus("elec", shot.power * 10)
		if(D_BURNING)
			src.artifact_stimulus("heat", 310 + (shot.power * 5))
		if(D_RADIOACTIVE)
			src.artifact_stimulus("radiate", shot.power)

/// Called when this artifact is hit by a thrown movable
/datum/component/artifact/proc/artifact_hitby(atom/movable/AM, datum/thrown_thing/thr)
	src.artifact_stimulus("force", AM.throwforce)
	var/obj/machinery/networked/test_apparatus/impact_pad/pad = locate() in src.artifact_atom.loc
	pad?.impactpad_senseforce(src.artifact, AM)

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
			if (src.artifact.artitype.name == "martian")
				src.maybe_develop_fault(faultprob = 80)
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
			src.artifact_take_damage(damage = volume * 2)
		if("pacid","clacid","nitric_acid")
			src.artifact_take_damage(damage = volume * 10)
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
					playsound(src.artifact_atom.loc, "sound/impact_sounds/Slimy_Hit_3.ogg", 100, 1)
					src.maybe_develop_fault(faultprob = 33)
					src.artifact_take_damage(damage = strength / 1.5)
			if(stimtype == "elec")
				if (strength >= 3000) // max you can get from the electrobox is 5000
					T.visible_message("<span class='alert'>[src] seems to quiver in pain!</span>")
					src.artifact_take_damage(damage = strength / 1000)
			if(stimtype == "radiate")
				if (strength >= 6)
					src.maybe_develop_fault(faultprob = strength * 10 - 20) // 40% at 6, 80% at 10
					src.artifact_take_damage(damage = strength * 1.25)
		if("wizard") // these are big crystals, thus you probably shouldn't smack them around too hard!
			if(stimtype == "force")
				if (strength >= 20)
					T.visible_message("<span class='alert'>[src] cracks and splinters!</span>")
					playsound(src.artifact_atom.loc, "sound/impact_sounds/Glass_Shards_Hit_1.ogg", 100, 1)
					src.maybe_develop_fault(faultprob = 80)
					src.artifact_take_damage(damage = strength * 1.5)

	if (!src.artifact.activated)
		for (var/datum/artifact_trigger/trigger in src.artifact.triggers)
			if (trigger.stimulus_required == stimtype)
				// We need to check the amount of stimulus, might not activate if too low/high (e.g. rads)
				if (trigger.do_amount_check)
					if (trigger.stimulus_type == ARTIFACT_STIMULUS_AMOUNT_GEQ && strength >= trigger.stimulus_amount)
						src.artifact_activated()
					else if (trigger.stimulus_type == ARTIFACT_STIMULUS_AMOUNT_EXACT && strength <= trigger.stimulus_amount)
						src.artifact_activated()
					else if (trigger.stimulus_type == ARTIFACT_STIMULUS_AMOUNT_LEQ && strength == trigger.stimulus_amount)
						src.artifact_activated()
					else
						if (istext(src.artifact.hint_text))
							if (strength >= trigger.stimulus_amount - trigger.hint_range && strength <= trigger.stimulus_amount + trigger.hint_range)
								T.visible_message("<b>[src.artifact_atom]</b> [src.artifact.hint_text]")
				// We don't care about stimulus amount at all (e.g. carbon touch)
				else
					src.artifact_activated()


/// Removes all artifact forms attached to this and makes them fall to the floor
/// Because artifacts often like to disappear in mysterious ways
/datum/component/artifact/proc/remove_artifact_forms()
	var/removed = 0
	for(var/obj/item/sticker/postit/artifact_paper/AP in src.artifact_atom.vis_contents)
		AP.remove_from_attached()
		removed++
	if(removed == 1)
		src.artifact_atom.visible_message("The artifact form that was attached falls to the ground.")
	else if(removed > 1)
		src.artifact_atom.visible_message("All the artifact forms that were attached fall to the ground.")


// Not part of the component but I'm putting it here anyways
/// Spawn an artifact somewhere. Used by the game to spawn artifacts as the round starts.
/proc/Artifact_Spawn(var/atom/T, var/forceartiorigin, var/datum/artifact/forceartitype = null)
	if (!T)
		return

	var/list/artifactweights
	if(forceartiorigin)
		artifactweights = global.artifact_controls.artifact_rarities[forceartiorigin]
	else
		artifactweights = global.artifact_controls.artifact_rarities["all"]

	var/datum/artifact/picked
	if(forceartitype)
		picked = forceartitype
	else
		if (length(artifactweights) == 0)
			return
		picked = weighted_pick(artifactweights) // Get artifact datum type

	var/type = null
	if(ispath(picked, /datum/artifact))
		type = initial(picked.associated_object) // Get artifact object type
	else
		stack_trace("Didn't get an artifact datum path to spawn an artifact from origin []")
		return

	if (istext(forceartiorigin))
		new type(T,forceartiorigin)
	else
		new type(T)
