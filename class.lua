local Players = game:GetService("Players")
local PlayerClass = {} do 
	PlayerClass.__index = PlayerClass
	
	local Utility = require(game.ReplicatedStorage.Shared.Utility)
	local Signal  = require(script.Signal)

	local function getRelativeMoveDirection(humanoid: Humanoid): string?
		local hrp = humanoid.Parent:FindFirstChild("HumanoidRootPart")
		if not hrp then return "None" end

		local moveDir = humanoid.MoveDirection
		if moveDir.Magnitude < 0.1 then
			return "Backward"
		end

		local localDir = hrp.CFrame:VectorToObjectSpace(moveDir)
		local X, Z = localDir.X, localDir.Z

		if math.abs(X) > math.abs(Z) then if X > 0 then return "Right" else return "Left" end
		else if Z < 0 then return "Forward" else return "Backward" end end
	end

	function PlayerClass.new(character: Model)
		local self = setmetatable({}, PlayerClass) do 
			self.character = character
			
			self.weapon = {
				string     = "Scimitar",
				type       = "Sword",
				------------------------
				equipped   = false,
				swingSpeed = 1.02
			}
			
			self.FOV = 70
			self.torsoRotationEnabled = false
			
			self.enum = {
				PLAYERSTATES = {
					["IDLE"]      = 0,
					["BLOCKING"]  = 1,
					["PARRYING"]  = 2,
					["DODGING"]   = 3,
					["STUNNED"]   = 4,
					["PARRIED"]   = 5,
					["ATTACKING"] = 6,
					["ATTACKAIR"] = 7
				},
				DAMAGESTATES = {
					["NONE"]       = 0,
					["SUPERARMOR"] = 1,
					["HYPERARMOR"] = 2,
					["CANCEL"]     = 3
				},
				QUERYTYPES = {
					["PLAYERSTATE"] = 0,
					["DAMAGESTATE"] = 1
				}
			}
			
			self.signals = {
				["M1CANCEL"] = Signal.new()
			}
			
			self.continueBlock = false
			self.combo = 0
			self.lasthit = 0
			
			self.cooldownManager = {cooldowns = {}}
			
			self.controller = {} do
				self.controller.__parent = self
				
				self.controller.active    = true
				self.controller.canAttack = true
				self.controller.canFeint  = false 
				self.controller.canCancel = false
			end
			
			self.stateMachine = {
				parent = self,
				playerState = 0,
				damageState = 0,
				playerStateLast = 0,
				damageStateLast = 0
			}; 
			
			self.stunController = {
				controllers = {}
			} do 
				self.stunController.parent = self
			end
			
			self.input = {
				inputs = {
					["block/parry"] = {
						trueString = "Blocking / Parrying",
						keycode    = Enum.KeyCode.F,
						values     = {
							parryCD = false,
							continueBlock = false
						}
					},
					["sprint"] = {
						trueString = "Sprinting",
						keycode    = Enum.KeyCode.W, 
						values     = {
							INPUT_BUFFER  = 0.3,
							LAST_INPUT    = 0,
							SPRINTING     = false,
							LASTWALKSPEED = 0
						}
					},
					["2"] = {
						trueString = "Skill 2",
						keycode    = Enum.KeyCode.Two,
						values     = { module = "Stomp" }
					},
					["3"] = {
						trueString = "Skill 3",
						keycode    = Enum.KeyCode.Three,
						values     = { module = "Claw" }
					},
					["4"] = {
						trueString = "Skill 4",
						keycode    = Enum.KeyCode.Four,
						values     = { module = "SkullCrusher" }
					}
				},
				__parent = self;
			}
			
			-- [ CONTROLLER ] --
			function self.controller:setJumpingEnabled(v: boolean)
				local humanoid = self.__parent.character:FindFirstChildOfClass("Humanoid")
				if (not v) then
					self.__parent.__recordedJumpHeight = (humanoid::Humanoid).JumpHeight
				end
				humanoid.UseJumpPower = v
				humanoid.JumpHeight = if (v) then self.__parent.__recordedJumpHeight else 0
			end
			
			function self.controller:dash()
				local character = self.__parent.character
				local player    = self.__parent:isPlayer()
				
				local enum = self.__parent.enum

				local humanoidRootPart = character.HumanoidRootPart
				local dirVectors = {
					["Forward"] = humanoidRootPart.CFrame.LookVector * 60,
					["Backward"] = humanoidRootPart.CFrame.LookVector * -60,
					["Left"] = humanoidRootPart.CFrame.RightVector * -60,
					["Right"] = humanoidRootPart.CFrame.RightVector * 60
				}

				if (not self.__parent.stateMachine:assertStates({
					enum.PLAYERSTATES["BLOCKING"],
					enum.PLAYERSTATES["PARRYING"],
					enum.PLAYERSTATES["STUNNED"],
					enum.PLAYERSTATES["ATTACKING"],
					enum.PLAYERSTATES["PARRIED"]
				}, false)) then return end;
				
				if not(self.__parent.controller.active) then return end;
				
				self.__parent.cooldownManager:link("dash", function()
					local Animation = "Dash";

					local dir = getRelativeMoveDirection(character.Humanoid)
					local dirVector = dirVectors[dir] do 
						Animation ..= dir
					end

					self:setJumpingEnabled(false) do 
						self.__parent.stateMachine:set(
							self.__parent.enum.PLAYERSTATES["DODGING"],
							self.__parent.enum.QUERYTYPES["PLAYERSTATE"]
						)
					end

					self.__parent.__replicated.Events.Animation:FireClient(player, "DashAnimations", Animation, {
						weight        = 0.3,
						fadeStart     = 0.3,
						fadeEnd       = 0.1
					}, {}, Enum.AnimationPriority.Action3);

					local attachment = Instance.new("Attachment", humanoidRootPart) do 
						attachment.WorldPosition = (humanoidRootPart::BasePart).AssemblyCenterOfMass
					end

					local linearVelocity = Instance.new("LinearVelocity") do
						local mass = (humanoidRootPart::BasePart).AssemblyMass * 1000
						linearVelocity.Parent = humanoidRootPart
						linearVelocity.VectorVelocity = Vector3.new(dirVector.X, 0, dirVector.Z)
						linearVelocity.Attachment0 = attachment
						linearVelocity.ForceLimitMode = Enum.ForceLimitMode.PerAxis
						linearVelocity.MaxAxesForce = Vector3.new(mass, 0, mass)
					end

					game:GetService("Debris"):AddItem(attachment, 0.25)

					task.delay(0.25, function()
						self:setJumpingEnabled(true) do 
							self.__parent.stateMachine:set(
								self.__parent.enum.PLAYERSTATES["IDLE"],
								self.__parent.enum.QUERYTYPES["PLAYERSTATE"]
							)
						end
					end)
				end, 1.9)
			end
			
			function self.controller:feint() -- [deprecated rn]
				local character = self.__parent.character
				local player    = self.__parent:isPlayer()
				local enum = self.__parent.enum
				local state = self.__parent.stateMachine.playerState
				local feintBuffer = (self.__parent.controller.windup / 1.5)
				local trackData = self.__parent.__replicated.Events.Track
				
				self.__parent.cooldownManager:link("feint", function()
					if (state == enum.PLAYERSTATES["ATTACKING"] and self.__parent.controller.canFeint) then 
						local timePosition = trackData:InvokeClient(player, self.__parent.weapon, "Light" .. self.__parent.combo, "TimePosition")
						local schedule = (feintBuffer - timePosition)
						local function _feint()
							self.__parent.stateMachine:set(
								enum.DAMAGESTATES["CANCEL"],
								enum.QUERYTYPES["DAMAGESTATE"]
							)

							task.wait(0.02, function()
								self.__parent.cooldownManager:remove("mouse1")
							end)
						end
						if (schedule < 0) then 
							_feint()
						else
							task.delay(schedule, _feint)
						end
					end
				end, 1)
			end
			
			function self.controller:jump()
				local character = self.__parent.character
				local humanoid  = character.Humanoid
				
				local assets = game.ReplicatedStorage.Assets
				
				local function isInAir(humanoid: Humanoid): boolean
					local state = humanoid:GetState()
					return state == Enum.HumanoidStateType.Freefall 
						or state == Enum.HumanoidStateType.Jumping
				end
				
				local enum = self.__parent.enum
				if (not self.__parent.stateMachine:assertStates({
					enum.PLAYERSTATES["BLOCKING"],
					enum.PLAYERSTATES["PARRYING"],
					enum.PLAYERSTATES["STUNNED"],
					enum.PLAYERSTATES["ATTACKING"],
					enum.PLAYERSTATES["PARRIED"]
				}, false)) then return end;
				
				self.__parent.cooldownManager:link("doubleJump", function()
					if isInAir(humanoid) then 
						local humanoidRootPart = character.HumanoidRootPart
						
						self:setJumpingEnabled(false) 
						
						local attachment = Instance.new("Attachment", humanoidRootPart) do 
							attachment.WorldPosition = (humanoidRootPart::BasePart).AssemblyCenterOfMass
						end

						local linearVelocity = Instance.new("LinearVelocity") do
							linearVelocity.MaxForce = math.huge
							linearVelocity.VectorVelocity = (humanoidRootPart.CFrame::CFrame).UpVector * 43
							linearVelocity.Attachment0 = attachment
							linearVelocity.Parent = humanoidRootPart
						end
						
						local Effect = assets.Visuals.Particles.DoubleJump
							
						:Clone() do 
							Effect.Parent = humanoidRootPart
							Effect.WorldPosition = humanoidRootPart.Position - Vector3.new(0, 2, 0)
							
							Utility.forEach(Effect:GetChildren(), function(entry)
								(entry::ParticleEmitter):Emit(entry:GetAttribute("EmitCount"))
							end, function(p) return p:IsA("ParticleEmitter") end)
						end
						
						game:GetService("Debris"):AddItem(attachment, 0.25) do 
							self:setJumpingEnabled(true) 
						end
					end
				end, 1.3)
			end
			
			-- [ COOLDOWNS ]
			function self.cooldownManager:link(id: string, callback: Function, duration: int?)
				local registry = self.cooldowns
				if (not registry[id]) then 
					callback()

					registry[id] = true
					if (duration) then
						task.delay(duration, function()
							registry[id] = nil
						end)
					end
				end
			end
			
			function self.cooldownManager:remove(id: string)
				local registry = self.cooldowns
				if (registry[id]) then 
					registry[id] = nil
				end
			end
			
			function self.cooldownManager:instance(id: string, duration: int?)
				local registry = self.cooldowns
				if (registry[id]) then 
					registry[id] = true
					task.delay(duration, function()
						registry[id] = nil
					end)
				end
			end
			
			-- [ STATE MACHINE ] --
			
			function self.stateMachine:assert(p0, n: boolean): boolean
				return if (n) then (p0 == self.parent.enum.QUERYTYPES["PLAYERSTATE"])
					else (p0 == self.parent.enum.QUERYTYPES["DAMAGESTATE"])
			end
			
			function self.stateMachine:update()
				local playerState, damageState = 
					self.playerState, 
					self.damageState
				
				if (not self.parent:conditional("cancel")) then 
					self.parent.signals['M1CANCEL']:Fire()
				end

				local player = self.parent:isPlayer()
				if (player) then 
					local playerGUI = player.PlayerGui :: PlayerGui
					local frame = playerGUI.Screen
					local t0, t1 = frame.StateMachine, frame.DStateMachine;

					(t0::TextLabel).Text = "state: " .. self:get(self.parent.enum.QUERYTYPES["PLAYERSTATE"]);
					(t1::TextLabel).Text = "damage state: " .. self:get(self.parent.enum.QUERYTYPES["DAMAGESTATE"]);
				end
			end
			
			function self.stateMachine:set(state: number, type: number)
				local pS, dS = self.playerState, self.damageState
				if self:assert(type, true) then self.playerState = state
				else self.damageState = state end; 
				
				self:update()
			end	
			
			function self.stateMachine:get(type: number): number
				local pState, dState = self.playerState, self.damageState
				
				if self:assert(type, true) then return pState
				else return dState end
			end
			
			function self.stateMachine:assertStates(states: {number}, n: boolean): boolean
				for index, state in states do 
					if (not n) and (self.playerState == state) then return false
					elseif (n) and (self.playerState ~= state) then return false end
				end
				return true
			end
			
			function self.stateMachine:clear()
				self:set(
					self.parent.enum.PLAYERSTATES["ATTACKING"],
					self.parent.enum.QUERYTYPES["PLAYERSTATE"]
				)
			end
			
			-- [STUN CONTROLLER] --
			
			function self.stunController:getOrCreate(id, t: number)
				if not self.controllers[id] then
					local enum = self.parent.enum
				
					local sub = {time = (t or 0)} 
					
					function sub.instance()
						self.parent.stateMachine:set(
							enum.PLAYERSTATES["STUNNED"],
							enum.QUERYTYPES["PLAYERSTATE"]
						)
					end
					
					function sub.remove()
						self.parent.stateMachine:set(
							enum.PLAYERSTATES["IDLE"],
							enum.QUERYTYPES["PLAYERSTATE"]
						)
					end
					
					self.controllers[id] = sub
					
					if (t) then
						task.delay(t, function()
							self.parent.stateMachine:set(
								enum.PLAYERSTATES["IDLE"],
								enum.QUERYTYPES["PLAYERSTATE"]
							)
						end)
					end
					
					return self.controllers[id]
				else return self.controllers[id]; end
			end
			
			-- [INPUT] -- 
			function self.input:fire(Keycode: Enum.KeyCode, held: boolean)
				if (Keycode == self.inputs["block/parry"].keycode) then 
					local Parry, Block    = "Parry", "Block"
					
					local stateMachine = self.__parent.stateMachine
					local values       = self.inputs["block/parry"].values
					local player       = self.__parent:isPlayer()
					
					local parryCD      = values.parryCD
					
					local trackData = (self.__parent.__replicated.Events.Track :: RemoteFunction)
					
					local function startBlock()
						stateMachine:set(
							self.__parent.enum.PLAYERSTATES["BLOCKING"], -- [ ASSERT BLOCK ACTIVE EVEN IF PARRY ON CD ]
							self.__parent.enum.QUERYTYPES["PLAYERSTATE"]
						)

						self.__parent.__replicated.Events.Animation:FireClient(self.__parent:isPlayer(), self.__parent.weapon, Block, {
							weight        = 0.3,
							fadeStart     = 0.2,
							fadeEnd       = 0.3
						}, {}, Enum.AnimationPriority.Action3);
						
						values.continueBlock = true
					end
					
					local function unblock()
						stateMachine:set(
							self.__parent.enum.PLAYERSTATES["IDLE"], 
							self.__parent.enum.QUERYTYPES["PLAYERSTATE"]
						)

						self.__parent.__replicated.Events.Animation:FireClient(self.__parent:isPlayer(), self.__parent.weapon, Block, {
							toStop = true
						});
					end
					
					if (held) then 						
						if (not parryCD) then
							values.parryCD = true

							local parryWindow = 0.25

							self.__parent.__replicated.Events.Animation:FireClient(self.__parent:isPlayer(), self.__parent.weapon, Parry, {
								weight        = 0.3,
								fadeStart     = 0.3,
								fadeEnd       = 0.1
							}, {}, Enum.AnimationPriority.Action4); do 
								values.continueBlock = false
							end

							local duration = trackData:InvokeClient(player, self.__parent.weapon, Parry, "Length")

							stateMachine:set(
								self.__parent.enum.PLAYERSTATES["PARRYING"],
								self.__parent.enum.QUERYTYPES["PLAYERSTATE"]
							)

							task.delay(parryWindow, function()
								stateMachine:set(
									self.__parent.enum.PLAYERSTATES["BLOCKING"], -- [ DISALLOW GAP IN PARRY TO BLOCK TRANSITION ]
									self.__parent.enum.QUERYTYPES["PLAYERSTATE"]
								)
							end)

							task.delay(duration + 1, function()
								values.parryCD = false
							end)
							
							task.delay(duration - 0.09, startBlock)
						else
							startBlock()
						end
					else
						if (values.continueBlock) then 
							unblock()
						else 
							repeat wait() until 
								values.continueBlock
							
							unblock()
						end
					end
				elseif (Keycode == self.inputs["sprint"].keycode) then 
					local values = self.inputs["sprint"].values
					
					if (values.LASTWALKSPEED == 0) then 
						values.LASTWALKSPEED = self.__parent.character.Humanoid.WalkSpeed
					end
					
					local function setSprintEnabled(value)
						local character = self.__parent.character 
						local humanoid  = character.Humanoid :: Humanoid do 
							values.LASTWALKSPEED = self.__parent.character.Humanoid.WalkSpeed
							values.SPRINTING = value
								
							if (value) then
								self.__parent.character.gameClient.ClientInput.Animation.Value = "Run"
								humanoid.WalkSpeed = 24
							else 
								self.__parent.character.gameClient.ClientInput.Animation.Value = "Walk"
								humanoid.WalkSpeed = 12; do 
									self.__parent:animation(self.__parent.weapon, "Run", { toStop = true })
								end
							end
						end
					end
					
					if (held) then
						local NOW = tick()
						
						if (NOW - values.LAST_INPUT) <= values.INPUT_BUFFER then
							setSprintEnabled(true)
						end

						values.LAST_INPUT = NOW
					elseif (values.SPRINTING) then 
						setSprintEnabled(false)
					end
				end
				-- [SKILLS] -- 
				for index, keyObject in pairs(self.inputs) do 
					if tonumber(index) then 
						if (Keycode == keyObject.keycode) then 
							if not(held) then return end;
							if not(self.__parent:conditional("action")) then return end
							require(script.Skills[keyObject.values.module])(self.__parent)
						end
					end
				end
			end
			
			-- [HIDDEN] --
			self.__replicated = game.ReplicatedStorage
			self.__recordedJumpHeight = 0
		end return (self)
	end
	
	function PlayerClass:incrementCombo()
		self.combo += 1
		if (self.combo > 3) then
			self.combo = 0
		end; 
	end
	
	function PlayerClass:getDamageType()
		return if (self.combo == 3) then 
			"Heavy"
		else nil;
	end
	
	function PlayerClass:isInAir()
		local state = self.character.Humanoid:GetState()
		return state == Enum.HumanoidStateType.Freefall 
			or state == Enum.HumanoidStateType.Jumping
	end
	
	function PlayerClass:animation(class: String, animation: String, params: {any}, priority: Enum.AnimationPriority)
		self.__replicated.Events.Animation:FireClient(self:isPlayer(), class, animation, params, {}, priority);
	end
	
	function PlayerClass:getWeapon()
		for index, object in self.character:GetChildren() do 
			if object:IsA("Model") and object:GetAttribute("isWeapon") then 
				return object
			end
		end
		return nil;
	end
	
	function PlayerClass:isPlayer()
		return Players:GetPlayerFromCharacter(self.character :: Model);
	end
	
	function PlayerClass:conditional(condition)
		return require(script.Conditional)(condition, self)
	end
	
	function PlayerClass:getHitDelta()
		return (tick() - self.lasthit)
	end
	
	function PlayerClass:on(a)
		return self.signals[a]
	end
end return PlayerClass;
