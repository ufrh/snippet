-- Data

local Bounds = workspace.Map["Roads/Structure"].Bounds
local RainBounds = workspace.Map["Roads/Structure"].RainBounds

local Temperature = 70 -- F
local AtmosphericPressure = 101325 -- PAs
local Humidity = 0 -- %

local Lighting = game.Lighting
local RunService = game["Run Service"]
local Clouds = workspace.Terrain.Clouds
local Replicated = game.ReplicatedStorage

local TimeUpdatedCycle = Lighting:GetPropertyChangedSignal("ClockTime")
local Cycle = workspace.WorldConfig.DayLength.Value

local Settings = {
	EvaporationRate = { -- mm/tick
		Min = 1,
		Max = 5
	},
	CondensationRate = { -- gal/tick
		Min = .3,
		Max = .5,
		Constant = 5
	}
}

local StoredEnvData = {
	EvaporatedMolecules = 0, -- mm
	
	CloudCondensationStorage = 0, -- gal,
	CloudCoverage = 0, -- randomized value to increase UX,
	
	AirDensity = 1.2, -- kg/m^3
}

local AtmosphericPressureN = {
	Low = 100914.4,
	High = 101500
}

local CloudCoverageN = {
	Low = 0.1,
	High = 1
}

local Neg = false
local IntervalTick = tick()
local Elapsed = 0

local function lerp(start, finish, alpha)
	return start + (finish - start) * alpha
end

-- Calculations

local AirPressureN, AirPressureNormalizedN = 1013, 1
local SunAmplitude = 0

local Debounce = false
TimeUpdatedCycle:Connect(function()
	local DistanceTillSunrise = Vector3.new(0.9128907918930054, 0.08736539632081985, -0.3987451493740082):Dot(Lighting:GetSunDirection())
	SunAmplitude = DistanceTillSunrise

	local Interval = 0.01
	if Elapsed >= Interval then 
		Elapsed = 0
		
		local FrameHasRain = false
		
		-- Calculate needed data

		local EvaporationFactor = Random.new(tick() * 1000):NextNumber(Settings.EvaporationRate.Min, Settings.EvaporationRate.Max)
		local CondensationFactor = Random.new(tick() * 1000):NextNumber(Settings.CondensationRate.Min, Settings.CondensationRate.Max)
		local CloudDensity = StoredEnvData.AirDensity * (2048/20^3) -- density * studs to cubic meters (N^3)
		local TemperatureKelvin = (Temperature - 32) * 5/9 + 273.15 -- F to K conversion formula (N - 32) * 5/9 + 273.15
		local CloudBase = (Temperature - (Temperature - ((100 - Humidity)/5.))) / 2.5 * 1000 -- Cloud base altitude via dew point and temp
		local AirPressure = (AtmosphericPressure * ((-0.0065 / TemperatureKelvin)*(CloudBase-15000))^(9.80665*0.0289644/8.31432*-0.0065)) / 100 -- pascal -> mb (millibar) conversion (N / 100 = Nmb)
		local PressureNormalized = (AirPressure - 870) / (1083.8 - 870)
		
		-- Set outside variables for reading
		
		AirPressureN = AirPressure
		AirPressureNormalizedN = PressureNormalized
		
		-- Set dynamic variables
		
		StoredEnvData.AirDensity = AirPressure / 287.05 * Temperature
		StoredEnvData.EvaporatedMolecules += EvaporationFactor
		StoredEnvData.CloudCondensationStorage += (CondensationFactor / PressureNormalized) * 0.000264 -- mm -> gal conversion (N × 0.000264 = Ngal)
		
		-- Update cloud properties
		
		Clouds.Cover = math.clamp(StoredEnvData.CloudCondensationStorage, 0, StoredEnvData.CloudCoverage * PressureNormalized / 1.1)
		Clouds.Density = StoredEnvData.CloudCondensationStorage
		Clouds.Color = Color3.new(
			StoredEnvData.CloudCondensationStorage / 1.5, 
			StoredEnvData.CloudCondensationStorage / 1.5, 
			StoredEnvData.CloudCondensationStorage / 1.5
		)
		
		-- Remove evaporated molecules from the stored variable
		
		StoredEnvData.EvaporatedMolecules -= (EvaporationFactor / PressureNormalized * 0.000264)
		
		-- Print data for monitoring activity 
		
		--[ Monitored Data descriptions ]--
		
		-- Used condensation value, 
		-- Reserved evaporation and condensation value, 
		
		-- Air pressure at cloud base altitude as placeholder calculation 
		-- since I cant calculate the value at a 'average' altitude or at any players altitude (server
		-- side limitations)
		
		-- Temperature
		-- Cloud Coverage
		
		print("Final condensation Density - " .. StoredEnvData.CloudCondensationStorage .. " gal")
		print("Condensation Reserve Density - " .. StoredEnvData.EvaporatedMolecules .. " mm")
		print("Air Pressure - " .. AirPressure .. " mb (millibars)")
		print("Cloud Coverage - " .. StoredEnvData.CloudCoverage .. " normalized")
		print("Temperature - " .. Temperature .. " F")
		
		-- Rain 
		if StoredEnvData.CloudCondensationStorage >= 0.1 and not Debounce then 
			Debounce = true
			FrameHasRain = true
			StoredEnvData.CloudCondensationStorage -= Random.new(tick() * 1000):NextNumber(0, 0.1)
			for _,Player in pairs(game.Players:GetPlayers()) do 
				Replicated.Systems.Client:FireClient(Player, "SetRainEnabled", {true})
			end
		end
	end
	Elapsed += (tick() - IntervalTick) 
	IntervalTick = tick()
end)

