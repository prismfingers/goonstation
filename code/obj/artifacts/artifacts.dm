/obj/artifact
	// a totally inert piece of shit that does nothing (alien art)
	// might as well use it as the category header for non-machinery artifacts just to be efficient
	name = "artifact large art piece"
	icon = 'icons/obj/artifacts/artifacts.dmi'
	icon_state = "wizard-1" // it's technically pointless to set this but it makes it easier to find in the dreammaker tree
	opacity = 0
	density = 1
	anchored = 0
	artifact = 1
	mat_changename = 0
	mat_changedesc = 0
	var/associated_datum = /datum/artifact/art

	New(var/loc, var/forceartiorigin)
		..()
		var/datum/artifact/AS = new src.associated_datum(src)
		if (forceartiorigin) AS.validtypes = list("[forceartiorigin]")
		src.artifact = AS

		SPAWN(0)
			src.ArtifactSetup()

	// TODO
	examine()
		. = list("You have no idea what this thing is!")
		if (!src.ArtifactSanityCheck())
			return
		var/datum/artifact/A = src.artifact
		if (istext(A.examine_hint))
			. += A.examine_hint

/obj/machinery/artifact
	name = "artifact large art piece"
	icon = 'icons/obj/artifacts/artifacts.dmi'
	icon_state = "wizard-1" // it's technically pointless to set this but it makes it easier to find in the dreammaker tree
	opacity = 0
	density = 1
	anchored = 0
	artifact = 1
	mat_changename = 0
	mat_changedesc = 0
	var/associated_datum = /datum/artifact/art

	New(var/loc, var/forceartiorigin)
		..()
		var/datum/artifact/AS = new src.associated_datum(src)
		if (forceartiorigin)
			AS.validtypes = list("[forceartiorigin]")
		src.artifact = AS

		SPAWN(0)
			src.ArtifactSetup()

	examine()
		. = list("You have no idea what this thing is!")
		if (!src.ArtifactSanityCheck())
			return
		var/datum/artifact/A = src.artifact
		if (istext(A.examine_hint))
			. += A.examine_hint

	process()
		..()
		if (!src.ArtifactSanityCheck())
			return
		var/datum/artifact/A = src.artifact

		if (A.activated)
			A.effect_process(src)

/obj/item/artifact
	name = "artifact small art piece"
	icon = 'icons/obj/artifacts/artifactsitem.dmi'
	icon_state = "wizard-1"
	artifact = 1
	mat_changename = 0
	mat_changedesc = 0
	var/associated_datum = /datum/artifact/art

	New(var/loc, var/forceartiorigin)
		..()
		var/datum/artifact/AS = new src.associated_datum(src)
		if (forceartiorigin)
			AS.validtypes = list("[forceartiorigin]")
		src.artifact = AS

		SPAWN(0)
			src.ArtifactSetup()



/obj/artifact_spawner
	// pretty much entirely for debugging/gimmick use
	New(var/loc,var/forceartiorigin = null,var/cinematic = 0)
		..()
		var/turf/T = get_turf(src)
		if (cinematic)
			T.visible_message("<span class='alert'><b>An artifact suddenly warps into existence!</b></span>")
			playsound(T,"sound/effects/teleport.ogg",50,1)
			var/obj/decal/teleport_swirl/swirl = new /obj/decal/teleport_swirl
			swirl.set_loc(T)
			SPAWN(1.5 SECONDS)
				qdel(swirl)
		Artifact_Spawn(T,forceartiorigin)
		qdel(src)
		return

/obj/artifact_type_spawner
	var/list/types = list()

	New(var/loc)
		..()
		if(length(types))
			Artifact_Spawn(src.loc, forceartitype = pick(src.types))
		else
			CRASH("No artifact types provided.")
		qdel(src)
		return

/obj/artifact_type_spawner/vurdalak

	New(var/loc)
		src.types = concrete_typesof(/datum/artifact)
		..()

// I removed mining artifacts from this list because they are kinda not in the game right now
/obj/artifact_type_spawner/gragg
	types = list(
		/datum/artifact/activator_key,
		/datum/artifact/wallwand,
		/datum/artifact/melee,
		/datum/artifact/telewand,
		/datum/artifact/energygun,
		/datum/artifact/watercan,
		/datum/artifact/pitcher
		)
