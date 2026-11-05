-- LocalScript: taruh di StarterPlayer > StarterPlayerScripts
-- Universal R4MEN v7.6 (Speed/Run Fix + Item Scanner v2: live tracking)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

for _, n in ipairs({ "UniversalUrbee", "ControlPanel" }) do
	local old = playerGui:FindFirstChild(n)
	if old then old:Destroy() end
end

-- =====================================================
-- STATE
-- =====================================================
local settings: { [string]: any } = {
	toggleKey = Enum.KeyCode.K,
	floatUpKey = Enum.KeyCode.PageUp,
	floatDownKey = Enum.KeyCode.PageDown,
}

local state: { [string]: boolean } = {
	speed = false,
	jump = false,
	infJump = false,
	float = false,
	noclip = false,
	walkFling = false,
	esp = false,
	freecam = false,
}

local values: { [string]: number } = {
	speed = 50,
	jump = 100,
	freecam = 60,
}

local targetUsername = ""
local fc = { pos = Vector3.zero, yaw = 0, pitch = 0 }
local sliderSetters: { [string]: (number) -> () } = {}
local conns: { RBXScriptConnection } = {}
local unloaded = false

local function track(c: RBXScriptConnection)
	table.insert(conns, c)
	return c
end

-- =====================================================
-- HELPER KARAKTER
-- =====================================================
local function getHum(): Humanoid?
	local char = player.Character
	return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot(): BasePart?
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- =====================================================
-- SPEED & JUMP POWER
-- =====================================================
local saved: { walk: number?, jump: number?, useJump: boolean? } = {}
local restoreSpeed: () -> ()
local restoreJump: () -> ()

-- Seluruh speed engine dibungkus do...end supaya TIDAK menambah jumlah variabel local
-- di level atas (Luau membatasi 200 local per chunk; melewatinya = script gagal dijalankan).
do
	-- Masalah lama: WalkSpeed hanya ditulis di Heartbeat (SETELAH fisika). Banyak game punya
	-- script sprint/anti-cheat yang menulis WalkSpeed di RenderStepped/Stepped (SEBELUM fisika),
	-- sehingga nilai kita tertimpa walau toggle ON.
	-- Perbaikan: (1) tulis ulang di Stepped + Heartbeat + RenderStepped, (2) pantau perubahan
	-- WalkSpeed lalu timpa, (3) fallback gerak berbasis velocity bila game memaksa kecepatan.
	local DEFAULT_WALK = 16
	local trackedHum: Humanoid? = nil
	local speedHumConn: RBXScriptConnection? = nil
	local lastWritten: number? = nil
	local assist = { active = false, slowT = 0 }

	local function speedWanted(): boolean
		return state.speed and not state.freecam
	end

	local function writeWalkSpeed(hum: Humanoid, v: number)
		if hum.WalkSpeed ~= v then
			lastWritten = v
			hum.WalkSpeed = v
		end
	end

	local function resetAssist()
		assist.active = false
		assist.slowT = 0
	end

	restoreSpeed = function()
		resetAssist()
		local hum = getHum()
		if hum then
			hum.WalkSpeed = saved.walk or DEFAULT_WALK
		end
	end

	restoreJump = function()
		local hum = getHum()
		if hum and saved.jump then
			hum.UseJumpPower = saved.useJump == true
			hum.JumpPower = saved.jump
		end
	end

	-- Pasang pantauan pada Humanoid aktif (otomatis ikut saat respawn / karakter diganti game).
	local function bindHumanoid(hum: Humanoid)
		if hum == trackedHum then return end
		trackedHum = hum
		resetAssist()
		lastWritten = nil
		saved.walk = hum.WalkSpeed
		saved.jump = hum.JumpPower
		saved.useJump = hum.UseJumpPower

		if speedHumConn then
			speedHumConn:Disconnect()
		end
		-- track(): koneksi ikut diputus otomatis saat Unload
		speedHumConn = track(hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
			if unloaded then return end
			local cur = hum.WalkSpeed
			if cur == lastWritten then return end -- perubahan dari kita sendiri
			if speedWanted() then
				if cur ~= values.speed then
					saved.walk = cur -- nilai asli game, untuk restore
					writeWalkSpeed(hum, values.speed)
				end
			else
				saved.walk = cur
			end
		end))
	end

	local function enforceSpeed()
		local hum = getHum()
		if not hum then return end
		bindHumanoid(hum)
		if speedWanted() and hum.Health > 0 then
			writeWalkSpeed(hum, values.speed)
		end
	end

	-- Fallback: bila kecepatan nyata tetap jauh di bawah target padahal sedang berjalan di
	-- lantai, game memaksa WalkSpeed. Dorong karakter lewat velocity horizontal.
	local ASSIST_STATES = {
		[Enum.HumanoidStateType.Running] = true,
		[Enum.HumanoidStateType.RunningNoPhysics] = true,
		[Enum.HumanoidStateType.Freefall] = true,
		[Enum.HumanoidStateType.Jumping] = true,
		[Enum.HumanoidStateType.Landed] = true,
	}

	local function assistStep(dt: number)
		if not speedWanted() then
			if assist.active or assist.slowT > 0 then resetAssist() end
			return
		end
		local hum, hrp = getHum(), getRoot()
		if not (hum and hrp) or hum.Health <= 0 or hum.Sit then
			resetAssist()
			return
		end
		if not ASSIST_STATES[hum:GetState()] then return end

		local move = hum.MoveDirection
		if move.Magnitude < 0.1 then
			assist.slowT = 0
			return
		end

		local want = values.speed
		local v = hrp.AssemblyLinearVelocity
		local flat = Vector3.new(v.X, 0, v.Z).Magnitude

		if not assist.active then
			if hum.FloorMaterial ~= Enum.Material.Air and flat < want * 0.75 then
				assist.slowT = assist.slowT + dt
				if assist.slowT >= 0.4 then
					assist.active = true
				end
			else
				assist.slowT = 0
			end
			return
		end

		local dir = move.Unit
		hrp.AssemblyLinearVelocity = Vector3.new(dir.X * want, v.Y, dir.Z * want)
	end

	track(RunService.Stepped:Connect(function()
		enforceSpeed()
	end))

	track(RunService.RenderStepped:Connect(function()
		enforceSpeed()
	end))

	track(RunService.Heartbeat:Connect(function(dt)
		enforceSpeed()
		local hum = getHum()
		if hum and state.jump then
			hum.UseJumpPower = true
			hum.JumpPower = values.jump
		end
		assistStep(dt)
	end))

	track(player.CharacterAdded:Connect(function()
		trackedHum = nil
		resetAssist()
	end))
end

-- =====================================================
-- INFINITE JUMP
-- =====================================================
track(UIS.JumpRequest:Connect(function()
	if not state.infJump or state.freecam then return end
	local hum = getHum()
	if hum then
		hum:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end))

-- =====================================================
-- FLOAT
-- =====================================================
local platform: Part?
local floatY: number?

local function destroyPlatform()
	if platform then
		platform:Destroy()
		platform = nil
	end
	floatY = nil
end

local function ensurePlatform(): Part
	if platform and platform.Parent then
		return platform
	end
	local p = Instance.new("Part")
	p.Name = "UU_FloatPlatform"
	p.Size = Vector3.new(7, 1, 7)
	p.Anchored = true
	p.CanCollide = true
	p.Transparency = 1
	p.Locked = true
	p.Parent = workspace.CurrentCamera or workspace
	platform = p
	return p
end

local FLOAT_SPEED = 24

local function updateFloat(dt: number)
	if state.freecam then return end
	local hum, hrp = getHum(), getRoot()
	if not (hum and hrp) then return end
	local plat = ensurePlatform()

	local feetOffset = (hum.RigType == Enum.HumanoidRigType.R6) and 3 or (hum.HipHeight + hrp.Size.Y / 2)
	local pos = hrp.Position
	local feetY = pos.Y - feetOffset
	local fy: number = floatY or (feetY - 0.15)

	local grounded = hum.FloorMaterial ~= Enum.Material.Air
	local rising = hrp.AssemblyLinearVelocity.Y > 0.5
	local typing = UIS:GetFocusedTextBox() ~= nil
	local upKey, downKey = settings.floatUpKey, settings.floatDownKey
	local upHeld = (not typing) and upKey ~= nil and UIS:IsKeyDown(upKey)
	local downHeld = (not typing) and downKey ~= nil and UIS:IsKeyDown(downKey)
	if upHeld and downHeld then
		upHeld, downHeld = false, false
	end

	if upHeld then
		local v = hrp.AssemblyLinearVelocity
		hrp.AssemblyLinearVelocity = Vector3.new(v.X, FLOAT_SPEED, v.Z)
		fy = math.max(fy, feetY - 0.15)
	elseif downHeld then
		fy -= FLOAT_SPEED * dt
	elseif grounded or rising then
		fy = math.max(fy, feetY - 0.15)
	end

	floatY = fy
	plat.CFrame = CFrame.new(pos.X, fy - 0.5, pos.Z)
end

track(player.CharacterAdded:Connect(function()
	floatY = nil
end))

-- =====================================================
-- NOCLIP & FLING
-- =====================================================
local function noclipStep()
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
		end
	end
end

local function restoreNoclip()
	local char = player.Character
	if not char then return end
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.CanCollide = true
		end
	end
end

-- WalkFling: velocity besar hanya dipasang sesaat (untuk direplikasi ke pemain lain),
-- lalu langsung dikembalikan sebelum fisika lokal berjalan. Jadi karaktermu sendiri
-- tidak ikut terlempar dan kamera tidak rusak (layar hitam putih).
local flingRunning = false

local function startFling()
	if flingRunning then return end
	flingRunning = true
	task.spawn(function()
		while state.walkFling and not unloaded do
			RunService.Heartbeat:Wait()
			local hrp = getRoot()
			if hrp and hrp.Parent and not state.freecam then
				local vel = hrp.AssemblyLinearVelocity
				if vel.Magnitude > 500 then
					vel = Vector3.zero -- pengaman: jangan pernah mewarisi kecepatan ekstrem
				end
				hrp.AssemblyLinearVelocity = vel * 10000 + Vector3.new(0, 10000, 0)
				RunService.RenderStepped:Wait()
				if hrp.Parent then
					hrp.AssemblyLinearVelocity = vel
				end
				RunService.Stepped:Wait()
				if hrp.Parent then
					hrp.AssemblyLinearVelocity = vel + Vector3.new(0, 0.1, 0)
				end
			end
		end
		flingRunning = false
	end)
end

track(RunService.Stepped:Connect(function(_, dt)
	if state.float then
		updateFloat(dt)
	end
	if state.noclip or state.walkFling then
		noclipStep()
	end
end))

-- =====================================================
-- EFEK TOGGLE & RESET ALL
-- =====================================================
local switches: { [string]: { Set: (boolean) -> () } } = {}
local setEsp: (boolean) -> () = function() end
local setFreecam: (boolean) -> () = function() end
local refreshActive: () -> () = function() end
local clearMarkings: () -> () = function() end

local effects: { [string]: (boolean) -> () } = {
	speed = function(on) if not on then restoreSpeed() end end,
	jump = function(on) if not on then restoreJump() end end,
	infJump = function() end,
	float = function(on)
		if on then floatY = nil else destroyPlatform() end
	end,
	noclip = function(on) if not on then restoreNoclip() end end,
	walkFling = function(on)
		if on then startFling() else restoreNoclip() end
	end,
	esp = function(on) setEsp(on) end,
	freecam = function(on) setFreecam(on) end,
}

local function setFeature(key: string, on: boolean)
	state[key] = on
	if switches[key] then
		switches[key].Set(on)
	end
	effects[key](on)
	refreshActive()
end

local function disableAllFeatures()
	for key in pairs(state) do
		state[key] = false
		if switches[key] then
			switches[key].Set(false)
		end
	end
	restoreSpeed()
	restoreJump()
	destroyPlatform()
	restoreNoclip()
	setEsp(false)
	setFreecam(false)
	clearMarkings()
	refreshActive()
end

-- =====================================================
-- WAYPOINT & TP TARGET
-- =====================================================
type Waypoint = { name: string, cf: CFrame }

local MAX_WP = 30
local waypoints: { Waypoint } = {}
local selected = 0
local wpCounter = 0

local toast: (string) -> () = function() end
local rebuildList: () -> () = function() end
local refreshSelection: () -> () = function() end

local function teleportTo(i: number)
	local wp = waypoints[i]
	local char = player.Character
	local hrp = getRoot()
	if not (wp and char and hrp) then
		toast("Karakter belum siap")
		return
	end
	char:PivotTo(wp.cf)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	floatY = nil
	toast("Teleport ke " .. wp.name)
end