-- Environment Fluxuations

local steps = 1 / (24 * 60)
local currentStep = 0

local TemperatureNormalized = (70 - 0) / (120 - 0)

local TargetAtmosphericPressure = Random.new(tick() * 1000):NextNumber(AtmosphericPressureN.Low, AtmosphericPressureN.High)
local ConstantAtmosPressure = AtmosphericPressure

local TargetCloudCoverage = Random.new(tick() * 1000):NextNumber(CloudCoverageN.Low, CloudCoverageN.High)
local ConstantCloudCoverage = StoredEnvData.CloudCoverage

RunService.Stepped:Connect(function(t, dt)
	currentStep += steps * dt
	if currentStep > 1 then 
		currentStep = 0 
		
		ConstantAtmosPressure = AtmosphericPressure 
		TargetAtmosphericPressure = Random.new(tick() * 1000):NextNumber(AtmosphericPressureN.Low, AtmosphericPressureN.High)
		
		ConstantCloudCoverage = StoredEnvData.CloudCoverage
		TargetCloudCoverage = Random.new(tick() * 1000):NextNumber(CloudCoverageN.Low, CloudCoverageN.High)
	end
	
	AtmosphericPressure = lerp(ConstantAtmosPressure, TargetAtmosphericPressure, currentStep)
	StoredEnvData.CloudCoverage = lerp(ConstantCloudCoverage, TargetCloudCoverage, currentStep)
	
	Temperature = 70 - (AirPressureNormalizedN - 0.6) / (0.61 - 0.6) * SunAmplitude
end)

-- Raycast Sound System

local function Raycast(Parameters, Visualized)
	local Cast = workspace:Raycast(unpack(Parameters))

	local function VisualizeLine(AD, P1)
		local Visualizer = Instance.new("LineHandleAdornment")
		Visualizer.Adornee     = AD 
		Visualizer.Parent      = AD
		Visualizer.Length      = (AD.Position - P1).Magnitude 
		Visualizer.Thickness   = 3
		Visualizer.Color3      = Color3.new(1, 0, 0)
		Visualizer.AlwaysOnTop = true
	end 

	if Visualized then
		local P0 = Instance.new("Part")
		P0.Parent       = workspace.Loose
		P0.CanCollide   = false 
		P0.Transparency = 1
		P0.Anchored     = true
		P0.Position     = Parameters[1]
		P0.CFrame       = CFrame.lookAt(P0.Position, Cast and Cast.Position or Parameters[4])

		VisualizeLine(P0, Cast and Cast.Position or Parameters[4])

		game.Debris:AddItem(P0, 2)
	end

	return Cast
end


--game.Players.PlayerAdded:Connect(function(v)
--	repeat wait() until v.Character
--	task.spawn(function()
--		while wait() do
--			local RPos = Bounds.CFrame * CFrame.new(
--				Random.new():NextInteger(-(Bounds.Size.X / 2), Bounds.Size.X / 2),
--				Bounds.Size.Y + Random.new():NextInteger(30, 50),
--				Random.new():NextInteger(-(Bounds.Size.Z / 2), Bounds.Size.Z / 2)
--			).Position do 
--				local Cast = Raycast({RPos, (v.Character.HumanoidRootPart.Position - RPos), RaycastParams.new(), v.Character.HumanoidRootPart.Position}, false)
--				if Cast.Instance.Parent == v.Character then 
--					game.ReplicatedStorage.SetWindAuditoryAmplitude:FireClient(v, "Add", 0.1, WindSoundAmplitudeMax)
--					task.delay((0.1 / WindAuditorySimulationRate) + 0.3, function()
--						--game.ReplicatedStorage.SetWindAuditoryAmplitude:FireClient(v, "Sub", 0.1)
--					end)
--				else game.ReplicatedStorage.SetWindAuditoryAmplitude:FireClient(v, "Sub", 0.01, WindSoundAmplitudeMax) end
--			end
--		end
--	end)
--end)


return 0



