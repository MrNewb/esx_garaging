--[[
  _____   _                                 _   _   _
 |_   _| (_)  _ __    _   _   ___          | \ | | | |
   | |   | | | '_ \  | | | | / __|         |  \| | | |    
   | |   | | | | | | | |_| | \__ \         | |\  | | |___ 
   |_|   |_| |_| |_|  \__,_| |___/  _____  |_| \_| |_____|
                                   |_____|
]]--

-- ESX
ESX             = nil

Citizen.CreateThread(function()
	while ESX == nil do
		TriggerEvent('esx:getSharedObject', function(obj) ESX = obj end)
		Citizen.Wait(0)
	end
end)

RegisterNetEvent('esx:playerLoaded')
AddEventHandler('esx:playerLoaded', function(xPlayer)
	while true do
		if ESX == nil then
			Citizen.Wait(1)
		else
			ESX.PlayerData = xPlayer
			break
		end
	end
end)

RegisterNetEvent('esx:setJob')
AddEventHandler('esx:setJob', function(job)
	ESX.PlayerData.job = job
end)

-- Code

local PlayerGarages = {}
local InsideGarage = nil
local MenuOpened = false

function UpdatePlayerGarages()
	ESX.TriggerServerCallback('esx_garaging:GetGarages', function(NewPlayerGarages)
		PlayerGarages = NewPlayerGarages
	end)
end

function CheckGarageOwned(GarageID)
	local Owned = false

	if GarageID == 1 then
		Owned = true
	else
		for Index, CurrentGarage in pairs(PlayerGarages) do
			if CurrentGarage.id == GarageID then
				Owned = true
			end
		end
	end

	return Owned
end

function GetTypeInfo(GottenTypeName)
	local TypeInfo = {}

	for Index, GarageType in pairs(Config.GarageTypes) do
		if GarageType.TypeName == GottenTypeName then
			TypeInfo = GarageType
		end
	end

	return TypeInfo
end

function SpawnVehicle(VehiclesInfo, SpawnCoords, SpawnHeading, Networked, Stored)
	VehicleHash = VehiclesInfo.model
	RequestModel(VehicleHash)

	local TimeWaited = 0

	while not HasModelLoaded(VehicleHash) do
		Citizen.Wait(100)
		TimeWaited = TimeWaited + 100

		if TimeWaited >= 5000 then
			ESX.ShowNotification(Translations[Config.Translation]["SPAWN_ERROR"], false, true, 90)
			break
		end
	end

	local NewVehicle = CreateVehicle(
		VehicleHash, 
		SpawnCoords.x, SpawnCoords.y, SpawnCoords.z,
		SpawnHeading,
		Networked, false
	)
	SetVehicleOnGroundProperly(NewVehicle)
	SetModelAsNoLongerNeeded(VehicleHash)
	WashDecalsFromVehicle(NewVehicle)
	SetVehicleDirtLevel(NewVehicle)
	SetVehicleFixed(NewVehicle)
	SetVehicleUndriveable(NewVehicle,false)
	ESX.Game.SetVehicleProperties(NewVehicle, VehiclesInfo)

	SetModelAsNoLongerNeeded(VehicleHash)

	local VehiclePlate = GetVehicleNumberPlateText(NewVehicle)
	TriggerServerEvent('ls:mainCheck', VehiclePlate, NewVehicle, true)

	if Stored == false then
		SetEntityAlpha(NewVehicle, 51, 0)
		SetEntityCollision(NewVehicle, false, true)
		SetVehicleDoorsLocked(NewVehicle, 2)
	end

	return NewVehicle
end