local function teleportToUsername(name: string)
	local targetPlayer = nil
	local lowerName = string.lower(name)
	
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local pName = string.lower(p.Name)
			local dName = string.lower(p.DisplayName)
			if string.find(pName, lowerName, 1, true) or string.find(dName, lowerName, 1, true) then
				targetPlayer = p
				break
			end
		end
	end

	if not targetPlayer then
		toast("Pemain tidak ditemukan")
		return
	end

	local targetChar = targetPlayer.Character
	local targetRoot = targetChar and targetChar:FindFirstChild("HumanoidRootPart") :: BasePart?
	local char = player.Character
	local hrp = getRoot()

	if not (targetRoot and char and hrp) then
		toast("Karakter target/kamu belum siap")
		return
	end

	char:PivotTo(targetRoot.CFrame + Vector3.new(0, 3, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	floatY = nil
	toast("Teleport ke " .. targetPlayer.Name)
end

local function waypointCF(): CFrame?
	if state.freecam then
		return CFrame.new(fc.pos) * CFrame.Angles(0, fc.yaw, 0)
	end
	local hrp = getRoot()
	return hrp and hrp.CFrame
end

local function saveWaypoint()
	local cf = waypointCF()
	if not cf then
		toast("Karakter belum siap")
		return
	end
	if #waypoints >= MAX_WP then
		toast("Maksimal " .. tostring(MAX_WP) .. " waypoint")
		return
	end
	wpCounter += 1
	table.insert(waypoints, { name = "Waypoint " .. tostring(wpCounter), cf = cf })
	selected = #waypoints
	rebuildList()
	toast(waypoints[selected].name .. (state.freecam and " tersimpan (posisi free cam)" or " tersimpan"))
end

local function teleportSelected()
	if selected < 1 or not waypoints[selected] then
		toast("Belum ada waypoint terpilih")
		return
	end
	teleportTo(selected)
end

local function cycleWaypoint()
	if #waypoints == 0 then
		toast("Belum ada waypoint")
		return
	end
	selected = (selected % #waypoints) + 1
	refreshSelection()
	toast("Terpilih: " .. waypoints[selected].name)
end

-- =====================================================
-- GUI: THEME & HELPER
-- =====================================================
local WHITE = Color3.new(1, 1, 1)

local T = {
	bg = Color3.fromRGB(12, 12, 19),
	bgTop = Color3.fromRGB(23, 22, 36),
	side = Color3.fromRGB(15, 15, 23),
	card = Color3.fromRGB(24, 24, 36),
	card2 = Color3.fromRGB(31, 30, 47),
	cardSel = Color3.fromRGB(38, 33, 66),
	stroke = Color3.fromRGB(54, 54, 80),
	text = Color3.fromRGB(240, 240, 252),
	sub = Color3.fromRGB(146, 146, 178),
	accent = Color3.fromRGB(135, 98, 255),
	accent2 = Color3.fromRGB(62, 152, 255),
	off = Color3.fromRGB(52, 52, 76),
	danger = Color3.fromRGB(232, 80, 98),
	good = Color3.fromRGB(70, 210, 140),
}

local function new(class: string, props: { [string]: any }, parent: Instance?): any
	local inst: any = Instance.new(class)
	for k, v in pairs(props) do
		inst[k] = v
	end
	-- Kunci font: sebagian game punya script yang menimpa font semua teks di PlayerGui
	-- (hasilnya huruf serif/aneh). Font dicatat SEBELUM objek masuk PlayerGui, lalu dikembalikan
	-- otomatis bila ada yang mengubahnya.
	if class == "TextLabel" or class == "TextButton" or class == "TextBox" then
		local want = inst.FontFace
		local busy = false
		inst:GetPropertyChangedSignal("FontFace"):Connect(function()
			if busy or inst.FontFace == want then return end
			busy = true
			inst.FontFace = want
			busy = false
		end)
	end
	inst.Parent = parent
	return inst
end

local function round(parent: Instance, r: number): any
	return new("UICorner", { CornerRadius = UDim.new(0, r) }, parent)
end

local function stroke(parent: Instance, color: Color3, thickness: number, transparency: number?): any
	return new("UIStroke", {
		Color = color,
		Thickness = thickness,
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function grad(parent: Instance, c0: Color3, c1: Color3, rot: number?): any
	return new("UIGradient", { Color = ColorSequence.new(c0, c1), Rotation = rot or 0 }, parent)
end

local function text(parent: Instance, props: { [string]: any }): any
	local p: { [string]: any } = {
		BackgroundTransparency = 1,
		TextColor3 = T.text,
		Font = Enum.Font.Gotham,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return new("TextLabel", p, parent)
end

local function tween(inst: Instance, props: { [string]: any }, t: number?)
	TweenService:Create(inst, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end

local function lighten(c: Color3): Color3
	return c:Lerp(WHITE, 0.14)
end

local function hover(btn: GuiButton, base: Color3)
	local over = lighten(base)
	btn.MouseEnter:Connect(function()
		tween(btn, { BackgroundColor3 = over }, 0.1)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundColor3 = base }, 0.1)
	end)
end

local function isPointer(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
end

local function isMove(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch
end

local function makeDraggable(handle: GuiObject, target: GuiObject, onClick: (() -> ())?)
	local dragging, moved = false, false
	local startMouse = Vector3.zero
	local startPos = UDim2.new()

	handle.InputBegan:Connect(function(input)
		if isPointer(input) then
			dragging, moved = true, false
			startMouse = input.Position
			startPos = target.Position
		end
	end)

	track(UIS.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			local d = input.Position - startMouse
			if d.Magnitude > 4 then moved = true end
			if moved then
				target.Position = UDim2.new(
					startPos.X.Scale, startPos.X.Offset + d.X,
					startPos.Y.Scale, startPos.Y.Offset + d.Y
				)
			end
		end
	end))

	track(UIS.InputEnded:Connect(function(input)
		if dragging and isPointer(input) then
			dragging = false
			if not moved and onClick then onClick() end
		end
	end))
end

-- =====================================================
-- ESP CHAMS
-- =====================================================
local ESP_SOFT_WHITE = Color3.fromRGB(200, 200, 212)
local ESP_TEXT_SIZE = 12

type EspObj = {
	char: Model,
	hl: Highlight,
	bb: BillboardGui,
	name: TextLabel,
	info: TextLabel,
}

local espFolder: Folder? = nil
local espObjs: { [Player]: EspObj } = {}
local espAccum = 0

local function removeEsp(p: Player)
	local o = espObjs[p]
	if o then
		if o.hl then o.hl:Destroy() end
		if o.bb then o.bb:Destroy() end
		espObjs[p] = nil
	end
end

local function clearEsp()
	for p in pairs(espObjs) do
		removeEsp(p)
	end
	if espFolder then
		espFolder:Destroy()
		espFolder = nil
	end
end

local function buildEsp(p: Player, char: Model)
	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not head then return end

	if not (espFolder and espFolder.Parent) then
		espFolder = new("Folder", { Name = "UU_ESP" }, workspace.CurrentCamera or workspace)
	end

	local hl = new("Highlight", {
		Adornee = char,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillColor = ESP_SOFT_WHITE,
		OutlineColor = ESP_SOFT_WHITE,
		FillTransparency = 0.6,
		OutlineTransparency = 0.15,
	}, espFolder)

	local bb = new("BillboardGui", {
		Adornee = head,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(170, 32),
		StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0),
		MaxDistance = math.huge,
	}, espFolder)

	local nameLbl = text(bb, {
		Size = UDim2.new(1, 0, 0.5, 0),
		Font = Enum.Font.GothamBold,
		TextSize = ESP_TEXT_SIZE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.25,
	})
	local infoLbl = text(bb, {
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0.5, 0),
		Font = Enum.Font.GothamBold,
		TextSize = ESP_TEXT_SIZE - 1,
		TextColor3 = ESP_SOFT_WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeColor3 = Color3.new(0, 0, 0),
		TextStrokeTransparency = 0.25,
		RichText = true,
	})

	espObjs[p] = { char = char, hl = hl, bb = bb, name = nameLbl, info = infoLbl }
end

local function updateEsp(dt: number)
	espAccum += dt
	if espAccum < 0.1 then return end
	espAccum = 0

	local teamsObj = game:GetService("Teams")
	local hasTeams = #teamsObj:GetChildren() > 0
	local myRoot = getRoot()

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local char = p.Character
			local o = espObjs[p]

			if o and (o.char ~= char or not o.char.Parent) then
				removeEsp(p)
				o = nil
			end
			if char and not o then
				buildEsp(p, char)
				o = espObjs[p]
			end

			if o and char then
				local col = ESP_SOFT_WHITE
				if hasTeams and p.Team then
					col = p.TeamColor.Color
				end
				o.hl.FillColor = col
				o.hl.OutlineColor = col
				o.name.Text = p.Name
				o.name.TextColor3 = col

				local hum = char:FindFirstChildOfClass("Humanoid")
				local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?

				local distStr = "?"
				if myRoot and root then
					distStr = tostring(math.floor((myRoot.Position - root.Position).Magnitude + 0.5))
				end

				local hpStr = "-"
				local hpHex = ESP_SOFT_WHITE:ToHex()
				if hum then
					local hp = math.max(0, math.floor(hum.Health + 0.5))
					local ratio = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
					hpStr = tostring(hp)
					hpHex = Color3.fromHSV(ratio * 0.33, 0.6, 1):ToHex()
				end

				o.info.Text = string.format('<font color="#%s">%s HP</font>  %sst', hpHex, hpStr, distStr)
			end
		end
	end
end

setEsp = function(on: boolean)
	if not on then
		clearEsp()
	end
end

track(RunService.Heartbeat:Connect(function(dt)
	if state.esp then
		updateEsp(dt)
	end
end))

track(Players.PlayerRemoving:Connect(function(p)
	removeEsp(p)
end))

-- =====================================================
-- FREE CAM
-- =====================================================
do -- Free Cam dibungkus agar local-nya tidak menghabiskan jatah 200 local
local FC_BIND = "UU_Freecam"
local fcBound = false
local fcRmb = false
local fcPrevType: any = nil
local fcPrevSubject: Instance? = nil
local fcMouseBefore: any = nil
local fcControls: any = nil

local function getControls(): any
	if fcControls then return fcControls end
	local ok, res = pcall(function()
		local ps = player:WaitForChild("PlayerScripts", 2)
		local pm = ps:WaitForChild("PlayerModule", 2)
		return require(pm):GetControls()
	end)
	if ok then fcControls = res end
	return fcControls
end

local function fcStep(dt: number)
	local cam = workspace.CurrentCamera
	if not cam then return end
	if cam.CameraType ~= Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Scriptable
	end

	local rot = CFrame.fromEulerAnglesYXZ(fc.pitch, fc.yaw, 0)
	local move = Vector3.zero
	if UIS:GetFocusedTextBox() == nil then
		if UIS:IsKeyDown(Enum.KeyCode.W) then move += rot.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then move -= rot.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then move += rot.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then move -= rot.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.E) then move += Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.Q) then move -= Vector3.yAxis end
	end
	if move.Magnitude > 0 then
		local sp = values.freecam
		if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then sp *= 3 end
		fc.pos += move.Unit * sp * dt
	end

	if fcRmb and UIS.MouseBehavior ~= Enum.MouseBehavior.LockCurrentPosition then
		UIS.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end

	cam.CFrame = CFrame.new(fc.pos) * rot
end

local function fcLook(d: Vector2)
	fc.yaw -= d.X * 0.004
	fc.pitch = math.clamp(fc.pitch - d.Y * 0.004, -1.5, 1.5)
end

track(UIS.InputBegan:Connect(function(input, processed)
	if state.freecam and not processed and input.UserInputType == Enum.UserInputType.MouseButton2 then
		fcRmb = true
		fcMouseBefore = UIS.MouseBehavior
	end
end))

track(UIS.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and fcRmb then
		fcRmb = false
		UIS.MouseBehavior = fcMouseBefore or Enum.MouseBehavior.Default
	end
end))

track(UIS.InputChanged:Connect(function(input, processed)
	if not state.freecam then return end
	if input.UserInputType == Enum.UserInputType.MouseMovement then
		if fcRmb then fcLook(input.Delta) end
	elseif input.UserInputType == Enum.UserInputType.Touch and not processed then
		fcLook(input.Delta)
	end
end))

setFreecam = function(on: boolean)
	local cam = workspace.CurrentCamera
	local hrp = getRoot()
	local hum = getHum()

	if on then
		if fcBound or not cam then return end
		fcPrevType = cam.CameraType
		fcPrevSubject = cam.CameraSubject

		local cf = cam.CFrame
		local rx, ry = cf:ToEulerAnglesYXZ()
		fc.pitch = math.clamp(rx, -1.5, 1.5)
		fc.yaw = ry
		fc.pos = cf.Position

		if hrp then hrp.Anchored = true end
		if hum then hum.PlatformStand = true end

		local c = getControls()
		if c then pcall(function() c:Disable() end) end

		cam.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(FC_BIND, Enum.RenderPriority.Camera.Value + 1, fcStep)
		fcBound = true
	else
		if fcBound then
			RunService:UnbindFromRenderStep(FC_BIND)
			fcBound = false
		end

		if hrp then hrp.Anchored = false end
		if hum then hum.PlatformStand = false end

		if fcRmb then
			fcRmb = false
			UIS.MouseBehavior = fcMouseBefore or Enum.MouseBehavior.Default
		end
		if fcControls then
			pcall(function() fcControls:Enable() end)
		end
		if cam then
			if fcPrevSubject and fcPrevSubject.Parent then
				cam.CameraSubject = fcPrevSubject
			else
				local currentHum = getHum()
				if currentHum then cam.CameraSubject = currentHum end
			end
			cam.CameraType = fcPrevType or Enum.CameraType.Custom
		end
	end
end
end -- tutup do (Free Cam)

-- =====================================================
-- GUI: KERANGKA UTAMA
-- =====================================================
local MIN_W, MIN_H, MAX_W, MAX_H = 460, 360, 820, 800
local SIDE_W = 112

local function viewport(): Vector2
	local cam = workspace.CurrentCamera
	return cam and cam.ViewportSize or Vector2.new(1280, 720)
end

local function clampSize(w: number, h: number): (number, number)
	local vs = viewport()
	local maxW = math.min(MAX_W, vs.X - 20)
	local maxH = math.min(MAX_H, vs.Y - 20)
	return math.clamp(w, math.min(MIN_W, maxW), maxW), math.clamp(h, math.min(MIN_H, maxH), maxH)
end

local panelW, panelH = clampSize(520, 450)

local gui = new("ScreenGui", {
	Name = "UniversalUrbee",
	ResetOnSpawn = false,
	DisplayOrder = 999,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, playerGui)

local modal = new("TextButton", {
	Name = "MouseFree",
	Size = UDim2.fromOffset(1, 1),
	BackgroundTransparency = 1,
	Text = "",
	Modal = false,
}, gui)

local main = new("Frame", {
	Name = "Main",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(panelW, panelH),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, gui)
round(main, 16)
grad(main, T.bgTop, T.bg, 90)
local mainStroke = stroke(main, WHITE, 1.5, 0.35)
grad(mainStroke, T.accent, T.accent2, 45)

-- Header
local header = new("Frame", {
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 54),
	BackgroundTransparency = 1,
}, main)

local logo = new("Frame", {
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.fromOffset(30, 30),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, header)
round(logo, 9)
grad(logo, T.accent, T.accent2, 45)
text(logo, {
	Text = "U",
	Font = Enum.Font.GothamBold,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
})

local title = text(header, {
	Text = "Universal R4MEN",
	Font = Enum.Font.GothamBold,
	TextSize = 16,
	TextColor3 = WHITE,
	Position = UDim2.fromOffset(54, 9),
	Size = UDim2.new(1, -216, 0, 20),
})
grad(title, WHITE, Color3.fromRGB(196, 176, 255), 0)

local subtitle = text(header, {
	TextSize = 11,
	TextColor3 = T.sub,
	Position = UDim2.fromOffset(54, 30),
	Size = UDim2.new(1, -216, 0, 14),
})

local pill = new("Frame", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -84, 0.5, 0),
	Size = UDim2.fromOffset(76, 24),
	BackgroundColor3 = T.card,
	BorderSizePixel = 0,
}, header)
round(pill, 12)
stroke(pill, T.stroke, 1, 0.4)
local pillDot = new("Frame", {
	Position = UDim2.fromOffset(10, 9),
	Size = UDim2.fromOffset(6, 6),
	BackgroundColor3 = T.off,
	BorderSizePixel = 0,
}, pill)
round(pillDot, 3)
local pillText = text(pill, {
	Text = "0 aktif",
	TextSize = 11,
	Font = Enum.Font.GothamMedium,
	TextColor3 = T.sub,
	Position = UDim2.fromOffset(22, 0),
	Size = UDim2.new(1, -26, 1, 0),
})

local function headerButton(txt: string, xOffset: number, hoverColor: Color3)
	local b = new("TextButton", {
		Size = UDim2.fromOffset(26, 26),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, xOffset, 0.5, 0),
		BackgroundColor3 = T.card,
		Text = txt,
		TextColor3 = T.sub,
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		AutoButtonColor = false,
	}, header)
	round(b, 13)
	b.MouseEnter:Connect(function()
		tween(b, { BackgroundColor3 = hoverColor, TextColor3 = WHITE }, 0.1)
	end)
	b.MouseLeave:Connect(function()
		tween(b, { BackgroundColor3 = T.card, TextColor3 = T.sub }, 0.1)
	end)
	return b
