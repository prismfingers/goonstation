// These are needed because Load Area seems to have issues with ordinary var-edited landmarks.
/obj/landmark/bandits
	name = "Bandit-Spawn"

	leader
		name = "Bandit-Leader-Spawn"

/datum/antagonist/bandit
	id = ROLE_BANDIT
	display_name = "Bandit"

	var/bandit_leader = FALSE

	give_equipment()
		if (!ishuman(src.owner.current))
			boutput(src.owner.current, "<span class='alert'>How are you gonna shoot a gun if you can't hold it, pardner?</span>")
			return FALSE
		var/mob/living/carbon/human/H = src.owner.current
		H.unequip_all(TRUE)

		if (id == ROLE_BANDIT_LEADER)
			H.equip_if_possible(new /obj/item/clothing/under/shirt_pants_b(H), H.slot_w_uniform)
			H.equip_if_possible(new /obj/item/clothing/suit/armor/pirate_captain_coat(H), H.slot_wear_suit)
			H.equip_if_possible(new /obj/item/clothing/head/pirate_captain(H), H.slot_head)
			H.equip_if_possible(new /obj/item/clothing/shoes/swat/heavy(H), H.slot_shoes)
			H.equip_if_possible(new /obj/item/device/radio/headset/pirate/captain(H), H.slot_ears)
			H.equip_if_possible(new /obj/item/pinpointer/gold_bee(H), H.slot_l_store)

		else if (id == ROLE_BANDIT)
			// Random clothing:
			var/obj/item/clothing/jumpsuit = pick(/obj/item/clothing/under/gimmick/waldo,
							/obj/item/clothing/under/misc/serpico,
							/obj/item/clothing/under/gimmick/guybrush,
							/obj/item/clothing/under/misc/dirty_vest)
			var/obj/item/clothing/hat = pick(/obj/item/clothing/head/red,
							/obj/item/clothing/head/bandana/red,
							/obj/item/clothing/head/pirate_brn,
							/obj/item/clothing/head/pirate_blk)

			H.equip_if_possible(new jumpsuit, H.slot_w_uniform)
			H.equip_if_possible(new hat, H.slot_head)
			H.equip_if_possible(new /obj/item/device/radio/headset/pirate(H), H.slot_ears)

		H.equip_if_possible(new /obj/item/clothing/shoes/swat(H), H.slot_shoes)
		H.equip_if_possible(new /obj/item/storage/backpack(H), H.slot_back)
		H.equip_if_possible(new /obj/item/clothing/glasses/eyepatch/pirate(H), H.slot_glasses)
		H.equip_if_possible(new /obj/item/tank/emergency_oxygen/extended(H), H.slot_r_store)
		H.equip_if_possible(new /obj/item/swords_sheaths/pirate(H), H.slot_belt)

		H.equip_sensory_items()

		H.traitHolder.addTrait("training_drinker")
		H.traitHolder.addTrait("smoker")

	bandit_leader
		id = ROLE_BANDIT_LEADER
		display_name = "Bandit leader"
		bandit_leader = TRUE