function LoadGarageVehicles(GarageID, GarageTypeInfo)
	Citizen.Wait(1000)
	ESX.TriggerServerCallback('esx_garaging:GetVehicles', function(PlayerVehicles)
		InsideGarage.Vehicles = {}
		local LoadedVehicles = 0

		for Index, CurrentVehicle in pairs(PlayerVehicles) do
			if CurrentVehicle.garage == GarageID then
				if LoadedVehicles ~= #GarageTypeInfo.TypeLocations then
					local CurrentVehicleEntity = SpawnVehicle(json.decode(CurrentVehicle.vehicle), GarageTypeInfo.TypeLocations[LoadedVehicles + 1].Pos, GarageTypeInfo.TypeLocations[LoadedVehicles + 1].Heading, false, CurrentVehicle.stored)
					FreezeEntityPosition(CurrentVehicleEntity, true)

					table.insert(InsideGarage.Vehicles, #InsideGarage.Vehicles + 1, {VehicleData = CurrentVehicle, VehicleEntity = CurrentVehicleEntity})

					LoadedVehicles = LoadedVehicles + 1
				end
			end
		end
	end)
end

function LeaveGarage()
	FreezeEntityPosition(PlayerPedId(), true)

	BeginTextCommandBusyspinnerOn("LOADING_LEAVE_GARAGE")
	EndTextCommandBusyspinnerOn(4)

	Citizen.Wait(1000)

	for Index, CurrentVehicle in pairs(InsideGarage.Vehicles) do
		if DoesEntityExist(CurrentVehicle.VehicleEntity) then
			DeleteVehicle(CurrentVehicle.VehicleEntity)
		end
	end

	BusyspinnerOff()

	SetEntityCoords(PlayerPedId(), InsideGarage.GarageInfo.DoorPos.x, InsideGarage.GarageInfo.DoorPos.y, InsideGarage.GarageInfo.DoorPos.z, 0.0, 0.0, 0.0, false)

	FreezeEntityPosition(PlayerPedId(), false)
end

function UpdateBlips()
	for Index, CurrentGarage in pairs(Config.Garages) do
		if CheckGarageOwned(Index) then
			SetBlipColour(CurrentGarage.Blip, 25)
		else
			SetBlipColour(CurrentGarage.Blip, 45)
		end
	end
end

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)

		if ESX ~= nil then
			AddTextEntry("LOADING_ENTER_GARAGE", Translations[Config.Translation]["LOADING_ENTER_GARAGE"])
			AddTextEntry("LOADING_LEAVE_GARAGE", Translations[Config.Translation]["LOADING_LEAVE_GARAGE"])
			UpdatePlayerGarages()

			for Index, CurrentGarage in pairs(Config.Garages) do
				local GarageTypeInfo = GetTypeInfo(CurrentGarage.GarageType)

				CurrentGarage["Blip"] = AddBlipForCoord(CurrentGarage.DoorPos.x, CurrentGarage.DoorPos.y, CurrentGarage.DoorPos.z)
				SetBlipSprite(CurrentGarage["Blip"], GarageTypeInfo.TypeBlip.BlipSprite)
				SetBlipDisplay(CurrentGarage["Blip"], 4)
				SetBlipScale(CurrentGarage["Blip"], GarageTypeInfo.TypeBlip.BlipSize)
				SetBlipColour(CurrentGarage["Blip"], 45)
				SetBlipAsShortRange(CurrentGarage["Blip"], true)
				BeginTextCommandSetBlipName("STRING")
				AddTextComponentString(GarageTypeInfo.TypeBlip.BlipInfo)
				EndTextCommandSetBlipName(CurrentGarage["Blip"])
			end

			Citizen.Wait(1000)

			UpdateBlips()

			break
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)

		if ESX ~= nil then
			local PlayerCoords = GetEntityCoords(PlayerPedId())
			local PlayerVehicle = GetVehiclePedIsIn(PlayerPedId())

			for Index, CurrentGarage in pairs(Config.Garages) do
				if PlayerVehicle == 0 then
					if Vdist2(PlayerCoords, CurrentGarage.DoorPos) <= 100 then
						DrawMarker(
							6,
							CurrentGarage.DoorPos.x, CurrentGarage.DoorPos.y, CurrentGarage.DoorPos.z,
							0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
							1.0, 1.0, 1.0,
							0, 255, 0, 155,
							false, true, 2, nil, nil, false
						)

						if CheckGarageOwned(Index) then
							DrawMarker(
								42,
								CurrentGarage.DoorPos.x, CurrentGarage.DoorPos.y, CurrentGarage.DoorPos.z,
								0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
								0.75, 0.75, 0.75,
								0, 255, 0, 155,
								false, true, 2, nil, nil, false
							)

							if Vdist2(PlayerCoords, CurrentGarage.DoorPos) <= 1.5 then
								ESX.ShowHelpNotification(Translations[Config.Translation]["ENTER_GARAGE"], true, false, 1)

								if IsControlJustPressed(1, 51) then
									FreezeEntityPosition(PlayerPedId(), true)

									BeginTextCommandBusyspinnerOn("LOADING_ENTER_GARAGE")
									EndTextCommandBusyspinnerOn(4)

									local GarageTypeInfo = GetTypeInfo(CurrentGarage.GarageType)

									InsideGarage = {}
									InsideGarage["InsideDoor"] = GarageTypeInfo.TypeDoor
									InsideGarage["InsideLaptop"] = GarageTypeInfo.TypeLaptop
									InsideGarage["GarageID"] = Index
									InsideGarage["GarageInfo"] = CurrentGarage

									LoadGarageVehicles(Index, GarageTypeInfo)

									BusyspinnerOff()

									SetEntityCoords(PlayerPedId(), GarageTypeInfo.TypeDoor.x, GarageTypeInfo.TypeDoor.y, GarageTypeInfo.TypeDoor.z, 0.0, 0.0, 0.0, false)

									FreezeEntityPosition(PlayerPedId(), false)
								end
							end
						else
							DrawMarker(
								29,
								CurrentGarage.DoorPos.x, CurrentGarage.DoorPos.y, CurrentGarage.DoorPos.z,
								0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
								1.0, 1.0, 1.0,
								0, 255, 0, 155,
								false, true, 2, nil, nil, false
							)

							if PlayerVehicle == 0 then
								if Vdist2(PlayerCoords, CurrentGarage.DoorPos) <= 1.5 then
									ESX.ShowHelpNotification(Translations[Config.Translation]["BUY_GARAGE"], true, false, 1)

									if IsControlJustPressed(1, 51) and MenuOpened == false then
										MenuOpened = true

										local GarageTypeInfo = GetTypeInfo(CurrentGarage.GarageType)

										ESX.UI.Menu.Open("default", GetCurrentResourceName(), "buy_menu", {
											title = Translations[Config.Translation]["MENU_BUY"],
											align = "bottom-left",
											elements = {
												{ label = Translations[Config.Translation]["YES_BUY"]..' | <span style="color:green;"> €'..GarageTypeInfo.TypePrice..",-</span>", value = "yes" },
												{ label = Translations[Config.Translation]["NO_BUY"], value = "no" }
											}
										},
										function(Data, BuyMenu)
											if Data.current.value == "yes" then
												ESX.TriggerServerCallback('esx_garaging:BuyGarage', function(Status)
													if Status == true then
														ESX.ShowNotification(Translations[Config.Translation]["SUCCES_BUY"], false, true, 90)
														UpdatePlayerGarages()
														UpdateBlips()
													else
														ESX.ShowNotification(Translations[Config.Translation]["MONEY_BUY"]..GarageTypeInfo.TypePrice..",-", false, true, 90)
													end
												end, Index)
											end

											BuyMenu.close()
											MenuOpened = false
										end, 
										function(Data, BuyMenu)
											BuyMenu.close()
											MenuOpened = false
										end)
									end
								end
							end
						end
					end
				else
					if CheckGarageOwned(Index) then
						if Vdist2(PlayerCoords, CurrentGarage.SpawnPos) <= 100 then
							DrawMarker(
								6,
								CurrentGarage.SpawnPos.x, CurrentGarage.SpawnPos.y, CurrentGarage.SpawnPos.z,
								0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
								1.5, 1.5, 1.5,
								255, 0, 0, 155,
								false, true, 2, nil, nil, false
							)

							DrawMarker(
								36,
								CurrentGarage.SpawnPos.x, CurrentGarage.SpawnPos.y, CurrentGarage.SpawnPos.z,
								0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
								1.25, 1.25, 1.25,
								255, 0, 0, 155,
								false, true, 2, nil, nil, false
							)

							if Vdist2(PlayerCoords, CurrentGarage.SpawnPos) <= 2.0 then
								ESX.ShowHelpNotification(Translations[Config.Translation]["ENTER_GARAGE"], true, false, 1)

								if IsControlJustPressed(1, 51) then
									local VehiclePlate = GetVehicleNumberPlateText(PlayerVehicle)

									ESX.TriggerServerCallback('esx_garaging:GetVehicles', function(PlayerVehicles)
										local VehiclesInGarage = 0
										local OwnedVehicle = false
										local CanGoIn = false

										for VehicleIndex, CurrentVehicle in pairs(PlayerVehicles) do
											if CurrentVehicle.garage == Index then
												VehiclesInGarage = VehiclesInGarage + 1

												if CurrentVehicle.plate.." " == VehiclePlate then
													CanGoIn = true
												end
											end

											if CurrentVehicle.plate.." " == VehiclePlate then
												OwnedVehicle = true
											end
										end

										if OwnedVehicle == true then
											local GarageTypeInfo = GetTypeInfo(CurrentGarage.GarageType)

											if VehiclesInGarage < #GarageTypeInfo.TypeLocations and CanGoIn == false then
												CanGoIn = true
											end

											if CanGoIn == true then
												local VehicleProps = ESX.Game.GetVehicleProperties(PlayerVehicle)

												TriggerServerEvent('esx_garaging:SetStored', VehiclePlate, true)
												TriggerServerEvent('esx_garaging:SetGarage', VehiclePlate, Index)
												TriggerServerEvent('esx_garaging:SetProps', VehicleProps)
												DeleteVehicle(PlayerVehicle)

												FreezeEntityPosition(PlayerPedId(), true)

												BeginTextCommandBusyspinnerOn("LOADING_ENTER_GARAGE")
												EndTextCommandBusyspinnerOn(4)

												InsideGarage = {}
												InsideGarage["InsideDoor"] = GarageTypeInfo.TypeDoor
												InsideGarage["InsideLaptop"] = GarageTypeInfo.TypeLaptop
												InsideGarage["GarageID"] = Index
												InsideGarage["GarageInfo"] = CurrentGarage

												LoadGarageVehicles(Index, GarageTypeInfo)

												BusyspinnerOff()

												SetEntityCoords(PlayerPedId(), GarageTypeInfo.TypeDoor.x, GarageTypeInfo.TypeDoor.y, GarageTypeInfo.TypeDoor.z, 0.0, 0.0, 0.0, false)

												FreezeEntityPosition(PlayerPedId(), false)
											else
												ESX.ShowNotification(Translations[Config.Translation]["NO_SPACE"], false, true, 90)
											end
										else
											ESX.ShowNotification(Translations[Config.Translation]["NOT_OWNED"], false, true, 90)
										end
									end)
								end
							end
						end
					end
				end
			end
		end
	end