end

local minBtn = headerButton("-", -42, T.accent)
local hideBtn = headerButton("x", -12, T.danger)

local divider = new("Frame", {
	Position = UDim2.fromOffset(14, 54),
	Size = UDim2.new(1, -28, 0, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
}, main)
new("UIGradient", {
	Color = ColorSequence.new(T.accent, T.accent2),
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	}),
}, divider)

makeDraggable(header, main)

-- =====================================================
-- BUBBLE & UI STATE CONTROL (DI-SET DI AWAL SUPAYA TIDAK ERROR)
-- =====================================================
local BUBBLE = 54

local bubble = new("TextButton", {
	Name = "Bubble",
	Size = UDim2.fromOffset(BUBBLE, BUBBLE),
	Position = UDim2.fromOffset(16, 16),
	BackgroundColor3 = T.bg,
	Text = "",
	AutoButtonColor = false,
	Visible = false,
	ZIndex = 5,
}, gui)
round(bubble, BUBBLE / 2)
local bubbleStroke = stroke(bubble, WHITE, 2, 0.1)
grad(bubbleStroke, T.accent, T.accent2, 45)

local bubbleBg = new("Frame", {
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = WHITE,
	BorderSizePixel = 0,
	ZIndex = 5,
}, bubble)
round(bubbleBg, BUBBLE / 2)
grad(bubbleBg, T.accent, T.accent2, 45)

text(bubble, {
	Text = "UU",
	Font = Enum.Font.GothamBold,
	TextSize = 17,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 6,
})

local badge = new("Frame", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, 3, 0, -3),
	Size = UDim2.fromOffset(20, 20),
	BackgroundColor3 = T.good,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 7,
}, bubble)
round(badge, 10)
stroke(badge, T.bg, 2, 0)
local badgeText = text(badge, {
	Font = Enum.Font.GothamBold,
	TextSize = 11,
	TextColor3 = Color3.fromRGB(10, 34, 22),
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 8,
})

local setUIState: (string) -> () = function() end
local uiState = "open"
local isOpen = true
local unloadFn: (() -> ())? = nil -- diisi setelah unload() didefinisikan (tombol X memakainya)
local mouseConn: RBXScriptConnection? = nil

local function placeBubbleAtPanel()
	local ap = main.AbsolutePosition - gui.AbsolutePosition
	local vs = gui.AbsoluteSize
	local x = math.clamp(ap.X + 6, 0, math.max(0, vs.X - BUBBLE))
	local y = math.clamp(ap.Y + 6, 0, math.max(0, vs.Y - BUBBLE))
	bubble.Position = UDim2.fromOffset(x, y)
end

local function placePanelAtBubble()
	local bp = bubble.AbsolutePosition - gui.AbsolutePosition
	local vs = gui.AbsoluteSize
	local x = math.clamp(bp.X - 6, 0, math.max(0, vs.X - panelW))
	local y = math.clamp(bp.Y - 6, 0, math.max(0, vs.Y - panelH))
	main.Position = UDim2.fromOffset(x + panelW / 2, y + panelH / 2)
end

local function isRmbDown(): boolean
	return UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
end

-- Kunci kamera: JANGAN menimpa MouseBehavior saat klik kanan ditahan.
-- Kamera bawaan Roblox (dan freecam) memakai LockCurrentPosition selama klik kanan + geser;
-- kode lama memaksa Default tiap frame sehingga rotasi kamera mati saat UI terbuka.
local function updateMouseLock()
	if mouseConn then
		mouseConn:Disconnect()
		mouseConn = nil
	end

	if uiState == "open" then
		UIS.MouseIconEnabled = true
		mouseConn = track(RunService.RenderStepped:Connect(function()
			if uiState ~= "open" then return end
			UIS.MouseIconEnabled = true
			-- Hanya bebaskan kursor dari mode kunci-tengah (first person / shift lock),
			-- dan hanya bila pemain sedang TIDAK memutar kamera dengan klik kanan.
			if not isRmbDown() and UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
				UIS.MouseBehavior = Enum.MouseBehavior.Default
			end
		end))
	elseif UIS.MouseBehavior == Enum.MouseBehavior.LockCenter and not isRmbDown() then
		UIS.MouseBehavior = Enum.MouseBehavior.Default
	end
end

setUIState = function(s: string)
	local prev = uiState
	uiState = s
	local nowOpen = (s == "open")

	if s == "mini" and prev == "open" then
		placeBubbleAtPanel()
	elseif nowOpen and prev == "mini" then
		placePanelAtBubble()
	end

	main.Visible = nowOpen
	bubble.Visible = (s == "mini")
	modal.Modal = false -- Modal=true memblokir rotasi kamera; kursor sudah ditangani updateMouseLock

	if nowOpen and not isOpen then
		main.Size = UDim2.fromOffset(panelW * 0.94, panelH * 0.94)
		tween(main, { Size = UDim2.fromOffset(panelW, panelH) }, 0.18)
	end
	isOpen = nowOpen

	updateMouseLock()
end

makeDraggable(bubble, bubble, function() setUIState("open") end)

minBtn.MouseButton1Click:Connect(function() 
	setUIState("mini") 
end)

hideBtn.MouseButton1Click:Connect(function()
	-- Tombol X = tutup sepenuhnya (unload). Untuk sekadar menyembunyikan UI pakai keybind K
	-- atau tombol "-" (minimize).
	if unloadFn then
		unloadFn()
	else
		disableAllFeatures()
		setUIState("hidden")
	end
end)

-- =====================================================
-- TOAST
-- =====================================================
refreshActive = function()
	local n = 0
	for _, v in pairs(state) do
		if v then n += 1 end
	end
	pillText.Text = tostring(n) .. " aktif"
	pillDot.BackgroundColor3 = n > 0 and T.good or T.off
	badge.Visible = n > 0
	badgeText.Text = tostring(n)
end

local toastFrame = new("Frame", {
	Name = "Toast",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, -30),
	Size = UDim2.fromOffset(0, 36),
	AutomaticSize = Enum.AutomaticSize.X,
	BackgroundColor3 = T.bg,
	BackgroundTransparency = 0.04,
	BorderSizePixel = 0,
	Visible = false,
	ZIndex = 20,
}, gui)
round(toastFrame, 18)
local toastStroke = stroke(toastFrame, WHITE, 1.5, 0.15)
grad(toastStroke, T.accent, T.accent2, 0)
new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 18) }, toastFrame)

local toastLabel = text(toastFrame, {
	Size = UDim2.new(0, 0, 1, 0),
	AutomaticSize = Enum.AutomaticSize.X,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Center,
	ZIndex = 21,
})

local toastId = 0
toast = function(msg: string)
	toastId += 1
	local id = toastId
	toastLabel.Text = msg
	toastFrame.Position = UDim2.new(0.5, 0, 0, -30)
	toastFrame.Visible = true
	tween(toastFrame, { Position = UDim2.new(0.5, 0, 0, 14) }, 0.2)
	task.delay(1.8, function()
		if id == toastId and not unloaded then
			toastFrame.Visible = false
		end
	end)
end

-- =====================================================
-- GUI: SIDEBAR TAB & HALAMAN
-- =====================================================
local pages: { [string]: ScrollingFrame } = {}
local tabButtons: { [string]: any } = {}
local currentTab = ""

local sidebar = new("Frame", {
	Position = UDim2.fromOffset(12, 62),
	Size = UDim2.new(0, SIDE_W, 1, -74),
	BackgroundColor3 = T.side,
	BorderSizePixel = 0,
}, main)
round(sidebar, 12)
stroke(sidebar, T.stroke, 1, 0.6)

local tabList = new("ScrollingFrame", {
	Position = UDim2.fromOffset(6, 6),
	Size = UDim2.new(1, -12, 1, -12),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
}, sidebar)
new("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabList)

local pageHolder = new("Frame", {
	Position = UDim2.fromOffset(SIDE_W + 24, 62),
	Size = UDim2.new(1, -(SIDE_W + 36), 1, -74),
	BackgroundTransparency = 1,
}, main)

local function newPage(name: string): ScrollingFrame
	local p = new("ScrollingFrame", {
		Name = name,
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.stroke,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Visible = false,
	}, pageHolder)
	new("UIListLayout", {
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, p)
	new("UIPadding", { PaddingRight = UDim.new(0, 8), PaddingBottom = UDim.new(0, 14) }, p)
	pages[name] = p
	return p
end

local function setScrolling(on: boolean)
	for _, p in pairs(pages) do
		p.ScrollingEnabled = on
	end
end

local function selectTab(name: string)
	currentTab = name
	for n, page in pairs(pages) do
		if n == name then
			page.Position = UDim2.fromOffset(0, 10)
			page.Visible = true
			tween(page, { Position = UDim2.fromOffset(0, 0) }, 0.18)
		else
			page.Visible = false
		end
	end
	for n, t in pairs(tabButtons) do
		local active = (n == name)
		tween(t.act, { BackgroundTransparency = active and 0 or 1 }, 0.15)
		tween(t.lbl, { TextColor3 = active and WHITE or T.sub }, 0.15)
		tween(t.dot, { BackgroundColor3 = active and WHITE or T.off }, 0.15)
		if active then
			tween(t.btn, { BackgroundTransparency = 1 }, 0.1)
		end
	end
end

local movementPage = newPage("Movement")
local physicsPage = newPage("Physics")
local teleportPage = newPage("Teleport")
local configPage = newPage("Config")
local settingsPage = newPage("Settings")

for i, name in ipairs({ "Movement", "Physics", "Teleport", "Config", "Settings" }) do
	local b = new("TextButton", {
		LayoutOrder = i,
		Size = UDim2.new(1, 0, 0, 38),
		BackgroundColor3 = T.card,
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
	}, tabList)
	round(b, 10)

	local act = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, b)
	round(act, 10)
	grad(act, T.accent, T.accent2, 0)

	local dotI = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(6, 6),
		BackgroundColor3 = T.off,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, b)
	round(dotI, 3)

	local lbl = text(b, {
		Text = name,
		Font = Enum.Font.GothamMedium,
		TextSize = 13,
		TextColor3 = T.sub,
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -30, 1, 0),
		ZIndex = 2,
	})

	tabButtons[name] = { btn = b, act = act, dot = dotI, lbl = lbl }

	b.MouseEnter:Connect(function()
		if currentTab ~= name then
			tween(b, { BackgroundTransparency = 0.35 }, 0.1)
		end
	end)
	b.MouseLeave:Connect(function()
		tween(b, { BackgroundTransparency = 1 }, 0.1)
	end)
	b.MouseButton1Click:Connect(function() selectTab(name) end)
end

-- =====================================================
-- GUI: GRIP RESIZE
-- =====================================================
local grip = new("TextButton", {
	Name = "ResizeGrip",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -3, 1, -3),
	Size = UDim2.fromOffset(22, 22),
	BackgroundTransparency = 1,
	Text = "",
	AutoButtonColor = false,
	ZIndex = 10,
}, main)

for row = 0, 2 do
	for col = 0, 2 - row do
		local d = new("Frame", {
			Position = UDim2.fromOffset(17 - col * 5, 17 - row * 5),
			Size = UDim2.fromOffset(3, 3),
			BackgroundColor3 = T.sub,
			BorderSizePixel = 0,
			ZIndex = 10,
		}, grip)
		round(d, 2)
	end
end

do
	local resizing = false
	local startMouse = Vector3.zero
	local startW, startH = panelW, panelH
	local startPos = UDim2.new()

	grip.InputBegan:Connect(function(input)
		if isPointer(input) then
			resizing = true
			startMouse = input.Position
			startW, startH = panelW, panelH
			startPos = main.Position
		end
	end)

	track(UIS.InputChanged:Connect(function(input)
		if resizing and isMove(input) then
			local d = input.Position - startMouse
			local w, h = clampSize(startW + d.X, startH + d.Y)
			panelW, panelH = w, h
			main.Size = UDim2.fromOffset(w, h)
			main.Position = UDim2.new(
				startPos.X.Scale, startPos.X.Offset + (w - startW) / 2,
				startPos.Y.Scale, startPos.Y.Offset + (h - startH) / 2
			)
		end
	end))

	track(UIS.InputEnded:Connect(function(input)
		if isPointer(input) then
			resizing = false
		end
	end))
