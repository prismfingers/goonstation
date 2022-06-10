/obj/item/instrument/artifact
	name = "artifact instrument"
	sounds_instrument = list()
	volume = 50
	randomized_pitch = TRUE
	desc_verb = list("plays", "makes", "causes")
	desc_sound = list("strange", "odd", "bizarre", "weird", "offputting", "unusual")
	desc_music = list("song", "ditty", "sound", "noise")

	New(var/loc, var/forceartiorigin)
		..()
		src.AddComponent(/datum/component/artifact, /datum/artifact/instrument, TRUE, forceartiorigin)

	play(mob/user)
		if (!ON_COOLDOWN(src, "artifact instrument spam", 25 SECONDS))
			SEND_SIGNAL(src, COMSIG_ARTIFACT_FAULT_USED, user)
			show_play_message(user)
			playsound(src, islist(src.sounds_instrument) ? pick(src.sounds_instrument) : src.sounds_instrument, src.volume, src.randomized_pitch)

/datum/artifact/instrument
	associated_object = /obj/item/artifact/instrument
	type_name = "Instrument"
	type_size = ARTIFACT_SIZE_MEDIUM
	automatic_activation = TRUE
	rarity_weight = 450
	validtypes = list("wizard", "eldritch", "precursor", "martian", "ancient")
	react_xray = list(10,65,95,9,"TUBULAR")

	post_setup()
		..()
		var/obj/item/instrument/artifact_item = src.holder
		artifact_item.sounds_instrument = src.artitype.instrument_sounds