end)

Citizen.CreateThread(function()
	while true do
		Citizen.Wait(1)

		if InsideGarage ~= nil then
			local PlayerCoords = GetEntityCoords(PlayerPedId())
			local PlayerVehicle = GetVehiclePedIsIn(PlayerPedId())

			if PlayerVehicle == 0 then
				DrawMarker(
					6,
					InsideGarage.InsideDoor.x, InsideGarage.InsideDoor.y, InsideGarage.InsideDoor.z,
					0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
					1.0, 1.0, 1.0,
					0, 255, 0, 155,
					false, true, 2, nil, nil, false
				)

				DrawMarker(
					42,
					InsideGarage.InsideDoor.x, InsideGarage.InsideDoor.y, InsideGarage.InsideDoor.z,
					0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
					0.75, 0.75, 0.75,
					0, 255, 0, 155,
					false, true, 2, nil, nil, false
				)

				DrawMarker(
					6,
					InsideGarage.InsideLaptop.x, InsideGarage.InsideLaptop.y, InsideGarage.InsideLaptop.z,
					0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
					0.75, 0.75, 0.75,
					0, 155, 255, 155,
					false, true, 2, nil, nil, false
				)

				DrawMarker(
					24,
					InsideGarage.InsideLaptop.x, InsideGarage.InsideLaptop.y, InsideGarage.InsideLaptop.z + 0.05,
					0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
					0.45, 0.45, 0.45,
					0, 155, 255, 155,
					false, true, 2, nil, nil, false
				)

				if Vdist2(PlayerCoords, InsideGarage.InsideDoor) <= 1.5 then
					ESX.ShowHelpNotification(Translations[Config.Translation]["LEAVE_GARAGE"], true, false, 1)

					if IsControlJustPressed(1, 51) then
						LeaveGarage()
						InsideGarage = nil
					end
				elseif Vdist2(PlayerCoords, InsideGarage.InsideLaptop) <= 1.5 then
					ESX.ShowHelpNotification(Translations[Config.Translation]["OPEN_LAPTOP"], true, false, 1)

					if IsControlJustPressed(1, 51) and MenuOpened == false then
						MenuOpened = true
						ESX.TriggerServerCallback('esx_garaging:GetVehicles', function(PlayerVehicles)
							local MenuElements = {}

							for Index, CurrentVehicle in pairs(PlayerVehicles) do
								if CurrentVehicle.stored == false and CurrentVehicle.garage == InsideGarage.GarageID then
									local VehicleData = json.decode(CurrentVehicle.vehicle)
									local VehicleName = GetDisplayNameFromVehicleModel(VehicleData.model)

									if VehicleName == nil then
										VehicleName = '<span style="color:red;">'..Translations[Config.Translation]["NAME_LAPTOP"]..'</span>'
									end

									table.insert(MenuElements, #MenuElements + 1, { label = VehicleName.." | "..CurrentVehicle.plate, value = CurrentVehicle.plate })
								end
							end

							ESX.UI.Menu.Open("default", GetCurrentResourceName(), "laptop_menu", {
								title = Translations[Config.Translation]["MENU_LAPTOP"],
								align = "bottom-left",
								elements = MenuElements
							},
							function(Data, LaptopMenu)
								ESX.TriggerServerCallback('esx_garaging:ReturnVehicle', function(Status)
									if Status == true then
										ESX.ShowNotification(Translations[Config.Translation]["SUCCES_LAPTOP"], false, true, 90)

										TriggerServerEvent('esx_garaging:SetStored', Data.current.value, true)

										local GarageTypeInfo = GetTypeInfo(InsideGarage.GarageInfo.GarageType)

										for Index, CurrentVehicle in pairs(InsideGarage.Vehicles) do
											if DoesEntityExist(CurrentVehicle.VehicleEntity) then
												DeleteVehicle(CurrentVehicle.VehicleEntity)
											end
										end

										LoadGarageVehicles(InsideGarage.GarageID, GarageTypeInfo)
									else
										ESX.ShowNotification(Translations[Config.Translation]["MONEY_LAPTOP"]..Config.Laptop.MoneyAmount..",-", false, true, 90)
									end
								end)

								LaptopMenu.close()
								MenuOpened = false
							end, 
							function(Data, LaptopMenu)
								LaptopMenu.close()
								MenuOpened = false
							end)
						end)
					end
				end
			else
				if InsideGarage.Vehicles ~= nil then
					local IsInGarage = false

					for Index, CurrentVehicle in pairs(InsideGarage.Vehicles) do
						if CurrentVehicle.VehicleEntity == PlayerVehicle then
							ESX.ShowHelpNotification(Translations[Config.Translation]["LEAVE_GARAGE"], true, false, 1)

							if IsControlJustPressed(1, 51) then
								LeaveGarage()

								local SpawnedVehicle = SpawnVehicle(json.decode(CurrentVehicle.VehicleData.vehicle), InsideGarage.GarageInfo.SpawnPos, InsideGarage.GarageInfo.SpawnHeading, true)
								TaskWarpPedIntoVehicle(PlayerPedId(), SpawnedVehicle, -1)

								InsideGarage = nil

								TriggerServerEvent('esx_garaging:SetStored', GetVehicleNumberPlateText(SpawnedVehicle), false)
							end
						end
					end
				end
			end
		end
	end
end)