end

-- =====================================================
-- GUI: KOMPONEN
-- =====================================================
local function makeCard(parent: Instance, height: number, order: number): any
	local card = new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, parent)
	round(card, 12)
	grad(card, T.card2, T.card, 90)
	stroke(card, T.stroke, 1, 0.45)
	return card
end

local function cardGlow(card: Instance): (boolean) -> ()
	local s = card:FindFirstChildOfClass("UIStroke")
	return function(on: boolean)
		if s then
			tween(s, { Color = on and T.accent or T.stroke, Transparency = on and 0.05 or 0.45 }, 0.15)
		end
	end
end

local function sectionLabel(parent: Instance, order: number, txt: string)
	return text(parent, {
		LayoutOrder = order,
		Text = string.upper(txt),
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = T.sub,
		Size = UDim2.new(1, 0, 0, 16),
	})
end

local function makeSwitch(parent: Instance, position: UDim2, initial: boolean, callback: (boolean) -> (), visual: ((boolean) -> ())?)
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = position,
		Size = UDim2.fromOffset(46, 26),
		BackgroundColor3 = T.off,
		Text = "",
		AutoButtonColor = false,
	}, parent)
	round(btn, 13)

	local fill = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = WHITE,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 1,
	}, btn)
	round(fill, 13)
	grad(fill, T.accent, T.accent2, 0)

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 3, 0.5, 0),
		Size = UDim2.fromOffset(20, 20),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, btn)
	round(knob, 10)

	local on = initial

	local function render(animate: boolean)
		local fillT = on and 0 or 1
		local p = on and UDim2.new(0, 23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0)
		if animate then
			tween(fill, { BackgroundTransparency = fillT }, 0.15)
			tween(knob, { Position = p }, 0.15)
		else
			fill.BackgroundTransparency = fillT
			knob.Position = p
		end
		if visual then visual(on) end
	end

	btn.MouseButton1Click:Connect(function()
		on = not on
		render(true)
		callback(on)
	end)

	render(false)

	return {
		Set = function(v: boolean)
			on = v
			render(true)
		end,
	}
end

local function addToggleCard(page: Instance, order: number, title: string, desc: string, key: string)
	local card = makeCard(page, 76, order)
	text(card, {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -84, 0, 18),
	})
	local descLabel = text(card, {
		Text = desc,
		TextSize = 11,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 30),
		Size = UDim2.new(1, -84, 0, 40),
	})
	switches[key] = makeSwitch(card, UDim2.new(1, -14, 0.5, 0), false, function(on)
		state[key] = on
		effects[key](on)
		refreshActive()
	end, cardGlow(card))
	return descLabel
end

local function addSliderCard(page: Instance, order: number, title: string, hint: string, key: string, min: number, max: number, hardMax: number)
	local card = makeCard(page, 100, order)
	text(card, {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.new(1, -84, 0, 18),
	})
	text(card, {
		Text = hint,
		TextSize = 11,
		TextColor3 = T.sub,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, 30),
		Size = UDim2.new(1, -84, 0, 14),
	})
	switches[key] = makeSwitch(card, UDim2.new(1, -14, 0, 25), false, function(on)
		state[key] = on
		effects[key](on)
		refreshActive()
	end, cardGlow(card))

	local hit = new("Frame", {
		Position = UDim2.fromOffset(14, 58),
		Size = UDim2.new(1, -100, 0, 28),
		BackgroundTransparency = 1,
	}, card)

	local bar = new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(1, 0, 0, 8),
		BackgroundColor3 = T.off,
		BorderSizePixel = 0,
	}, hit)
	round(bar, 4)

	local fill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
	}, bar)
	round(fill, 4)
	grad(fill, T.accent, T.accent2, 0)

	local knob = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 2,
	}, bar)
	round(knob, 9)
	stroke(knob, T.accent, 2.5, 0)

	local box = new("TextBox", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0, 72),
		Size = UDim2.fromOffset(64, 28),
		BackgroundColor3 = T.bg,
		Text = tostring(values[key]),
		TextColor3 = T.text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, card)
	round(box, 8)
	stroke(box, T.stroke, 1, 0.3)

	local function setValue(v: number)
		v = math.clamp(math.floor(v + 0.5), 1, hardMax)
		values[key] = v
		box.Text = tostring(v)
		local a = math.clamp((v - min) / (max - min), 0, 1)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
	end

	setValue(values[key])
	sliderSetters[key] = setValue

	box.FocusLost:Connect(function()
		setValue(tonumber(box.Text) or values[key])
	end)

	local dragging = false
	local function fromInput(input: InputObject)
		local rel = (input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
		setValue(min + math.clamp(rel, 0, 1) * (max - min))
	end

	hit.InputBegan:Connect(function(input)
		if isPointer(input) then
			dragging = true
			setScrolling(false)
			fromInput(input)
		end
	end)
	track(UIS.InputChanged:Connect(function(input)
		if dragging and isMove(input) then
			fromInput(input)
		end
	end))
	track(UIS.InputEnded:Connect(function(input)
		if dragging and isPointer(input) then
			dragging = false
			setScrolling(true)
		end
	end))
end

local function makeButton(parent: Instance, order: number, txt: string, color: Color3, height: number?): any
	local b = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, height or 40),
		BackgroundColor3 = color,
		Text = txt,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		AutoButtonColor = false,
	}, parent)
	round(b, 10)
	return b
end

-- =====================================================
-- GUI: HALAMAN MOVEMENT & PHYSICS
-- =====================================================
sectionLabel(movementPage, 0, "Kecepatan & lompat")
addSliderCard(movementPage, 1, "Speed", "Bawaan Roblox: 16", "speed", 16, 1500, 2000)
addSliderCard(movementPage, 2, "Jump Power", "Bawaan Roblox: 50", "jump", 50, 300, 1000)
addToggleCard(movementPage, 3, "Infinite Jump", "Lompat berkali-kali di udara.", "infJump")

sectionLabel(physicsPage, 0, "Fisika & visual")
local floatDesc = addToggleCard(physicsPage, 1, "Float", "", "float")
addToggleCard(physicsPage, 2, "Noclip", "Tembus tembok dan objek.", "noclip")
addToggleCard(physicsPage, 3, "WalkFling",
	"Otomatis tembus tembok. Pemain lain terpental saat menyentuhmu.", "walkFling")
addToggleCard(physicsPage, 4, "ESP Chams",
	"Siluet pemain tembus tembok + username, darah, jarak. Warna ikut tim; tanpa tim: putih lembut.", "esp")

-- =====================================================
-- GUI: HALAMAN TELEPORT & ITEM DETECTOR
-- =====================================================
sectionLabel(teleportPage, 0, "Teleport ke Pemain")

do

local tpTargetCard = makeCard(teleportPage, 76, 0)
text(tpTargetCard, {
	Text = "TP to Player",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(1, -84, 0, 18),
})

local tpTargetInput = new("TextBox", {
	Position = UDim2.fromOffset(14, 34),
	Size = UDim2.new(1, -114, 0, 30),
	BackgroundColor3 = T.bg,
	Text = "",
	PlaceholderText = "Ketik huruf nama (mis: asel)",
	PlaceholderColor3 = T.sub,
	TextColor3 = T.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, tpTargetCard)
round(tpTargetInput, 8)
stroke(tpTargetInput, T.stroke, 1, 0.3)

local tpTargetBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0, 49),
	Size = UDim2.fromOffset(80, 30),
	BackgroundColor3 = T.accent2,
	Text = "TP",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	AutoButtonColor = false,
}, tpTargetCard)
round(tpTargetBtn, 8)
hover(tpTargetBtn, T.accent2)

tpTargetBtn.MouseButton1Click:Connect(function()
	local nameQuery = string.match(tpTargetInput.Text, "^%s*(.-)%s*$") or ""
	if nameQuery ~= "" then
		teleportToUsername(nameQuery)
	else
		toast("Masukkan sebagian nama terlebih dahulu")
	end
end)

tpTargetInput.FocusLost:Connect(function(enterPressed)
	if enterPressed then
		local nameQuery = string.match(tpTargetInput.Text, "^%s*(.-)%s*$") or ""
		if nameQuery ~= "" then
			teleportToUsername(nameQuery)
		end
	end
end)

end

-- =====================================================
-- ITEM ESP SELEKTIF (scan ringan + daftar pilihan + detail hanya untuk yang dipilih)
-- =====================================================
sectionLabel(teleportPage, 1, "Loot & Item ESP")

do

-- ---------- UI ----------
local scannerCard = makeCard(teleportPage, 366, 2)

local scanBtn = new("TextButton", {
	Position = UDim2.fromOffset(14, 12),
	Size = UDim2.new(1, -28 - 94, 0, 30),
	BackgroundColor3 = T.accent,
	Text = "🔍 SCAN ITEM",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBold,
	TextSize = 12,
	AutoButtonColor = false,
}, scannerCard)
round(scanBtn, 8)
hover(scanBtn, T.accent)

local autoBtn = new("TextButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 12),
	Size = UDim2.fromOffset(88, 30),
	BackgroundColor3 = T.bg,
	Text = "Live: OFF",
	TextColor3 = T.sub,
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	AutoButtonColor = false,
	BorderSizePixel = 0,
}, scannerCard)
round(autoBtn, 8)
stroke(autoBtn, T.stroke, 1, 0.3)

local scanStatus = text(scannerCard, {
	Text = "Belum scan",
	TextSize = 11,
	TextColor3 = T.sub,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Position = UDim2.fromOffset(14, 48),
	Size = UDim2.new(1, -28, 0, 14),
})

local lootSearchBox = new("TextBox", {
	Position = UDim2.fromOffset(14, 66),
	Size = UDim2.new(1, -28, 0, 28),
	BackgroundColor3 = T.bg,
	PlaceholderText = "🔎 Cari nama item...",
	PlaceholderColor3 = T.sub,
	Text = "",
	TextColor3 = T.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 11,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, scannerCard)
round(lootSearchBox, 8)
stroke(lootSearchBox, T.stroke, 1, 0.3)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, lootSearchBox)

-- Chip kategori
local chipRow = new("Frame", {
	Position = UDim2.fromOffset(14, 100),
	Size = UDim2.new(1, -28, 0, 24),
	BackgroundTransparency = 1,
}, scannerCard)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, chipRow)

local chipNames = { "Semua", "Terpilih", "Prompt", "Klik", "Tool", "Sentuh" }
local chipBtns: { [string]: any } = {}

-- Baris aksi
local actionRow = new("Frame", {
	Position = UDim2.fromOffset(14, 130),
	Size = UDim2.new(1, -28, 0, 24),
	BackgroundTransparency = 1,
}, scannerCard)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, actionRow)

