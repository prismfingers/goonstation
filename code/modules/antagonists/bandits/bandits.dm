// These are needed because Load Area seems to have issues with ordinary var-edited landmarks.
/obj/landmark/bandits
	name = "Bandit-Spawn"

	leader
		name = "Bandit-Leader-Spawn"

/datum/antagonist/bandit
	id = ROLE_BANDIT
	display_name = "Bandit"

	give_equipment()
		if (!ishuman(src.owner.current))
			boutput(src.owner.current, "<span class='alert'>How are you gonna shoot a gun if you can't hold it, pardner?</span>")
			return FALSE
		var/mob/living/carbon/human/H = src.owner.current
		H.unequip_all(TRUE)

		if (id == ROLE_BANDIT_LEADER)
			H.equip_if_possible(new /obj/item/clothing/under/misc/western(H), H.slot_w_uniform)
			H.equip_if_possible(new /obj/item/clothing/suit/gimmick/guncoat/reinforced/black(H), H.slot_wear_suit)
			H.equip_if_possible(new /obj/item/clothing/head/westhat/black(H), H.slot_head)
			H.equip_if_possible(new /obj/item/clothing/shoes/westboot/black(H), H.slot_shoes)
			H.equip_if_possible(new /obj/item/device/radio/headset/bandit/leader(H), H.slot_ears)
			H.equip_if_possible(new /obj/item/storage/belt/security/shoulder_holster/inspector(H), H.slot_belt)

		else if (id == ROLE_BANDIT)
			// Random clothing:
			var/obj/item/clothing/jumpsuit = pick(/obj/item/clothing/under/misc/western,
												/obj/item/clothing/under/misc/serpico)
			var/obj/item/clothing/hat = pick(/obj/item/clothing/head/westhat/red,
											/obj/item/clothing/head/westhat/brown,
											/obj/item/clothing/head/westhat/tan)
			var/obj/item/clothing/boots = pick(/obj/item/clothing/shoes/westboot/black,
											/obj/item/clothing/shoes/westboot/brown,
											/obj/item/clothing/shoes/westboot/dirty,
											/obj/item/clothing/shoes/westboot)
			H.equip_if_possible(new jumpsuit, H.slot_w_uniform)
			H.equip_if_possible(new hat, H.slot_head)
			H.equip_if_possible(new boots, H.slot_shoes)
			H.equip_if_possible(new /obj/item/device/radio/headset/bandit(H), H.slot_ears)
			H.equip_if_possible(new /obj/item/storage/belt/security/shoulder_holster(H), H.slot_belt)

		H.equip_if_possible(new /obj/item/storage/backpack(H), H.slot_back)

		H.equip_sensory_items()

		H.traitHolder.addTrait("training_drinker")
		H.traitHolder.addTrait("smoker")

	bandit_leader
		id = ROLE_BANDIT_LEADER
		display_name = "Bandit leader"
