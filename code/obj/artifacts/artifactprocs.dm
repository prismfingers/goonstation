/proc/Artifact_Spawn(var/atom/T,var/forceartiorigin, var/datum/artifact/forceartitype = null)
	if (!T)
		return
	if (!istype(T,/turf/) && !istype(T,/obj/))
		return

	var/list/artifactweights
	if(forceartiorigin)
		artifactweights = artifact_controls.artifact_rarities[forceartiorigin]
	else
		artifactweights = artifact_controls.artifact_rarities["all"]

	var/datum/artifact/picked
	if(forceartitype)
		picked = forceartitype
	else
		if (artifactweights.len == 0)
			return
		picked = weighted_pick(artifactweights)

	var/type = null
	if(ispath(picked,/datum/artifact/))
		type = initial(picked.associated_object)	// artifact type
	else
		return

	if (istext(forceartiorigin))
		new type(T,forceartiorigin)
	else
		new type(T)


/obj/proc/ArtifactSetup()
	// This proc gets called in every artifact's New() proc, after src.artifact is turned from a 1 into its appropriate datum.
	//It scrambles the name and appearance of the artifact so we can't tell what it is on sight or cursory examination.
	// Could potentially go in /obj/New(), but...
	if (!src.ArtifactSanityCheck())
		return
	var/datum/artifact/A = src.artifact
	A.holder = src

	if (!artifact_controls) //Hasn't been init'd yet
		sleep(2 SECONDS)

	var/datum/artifact_origin/AO = artifact_controls.get_origin_from_string(pick(A.validtypes))
	if (!istype(AO,/datum/artifact_origin/))
		qdel(src)
		return
	A.artitype = AO
	A.scramblechance = AO.scramblechance
	// Refers to the artifact datum's list of origins it's allowed to be from and selects one at random. This way we can avoid
	// stuff that doesn't make sense like ancient robot plant seeds or eldritch healing devices

	var/datum/artifact_origin/appearance = artifact_controls.get_origin_from_string(AO.name)
	if (prob(A.scramblechance))
		appearance = null
	// rare-ish chance of an artifact appearing to be a different origin, just to throw things off

	if (!istype(appearance,/datum/artifact_origin/))
		var/list/all_origin_names = list()
		for (var/datum/artifact_origin/O in artifact_controls.artifact_origins)
			all_origin_names += O.name
		appearance = artifact_controls.get_origin_from_string(pick(all_origin_names))

	var/name1 = pick(appearance.adjectives)
	var/name2 = "thingy"
	if (isitem(src))
		name2 = pick(appearance.nouns_small)
	else
		name2 = pick(appearance.nouns_large)

	src.name = "[name1] [name2]"
	src.real_name = "[name1] [name2]"
	desc = "You have no idea what this thing is!"
	A.touch_descriptors |= appearance.touch_descriptors

	src.icon_state = appearance.name + "-[rand(1,appearance.max_sprites)]"
	if (isitem(src))
		var/obj/item/I = src
		I.item_state = appearance.name

	A.fx_image = image(src.icon, src.icon_state + "fx")
	A.fx_image.color = rgb(rand(AO.fx_red_min,AO.fx_red_max),rand(AO.fx_green_min,AO.fx_green_max),rand(AO.fx_blue_min,AO.fx_blue_max))

	A.react_mpct[1] = AO.impact_reaction_one
	A.react_mpct[2] = AO.impact_reaction_two
	A.react_heat[1] = AO.heat_reaction_one
	A.activ_sound = pick(AO.activation_sounds)
	A.fault_types |= AO.fault_types - A.fault_blacklist
	A.internal_name = AO.generate_name()
	A.used_names[AO.type_name] = A.internal_name
	A.nofx = AO.nofx

	ArtifactDevelopFault(10)

	if (A.automatic_activation)
		src.ArtifactActivated()

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
	A.post_setup()

/obj/proc/ArtifactHitWith(var/obj/item/O, var/mob/user)
	if (!src.ArtifactSanityCheck())
		return 1


// DONE
/obj/proc/ArtifactDevelopFault()
/obj/proc/ArtifactSanityCheck()
/obj/proc/ArtifactDestroyed()
/obj/proc/Artifact_emp_act()
/obj/proc/Artifact_blob_act(var/power)
/obj/proc/ArtifactTakeDamage(var/dmg_amount)
/obj/proc/remove_artifact_forms()
/obj/proc/ArtifactTouched(mob/user as mob)
/obj/proc/Artifact_attackby(obj/item/W, mob/user)
/obj/proc/Artifact_reagent_act(var/reagent_id, var/volume)
/obj/proc/ArtifactFaultUsed(var/mob/user, var/atom/cosmeticSource = null)
/obj/proc/ArtifactDeactivated()
/obj/proc/ArtifactActivated()