local function smallButton(parent: Instance, txt: string, size: UDim2, layoutOrder: number): any
	local b = new("TextButton", {
		LayoutOrder = layoutOrder,
		Size = size,
		BackgroundColor3 = T.bg,
		Text = txt,
		TextColor3 = T.sub,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, parent)
	round(b, 6)
	stroke(b, T.stroke, 1, 0.4)
	return b
end

do -- Item ESP dibungkus agar local-nya tidak menghabiskan jatah 200 local
local selectAllBtn = smallButton(actionRow, "Pilih hasil", UDim2.new(1 / 3, -4, 1, 0), 1)
local clearSelBtn = smallButton(actionRow, "Kosongkan", UDim2.new(1 / 3, -4, 1, 0), 2)
local dotsBtn = smallButton(actionRow, "Titik: ON", UDim2.new(1 / 3, -4, 1, 0), 3)
hover(selectAllBtn, T.bg)
hover(clearSelBtn, T.bg)

-- Daftar item unik
local lootScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 162),
	Size = UDim2.new(1, -28, 0, 192),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = T.stroke,
}, scannerCard)
new("UIListLayout", {
	Padding = UDim.new(0, 4),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, lootScroll)

local emptyLbl = text(scannerCard, {
	Text = "Belum ada data — tekan SCAN ITEM",
	TextSize = 11,
	TextColor3 = T.sub,
	TextXAlignment = Enum.TextXAlignment.Center,
	Position = UDim2.fromOffset(14, 162),
	Size = UDim2.new(1, -28, 0, 192),
})

-- =====================================================
-- MESIN SCANNER v2
-- * Pelacakan LIVE berbasis event (DescendantAdded/Removing) -> item yang baru muncul,
--   di-stream masuk, atau hilang langsung ikut terdata tanpa scan ulang.
-- * Deteksi: ProximityPrompt, ClickDetector, Tool, dan TouchTransmitter (sentuh/koin).
-- * Prompt di dalam Attachment/Folder/Model sekarang ikut terdeteksi.
-- * Semua kerja berat dipecah per frame (ada anggaran waktu) -> tidak ada lag/hitch.
-- * Titik & label hanya dibuat untuk objek TERDEKAT (bukan 600 pertama di workspace).
-- * Scan dibungkus pcall: satu error tidak lagi membuat tombol macet selamanya.
-- Dibungkus fungsi sendiri supaya punya jatah 200 local terpisah dari chunk utama.
-- =====================================================
local function runScanner()

-- ---------- konfigurasi (aman diubah) ----------
local DOT_LIMIT = 500            -- target titik dasar terdekat yang digambar
local DOT_HARD = 700             -- batas keras jumlah titik
local LABEL_LIMIT = 150          -- target label nama+jarak terdekat (item terpilih)
local LABEL_HARD = 200           -- batas keras jumlah label
local DOT_MAX_DIST = 600         -- titik hanya tampil dalam jarak ini (studs)
local LABEL_MAX_DIST = 3000      -- label tampil sampai jarak ini (studs)
local ROW_LIMIT = 250            -- baris daftar yang dibuat (sisanya lewat kotak cari)
local MAX_ENTRIES = 30000        -- batas total objek yang dilacak
local MAKE_PER_TICK = 60         -- maks. titik/label baru dibuat per langkah
local SLICE = 500                -- jumlah objek yang diukur jaraknya per frame
local PROCESS_BUDGET = 0.0025    -- detik/frame untuk memproses kandidat baru
local SCAN_BUDGET = 0.004        -- detik/frame saat scan penuh berjalan
local MARK_INTERVAL = 0.4        -- detik antar pemilihan titik/label
local LABEL_INTERVAL = 0.2       -- detik antar update teks jarak
local ROWS_PER_FLUSH = 30        -- baris daftar baru per langkah UI
local RETRY_DELAY = 0.6          -- jeda sebelum mencoba ulang objek yang belum lengkap
local RETRY_MAX = 6
local DB, LB = 120, 100          -- jumlah bucket histogram jarak (titik / label)

local COL_DOT = T.accent2
local COL_SEL = T.good

local CLASS_CAT: { [string]: string } = {
	ProximityPrompt = "Prompt",
	ClickDetector = "Klik",
	Tool = "Tool",
	TouchTransmitter = "Sentuh",
}
local PRI: { [string]: number } = { Prompt = 4, Klik = 3, Tool = 2, Sentuh = 1 }

-- Nama part yang terlalu umum -> pakai nama induknya
local GENERIC: { [string]: boolean } = {
	Handle = true, Part = true, MeshPart = true, Union = true, UnionOperation = true,
	Main = true, Root = true, Hitbox = true, Attachment = true, Base = true, Body = true,
	Mesh = true, Primary = true, PrimaryPart = true, Hit = true, Trigger = true,
	Collider = true, Prompt = true, Interact = true,
}

-- ---------- data ----------
local groups: { [string]: any } = {}     -- nama -> { name, lower, cats, list }
local order: { string } = {}             -- nama unik (urut abjad)
local itemSel: { [string]: boolean? } = {}
local rows: { [string]: any } = {}
local all: { any } = {}                  -- semua entri (untuk pengukuran jarak bergilir)
local byTrig: { [Instance]: any } = {}   -- pemicu (prompt/click/tool/touch) -> entri
local byPart: { [Instance]: any } = {}   -- part -> entri (anti-duplikat)
local labeled: { [any]: boolean } = {}
local dirtyNames: { [string]: boolean } = {}
local pendingRows: { string } = {}
local retryList: { any } = {}
local qInst: { any } = {}
local qTries: { number } = {}
local qHead, qTail = 1, 0
local orderDirty = false
local layoutDirty = false
local markDue = false
local totalObjs = 0
local labelCount, dotCount = 0, 0
local sliceIdx = 1
local matchShown, matchTotal = 0, 0
local scanning = false
local autoScan = false                   -- = pelacakan live aktif
local dotsOn = true
local filterMode = "Semua"
local markFolder: Folder? = nil
local liveAdd: RBXScriptConnection? = nil
local liveRem: RBXScriptConnection? = nil
local curOrigin: Vector3? = nil
local warnedReg = false

-- ---------- penanda (titik & label) ----------
local function ensureFolder(): Folder
	if not (markFolder and markFolder:IsDescendantOf(workspace)) then
		if markFolder then markFolder:Destroy() end
		markFolder = new("Folder", { Name = "UU_ITEMS" }, workspace.CurrentCamera or workspace)
	end
	return markFolder :: Folder
end

local function styleDot(e: any, on: boolean)
	local f = e.dotFrame
	if f then
		f.BackgroundColor3 = on and COL_SEL or COL_DOT
	end
	local d = e.dot
	if d then
		d.Size = on and UDim2.fromOffset(10, 10) or UDim2.fromOffset(7, 7)
	end
end

local function makeDot(e: any)
	if e.dot or dotCount >= DOT_HARD then return end
	local bb = new("BillboardGui", {
		Name = "Dot",
		Adornee = e.part,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(7, 7),
		MaxDistance = DOT_MAX_DIST,
		LightInfluence = 0,
		Enabled = dotsOn,
	}, ensureFolder())
	local f = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = COL_DOT,
		BackgroundTransparency = 0.1,
		BorderSizePixel = 0,
	}, bb)
	round(f, 2)
	e.dot = bb
	e.dotFrame = f
	dotCount += 1
	if e.label then styleDot(e, true) end
end

local function dropDot(e: any)
	if e.dot then
		e.dot:Destroy()
		e.dot = nil
		e.dotFrame = nil
		dotCount = math.max(0, dotCount - 1)
	end
end

local function makeLabel(e: any)
	if e.label or labelCount >= LABEL_HARD then return end
	local bb = new("BillboardGui", {
		Name = "Label",
		Adornee = e.part,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(132, 36),
		StudsOffset = Vector3.new(0, 2, 0),
		MaxDistance = LABEL_MAX_DIST,
		LightInfluence = 0,
	}, ensureFolder())
	local bg = new("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, bb)
	round(bg, 8)
	stroke(bg, COL_SEL, 1, 0.35)
	text(bg, {
		Text = e.name,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, 3),
		Size = UDim2.new(1, -16, 0, 16),
	})
	local d = text(bg, {
		Text = "",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = COL_SEL,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(8, 19),
		Size = UDim2.new(1, -16, 0, 14),
	})
	e.label = bb
	e.distLbl = d
	e.lastDist = -1
	labeled[e] = true
	labelCount += 1
end

local function dropLabel(e: any)
	if e.label then
		e.label:Destroy()
		e.label = nil
		e.distLbl = nil
		labeled[e] = nil
		labelCount = math.max(0, labelCount - 1)
	end
end

-- ---------- entri: tambah / hapus ----------
local function removeEntry(e: any)
	if e.dead then return end
	e.dead = true
	if e.dot then dropDot(e) end
	if e.label then dropLabel(e) end
	byTrig[e.trig] = nil
	if byPart[e.part] == e then byPart[e.part] = nil end

	local n = #all
	local ai = e.ai
	if ai ~= n then
		local last = all[n]
		all[ai] = last
		last.ai = ai
	end
	all[n] = nil

	local g = groups[e.name]
	if g then
		local gl = g.list
		local m = #gl
		local gi = e.gi
		if gi ~= m then
			local last = gl[m]
			gl[gi] = last
			last.gi = gi
		end
		gl[m] = nil
		local c = (g.cats[e.cat] or 1) - 1
		if c > 0 then
			g.cats[e.cat] = c
		else
			g.cats[e.cat] = nil
			orderDirty = true
		end
		if m - 1 == 0 then
			groups[e.name] = nil
			orderDirty = true
		end
	end
	totalObjs -= 1
	dirtyNames[e.name] = true
end

