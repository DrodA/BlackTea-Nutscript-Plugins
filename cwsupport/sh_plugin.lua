PLUGIN.name = "Macro Weapon Register"
PLUGIN.author = "Black Tea"
PLUGIN.desc = "Gun Jesus have arrived."


nut.util.include("sh_configs.lua")
nut.util.include("sh_languages.lua")
nut.util.include("cl_cw3d2d.lua")

function PLUGIN:InitializedPlugins()
	table.Merge(nut.lang.stored["korean"], self.koreanTranslation)
	table.Merge(nut.lang.stored["english"], self.englishTranslation)

	-- Create Items with Lua
	do
		-- ammunition
		for name, data in pairs(self.ammoInfo) do
			local uniqueID = "ammo_"..name:lower()
			local ammoInfo = data

			local ITEM = nut.item.register(uniqueID, "base_ammo", nil, nil, true)
			ITEM.name = ammoInfo.name
			ITEM.ammo = name
			ITEM.ammoAmount = ammoInfo.amount or 30
			ITEM.price = ammoInfo.price or 200
			ITEM.model = ammoInfo.model or AMMO_BOX

			function ITEM:getDesc()
				return L("ammoDesc", self.ammoAmount, L(self.ammo))
			end
		end

		-- they were ass.
		local assWeapons = {
			["cw_ber_cz75"] = "muzzleflash_6",
			["cw_ber_deagletoast"] = "muzzleflash_6",
			["cw_ber_fnp45"] = "muzzleflash_6",
			["cw_ber_m9"] = "muzzleflash_6",
			["cw_ber_p220"] = "muzzleflash_6",
			["cw_ber_model620"] = "muzzleflash_6",
			["cw_ber_usp"] = "muzzleflash_6",
		}

		for k, v in ipairs(weapons.GetList()) do
			local class = v.ClassName
			local prefix

			if (class:find("cw_")) then
				prefix = "cw_"
			elseif (class:find("ma85_")) then
				prefix = "ma85_"
			end
			
			if (prefix and !class:find("base")) then
				-- Configure Weapon's Variables
				v.CanRicochet = false
				v.isGoodWeapon = true
				v.canPenetrate = function() return false end
				v.canRicochet = function() return false end
				v.MuzzleEffect = "muzzleflash_ak74"
				v.Primary.DefaultClip = 0

				if (self.changeAmmo[v.Primary.Ammo]) then
					v.Primary.Ammo = self.changeAmmo[v.Primary.Ammo]
				end

				v.VelocitySensitivity = 2

				if (v.MaxSpreadInc) then
					if (!v.neat_MaxSpreadInc) then
						v.neat_MaxSpreadInc = v.MaxSpreadInc
					end
					v.MaxSpreadInc = ((v.neat_MaxSpreadInc or v.MaxSpreadInc) or 0.1) * 3 
				end
				
				if (v.SpreadPerShot) then
					if (!v.neat_SpreadPerShot) then
						v.neat_SpreadPerShot  = v.SpreadPerShot or 0.1
					end

					v.SpreadPerShot = (v.neat_SpreadPerShot or v.SpreadPerShot) * 10

					if (v.FireDelay) then
						v.SpreadCooldown = (v.FireDelay or 0)*0.3
					end
					v.AddSpreadSpeed = v.SpreadPerShot*5
				end


				function v:getFinalSpread(vel, maxMultiplier)
					maxMultiplier = maxMultiplier or 1
					
					local final = self.BaseCone
					local aiming = self.dt.State == CW_AIMING
					-- take the continuous fire spread into account
					final = final + self.AddSpread
					
					-- and the player's velocity * mobility factor
					
					if aiming then
						-- irl the accuracy of your weapon goes to shit when you start moving even if you aim down the sights, so when aiming, player movement will impact the spread even more than it does during hip fire
						-- but we're gonna clamp it to a maximum of the weapon's hip fire spread, so that even if you aim down the sights and move, your accuracy won't be worse than your hip fire spread
						final = math.min(final + (vel / 10000 * self.VelocitySensitivity) * self.AimMobilitySpreadMod, self.HipSpread)
					else
						final = final + (vel / 10000 * self.VelocitySensitivity)
					end
					
					if self.ShootWhileProne and self:isPlayerProne() then
						final = final + vel / 1000
					end
					
					-- lastly, return the final clamped value
					return math.Clamp(final, 0, 0.09 + self:getMaxSpreadIncrease(maxMultiplier))
				end

				function v:recalculateDamage()
					local mult = hook.Run("GetSchemaCWDamage", self, self.Owner) or 1

					self.Damage = self.Damage_Orig * self.DamageMult * mult
				end

				function v:recalculateRecoil()
					local mult = hook.Run("GetSchemaCWRecoil", self, self.Owner) or 1

					self.Recoil = self.Recoil_Orig * self.RecoilMult * mult
				end

				function v:recalculateFirerate()
					local mult = hook.Run("GetSchemaCWFirerate", self, self.Owner) or 1

					self.FireDelay = self.FireDelay_Orig * self.FireDelayMult * mult
				end

				function v:recalculateVelocitySensitivity()
					local mult = hook.Run("GetSchemaCWVel", self, self.Owner) or 1

					self.VelocitySensitivity = self.VelocitySensitivity_Orig * self.VelocitySensitivityMult * mult
				end

				function v:recalculateAimSpread()
					local mult = hook.Run("GetSchemaCWAimSpread", self, self.Owner) or 1

					self.AimSpread = self.AimSpread_Orig * self.AimSpreadMult * mult
				end

				function v:recalculateHipSpread()
					local mult = hook.Run("GetSchemaCWHipSpread", self, self.Owner) or 1

					self.HipSpread = self.HipSpread_Orig * self.HipSpreadMult * mult
				end

				function v:recalculateDeployTime()
					local mult = hook.Run("GetSchemaCWDeployTime", self, self.Owner) or 1

					self.DrawSpeed = self.DrawSpeed_Orig * self.DrawSpeedMult * mult
				end

				function v:recalculateReloadSpeed()
					local mult = hook.Run("GetSchemaCWReloadSpeed", self, self.Owner) or 1

					self.ReloadSpeed = self.ReloadSpeed_Orig * self.ReloadSpeedMult * mult
				end

				function v:recalculateMaxSpreadInc()
					local mult = hook.Run("GetSchemaCWMaxSpread", self, self.Owner) or 1

					self.MaxSpreadInc = self.MaxSpreadInc_Orig * self.MaxSpreadIncMult * mult
				end

				-- Generate Items
				local uniqueID = string.Replace(class, prefix, ""):lower()
				local dat = self.gunData[prefix .. uniqueID] or {}

				v.Slot = dat.slot or 2
				local ITEM = nut.item.register(class:lower(), "base_weapons", nil, nil, true)
				ITEM.name = uniqueID
				ITEM.price = dat.price or 4000
				ITEM.iconCam = self.modelCam[v.WorldModel:lower()]
				ITEM.class = prefix .. uniqueID
				ITEM.holsterDrawInfo = dat.holster

				if (dat.holster) then
					ITEM.holsterDrawInfo.model = v.WorldModel
				end

				ITEM.model = v.WorldModel

				local slot = self.slotCategory[v.Slot]
				ITEM.width = 1
				ITEM.height = 1
				ITEM.weaponCategory = slot or "primary"

				function ITEM:onEquipWeapon(client, weapon)
				end

				function ITEM:paintOver(item, w, h)
					local x, y = w - 14, h - 14

					if (item:getData("equip")) then
						surface.SetDrawColor(110, 255, 110, 100)
						surface.DrawRect(x, y, 8, 8)

						x = x - 8*1.6
					end

					if (item:getData("mod")) then
						surface.SetDrawColor(255, 255, 110, 100)
						surface.DrawRect(x, y, 8, 8)
					end
				end

				function ITEM:getDesc()
					if (!self.entity or !IsValid(self.entity)) then
						local text = L("gunInfoDesc", L(v.Primary.Ammo)) .. "\n"

						text = text .. L("gunInfoStat", v.Damage, self.weaponCategory, v.Primary.ClipSize) .. "\n"

						local attText = ""
						local mods = self:getData("mod", {})
						for _, att1 in pairs(mods) do
							attText = attText .. "\n<color=39, 174, 96>" .. L(att1) .. "</color>"
						end

						text = text .. L("gunInfoAttachments", attText)

						return text
					else
						local text = L("gunInfoDesc", L(v.Primary.Ammo))
						return text
					end
				end

				HOLSTER_DRAWINFO[ITEM.class] = ITEM.holsterDrawInfo

				if (CLIENT) then
					if (nut.lang.stored["english"] and nut.lang.stored["korean"]) then
						ITEM.name = v.PrintName 

						nut.lang.stored["english"][prefix .. uniqueID] = v.PrintName 
						nut.lang.stored["korean"][prefix .. uniqueID] = v.PrintName 
					end
				end
			end
		end

		-- attachments
		for k, v in pairs(CustomizableWeaponry.registeredAttachments) do
			local className = v.name
			local printName = v.displayName

			if (className:lower():find("am_")) then
				continue
			end

			local requiresWorkbench = false

			if (className:lower():find("bg_")) then
				requiresWorkbench = true
			end

			local ITEM = nut.item.register(className, nil, nil, nil, true)
			ITEM.name = className
			ITEM.desc = "attachment" .. (requiresWorkbench and "2" or "")
			ITEM.price = 300
			ITEM.model = "models/Items/BoxSRounds.mdl"
			ITEM.width = 1
			ITEM.height = 1
			ITEM.isAttachment = true
			ITEM.category = "Attachments"

			if (CLIENT) then
				if (nut.lang.stored["english"] and nut.lang.stored["korean"]) then
					ITEM.name = className

					nut.lang.stored["english"][className] = printName
					table.Merge(nut.lang.stored["korean"], self.attachmentKorean)
				end
			end

			ITEM.functions.use = {
			name = "Attach",
			tip = "useTip",
			icon = "icon16/wrench.png",
			onRun = function(item)
						local client = item.player
						local char = client:getChar()
						local inv = char:getInv()
						local items = inv:getItems()

						for k, v in pairs(items) do
							if (v.isWeapon) then
								local class = v.class
								local SWEP = weapons.Get(class)


								if (SWEP and (class:find("cw_") or class:find("ma85_"))) then
									local atts = SWEP.Attachments

									local mods = v:getData("mod", {})
									
									if (atts) then		
										local canAttach
										for atcat, data in pairs(atts) do
											for k, name in pairs(data.atts) do
												if (name == item.uniqueID) then
													canAttach = atcat

													break
												end
											end
										end
										
										local slotFilled
										if (atts[canAttach]) then
											for _, att1 in pairs(mods) do
												for _, att2 in pairs(atts[canAttach].atts) do
													if (att1 == att2) then
														slotFilled = true
													end
												end 
											end
										end

										if (slotFilled) then
											client:notifyLocalized("cantAttached")

											return false
										end

										if (!canAttach) then
											client:notifyLocalized("cantAttached")

											return false
										end

										if (!table.HasValue(mods, item.uniqueID)) then
											table.insert(mods, item.uniqueID)

											v:setData("mod", mods)

											local wepon = client:GetActiveWeapon()
											if (IsValid(wepon) and wepon:GetClass() == v.class) then
												wepon:attachSpecificAttachment(item.uniqueID)
											end
											return true
										else
											client:notifyLocalized("alreadyAttached")

											return false
										end
									else
										client:notifyLocalized("notCW")
									end
								end
							end
						end

						client:notifyLocalized("noWeapon")
						return false
					end,
			}

 		end
	end

	-- Reconfigure Customizable Weaponry in here	
	do
		CustomizableWeaponry.customizationMenuKey = "" -- the key we need to press to toggle the customization menu
		CustomizableWeaponry.canDropWeapon = false
		CustomizableWeaponry.enableWeaponDrops = false
		CustomizableWeaponry.quickGrenade.enabled = false
		CustomizableWeaponry.quickGrenade.canDropLiveGrenadeIfKilled = false
		CustomizableWeaponry.quickGrenade.unthrownGrenadesGiveWeapon = false
		CustomizableWeaponry.physicalBulletsEnabled = false
		CustomizableWeaponry.customizationEnabled = false

		hook.Remove("PlayerInitialSpawn", "CustomizableWeaponry.PlayerInitialSpawn")
		hook.Remove("PlayerSpawn", "CustomizableWeaponry.PlayerSpawn")
		hook.Remove("AllowPlayerPickup", "CustomizableWeaponry.AllowPlayerPickup")

		if (CLIENT) then
			local up = Vector(0, 0, -100)
			local shellMins, shellMaxs = Vector(-0.5, -0.15, -0.5), Vector(0.5, 0.15, 0.5)
			local angleVel = Vector(0, 0, 0)

			function CustomizableWeaponry.shells:finishMaking(pos, ang, velocity, soundTime, removeTime)
				velocity = velocity or up
				velocity.x = velocity.x + math.Rand(-5, 5)
				velocity.y = velocity.y + math.Rand(-5, 5)
				velocity.z = velocity.z + math.Rand(-5, 5)
				
				time = time or 0.5
				removetime = removetime or 5
				
				local t = self._shellTable or CustomizableWeaponry.shells:getShell("mainshell") -- default to the 'mainshell' shell type if there is none defined

				local ent = ClientsideModel(t.m, RENDERGROUP_BOTH) 
				ent:SetPos(pos)
				ent:PhysicsInitBox(shellMins, shellMaxs)
				ent:SetAngles(ang + AngleRand())
				ent:SetModelScale((self.ShellScale*.9 or .7), 0)
				ent:SetMoveType(MOVETYPE_VPHYSICS) 
				ent:SetSolid(SOLID_VPHYSICS) 
				ent:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
				
				local phys = ent:GetPhysicsObject()
				phys:SetMaterial("gmod_silent")
				phys:SetMass(10)
				phys:SetVelocity(velocity)
				
				angleVel.x = math.random(-500, 500)
				angleVel.y = math.random(-500, 500)
				angleVel.z = math.random(-500, 500)
				
				phys:AddAngleVelocity(ang:Right() * 100 + angleVel + VectorRand()*50000)

				timer.Simple(time, function()
					if t.s and IsValid(ent) then
						sound.Play(t.s, ent:GetPos())
					end
				end)
				
				SafeRemoveEntityDelayed(ent, removetime)
			end
		end

		do
			CustomizableWeaponry.callbacks:addNew("finishReload", "nutExperience", function(weapon)
				if (CLIENT) then return end

				local owner = weapon.Owner

				if (IsValid(owner) and owner:IsPlayer()) then
					local char = owner:getChar()

					if (char) then
						if (char:getAttrib("gunskill", 0) < 5) then
							char:updateAttrib("gunskill", 0.003)
						end
					end
				end
			end)

			if (CLIENT) then
				netstream.Hook("nutUpdateWeapon", function(weapon) if (weapon and weapon:IsValid() and weapon.recalculateStats) then weapon:recalculateStats() end end)
			end

			function CustomizableWeaponry:hasAttachment(ply, att, lookIn)		
				return true
			end

			CustomizableWeaponry.callbacks:addNew("deployWeapon", "uploadAttachments", function(weapon)
				if (CLIENT) then return end

				timer.Simple(.1, function()
					if (IsValid(weapon)) then
						if (weapon.recalculateStats) then
							weapon:recalculateStats()
							
							netstream.Start(weapon.Owner, "nutUpdateWeapon", weapon)
						end
					end
				end)

				local class = weapon:GetClass():lower()
				local client = weapon.Owner

				if (!client) then return end
				if (weapon.attLoaded) then return end

				local char = client:getChar()

				if (char) then
					local inv = char:getInv()

					for k, v in pairs(inv:getItems()) do
						if (v.class == class) then
							local attachments = v:getData("mod")

							if (attachments) then
								for a, b in pairs(attachments) do
									timer.Simple(0.2, function()
										if (weapon.attachSpecificAttachment) then
											weapon:attachSpecificAttachment(b)
										end
									end)
								end
							end
						end
					end

					weapon.attLoaded = true
				end
			end)
		end
	end
end

function PLUGIN:GetSchemaCWVel(weapon, client)
	return 10
end

if (SERVER) then
	function PLUGIN:OnCharAttribUpdated(client, character, key, value)
		if (!client) then
			client = (character and character:getPlayer())
		end

		if (client and client:IsValid()) then
			local weapon = client:GetActiveWeapon()

			if (value == "gunskill") then
				if (weapon and weapon:IsValid() and weapon.recalculateStats) then
					weapon:recalculateStats()
					
					netstream.Start(client, "nutUpdateWeapon", weapon)
				end
			end
		end
	end

	function PLUGIN:OnCharAttribBoosted(client, character, attribID, boostID, boostAmount)
		if (!client) then
			client = (character and character:getPlayer())
		end

		if (client and client:IsValid()) then
			local weapon = client:GetActiveWeapon()

			if (value == "gunskill") then
				if (weapon and weapon:IsValid() and weapon.recalculateStats) then
					weapon:recalculateStats()
					
					netstream.Start(client, "nutUpdateWeapon", weapon)
				end
			end
		end
	end
end