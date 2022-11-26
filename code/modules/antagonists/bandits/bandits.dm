// These are needed because Load Area seems to have issues with ordinary var-edited landmarks.
/obj/landmark/bandits
	name = "Bandit-Spawn"

	leader
		name = "Bandit-Leader-Spawn"

/obj/gold_bee
	name = "\improper Gold Bee Statue"
	desc = "The artist has painstainkly sculpted every individual strand of bee wool to achieve this breath-taking result. You could almost swear this bee is about to spontaneously take flight."
	icon = 'icons/obj/decoration.dmi'
	icon_state = "gold_bee"
	flags = FPRINT | FLUID_SUBMERGE | TGUI_INTERACTIVE
	object_flags = NO_GHOSTCRITTER
	density = 1
	anchored = 0
	var/list/gibs = list()

	New()
		..()
		src.setMaterial(getMaterial("gold"), appearance = 0, setname = 0)
		for(var/i in 1 to 7)
			gibs.Add(new /obj/item/stamped_bullion)
			gibs.Add(new /obj/item/raw_material/gold)

	attack_hand(mob/user)
		src.add_fingerprint(user)

		if (user.a_intent != INTENT_HARM)
			src.visible_message("<span class='notice'><b>[user]</b> pets [src]!</span>")

	attackby(obj/item/W, mob/user)
		src.add_fingerprint(user)
		user.lastattacked = src

		src.visible_message("<span class='combat'><b>[user]</b> hits [src] with [W]!</span>")
		src.take_damage(W.force / 3)
		playsound(src.loc, 'sound/impact_sounds/Metal_Hit_Light_1.ogg', 100, 1)
		attack_particle(user, src)

	bullet_act(var/obj/projectile/P)
		var/damage = 0
		damage = round(((P.power/6)*P.proj_data.ks_ratio), 1.0)

		src.visible_message("<span class='combat'><b>[src]</b> is hit by [P]!</span>")
		if (damage <= 0)
			return
		if(P.proj_data.damage_type == D_KINETIC || (P.proj_data.damage_type == D_ENERGY && damage))
			src.take_damage(damage / 3)
		else if (P.proj_data.damage_type == D_PIERCING)
			src.take_damage(damage)

	proc/take_damage(var/amount)
		if (!isnum(amount) || amount < 1)
			return
		src._health = max(0,src._health - amount)

		if (src._health < 1)
			src.visible_message("<span class='alert'><b>[src]</b> breaks and shatters into many peices!</span>")
			playsound(src.loc, 'sound/impact_sounds/plate_break.ogg', 50, 0.1, 0, 0.5)
			if (length(gibs))
				for (var/atom/movable/I in gibs)
					I.set_loc(get_turf(src))
					ThrowRandom(I, 3, 1)
			qdel(src)

/obj/item/pinpointer/gold_bee
	name = "pinpointer (Gold Bee Statue)"
	desc = "Points in the direction of the Gold Bee Statue."
	icon_state = "disk_pinoff"
	icon_type = "disk"
	target_criteria = /obj/gold_bee
	hudarrow_color = "#e1940d"

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