local function addEntry(inst: Instance, cat: string, part: BasePart, name: string)
	local g = groups[name]
	if not g then
		g = { name = name, lower = string.lower(name), cats = {}, list = {} }
		groups[name] = g
		orderDirty = true
	end
	if not g.cats[cat] then
		orderDirty = true
	end
	g.cats[cat] = (g.cats[cat] or 0) + 1

	local d = math.huge
	if curOrigin then
		d = (part.Position - curOrigin).Magnitude
	end
	local e: any = { name = name, cat = cat, part = part, trig = inst, dist = d, lastDist = -1 }

	local gl = g.list
	gl[#gl + 1] = e
	e.gi = #gl
	all[#all + 1] = e
	e.ai = #all
	byTrig[inst] = e
	byPart[part] = e
	totalObjs += 1
	dirtyNames[name] = true
end

-- ---------- resolusi pemicu -> part & nama ----------
local function inCharacter(inst: Instance): boolean
	local a: Instance? = inst
	while a and a ~= (workspace :: Instance) do
		if Players:GetPlayerFromCharacter(a) then return true end
		a = a.Parent
	end
	return false
end

local function firstPart(m: Instance): BasePart?
	if m:IsA("Model") then
		local pp = (m :: Model).PrimaryPart
		if pp then return pp end
	end
	return m:FindFirstChildWhichIsA("BasePart", true) :: BasePart?
end

-- Naik dari pemicu sampai ketemu BasePart/Model. Menangani prompt di dalam
-- Attachment, Folder, dll yang dulu dilewati begitu saja.
local function resolve(inst: Instance, cat: string): (BasePart?, Instance?)
	if cat == "Tool" then
		local h = inst:FindFirstChild("Handle")
		if h and h:IsA("BasePart") then return h :: BasePart, inst end
		return firstPart(inst), inst
	end
	local cur: Instance? = inst.Parent
	while cur and cur ~= (workspace :: Instance) do
		if cur:IsA("BasePart") then return cur :: BasePart, cur end
		if cur:IsA("Model") then return firstPart(cur), cur end
		cur = cur.Parent
	end
	return nil, nil
end

local function baseName(anchor: Instance): string
	local n = anchor.Name
	local cur: Instance = anchor
	for _ = 1, 2 do
		if not GENERIC[n] then break end
		local p = cur.Parent
		if not p or p == (workspace :: Instance) then break end
		cur = p
		n = p.Name
	end
	return n
end

local function tryRegister(inst: Instance, tries: number)
	if byTrig[inst] then return end
	if not inst:IsDescendantOf(workspace) then return end
	local cat = CLASS_CAT[inst.ClassName]
	if not cat then return end
	if #all >= MAX_ENTRIES then return end

	local part, anchor = resolve(inst, cat)
	if not part or not anchor then
		-- struktur belum lengkap (sering terjadi saat streaming) -> coba lagi sebentar lagi
		if tries < RETRY_MAX then
			retryList[#retryList + 1] = { inst, tries + 1, os.clock() + RETRY_DELAY }
		end
		return
	end
	if inCharacter(anchor) then return end

	if cat == "Sentuh" then
		if part.CanTouch == false then return end
		local par = part.Parent
		if par and par:FindFirstChildOfClass("Humanoid") then return end -- bagian tubuh NPC
	end

	local old = byPart[part]
	if old and not old.dead then
		if PRI[cat] > PRI[old.cat] then
			removeEntry(old)
		else
			return
		end
	end

	local name: string
	if cat == "Prompt" and (inst :: ProximityPrompt).ObjectText ~= "" then
		name = (inst :: ProximityPrompt).ObjectText
	elseif cat == "Tool" then
		name = inst.Name
	else
		name = baseName(anchor)
	end
	addEntry(inst, cat, part, name)
end

-- ---------- antrean kandidat (diproses per frame dengan anggaran waktu) ----------
local function enqueue(inst: Instance, tries: number)
	qTail += 1
	qInst[qTail] = inst
	qTries[qTail] = tries
end

local function processQueue(budget: number)
	if qHead > qTail then return end
	local t0 = os.clock()
	local n = 0
	while qHead <= qTail do
		local inst, tries = qInst[qHead], qTries[qHead]
		qInst[qHead] = nil
		qTries[qHead] = nil
		qHead += 1
		local ok, err = pcall(tryRegister, inst, tries)
		if not ok and not warnedReg then
			warnedReg = true
			warn("[ItemScan] " .. tostring(err))
		end
		n += 1
		if n % 8 == 0 and os.clock() - t0 > budget then break end
	end
	if qHead > qTail then
		qHead, qTail = 1, 0
	end
end

local function retryStep()
	if #retryList == 0 then return end
	local now = os.clock()
	local i = #retryList
	while i >= 1 do
		local r = retryList[i]
		if now >= r[3] then
			retryList[i] = retryList[#retryList]
			retryList[#retryList] = nil
			enqueue(r[1], r[2])
		end
		i -= 1
	end
end

-- ---------- pelacakan live ----------
local function startLive()
	if liveAdd then return end
	liveAdd = track(workspace.DescendantAdded:Connect(function(inst)
		if CLASS_CAT[inst.ClassName] then
			enqueue(inst, 0)
		end
	end))
	liveRem = track(workspace.DescendantRemoving:Connect(function(inst)
		local e = byTrig[inst]
		if e then removeEntry(e) end
	end))
end

local function stopLive()
	if liveAdd then liveAdd:Disconnect(); liveAdd = nil end
	if liveRem then liveRem:Disconnect(); liveRem = nil end
end

-- ---------- status & filter ----------
local function countSelected(): number
	local n = 0
	for name in pairs(itemSel) do
		if groups[name] then n += 1 end
	end
	return n
end

local function refreshStatus()
	local s: string
	if scanning then
		s = string.format("Memindai... %d objek ditemukan", totalObjs)
	elseif #order == 0 and totalObjs == 0 then
		s = autoScan and "Live aktif · belum ada item terdeteksi" or "Belum scan"
	else
		s = string.format("%d jenis · %d objek · %d dipilih", #order, totalObjs, countSelected())
		if matchTotal > matchShown then
			s ..= string.format(" · tampil %d/%d (cari untuk menyaring)", matchShown, matchTotal)
		end
		if labelCount >= LABEL_LIMIT then
			s ..= " · label dibatasi " .. LABEL_LIMIT
		end
	end
	if scanStatus.Text ~= s then
		scanStatus.Text = s
	end
end

local function groupMatches(g: any, q: string): boolean
	if q ~= "" and not string.find(g.lower, q, 1, true) then return false end
	local fm = filterMode
	if fm == "Semua" then
		if q ~= "" then return true end -- pencarian menembus semua kategori
		for cat in pairs(g.cats) do
			if cat ~= "Sentuh" then return true end -- "Sentuh" hanya di chip-nya sendiri (terlalu ramai)
		end
		return false
	elseif fm == "Terpilih" then
		return itemSel[g.name] == true
	end
	return g.cats[fm] ~= nil
end

local function applyFilter(): number
	local q = string.lower(lootSearchBox.Text)
	local shown, total = 0, 0
	table.clear(pendingRows)
	for i = 1, #order do
		local name = order[i]
		local g = groups[name]
		local r = rows[name]
		local ok = g ~= nil and groupMatches(g, q)
		if ok then
			total += 1
			if shown < ROW_LIMIT then
				shown += 1
				if r then
					r.btn.Visible = true
				else
					pendingRows[#pendingRows + 1] = name
				end
			elseif r then
				r.btn.Visible = false
			end
		elseif r then
			r.btn.Visible = false
		end
	end
	matchShown, matchTotal = shown, total

	if shown == 0 then
		if scanning then
			emptyLbl.Text = "Memindai..."
		elseif #order == 0 then
			emptyLbl.Text = autoScan and "Live aktif — belum ada item terdeteksi" or "Belum ada data — tekan SCAN ITEM"
		elseif filterMode == "Terpilih" then
			emptyLbl.Text = "Belum ada item yang dipilih"
		else
			emptyLbl.Text = "Tidak ada hasil"
		end
	end
	emptyLbl.Visible = shown == 0
	return shown
end

local function setSelected(name: string, on: boolean)
	itemSel[name] = on or nil
	local r = rows[name]
	if r then r.apply() end
	markDue = true -- titik/label diperbarui di frame berikutnya
end

-- ---------- teleport ----------
local function teleportToNearest(g: any)
	local char = player.Character
	local hrp = getRoot()
	if not (char and hrp) then return end

	-- Tiap tekan TP pindah ke item BERIKUTNYA (terdekat yang belum dikunjungi).
	-- Kalau semua sudah dikunjungi, putaran diulang dari awal.
	local visited: { [any]: boolean } = g.visited or {}
	g.visited = visited

	local total = 0
	for _, e in ipairs(g.list) do
		if e.part.Parent then total += 1 end
	end
	if total == 0 then
		toast("Item sudah tidak ada")
		return
	end

	local origin: Vector3 = hrp.Position
	local function pick(skip: any): any
		local best: any = nil
		local bestD = math.huge
		for _, e in ipairs(g.list) do
			if e.part.Parent and not visited[e] and e ~= skip then
				local d = (e.part.Position - origin).Magnitude
				if d < bestD then
					bestD = d
					best = e
				end
			end
		end
		return best
	end

	local best = pick(nil)
	if not best then
		local last = g.last
		table.clear(visited)
		local skip = nil
		if total > 1 then skip = last end
		best = pick(skip)
	end
	if not best then
		toast("Item sudah tidak ada")
		return
	end

	visited[best] = true
	g.last = best
	local n = 0
	for e in pairs(visited) do
		if not e.dead and e.part.Parent then n += 1 end
	end

	char:PivotTo(best.part.CFrame + Vector3.new(0, 3, 0))
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.AssemblyAngularVelocity = Vector3.zero
	floatY = nil
	if total > 1 then
		toast(string.format("Teleport ke %s (%d/%d)", g.name, n, total))
	else
		toast("Teleport ke " .. g.name)
	end
end

-- ---------- baris daftar ----------
local function buildRow(g: any)
	local name: string = g.name
	local btn = new("TextButton", {
		Name = string.sub(name, 1, 50),
		LayoutOrder = 0,
		Size = UDim2.new(1, -6, 0, 28),
		BackgroundColor3 = T.bg,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, lootScroll)
	round(btn, 6)

	local box = new("Frame", {
		Position = UDim2.new(0, 8, 0.5, -7),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = T.off,
		BorderSizePixel = 0,
	}, btn)
	round(box, 4)
	stroke(box, T.stroke, 1, 0.2)
	local check = text(box, {
		Text = "✓",
		Font = Enum.Font.GothamBold,
		TextSize = 11,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
	})

	text(btn, {
		Text = name,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -30 - 78, 1, 0),
	})
	local cnt = text(btn, {
		Text = "×" .. #g.list,
		TextSize = 10,
		TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -40, 0.5, 0),
		Size = UDim2.fromOffset(34, 14),
	})

	local tp = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -5, 0.5, 0),
		Size = UDim2.fromOffset(30, 20),
		BackgroundColor3 = T.accent2,
		Text = "TP",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, btn)
	round(tp, 5)
	hover(tp, T.accent2)

	local function baseColor(): Color3
		return itemSel[name] and T.cardSel or T.bg
	end
	local function apply()
		local sel = itemSel[name] == true
		box.BackgroundColor3 = sel and COL_SEL or T.off
		check.Visible = sel
		btn.BackgroundColor3 = baseColor()
	end

	btn.MouseEnter:Connect(function()
		tween(btn, { BackgroundColor3 = lighten(baseColor()) }, 0.1)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundColor3 = baseColor() }, 0.1)
	end)
	btn.MouseButton1Click:Connect(function()
		setSelected(name, not itemSel[name])
		refreshStatus()
		if filterMode == "Terpilih" then applyFilter() end
	end)
	tp.MouseButton1Click:Connect(function()
		local cur = groups[name]
		if cur then
			teleportToNearest(cur)
		else
			toast("Item sudah tidak ada")
		end
	end)

	rows[name] = { btn = btn, apply = apply, cnt = cnt, order = 0 }
	apply()
end

local function buildPending(maxN: number)
	local built = 0
	while built < maxN do
		local name = table.remove(pendingRows, 1)
		if not name then break end
		local g = groups[name]
		if g and not rows[name] then
			buildRow(g)
			built += 1
		end
	end
	if built > 0 or layoutDirty then
		for i = 1, #order do
			local r = rows[order[i]]
			if r and r.order ~= i then
				r.order = i
				r.btn.LayoutOrder = i
			end
		end
		layoutDirty = false
	end
end

local function rebuildOrder()
	table.clear(order)
	for name in pairs(groups) do
		order[#order + 1] = name
	end
	table.sort(order, function(a, b)
		local la, lb = groups[a].lower, groups[b].lower
		if la ~= lb then return la < lb end
		return a < b
	end)
	orderDirty = false
end

local function flushUI()
	if orderDirty then
		rebuildOrder()
		layoutDirty = true
		applyFilter()
	end
	for name in pairs(dirtyNames) do
		local g = groups[name]
		local r = rows[name]
		if r then
			if g then
				r.cnt.Text = "×" .. #g.list
			else
				r.btn:Destroy()
				rows[name] = nil
			end
		end
	end
	table.clear(dirtyNames)
	buildPending(ROWS_PER_FLUSH)
	refreshStatus()
end

-- ---------- bersihkan ----------
local function wipe()
	if markFolder then
		markFolder:Destroy()
		markFolder = nil
	end
	for _, r in pairs(rows) do
		r.btn:Destroy()
	end
	rows = {}
	groups = {}
	order = {}
	all = {}
	byTrig = {}
	byPart = {}
	labeled = {}
	dirtyNames = {}
	pendingRows = {}
	retryList = {}
	qInst, qTries = {}, {}
	qHead, qTail = 1, 0
	orderDirty = false
	layoutDirty = false
	totalObjs, labelCount, dotCount = 0, 0, 0
	sliceIdx = 1
	matchShown, matchTotal = 0, 0
	applyFilter()
	refreshStatus()
end

local function setAutoUI()
	autoBtn.Text = autoScan and "Live: ON" or "Live: OFF"
	tween(autoBtn, {
		BackgroundColor3 = autoScan and T.cardSel or T.bg,
		TextColor3 = autoScan and T.text or T.sub,
	}, 0.12)
end

clearMarkings = function()
	stopLive()
	autoScan = false
	setAutoUI()
	wipe()
end

-- ---------- scan penuh ----------
local function scanItems()
	if scanning or unloaded then return end
	scanning = true
	scanBtn.Text = "⏳ Memindai..."

	local ok, err = pcall(function()
		wipe()
		startLive()          -- tangkap juga item yang muncul selama scan berjalan
		autoScan = true
		setAutoUI()
		refreshStatus()

		local desc = workspace:GetDescendants()
		local t0 = os.clock()
		for i = 1, #desc do
			local inst = desc[i]
			if CLASS_CAT[inst.ClassName] then
				enqueue(inst, 0)
			end
			if i % 400 == 0 and os.clock() - t0 > SCAN_BUDGET then
				RunService.Heartbeat:Wait()
				if unloaded then return end
				t0 = os.clock()
			end
		end
		desc = nil

		-- tunggu antrean kandidat habis diproses (dikerjakan di Heartbeat)
		local guard = os.clock()
		while qHead <= qTail and not unloaded do
			RunService.Heartbeat:Wait()
			if os.clock() - guard > 60 then break end
		end
	end)

	scanning = false
	if unloaded then return end
	scanBtn.Text = "🔍 SCAN ITEM"
	flushUI()

	if not ok then
		warn("[ItemScan] " .. tostring(err))
		toast("Scan error — lihat Output (F9)")
	else
		-- pilihan lama yang sudah tidak ada di hasil scan ikut dibuang
		for name in pairs(itemSel) do
			if not groups[name] then itemSel[name] = nil end
		end
		if totalObjs == 0 then
			if workspace.StreamingEnabled then
				toast("Belum ada item (StreamingEnabled aktif) — Live tetap memantau saat kamu bergerak")
			else
				toast("Tidak ada Prompt/Klik/Tool/Sentuh terdeteksi di game ini")
			end
		else
			toast(string.format("Scan selesai: %d jenis, %d objek", #order, totalObjs))
		end
		refreshStatus()
	end
end

-- ---------- tombol ----------
local function onFilterChanged()
	applyFilter()
	buildPending(ROWS_PER_FLUSH)
	refreshStatus()
end

local function setChip(mode: string)
	filterMode = mode
	for nm, b in pairs(chipBtns) do
		local active = nm == mode
		tween(b, {
			BackgroundColor3 = active and T.accent or T.bg,
			TextColor3 = active and WHITE or T.sub,
		}, 0.12)
	end
	onFilterChanged()
end

do
	local nChips = #chipNames
	local chipPad = math.ceil(6 * (nChips - 1) / nChips)
	for i, nm in ipairs(chipNames) do
		local b = smallButton(chipRow, nm, UDim2.new(1 / nChips, -chipPad, 1, 0), i)
		b.TextSize = 10
		chipBtns[nm] = b
		b.MouseButton1Click:Connect(function()
			setChip(nm)
		end)
	end
	chipBtns["Semua"].BackgroundColor3 = T.accent
	chipBtns["Semua"].TextColor3 = WHITE
end

scanBtn.MouseButton1Click:Connect(scanItems)
lootSearchBox:GetPropertyChangedSignal("Text"):Connect(onFilterChanged)

autoBtn.MouseButton1Click:Connect(function()
	if autoScan then
		autoScan = false
		stopLive()
		setAutoUI()
		refreshStatus()
		applyFilter()
	else
		autoScan = true
		setAutoUI()
		if not scanning then
			task.spawn(scanItems)
		end
	end
end)

selectAllBtn.MouseButton1Click:Connect(function()
	-- pilih semua item yang sedang tampil (sesuai pencarian & kategori)
	local q = string.lower(lootSearchBox.Text)
	local picked = 0
	for i = 1, #order do
		local name = order[i]
		local g = groups[name]
		if g and not itemSel[name] and groupMatches(g, q) then
			if picked >= ROW_LIMIT then break end
			picked += 1
			setSelected(name, true)
		end
	end
	refreshStatus()
	applyFilter()
end)

clearSelBtn.MouseButton1Click:Connect(function()
	for name in pairs(table.clone(itemSel)) do
		setSelected(name, false)
	end
	refreshStatus()
	applyFilter()
end)

dotsBtn.MouseButton1Click:Connect(function()
	dotsOn = not dotsOn
	dotsBtn.Text = dotsOn and "Titik: ON" or "Titik: OFF"
	for i = 1, #all do
		local d = all[i].dot
		if d then d.Enabled = dotsOn end
	end
end)

-- ---------- loop per-frame ----------
local function getOrigin(): Vector3?
	local cam = workspace.CurrentCamera
	if state.freecam and cam then
		return cam.CFrame.Position
	end
	local root = getRoot()
	if root then return root.Position end
	return cam and cam.CFrame.Position or nil
end

-- Ukur jarak secara bergilir (maks. SLICE objek per frame), sekalian buang entri yang part-nya hilang.
local function distanceStep(origin: Vector3)
	local n = #all
	if n == 0 then return end
	local idx = sliceIdx
	local count = 0
	while count < SLICE do
		if idx > n then idx = 1 end
		local e = all[idx]
		if not e then break end
		local part = e.part
		if part.Parent == nil then
			removeEntry(e) -- entri terakhir dipindah ke posisi idx, jadi idx tidak dimajukan
			n = #all
			if n == 0 then break end
		else
			e.dist = (part.Position - origin).Magnitude
			idx += 1
		end
		count += 1
		if count >= n then break end
	end
	sliceIdx = idx
end

-- Pilih titik & label untuk objek TERDEKAT saja. Memakai histogram jarak (O(n), tanpa sort).
local function updateMarkers()
	local n = #all
	if n == 0 then return end
	local dHist = table.create(DB, 0)
	local lHist = table.create(LB, 0)
	local dStep = DOT_MAX_DIST / DB
	local lStep = LABEL_MAX_DIST / LB

	for i = 1, n do
		local e = all[i]
		local d = e.dist
		local sel = itemSel[e.name] == true
		if d <= DOT_MAX_DIST and (sel or e.cat ~= "Sentuh") then
			local b = math.min(DB, math.floor(d / dStep) + 1)
			dHist[b] += 1
		end
		if sel and d <= LABEL_MAX_DIST then
			local b = math.min(LB, math.floor(d / lStep) + 1)
			lHist[b] += 1
		end
	end

	local dThr, cum = DOT_MAX_DIST, 0
	for b = 1, DB do
		cum += dHist[b]
		if cum >= DOT_LIMIT then
			dThr = b * dStep
			break
		end
	end
	local lThr = LABEL_MAX_DIST
	cum = 0
	for b = 1, LB do
		cum += lHist[b]
		if cum >= LABEL_LIMIT then
			lThr = b * lStep
			break
		end
	end
	local dKeep, lKeep = dThr * 1.15, lThr * 1.15 -- histeresis: cegah titik berkedip di batas

	local madeDots, madeLabels = 0, 0
	for i = 1, n do
		local e = all[i]
		local d = e.dist
		local sel = itemSel[e.name] == true
		local eligible = sel or e.cat ~= "Sentuh"

		-- pulihkan bila penanda hilang (mis. kamera diganti oleh game)
		if e.dot and not e.dot:IsDescendantOf(workspace) then
			e.dot = nil
			e.dotFrame = nil
			dotCount = math.max(0, dotCount - 1)
		end
		if e.label and not e.label:IsDescendantOf(workspace) then
			e.label = nil
			e.distLbl = nil
			labeled[e] = nil
			labelCount = math.max(0, labelCount - 1)
		end

		if eligible and d <= dThr then
			if not e.dot and madeDots < MAKE_PER_TICK then
				makeDot(e)
				if e.dot then madeDots += 1 end
			end
		elseif e.dot and (not eligible or d > dKeep) then
			dropDot(e)
		end

		if sel and d <= lThr then
			if not e.label and madeLabels < MAKE_PER_TICK then
				makeLabel(e)
				if e.label then
					madeLabels += 1
					styleDot(e, true)
				end
			end
		elseif e.label and (not sel or d > lKeep) then
			dropLabel(e)
			styleDot(e, false)
		end
	end

	if madeDots >= MAKE_PER_TICK or madeLabels >= MAKE_PER_TICK then
		markDue = true -- masih ada yang antre, lanjutkan di frame berikutnya
	end
end

local function updateLabels(origin: Vector3)
	for e in pairs(labeled) do
		local lbl = e.distLbl
		local part = e.part
		if lbl and part.Parent then
			local d = math.floor((part.Position - origin).Magnitude + 0.5)
			if d ~= e.lastDist then
				e.lastDist = d
				lbl.Text = d .. " st"
			end
		end
	end
end

local acc = { mark = 0, label = 0, ui = 0, retry = 0 }
track(RunService.Heartbeat:Connect(function(dt: number)
	if unloaded then return end

	processQueue(scanning and SCAN_BUDGET or PROCESS_BUDGET)

	local origin = getOrigin()
	curOrigin = origin
	if origin and #all > 0 then
		distanceStep(origin)
	end
	local n = #all

	acc.retry += dt
	if acc.retry >= 0.25 then
		acc.retry = 0
		retryStep()
	end

	acc.mark += dt
	if origin and n > 0 and (markDue or acc.mark >= MARK_INTERVAL) then
		acc.mark = 0
		markDue = false
		updateMarkers()
	end

	acc.label += dt
	if origin and acc.label >= LABEL_INTERVAL then
		acc.label = 0
		if next(labeled) ~= nil then
			updateLabels(origin)
		end
	end

	acc.ui += dt
	if acc.ui >= math.clamp(n / 6000, 0.3, 1) then
		acc.ui = 0
		flushUI()
	end
end))

applyFilter()
refreshStatus()

end -- runScanner

runScanner()

end -- tutup do (Item ESP v2)

sectionLabel(teleportPage, 3, "Free Cam & Waypoint")

addSliderCard(teleportPage, 4, "Free Cam", "WASD + E/Q, Shift cepat, klik kanan = lihat", "freecam", 5, 600, 1000)

local topCard = makeCard(teleportPage, 112, 5)
text(topCard, {
	Text = "Waypoint",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(0.5, -14, 0, 18),
})
local countLabel = text(topCard, {
	TextSize = 11,
	TextColor3 = T.sub,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.new(0.5, 0, 0, 12),
	Size = UDim2.new(0.4, -14, 0, 14),
})
local statusLabel = text(topCard, {
	TextSize = 12,
	TextColor3 = T.sub,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Position = UDim2.fromOffset(14, 32),
	Size = UDim2.new(1, -28, 0, 16),
})

local btnRow = new("Frame", {
	Position = UDim2.fromOffset(14, 58),
	Size = UDim2.new(1, -28, 0, 40),
	BackgroundTransparency = 1,
}, topCard)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, btnRow)

local function rowButton(order: number, txt: string, color: Color3, onClick: () -> ())
	local b = new("TextButton", {
		LayoutOrder = order,
		Size = UDim2.new(0.5, -4, 1, 0),
		BackgroundColor3 = color,
		Text = txt,
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		AutoButtonColor = false,
	}, btnRow)
	round(b, 10)
	hover(b, color)
	b.MouseButton1Click:Connect(onClick)
	return b
end

rowButton(1, "+ Simpan Posisi", T.accent, saveWaypoint)
rowButton(2, "Teleport", T.accent2, teleportSelected)

local emptyLabel = text(teleportPage, {
	LayoutOrder = 6,
	Text = "Belum ada waypoint. Tekan \"Simpan Posisi\" untuk menyimpan posisimu sekarang.",
	TextSize = 12,
	TextColor3 = T.sub,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 44),
})

local rowRefs: { { row: any, stroke: any } } = {}

local function coordText(cf: CFrame): string
	local p = cf.Position
	return string.format("X %d   Y %d   Z %d", math.floor(p.X + 0.5), math.floor(p.Y + 0.5), math.floor(p.Z + 0.5))
end

refreshSelection = function()
	countLabel.Text = tostring(#waypoints) .. " / " .. tostring(MAX_WP)
	local wp = waypoints[selected]
	if wp then
		statusLabel.Text = "Terpilih: " .. tostring(selected) .. ". " .. wp.name
	else
		statusLabel.Text = "Belum ada waypoint terpilih"
	end
	for idx, ref in ipairs(rowRefs) do
		local sel = (idx == selected)
		ref.stroke.Color = sel and T.accent or T.stroke
		ref.stroke.Transparency = sel and 0 or 0.5
		ref.stroke.Thickness = sel and 1.5 or 1
		ref.row.BackgroundColor3 = sel and T.cardSel or T.card
	end
end

local function buildRow(i: number, wp: Waypoint)
	local row = new("TextButton", {
		LayoutOrder = 10 + i,
		Size = UDim2.new(1, 0, 0, 56),
		BackgroundColor3 = T.card,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, teleportPage)
	round(row, 12)
	local rowStroke = stroke(row, T.stroke, 1, 0.5)

	text(row, {
		Text = tostring(i),
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		TextColor3 = T.accent,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.fromOffset(28, 56),
	})

	local nameBox = new("TextBox", {
		Position = UDim2.fromOffset(40, 8),
		Size = UDim2.new(1, -190, 0, 20),
		BackgroundTransparency = 1,
		Text = wp.name,
		PlaceholderText = "Nama waypoint",
		TextColor3 = T.text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClearTextOnFocus = false,
	}, row)

	local coords = text(row, {
		Text = coordText(wp.cf),
		TextSize = 11,
		TextColor3 = T.sub,
		Position = UDim2.fromOffset(40, 31),
		Size = UDim2.new(1, -190, 0, 16),
	})

	local function smallBtn(txt: string, color: Color3, w: number, xOff: number)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOff, 0.5, 0),
			Size = UDim2.fromOffset(w, 30),
			BackgroundColor3 = color,
			Text = txt,
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			AutoButtonColor = false,
		}, row)
		round(b, 8)
		hover(b, color)
		return b
	end

	local tpBtn = smallBtn("TP", T.accent2, 48, -88)
	local setBtn = smallBtn("Set", T.off, 40, -42)
	local delBtn = smallBtn("x", T.danger, 28, -8)

	rowRefs[#rowRefs + 1] = { row = row, stroke = rowStroke }

	row.MouseButton1Click:Connect(function()
		selected = i
		refreshSelection()
	end)

	nameBox.Focused:Connect(function()
		selected = i
		refreshSelection()
	end)
	nameBox.FocusLost:Connect(function()
		local n = string.match(nameBox.Text, "^%s*(.-)%s*$") or ""
		n = string.sub(n, 1, 24)
		if n == "" then n = wp.name end
		wp.name = n
		nameBox.Text = n
		refreshSelection()
	end)

	tpBtn.MouseButton1Click:Connect(function()
		selected = i
		refreshSelection()
		teleportTo(i)
	end)

	setBtn.MouseButton1Click:Connect(function()
		local cf = waypointCF()
		if not cf then
			toast("Karakter belum siap")
			return
		end
		wp.cf = cf
		coords.Text = coordText(wp.cf)
		selected = i
		refreshSelection()
		toast(wp.name .. " diperbarui")
	end)

	delBtn.MouseButton1Click:Connect(function()
		table.remove(waypoints, i)
		if selected == i then
			selected = math.min(i, #waypoints)
		elseif selected > i then
			selected -= 1
		end
		rebuildList()
	end)
end

rebuildList = function()
	for _, ref in ipairs(rowRefs) do
		ref.row:Destroy()
	end
	rowRefs = {}
	emptyLabel.Visible = (#waypoints == 0)
	for i, wp in ipairs(waypoints) do
		buildRow(i, wp)
	end
	refreshSelection()
end
end -- tutup do (Item ESP)

-- =====================================================
-- GUI: HALAMAN SETTINGS
-- =====================================================
local keyButtons: { [string]: any } = {}
local listening: { name: string, allowClear: boolean }? = nil

local function keyText(k: any): string
	return k and k.Name or "None"
end

local function refreshKeyUI()
	for name, btn in pairs(keyButtons) do
		if listening and listening.name == name then
			btn.Text = "Tekan tombol..."
		else
			btn.Text = keyText(settings[name])
		end
	end
	subtitle.Text = "Tekan [" .. keyText(settings.toggleKey) .. "] untuk hide / show"
	floatDesc.Text = "Lantai tak terlihat di bawah kaki. Naik: ["
		.. keyText(settings.floatUpKey) .. "]  Turun: [" .. keyText(settings.floatDownKey)
		.. "]. Atur di tab Settings."
end

local function addKeyRow(order: number, title: string, desc: string, name: string, allowClear: boolean)
	local card = makeCard(settingsPage, 64, order)
	text(card, {
		Text = title,
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.fromOffset(14, 9),
		Size = UDim2.new(1, -140, 0, 18),
	})
	text(card, {
		Text = desc,
		TextSize = 11,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 29),
		Size = UDim2.new(1, -140, 0, 30),
	})
	local btn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(108, 30),
		BackgroundColor3 = T.bg,
		Text = "",
		TextColor3 = T.text,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
	}, card)
	round(btn, 8)
	stroke(btn, T.accent, 1.5, 0.1)
	hover(btn, T.bg)
	keyButtons[name] = btn
	btn.MouseButton1Click:Connect(function()
		listening = { name = name, allowClear = allowClear }
		refreshKeyUI()
	end)
end

sectionLabel(settingsPage, 0, "Keybind")
addKeyRow(1, "Tombol Hide / Show", "Ganti jika bentrok dengan tombol game.", "toggleKey", false)
addKeyRow(2, "Tombol Simpan Waypoint", "Simpan posisi tanpa membuka panel. Backspace untuk mengosongkan.", "saveKey", true)
addKeyRow(3, "Tombol Teleport", "Teleport ke waypoint terpilih. Backspace untuk mengosongkan.", "tpKey", true)
addKeyRow(4, "Tombol Ganti Waypoint", "Pindah ke waypoint berikutnya. Backspace untuk mengosongkan.", "cycleKey", true)
addKeyRow(5, "Float: Naik", "Tahan untuk naik saat Float aktif. Backspace untuk mengosongkan.", "floatUpKey", true)
addKeyRow(6, "Float: Turun", "Tahan untuk turun saat Float aktif. Backspace untuk mengosongkan.", "floatDownKey", true)
refreshKeyUI()

local sizeCard = makeCard(settingsPage, 78, 7)
text(sizeCard, {
	Text = "Ukuran Panel",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 9),
	Size = UDim2.new(1, -28, 0, 18),
})
local sizeRow = new("Frame", {
	Position = UDim2.fromOffset(14, 38),
	Size = UDim2.new(1, -28, 0, 30),
	BackgroundTransparency = 1,
}, sizeCard)
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, sizeRow)

