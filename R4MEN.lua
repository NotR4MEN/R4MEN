local SRC = [==[
-- ===== AUTO-RERUN: HANYA DI GAME YANG SAMA =====
do
	local q = queue_on_teleport or queueonteleport
		or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	if q and readfile and isfile and isfile("R4MEN_auto.lua") then
		local gid = tostring(game.GameId)
		pcall(q, "local GID = " .. gid .. "\n" .. [[
			if not game:IsLoaded() then game.Loaded:Wait() end
			if game.GameId ~= GID then return end
			task.wait(2)
			local lp = game:GetService("Players").LocalPlayer
			local pg = lp and lp:WaitForChild("PlayerGui", 10)
			if pg and pg:FindFirstChild("UniversalUrbee") then return end
			local ok, e = pcall(function() loadstring(readfile("R4MEN_auto.lua"))() end)
			if not ok then warn("R4MEN auto-run gagal: " .. tostring(e)) end
		]])
	end
end
-- ================================================

-- LocalScript: taruh di StarterPlayer > StarterPlayerScripts
-- Universal R4MEN v1 (+ tab Visual: ESP NPC/Hewan, Fullbright, FOV, Anti-AFK aktif otomatis; daftar pemain klik-untuk-TP)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

for _, n in ipairs({ "UniversalUrbee", "ControlPanel", "UU_ITEMS", "UU_NPC", "UU_RARITY" }) do
	local old = playerGui:FindFirstChild(n)
	if old then old:Destroy() end
end

-- =====================================================
-- STATE
-- =====================================================
local settings: { [string]: any } = {
	saveFolder = "R4MEN", -- nama folder penyimpanan di dalam folder workspace executor (boleh diganti)
	clickTp = true, -- klik/tap label ESP (item & NPC) = teleport ke sana. Ubah ke false untuk mematikan
	clickNeedsShift = false, -- true = harus menahan Shift kiri saat klik label (menghindari klik tembus ke game)
	toggleKey = Enum.KeyCode.K,
	saveKey = Enum.KeyCode.LeftBracket,
	tpKey = Enum.KeyCode.RightBracket,
	cycleKey = Enum.KeyCode.Quote,
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
	antiAfk = true, -- aktif sejak awal; bisa dimatikan lewat tombol di tab Visual
	fullbright = false,
	noFog = false,
	fov = false,
}

local values: { [string]: number } = {
	speed = 50,
	jump = 100,
	freecam = 60,
	bright = 2,
	clock = 14,
	fov = 70,
	npcDist = 2000,
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
		if hrp:GetAttribute("R4Fling") then return end
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
-- Nilai CanCollide asli dicatat per part, lalu dikembalikan persis saat Noclip/WalkFling
-- dimatikan (part yang dari awal non-collide, mis. aksesori, tidak ikut diubah).
-- Dibungkus do...end supaya tidak menambah jumlah local di level atas.
local noclipStep: () -> ()
local restoreNoclip: () -> ()
do
	local origCollide: { [BasePart]: boolean } = {}

	noclipStep = function()
		local char = player.Character
		if not char then return end
		for _, part in ipairs(char:GetDescendants()) do
			if part:IsA("BasePart") and part.CanCollide then
				if origCollide[part] == nil then
					origCollide[part] = true
				end
				part.CanCollide = false
			end
		end
	end

	-- Bagian inti karakter yang selalu harus kembali bisa-tabrak setelah Noclip/WalkFling dimatikan
	local CORE_PARTS: { [string]: boolean } = {
		HumanoidRootPart = true, Head = true, Torso = true, UpperTorso = true, LowerTorso = true,
	}

	restoreNoclip = function()
		for part, was in pairs(origCollide) do
			if part.Parent then
				part.CanCollide = was
			end
		end
		table.clear(origCollide)
		-- Pengaman: setelah mati/respawn, catatan lama bisa tidak mencakup bagian karakter yang baru,
		-- sehingga tembok masih tembus walau toggle sudah OFF. Bagian inti dikembalikan langsung.
		local char = player.Character
		if char then
			for _, part in ipairs(char:GetChildren()) do
				if part:IsA("BasePart") and CORE_PARTS[part.Name] then
					part.CanCollide = true
				end
			end
		end
	end
end

-- WalkFling: velocity besar hanya dipasang sesaat (untuk direplikasi ke pemain lain),
-- lalu langsung dikembalikan sebelum fisika lokal berjalan.
-- PERBAIKAN BUG (tidak bisa lompat & jalan pelan):
--  1. Spike HANYA dikirim saat ada pemain lain dalam jarak FLING_RANGE. Sebelumnya spike
--     ditulis di SETIAP frame, sehingga velocity karaktermu terus-menerus ditimpa dan
--     Humanoid tidak pernah bisa menumpuk kecepatan/lompatan.
--  2. Pengaman ">500" dulu membuat velocity jadi Vector3.zero (karakter "dikunci" diam).
--     Sekarang memakai velocity aman terakhir (lastSafe) sehingga gerakan tidak terhenti.
--  3. Speed-assist tidak lagi membaca/menulis velocity saat spike sedang aktif (atribut R4Fling).
local flingRunning = false
local startFling: () -> ()

do
	local FLING_RANGE = 12

	local function playerNearby(hrp: BasePart): boolean
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local ch = p.Character
				local r = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
				if r and (r.Position - hrp.Position).Magnitude <= FLING_RANGE then
					return true
				end
			end
		end
		return false
	end

	startFling = function()
		if flingRunning then return end
		flingRunning = true
		task.spawn(function()
			local lastSafe = Vector3.zero
			local lastHrp: BasePart? = nil

			-- Satu iterasi spike. Dipisah supaya bisa dibungkus pcall: kalau terjadi error,
			-- flingRunning TIDAK macet di true dan velocity/atribut selalu dibersihkan.
			local function step()
				RunService.Heartbeat:Wait()
				if not state.walkFling or unloaded then return end -- dimatikan saat menunggu
				local hrp = getRoot()
				local hum = getHum()
				if not (hrp and hrp.Parent and hum and hum.Health > 0)
					or state.freecam or not playerNearby(hrp) then
					return
				end
				lastHrp = hrp
				local vel = hrp.AssemblyLinearVelocity
				if vel.Magnitude > 500 then
					vel = lastSafe
				else
					lastSafe = vel
				end
				hrp:SetAttribute("R4Fling", true)
				hrp.AssemblyLinearVelocity = vel * 10000 + Vector3.new(0, 10000, 0)
				RunService.RenderStepped:Wait()
				if hrp.Parent then
					hrp.AssemblyLinearVelocity = vel
				end
				RunService.Stepped:Wait()
				if hrp.Parent then
					-- kalau dimatikan / karakter mati di tengah iterasi, jangan tambahkan dorongan lagi
					local stillOn = state.walkFling and not unloaded and hum.Health > 0
					hrp.AssemblyLinearVelocity = stillOn and (vel + Vector3.new(0, 0.1, 0)) or vel
					if not stillOn then hrp:SetAttribute("R4Fling", nil) end
				end
			end

			while state.walkFling and not unloaded do
				local ok, err = pcall(step)
				if not ok then
					warn("WalkFling error: " .. tostring(err))
					task.wait(0.1)
				end
			end

			-- BERSIHKAN TOTAL saat dimatikan: atribut, velocity ekstrem, dan tabrakan karakter.
			local hrp = getRoot() or lastHrp
			if hrp and hrp.Parent then
				hrp:SetAttribute("R4Fling", nil)
				if hrp.AssemblyLinearVelocity.Magnitude > 500 then
					hrp.AssemblyLinearVelocity = Vector3.zero
				end
			end
			if not state.noclip then
				restoreNoclip()
			end
			flingRunning = false
		end)
	end
end

track(RunService.Stepped:Connect(function(_, dt)
	if state.float then
		updateFloat(dt)
	end
	if state.noclip or state.walkFling then
		noclipStep()
	end
	-- Watchdog: saat WalkFling OFF, velocity ekstrem sisa spike (mis. karena mati/reset di tengah
	-- iterasi) langsung dinolkan supaya tidak terus melempar pemain lain.
	if not state.walkFling then
		local hrp = getRoot()
		if hrp then
			if hrp:GetAttribute("R4Fling") then hrp:SetAttribute("R4Fling", nil) end
			if hrp.AssemblyLinearVelocity.Magnitude > 500 then
				hrp.AssemblyLinearVelocity = Vector3.zero
				hrp.AssemblyAngularVelocity = Vector3.zero
			end
		end
	end
end))

-- Karakter baru (mati / reset): kalau WalkFling OFF, pastikan bersih dari sisa efek karakter lama.
track(player.CharacterAdded:Connect(function()
	if state.walkFling then return end
	if not state.noclip then
		restoreNoclip()
	end
	task.defer(function()
		local hrp = getRoot()
		if hrp and not state.walkFling then
			hrp:SetAttribute("R4Fling", nil)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end)
end))

-- =====================================================
-- EFEK TOGGLE & RESET ALL
-- =====================================================
local switches: { [string]: { Set: (boolean) -> () } } = {}
local setEsp: (boolean) -> () = function() end
local setFreecam: (boolean) -> () = function() end
local refreshActive: () -> () = function() end
local clearMarkings: () -> () = function() end

-- Hook fitur tab Visual (diisi di bagian GUI Visual; satu tabel = hemat jatah 200 local)
local ext: { [string]: (boolean) -> () } = {
	npc = function() end,
	light = function() end,
	fog = function() end,
	fov = function() end,
}

local effects: { [string]: (boolean) -> () } = {
	speed = function(on) if not on then restoreSpeed() end end,
	jump = function(on) if not on then restoreJump() end end,
	infJump = function() end,
	float = function(on)
		if on then floatY = nil else destroyPlatform() end
	end,
	noclip = function(on) if not on then restoreNoclip() end end,
	walkFling = function(on)
		if on then
			startFling()
		elseif not state.noclip then
			restoreNoclip()
		end
	end,
	esp = function(on) setEsp(on) end,
	freecam = function(on) setFreecam(on) end,
	antiAfk = function() end,
	fullbright = function(on) ext.light(on) end,
	noFog = function(on) ext.fog(on) end,
	fov = function(on) ext.fov(on) end,
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
		-- Anti-AFK sengaja dikecualikan: "Matikan Semua" tidak boleh membuatmu ter-kick karena idle
		-- (saat Unload handler-nya ikut diputus). Matikan manual lewat tombolnya.
		if key ~= "antiAfk" then
			state[key] = false
			if switches[key] then
				switches[key].Set(false)
			end
		end
	end
	restoreSpeed()
	restoreJump()
	destroyPlatform()
	restoreNoclip()
	setEsp(false)
	setFreecam(false)
	ext.npc(false)
	ext.light(false)
	ext.fog(false)
	ext.fov(false)
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

-- exactPlayer (opsional): pemain pasti dari daftar klik; kalau kosong, cari lewat potongan nama.
local function teleportToUsername(name: string, exactPlayer: Player?)
	local targetPlayer = exactPlayer
	local lowerName = string.lower(name)

	if not targetPlayer then
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
	-- pakai nomor terkecil yang belum dipakai (hapus semua -> mulai dari 1 lagi)
	local used: { [string]: boolean } = {}
	for _, w in ipairs(waypoints) do
		used[w.name] = true
	end
	local n = 1
	while used["Waypoint " .. tostring(n)] do
		n += 1
	end
	wpCounter = n
	table.insert(waypoints, { name = "Waypoint " .. tostring(n), cf = cf })
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
				local col = Color3.fromRGB(80, 200, 255) -- BIRU MUDA = PEMAIN
				o.hl.FillColor = col
				o.hl.OutlineColor = col
				o.name.Text = "[P] " .. p.Name
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
task.spawn(getControls) -- siapkan lebih awal di latar belakang supaya free cam tidak menunggu

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

		cam.CameraType = Enum.CameraType.Scriptable
		RunService:BindToRenderStep(FC_BIND, Enum.RenderPriority.Camera.Value + 1, fcStep)
		fcBound = true

		task.spawn(function()
			local c = getControls()
			if c and fcBound and not unloaded then
				pcall(function() c:Disable() end)
			end
		end)
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

-- Lencana versi di samping judul
-- Naikkan VERSION HANYA untuk update besar; update kecil tidak mengubah versi.
do
	local VERSION = "v1"
	local verBadge = new("Frame", {
		Position = UDim2.fromOffset(54 + 124, 11),
		Size = UDim2.fromOffset(34, 16),
		BackgroundColor3 = T.card,
		BorderSizePixel = 0,
	}, header)
	round(verBadge, 8)
	local verStroke = stroke(verBadge, WHITE, 1, 0.3)
	grad(verStroke, T.accent, T.accent2, 45)
	text(verBadge, {
		Text = VERSION,
		Font = Enum.Font.GothamBold,
		TextSize = 10,
		TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Center,
		Size = UDim2.fromScale(1, 1),
	})
	-- ikuti lebar judul sebenarnya supaya lencana selalu menempel di ujung teks
	local function place()
		verBadge.Position = UDim2.fromOffset(54 + title.TextBounds.X + 8, 11)
	end
	place()
	title:GetPropertyChangedSignal("TextBounds"):Connect(place)
end

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

-- Tombol X harus DOUBLE TAP (dua klik dalam 0.8 detik) supaya tidak tertutup karena salah pencet.
-- Klik pertama hanya "mengaktifkan" (tombol memerah + info); klik kedua baru menutup.
local CLOSE_DOUBLE_TAP = 0.8
local closeArmedAt = 0
local closeOrigBg = hideBtn.BackgroundColor3
hideBtn.MouseButton1Click:Connect(function()
	local now = os.clock()
	if closeArmedAt > 0 and now - closeArmedAt <= CLOSE_DOUBLE_TAP then
		closeArmedAt = 0
		hideBtn.BackgroundColor3 = closeOrigBg
		-- Tombol X = tutup sepenuhnya (unload). Untuk sekadar menyembunyikan UI pakai keybind K
		-- atau tombol "-" (minimize).
		if unloadFn then
			unloadFn()
		else
			disableAllFeatures()
			setUIState("hidden")
		end
		return
	end
	closeArmedAt = now
	hideBtn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	tween(hideBtn, { BackgroundColor3 = closeOrigBg }, CLOSE_DOUBLE_TAP)
	toast("Tap X sekali lagi (double tap) untuk menutup script")
	task.delay(CLOSE_DOUBLE_TAP, function()
		if closeArmedAt == now then closeArmedAt = 0 end
	end)
end)

-- =====================================================
-- TOAST
-- =====================================================
refreshActive = function()
	local n = 0
	for k, v in pairs(state) do
		if v and k ~= "antiAfk" then n += 1 end -- Anti-AFK tidak dihitung (aktif sejak awal)
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
newPage("ESP") -- halaman ESP sendiri (ESP NPC/Hewan + Loot & Item ESP); diakses lewat pages.ESP
local configPage = newPage("Config")
local settingsPage = newPage("Settings")

for i, name in ipairs({ "Movement", "Physics", "Visual", "ESP", "Teleport", "Config", "Settings" }) do
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

local function addSliderCard(page: Instance, order: number, title: string, hint: string, key: string, min: number, max: number, hardMax: number, bare: boolean?)
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
	if not bare then -- bare = kartu slider tanpa saklar (nilai dipakai fitur lain)
		switches[key] = makeSwitch(card, UDim2.new(1, -14, 0, 25), false, function(on)
			state[key] = on
			effects[key](on)
			refreshActive()
		end, cardGlow(card))
	end

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
-- GUI: HALAMAN VISUAL (Fullbright, FOV, Anti-AFK) -- blok 1
-- Dibungkus do...end supaya local-nya tidak menghabiskan jatah 200 local.
-- =====================================================
do
	local visualPage = newPage("Visual")

	sectionLabel(visualPage, 0, "Pencahayaan")
	addToggleCard(visualPage, 1, "Fullbright", "Terang penuh tanpa bayangan. Atur kecerahan dan jam di bawah.", "fullbright")
	addSliderCard(visualPage, 2, "Kecerahan", "Brightness 1-10 (bawaan game biasanya 1-3)", "bright", 1, 10, 10, true)
	addSliderCard(visualPage, 3, "Jam Dunia", "1-24 (12 = siang, 24 = tengah malam)", "clock", 1, 24, 24, true)
	addToggleCard(visualPage, 4, "Hilangkan Kabut", "Menghapus fog dan haze agar pandangan jauh jelas.", "noFog")

	sectionLabel(visualPage, 5, "Kamera")
	addSliderCard(visualPage, 6, "FOV", "Bawaan Roblox: 70", "fov", 30, 120, 120)

	-- ESP NPC / Hewan ada di tab ESP (satu tempat dengan scan barang) -- lihat blok 2

	sectionLabel(visualPage, 10, "Utilitas")
	addToggleCard(visualPage, 11, "Anti-AFK", "Mencegah kick karena diam 20 menit. Aktif sejak awal.", "antiAfk")
	switches.antiAfk.Set(true)

	-- ---------- Fullbright / kabut / FOV ----------
	local Lighting = game:GetService("Lighting")
	local L: any = Lighting
	local lightOrig: any = nil
	local fogOrig: any = nil
	local fovOrig: number? = nil

	local function setProp(obj: any, prop: string, v: any)
		if obj[prop] ~= v then
			obj[prop] = v
		end
	end

	ext.light = function(on: boolean)
		if on then
			if not lightOrig then
				lightOrig = {
					Brightness = L.Brightness,
					ClockTime = L.ClockTime,
					Ambient = L.Ambient,
					OutdoorAmbient = L.OutdoorAmbient,
					GlobalShadows = L.GlobalShadows,
				}
			end
		elseif lightOrig then
			local o = lightOrig
			lightOrig = nil
			for k, v in pairs(o) do
				pcall(function() L[k] = v end)
			end
		end
	end

	ext.fog = function(on: boolean)
		if on then
			if not fogOrig then
				local atm = Lighting:FindFirstChildOfClass("Atmosphere")
				fogOrig = {
					FogEnd = L.FogEnd,
					FogStart = L.FogStart,
					atm = atm,
					density = atm and (atm :: any).Density,
					haze = atm and (atm :: any).Haze,
				}
			end
		elseif fogOrig then
			local o = fogOrig
			fogOrig = nil
			pcall(function()
				L.FogEnd = o.FogEnd
				L.FogStart = o.FogStart
				if o.atm and o.atm.Parent then
					o.atm.Density = o.density
					o.atm.Haze = o.haze
				end
			end)
		end
	end

	ext.fov = function(on: boolean)
		local cam = workspace.CurrentCamera
		if on then
			if cam and not fovOrig then fovOrig = cam.FieldOfView end
		else
			if cam and fovOrig then cam.FieldOfView = fovOrig end
			fovOrig = nil
		end
	end

	-- Ditulis ulang tiap frame supaya tidak ditimpa script day-night / sprint milik game.
	track(RunService.RenderStepped:Connect(function()
		if unloaded then return end

		if state.fullbright then
			if not lightOrig then ext.light(true) end
			local lv = math.clamp(0.35 + values.bright * 0.13, 0, 1)
			local amb = Color3.new(lv, lv, lv)
			setProp(L, "Brightness", values.bright)
			setProp(L, "ClockTime", values.clock % 24)
			setProp(L, "Ambient", amb)
			setProp(L, "OutdoorAmbient", amb)
			setProp(L, "GlobalShadows", false)
		end

		if state.noFog then
			if not fogOrig then ext.fog(true) end
			setProp(L, "FogEnd", 1e9)
			setProp(L, "FogStart", 0)
			local atm: any = Lighting:FindFirstChildOfClass("Atmosphere")
			if atm then
				setProp(atm, "Density", 0)
				setProp(atm, "Haze", 0)
			end
		end

		if state.fov then
			local cam = workspace.CurrentCamera
			if cam then
				if not fovOrig then fovOrig = cam.FieldOfView end
				setProp(cam, "FieldOfView", values.fov)
			end
		end
	end))

	-- ---------- Anti-AFK ----------
	local VirtualUser = game:GetService("VirtualUser")
	track(player.Idled:Connect(function()
		if unloaded or not state.antiAfk then return end
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new(0, 0))
		end)
	end))
end

-- =====================================================
-- GUI: ESP NPC / HEWAN -- blok 2
-- Pola sama dengan Item ESP: SCAN -> daftar nama unik -> centang yang mau ditandai.
-- Pelacakan live lewat DescendantAdded/Removing; visual hanya untuk yang dipilih,
-- dalam jarak slider, dan dibatasi NPC terdekat (Highlight Roblox maks. ~31 sekaligus).
-- =====================================================
do
	local NPC_COL = Color3.fromRGB(255, 176, 72)
	local NPC_MAX = math.huge      -- tanpa batas: semua NPC terpilih dalam jarak ditandai (label nama+jarak)
	local NPC_HL_MAX = 30          -- siluet: batas keras mesin Roblox ~31 Highlight sekaligus (sisanya tetap berlabel)
	local NPC_ROW_LIMIT = math.huge -- tanpa batas baris daftar
	local ROWS_PER_PASS = 30       -- baris baru dibuat bertahap (30/langkah) agar layar tidak freeze
	local NPC_CLASS: { [string]: boolean } = { Humanoid = true, AnimationController = true }

	local N: any = {
		groups = {}, byModel = {}, order = {}, sel = {}, rows = {}, vis = {},
		folder = nil, addConn = nil, remConn = nil,
		scanning = false, scanned = false, dirty = false, orderDirty = true,
		acc = 0, acc2 = 0, interval = 0.15, cand = {}, cat = "Semua",
		shown = 0, inRange = 0, selTotal = 0, base = "", err = nil, live = false,
		setStatus = function() end, -- diisi di bagian UI
	}

	-- ---------- NAMA KUSTOM NPC (alias, disimpan per game) ----------
	-- Contoh: "John" -> "1 John (jual)". Hanya tampilan: pilihan/centang tetap memakai nama asli.
	N.alias = {}
	do
		local HttpSvc = game:GetService("HttpService")
		local aliasPath = tostring(settings.saveFolder) .. "/npc_alias_" .. tostring(game.GameId) .. ".json"
		if readfile and isfile and isfile(aliasPath) then
			local okA, d = pcall(function() return HttpSvc:JSONDecode(readfile(aliasPath)) end)
			if okA and type(d) == "table" then
				for k, v in pairs(d) do
					if type(k) == "string" and type(v) == "string" and v ~= "" then N.alias[k] = v end
				end
			end
		end
		N.saveAlias = function()
			if not writefile then return end
			if makefolder and isfolder and not isfolder(settings.saveFolder) then
				pcall(makefolder, settings.saveFolder)
			end
			pcall(function() writefile(aliasPath, HttpSvc:JSONEncode(N.alias)) end)
		end

		-- Centang NPC (per game): dimuat lagi saat script jalan; ESP NPC langsung menandai yang sudah dicentang.
		local selPath = tostring(settings.saveFolder) .. "/npc_sel_" .. tostring(game.GameId) .. ".json"
		if readfile and isfile and isfile(selPath) then
			local okS, d = pcall(function() return HttpSvc:JSONDecode(readfile(selPath)) end)
			if okS and type(d) == "table" and type(d.sel) == "table" then
				for _, nm in ipairs(d.sel) do
					if type(nm) == "string" and nm ~= "" then N.sel[nm] = true end
				end
			end
		end
		N.saveSel = function()
			if not writefile then return end
			local names = {}
			for nm, v in pairs(N.sel) do
				if v then names[#names + 1] = nm end
			end
			if makefolder and isfolder and not isfolder(settings.saveFolder) then
				pcall(makefolder, settings.saveFolder)
			end
			pcall(function() writefile(selPath, HttpSvc:JSONEncode({ sel = names })) end)
		end
	end
	N.display = function(name: string): string
		return N.alias[name] or name
	end
	-- Urut alami: "2 Albert" sebelum "10 Budi" (angka dipadatkan supaya urutannya numerik)
	N.sortKey = function(s: string): string
		return (string.lower(s):gsub("%d+", function(d) return string.rep("0", math.max(0, 9 - #d)) .. d end))
	end

	local function npcRootOf(m: Model): BasePart?
		local r = m:FindFirstChild("HumanoidRootPart")
		if r and r:IsA("BasePart") then return r end
		local p = m.PrimaryPart
		if p then return p end
		return m:FindFirstChildWhichIsA("BasePart")
	end

	-- ---------- kategori (tebakan dari nama model + teks tombol interaksi NPC) ----------
	local CAT_ANIMAL = { "cat", "dog", "pig", "cow", "hen", "duck", "goat", "deer", "bear", "wolf", "fox", "bird", "crow", "owl", "bat", "rat",
		"fish", "frog", "lion", "ape", "ox", "elk", "yak", "emu", "sheep", "horse", "boar", "mouse", "snake", "tiger", "zebra", "hippo",
		"croc", "monkey", "elephant", "giraffe", "buffalo", "rabbit", "hare", "squirrel", "turkey", "chicken", "rooster", "camel", "moose",
		"bison", "cheetah", "leopard", "panther", "jaguar", "gorilla", "rhino", "hyena", "eagle", "hawk", "falcon", "vulture", "parrot",
		"penguin", "seal", "whale", "shark", "dolphin", "turtle", "lizard", "gecko", "crab", "kangaroo", "koala", "panda", "otter", "beaver",
		"badger", "skunk", "raccoon", "possum", "lynx", "coyote", "jackal", "animal", "creature", "wildlife", "pony", "donkey", "mule", "llama",
		"alpaca", "kucing", "anjing", "rusa", "gajah", "singa", "harimau", "babi", "sapi", "ayam", "kambing", "kelinci", "ular", "burung",
		"ikan", "kerbau", "kuda", "domba", "hewan", "monyet", "buaya", "beruang", "serigala" }
	local CAT_SHOP = { "shop", "store", "merchant", "vendor", "trader", "seller", "dealer", "buyer", "market", "toko", "penjual", "pedagang",
		"blacksmith", "smith", "armorer", "weaponsmith", "cashier", "bazaar" }
	local CAT_QUEST = { "quest", "mission", "dialog", "dialogue", "guide", "tutorial", "questgiver", "misi", "elder", "villager", "mentor",
		"trainer", "instructor", "teacher", "storyteller", "wizard" }
	local CAT_ENEMY = { "zombie", "enemy", "enemies", "boss", "mob", "monster", "bandit", "skeleton", "orc", "goblin", "demon", "ghost",
		"raider", "guard", "soldier", "bot", "minion", "dragon", "slime", "spider", "troll", "undead", "musuh" }
	local PROMPT_SHOP = { "buy", "sell", "shop", "trade", "store", "purchase", "beli", "jual", "toko", "dagang" }
	local PROMPT_QUEST = { "talk", "chat", "quest", "mission", "dialog", "speak", "bicara", "misi", "ngobrol", "interact" }

	local function nameWords(s: string): { string }
		local spaced = string.gsub(s, "(%l)(%u)", "%1 %2") -- "LionCub" -> "Lion Cub"
		local sp = string.lower(spaced)
		local t: { string } = {}
		for w in string.gmatch(sp, "%a+") do
			t[#t + 1] = w
			if #w > 3 and string.sub(w, -1) == "s" then
				t[#t + 1] = string.sub(w, 1, -2) -- bentuk jamak: "Lions" -> "lion"
			end
		end
		return t
	end

	-- kata pendek (<5 huruf) harus cocok sebagai kata utuh (supaya "Merchant" tidak dianggap "ant");
	-- kata panjang boleh cocok sebagian ("PolarBear2", "elephantBull")
	local function nameHit(lower: string, toks: { string }, list: { string }): boolean
		for _, w in ipairs(list) do
			if #w >= 5 then
				if string.find(lower, w, 1, true) then return true end
			else
				for _, t in ipairs(toks) do
					if t == w then return true end
				end
			end
		end
		return false
	end

	local function textHit(s: string, list: { string }): boolean
		for _, w in ipairs(list) do
			if string.find(s, w, 1, true) then return true end
		end
		return false
	end

	local function npcClassify(m: Model, lower: string): string
		local toks = nameWords(m.Name)
		local shopP, questP = false, false
		for _, d in ipairs(m:GetDescendants()) do
			if d:IsA("ProximityPrompt") then
				local t = string.lower(d.ActionText .. " " .. d.ObjectText)
				if textHit(t, PROMPT_SHOP) then shopP = true end
				if textHit(t, PROMPT_QUEST) then questP = true end
			end
		end
		if shopP or nameHit(lower, toks, CAT_SHOP) then return "Toko" end
		if nameHit(lower, toks, CAT_ANIMAL) then return "Hewan" end
		if questP or nameHit(lower, toks, CAT_QUEST) then return "Quest" end
		if nameHit(lower, toks, CAT_ENEMY) then return "Musuh" end
		-- model beranimasi tanpa Humanoid (AnimationController) biasanya hewan/makhluk
		if not m:FindFirstChildOfClass("Humanoid") and m:FindFirstChildWhichIsA("AnimationController", true) then
			return "Hewan"
		end
		return "Lainnya"
	end

	local function npcAdd(inst: Instance, tries: number)
		local m = inst.Parent
		if not m or not m:IsA("Model") or N.byModel[m] then return end
		if not m:IsDescendantOf(workspace) then return end
		if Players:GetPlayerFromCharacter(m) then return end
		local root = npcRootOf(m :: Model)
		if not root then
			-- struktur belum lengkap (streaming) -> coba lagi sebentar lagi
			if tries < 4 then
				task.delay(1, function()
					if not unloaded and inst.Parent then
						npcAdd(inst, tries + 1)
					end
				end)
			end
			return
		end
		local name = m.Name
		local g = N.groups[name]
		if not g then
			local lower = string.lower(name)
			local okc, cat = pcall(npcClassify, m :: Model, lower)
			g = { name = name, lower = lower, list = {}, cat = okc and cat or "Lainnya" }
			N.groups[name] = g
			N.orderDirty = true
		end
		local e: any = { model = m, root = root, name = name }
		g.list[#g.list + 1] = e
		e.gi = #g.list
		N.byModel[m] = e
		N.dirty = true
	end

	local function npcDropVis(e: any)
		local v = N.vis[e]
		if v then
			if v.hl then v.hl:Destroy() end
			v.bb:Destroy()
			N.vis[e] = nil
		end
	end

	local function npcRemove(e: any)
		N.byModel[e.model] = nil
		npcDropVis(e)
		local g = N.groups[e.name]
		if g then
			local gl = g.list
			local m = #gl
			local gi = e.gi
			if gl[gi] == e then
				if gi ~= m then
					local last = gl[m]
					gl[gi] = last
					last.gi = gi
				end
				gl[m] = nil
			end
			if #gl == 0 then
				N.groups[e.name] = nil
				N.orderDirty = true
			end
		end
		N.dirty = true
	end

	local function npcStopLive()
		if N.addConn then N.addConn:Disconnect() N.addConn = nil end
		if N.remConn then N.remConn:Disconnect() N.remConn = nil end
		N.live = false
	end

	local function npcStartLive()
		N.live = true
		if N.addConn then return end
		N.addConn = track(workspace.DescendantAdded:Connect(function(inst)
			if NPC_CLASS[inst.ClassName] then
				task.defer(npcAdd, inst, 0)
			end
		end))
		N.remConn = track(workspace.DescendantRemoving:Connect(function(inst)
			if NPC_CLASS[inst.ClassName] then
				local m = inst.Parent
				local e = m and N.byModel[m]
				if e then npcRemove(e) end
			end
		end))
	end

	-- ---------- visual ----------
	local function npcOrigin(): Vector3?
		local cam = workspace.CurrentCamera
		if state.freecam and cam then
			return cam.CFrame.Position
		end
		local r = getRoot()
		if r then return r.Position end
		return cam and cam.CFrame.Position or nil
	end

	local function npcClearVis()
		for e in pairs(N.vis) do
			npcDropVis(e)
		end
		if N.folder then
			N.folder:Destroy()
			N.folder = nil
		end
	end

	local function npcBuildVis(e: any): any
		if not (N.folder and N.folder.Parent) then
			N.folder = new("Folder", { Name = "UU_NPC" }, playerGui)
		end
		local head = e.model:FindFirstChild("Head")
		local adornee = (head and head:IsA("BasePart")) and head or e.root
		local bb = new("BillboardGui", {
			Adornee = adornee,
			AlwaysOnTop = true,
			Active = true,
			Size = UDim2.fromOffset(160, 30),
			StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0),
			MaxDistance = math.huge,
		}, N.folder)
		local nameL = text(bb, {
			Text = "[NPC] " .. N.display(e.name),
			Size = UDim2.new(1, 0, 0.5, 0),
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			TextColor3 = NPC_COL,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0.25,
			TextTruncate = Enum.TextTruncate.AtEnd,
		})
		local infoL = text(bb, {
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0.5, 0),
			Font = Enum.Font.GothamBold,
			TextSize = 11,
			TextColor3 = ESP_SOFT_WHITE,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextStrokeColor3 = Color3.new(0, 0, 0),
			TextStrokeTransparency = 0.25,
			RichText = true,
		})
		-- KLIK LABEL = TELEPORT ke NPC/hewan ini (tombol transparan di atas label)
		local hit = new("TextButton", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ZIndex = 5,
		}, bb)
		hit.MouseButton1Click:Connect(function()
			if unloaded or not settings.clickTp then return end
			if settings.clickNeedsShift and not UIS:IsKeyDown(Enum.KeyCode.LeftShift) then return end
			local root = e.root
			local char, hrp = player.Character, getRoot()
			if not (root and root.Parent and char and hrp) then
				toast("NPC sudah tidak ada")
				return
			end
			char:PivotTo(root.CFrame + Vector3.new(0, 4, 0))
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
			floatY = nil
			toast("Teleport ke " .. N.display(e.name))
		end)
		local v: any = { bb = bb, name = nameL, info = infoL }
		N.vis[e] = v
		return v
	end

	-- Gambar/perbarui satu NPC. Dipanggil lewat pcall: satu NPC bermasalah tidak mematikan yang lain.
	local function npcShow(e: any, d: number, i: number)
		local v = N.vis[e]
		if v and not v.bb:IsDescendantOf(playerGui) then
			npcDropVis(e) -- folder hilang (mis. kamera diganti game) -> bangun ulang
			v = nil
		end
		if not v then v = npcBuildVis(e) end

		if i <= NPC_HL_MAX then
			if not v.hl then
				v.hl = new("Highlight", {
					Adornee = e.model,
					DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
					FillColor = NPC_COL,
					OutlineColor = NPC_COL,
					FillTransparency = 0.65,
					OutlineTransparency = 0.2,
				}, N.folder)
			end
		elseif v.hl then
			v.hl:Destroy()
			v.hl = nil
		end

		local hpTxt = ""
		local hum = e.model:FindFirstChildOfClass("Humanoid")
		if hum then
			local h, mh = hum.Health, hum.MaxHealth
			-- HP tak hingga / NaN (umum di NPC game) tidak boleh merusak format teks
			if h == h and h ~= math.huge and mh == mh and mh ~= math.huge and mh > 0 then
				local ratio = math.clamp(h / mh, 0, 1)
				local hex = Color3.fromHSV(ratio * 0.33, 0.6, 1):ToHex()
				hpTxt = '<font color="#' .. hex .. '">' .. tostring(math.max(0, math.floor(h + 0.5))) .. " HP</font>  "
			end
		end
		v.info.Text = hpTxt .. tostring(math.floor(d + 0.5)) .. "st"
	end

	local function npcUpdate()
		local origin = npcOrigin()
		if not origin then return end
		local maxD = values.npcDist

		-- Hanya jenis yang DIPILIH yang diproses; array dipakai ulang (tanpa alokasi tabel baru).
		local cand: { any } = N.cand
		table.clear(cand)
		local n, total = 0, 0
		for name in pairs(N.sel) do
			local g = N.groups[name]
			if g then
				local list = g.list
				total += #list
				for i = 1, #list do
					local e = list[i]
					local root = e.root
					if root.Parent then
						local d = (root.Position - origin).Magnitude
						if d <= maxD then
							e.d = d
							n += 1
							cand[n] = e
						end
					end
				end
			end
		end
		-- semakin banyak objek terpilih, semakin jarang diperbarui (0.15 s .. 0.6 s)
		N.interval = math.clamp(total / 4000, 0.15, 0.6)
		table.sort(cand, function(a, b) return a.d < b.d end)

		local keep: { [any]: boolean } = {}
		local shown = 0
		for i = 1, math.min(n, NPC_MAX) do
			local e = cand[i]
			keep[e] = true
			local ok, err = pcall(npcShow, e, e.d, i)
			if ok then
				shown += 1
			else
				npcDropVis(e)
				if not N.err then
					N.err = tostring(err)
					warn("[NpcEsp] " .. N.err)
					toast("ESP NPC error: " .. N.err)
				end
			end
		end

		for e in pairs(N.vis) do
			if not keep[e] then
				npcDropVis(e)
			end
		end

		N.shown, N.inRange, N.selTotal = shown, n, total
		N.setStatus()
	end

	-- ESP NPC selalu aktif: yang ditandai = jenis yang dicentang. "Matikan semua" = kosongkan pilihan.
	ext.npc = function(on: boolean)
		if on then
			N.acc = 1 -- langsung gambar di frame berikutnya
		else
			table.clear(N.sel)
			npcClearVis()
			N.shown, N.inRange = 0, 0
			N.refreshRows()
		end
		N.setStatus()
	end

	-- ---------- UI ----------
	local npcRefreshList: () -> () = function() end

	-- Diletakkan di tab ESP, tepat di atas "Loot & Item ESP" (scan NPC di atas, scan barang di bawah).
	sectionLabel(pages.ESP, 1, "ESP NPC / Hewan")
	local card = makeCard(pages.ESP, 364, 2)
	text(card, {
		Text = "ESP NPC / Hewan",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.new(1, -28, 0, 18),
	})

	local scanBtn = new("TextButton", {
		Position = UDim2.fromOffset(14, 42),
		Size = UDim2.new(1, -28 - 94, 0, 30),
		BackgroundColor3 = T.accent,
		Text = "🔍 SCAN NPC / HEWAN",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
	}, card)
	round(scanBtn, 8)
	hover(scanBtn, T.accent)

	-- Auto scan (Live): NPC yang spawn belakangan langsung masuk daftar tanpa menekan SCAN lagi
	local liveBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 42),
		Size = UDim2.fromOffset(88, 30),
		BackgroundColor3 = T.bg,
		Text = "Auto: OFF",
		TextColor3 = T.sub,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, card)
	round(liveBtn, 8)
	stroke(liveBtn, T.stroke, 1, 0.3)

	local function setLiveUI()
		liveBtn.Text = N.live and "Auto: ON" or "Auto: OFF"
		tween(liveBtn, {
			BackgroundColor3 = N.live and T.cardSel or T.bg,
			TextColor3 = N.live and T.text or T.sub,
		}, 0.12)
	end

	-- Slider jarak ringkas, tepat di bawah tombol SCAN (menggantikan kartu slider terpisah)
	do
		local DMIN, DMAX, DHARD = 50, 5000, 20000
		local row = new("Frame", {
			Position = UDim2.fromOffset(14, 80),
			Size = UDim2.new(1, -28, 0, 28),
			BackgroundTransparency = 1,
		}, card)
		text(row, {
			Text = "Jarak",
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextColor3 = T.sub,
			Size = UDim2.fromOffset(34, 28),
		})
		local hit = new("Frame", {
			Position = UDim2.fromOffset(38, 0),
			Size = UDim2.new(1, -38 - 64, 1, 0),
			BackgroundTransparency = 1,
		}, row)
		local bar = new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.new(1, 0, 0, 6),
			BackgroundColor3 = T.off,
			BorderSizePixel = 0,
		}, hit)
		round(bar, 3)
		local fill = new("Frame", {
			Size = UDim2.fromScale(0, 1),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
		}, bar)
		round(fill, 3)
		grad(fill, T.accent, T.accent2, 0)
		local knob = new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(15, 15),
			BackgroundColor3 = WHITE,
			BorderSizePixel = 0,
			ZIndex = 2,
		}, bar)
		round(knob, 8)
		stroke(knob, T.accent, 2, 0)

		local box = new("TextBox", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(56, 24),
			BackgroundColor3 = T.bg,
			Text = tostring(values.npcDist),
			TextColor3 = T.text,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			ClearTextOnFocus = false,
			BorderSizePixel = 0,
		}, row)
		round(box, 7)
		stroke(box, T.stroke, 1, 0.3)

		local function setValue(v: number)
			v = math.clamp(math.floor(v + 0.5), 1, DHARD)
			values.npcDist = v
			box.Text = tostring(v)
			local a = math.clamp((v - DMIN) / (DMAX - DMIN), 0, 1)
			fill.Size = UDim2.fromScale(a, 1)
			knob.Position = UDim2.fromScale(a, 0.5)
		end
		setValue(values.npcDist)
		sliderSetters.npcDist = setValue -- ikut tersimpan di Config / file lokal

		box.FocusLost:Connect(function()
			setValue(tonumber(box.Text) or values.npcDist)
		end)

		local dragging = false
		local function fromInput(input: InputObject)
			local rel = (input.Position.X - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1)
			setValue(DMIN + math.clamp(rel, 0, 1) * (DMAX - DMIN))
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

	local statusLbl = text(card, {
		Text = "Belum scan",
		TextSize = 11,
		TextColor3 = T.sub,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, 112),
		Size = UDim2.new(1, -28, 0, 14),
	})

	-- Status = ringkasan daftar + keadaan ESP (berapa NPC yang benar-benar tergambar).
	N.setStatus = function()
		local s: string = N.base
		if s ~= "" and not N.scanning and N.selTotal > 0 then
			if N.inRange == 0 then
				s ..= " · di luar jarak slider"
			else
				s ..= string.format(" · ESP %d/%d", N.shown, N.inRange)
			end
		end
		if statusLbl.Text ~= s then
			statusLbl.Text = s
		end
	end

	local searchBox = new("TextBox", {
		Position = UDim2.fromOffset(14, 130),
		Size = UDim2.new(1, -28, 0, 28),
		BackgroundColor3 = T.bg,
		PlaceholderText = "🔎 Cari nama NPC / hewan...",
		PlaceholderColor3 = T.sub,
		Text = "",
		TextColor3 = T.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, card)
	round(searchBox, 8)
	stroke(searchBox, T.stroke, 1, 0.3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, searchBox)

	-- Chip kategori: Semua / Hewan / Toko / Quest / Musuh / Lainnya
	local chipRow = new("Frame", {
		Position = UDim2.fromOffset(14, 162),
		Size = UDim2.new(1, -28, 0, 24),
		BackgroundTransparency = 1,
	}, card)
	new("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chipRow)
	local CAT_CHIPS = { "Semua", "Hewan", "Toko", "Quest", "Musuh", "Lainnya" }
	local chipBtns: { [string]: any } = {}
	do
		local n = #CAT_CHIPS
		local pad = math.ceil(4 * (n - 1) / n)
		for i, nm in ipairs(CAT_CHIPS) do
			local b = new("TextButton", {
				LayoutOrder = i,
				Size = UDim2.new(1 / n, -pad, 1, 0),
				BackgroundColor3 = nm == "Semua" and T.accent or T.bg,
				Text = nm,
				TextColor3 = nm == "Semua" and WHITE or T.sub,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				AutoButtonColor = false,
				BorderSizePixel = 0,
			}, chipRow)
			round(b, 6)
			stroke(b, T.stroke, 1, 0.4)
			chipBtns[nm] = b
			b.MouseButton1Click:Connect(function()
				N.cat = nm
				for name2, b2 in pairs(chipBtns) do
					local active = name2 == nm
					tween(b2, {
						BackgroundColor3 = active and T.accent or T.bg,
						TextColor3 = active and WHITE or T.sub,
					}, 0.12)
				end
				npcRefreshList()
			end)
		end
	end

	local actionRow = new("Frame", {
		Position = UDim2.fromOffset(14, 192),
		Size = UDim2.new(1, -28, 0, 24),
		BackgroundTransparency = 1,
	}, card)

	local function miniBtn(txt: string, pos: UDim2): any
		local b = new("TextButton", {
			Position = pos,
			Size = UDim2.new(0.5, -3, 1, 0),
			BackgroundColor3 = T.bg,
			Text = txt,
			TextColor3 = T.sub,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, actionRow)
		round(b, 6)
		stroke(b, T.stroke, 1, 0.4)
		hover(b, T.bg)
		return b
	end
	local selAllBtn = miniBtn("Pilih hasil", UDim2.fromScale(0, 0))
	local clrBtn = miniBtn("Kosongkan", UDim2.new(0.5, 3, 0, 0))

	local scroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 222),
		Size = UDim2.new(1, -28, 0, 130),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.stroke,
	}, card)
	new("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)

	local emptyLbl = text(card, {
		Text = "Belum ada data - tekan SCAN NPC / HEWAN",
		TextSize = 11,
		TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(14, 222),
		Size = UDim2.new(1, -28, 0, 130),
	})

	-- Editor ganti nama: muncul di atas baris tombol "Pilih hasil" saat "Ubah" ditekan
	do
		local ov = new("Frame", {
			Position = UDim2.fromOffset(14, 190),
			Size = UDim2.new(1, -28, 0, 62),
			BackgroundColor3 = T.bg,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 20,
		}, card)
		round(ov, 8)
		stroke(ov, T.accent, 1, 0.2)
		local title = text(ov, {
			Text = "",
			TextSize = 10,
			TextColor3 = T.sub,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 14),
		})
		local box = new("TextBox", {
			Position = UDim2.fromOffset(8, 24),
			Size = UDim2.new(1, -16 - 112, 0, 30),
			BackgroundColor3 = T.off,
			PlaceholderText = "contoh: 1 John (jual)",
			PlaceholderColor3 = T.sub,
			Text = "",
			TextColor3 = T.text,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			TextXAlignment = Enum.TextXAlignment.Left,
			ClearTextOnFocus = false,
			BorderSizePixel = 0,
		}, ov)
		round(box, 6)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)

		local function ovBtn(txt: string, x: number, col: Color3): any
			local b = new("TextButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, x, 0, 24),
				Size = UDim2.fromOffset(52, 30),
				BackgroundColor3 = col,
				Text = txt,
				TextColor3 = WHITE,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				AutoButtonColor = false,
				BorderSizePixel = 0,
			}, ov)
			round(b, 6)
			hover(b, col)
			return b
		end
		local saveB = ovBtn("Simpan", -64, T.accent)
		local cancelB = ovBtn("Batal", -8, T.off)

		local target: string? = nil
		local function close()
			ov.Visible = false
			target = nil
		end
		local function commit()
			local nm = target
			if not nm then return end
			local v = (box.Text:gsub("^%s+", "")):gsub("%s+$", "")
			if v == "" or v == nm then
				N.alias[nm] = nil
			else
				N.alias[nm] = string.sub(v, 1, 40)
			end
			N.saveAlias()
			N.orderDirty = true
			for e, vis in pairs(N.vis) do -- label ESP yang sudah tergambar ikut berganti
				if e.name == nm and vis.name then vis.name.Text = "[NPC] " .. N.display(nm) end
			end
			close()
			npcRefreshList()
			toast("Nama NPC: " .. N.display(nm))
		end
		N.openRename = function(name: string)
			target = name
			title.Text = "Nama asli: " .. name .. "  (kosongkan = kembali ke nama asli)"
			box.Text = N.alias[name] or name
			ov.Visible = true
			box:CaptureFocus()
		end
		saveB.MouseButton1Click:Connect(commit)
		cancelB.MouseButton1Click:Connect(close)
		box.FocusLost:Connect(function(enter: boolean)
			if enter then commit() end
		end)
	end

	local function matches(g: any, q: string): boolean
		if N.cat ~= "Semua" and g.cat ~= N.cat then return false end
		if q == "" then return true end
		if string.find(g.lower, q, 1, true) then return true end
		local al = N.alias[g.name]
		return al ~= nil and string.find(string.lower(al), q, 1, true) ~= nil
	end

	local function npcTeleport(g: any)
		local char = player.Character
		local hrp = getRoot()
		if not (char and hrp) then
			toast("Karakter belum siap")
			return
		end
		local best: any, bestD = nil, math.huge
		for _, e in ipairs(g.list) do
			if e.root.Parent then
				local d = (e.root.Position - hrp.Position).Magnitude
				if d < bestD then
					best, bestD = e, d
				end
			end
		end
		if not best then
			toast("NPC sudah tidak ada")
			return
		end
		char:PivotTo(best.root.CFrame + Vector3.new(0, 4, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		floatY = nil
		toast("Teleport ke " .. N.display(g.name))
	end

	local function npcBuildRow(g: any)
		local name: string = g.name
		local btn = new("TextButton", {
			Name = string.sub(name, 1, 50),
			Size = UDim2.new(1, -6, 0, 28),
			BackgroundColor3 = T.bg,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, scroll)
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

		local nameLbl = text(btn, {
			Text = N.display(name),
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -30 - 122, 1, 0),
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

		local edit = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -76, 0.5, 0),
			Size = UDim2.fromOffset(38, 20),
			BackgroundColor3 = T.off,
			Text = "Ubah",
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, btn)
		round(edit, 5)
		hover(edit, T.off)
		edit.MouseButton1Click:Connect(function()
			if N.openRename then N.openRename(name) end
		end)

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
			return N.sel[name] and T.cardSel or T.bg
		end
		local function apply()
			local sel = N.sel[name] == true
			box.BackgroundColor3 = sel and T.good or T.off
			check.Visible = sel
			btn.BackgroundColor3 = baseColor()
		end

		btn.MouseEnter:Connect(function()
			tween(btn, { BackgroundColor3 = lighten(baseColor()) }, 0.1)
		end)
		btn.MouseLeave:Connect(function()
			tween(btn, { BackgroundColor3 = baseColor() }, 0.1)
		end)
		-- Centang HANYA berubah kalau area kotak centang (kiri, sampai sebelum nama) yang diklik.
		local hit = new("TextButton", {
			Name = "CheckHit",
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.fromOffset(28, 28),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
			ZIndex = 5,
		}, btn)
		hit.MouseButton1Click:Connect(function()
			N.sel[name] = (not N.sel[name]) or nil
			N.saveSel()
			apply()
			npcRefreshList()
		end)
		tp.MouseButton1Click:Connect(function()
			local cur = N.groups[name]
			if cur then
				npcTeleport(cur)
			else
				toast("NPC sudah tidak ada")
			end
		end)

		N.rows[name] = { btn = btn, apply = apply, cnt = cnt, lbl = nameLbl }
		apply()
	end

	N.refreshRows = function()
		npcRefreshList()
	end

	npcRefreshList = function()
		if unloaded then return end
		N.acc = 1 -- pilihan/daftar berubah -> ESP digambar ulang segera

		local order = N.order
		-- Urutan hanya dihitung ulang kalau ada JENIS baru/hilang (bukan tiap hewan spawn).
		if N.orderDirty then
			N.orderDirty = false
			table.clear(order)
			for name in pairs(N.groups) do
				order[#order + 1] = name
			end
			table.sort(order, function(a, b)
				local la, lb = N.sortKey(N.display(a)), N.sortKey(N.display(b))
				if la ~= lb then return la < lb end
				return a < b
			end)

			for name, r in pairs(N.rows) do -- buang baris grup yang sudah hilang
				if not N.groups[name] then
					r.btn:Destroy()
					N.rows[name] = nil
				end
			end
		end

		local q = string.lower(searchBox.Text)
		local shown, total, objs = 0, 0, 0
		local built, pending = 0, false
		for i, name in ipairs(order) do
			local g = N.groups[name]
			objs += #g.list
			local r = N.rows[name]
			if matches(g, q) then
				total += 1
				if not r then
					if built < ROWS_PER_PASS then
						npcBuildRow(g)
						built += 1
						r = N.rows[name]
					else
						pending = true -- sisanya dibuat di langkah berikutnya
					end
				end
				if r then
					shown += 1
					r.btn.Visible = true
					r.btn.LayoutOrder = i
					r.cnt.Text = "×" .. #g.list
					r.lbl.Text = N.display(name)
					r.apply()
				end
			elseif r then
				r.btn.Visible = false
			end
		end
		if pending then
			N.dirty = true
			N.acc2 = 1 -- lanjutkan membangun daftar di frame berikutnya
		end

		local selN = 0
		for name in pairs(N.sel) do
			if N.groups[name] then selN += 1 end
		end

		local s: string
		if N.scanning then
			s = "Memindai..."
		elseif #order == 0 then
			s = N.live and "Auto scan aktif · belum ada NPC terdeteksi" or "Belum scan"
		else
			s = string.format("%d jenis · %d objek · %d dipilih", #order, objs, selN)
			if pending then
				s ..= string.format(" · memuat daftar %d/%d...", shown, total)
			end
		end
		N.base = s
		N.selTotal = 0
		for name in pairs(N.sel) do
			local g = N.groups[name]
			if g then N.selTotal += #g.list end
		end
		N.setStatus()

		if shown == 0 then
			if N.scanning then
				emptyLbl.Text = "Memindai..."
			elseif #order == 0 then
				emptyLbl.Text = N.live and "Auto scan aktif - belum ada NPC terdeteksi" or "Belum ada data - tekan SCAN NPC / HEWAN"
			else
				emptyLbl.Text = "Tidak ada hasil"
			end
		end
		emptyLbl.Visible = shown == 0
	end

	local function npcScan()
		if N.scanning or unloaded then return end
		N.scanning = true
		scanBtn.Text = "⏳ Memindai..."
		npcRefreshList()

		local ok, err = pcall(function()
			for _, e in pairs(table.clone(N.byModel)) do
				npcRemove(e)
			end
			npcStartLive() -- tangkap juga NPC yang muncul selama & sesudah scan
			setLiveUI()
			N.scanned = true

			local desc = workspace:GetDescendants()
			local t0 = os.clock()
			for i = 1, #desc do
				local inst = desc[i]
				if NPC_CLASS[inst.ClassName] then
					npcAdd(inst, 0)
				end
				if i % 400 == 0 and os.clock() - t0 > 0.004 then
					RunService.Heartbeat:Wait()
					if unloaded then return end
					t0 = os.clock()
				end
			end
		end)

		N.scanning = false
		if unloaded then return end
		scanBtn.Text = "🔍 SCAN NPC / HEWAN"
		npcRefreshList()

		if not ok then
			warn("[NpcScan] " .. tostring(err))
			toast("Scan error - lihat Output (F9)")
		else
			local kinds = 0
			for _ in pairs(N.groups) do kinds += 1 end
			if kinds == 0 then
				toast("Tidak ada NPC/hewan terdeteksi (Auto scan tetap memantau)")
			else
				toast(string.format("Scan selesai: %d jenis NPC/hewan", kinds))
			end
		end
	end

	scanBtn.MouseButton1Click:Connect(npcScan)
	liveBtn.MouseButton1Click:Connect(function()
		if N.live then
			npcStopLive()
			setLiveUI()
			npcRefreshList()
			toast("Auto scan NPC dimatikan")
		else
			setLiveUI() -- npcScan menyalakan Auto dan memindai semua NPC yang sudah ada
			task.spawn(npcScan)
			toast("Auto scan NPC dinyalakan")
		end
	end)
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		npcRefreshList()
	end)

	selAllBtn.MouseButton1Click:Connect(function()
		local q = string.lower(searchBox.Text)
		local picked = 0
		for _, name in ipairs(N.order) do
			local g = N.groups[name]
			if g and matches(g, q) then
				picked += 1
				N.sel[name] = true
			end
		end
		N.saveSel()
		npcRefreshList()
	end)

	clrBtn.MouseButton1Click:Connect(function()
		table.clear(N.sel)
		N.saveSel()
		npcRefreshList()
	end)

	-- Ada centang NPC tersimpan: nyalakan Auto scan + scan otomatis supaya langsung tertandai di server ini
	if next(N.sel) ~= nil then
		task.delay(2.5, function()
			if not unloaded and not N.scanning and not N.live then
				npcScan()
			end
		end)
	end

	-- ---------- loop ----------
	track(RunService.Heartbeat:Connect(function(dt: number)
		if unloaded then return end

		N.acc += dt
		if N.acc >= N.interval then
			N.acc = 0
			if next(N.sel) ~= nil or next(N.vis) ~= nil then
				local ok, err = pcall(npcUpdate)
				if not ok and not N.warned then
					N.warned = true
					warn("[NpcEsp] " .. tostring(err))
				end
			end
		end

		N.acc2 += dt
		if N.acc2 >= 1.0 then
			N.acc2 = 0
			if N.dirty then
				N.dirty = false
				npcRefreshList()
			end
		end
	end))

	npcRefreshList()
end

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

-- ---------- Daftar pemain: klik baris / tombol TP untuk teleport ----------
-- Dibungkus fungsi anonim langsung-jalan supaya local-nya punya jatah sendiri
-- (tidak menambah hitungan 200 local di chunk utama).
tpTargetCard.Size = UDim2.new(1, 0, 0, 232)
;(function()
	local plrCount = text(tpTargetCard, {
		Text = "Pemain online: 0",
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextColor3 = T.sub,
		Position = UDim2.fromOffset(14, 70),
		Size = UDim2.new(1, -28, 0, 14),
	})

	local plrScroll = new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.new(1, -28, 0, 134),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.stroke,
	}, tpTargetCard)
	new("UIListLayout", {
		Padding = UDim.new(0, 4),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, plrScroll)

	local plrEmpty = text(tpTargetCard, {
		Text = "Tidak ada pemain lain di server",
		TextSize = 11,
		TextColor3 = T.sub,
		TextXAlignment = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(14, 88),
		Size = UDim2.new(1, -28, 0, 134),
	})

	local plrRows: { [Player]: any } = {}

	local function buildPlayerRow(p: Player): any
		local btn = new("TextButton", {
			Name = string.sub(p.Name, 1, 40),
			Size = UDim2.new(1, -6, 0, 28),
			BackgroundColor3 = T.bg,
			Text = "",
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, plrScroll)
		round(btn, 6)
		hover(btn, T.bg)

		local label = p.Name
		if p.DisplayName ~= "" and p.DisplayName ~= p.Name then
			label = p.DisplayName .. "  (@" .. p.Name .. ")"
		end
		text(btn, {
			Text = label,
			Font = Enum.Font.GothamMedium,
			TextSize = 11,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(10, 0),
			Size = UDim2.new(1, -58, 1, 0),
		})

		local tp = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -5, 0.5, 0),
			Size = UDim2.fromOffset(36, 20),
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

		local function go()
			if p.Parent then
				teleportToUsername(p.Name, p)
			else
				toast("Pemain sudah keluar")
			end
		end
		btn.MouseButton1Click:Connect(go)
		tp.MouseButton1Click:Connect(go)
		return btn
	end

	local function refreshPlayerList()
		if unloaded then return end
		local others: { Player } = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				others[#others + 1] = p
			end
		end
		table.sort(others, function(a, b)
			local la, lb = string.lower(a.DisplayName), string.lower(b.DisplayName)
			if la ~= lb then return la < lb end
			return a.UserId < b.UserId
		end)

		local present: { [Player]: boolean } = {}
		for i, p in ipairs(others) do
			present[p] = true
			local row = plrRows[p]
			if not row then
				row = buildPlayerRow(p)
				plrRows[p] = row
			end
			row.LayoutOrder = i
		end
		for p, row in pairs(plrRows) do
			if not present[p] then
				row:Destroy()
				plrRows[p] = nil
			end
		end

		plrCount.Text = "Pemain online: " .. tostring(#others)
		plrEmpty.Visible = #others == 0
	end

	track(Players.PlayerAdded:Connect(refreshPlayerList))
	track(Players.PlayerRemoving:Connect(function()
		-- PlayerRemoving terpanggil sebelum pemain benar-benar hilang dari GetPlayers
		task.defer(refreshPlayerList)
	end))
	refreshPlayerList()
end)()

end

-- =====================================================
-- ITEM ESP SELEKTIF (scan ringan + daftar pilihan + detail hanya untuk yang dipilih)
-- =====================================================
-- =====================================================
-- DATA RARITY (tanpa kartu/label sendiri) -- dipakai oleh Item ESP di bawah
--  * Rarity dibaca otomatis dari ModuleScript data game (ReplicatedStorage), tanpa memetik item.
--  * Nomor tier (1,2,3...) diterjemahkan ke nama rarity.
--  * Item ESP memakainya untuk: dropdown "Rarity" (filter daftar) + warna label/titik per rarity.
--  * Data dimuat otomatis saat pertama kali dibutuhkan (dropdown dibuka / label item muncul).
-- Dibungkus xpcall + function supaya tidak menambah jumlah local di level atas.
-- =====================================================
xpcall(function()
	local RAR_WORDS = { "legendary", "mythical", "mythic", "epic", "uncommon", "common", "rare", "exotic", "divine", "godly", "secret", "unique" }
	local MOD_WORDS = { "item", "mushroom", "shroom", "fung", "rarit", "data", "config", "loot", "drop", "forag", "catalog", "info", "stat", "list", "const", "shop", "crop", "plant" }
	local NAMES = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }
	local RCOL = {
		Common = Color3.fromRGB(200, 200, 205),
		Uncommon = Color3.fromRGB(110, 220, 120),
		Rare = Color3.fromRGB(90, 165, 255),
		Epic = Color3.fromRGB(192, 110, 255),
		Legendary = Color3.fromRGB(255, 196, 60),
		Mythic = Color3.fromRGB(255, 90, 120),
	}
	local DEF_NUM = { [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary", [6] = "Mythic" }

	local api = {
		names = NAMES,
		colors = RCOL,
		ready = false,
		loading = false,
		failed = false,
		version = 0,
		count = 0,
		listeners = {},
	}
	local rarMap, keysByLen = {}, {}   -- namaTernormalisasi -> nama rarity
	local numName = DEF_NUM
	local cache = {}

	-- ---------- helper teks ----------
	local function wordIn(s)
		local l = string.lower(tostring(s))
		for _, w in ipairs(RAR_WORDS) do
			if string.find(l, "%f[%a]" .. w .. "%f[%A]") then return w end
		end
		return nil
	end

	local function exactWord(s)
		local l = string.lower(tostring(s))
		l = string.gsub(l, "[%s_%-]", "")
		for _, w in ipairs(RAR_WORDS) do
			if l == w then return w end
		end
		return nil
	end

	-- skor nama field rarity: "Rarity" paling kuat, lalu yang mengandung rarity, lalu Tier/Grade
	local function keyScore(k)
		local l = string.lower(tostring(k))
		if l == "rarity" then return 3 end
		if string.find(l, "rarity", 1, true) then return 2 end
		if string.find(l, "tier", 1, true) or string.find(l, "grade", 1, true) then return 1 end
		return 0
	end

	local function norm(s)
		return (string.gsub(string.lower(tostring(s)), "[^%w]", ""))
	end

	local function cap(s)
		return string.upper(string.sub(s, 1, 1)) .. string.sub(s, 2)
	end

	local function scanTable(root, found)
		local seen, nodes = {}, 0
		local function walk(t, depth, key)
			if depth > 5 or seen[t] or nodes > 5000 then return end
			seen[t] = true
			nodes = nodes + 1

			local rv, best = nil, 0
			for k, v in pairs(t) do
				if type(k) == "string" and (type(v) == "string" or type(v) == "number") then
					local sc = keyScore(k)
					if sc > best then
						best, rv = sc, v
					end
				end
			end
			if rv ~= nil then
				local nm = t.Name or t.DisplayName or t.name or t.displayName or t.Title or key
				if nm ~= nil and type(nm) ~= "table" then
					table.insert(found, { name = tostring(nm), rar = rv, sc = best })
				end
			end

			for k, v in pairs(t) do
				if type(v) == "table" then
					if type(k) == "string" and exactWord(k) then
						for ik, iv in pairs(v) do
							local nm = nil
							if type(iv) == "string" then
								nm = iv
							elseif type(ik) == "string" then
								nm = ik
							elseif type(iv) == "table" then
								nm = iv.Name or iv.DisplayName or iv.name
							end
							if nm ~= nil and type(nm) ~= "table" then
								table.insert(found, { name = tostring(nm), rar = k, sc = 1 })
							end
						end
					end
					walk(v, depth + 1, (type(k) == "string") and k or key)
				end
			end
		end
		pcall(walk, root, 0, nil)
	end

	local function loadData()
		if api.loading or unloaded then return end
		api.loading = true
		api.ready = false
		api.failed = false

		local mods = {}
		for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
			if d:IsA("ModuleScript") then
				local l = string.lower(d.Name)
				for _, w in ipairs(MOD_WORDS) do
					if string.find(l, w, 1, true) then
						table.insert(mods, d)
						break
					end
				end
			end
		end

		local found = {}
		for i, m in ipairs(mods) do
			if i > 80 or unloaded then break end
			local done, res = false, nil
			task.spawn(function()
				local ok, r = pcall(require, m)
				if ok then res = r end
				done = true
			end)
			local t0 = os.clock()
			while not done and os.clock() - t0 < 1.5 do task.wait() end
			if done and type(res) == "table" then
				scanTable(res, found)
			end
		end

		-- satu entri terbaik per nama (field "Rarity" menang atas Tier/Grade)
		local best = {}
		for _, f in ipairs(found) do
			local k = norm(f.name)
			if k ~= "" then
				local cur = best[k]
				if not cur or f.sc > cur.sc then best[k] = f end
			end
		end

		-- terjemahan nomor tier -> nama rarity. Dikalibrasi dengan 4 mushroom yang rarity-nya
		-- sudah diketahui dari tabel game; kalau tidak lengkap, pakai urutan standar 1..5.
		local nm = {}
		for n, r in pairs(DEF_NUM) do nm[n] = r end
		local anchors = { honeyfungus = "Common", amethystdeceiver = "Uncommon", blacktrumpet = "Rare", blacktruffle = "Epic" }
		local cal, calOk, epicN = {}, true, nil
		for k, rn in pairs(anchors) do
			local f = best[k]
			if f and type(f.rar) == "number" then
				cal[f.rar] = rn
				if rn == "Epic" then epicN = f.rar end
			else
				calOk = false
			end
		end
		local calCount = 0
		for _ in pairs(cal) do calCount = calCount + 1 end
		if calOk and calCount == 4 and epicN then
			nm = {}
			for n, rn in pairs(cal) do nm[n] = rn end
			local higher, arr = {}, {}
			for _, f in pairs(best) do
				if type(f.rar) == "number" and f.rar > epicN then higher[f.rar] = true end
			end
			for n in pairs(higher) do table.insert(arr, n) end
			table.sort(arr)
			if arr[1] then nm[arr[1]] = "Legendary" end
			if arr[2] then nm[arr[2]] = "Mythic" end
		end
		numName = nm

		rarMap, keysByLen = {}, {}
		local count = 0
		for k, f in pairs(best) do
			local rn
			if type(f.rar) == "number" then
				rn = numName[f.rar] or ("Tier " .. tostring(f.rar))
			else
				local w = wordIn(f.rar)
				rn = w and cap(w) or tostring(f.rar)
			end
			rarMap[k] = rn
			count = count + 1
			if #k >= 5 then table.insert(keysByLen, k) end
		end
		table.sort(keysByLen, function(a, b) return #a > #b end)

		cache = {}
		api.loading = false
		api.count = count
		if count > 0 then
			api.ready = true
		else
			api.failed = true
		end
		api.version = api.version + 1
		for _, fn in ipairs(api.listeners) do pcall(fn) end
	end


	-- cocokkan teks item dengan data (persis, lalu akhiran: "Huge Slippery Jack" -> "Slippery Jack")
	local function lookup(c)
		if c == "" then return nil end
		local r = rarMap[c]
		if r then return r end
		for _, k in ipairs(keysByLen) do
			if #k <= #c and string.sub(c, -#k) == k then return rarMap[k] end
		end
		return nil
	end

	-- nama item -> rarity (nil = tidak dikenal / data belum siap)
	function api.get(name)
		if not api.ready then return nil end
		local c = norm(name)
		if c == "" then return nil end
		local r = cache[c]
		if r == nil then
			r = lookup(c) or false
			cache[c] = r
		end
		return r or nil
	end

	-- cadangan: atribut spesies pada model (mis. Sp = "SlipperyJack")
	function api.getAttr(inst)
		if not (api.ready and inst) then return nil end
		for _, an in ipairs({ "Sp", "Species", "Type" }) do
			local v = inst:GetAttribute(an)
			if type(v) == "string" then
				local r = lookup(norm(v))
				if r then return r end
			end
		end
		return nil
	end

	function api.ensure()
		if api.ready or api.loading or api.failed or unloaded then return end
		task.spawn(loadData)
	end

	settings.rarityApi = api
end, warn)

sectionLabel(pages.ESP, 4, "Loot & Item ESP")

do

-- ---------- UI ----------
local scannerCard = makeCard(pages.ESP, 340, 5)

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
local selectAllBtn = smallButton(actionRow, "Pilih hasil", UDim2.new(0.25, -5, 1, 0), 1)
local clearSelBtn = smallButton(actionRow, "Kosongkan", UDim2.new(0.25, -5, 1, 0), 2)
local dotsBtn = smallButton(actionRow, "Titik: ON", UDim2.new(0.25, -5, 1, 0), 3)
selectAllBtn.TextSize = 10
clearSelBtn.TextSize = 10
dotsBtn.TextSize = 10
hover(selectAllBtn, T.bg)
hover(clearSelBtn, T.bg)

-- Daftar item unik
local lootScroll = new("ScrollingFrame", {
	Position = UDim2.fromOffset(14, 162),
	Size = UDim2.new(1, -28, 0, 122),
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
	Size = UDim2.new(1, -28, 0, 122),
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
local groups: { [string]: any } = {}     -- nama -> { name, lower, cats, list }  (hanya yang SEDANG ada di map)
local catalog: { [string]: any } = {}    -- KATALOG: semua nama yang pernah terlihat/diketahui (tidak dihapus saat item hilang)
local persistDirty = false               -- katalog/centangan berubah -> perlu disimpan ke file
local order: { string } = {}             -- nama unik (urut abjad)
local itemSel: { [string]: boolean? } = {}
local pin: any = { list = {}, set = {}, w = 460, h = 36 }  -- item yang dipasang di pop-up (berurutan)
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
local rarSel: { [string]: boolean } = {}   -- rarity yang dipilih di dropdown (kosong = Semua)
local rarSelN = 0
local onlyPresent = false                -- true = sembunyikan item yang stoknya 0 (belum ada di map)
local markFolder: Folder? = nil
local liveAdd: RBXScriptConnection? = nil
local liveRem: RBXScriptConnection? = nil
local curOrigin: Vector3? = nil
local warnedReg = false

-- ---------- rarity (data dari modul di atas: settings.rarityApi) ----------
local function rarityOf(name: string): string?
	local api = settings.rarityApi
	if not api or not api.ready then return nil end
	local cg = catalog[name]
	if cg and cg.rarV == api.version then return cg.rar or nil end
	local r = api.get(name)
	local final = true
	if not r then
		local g = groups[name]
		local e1 = g and g.list[1]
		if e1 then
			local okA, ra = pcall(function()
				local tr = e1.trig
				local m = tr:IsA("Tool") and tr or tr:FindFirstAncestorOfClass("Model") or e1.part
				return api.getAttr(m)
			end)
			if okA then r = ra end
		else
			final = false -- belum ada instance di map: jangan simpan hasil "tidak ada" dulu
		end
	end
	if cg and final then
		cg.rar = r or false
		cg.rarV = api.version
	end
	return r
end

local function rarityColor(name: string): Color3?
	local api = settings.rarityApi
	local r = api and rarityOf(name)
	return r and api.colors[r] or nil
end

-- Warnai label (nama, garis tepi, jarak) dan titik sesuai rarity. Tanpa rarity = tampilan default.
local function applyRarityColor(e: any)
	local api = settings.rarityApi
	local ver = api and api.version or 0
	if e.rarV == ver then return end
	e.rarV = ver
	local col = rarityColor(e.name)
	e.rarCol = col
	if e.nameLbl then e.nameLbl.TextColor3 = col or T.text end
	if e.lblStroke then e.lblStroke.Color = col or COL_SEL end
	if e.distLbl then e.distLbl.TextColor3 = col or COL_SEL end
	if e.dotFrame and e.label then e.dotFrame.BackgroundColor3 = col or COL_SEL end
end

-- ---------- penanda (titik & label) ----------
local function ensureFolder(): Folder
	if not (markFolder and markFolder:IsDescendantOf(playerGui)) then
		if markFolder then markFolder:Destroy() end
		markFolder = new("Folder", { Name = "UU_ITEMS" }, playerGui)
	end
	return markFolder :: Folder
end

local function styleDot(e: any, on: boolean)
	local f = e.dotFrame
	if f then
		f.BackgroundColor3 = on and (e.rarCol or COL_SEL) or COL_DOT
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
		Active = true,
		Size = UDim2.fromOffset(132, 36),
		StudsOffset = Vector3.new(0, 2, 0),
		MaxDistance = LABEL_MAX_DIST,
		LightInfluence = 0,
	}, ensureFolder())
	local bg = new("TextButton", {
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = T.bg,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
	}, bb)
	round(bg, 8)
	e.lblStroke = stroke(bg, COL_SEL, 1, 0.35)
	-- KLIK LABEL = TELEPORT ke item ini
	bg.MouseButton1Click:Connect(function()
		if unloaded or not settings.clickTp or e.dead then return end
		if settings.clickNeedsShift and not UIS:IsKeyDown(Enum.KeyCode.LeftShift) then return end
		local part = e.part
		local char, hrp = player.Character, getRoot()
		if not (part and part.Parent and char and hrp) then
			toast("Item sudah tidak ada")
			return
		end
		char:PivotTo(part.CFrame + Vector3.new(0, 3, 0))
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.AssemblyAngularVelocity = Vector3.zero
		floatY = nil
		toast("Teleport ke " .. e.name)
	end)
	e.nameLbl = text(bg, {
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
	e.rarV = nil
	local rapi = settings.rarityApi
	if rapi then rapi.ensure() end
	applyRarityColor(e)
end

local function dropLabel(e: any)
	if e.label then
		e.label:Destroy()
		e.label = nil
		e.distLbl = nil
		e.nameLbl = nil
		e.lblStroke = nil
		e.rarV = nil
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
	local cg = catalog[name]
	if not cg then
		cg = { name = name, lower = string.lower(name), cats = {} }
		catalog[name] = cg
		orderDirty = true
		persistDirty = true
	end
	if not cg.cats[cat] then
		cg.cats[cat] = true
		persistDirty = true
	end
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
		if catalog[name] then n += 1 end
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
		local liveKinds = 0
		for _ in pairs(groups) do liveKinds += 1 end
		s = string.format("%d jenis (%d ada di map) · %d objek · %d dipilih", #order, liveKinds, totalObjs, countSelected())
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

-- Pencarian multi-kata: dipisah spasi / koma / titik koma. Item cocok kalau namanya memuat SALAH SATU kata.
local termCacheQ: string? = nil
local termCache: { string } = {}
local function termsOf(q: string): { string }
	if q ~= termCacheQ then
		termCacheQ = q
		termCache = {}
		for w in string.gmatch(q, "[^%s,;]+") do
			termCache[#termCache + 1] = w
		end
	end
	return termCache
end

local function groupMatches(g: any, q: string): boolean
	if onlyPresent and not groups[g.name] then return false end
	local terms = termsOf(q)
	local hasQuery = #terms > 0
	if hasQuery then
		local hit = false
		for i = 1, #terms do
			if string.find(g.lower, terms[i], 1, true) then hit = true; break end
		end
		if not hit then return false end
	end
	-- Di tab Terpilih, item yang dicentang manual tetap tampil walau rarity-nya di luar filter
	if rarSelN > 0 and not (filterMode == "Terpilih" and itemSel[g.name] == true) then
		local rapi = settings.rarityApi
		if rapi and not rapi.failed then
			local r = rarityOf(g.name)
			if not (r and rarSel[r]) then return false end
		end
	end
	local fm = filterMode
	if fm == "Semua" then
		if hasQuery then return true end -- pencarian menembus semua kategori
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
		local g = catalog[name]
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
	persistDirty = true
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

	local nmL = text(btn, {
		Text = name,
		Font = Enum.Font.GothamMedium,
		TextSize = 11,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(30, 0),
		Size = UDim2.new(1, -30 - 112, 1, 0),
	})
	local cnt = text(btn, {
		Text = "×" .. (groups[name] and #groups[name].list or 0),
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

	-- tombol pin: pasang/lepas item ini di pop-up
	local pinBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -78, 0.5, 0),
		Size = UDim2.fromOffset(30, 20),
		BackgroundColor3 = T.off,
		Text = "PIN",
		TextColor3 = T.sub,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, btn)
	round(pinBtn, 5)
	pinBtn.MouseButton1Click:Connect(function()
		pin.toggle(name)
	end)

	local function baseColor(): Color3
		return itemSel[name] and T.cardSel or T.bg
	end
	local function apply()
		local sel = itemSel[name] == true
		box.BackgroundColor3 = sel and COL_SEL or T.off
		check.Visible = sel
		pinBtn.BackgroundColor3 = pin.set[name] and T.accent or T.off
		pinBtn.TextColor3 = pin.set[name] and WHITE or T.sub
		btn.BackgroundColor3 = baseColor()
	end

	btn.MouseEnter:Connect(function()
		tween(btn, { BackgroundColor3 = lighten(baseColor()) }, 0.1)
	end)
	btn.MouseLeave:Connect(function()
		tween(btn, { BackgroundColor3 = baseColor() }, 0.1)
	end)
	-- Centang HANYA berubah kalau area kotak centang (kiri, sampai sebelum nama item) yang diklik.
	-- Klik di nama / area kosong / sekitar tombol TP tidak mengubah centang.
	local hit = new("TextButton", {
		Name = "CheckHit",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(28, 28),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, btn)
	hit.MouseButton1Click:Connect(function()
		setSelected(name, not itemSel[name])
		refreshStatus()
		if filterMode == "Terpilih" then applyFilter() end
	end)
	tp.MouseButton1Click:Connect(function()
		local cur = groups[name]
		if cur then
			teleportToNearest(cur)
		else
			toast("Belum ada di map (belum respawn) - kalau sudah dicentang, otomatis tertandai saat muncul")
		end
	end)

	rows[name] = { btn = btn, apply = apply, cnt = cnt, order = 0, nmL = nmL }
	apply()
	nmL.TextColor3 = rarityColor(name) or T.text
end

local function buildPending(maxN: number)
	local built = 0
	while built < maxN do
		local name = table.remove(pendingRows, 1)
		if not name then break end
		local g = catalog[name]
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
	for name in pairs(catalog) do
		order[#order + 1] = name
	end
	table.sort(order, function(a, b)
		local la, lb = catalog[a].lower, catalog[b].lower
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
				r.cnt.Text = "×0" -- item belum respawn / hilang: baris & centangan tetap ada
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
		r.cnt.Text = "×0"
	end
	groups = {}
	all = {}
	byTrig = {}
	byPart = {}
	labeled = {}
	dirtyNames = {}
	pendingRows = {}
	retryList = {}
	qInst, qTries = {}, {}
	qHead, qTail = 1, 0
	rebuildOrder() -- urutan dibangun dari KATALOG, bukan dari hasil scan
	layoutDirty = true
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

-- ---------- seed katalog dari ReplicatedStorage ----------
-- Template item yang disimpan di ReplicatedStorage (lalu dikloning game saat respawn) bisa dibaca client,
-- jadi namanya langsung masuk daftar walau barangnya belum ada di map. ServerStorage tidak bisa dibaca client.
-- Matikan dengan settings.seedReplicated = false.
local function seedFromStorage()
	local okD, desc = pcall(function() return ReplicatedStorage:GetDescendants() end)
	if not okD then return end
	local t0 = os.clock()
	for i = 1, #desc do
		local inst = desc[i]
		local cat = CLASS_CAT[inst.ClassName]
		if cat and cat ~= "Sentuh" then
			local name: string? = nil
			if cat == "Tool" then
				name = inst.Name
			else
				local _, anchor = resolve(inst, cat)
				if anchor then
					if cat == "Prompt" and (inst :: ProximityPrompt).ObjectText ~= "" then
						name = (inst :: ProximityPrompt).ObjectText
					else
						name = baseName(anchor)
					end
				end
			end
			if name and name ~= "" then
				local cg = catalog[name]
				if not cg then
					cg = { name = name, lower = string.lower(name), cats = {} }
					catalog[name] = cg
					orderDirty = true
					persistDirty = true
				end
				if not cg.cats[cat] then
					cg.cats[cat] = true
					persistDirty = true
				end
			end
		end
		if i % 400 == 0 and os.clock() - t0 > SCAN_BUDGET then
			RunService.Heartbeat:Wait()
			if unloaded then return end
			t0 = os.clock()
		end
	end
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

		if settings.seedReplicated ~= false then
			seedFromStorage()
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
		-- pilihan (centang) TIDAK dibuang walau itemnya belum ada di map: begitu respawn langsung tertandai
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

-- Tombol filter "Ada": tampilkan hanya item yang stoknya > 0 di map (bisa digabung dengan chip kategori & pencarian)
lootSearchBox.Size = UDim2.new(1, -28 - 84, 0, 28)
local presentBtn = smallButton(scannerCard, "Ada: OFF", UDim2.fromOffset(78, 28), 0)
presentBtn.AnchorPoint = Vector2.new(1, 0)
presentBtn.Position = UDim2.new(1, -14, 0, 66)
presentBtn.MouseButton1Click:Connect(function()
	onlyPresent = not onlyPresent
	presentBtn.Text = onlyPresent and "Ada: ON" or "Ada: OFF"
	tween(presentBtn, {
		BackgroundColor3 = onlyPresent and T.accent or T.bg,
		TextColor3 = onlyPresent and WHITE or T.sub,
	}, 0.12)
	onFilterChanged()
end)
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
		local g = catalog[name]
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

-- ---------- dropdown RARITY: filter daftar; warna label & titik ikut rarity ----------
do
	local api = settings.rarityApi
	if api then
		local RN = { "Semua" }
		for _, n in ipairs(api.names) do RN[#RN + 1] = n end

		local rarBtn = smallButton(actionRow, "Rarity ▼", UDim2.new(0.25, -5, 1, 0), 4)
		rarBtn.TextSize = 10

		local ROW_H, GAP = 22, 2
		local panel = new("Frame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, 158),
			Size = UDim2.fromOffset(150, 8 + #RN * ROW_H + (#RN - 1) * GAP),
			BackgroundColor3 = T.card,
			BorderSizePixel = 0,
			Active = true, -- cegah klik tembus ke daftar di bawahnya
			Visible = false,
			ZIndex = 30,
		}, scannerCard)
		round(panel, 8)
		stroke(panel, T.stroke, 1, 0.2)

		local rbtn = {}
		for i, _ in ipairs(RN) do
			local b = new("TextButton", {
				Position = UDim2.fromOffset(4, 4 + (i - 1) * (ROW_H + GAP)),
				Size = UDim2.new(1, -8, 0, ROW_H),
				BackgroundColor3 = T.bg,
				Text = "",
				TextColor3 = T.text,
				Font = Enum.Font.GothamMedium,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				RichText = true,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 31,
			}, panel)
			round(b, 6)
			new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
			rbtn[i] = b
		end

		local function refreshRar()
			for i, n in ipairs(RN) do
				local chk = (n == "Semua" and rarSelN == 0) or rarSel[n] == true
				local col = api.colors[n] or WHITE
				rbtn[i].Text = string.format('<font color="#%s">●</font>  %s%s', col:ToHex(), n, chk and "   ✓" or "")
				rbtn[i].BackgroundColor3 = chk and T.cardSel or T.bg
			end
			local label = "Rarity"
			if rarSelN == 1 then
				label = tostring(next(rarSel))
			elseif rarSelN > 1 then
				label = rarSelN .. " rarity"
			end
			local active = rarSelN > 0
			rarBtn.Text = label .. (panel.Visible and " ▲" or " ▼")
			rarBtn.BackgroundColor3 = active and T.accent or T.bg
			rarBtn.TextColor3 = active and WHITE or T.sub
		end

		for i, n in ipairs(RN) do
			rbtn[i].MouseButton1Click:Connect(function()
				if n == "Semua" then
					table.clear(rarSel)
					rarSelN = 0
					panel.Visible = false
				else
					if rarSel[n] then
						rarSel[n] = nil
						rarSelN -= 1
					else
						rarSel[n] = true
						rarSelN += 1
					end
					api.ensure()
					if api.loading then toast("Memuat data rarity...") end
				end
				refreshRar()
				onFilterChanged()
			end)
		end

		rarBtn.MouseButton1Click:Connect(function()
			panel.Visible = not panel.Visible
			if panel.Visible then api.ensure() end
			refreshRar()
		end)

		-- data rarity selesai dimuat -> warnai ulang daftar & label, terapkan filter
		api.listeners[#api.listeners + 1] = function()
			if unloaded then return end
			if api.failed then toast("Data rarity tidak ditemukan di game ini") end
			for name, r in pairs(rows) do
				if r.nmL then r.nmL.TextColor3 = rarityColor(name) or T.text end
			end
			markDue = true
			onFilterChanged()
		end

		refreshRar()
	end
end

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
		if e.dot and not e.dot:IsDescendantOf(playerGui) then
			e.dot = nil
			e.dotFrame = nil
			dotCount = math.max(0, dotCount - 1)
		end
		if e.label and not e.label:IsDescendantOf(playerGui) then
			e.label = nil
			e.distLbl = nil
			e.nameLbl = nil
			e.lblStroke = nil
			e.rarV = nil
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
			applyRarityColor(e)
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

-- ---------- KATALOG PERMANEN (per game) ----------
-- Nama item yang pernah terlihat + centangan disimpan ke file, jadi daftar langsung lengkap
-- begitu script dijalankan lagi (tanpa menunggu item respawn atau menekan SCAN).
local HttpService = game:GetService("HttpService")
-- ---------- POP-UP ITEM (pin) ----------
-- Bilah yang selalu tampil (walau menu ditutup). Isinya item yang kamu pin dengan tombol PIN di daftar.
--  * Klik nama item = TP ke item terdekat (klik lagi = item berikutnya)
--  * X = hapus item dari pop-up
--  * Garis tiga di kiri = geser pop-up
--  * Titik-titik di pojok kanan bawah = ubah ukuran bebas (lebar & tinggi), sama seperti menu utama.
--    Makin lebar = kotak item makin lebar; makin sempit = item turun ke baris baru; makin tinggi = kotak & huruf makin besar.
do
	local PIN_MAX = 6 -- jumlah maksimal item di pop-up
	-- Ukuran dasar = BATAS MAKSIMAL (skala 1.0). Bilah bisa diperkecil sesuai keinginan (skala MIN_SC..1.0)
	-- dan diperpanjang ke samping. Bawaan awal: skala 0.75.
	local K: any = {
		STRIP = 16, RW = 18, PAD = 4, GAP = 4,
		MIN_W = 130,
		BASE_CH = 26, BASE_NS = 12, BASE_IS = 11, BASE_XS = 16,
		MIN_SC = 0.55, MAX_SC = 1, DEF_SC = 0.75,
	}
	K.AREA_L, K.AREA_R = K.STRIP + 2, K.RW + 2
	local TextService = game:GetService("TextService")

	local function textW(txt: string, font: Enum.Font, size: number): number
		local okM, sz = pcall(function()
			return TextService:GetTextSize(txt, size, font, Vector2.new(100000, 100000))
		end)
		return okM and sz.X or (#txt * size * 0.6)
	end
	-- hitung ukuran kotak & huruf dari skala (info punya lebar tetap supaya kotak tidak "bergoyang")
	local function applyScale(s: number)
		s = math.clamp(s, K.MIN_SC, K.MAX_SC)
		pin.sc = s
		K.CH = math.floor(K.BASE_CH * s + 0.5)
		K.NS = math.max(7, math.floor(K.BASE_NS * s + 0.5))
		K.IS = math.max(7, math.floor(K.BASE_IS * s + 0.5))
		K.XS = math.max(10, math.floor(K.BASE_XS * s + 0.5))
		K.IW = math.ceil(textW("×99 · 9999 st", Enum.Font.GothamBold, K.IS)) + 4
	end
	applyScale(pin.sc or K.DEF_SC)

	local function clampBar(w: number, h: number): (number, number)
		local maxW = math.max(K.MIN_W, viewport().X - 20)
		return math.clamp(w, K.MIN_W, maxW), h
	end
	pin.w, pin.h = clampBar(pin.w, pin.h)

	local bar = new("Frame", {
		Name = "PinBar",
		AnchorPoint = Vector2.new(0, 0),
		Position = UDim2.new(0.5, -pin.w / 2, 0, 36),
		Size = UDim2.fromOffset(pin.w, K.CH + 2 * K.PAD),
		BackgroundColor3 = T.bgTop,
		BackgroundTransparency = 0.12,
		BorderSizePixel = 0,
		Visible = false,
	}, gui)
	round(bar, 10)
	stroke(bar, T.accent, 1.2, 0.35)

	-- gagang geser (kiri): tiga garis digambar sendiri
	local mover = new("TextButton", {
		Size = UDim2.new(0, K.STRIP, 1, 0),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, bar)
	local moverLines = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(10, 10),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, mover)
	new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, moverLines)
	for i = 1, 3 do
		local ln = new("Frame", {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 2),
			BackgroundColor3 = T.sub,
			BorderSizePixel = 0,
		}, moverLines)
		round(ln, 1)
	end
	makeDraggable(mover, bar)

	-- area isi: kotak disusun dari kiri, turun ke baris baru kalau bilah dipendekkan
	local area = new("Frame", {
		Position = UDim2.fromOffset(K.AREA_L, K.PAD),
		Size = UDim2.new(1, -(K.AREA_L + K.AREA_R), 1, -2 * K.PAD),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, bar)

	-- gagang perpanjang (kanan bawah): hanya mengubah PANJANG, tinggi terkunci
	local rgrip = new("TextButton", {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -1, 1, -1),
		Size = UDim2.fromOffset(K.RW, K.RW),
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		ZIndex = 5,
	}, bar)
	for row = 0, 2 do
		for col = 0, 2 - row do
			local d = new("Frame", {
				Position = UDim2.fromOffset(13 - col * 4, 13 - row * 4),
				Size = UDim2.fromOffset(3, 3),
				BackgroundColor3 = T.sub,
				BorderSizePixel = 0,
				ZIndex = 5,
			}, rgrip)
			round(d, 1)
		end
	end

	local chips: { [string]: any } = {}

	local function distInfo(name: string): string
		local g = groups[name]
		if not g then return "×0" end
		local hrp = getRoot()
		if not hrp then return "..." end
		local n, best = 0, math.huge
		for _, e in ipairs(g.list) do
			local part = e.part
			if part and part.Parent then
				n += 1
				local d = (part.Position - hrp.Position).Magnitude
				if d < best then best = d end
			end
		end
		if n == 0 then return "×0" end
		return string.format("×%d · %d st", n, math.floor(best + 0.5))
	end

	-- susun kotak: lebar tiap kotak mengikuti panjang namanya, tinggi tetap
	local function relayout()
		local innerW = pin.w - K.AREA_L - K.AREA_R
		local x, r = 0, 0
		for _, name in ipairs(pin.list) do
			local c = chips[name]
			if c then
				local want = math.ceil(textW(name, Enum.Font.GothamBold, K.NS)) + K.IW + K.XS + 32
				local w = math.min(want, innerW)
				if x > 0 and x + w > innerW then
					x = 0
					r += 1
				end
				c.chip.Position = UDim2.fromOffset(x, r * (K.CH + K.GAP))
				c.chip.Size = UDim2.fromOffset(w, K.CH)
				c.holder.Size = UDim2.new(1, -(K.XS + 8), 1, 0)
				c.nm.TextSize = K.NS
				c.nm.Size = UDim2.new(1, -(8 + K.IW + 8), 1, 0)
				c.info.TextSize = K.IS
				c.info.Size = UDim2.new(0, K.IW, 1, 0)
				c.x.Size = UDim2.fromOffset(K.XS, K.XS)
				c.x.TextSize = math.max(7, K.NS - 3)
				x += w + K.GAP
			end
		end
		local nRows = (#pin.list > 0) and (r + 1) or 1
		pin.h = nRows * K.CH + (nRows - 1) * K.GAP + 2 * K.PAD
		bar.Size = UDim2.fromOffset(pin.w, pin.h)
	end

	local function buildChip(name: string, idx: number)
		local chip = new("Frame", {
			LayoutOrder = idx,
			Size = UDim2.fromOffset(120, K.CH),
			BackgroundColor3 = T.bg,
			BorderSizePixel = 0,
		}, area)
		round(chip, 7)
		local st = stroke(chip, T.stroke, 1, 0.2)

		-- area nama + info: klik = TP
		local holder = new("TextButton", {
			Size = UDim2.new(1, -(K.XS + 8), 1, 0),
			BackgroundTransparency = 1,
			Text = "",
			AutoButtonColor = false,
			ClipsDescendants = true,
			BorderSizePixel = 0,
		}, chip)
		local nm = text(holder, {
			Text = name,
			Font = Enum.Font.GothamBold,
			TextSize = K.NS,
			TextWrapped = false,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -(8 + K.IW + 8), 1, 0),
		})
		local info = text(holder, {
			Text = "",
			Font = Enum.Font.GothamBold,
			TextSize = K.IS,
			TextColor3 = T.sub,
			TextXAlignment = Enum.TextXAlignment.Right,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -2, 0, 0),
			Size = UDim2.new(0, K.IW, 1, 0),
		})

		holder.MouseButton1Click:Connect(function()
			local g = groups[name]
			if g then
				teleportToNearest(g)
			else
				toast("Belum ada di map (belum respawn)")
			end
		end)
		holder.MouseEnter:Connect(function()
			tween(chip, { BackgroundColor3 = lighten(T.bg) }, 0.1)
		end)
		holder.MouseLeave:Connect(function()
			tween(chip, { BackgroundColor3 = T.bg }, 0.1)
		end)

		local x = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -4, 0.5, 0),
			Size = UDim2.fromOffset(K.XS, K.XS),
			BackgroundColor3 = T.off,
			Text = "X",
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 9,
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, chip)
		new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, x)
		hover(x, T.off)
		x.MouseButton1Click:Connect(function()
			pin.toggle(name)
		end)

		chips[name] = { chip = chip, holder = holder, nm = nm, info = info, st = st, x = x, infoStr = "" }
	end

	local function tickBar()
		for name, c in pairs(chips) do
			local s = distInfo(name)
			if s ~= c.infoStr then
				c.infoStr = s
				c.info.Text = s
			end
			local col = rarityColor(name)
			c.nm.TextColor3 = col or T.text
			c.st.Color = col or T.stroke
		end
	end

	local function refreshBar()
		for _, c in pairs(chips) do
			c.chip:Destroy()
		end
		table.clear(chips)
		for i, name in ipairs(pin.list) do
			buildChip(name, i)
		end
		bar.Visible = #pin.list > 0
		relayout()
		tickBar()
	end

	-- gagang kanan bawah: geser kiri/kanan = panjang bilah; geser atas = perkecil, bawah = perbesar (maks = ukuran dasar)
	local resizing = false
	local sMouse, sW, sS = Vector3.zero, 0, 1
	rgrip.InputBegan:Connect(function(input)
		if isPointer(input) then
			resizing = true
			sMouse = input.Position
			sW, sS = pin.w, pin.sc
		end
	end)
	track(UIS.InputChanged:Connect(function(input)
		if resizing and isMove(input) then
			local d = input.Position - sMouse
			pin.w = clampBar(sW + d.X, pin.h)
			applyScale(sS + d.Y / 80)
			relayout()
		end
	end))
	track(UIS.InputEnded:Connect(function(input)
		if resizing and isPointer(input) then
			resizing = false
			persistDirty = true
		end
	end))

	pin.add = function(name: string): boolean
		if pin.set[name] then return true end
		if #pin.list >= PIN_MAX then return false end
		pin.set[name] = true
		pin.list[#pin.list + 1] = name
		return true
	end

	pin.toggle = function(name: string)
		if pin.set[name] then
			pin.set[name] = nil
			local i = table.find(pin.list, name)
			if i then table.remove(pin.list, i) end
		elseif not pin.add(name) then
			toast("Pop-up penuh (maks " .. PIN_MAX .. " item) — hapus satu dulu dengan X")
			return
		end
		persistDirty = true
		refreshBar()
		local r = rows[name]
		if r then r.apply() end
	end

	-- dipanggil sekali setelah ukuran & pin tersimpan dimuat
	pin.refresh = function()
		applyScale(pin.sc or K.DEF_SC)
		pin.w, pin.h = clampBar(pin.w, pin.h)
		bar.Position = UDim2.new(0.5, -pin.w / 2, 0, 36)
		refreshBar()
	end

	local accT = 0
	track(RunService.Heartbeat:Connect(function(dt)
		accT += dt
		if accT < 0.5 then return end
		accT = 0
		if bar.Visible then tickBar() end
	end))
end

local catPath = tostring(settings.saveFolder) .. "/items_" .. tostring(game.GameId) .. ".json"

local function saveCatalog()
	if not writefile then return end
	local names = {}
	for _, cg in pairs(catalog) do
		local cats = {}
		for c in pairs(cg.cats) do cats[#cats + 1] = c end
		names[#names + 1] = { n = cg.name, c = cats }
	end
	local sel = {}
	for nm, v in pairs(itemSel) do
		if v then sel[#sel + 1] = nm end
	end
	local okJ, json = pcall(function() return HttpService:JSONEncode({ names = names, sel = sel, pins = pin.list, pinW = pin.w, pinH = pin.h, pinS = pin.sc }) end)
	if not okJ then return end
	if makefolder and isfolder and not isfolder(settings.saveFolder) then
		pcall(makefolder, settings.saveFolder)
	end
	pcall(writefile, catPath, json)
	persistDirty = false
end

local loadedCatalog = false
if readfile and isfile and isfile(catPath) then
	local okL, data = pcall(function() return HttpService:JSONDecode(readfile(catPath)) end)
	if okL and type(data) == "table" then
		if type(data.names) == "table" then
			for _, it in ipairs(data.names) do
				if type(it) == "table" and type(it.n) == "string" and it.n ~= "" then
					local cats = {}
					if type(it.c) == "table" then
						for _, c in ipairs(it.c) do
							if type(c) == "string" and PRI[c] then cats[c] = true end
						end
					end
					catalog[it.n] = { name = it.n, lower = string.lower(it.n), cats = cats }
				end
			end
		end
		if type(data.sel) == "table" then
			for _, nm in ipairs(data.sel) do
				if type(nm) == "string" and catalog[nm] then itemSel[nm] = true end
			end
		end
		if type(data.pinW) == "number" and type(data.pinH) == "number" then
			pin.w, pin.h = data.pinW, data.pinH
		end
		if type(data.pinS) == "number" then pin.sc = data.pinS end
		if type(data.pins) == "table" then
			for _, nm in ipairs(data.pins) do
				if type(nm) == "string" then pin.add(nm) end
			end
		end
		pin.refresh()
		orderDirty = true
		loadedCatalog = next(catalog) ~= nil
	end
end

-- ---------- SERVER HOP ----------
-- Pindah ke server publik lain (daftar diambil dari API Roblox). Script otomatis jalan lagi di server baru
-- lewat R4MEN_auto.lua, dan katalog + centangan item langsung dimuat.
do
	local TeleportService = game:GetService("TeleportService")
	local hopFile = tostring(settings.saveFolder) .. "/hop_visited.json"
	local HOP_SKIP_SECONDS = 1800 -- server yang baru dikunjungi tidak dipilih lagi selama 30 menit
	local hopMode = "Sepi"
	local hopping = false

	local hopBtn = new("TextButton", {
		Position = UDim2.fromOffset(14, 296),
		Size = UDim2.new(1, -28 - 98, 0, 32),
		BackgroundColor3 = T.accent,
		Text = "🌐 HOP SERVER",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, scannerCard)
	round(hopBtn, 8)
	hover(hopBtn, T.accent)

	local modeBtn = smallButton(scannerCard, "Mode: Sepi", UDim2.fromOffset(90, 32), 0)
	modeBtn.AnchorPoint = Vector2.new(1, 0)
	modeBtn.Position = UDim2.new(1, -14, 0, 296)
	hover(modeBtn, T.bg)
	modeBtn.MouseButton1Click:Connect(function()
		hopMode = (hopMode == "Sepi") and "Acak" or "Sepi"
		modeBtn.Text = "Mode: " .. hopMode
	end)

	local function resetHop()
		hopping = false
		hopBtn.Text = "🌐 HOP SERVER"
	end

	local function httpGet(url: string): string?
		local req = (syn and syn.request) or http_request or request or (fluxus and fluxus.request)
		if req then
			local okR, res = pcall(req, { Url = url, Method = "GET" })
			if okR and type(res) == "table" and res.Body and (res.StatusCode == nil or res.StatusCode == 200) then
				return res.Body
			end
		end
		local okG, body = pcall(function() return game:HttpGet(url) end)
		if okG and type(body) == "string" then return body end
		return nil
	end

	local function loadVisited(): { [string]: number }
		local t = {}
		if readfile and isfile and isfile(hopFile) then
			local okV, d = pcall(function() return HttpService:JSONDecode(readfile(hopFile)) end)
			if okV and type(d) == "table" then
				for id, ts in pairs(d) do
					if type(id) == "string" and type(ts) == "number" and os.time() - ts < HOP_SKIP_SECONDS then
						t[id] = ts
					end
				end
			end
		end
		return t
	end

	local function fetchServers(): { any }
		local list, cursor = {}, nil
		for _ = 1, 3 do
			local url = string.format(
				"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100%s",
				game.PlaceId,
				cursor and ("&cursor=" .. cursor) or ""
			)
			local body = httpGet(url)
			if not body then break end
			local okJ, d = pcall(function() return HttpService:JSONDecode(body) end)
			if not okJ or type(d) ~= "table" or type(d.data) ~= "table" then break end
			for _, sv in ipairs(d.data) do list[#list + 1] = sv end
			cursor = d.nextPageCursor
			if type(cursor) ~= "string" then break end
		end
		return list
	end

	local function doHop()
		if hopping then return end
		hopping = true
		hopBtn.Text = "Mencari server..."
		task.spawn(function()
			local visited = loadVisited()
			visited[game.JobId] = os.time()

			local cands = {}
			for _, sv in ipairs(fetchServers()) do
				if type(sv) == "table" and type(sv.id) == "string" and sv.id ~= game.JobId and not visited[sv.id]
					and type(sv.playing) == "number" and type(sv.maxPlayers) == "number"
					and sv.playing < sv.maxPlayers - 1 then
					cands[#cands + 1] = sv
				end
			end

			if #cands == 0 then
				toast("Tidak ada server yang cocok (atau gagal mengambil daftar server)")
				resetHop()
				return
			end

			local pick
			if hopMode == "Sepi" then
				table.sort(cands, function(a, b) return a.playing < b.playing end)
				pick = cands[math.random(1, math.min(#cands, 5))]
			else
				pick = cands[math.random(1, #cands)]
			end

			visited[pick.id] = os.time()
			if writefile then
				if makefolder and isfolder and not isfolder(settings.saveFolder) then
					pcall(makefolder, settings.saveFolder)
				end
				pcall(writefile, hopFile, HttpService:JSONEncode(visited))
			end
			if persistDirty then pcall(saveCatalog) end

			toast(string.format("Pindah ke server (%d/%d pemain)...", pick.playing, pick.maxPlayers))
			local okT, errT = pcall(function()
				TeleportService:TeleportToPlaceInstance(game.PlaceId, pick.id, Players.LocalPlayer)
			end)
			if not okT then
				toast("Gagal teleport: " .. tostring(errT))
				resetHop()
				return
			end
			task.delay(20, function()
				if hopping and not unloaded then resetHop() end
			end)
		end)
	end

	hopBtn.MouseButton1Click:Connect(doHop)
	track(TeleportService.TeleportInitFailed:Connect(function(_, _, msg)
		toast("Teleport gagal: " .. tostring(msg))
		resetHop()
	end))
end

local saveAcc = 0
track(RunService.Heartbeat:Connect(function(dt: number)
	if unloaded then return end
	saveAcc += dt
	if saveAcc >= 3 then
		saveAcc = 0
		if persistDirty then pcall(saveCatalog) end
	end
end))

applyFilter()
refreshStatus()

if loadedCatalog then
	flushUI()
	-- Ada katalog tersimpan: nyalakan Live + scan otomatis supaya item yang sudah dicentang langsung tertandai
	task.delay(2, function()
		if not unloaded and not scanning and not autoScan then
			scanItems()
		end
	end)
end

end -- runScanner

runScanner()

end -- tutup do (Item ESP v2)

sectionLabel(teleportPage, 6, "Waypoint & Free Cam")

addSliderCard(teleportPage, 90, "Free Cam", "WASD + E/Q, Shift cepat, klik kanan = lihat", "freecam", 5, 600, 1000)

local topCard = makeCard(teleportPage, 112, 7)
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
	LayoutOrder = 8,
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
		values = table.clone(values),
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
			-- data lama tidak punya antiAfk: biarkan nilainya, jangan dimatikan diam-diam
			if key ~= "antiAfk" or d.state[key] ~= nil then
				setFeature(key, d.state[key] == true)
			end
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
		or (writefile and "Penyimpanan: file lokal (folder workspace executor)")
		or "Penyimpanan: sesi ini saja (hilang saat keluar)"
end

rebuildSlots()

-- =====================================================
-- PENYIMPANAN FILE LOKAL (writefile/readfile)
--  settings.json     : keybind, speed/jump/freecam, ukuran panel (global, semua game)
--  wp_<GameId>.json  : waypoint (terpisah per game)
--  slots.json        : daftar Config yang kamu simpan (global)
-- Semua dibungkus pcall; kalau executor tidak mendukung, bagian ini dilewati.
-- =====================================================
task.spawn(function()
	if not (writefile and readfile and isfile) then return end
	local HttpService = game:GetService("HttpService")

	local folder = tostring(settings.saveFolder or "R4MEN")
	local useFolder = false
	if makefolder and isfolder then
		pcall(function()
			if not isfolder(folder) then makefolder(folder) end
			useFolder = isfolder(folder) == true
		end)
	end

	local function path(name: string): string
		if useFolder then return folder .. "/" .. name end
		return folder .. "_" .. name
	end

	local function readJson(name: string): any
		local ok, res = pcall(function()
			local p = path(name)
			if not isfile(p) then return nil end
			return HttpService:JSONDecode(readfile(p))
		end)
		if ok and type(res) == "table" then return res end
		return nil
	end

	local function encode(t: any): string?
		local ok, res = pcall(function() return HttpService:JSONEncode(t) end)
		if ok and type(res) == "string" then return res end
		return nil
	end

	local wpFile = "wp_" .. tostring(game.GameId) .. ".json"

	local function globalData(): any
		local d = snapshot(false)
		-- hanya Anti-AFK yang ikut tersimpan otomatis (fitur lain sengaja mati saat game dibuka)
		d.state = { antiAfk = state.antiAfk == true }
		d.wps = nil
		return d
	end

	local function wpData(): any
		return { wps = snapshot(true).wps }
	end

	-- ---------- muat ----------
	local g = readJson("settings.json")
	if g then
		-- Anti-AFK selalu mulai AKTIF tiap kali skrip dijalankan; nilai lama di file tidak dipakai
		-- (file lama menyimpan antiAfk = false dari versi sebelumnya).
		g.state = nil
		pcall(applySnapshot, g)
	end

	local w = readJson(wpFile)
	if w and type(w.wps) == "table" then pcall(applySnapshot, { wps = w.wps }) end

	if not remote then
		local sl = readJson("slots.json")
		if sl then
			for _, sv in ipairs(sl) do
				if #slots >= MAX_SLOTS then break end
				if type(sv) == "table" and type(sv.name) == "string" and type(sv.data) == "table"
					and type(sv.data.values) == "table" and type(sv.data.state) == "table" then
					table.insert(slots, { name = sv.name, data = sv.data })
				end
			end
			if not unloaded then rebuildSlots() end
		end
	end

	-- ---------- simpan otomatis (hanya menulis kalau ada perubahan) ----------
	local lastG = encode(globalData())
	local lastW = encode(wpData())
	local lastS = encode(slots)

	while not unloaded do
		task.wait(3)
		if unloaded then break end

		local eg = encode(globalData())
		if eg and eg ~= lastG then
			lastG = eg
			pcall(writefile, path("settings.json"), eg)
		end

		local ew = encode(wpData())
		if ew and ew ~= lastW then
			lastW = ew
			pcall(writefile, path(wpFile), ew)
		end

		if not remote then
			local es = encode(slots)
			if es and es ~= lastS then
				lastS = es
				pcall(writefile, path("slots.json"), es)
			end
		end
	end
end)

task.spawn(function()
	local r = ReplicatedStorage:WaitForChild("CP_ConfigRemote", 5)
	if r and r:IsA("RemoteFunction") and not unloaded then
		local ok, res = pcall(function() return r:InvokeServer("load") end)
		if ok and type(res) == "table" then
			remote = r
			table.clear(slots)
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
-- GUI: TES DETEKSI RARITY (otomatis, tanpa harus memetik item)
-- Memeriksa: item di dunia (Attribute / Value / nama / teks GUI), ReplicatedStorage
-- (Attribute, Value, folder bernama rarity) dan ModuleScript data (require, dibatasi waktu).
-- Kartu kecil di tab Config: tekan SCAN, lalu "Salin hasil" (juga disimpan ke <saveFolder>/rarity_scan.txt).
-- Dibungkus xpcall + function supaya tidak menambah jumlah local di level atas
-- dan kalau ada error tidak merusak script lain.
-- =====================================================
xpcall(function()
	local RAR_WORDS = { "legendary", "mythical", "mythic", "epic", "uncommon", "common", "rare", "exotic", "divine", "godly", "secret", "unique" }
	local KEY_WORDS = { "rarity", "tier", "grade" }
	local MOD_WORDS = { "item", "mushroom", "shroom", "fung", "rarit", "data", "config", "loot", "drop", "forag", "catalog", "info", "stat", "list", "const", "shop", "crop", "plant" }

	-- kata rarity yang muncul di dalam teks (mis. "Epic Mushroom" -> "epic")
	local function wordIn(s)
		local l = string.lower(tostring(s))
		for _, w in ipairs(RAR_WORDS) do
			if string.find(l, "%f[%a]" .. w .. "%f[%A]") then return w end
		end
		return nil
	end

	-- teks yang HANYA berisi kata rarity (mis. nama folder "Epic")
	local function exactWord(s)
		local l = string.lower(tostring(s))
		l = string.gsub(l, "[%s_%-]", "")
		for _, w in ipairs(RAR_WORDS) do
			if l == w then return w end
		end
		return nil
	end

	-- nama atribut/field yang menandakan rarity (Rarity, ItemRarity, Tier, Grade, ...)
	local function isKey(k)
		local l = string.lower(tostring(k))
		for _, w in ipairs(KEY_WORDS) do
			if string.find(l, w, 1, true) then return true end
		end
		return false
	end

	-- ---------- UI (kecil, di tab Config) ----------
	local card = makeCard(configPage, 112, 200)
	text(card, {
		Text = "Tes Deteksi Rarity",
		Font = Enum.Font.GothamBold,
		TextSize = 13,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 18),
	})

	local scanB = new("TextButton", {
		Position = UDim2.fromOffset(14, 34),
		Size = UDim2.new(0.5, -18, 0, 28),
		BackgroundColor3 = T.accent,
		Text = "🔎 SCAN",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
	}, card)
	round(scanB, 8)
	hover(scanB, T.accent)

	local copyB = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 34),
		Size = UDim2.new(0.5, -18, 0, 28),
		BackgroundColor3 = T.bg,
		Text = "Salin hasil",
		TextColor3 = T.sub,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, card)
	round(copyB, 8)
	stroke(copyB, T.stroke, 1, 0.3)

	local status = text(card, {
		Text = "Belum scan. Dekati area mushroom, tekan SCAN, lalu Salin hasil.",
		TextSize = 11,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 68),
		Size = UDim2.new(1, -28, 0, 38),
	})

	local busy = false
	local lastReport = ""

	local function setStatus(s, col)
		status.Text = s
		status.TextColor3 = col or T.sub
	end

	-- Telusuri tabel data hasil require: cari entri yang punya field rarity,
	-- atau tabel yang dikelompokkan per kata rarity ({ Epic = { "Black Truffle", ... } }).
	local function scanTable(root, modName, found)
		local seen = {}
		local nodes = 0
		local function walk(t, depth, key)
			if depth > 5 or seen[t] or nodes > 4000 then return end
			seen[t] = true
			nodes = nodes + 1

			local rv = nil
			for k, v in pairs(t) do
				if type(k) == "string" and isKey(k) and (type(v) == "string" or type(v) == "number") then
					rv = v
					break
				end
			end
			if rv ~= nil then
				local nm = t.Name or t.DisplayName or t.name or t.displayName or t.Title or key
				if nm ~= nil then
					table.insert(found, { name = tostring(nm), rar = tostring(rv), src = modName })
				end
			end

			for k, v in pairs(t) do
				if type(v) == "table" then
					if type(k) == "string" and exactWord(k) then
						for ik, iv in pairs(v) do
							local nm = nil
							if type(iv) == "string" then
								nm = iv
							elseif type(ik) == "string" then
								nm = ik
							elseif type(iv) == "table" then
								nm = iv.Name or iv.DisplayName or iv.name
							end
							if nm ~= nil then
								table.insert(found, { name = tostring(nm), rar = k, src = modName })
							end
						end
					end
					walk(v, depth + 1, (type(k) == "string") and k or key)
				end
			end
		end
		pcall(walk, root, 0, nil)
	end

	local function run()
		if busy or unloaded then return end
		busy = true
		scanB.Text = "Memindai..."
		setStatus("Memindai item di dunia...", T.sub)

		local lines = {}
		local function add(s) lines[#lines + 1] = s end

		local yieldN = 0
		local function maybeYield()
			yieldN = yieldN + 1
			if yieldN % 2500 == 0 then task.wait() end
		end

		add("== TES DETEKSI RARITY ==")
		add("GameId: " .. tostring(game.GameId))

		-- ---------- 1) ITEM DI DUNIA (lewat ProximityPrompt) ----------
		local prompts, pickPrompts, groups = {}, {}, {}
		local function checkGroup(d, src)
			if d:IsA("Folder") or d:IsA("Configuration") or d:IsA("Model") then
				local rw = exactWord(d.Name)
				if rw and #d:GetChildren() > 0 then
					table.insert(groups, { rar = rw, inst = d, src = src })
				end
			end
		end

		for _, d in ipairs(workspace:GetDescendants()) do
			maybeYield()
			if d:IsA("ProximityPrompt") then
				table.insert(prompts, d)
				local at = string.lower(d.ActionText)
				if string.find(at, "pick", 1, true) then
					table.insert(pickPrompts, d)
				end
			else
				checkGroup(d, "Workspace")
			end
		end

		local use = (#pickPrompts > 0) and pickPrompts or prompts
		local seenM, items = {}, {}
		for _, pr in ipairs(use) do
			if #items >= 150 then break end
			local m = pr:FindFirstAncestorOfClass("Model") or pr.Parent
			if m and not seenM[m] then
				seenM[m] = true
				table.insert(items, { m = m, pr = pr })
			end
		end

		local function inspect(inst, ev, tag)
			for k, v in pairs(inst:GetAttributes()) do
				if type(v) == "string" or type(v) == "number" then
					if isKey(k) or (type(v) == "string" and wordIn(v)) then
						table.insert(ev, { k = "attr", t = "Attribute " .. tostring(k) .. "=" .. tostring(v) .. " [" .. tag .. "]" })
					end
				end
			end
			if inst:IsA("ValueBase") then
				local okv, val = pcall(function() return inst.Value end)
				if okv and (type(val) == "string" or type(val) == "number") then
					if isKey(inst.Name) or (type(val) == "string" and wordIn(val)) then
						table.insert(ev, { k = "val", t = "Value " .. inst.Name .. "=" .. tostring(val) })
					end
				end
			end
			if inst:IsA("TextLabel") or inst:IsA("TextButton") then
				if wordIn(inst.Text) then
					table.insert(ev, { k = "gui", t = "Teks GUI '" .. inst.Text .. "'" })
				end
			end
		end

		local withEv = 0
		local kinds = { attr = 0, val = 0, gui = 0, name = 0 }
		local samples = {}
		local noEvShape = {}

		for _, it in ipairs(items) do
			local ev = {}
			inspect(it.m, ev, "model")
			inspect(it.pr, ev, "prompt")
			local n = 0
			for _, d in ipairs(it.m:GetDescendants()) do
				n = n + 1
				if n > 250 then break end
				inspect(d, ev, d.ClassName)
			end
			local label = (it.pr.ObjectText ~= "" and it.pr.ObjectText) or it.m.Name
			if wordIn(it.m.Name) then
				table.insert(ev, { k = "name", t = "Nama model '" .. it.m.Name .. "'" })
			end
			if it.pr.ObjectText ~= "" and wordIn(it.pr.ObjectText) then
				table.insert(ev, { k = "name", t = "Nama prompt '" .. it.pr.ObjectText .. "'" })
			end

			if #ev > 0 then
				withEv = withEv + 1
				local got = {}
				for _, e in ipairs(ev) do
					if not got[e.k] then
						got[e.k] = true
						kinds[e.k] = kinds[e.k] + 1
					end
				end
				if #samples < 8 then
					table.insert(samples, "  • " .. label .. " -> " .. ev[1].t)
				end
			elseif #noEvShape < 2 then
				-- bentuk isi model yang tidak punya info rarity (untuk dibaca manual)
				local attrs = {}
				for k, v in pairs(it.m:GetAttributes()) do
					if #attrs < 12 then table.insert(attrs, tostring(k) .. "=" .. tostring(v)) end
				end
				local kids = {}
				local c = 0
				for _, d in ipairs(it.m:GetDescendants()) do
					c = c + 1
					if c > 18 then break end
					table.insert(kids, d.Name .. "(" .. d.ClassName .. ")")
				end
				table.insert(noEvShape, "  - " .. label .. " | Attribute: " .. (#attrs > 0 and table.concat(attrs, ", ") or "(kosong)")
					.. " | Isi: " .. table.concat(kids, ", "))
			end
		end

		add("")
		add("[1] ITEM DI DUNIA (ProximityPrompt): " .. #items .. " item dicek, " .. withEv .. " membawa info rarity")
		if #items == 0 then
			add("  Tidak ada item ber-prompt yang termuat. Dekati area mushroom (game bisa memuat item hanya di sekitarmu) lalu scan lagi.")
		else
			add("  Sumber: Attribute " .. kinds.attr .. " | Value " .. kinds.val .. " | Nama " .. kinds.name .. " | Teks GUI " .. kinds.gui)
			for _, s in ipairs(samples) do add(s) end
			if withEv == 0 then
				add("  Contoh isi item (tanpa info rarity):")
				for _, s in ipairs(noEvShape) do add(s) end
			end
		end

		-- ---------- 2) REPLICATEDSTORAGE ----------
		setStatus("Memindai ReplicatedStorage...", T.sub)
		local rsHits = {}
		local mods = {}
		for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
			maybeYield()
			for k, v in pairs(d:GetAttributes()) do
				if (type(v) == "string" or type(v) == "number") and (isKey(k) or (type(v) == "string" and wordIn(v))) then
					if #rsHits < 40 then
						table.insert(rsHits, d:GetFullName() .. " [Attribute " .. tostring(k) .. "=" .. tostring(v) .. "]")
					end
				end
			end
			if d:IsA("ValueBase") then
				local okv, val = pcall(function() return d.Value end)
				if okv and (type(val) == "string" or type(val) == "number") and (isKey(d.Name) or (type(val) == "string" and wordIn(val))) then
					if #rsHits < 40 then
						table.insert(rsHits, d:GetFullName() .. " [Value " .. tostring(val) .. "]")
					end
				end
			end
			if d:IsA("ModuleScript") then
				local l = string.lower(d.Name)
				for _, w in ipairs(MOD_WORDS) do
					if string.find(l, w, 1, true) then
						table.insert(mods, d)
						break
					end
				end
			end
			checkGroup(d, "ReplicatedStorage")
		end

		add("")
		add("[2] REPLICATEDSTORAGE: " .. #rsHits .. " atribut/value berinfo rarity, " .. #mods .. " modul data kandidat")
		for i = 1, math.min(#rsHits, 6) do add("  • " .. rsHits[i]) end

		-- ---------- 3) MODUL DATA (require, dibatasi waktu) ----------
		setStatus("Membaca modul data (" .. #mods .. ")...", T.sub)
		local found = {}
		local modOk, modFail = 0, 0
		for i, m in ipairs(mods) do
			if i > 80 or unloaded then break end
			local done, res = false, nil
			task.spawn(function()
				local ok, r = pcall(require, m)
				if ok then res = r end
				done = true
			end)
			local t0 = os.clock()
			while not done and os.clock() - t0 < 1.5 do task.wait() end
			if done and type(res) == "table" then
				modOk = modOk + 1
				scanTable(res, m.Name, found)
			else
				modFail = modFail + 1
			end
		end

		-- buang duplikat (nama sama)
		local uniq, seenN = {}, {}
		for _, f in ipairs(found) do
			local key = string.lower(f.name)
			if not seenN[key] then
				seenN[key] = true
				table.insert(uniq, f)
			end
		end

		add("")
		add("[3] MODUL DATA: " .. modOk .. " terbaca, " .. modFail .. " gagal/terlalu lama, " .. #uniq .. " entri berinfo rarity")
		for i = 1, math.min(#uniq, 12) do
			add("  • " .. uniq[i].name .. " -> " .. uniq[i].rar .. "  (" .. uniq[i].src .. ")")
		end

		-- ---------- FOLDER BERNAMA RARITY ----------
		add("")
		add("[4] FOLDER BERNAMA RARITY (Common/Epic/...): " .. #groups .. " ditemukan")
		for i = 1, math.min(#groups, 8) do
			local g = groups[i]
			local names = {}
			for j, ch in ipairs(g.inst:GetChildren()) do
				if j > 5 then break end
				table.insert(names, ch.Name)
			end
			add("  • " .. g.src .. "." .. g.inst.Name .. " (" .. #g.inst:GetChildren() .. " isi): " .. table.concat(names, ", "))
		end

		-- ---------- KESIMPULAN ----------
		local strong = withEv > 0 or #uniq > 0 or #groups > 0
		local weak = #rsHits > 0
		local verdict, col
		if strong then
			local src = {}
			if withEv > 0 then table.insert(src, "item di dunia") end
			if #uniq > 0 then table.insert(src, "modul data") end
			if #groups > 0 then table.insert(src, "folder rarity") end
			verdict = "TERDETEKSI: rarity bisa dibaca otomatis (" .. table.concat(src, ", ") .. "), tanpa memetik item."
			col = T.good
		elseif weak then
			verdict = "SEBAGIAN: ada atribut/value berinfo rarity di ReplicatedStorage, tapi belum terhubung ke item. Salin hasilnya untuk dicek."
			col = Color3.fromRGB(255, 176, 72)
		else
			verdict = "TIDAK TERDETEKSI: game tampaknya menyembunyikan rarity sampai item dipetik. Pakai tabel/rekam saat memetik."
			col = T.danger
		end
		add("")
		add("KESIMPULAN: " .. verdict)

		lastReport = table.concat(lines, "\n")
		setStatus(verdict, col)
		print(lastReport)
		if writefile then
			pcall(function()
				if makefolder and isfolder and not isfolder(settings.saveFolder) then
					makefolder(settings.saveFolder)
				end
				writefile(tostring(settings.saveFolder) .. "/rarity_scan.txt", lastReport)
			end)
		end

		scanB.Text = "🔎 SCAN RARITY"
		busy = false
	end

	scanB.MouseButton1Click:Connect(function()
		task.spawn(function()
			local ok, err = pcall(run)
			if not ok then
				busy = false
				scanB.Text = "🔎 SCAN RARITY"
				setStatus("Scan error: " .. tostring(err), T.danger)
				warn("[RarityScan] " .. tostring(err))
			end
		end)
	end)

	copyB.MouseButton1Click:Connect(function()
		local clip = setclipboard or toclipboard
		if lastReport == "" then
			toast("Belum ada hasil scan")
		elseif clip then
			pcall(clip, lastReport)
			toast("Hasil disalin")
		else
			toast("Executor tidak bisa menyalin; lihat file rarity_scan.txt")
		end
	end)
end, warn)

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
]==]

if writefile then pcall(writefile, "R4MEN_auto.lua", SRC) end
local fn, err = loadstring(SRC)
if fn then
	fn()
else
	warn("R4MEN gagal dimuat: " .. tostring(err))
end