local function setPanelSize(w: number, h: number)
	panelW, panelH = clampSize(w, h)
	main.Size = UDim2.fromOffset(panelW, panelH)
end

for i, preset in ipairs({
	{ "Kecil", 460, 400 },
	{ "Sedang", 520, 450 },
	{ "Besar", 660, 580 },
}) do
	local b = new("TextButton", {
		LayoutOrder = i,
		Size = UDim2.new(1 / 3, -4, 1, 0),
		BackgroundColor3 = T.bg,
		Text = preset[1],
		TextColor3 = T.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		AutoButtonColor = false,
	}, sizeRow)
	round(b, 8)
	stroke(b, T.stroke, 1, 0.3)
	hover(b, T.bg)
	b.MouseButton1Click:Connect(function()
		setPanelSize(preset[2], preset[3])
	end)
end

local offAllBtn = makeButton(settingsPage, 8, "Matikan Semua Fitur", T.accent, 40)
hover(offAllBtn, T.accent)
offAllBtn.MouseButton1Click:Connect(function()
	disableAllFeatures()
end)

local unloadBtn = makeButton(settingsPage, 9, "Unload & Bersihkan Semua", T.off, 40)
text(settingsPage, {
	LayoutOrder = 10,
	Text = "Menghapus panel, mematikan semua fitur, mengembalikan speed/jump ke semula, menghapus lantai float dan ESP, dan memutus semua koneksi script. Waypoint juga ikut hilang.",
	TextSize = 11,
	TextColor3 = T.sub,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Size = UDim2.new(1, 0, 0, 56),
})

-- =====================================================
-- CONFIG
-- =====================================================
do
local MAX_SLOTS = 10
local KEY_NAMES = { "toggleKey", "saveKey", "tpKey", "cycleKey", "floatUpKey", "floatDownKey" }

local slots: { { name: string, data: any } } = {}
local remote: RemoteFunction? = nil
local includeWP = false

local rebuildSlots: () -> () = function() end

local function trim(s: string): string
	return string.match(s, "^%s*(.-)%s*$") or ""
end

local saveToken = 0
local function persist()
	if not remote then return end
	saveToken += 1
	local t = saveToken
	task.delay(2.5, function()
		if t ~= saveToken or unloaded or not remote then return end
		local ok, res = pcall(function()
			return (remote :: RemoteFunction):InvokeServer("save", slots)
		end)
		if not ok or res ~= true then
			toast("Gagal simpan ke server")
		end
	end)
end

local function snapshot(withWP: boolean): any
	local d: any = {
		v = 1,
		values = { speed = values.speed, jump = values.jump, freecam = values.freecam },
		state = {},
		keys = {},
		size = { panelW, panelH },
	}
	for k, v in pairs(state) do
		d.state[k] = v
	end
	for _, n in ipairs(KEY_NAMES) do
		local kc = settings[n]
		d.keys[n] = kc and kc.Name or false
	end
	if withWP then
		d.wps = {}
		for _, wp in ipairs(waypoints) do
			table.insert(d.wps, { name = wp.name, c = { wp.cf:GetComponents() } })
		end
	end
	return d
end

local function applySnapshot(d: any)
	if type(d.values) == "table" then
		for k in pairs(values) do
			local v = d.values[k]
			if type(v) == "number" and sliderSetters[k] then
				sliderSetters[k](v)
			end
		end
	end

	if type(d.keys) == "table" then
		for _, n in ipairs(KEY_NAMES) do
			local v = d.keys[n]
			if v == false then
				settings[n] = nil
			elseif type(v) == "string" then
				local ok, kc = pcall(function() return Enum.KeyCode[v] end)
				if ok and kc then settings[n] = kc end
			end
		end
		refreshKeyUI()
	end

	if type(d.size) == "table" and type(d.size[1]) == "number" and type(d.size[2]) == "number" then
		setPanelSize(d.size[1], d.size[2])
	end

	if type(d.wps) == "table" then
		table.clear(waypoints)
		for _, w in ipairs(d.wps) do
			if #waypoints >= MAX_WP then break end
			if type(w) == "table" and type(w.name) == "string" and type(w.c) == "table" and #w.c == 12 then
				table.insert(waypoints, { name = w.name, cf = CFrame.new(table.unpack(w.c)) })
			end
		end
		wpCounter = #waypoints
		selected = (#waypoints > 0) and 1 or 0
		rebuildList()
	end

	if type(d.state) == "table" then
		for key in pairs(state) do
			setFeature(key, d.state[key] == true)
		end
	end
end

local function summarize(d: any): string
	local on = 0
	for _, v in pairs(d.state or {}) do
		if v then on += 1 end
	end
	local s = string.format("Speed %d | Jump %d | %d fitur ON",
		(d.values and d.values.speed) or 0, (d.values and d.values.jump) or 0, on)
	if d.wps then
		s ..= " | " .. tostring(#d.wps) .. " WP"
	end
	return s
end

local cfgTop = makeCard(configPage, 168, 1)
text(cfgTop, {
	Text = "Simpan Konfigurasi",
	Font = Enum.Font.GothamBold,
	TextSize = 14,
	Position = UDim2.fromOffset(14, 10),
	Size = UDim2.new(0.6, -14, 0, 18),
})
local slotCount = text(cfgTop, {
	TextSize = 11,
	TextColor3 = T.sub,
	TextXAlignment = Enum.TextXAlignment.Right,
	Position = UDim2.new(0.6, 0, 0, 12),
	Size = UDim2.new(0.4, -14, 0, 14),
})
local modeLabel = text(cfgTop, {
	Text = "Memeriksa penyimpanan...",
	TextSize = 11,
	TextColor3 = T.sub,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Position = UDim2.fromOffset(14, 31),
	Size = UDim2.new(1, -28, 0, 14),
})

local nameInput = new("TextBox", {
	Position = UDim2.fromOffset(14, 54),
	Size = UDim2.new(1, -28, 0, 28),
	BackgroundColor3 = T.bg,
	Text = "",
	PlaceholderText = "Nama save (opsional)",
	PlaceholderColor3 = T.sub,
	TextColor3 = T.text,
	Font = Enum.Font.GothamMedium,
	TextSize = 13,
	ClearTextOnFocus = false,
	BorderSizePixel = 0,
}, cfgTop)
round(nameInput, 8)
stroke(nameInput, T.stroke, 1, 0.3)

text(cfgTop, {
	Text = "Sertakan waypoint",
	Font = Enum.Font.GothamMedium,
	TextSize = 12,
	Position = UDim2.fromOffset(14, 92),
	Size = UDim2.new(1, -90, 0, 18),
})
makeSwitch(cfgTop, UDim2.new(1, -14, 0, 101), false, function(on)
	includeWP = on
end)

local saveNewBtn = new("TextButton", {
	Position = UDim2.fromOffset(14, 122),
	Size = UDim2.new(1, -28, 0, 34),
	BackgroundColor3 = T.accent,
	Text = "+ Simpan Konfigurasi Sekarang",
	TextColor3 = WHITE,
	Font = Enum.Font.GothamBold,
	TextSize = 13,
	AutoButtonColor = false,
}, cfgTop)
round(saveNewBtn, 10)
hover(saveNewBtn, T.accent)

local cfgEmpty = text(configPage, {
	LayoutOrder = 5,
	Text = "Belum ada save. Atur fitur sesukamu, lalu tekan \"Simpan Konfigurasi Sekarang\".",
	TextSize = 12,
	TextColor3 = T.sub,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	Size = UDim2.new(1, 0, 0, 44),
})

local slotRows: { any } = {}

local function buildSlotRow(i: number, slot: { name: string, data: any })
	local row = new("Frame", {
		LayoutOrder = 10 + i,
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundColor3 = T.card,
		BorderSizePixel = 0,
	}, configPage)
	round(row, 12)
	stroke(row, T.stroke, 1, 0.5)
	slotRows[#slotRows + 1] = row

	local nameBox = new("TextBox", {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -156, 0, 20),
		BackgroundTransparency = 1,
		Text = slot.name,
		PlaceholderText = "Nama save",
		TextColor3 = T.text,
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ClearTextOnFocus = false,
	}, row)

	text(row, {
		Text = summarize(slot.data),
		TextSize = 11,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(12, 31),
		Size = UDim2.new(1, -156, 0, 28),
	})

	local function smallBtn(txt: string, color: Color3, w: number, xOff: number)
		local b = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, xOff, 0.5, 0),
			Size = UDim2.fromOffset(w, 30),
			BackgroundColor3 = color,
			Text = txt,
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			AutoButtonColor = false,
		}, row)
		round(b, 8)
		hover(b, color)
		return b
	end

	local loadBtn = smallBtn("Load", T.accent2, 46, -94)
	local overBtn = smallBtn("Timpa", T.off, 46, -42)
	local delBtn = smallBtn("x", T.danger, 28, -8)

	nameBox.FocusLost:Connect(function()
		local n = string.sub(trim(nameBox.Text), 1, 24)
		if n == "" then n = slot.name end
		slot.name = n
		nameBox.Text = n
		persist()
	end)

	loadBtn.MouseButton1Click:Connect(function()
		applySnapshot(slot.data)
		toast("Load: " .. slot.name)
	end)

	overBtn.MouseButton1Click:Connect(function()
		slot.data = snapshot(includeWP)
		rebuildSlots()
		persist()
		toast(slot.name .. " ditimpa")
	end)

	local armedDel = false
	delBtn.MouseButton1Click:Connect(function()
		if not armedDel then
			armedDel = true
			delBtn.Text = "?"
			task.delay(2, function()
				if armedDel and delBtn.Parent then
					armedDel = false
					delBtn.Text = "x"
				end
			end)
		else
			table.remove(slots, i)
			rebuildSlots()
			persist()
			toast("Save dihapus")
		end
	end)
end

rebuildSlots = function()
	for _, r in ipairs(slotRows) do
		r:Destroy()
	end
	slotRows = {}
	cfgEmpty.Visible = (#slots == 0)
	slotCount.Text = tostring(#slots) .. " / " .. tostring(MAX_SLOTS)
	for i, s in ipairs(slots) do
		buildSlotRow(i, s)
	end
end

saveNewBtn.MouseButton1Click:Connect(function()
	if #slots >= MAX_SLOTS then
		toast("Maksimal " .. tostring(MAX_SLOTS) .. " save")
		return
	end
	local n = string.sub(trim(nameInput.Text), 1, 24)
	if n == "" then n = "Config " .. tostring(#slots + 1) end
	table.insert(slots, { name = n, data = snapshot(includeWP) })
	nameInput.Text = ""
	rebuildSlots()
	persist()
	toast("Tersimpan: " .. n)
end)

local function updateMode()
	modeLabel.Text = remote and "Penyimpanan: permanen (DataStore)"
		or "Penyimpanan: sesi ini saja (hilang saat keluar)"
end

rebuildSlots()

task.spawn(function()
	local r = ReplicatedStorage:WaitForChild("CP_ConfigRemote", 5)
	if r and r:IsA("RemoteFunction") and not unloaded then
		local ok, res = pcall(function() return r:InvokeServer("load") end)
		if ok and type(res) == "table" then
			remote = r
			for _, s in ipairs(res) do
				if type(s) == "table" and type(s.name) == "string" and type(s.data) == "table"
					and type(s.data.values) == "table" and type(s.data.state) == "table" then
					table.insert(slots, { name = s.name, data = s.data })
				end
			end
			if not unloaded then rebuildSlots() end
		end
	end
	if not unloaded then updateMode() end
end)

end

-- =====================================================
-- KEYBIND
-- =====================================================
track(UIS.InputBegan:Connect(function(input, processed)
	if listening then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local info = listening
			listening = nil
			if input.KeyCode == Enum.KeyCode.Escape then
				-- batal
			elseif input.KeyCode == Enum.KeyCode.Backspace and info.allowClear then
				settings[info.name] = nil
			else
				settings[info.name] = input.KeyCode
			end
			refreshKeyUI()
		end
		return
	end

	if processed then return end

	local kc = input.KeyCode
	if kc == Enum.KeyCode.Unknown then return end

	if kc == settings.toggleKey then
		if uiState == "open" then
			setUIState("hidden")
		else
			setUIState("open")
		end
	elseif kc == settings.saveKey then
		saveWaypoint()
	elseif kc == settings.tpKey then
		teleportSelected()
	elseif kc == settings.cycleKey then
		cycleWaypoint()
	end
end))

-- =====================================================
-- UNLOAD
-- =====================================================
local function unload()
	if unloaded then return end
	unloaded = true

	disableAllFeatures()
	destroyPlatform()
	clearEsp()

	modal.Modal = false
	if mouseConn then
		mouseConn:Disconnect()
		mouseConn = nil
	end
	UIS.MouseBehavior = Enum.MouseBehavior.Default

	for _, c in ipairs(conns) do
		c:Disconnect()
	end
	table.clear(conns)

	gui:Destroy()
end

unloadFn = unload

local armed = false
unloadBtn.MouseButton1Click:Connect(function()
	if not armed then
		armed = true
		unloadBtn.Text = "Klik lagi untuk konfirmasi"
		tween(unloadBtn, { BackgroundColor3 = T.danger }, 0.15)
		task.delay(3, function()
			if armed and not unloaded then
				armed = false
				unloadBtn.Text = "Unload & Bersihkan Semua"
				tween(unloadBtn, { BackgroundColor3 = T.off }, 0.15)
			end
		end)
	else
		unload()
	end
end)

-- =====================================================
-- START (LANGSUNG TAMPILKAN UI UTAMA)
-- =====================================================
rebuildList()
selectTab("Movement")
refreshActive()
-- Animasi welcome: splash muncul dulu, setelah selesai baru menu UI muncul
setUIState("hidden")

task.spawn(function()
	local BACK_OUT = TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

	local splash = new("Frame", {
		Name = "Welcome",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(320, 180),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 30,
	}, gui)
	round(splash, 18)
	grad(splash, T.bgTop, T.bg, 90)
	local splashStroke = stroke(splash, WHITE, 1.5, 0.3)
	grad(splashStroke, T.accent, T.accent2, 45)
	local splashScale = new("UIScale", { Scale = 0.5 }, splash)

	local splashLogo = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 18),
		Size = UDim2.fromOffset(46, 46),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 31,
	}, splash)
	round(splashLogo, 13)
	grad(splashLogo, T.accent, T.accent2, 45)
	text(splashLogo, {
		Text = "U",
		Font = Enum.Font.GothamBold,
		TextSize = 26,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 32,
	})

	local splashTitle = text(splash, {
		Text = "WELCOME TUAN MUDA",
		Font = Enum.Font.GothamBold,
		TextSize = 17,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Position = UDim2.fromOffset(0, 72),
		Size = UDim2.new(1, 0, 0, 22),
		ZIndex = 31,
	})

	local splashName = text(splash, {
		Text = "R4MEN",
		Font = Enum.Font.GothamBold,
		TextSize = 26,
		TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Position = UDim2.fromOffset(0, 94),
		Size = UDim2.new(1, 0, 0, 32),
		ZIndex = 31,
	})
	grad(splashName, T.accent, T.accent2, 0)

	local barTrack = new("Frame", {
		Position = UDim2.fromOffset(40, 138),
		Size = UDim2.new(1, -80, 0, 6),
		BackgroundColor3 = T.off,
		BorderSizePixel = 0,
		ZIndex = 31,
	}, splash)
	round(barTrack, 3)
	local barFill = new("Frame", {
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = WHITE,
		BorderSizePixel = 0,
		ZIndex = 32,
	}, barTrack)
	round(barFill, 3)
	grad(barFill, T.accent, T.accent2, 0)

	local splashStatus = text(splash, {
		Text = "Memuat menu...",
		TextSize = 10,
		TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextTransparency = 1,
		Position = UDim2.fromOffset(0, 152),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 31,
	})

	-- masuk
	TweenService:Create(splashScale, BACK_OUT, { Scale = 1 }):Play()
	task.wait(0.3)
	tween(splashTitle, { TextTransparency = 0 }, 0.3)
	task.wait(0.15)
	tween(splashName, { TextTransparency = 0 }, 0.3)
	tween(splashStatus, { TextTransparency = 0 }, 0.3)
	task.wait(0.2)

	-- loading bar
	TweenService:Create(
		barFill,
		TweenInfo.new(2.5, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ Size = UDim2.fromScale(1, 1) }
	):Play()
	task.wait(2.4)

	-- keluar
	TweenService:Create(
		splashScale,
		TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In),
		{ Scale = 0 }
	):Play()
	task.wait(0.3)
	splash:Destroy()
	if unloaded then return end

	-- menu UI muncul setelah welcome selesai
	local menuScale = new("UIScale", { Scale = 0.6 }, main)
	setUIState("open")
	TweenService:Create(menuScale, BACK_OUT, { Scale = 1 }):Play()
end)