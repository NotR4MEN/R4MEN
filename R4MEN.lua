--[=[
==============================================================================
 PANDUAN STRUKTUR SCRIPT  --  R4MEN Universal (BACA INI DULU sebelum mengubah)
==============================================================================
 File ini = satu string besar SRC (di bawah) yang dijalankan lewat loadstring dan
 juga disalin ke R4MEN_auto.lua. Semua kode panel ada DI DALAM string SRC.
 JANGAN menulis urutan karakter penutup string SRC (kurung siku, dua sama dengan,
 kurung siku) di komentar atau kode apa pun di dalam SRC: itu memotong script.
 Cari bagian dengan pencarian teks (nomor baris cepat usang), pakai judul di bawah.

 SUSUNAN TAB (7 tab, urutan sidebar = daftar di  for i, name in ipairs({...})
 tepat di bawah "GUI: SIDEBAR TAB & HALAMAN"):

  1. Movement : Speed, Jump Power, Infinite Jump, Follow Player (+ slider Jarak Berhenti)
  2. Physics  : Float, Noclip, WalkFling
  3. Visual   : Fullbright (+ slider Kecerahan, Jam Dunia), Hilangkan Kabut, FOV, Free Cam
  4. ESP      : ESP Chams (pemain)  ->  ESP NPC / Hewan  ->  Loot & Item ESP (+ pop-up Pin)
  5. Teleport : TP ke Pemain (daftar pemain), Waypoint, Pindah Server (Hop)
  6. Mini Game: Auto Cut (Mushrooming) / Auto Minigame universal -> Catur -> Scan Rarity -> Rekam Minigame + Auto Minigame -> Hasil
  7. Settings : Keybind, Ukuran Panel, Config (simpan/muat + toggle pop-up Pin/Daerah),
                Utilitas (Anti-AFK), Matikan Semua Fitur, Unload

 CARA MEMINDAHKAN FITUR KE TAB LAIN
  * Halaman dibuat lewat newPage("Nama") dan disimpan di tabel pages["Nama"].
    Variabel: movementPage, physicsPage, teleportPage, settingsPage (configPage = settingsPage),
    pages.ESP, pages["Mini Game"]. Halaman Visual dibuat di blok "HALAMAN VISUAL".
  * Untuk memindah fitur: ganti halaman induk pada pemanggilan addToggleCard / addSliderCard /
    makeCard / sectionLabel, lalu atur LayoutOrder (angka kecil = di atas).
  * Menambah/menghapus tab: ubah newPage(...) DAN daftar nama di loop sidebar.
  * Urutan LayoutOrder yang dipakai: Settings = Keybind 0-9, Config 20-60 (slot save 30+i),
    Utilitas 200, tombol Matikan Semua 300, Unload 301-302.
    Mini Game = Auto Minigame universal 0-1, Auto Cut 2, Catur 9-10, Scan 100-106. ESP = ESP Chams -2/-1, NPC 1-2, Item 4-5.
    Visual = Pencahayaan 0-4, Kamera 5-7.

 PETA BAGIAN (judul komentar "-- GUI: ..." di dalam script)
  AUTO-RERUN        : antre queue_on_teleport supaya script jalan lagi setelah pindah server
  STATE             : tabel settings, state (toggle), values (slider)
  PENYIMPANAN       : settings.path / save / load / flush (folder R4MEN, cadangan .bak)
  SPEED, INFINITE JUMP, FLOAT, NOCLIP & FLING, EFEK TOGGLE & RESET ALL (effects, setFeature)
  WAYPOINT & TP TARGET, THEME & HELPER (T, new, round, stroke, text, tween, hover)
  ESP CHAMS, FREE CAM, KERANGKA UTAMA (header, bubble, toast), SIDEBAR TAB & HALAMAN
  GRIP RESIZE, KOMPONEN (makeCard, addToggleCard, addSliderCard, makeButton)
  HALAMAN MOVEMENT & PHYSICS (+ FOLLOW PLAYER), HALAMAN VISUAL, ESP NPC / HEWAN,
  HALAMAN TELEPORT & ITEM DETECTOR, DATA RARITY, ITEM ESP (runScanner, pop-up Pin, SERVER HOP),
  waypoint UI, HALAMAN SETTINGS (keybind, ukuran, Anti-AFK), CONFIG, HALAMAN MINI GAME (Auto Cut + Auto Minigame universal), GUI: CATUR (jendela catur + AI + saran langkah),
  PENYIMPANAN FILE LOKAL, TAB SCAN (Rekam Minigame: capture/classifier/pattern evidence), KEYBIND, LABEL DAERAH, UNLOAD, START.

 ATURAN PENTING
  * Luau membatasi 200 variabel local per chunk. Bagian baru HARUS dibungkus do ... end
    atau function agar tidak menambah local di level atas.
  * Fitur toggle baru: tambahkan kunci di state, entri di effects, lalu addToggleCard.
  * Nilai slider baru: tambahkan di values + sliderSetters agar ikut tersimpan.
  * Anti-AFK dikecualikan dari "Matikan Semua"; fitur lain mati saat script dimulai.
==============================================================================
]=]
local SRC = [==[
-- ===== AUTO-RERUN: HANYA DI GAME YANG SAMA =====
do
	local q = queue_on_teleport or queueonteleport
		or (syn and syn.queue_on_teleport) or (fluxus and fluxus.queue_on_teleport)
	local env0 = (getgenv and getgenv()) or _G
	-- [FIX] antrean didaftarkan SEKALI per game (penanda dibersihkan oleh kode antrean saat teleport terjadi)
	if q and env0.__R4MEN_QUEUED ~= tostring(game.GameId) and readfile and isfile and isfile("R4MEN_auto.lua") then
		local gid = tostring(game.GameId)
		local okQ = pcall(q, "local GID = " .. gid .. "\n" .. [[
			local E = (getgenv and getgenv()) or _G
			E.__R4MEN_QUEUED = nil
			if not game:IsLoaded() then game.Loaded:Wait() end
			if game.GameId ~= GID then return end
			task.wait(2)
			local lp = game:GetService("Players").LocalPlayer
			local pg = lp and lp:WaitForChild("PlayerGui", 10)
			if pg and pg:FindFirstChild("UniversalUrbee") then return end
			local ok, e = pcall(function() loadstring(readfile("R4MEN_auto.lua"))() end)
			if not ok then warn("R4MEN auto-run gagal: " .. tostring(e)) end
		]])
		if okQ then env0.__R4MEN_QUEUED = gid end
	end
end
-- ================================================

-- LocalScript: taruh di StarterPlayer > StarterPlayerScripts
-- Universal R4MEN v1.2 (+ tab Visual: ESP NPC/Hewan, Fullbright, FOV, Anti-AFK aktif otomatis; daftar pemain klik-untuk-TP)

local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- [FIX] Matikan instance lama (loop, koneksi, autosave) sebelum instance baru jalan.
-- Tanpa ini, menjalankan script dua kali (atau auto-rerun + paste manual) meninggalkan
-- instance lama yang masih hidup: ESP lama tetap muncul & autosave-nya menimpa file simpanan.
do
	local env = (getgenv and getgenv()) or _G
	local prev = env.__R4MEN_UNLOAD
	if type(prev) == "function" then pcall(prev) end
	env.__R4MEN_UNLOAD = nil
end

for _, n in ipairs({ "UniversalUrbee", "ControlPanel", "UU_ITEMS", "UU_NPC", "UU_RARITY", "UU_ZONE", "UU_CHESS" }) do
	local old = playerGui:FindFirstChild(n)
	if old then old:Destroy() end
end

-- =====================================================
-- STATE
-- =====================================================
local settings: { [string]: any } = {
	saveFolder = "R4MEN", -- nama folder penyimpanan di dalam folder workspace executor (boleh diganti)
	seedReplicated = false, -- [FIX] jangan seed nama dari ReplicatedStorage (banyak sampah)
	nameDetect = true, -- [SCAN+] true = item TANPA Prompt/Klik/Tool (kunci, linggis, senter, dll) ikut terdeteksi lewat NAMA modelnya. false = cara lama
	manyThreshold = 60, -- [SCAN+] nama item tanpa folder yang jumlahnya >= angka ini dimasukkan ke grup "Banyak / Dekorasi". 0 = fitur dimatikan
	groupHideMany = true, -- [SCAN+] true = grup "Banyak / Dekorasi" tidak tampil di daftar utama (hanya lewat dropdown Grup atau pencarian). false = ikut tampil
	groupAlias = {}, -- [SCAN+] ganti judul grup dari nama folder game, mis. { WpnPrimary = "Senjata Utama" }
	itemGroups = {}, -- [SCAN+] grup buatan sendiri berdasar kata, mis. { Granat = { "grenade", "smoke", "c4" } }
	itemWords = {}, -- [SCAN+] kata tambahan untuk deteksi nama, mis. { "wayang", "topeng", "dupa" } (huruf kecil, satu kata). Masuk grup "Item Lainnya"
	clickTp = true, -- klik/tap label ESP (item & NPC) = teleport ke sana. Ubah ke false untuk mematikan
	mushroomOnly = true, -- true = daftar & ESP item HANYA untuk jamur yang ada di data rarity game (pisau/alat/pintu tidak ikut). false = semua yang terdeteksi
	dotsSelectedOnly = true, -- true = titik biru HANYA untuk item yang dicentang (lampu/pintu dll tidak ditandai). false = titik untuk semua yang terdeteksi
	autoRarity = true, -- true = data rarity dibaca otomatis saat script jalan (profil disimpan per game). false = hanya saat dropdown Rarity dibuka / tombol SCAN
	clickNeedsShift = false, -- true = harus menahan Shift kiri saat klik label (menghindari klik tembus ke game)
	followKey = Enum.KeyCode.Semicolon, -- tombol berhenti / lanjut mengikuti (bisa diganti di tab Settings)
	followFallbackNearest = false, -- Follow keybind: kalau tidak ada target/teman, true = ikuti pemain TERDEKAT siapa pun (hati-hati di server ramai)
	followCatchup = 0, -- Follow Player: kalau > 0, otomatis teleport ke target bila jarak melebihi angka ini (studs). 0 = mati (jalan kaki saja)
	toggleKey = Enum.KeyCode.K,
	miniGameIds = {}, -- opsional: GameId Mushrooming untuk pengecekan paling pasti, mis. { 123456789 }
	autoMiniGameIds = {}, -- GameId game yang punya Lockpick / Safe Dial. Kartu "Auto Minigame" HANYA muncul di game ini. Isi mis. { 123456789 } (lihat GameId di Scan / print(game.GameId))
	saveKey = Enum.KeyCode.LeftBracket,
	tpKey = Enum.KeyCode.RightBracket,
	cycleKey = Enum.KeyCode.Quote,
	recordMiniKey = Enum.KeyCode.F, -- Rekam Minigame: ON / OFF (bisa diganti di Settings)
	floatUpKey = Enum.KeyCode.PageUp,
	floatDownKey = Enum.KeyCode.PageDown,
}

-- Auto Cut (Jamur) hanya untuk Mushrooming: dikenali lewat GameId ATAU modul khas game-nya.
-- Perekam Minigame & tab Mini Game tetap ada di semua game.
settings.autoMiniOk = table.find(settings.autoMiniGameIds, game.GameId) ~= nil -- Auto Minigame (Lockpick/Safe Dial): khusus GameId di autoMiniGameIds
settings.miniGameOk = table.find(settings.miniGameIds, game.GameId) ~= nil
	or (ReplicatedStorage:FindFirstChild("WorldConfig", true) ~= nil
		and ReplicatedStorage:FindFirstChild("RootData", true) ~= nil)

-- =====================================================
-- PENYIMPANAN TERPUSAT (path seragam, cadangan .bak, flush paksa)
--  settings.path(nama)        -> path lengkap (folder R4MEN/, atau prefix R4MEN_ kalau tak ada folder)
--  settings.save(nama, teks)  -> tulis; file lama dicadangkan ke .bak; tidak menulis bila isi sama
--  settings.load(nama)        -> baca JSON; kalau file utama rusak, pakai .bak
--  settings.flushers / flush  -> tiap modul mendaftarkan fungsi simpan; flush() menjalankan semuanya
-- =====================================================
do
	local folder = tostring(settings.saveFolder)
	local mode: boolean? = nil
	local HttpSvc = game:GetService("HttpService")

	local function decide()
		if mode ~= nil then return end
		mode = false
		if isfolder then
			pcall(function()
				if not isfolder(folder) and makefolder then makefolder(folder) end
				mode = isfolder(folder) == true
			end)
		end
	end

	settings.path = function(name: string): string
		decide()
		if mode then return folder .. "/" .. name end
		return folder .. "_" .. name
	end

	settings.save = function(name: string, content: string): boolean
		if not writefile or type(content) ~= "string" then return false end
		local p = settings.path(name)
		if readfile and isfile then
			local okE, ex = pcall(isfile, p)
			if okE and ex then
				local okR, old = pcall(readfile, p)
				if okR and type(old) == "string" then
					if old == content then return true end -- tidak ada perubahan, lewati
					local a, b = string.sub(old, 1, 1), string.sub(old, -1)
					if (a == "{" and b == "}") or (a == "[" and b == "]") then
						pcall(writefile, p .. ".bak", old) -- cadangan hanya dari file yang utuh
					end
				end
			end
		end
		return (pcall(writefile, p, content))
	end

	settings.load = function(name: string): any
		if not (readfile and isfile) then return nil end
		local p = settings.path(name)
		for _, cand in ipairs({ p, p .. ".bak" }) do
			local okE, ex = pcall(isfile, cand)
			if okE and ex then
				local okR, raw = pcall(readfile, cand)
				if okR and type(raw) == "string" then
					local okD, d = pcall(function() return HttpSvc:JSONDecode(raw) end)
					if okD and type(d) == "table" then return d end
				end
			end
		end
		return nil
	end

	settings.flushers = {}
	settings.flush = function()
		for _, fn in pairs(settings.flushers) do
			pcall(fn)
		end
	end
end

local state: { [string]: boolean } = {
	speed = false,
	jump = false,
	infJump = false,
	float = false,
	noclip = false,
	walkFling = false,
	esp = false,
	freecam = false,
	antiAfk = true, -- aktif sejak awal; bisa dimatikan lewat tombol di tab Settings
	fullbright = false,
	noFog = false,
	fov = false,
	follow = false,
	autoCut = false, -- Mini Game: Auto Cut jamur (mati saat script dijalankan)
	autoMinigame = false, -- Mini Game: Auto Minigame universal (mati saat script dijalankan)
	chess = false, -- Mini Game: saran langkah catur dari papan in-game (mati saat script dijalankan)
}

local values: { [string]: number } = {
	followDist = 6,
	speed = 50,
	jump = 100,
	freecam = 60,
	bright = 2,
	clock = 14,
	fov = 70,
	npcDist = 50000,
	cutLead = 5, -- Mini Game: LEAD dalam milidetik (5 = 0.005 dtk)
	chessTime = 3, -- Mini Game: batas waktu berpikir saran catur (detik)
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

-- Follow Player: satu tabel (hemat jatah 200 local). Diisi di bagian GUI Movement.
local follow: any = { target = nil, set = function() end, pick = function() end }

local effects: { [string]: (boolean) -> () } = {
	follow = function(on) follow.set(on) end,
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
	autoCut = function() end, -- diisi blok GUI Mini Game
	autoMinigame = function() end, -- diisi blok GUI Auto Minigame universal
	chess = function() end, -- diisi blok GUI Catur
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
	if effects.scanRec then pcall(effects.scanRec, false) end
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
	hum: Humanoid?,
	root: Instance?,
	head: Instance?,
	alive: boolean,
	kids: number,
	t: number,
}

local espFolder: Folder? = nil
local espObjs: { [Player]: EspObj } = {}
local espAccum = 0

local function ensureEspFolder(): Folder
	-- Folder ini khusus BillboardGui. Highlight pemain dipasang langsung ke Model
	-- karakter agar mengikuti lifecycle karakter/respawn secara langsung.
	if not (espFolder and espFolder.Parent == workspace) then
		if espFolder then espFolder:Destroy() end
		espFolder = new("Folder", { Name = "UU_ESP" }, workspace)
	end
	return espFolder
end

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

-- [FIX] Pembuat Highlight terpisah supaya bisa dibuat ulang saat musuh mati/respawn.
-- Highlight bisa berhenti tergambar (padahal objeknya masih ada) kalau game mengganti
-- bagian tubuh / me-reset Humanoid pada model yang sama; membuatnya ulang memperbaikinya.
local function makeEspHighlight(char: Model, folder: Instance): Highlight
	return new("Highlight", {
		Name = "UU_PlayerHighlight",
		Adornee = char,
		Enabled = true,
		DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
		FillColor = Color3.fromRGB(80, 200, 255),
		OutlineColor = Color3.fromRGB(80, 200, 255),
		FillTransparency = 0.45,
		OutlineTransparency = 0.05,
	}, folder)
end

local function buildEsp(p: Player, char: Model)
	if not char or not char:IsDescendantOf(workspace) then return end

	local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
	if not head then return end

	local folder = ensureEspFolder()

	-- Penting: Highlight menjadi child karakter, bukan child Folder ESP bersama.
	-- Dengan begitu objek Highlight ikut hilang saat karakter lama dibuang dan
	-- dibuat ulang pada karakter baru setelah respawn.
	local hl = makeEspHighlight(char, folder)

	local bb = new("BillboardGui", {
		Name = "UU_PlayerBillboard",
		Adornee = head,
		AlwaysOnTop = true,
		Size = UDim2.fromOffset(170, 32),
		StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0),
		MaxDistance = math.huge,
	}, folder)

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

	local hum0 = char:FindFirstChildOfClass("Humanoid")
	espObjs[p] = {
		char = char, hl = hl, bb = bb, name = nameLbl, info = infoLbl,
		hum = hum0, root = char:FindFirstChild("HumanoidRootPart"), head = head,
		alive = hum0 ~= nil and hum0.Health > 0, kids = #char:GetChildren(), t = os.clock(),
	}
end

local function updateEsp(dt: number)
	espAccum += dt
	if espAccum < 0.1 then return end
	espAccum = 0

	-- Jika folder ESP hilang/terlepas, bersihkan referensi lama agar semua pemain
	-- dibuat ulang. Ini juga mencegah ESP tertinggal pada CurrentCamera lama.
	if espFolder and espFolder.Parent ~= workspace then
		clearEsp()
	end

	local myRoot = getRoot()

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player then
			local char = p.Character
			local o = espObjs[p]

			-- Respawn / streaming: buang ESP lama ketika model karakter berubah atau
			-- karakter sementara tidak berada di Workspace.
			if o and (o.char ~= char or not char or not char:IsDescendantOf(workspace)) then
				removeEsp(p)
				o = nil
			end

			local head = char and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
			-- Bangun ulang jika Highlight/Billboard dihancurkan game atau tidak lagi
			-- terhubung ke folder ESP/karakter yang benar.
			if o and (
				 not o.hl or o.hl.Parent ~= espFolder
				 or not o.bb or o.bb.Parent ~= espFolder
				 or o.hl.Adornee ~= char
				 or not head or o.bb.Adornee ~= head
				 or not o.name or o.name.Parent ~= o.bb
				 or not o.info or o.info.Parent ~= o.bb
			) then
				removeEsp(p)
				o = nil
			end

			if char and char:IsDescendantOf(workspace) and not o then
				buildEsp(p, char)
				o = espObjs[p]
			end

			-- [FIX] Siluet hilang setelah musuh mati lalu hidup lagi: buat ulang Highlight
			-- bila Humanoid/Head/Root berganti, nyawa naik dari 0, jumlah bagian karakter
			-- berubah, atau tiap 3 detik sebagai pengaman.
			if o and char then
				local hum0 = char:FindFirstChildOfClass("Humanoid")
				local root0 = char:FindFirstChild("HumanoidRootPart")
				local alive0 = hum0 ~= nil and hum0.Health > 0
				local kids0 = #char:GetChildren()
				local now = os.clock()
				local needs = o.hum ~= hum0 or o.root ~= root0 or o.head ~= head
					or (alive0 and not o.alive) or kids0 ~= o.kids or now - o.t > 3
				o.alive = alive0
				if needs then
					local old = o.hl
					o.hl = makeEspHighlight(char, ensureEspFolder())
					if old then old:Destroy() end
					o.hum, o.root, o.head, o.kids, o.t = hum0, root0, head, kids0, now
				end
			end

			if o and char then
				local col = Color3.fromRGB(80, 200, 255) -- BIRU MUDA = PEMAIN
				-- Paksa properti inti tetap benar jika diubah oleh game lain.
				o.hl.Enabled = true
				o.hl.Adornee = char
				o.hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				o.hl.FillColor = col
				o.hl.OutlineColor = col
				o.hl.FillTransparency = 0.45
				o.hl.OutlineTransparency = 0.05
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
	else
		-- Diagnosis: Roblox renders up to 255 Highlight instances per client.
		-- Warn when the game itself is already close to filling the available slots.
		task.defer(function()
			if unloaded or not state.esp then return end
			local count = 0
			for _, inst in ipairs(game:GetDescendants()) do
				if inst:IsA("Highlight") then count += 1 end
			end
			if count >= 245 then
				toast("Peringatan: " .. tostring(count) .. "/255 Highlight sudah ada di game. Siluet bisa dibatasi oleh slot Roblox.")
			end
		end)
	end
end

track(RunService.Heartbeat:Connect(function(dt)
	if state.esp then
		updateEsp(dt)
	end
end))

-- Lifecycle khusus pemain lain: CharacterAdded sering terpanggil sebelum seluruh rig
-- selesai masuk Workspace. Tunggu sampai model, Head/HRP, dan Humanoid siap, lalu
-- buat ulang Highlight pada folder Workspace yang stabil (Adornee = karakter baru).
do
	local characterHooks: { [Player]: { RBXScriptConnection } } = {}

	local function rebuildAfterRespawn(p: Player, char: Model)
		removeEsp(p) -- buang Billboard/Highlight milik karakter sebelum respawn
		task.spawn(function()
			for _ = 1, 100 do -- maksimum 10 detik menunggu rig selesai dimuat
				if unloaded or not state.esp or p.Parent ~= Players or p.Character ~= char then
					return
				end
				if char:IsDescendantOf(workspace) then
					local head = char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
					local hum = char:FindFirstChildOfClass("Humanoid")
					local root = char:FindFirstChild("HumanoidRootPart")
					if head and hum and root then
						local existing = espObjs[p]
						if existing and existing.char ~= char then
							removeEsp(p)
							existing = nil
						end
						if not existing then buildEsp(p, char) end
						return
					end
				end
				task.wait(0.1)
			end
			warn("R4MEN ESP: karakter " .. p.Name .. " belum siap setelah respawn; update loop akan mencoba lagi")
		end)
	end

	local function bindPlayer(p: Player)
		if p == player or characterHooks[p] then return end
		local hooks = {}
		table.insert(hooks, p.CharacterRemoving:Connect(function(char)
			local o = espObjs[p]
			if o and o.char == char then removeEsp(p) end
		end))
		table.insert(hooks, p.CharacterAdded:Connect(function(char)
			if state.esp and not unloaded then
				rebuildAfterRespawn(p, char)
			end
		end))
		characterHooks[p] = hooks
		for _, c in ipairs(hooks) do track(c) end
		if p.Character and state.esp then
			rebuildAfterRespawn(p, p.Character)
		end
	end

	local function unbindPlayer(p: Player)
		local hooks = characterHooks[p]
		if hooks then
			for _, c in ipairs(hooks) do c:Disconnect() end
			characterHooks[p] = nil
		end
		removeEsp(p)
	end

	for _, p in ipairs(Players:GetPlayers()) do bindPlayer(p) end
	track(Players.PlayerAdded:Connect(bindPlayer))
	track(Players.PlayerRemoving:Connect(unbindPlayer))
end

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
local mainStroke = stroke(main, WHITE, 2, 0.2) -- sedikit lebih tebal (sebelumnya 1.5)
-- 3 titik warna (accent -> accent2 -> accent) supaya putaran gradien mulus tanpa patahan
new("UIGradient", {
	Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, T.accent),
		ColorSequenceKeypoint.new(0.5, T.accent2),
		ColorSequenceKeypoint.new(1, T.accent),
	}),
	Rotation = 45,
}, mainStroke)

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
	local VERSION = "v1.2"
	local verBadge = new("Frame", {
		Position = UDim2.fromOffset(54 + 124, 11),
		Size = UDim2.fromOffset(40, 16),
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

-- ANIMASI OUTLINE: gradien warna berputar pelan di tepi panel & bubble (hanya saat terlihat)
do
	local mg = mainStroke:FindFirstChildOfClass("UIGradient")
	local bg2 = bubbleStroke:FindFirstChildOfClass("UIGradient")
	track(RunService.RenderStepped:Connect(function()
		if unloaded then return end
		local rot = (os.clock() * 50) % 360 -- 50 derajat/detik: satu putaran ~7 detik
		if main.Visible and mg then mg.Rotation = rot end
		if bubble.Visible and bg2 then bg2.Rotation = rot end
	end))
end

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
newPage("Mini Game") -- halaman Mini Game (Auto Cut + Scan Rarity + Rekam Minigame); diisi blok GUI Mini Game & blok TAB SCAN
newPage("ESP") -- halaman ESP sendiri (ESP NPC/Hewan + Loot & Item ESP); diakses lewat pages.ESP
local settingsPage = newPage("Settings")
local configPage = settingsPage -- Config tidak punya tab sendiri: kontennya ada di tab Settings (bagian "Config")

for i, name in ipairs({ "Movement", "Physics", "Visual", "ESP", "Teleport", "Mini Game", "Settings" }) do
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

-- =====================================================
-- FOLLOW PLAYER
-- Karakter otomatis berjalan mengikuti pemain lain.
--  * Mengikuti JEJAK LANGKAH target (titik-titik yang dia lewati), jadi di gunung/jalur berkelok
--    kamu lewat jalur yang sama dengan temanmu, bukan lurus menabrak tebing.
--  * Lompat otomatis saat jejak naik / saat tersangkut; titik jejak yang tak terjangkau dilewati.
--  * Menekan WASD = kontrol manual (follow jeda selama tombol ditahan).
--  * Berhenti saat sudah dekat (slider Jarak Berhenti). Opsional: settings.followCatchup (teleport bila ketinggalan jauh).
-- =====================================================
do
	local TRAIL_STEP = 3   -- jarak minimal antar titik jejak (studs)
	local TRAIL_MAX = 400  -- batas jumlah titik jejak
	local ARRIVE = 4       -- dianggap sampai di titik jejak bila sedekat ini
	local trail: { Vector3 } = {}
	local jumpAt: { [Vector3]: boolean } = {} -- titik jejak tempat target melompat
	local wasJump = false
	local lastCrumb: Vector3? = nil
	local stuckT, stuckAcc, lastPos = 0, 0, nil :: Vector3?
	local lastTp = 0

	local function setStatus(s: string)
		if follow.statusLbl then follow.statusLbl.Text = s end
	end

	local function resetTrail()
		table.clear(trail)
		table.clear(jumpAt)
		wasJump = false
		lastCrumb = nil
		stuckT, stuckAcc, lastPos = 0, 0, nil
	end

	-- Cocok persis menang. Kalau hanya cocok sebagian dan ada LEBIH DARI SATU pemain cocok,
	-- tidak dipilih sembarang: dikembalikan daftar nama supaya kamu mengetik lebih lengkap.
	local function findPlayer(q: string): (Player?, { string }?)
		local low = string.lower(q)
		if low == "" then return nil, nil end
		local partial: { Player } = {}
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player then
				local n, d = string.lower(p.Name), string.lower(p.DisplayName)
				if n == low or d == low then return p, nil end
				if string.find(n, low, 1, true) or string.find(d, low, 1, true) then
					partial[#partial + 1] = p
				end
			end
		end
		if #partial == 1 then return partial[1], nil end
		if #partial > 1 then
			local names: { string } = {}
			for i = 1, math.min(#partial, 4) do names[i] = partial[i].Name end
			return nil, names
		end
		return nil, nil
	end

	follow.resolve = function()
		local box = follow.box
		if not box then return end
		local q = string.match(box.Text, "^%s*(.-)%s*$") or ""
		if q == "" then return end
		local p, many = findPlayer(q)
		if p then
			follow.target = p
			resetTrail()
			setStatus("Target: " .. p.Name)
		elseif many then
			toast("Ada beberapa yang cocok: " .. table.concat(many, ", ") .. " - ketik lebih lengkap")
		else
			toast("Pemain tidak ditemukan")
		end
	end

	local function turnOff(msg: string?)
		state.follow = false
		if switches.follow then switches.follow.Set(false) end
		refreshActive()
		resetTrail()
		setStatus(msg or "Tidak mengikuti")
		if msg then toast(msg) end
	end

	follow.set = function(on: boolean)
		if on then
			if not follow.target or not follow.target.Parent then
				follow.target = nil
				follow.resolve()
			end
			if not follow.target then
				toast("Pilih pemain dulu (ketik nama lalu Set, atau tombol Ikuti di tab Teleport)")
				turnOff("Belum ada target")
				return
			end
			resetTrail()
			setStatus("Mengikuti: " .. follow.target.Name)
		else
			resetTrail()
			setStatus("Tidak mengikuti")
		end
	end

	-- Dipanggil dari daftar pemain (tab Teleport): klik "Ikuti" = mulai; klik lagi pada orang yang sama = berhenti.
	follow.pick = function(p: Player)
		if state.follow and follow.target == p then
			setFeature("follow", false)
			toast("Berhenti mengikuti")
			return
		end
		follow.target = p
		if follow.box then follow.box.Text = p.Name end
		resetTrail()
		setFeature("follow", true)
		toast("Mengikuti " .. p.Name)
	end

	-- Teman Roblox (Friends) yang ada di server: dipakai keybind supaya tidak salah ikut orang asing.
	local friendCache: { [number]: boolean } = {}
	local function isFriend(p: Player): boolean
		local c = friendCache[p.UserId]
		if c ~= nil then return c end
		local ok, res = pcall(function() return player:IsFriendsWith(p.UserId) end)
		c = ok and res == true
		friendCache[p.UserId] = c
		return c
	end

	local function nearestPlayer(friendsOnly: boolean): Player?
		local myRoot = getRoot()
		local best: Player? = nil
		local bestD = math.huge
		for _, p in ipairs(Players:GetPlayers()) do
			if p ~= player and (not friendsOnly or isFriend(p)) then
				local r = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local d = (myRoot and r) and (r.Position - myRoot.Position).Magnitude or 1e9
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
		return best
	end

	-- Keybind (settings.followKey) = MULAI atau STOP:
	--  * sedang mengikuti            -> berhenti
	--  * tidak mengikuti, urutan memilih target:
	--      1) target terakhir (kalau masih di server)
	--      2) nama yang diketik di kotak Follow Player
	--      3) teman Roblox terdekat di server
	--      4) (hanya bila settings.followFallbackNearest = true) pemain terdekat siapa pun
	follow.toggle = function()
		if state.follow then
			setFeature("follow", false)
			toast("Berhenti mengikuti")
			return
		end
		local p: Player? = nil
		if follow.target and follow.target.Parent then
			p = follow.target
		end
		if not p and follow.box and string.match(follow.box.Text, "%S") then
			follow.resolve()
			p = follow.target
			if not p then return end -- pesan (tidak ketemu / ambigu) sudah ditampilkan
		end
		if not p then p = nearestPlayer(true) end
		if not p and settings.followFallbackNearest == true then p = nearestPlayer(false) end
		if p then
			follow.pick(p)
		else
			toast("Tidak ada teman Roblox di server ini. Pilih manual lewat tombol Ikuti / kartu Follow Player")
		end
	end

	local WASD = { Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D }

	-- Stepped = sebelum fisika, setelah kontrol bawaan menulis arah jalan, jadi arah kita yang dipakai.
	-- followStep = HITUNG arah jalan (sekali per frame). applyMove = TERAPKAN arah itu (beberapa kali per frame).
	local function followStep(dt: number)
		follow.dir, follow.jump = nil, false
		if unloaded or not state.follow or state.freecam then return end
		local hum, hrp = getHum(), getRoot()
		if not (hum and hrp) or hum.Health <= 0 then return end

		local p: Player? = follow.target
		if not p or not p.Parent then
			turnOff("Target keluar dari server")
			return
		end
		local troot = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not troot then return end

		local tpos, mypos = troot.Position, hrp.Position

		-- rekam jejak langkah target (+ tandai titik tempat dia MELOMPAT)
		local thum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
		local jumpingNow = thum ~= nil and thum:GetState() == Enum.HumanoidStateType.Jumping
		local newJump = jumpingNow and not wasJump
		wasJump = jumpingNow
		if not lastCrumb or newJump or (tpos - lastCrumb).Magnitude >= TRAIL_STEP then
			trail[#trail + 1] = tpos
			lastCrumb = tpos
			if newJump then jumpAt[tpos] = true end
			if #trail > TRAIL_MAX then table.remove(trail, 1) end
		end

		local dist = (tpos - mypos).Magnitude

		-- opsional: ketinggalan terlalu jauh -> teleport dekat target
		local cu = settings.followCatchup
		if type(cu) == "number" and cu > 0 and dist > cu and os.clock() - lastTp > 3 then
			lastTp = os.clock()
			local char = player.Character
			if char then
				char:PivotTo(troot.CFrame + Vector3.new(3, 3, 0))
				hrp.AssemblyLinearVelocity = Vector3.zero
				resetTrail()
				toast("Menyusul " .. p.Name)
			end
			return
		end

		-- sudah dekat: berhenti & kosongkan jejak
		if dist <= values.followDist then
			table.clear(trail)
			table.clear(jumpAt)
			stuckT, stuckAcc, lastPos = 0, 0, nil
			setStatus(string.format("Dekat %s (%d st)", p.Name, math.floor(dist + 0.5)))
			return
		end

		-- kontrol manual (WASD) = jeda
		if UIS:GetFocusedTextBox() == nil then
			for _, k in ipairs(WASD) do
				if UIS:IsKeyDown(k) then return end
			end
		end

		-- buang titik jejak yang sudah dicapai
		while #trail > 0 do
			local c = trail[1]
			local flat = Vector3.new(c.X - mypos.X, 0, c.Z - mypos.Z).Magnitude
			-- titik tempat target melompat: dekati lebih presisi, lalu lompat di situ
			local isJ = jumpAt[c] == true
			if flat < (isJ and 1.5 or ARRIVE) and math.abs(c.Y - mypos.Y) < 6 then
				if isJ then
					follow.jump = true
					jumpAt[c] = nil
				end
				table.remove(trail, 1)
			else
				break
			end
		end

		local goal = trail[1] or tpos
		local delta = goal - mypos
		local flatV = Vector3.new(delta.X, 0, delta.Z)
		if flatV.Magnitude > 0.1 then
			follow.dir = flatV.Unit
		end
		if delta.Y > 2.5 and flatV.Magnitude < 10 then
			follow.jump = true -- jejak naik: lompat
		end

		-- deteksi tersangkut: hampir tak bergerak padahal sedang berjalan
		stuckAcc += dt
		if stuckAcc >= 0.3 then
			stuckAcc = 0
			if lastPos then
				local moved = Vector3.new(mypos.X - lastPos.X, 0, mypos.Z - lastPos.Z).Magnitude
				if moved < 0.3 then
					stuckT += 0.3
					follow.jump = true
					if stuckT >= 1.5 and #trail > 0 then
						table.remove(trail, 1) -- titik tak terjangkau: lewati
						stuckT = 0
					end
				else
					stuckT = 0
				end
			end
			lastPos = mypos
			setStatus(string.format("Mengikuti %s (%d st)", p.Name, math.floor(dist + 0.5)))
		end
	end

	-- Terapkan arah jalan di BEBERAPA titik frame (setelah kontrol bawaan menulis Move di RenderStepped,
	-- sebelum fisika di Stepped, dan di Heartbeat) supaya tidak tertimpa script kontrol game.
	local cmdSince = 0
	local function applyMove()
		local dir: Vector3? = follow.dir
		local hum = getHum()
		if not (dir and hum) or hum.Health <= 0 then
			cmdSince = 0
			return
		end
		hum:Move(dir, false)
		if follow.jump then hum.Jump = true end

		-- Cadangan: game yang mengabaikan Humanoid:Move -> dorong lewat velocity horizontal
		if cmdSince == 0 then cmdSince = os.clock() end
		if os.clock() - cmdSince > 0.7 and hum.FloorMaterial ~= Enum.Material.Air and not hum.Sit then
			local hrp = getRoot()
			if hrp then
				local ws = math.max(hum.WalkSpeed, 16)
				local v = hrp.AssemblyLinearVelocity
				if Vector3.new(v.X, 0, v.Z).Magnitude < ws * 0.5 then
					hrp.AssemblyLinearVelocity = Vector3.new(dir.X * ws, v.Y, dir.Z * ws)
				end
			end
		end
	end

	track(RunService.RenderStepped:Connect(function(dt)
		if unloaded then return end
		followStep(dt)
		applyMove()
	end))
	track(RunService.Stepped:Connect(function()
		if not unloaded then applyMove() end
	end))
	track(RunService.Heartbeat:Connect(function()
		if not unloaded then applyMove() end
	end))

	-- ---------- UI ----------
	sectionLabel(movementPage, 4, "Ikuti pemain")
	local card = makeCard(movementPage, 134, 5)
	text(card, {
		Text = "Follow Player",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.fromOffset(14, 11),
		Size = UDim2.new(1, -84, 0, 18),
	})
	switches.follow = makeSwitch(card, UDim2.new(1, -14, 0, 22), false, function(on)
		state.follow = on
		effects.follow(on)
		refreshActive()
	end, cardGlow(card))

	local box = new("TextBox", {
		Position = UDim2.fromOffset(14, 42),
		Size = UDim2.new(1, -28 - 70, 0, 30),
		BackgroundColor3 = T.bg,
		Text = "",
		PlaceholderText = "Ketik nama teman (mis: asel)",
		PlaceholderColor3 = T.sub,
		TextColor3 = T.text,
		Font = Enum.Font.GothamMedium,
		TextSize = 12,
		ClearTextOnFocus = false,
		BorderSizePixel = 0,
	}, card)
	round(box, 8)
	stroke(box, T.stroke, 1, 0.3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, box)
	follow.box = box

	local setBtn = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 42),
		Size = UDim2.fromOffset(62, 30),
		BackgroundColor3 = T.accent2,
		Text = "Set",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, card)
	round(setBtn, 8)
	hover(setBtn, T.accent2)
	setBtn.MouseButton1Click:Connect(function() follow.resolve() end)
	box.FocusLost:Connect(function(enter: boolean)
		if enter then follow.resolve() end
	end)

	follow.statusLbl = text(card, {
		Text = "Belum ada target",
		TextSize = 11,
		TextColor3 = T.sub,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(14, 78),
		Size = UDim2.new(1, -28, 0, 14),
	})
	text(card, {
		Text = "Mengikuti jejak langkah target (cocok untuk gunung). Tahan WASD untuk jalan manual. Bisa juga lewat tombol Ikuti di tab Teleport.",
		TextSize = 10,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 95),
		Size = UDim2.new(1, -28, 0, 34),
	})
end
addSliderCard(movementPage, 6, "Jarak Berhenti", "Berhenti saat sudah sedekat ini ke target (studs)", "followDist", 2, 30, 100, true)

sectionLabel(physicsPage, 0, "Fisika")
local floatDesc = addToggleCard(physicsPage, 1, "Float", "", "float")
addToggleCard(physicsPage, 2, "Noclip", "Tembus tembok dan objek.", "noclip")
addToggleCard(physicsPage, 3, "WalkFling",
	"Otomatis tembus tembok. Pemain lain terpental saat menyentuhmu.", "walkFling")
-- ESP Chams (pemain) ada di tab ESP, paling atas (LayoutOrder negatif supaya selalu di atas ESP NPC/Hewan & Item)
sectionLabel(pages.ESP, -2, "ESP Pemain")
addToggleCard(pages.ESP, -1, "ESP Chams",
	"Siluet pemain tembus tembok + username, darah, jarak. Warna biru muda = pemain.", "esp")

-- =====================================================
-- GUI: HALAMAN VISUAL (Fullbright, Kabut, FOV, Free Cam) -- blok 1
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
	addSliderCard(visualPage, 7, "Free Cam", "WASD + E/Q, Shift cepat, klik kanan = lihat", "freecam", 5, 600, 1000)

	-- ESP NPC / Hewan ada di tab ESP (satu tempat dengan scan barang) -- lihat blok 2

	-- Anti-AFK ada di tab Settings (bagian "Utilitas")

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
-- dalam jarak slider, dan dibatasi NPC terdekat (batas Highlight engine kini 255 instance).
-- =====================================================
do
	local NPC_COL = Color3.fromRGB(255, 176, 72)
	local NPC_MAX = math.huge      -- tanpa batas: semua NPC terpilih dalam jarak ditandai (label nama+jarak)
	local NPC_HL_MAX = 30          -- batasi siluet NPC agar slot Highlight tetap hemat (sisanya tetap berlabel)
	local NPC_ROW_LIMIT = math.huge -- tanpa batas baris daftar
	local ROWS_PER_PASS = 30       -- baris baru dibuat bertahap (30/langkah) agar layar tidak freeze
	local NPC_CLASS: { [string]: boolean } = { Humanoid = true, AnimationController = true }

	local N: any = {
		groups = {}, byModel = {}, order = {}, sel = {}, rows = {}, vis = {},
		folder = nil, addConn = nil, remConn = nil,
		scanning = false, scanned = false, dirty = false, orderDirty = true,
		acc = 0, acc2 = 0, interval = 0.15, cand = {}, cat = "Semua", rarFilter = "Semua",
		shown = 0, inRange = 0, selTotal = 0, base = "", err = nil, live = false,
		setStatus = function() end, -- diisi di bagian UI
	}

	-- ---------- NAMA KUSTOM NPC (alias, disimpan per game) ----------
	-- Contoh: "John" -> "1 John (jual)". Hanya tampilan: pilihan/centang tetap memakai nama asli.
	N.alias = {}
	do
		local HttpSvc = game:GetService("HttpService")
		local aliasPath = "npc_alias_" .. tostring(game.GameId) .. ".json"
		do
			local d = settings.load(aliasPath)
			if type(d) == "table" then
				for k, v in pairs(d) do
					if type(k) == "string" and type(v) == "string" and v ~= "" then N.alias[k] = v end
				end
			end
		end
		N.saveAlias = function()
			if not writefile then return end
			pcall(function() settings.save(aliasPath, HttpSvc:JSONEncode(N.alias)) end)
		end

		-- Centang NPC (per game): dimuat lagi saat script jalan; ESP NPC langsung menandai yang sudah dicentang.
		local selPath = "npc_sel_" .. tostring(game.GameId) .. ".json"
		do
			local d = settings.load(selPath)
			if type(d) == "table" and type(d.sel) == "table" then
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
			pcall(function() settings.save(selPath, HttpSvc:JSONEncode({ sel = names })) end)
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
	local npcClassify: (Model, string) -> string
	do -- [FIX] bungkus agar local-nya tidak menghabiskan jatah 200 local
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

	function npcClassify(m: Model, lower: string): string
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
	end -- [FIX] akhir pembungkus klasifikasi NPC

	-- ---------- RARITY NPC: baca bukti langsung dari model/atribut lalu cocokkan ke Rarity API ----------
	-- Nilai yang tidak cocok tetap Unknown; tidak ada rarity hasil tebakan.
	N.resolveRarity = function(m: Instance): string?
		local api = settings.rarityApi
		if not api then return nil end
		local keys = { "Rarity", "Tier", "Grade", "Quality", "Rank", "Species", "SpeciesId", "BeeId", "PetId", "Type", "Variant", "Mutation", "Sp" }
		local function lookupValue(v: any, field: string?): string?
			if type(v) == "number" then
				local tierNames = api.tierNames
				if type(tierNames) == "table" and type(tierNames[v]) == "string" then return tierNames[v] end
				if field and string.lower(field) == "tier" and type(tierNames) == "table" and type(tierNames[tostring(v)]) == "string" then
					return tierNames[tostring(v)]
				end
				return nil
			end
			if type(v) == "string" and v ~= "" then
				local raw = string.gsub(v, "^%s*(.-)%s*$", "%1")
				if raw == "" then return nil end
				if field and string.lower(field) == "rarity" then return raw end
				if api.get then
					local ok, r = pcall(api.get, raw)
					if ok and type(r) == "string" and r ~= "" then return r end
				end
				for _, n in ipairs(api.names or {}) do
					if string.lower(n) == string.lower(raw) then return n end
				end
			end
			return nil
		end
		for _, key in ipairs(keys) do
			local ok, value = pcall(function() return m:GetAttribute(key) end)
			if ok then
				local r = lookupValue(value, key)
				if r then return r end
			end
		end
		local okDesc, descendants = pcall(function() return m:GetDescendants() end)
		if okDesc then
			local checked = 0
			for _, d in ipairs(descendants) do
				if checked >= 180 then break end
				if d:IsA("ValueBase") then
					checked += 1
					local key = string.lower(d.Name)
					for _, wanted in ipairs(keys) do
						if key == string.lower(wanted) then
							local r = lookupValue(d.Value, d.Name)
							if r then return r end
							break
						end
					end
				end
			end
		end
		if api.getAttr then
			local ok, r = pcall(api.getAttr, m)
			if ok and type(r) == "string" and r ~= "" then return r end
		end
		return lookupValue(m.Name)
	end

	N.refreshRarity = function()
		for _, e in pairs(N.byModel) do
			if e.model and e.model.Parent then
				e.rarity = N.resolveRarity(e.model)
			end
		end
	end

	local function npcAdd(inst: Instance, tries: number)
		local m = inst.Parent
		if not m or not m:IsA("Model") or N.byModel[m] then return end
		if Players:GetPlayerFromCharacter(m) then return end
		-- [FIX] model yang BARU spawn sering belum masuk workspace / belum punya part saat Humanoid-nya
		-- muncul. Dulu langsung dibuang (tanpa retry); sekarang dicoba lagi sampai ~10 detik.
		local root: BasePart? = nil
		if m:IsDescendantOf(workspace) then
			root = npcRootOf(m :: Model)
		end
		if not root then
			-- struktur belum lengkap (spawn / streaming) -> coba lagi sebentar lagi
			if tries < 10 then
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
		local okR, rar = pcall(N.resolveRarity, m) -- [FIX] error rarity tidak boleh membatalkan pendaftaran NPC baru
		local e: any = { model = m, root = root, name = name, rarity = okR and rar or nil, inst = inst }
		g.list[#g.list + 1] = e
		e.gi = #g.list
		N.byModel[m] = e
		N.dirty = true
	end

	-- [PATCH] BATU QUEST (Rainstone / Moonstone / Sunstone): bukan NPC & bukan item,
	-- jadi dideteksi lewat NAMA dan HANYA masuk tab NPC (scanner item/jamur tidak tersentuh).
	-- Kalau nama asli di Explorer berbeda, tambahkan di daftar ini (huruf kecil, tanpa spasi/garis bawah).
	-- (disimpan sebagai field di N supaya TIDAK menambah variabel local: batas Luau 200 local per chunk)
	N.stoneNames = { "rainstone", "moonstone", "sunstone" }
	N.isStone = function(n: string): boolean
		local s = string.lower((string.gsub(n, "[^%a]", "")))
		for _, w in ipairs(N.stoneNames) do
			if string.find(s, w, 1, true) then return true end
		end
		return false
	end

	N.addStone = function(inst: Instance, tries: number)
		if N.byModel[inst] then return end
		if not (inst:IsA("Model") or inst:IsA("BasePart")) then return end
		if not N.isStone(inst.Name) then return end
		if not inst:IsDescendantOf(workspace) then return end
		-- part di dalam model yang namanya juga batu: biarkan modelnya yang dicatat (anti-duplikat)
		local par = inst.Parent
		if inst:IsA("BasePart") and par and par:IsA("Model") and N.isStone(par.Name) then return end
		local root: BasePart? = nil
		if inst:IsA("Model") then
			root = npcRootOf(inst :: Model)
		else
			root = inst :: BasePart
		end
		if not root then
			if tries < 4 then
				task.delay(1, function()
					if not unloaded and inst.Parent then
						N.addStone(inst, tries + 1)
					end
				end)
			end
			return
		end
		local name = inst.Name
		local g = N.groups[name]
		if not g then
			g = { name = name, lower = string.lower(name), list = {}, cat = "Part" }
			N.groups[name] = g
			N.orderDirty = true
		end
		local e: any = { model = inst, root = root, name = name, stone = true }
		g.list[#g.list + 1] = e
		e.gi = #g.list
		N.byModel[inst] = e
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
			elseif inst:IsA("Model") or inst:IsA("BasePart") then
				task.defer(N.addStone, inst, 0) -- [PATCH] batu quest
			end
		end))
		N.remConn = track(workspace.DescendantRemoving:Connect(function(inst)
			if NPC_CLASS[inst.ClassName] then
				local m = inst.Parent
				local e = m and N.byModel[m]
				if e then npcRemove(e) end
			end
			local se = N.byModel[inst] -- [PATCH] batu quest
			if se and se.stone then npcRemove(se) end
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

	N.makeHl = function(e: any): Highlight
		local hf = N.hlFolder
		if not (hf and hf.Parent == workspace) then
			hf = new("Folder", { Name = "UU_NPC_HL" }, workspace)
			N.hlFolder = hf
		end
		return new("Highlight", {
			Name = "UU_NpcHighlight",
			Adornee = e.model,
			Enabled = true,
			DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
			FillColor = NPC_COL,
			OutlineColor = NPC_COL,
			FillTransparency = 0.45,
			OutlineTransparency = 0.1,
		}, hf)
	end

	local function npcClearVis()
		for e in pairs(N.vis) do
			npcDropVis(e)
		end
		if N.hlFolder then
			N.hlFolder:Destroy()
			N.hlFolder = nil
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

		-- Saat ESP pemain aktif, dahulukan siluet pemain. Label NPC tetap berjalan,
		-- tetapi Highlight NPC dilepas sementara agar tidak menghabiskan slot render.
		local npcHighlightLimit = state.esp and 10 or NPC_HL_MAX
		if i <= npcHighlightLimit then
			-- [FIX] sama seperti ESP pemain: Highlight di folder Workspace, dibuat ulang bila
			-- hilang / Adornee berubah / jumlah bagian model berubah / tiap 4 detik, properti dipaksa benar.
			local now = os.clock()
			local kids = #e.model:GetChildren()
			local hl = v.hl
			if hl and (hl.Parent ~= N.hlFolder or hl.Adornee ~= e.model or kids ~= v.kids or now - (v.t or 0) > 4) then
				v.hl = N.makeHl(e)
				hl:Destroy()
				hl = v.hl
				v.kids, v.t = kids, now
			elseif not hl then
				hl = N.makeHl(e)
				v.hl = hl
				v.kids, v.t = kids, now
			end
			hl.Enabled = true
			hl.Adornee = e.model
			hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			hl.FillColor = NPC_COL
			hl.OutlineColor = NPC_COL
			hl.FillTransparency = 0.45
			hl.OutlineTransparency = 0.1
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
	local card = makeCard(pages.ESP, 394, 2)
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
		local DMIN, DMAX, DHARD = 50, 5000, 100000
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

	-- Chip kategori: Semua / Hewan / Toko / Quest / Musuh / Part / Lainnya ("Part" = batu quest dkk, dideteksi lewat nama)
	do -- [FIX] bungkus agar local-nya tidak menghabiskan jatah 200 local
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
	local CAT_CHIPS = { "Semua", "Hewan", "Toko", "Quest", "Musuh", "Part", "Lainnya" }
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
	end -- [FIX] akhir pembungkus Chip kategori

	-- Dropdown rarity NPC ditempatkan rapi di antara chip kategori dan tombol Pilih hasil/Kosongkan.
	do -- [FIX] bungkus agar local-nya tidak menghabiskan jatah 200 local
	local rarDrop = new("TextButton", {
		Position = UDim2.fromOffset(14, 192),
		Size = UDim2.new(1, -28, 0, 24),
		BackgroundColor3 = T.bg,
		Text = "✦  Rarity: Semua  ▼",
		TextColor3 = T.sub,
		Font = Enum.Font.GothamMedium,
		TextSize = 10,
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, card)
	round(rarDrop, 6)
	stroke(rarDrop, T.stroke, 1, 0.35)
	new("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 8) }, rarDrop)

	local rarPanel = new("ScrollingFrame", {
		Position = UDim2.fromOffset(14, 220),
		Size = UDim2.fromOffset(164, 0),
		CanvasSize = UDim2.fromOffset(0, 0),
		ScrollBarThickness = 3,
		ScrollBarImageColor3 = T.accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		BackgroundColor3 = T.card,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 40,
	}, card)
	round(rarPanel, 7)
	stroke(rarPanel, T.stroke, 1, 0.2)

	local function refreshNpcRarityMenu()
		local api = settings.rarityApi
		local opts, seen = { "Semua" }, { ["Semua"] = true }
		if api then
			for _, name in ipairs(api.names or {}) do
				if type(name) == "string" and not seen[name] and #opts < 22 then
					seen[name] = true
					opts[#opts + 1] = name
				end
			end
		end
		local observed = {}
		for _, group in pairs(N.groups) do
			for _, entry in ipairs(group.list) do
				local rarity = entry.rarity
				if type(rarity) == "string" and not seen[rarity] then
					seen[rarity] = true
					observed[#observed + 1] = rarity
				end
			end
		end
		table.sort(observed)
		for _, rarity in ipairs(observed) do
			if #opts >= 24 then break end
			opts[#opts + 1] = rarity
		end
		opts[#opts + 1] = "Unknown"
		for _, child in ipairs(rarPanel:GetChildren()) do
			if child:IsA("TextButton") then child:Destroy() end
		end
		local rowH = 22
		for i, name in ipairs(opts) do
			local active = N.rarFilter == name
			local b = new("TextButton", {
				Position = UDim2.fromOffset(4, 4 + (i - 1) * 24),
				Size = UDim2.new(1, -8, 0, rowH),
				BackgroundColor3 = active and T.cardSel or T.bg,
				Text = (name == "Semua" and "Semua rarity" or name) .. (active and "   ✓" or ""),
				TextColor3 = active and T.text or T.sub,
				Font = Enum.Font.GothamMedium,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
				AutoButtonColor = false,
				BorderSizePixel = 0,
				ZIndex = 41,
			}, rarPanel)
			round(b, 5)
			new("UIPadding", { PaddingLeft = UDim.new(0, 7) }, b)
			b.MouseButton1Click:Connect(function()
				N.rarFilter = name
				rarPanel.Visible = false
				rarDrop.Text = "✦  Rarity: " .. name .. "  ▼"
				rarDrop.BackgroundColor3 = name == "Semua" and T.bg or T.cardSel
				rarDrop.TextColor3 = name == "Semua" and T.sub or WHITE
				npcRefreshList()
			end)
		end
		local h = 8 + #opts * 24
		rarPanel.CanvasSize = UDim2.fromOffset(0, h)
		rarPanel.Size = UDim2.fromOffset(164, math.min(h, 128))
	end
	N.refreshRarityDropdown = refreshNpcRarityMenu

	rarDrop.MouseButton1Click:Connect(function()
		local api = settings.rarityApi
		if api and api.ensure then api.ensure() end
		if not rarPanel.Visible then
			N.refreshRarity()
			refreshNpcRarityMenu()
			npcRefreshList()
		end
		rarPanel.Visible = not rarPanel.Visible
		rarDrop.Text = "✦  Rarity: " .. N.rarFilter .. (rarPanel.Visible and "  ▲" or "  ▼")
	end)
	rarPanel.MouseLeave:Connect(function()
		-- Panel tetap terbuka sampai pilihan dibuat atau tombol ditekan lagi.
	end)
	end -- [FIX] akhir pembungkus Rarity NPC

	local actionRow = new("Frame", {
		Position = UDim2.fromOffset(14, 222),
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
		Position = UDim2.fromOffset(14, 252),
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
		Position = UDim2.fromOffset(14, 252),
		Size = UDim2.new(1, -28, 0, 130),
	})

	-- Editor ganti nama: muncul di atas baris tombol "Pilih hasil" saat "Ubah" ditekan
	do
		local ov = new("Frame", {
			Position = UDim2.fromOffset(14, 222),
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
		if N.rarFilter ~= "Semua" then
			local found = false
			for _, e in ipairs(g.list) do
				if (e.rarity or "Unknown") == N.rarFilter then found = true break end
			end
			if not found then return false end
		end
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

	-- Expose bridge untuk DATA RARITY yang dideklarasikan setelah blok NPC selesai.
	-- Tanpa ini, listener database tidak tahu cara memperbarui NPC yang sudah ter-scan.
	settings.npcRarityState = N

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
				elseif inst:IsA("Model") or inst:IsA("BasePart") then
					N.addStone(inst, 0) -- [PATCH] batu quest
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

	-- [FIX] Sinkronisasi berkala untuk NPC/hewan yang baru spawn:
	--  * nama model diganti SESUDAH spawn (mis. "Model" -> "Deer") -> pindahkan ke grup yang benar
	--  * part root yang dipilih saat spawn ternyata sementara / dihapus -> cari root yang baru
	--  * model sudah keluar dari workspace -> bersihkan
	-- (disimpan sebagai field N agar tidak menambah variabel local)
	N.sync = function()
		local drop: { any } = {}
		local readd: { any } = {}
		for m, e in pairs(N.byModel) do
			if not e.stone then
				if not m:IsDescendantOf(workspace) then
					drop[#drop + 1] = e
				elseif m.Name ~= e.name then
					readd[#readd + 1] = e
				else
					local r = e.root
					if not r or not r.Parent or not r:IsDescendantOf(m) then
						local nr = npcRootOf(m :: Model)
						if nr then e.root = nr end
					elseif r.Name ~= "HumanoidRootPart" then
						local hrp = m:FindFirstChild("HumanoidRootPart")
						if hrp and hrp:IsA("BasePart") then e.root = hrp end
					end
				end
			end
		end
		for _, e in ipairs(drop) do
			npcRemove(e)
		end
		for _, e in ipairs(readd) do
			local inst = e.inst
			npcRemove(e)
			if inst and inst.Parent then
				npcAdd(inst, 0)
			end
		end
	end

	-- [FIX] Jaring pengaman: event DescendantAdded kadang terlewat / terlalu dini untuk NPC yang baru
	-- spawn. Tiap 5 detik workspace dipindai ringan (bertahap, tanpa freeze) dan yang belum tercatat
	-- didaftarkan. Hanya jalan bila Auto scan aktif dan ada jenis NPC yang dicentang.
	N.discover = function()
		if N.discovering or N.scanning or unloaded then return end
		N.discovering = true
		pcall(function()
			local desc = workspace:GetDescendants()
			local t0 = os.clock()
			for i = 1, #desc do
				local inst = desc[i]
				if NPC_CLASS[inst.ClassName] then
					local m = inst.Parent
					if m and m:IsA("Model") and not N.byModel[m] and npcRootOf(m :: Model) then
						npcAdd(inst, 0)
					end
				end
				if i % 400 == 0 and os.clock() - t0 > 0.004 then
					RunService.Heartbeat:Wait()
					if unloaded then return end
					t0 = os.clock()
				end
			end
		end)
		N.discovering = false
	end

	-- ---------- loop ----------
	track(RunService.Heartbeat:Connect(function(dt: number)
		if unloaded then return end

		N.acc4 = (N.acc4 or 0) + dt
		if N.acc4 >= 5 then
			N.acc4 = 0
			if N.live and next(N.sel) ~= nil then
				task.spawn(N.discover)
			end
		end

		N.acc3 = (N.acc3 or 0) + dt
		if N.acc3 >= 1.0 then
			N.acc3 = 0
			if next(N.byModel) ~= nil then
				pcall(N.sync)
			end
		end

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
			Size = UDim2.new(1, -104, 1, 0),
		})

		local fb = new("TextButton", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -46, 0.5, 0),
			Size = UDim2.fromOffset(40, 20),
			BackgroundColor3 = T.accent,
			Text = "Ikuti",
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, btn)
		round(fb, 5)
		hover(fb, T.accent)
		fb.MouseButton1Click:Connect(function()
			if p.Parent then
				follow.pick(p)
			else
				toast("Pemain sudah keluar")
			end
		end)

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

	-- Saring daftar menurut teks di kotak pencarian (nama tampilan ATAU @username, tidak peka huruf besar-kecil)
	local function applyFilter()
		local q = string.lower(string.match(tpTargetInput.Text, "^%s*(.-)%s*$") or "")
		local total, shown = 0, 0
		for p, row in pairs(plrRows) do
			total += 1
			local ok = q == ""
			if not ok then
				ok = string.find(string.lower(p.Name), q, 1, true) ~= nil
					or string.find(string.lower(p.DisplayName), q, 1, true) ~= nil
			end
			row.Visible = ok
			if ok then shown += 1 end
		end
		if q == "" then
			plrCount.Text = "Pemain online: " .. tostring(total)
		else
			plrCount.Text = "Ditemukan " .. tostring(shown) .. " dari " .. tostring(total)
		end
		plrEmpty.Text = total == 0 and "Tidak ada pemain lain di server" or "Tidak ada pemain yang cocok"
		plrEmpty.Visible = shown == 0
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

		applyFilter()
	end

	track(Players.PlayerAdded:Connect(refreshPlayerList))
	track(Players.PlayerRemoving:Connect(function()
		-- PlayerRemoving terpanggil sebelum pemain benar-benar hilang dari GetPlayers
		task.defer(refreshPlayerList)
	end))
	tpTargetInput:GetPropertyChangedSignal("Text"):Connect(function()
		plrScroll.CanvasPosition = Vector2.new(0, 0)
		applyFilter()
	end)
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
	local RAR_WORDS = { "legendary", "legendaris", "legenda", "mythical", "mythic", "mitos", "mitis", "epic", "epik", "uncommon", "common", "rare", "langka", "jarang", "biasa", "exotic", "divine", "godly", "secret", "unique" }
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
	local DEF_NUM = { [1] = "Common", [2] = "Uncommon", [3] = "Rare", [4] = "Epic", [5] = "Legendary", [6] = "Mythic", [7] = "Secret" }
	local EXTRACOL = { -- [PATCH] warna tetap untuk rarity di atas Mythic
		Secret = Color3.fromRGB(0, 235, 235),
		Exotic = Color3.fromRGB(255, 140, 40),
		Divine = Color3.fromRGB(255, 245, 160),
		Godly = Color3.fromRGB(255, 255, 255),
		Unique = Color3.fromRGB(150, 255, 190),
	}
	local BASECOL = {} -- salinan warna dasar; RCOL sendiri dipakai sebagai api.colors dan diisi ulang sesuai data game
	for k, v in pairs(RCOL) do BASECOL[k] = v end

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

	-- ---------- NAMA & WARNA RARITY MENGIKUTI DATA GAME ----------
	-- Nama rarity yang ada di data game (Inggris/Indonesia/lainnya) diurutkan menurut tingkatnya.
	-- Nama dikenal (Common/Biasa, Rare/Jarang, Legendary/Legenda, Mythic/Mitos, dst.) memakai warna standar;
	-- nama lain mendapat warna otomatis. Hasilnya mengisi api.names (isi dropdown) dan api.colors.
	local MAX_NAMES = 12
	local RANK = {
		common = 1, biasa = 1,
		uncommon = 2, tidakumum = 2,
		rare = 3, jarang = 3, langka = 3,
		epic = 4, epik = 4,
		legendary = 5, legenda = 5, legendaris = 5,
		mythic = 6, mythical = 6, mitos = 6, mitis = 6,
		exotic = 7, divine = 8, godly = 9, secret = 10, unique = 11,
	}

	local function rankOf(nameStr)
		local low = string.lower(tostring(nameStr))
		local k = (string.gsub(low, "[^%w]", ""))
		if RANK[k] then return RANK[k] end
		local tn = string.match(low, "^tier%s*(%d+)$")
		if tn then return 100 + tonumber(tn) end
		return 1000
	end

	local function rebuildMeta()
		local seen, list = {}, {}
		for _, rn in pairs(rarMap) do
			if not seen[rn] and not string.match(rn, "^[Tt]ier%s*%d+$") then
				seen[rn] = true
				list[#list + 1] = rn
			end
		end
		if #list == 0 then return end
		table.sort(list, function(a, b)
			local ra, rb = rankOf(a), rankOf(b)
			if ra ~= rb then return ra < rb end
			return a < b
		end)
		local names = {}
		for i = 1, math.min(#list, MAX_NAMES) do names[i] = list[i] end
		api.names = names
		for k in pairs(api.colors) do api.colors[k] = nil end
		local autoN = 0
		for _, rn in ipairs(list) do
			local rk = rankOf(rn)
			local c = nil
			if rk >= 1 and rk <= 6 then c = BASECOL[NAMES[rk]] end
			if not c and EXTRACOL[rn] then c = EXTRACOL[rn] end
			if not c then
				autoN = autoN + 1
				c = Color3.fromHSV((autoN * 0.381966) % 1, 0.55, 1)
			end
			api.colors[rn] = c
		end
	end

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

	-- [PATCH] catat SUMBER tiap entri (nama modul + nama wadahnya) supaya data jamur bisa dipisah dari item lain (pisau, dll)
	local function subPath(path, k)
		if type(k) ~= "string" or exactWord(k) then return path, false end
		local _, n = string.gsub(path, "/", "")
		if n >= 3 then return path, false end
		return path .. "/" .. k, true
	end
	local function srcOf(path, app)
		if app then
			local up = string.match(path, "^(.*)/[^/]*$")
			if up then return up end
		end
		return path
	end

	local function fieldsOf(t)
		local out, n = {}, 0
		for k, v in pairs(t) do
			if type(k) == "string" and (type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
				n = n + 1
				if n > 12 then break end
				out[#out + 1] = k .. "=" .. tostring(v)
			end
		end
		table.sort(out)
		local str = table.concat(out, ", ")
		if #str > 220 then str = string.sub(str, 1, 220) .. "..." end
		return str
	end

	local function scanTable(root, found, rootName)
		local seen, nodes = {}, 0
		local function walk(t, depth, key, path, app)
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
					table.insert(found, { name = tostring(nm), rar = rv, sc = best, src = srcOf(path, app), fields = fieldsOf(t), lvl = t.level, prc = t.price, shp = t.shop })
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
								table.insert(found, { name = tostring(nm), rar = k, sc = 1, src = path })
							end
						end
					end
					local np, ap = subPath(path, k)
					walk(v, depth + 1, (type(k) == "string") and k or key, np, ap)
				end
			end
		end
		pcall(walk, root, 0, nil, tostring(rootName or "?"), false)
	end

	-- [PATCH] cari nama rarity ASLI di config game: array nama ({"Common",...}), kamus nama->nomor, atau tabel ber-Order
	local function findRarityNames(root)
		local seen, nodes, res = {}, 0, nil
		local ORDK = { "Order", "Tier", "Level", "Rank", "Id", "ID", "Index", "Value", "Num", "Number" }
		local function walk(t, depth)
			if res or depth > 4 or seen[t] or nodes > 3000 then return end
			seen[t] = true
			nodes = nodes + 1
			local n = #t
			if n >= 5 and n <= 14 then
				local arr, hits = {}, 0
				for i = 1, n do
					local v = t[i]
					local nmv = v
					if type(v) == "table" then nmv = v.Name or v.name or v.DisplayName or v.Title end
					if type(nmv) == "string" then
						arr[i] = nmv
						if exactWord(nmv) then hits = hits + 1 end
					end
				end
				if hits >= 4 then
					res = arr
					return
				end
			end
			local d, dh = {}, 0
			for k, v in pairs(t) do
				if type(k) == "string" and exactWord(k) then
					local num = nil
					if type(v) == "number" then
						num = v
					elseif type(v) == "table" then
						for _, f in ipairs(ORDK) do
							if type(v[f]) == "number" then
								num = v[f]
								break
							end
						end
					end
					if num then
						d[num] = k
						dh = dh + 1
					end
				end
			end
			if dh >= 4 then
				res = d
				return
			end
			for _, v in pairs(t) do
				if type(v) == "table" then walk(v, depth + 1) end
			end
		end
		pcall(walk, root, 0)
		return res
	end

	local function loadCore()
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
		local modKeys, gameNames = {}, nil
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
				scanTable(res, found, m.Name)
				if #modKeys < 10 then
					local ks = {}
					for k, v in pairs(res) do
						if type(k) == "string" and #ks < 25 then ks[#ks + 1] = k .. "(" .. type(v) .. ")" end
					end
					table.sort(ks)
					modKeys[#modKeys + 1] = m.Name .. ": " .. table.concat(ks, ", ")
				end
				if not gameNames then gameNames = findRarityNames(res) end
			end
		end

		api.modKeys = modKeys
		-- [PATCH] contoh data mentah utk laporan SCAN (pisau vs jamur)
		do
			local DIAG = { accordknife = true, barrowsteelblade = true, ashcap = true, blacktruffle = true }
			api.diag = {}
			for _, f in ipairs(found) do
				if DIAG[norm(f.name)] and #api.diag < 6 then
					api.diag[#api.diag + 1] = tostring(f.name) .. " | sumber=" .. tostring(f.src) .. " | rar=" .. tostring(f.rar) .. " | " .. tostring(f.fields or "")
				end
			end
		end

		-- [PATCH] daftar semua alat/pisau (sumber TOOLS) lengkap dengan level, harga, toko
		do
			api.tools = {}
			for _, f in ipairs(found) do
				if string.find(string.lower(tostring(f.src or "")), "tool", 1, true) then
					api.tools[#api.tools + 1] = { n = tostring(f.name), r = tonumber(f.rar) or 0, l = tonumber(f.lvl) or 0, p = tostring(f.prc or "?"), s = tostring(f.shp or "-") }
				end
			end
			table.sort(api.tools, function(a, b)
				if a.s ~= b.s then return a.s < b.s end
				return a.l < b.l
			end)
		end

		-- [PATCH] HANYA DATA JAMUR: modul/wadah yang memuat 4 jamur acuan (Honey Fungus dst.) dianggap data jamur.
		-- Item lain di modul/wadah lain (pisau, alat, dll) dibuang dari data rarity. Tidak ada acuan = tanpa filter.
		do
			local ANCH = { honeyfungus = true, amethystdeceiver = true, blacktrumpet = true, blacktruffle = true }
			local anchSrc, anyAnch = {}, false
			for _, f in ipairs(found) do
				if ANCH[norm(f.name)] then
					anchSrc[f.src or "?"] = true
					anyAnch = true
				end
			end
			api.mushOnly = false
			api.srcInfo = "jamur acuan tidak ditemukan -> tanpa filter jamur (semua sumber dipakai)"
			if anyAnch then
				local function isMushSrc(src)
					if anchSrc[src] then return true end
					local l = string.lower(src)
					return (string.find(l, "mushroom", 1, true) or string.find(l, "shroom", 1, true)
						or string.find(l, "fung", 1, true) or string.find(l, "jamur", 1, true)
						or string.find(l, "wild", 1, true)) ~= nil
				end
				local kept, keptN, dropN = {}, {}, {}
				for _, f in ipairs(found) do
					local sc = f.src or "?"
					if isMushSrc(sc) then
						kept[#kept + 1] = f
						keptN[sc] = (keptN[sc] or 0) + 1
					else
						dropN[sc] = (dropN[sc] or 0) + 1
					end
				end
				if #kept > 0 then
					local parts = {}
					local function addInfo(tag, tbl)
						local ks = {}
						for sc in pairs(tbl) do ks[#ks + 1] = sc end
						table.sort(ks)
						for i = 1, math.min(#ks, 6) do parts[#parts + 1] = tag .. ": " .. ks[i] .. " (" .. tbl[ks[i]] .. ")" end
					end
					addInfo("dipakai", keptN)
					addInfo("dibuang", dropN)
					api.srcInfo = table.concat(parts, "; ")
					api.mushOnly = true
					found = kept
				end
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
			-- [PATCH] semua tier di atas Epic diberi nama berurutan (dulu hanya Legendary & Mythic)
			local TOPN = { "Legendary", "Mythic", "Secret", "Exotic", "Divine", "Godly", "Unique" }
			for i, tn in ipairs(arr) do
				nm[tn] = TOPN[i] or ("Rarity " .. tostring(tn))
			end
		end
		api.namesFromGame = false
		api.gameNamesStr = nil
		if gameNames then
			local maxT = 0
			for _, f in pairs(best) do
				if type(f.rar) == "number" and f.rar > maxT then maxT = f.rar end
			end
			if maxT > 0 and type(gameNames[1]) == "string" and type(gameNames[maxT]) == "string" then
				local ks, ps = {}, {}
				for n, gname in pairs(gameNames) do
					if type(n) == "number" and type(gname) == "string" and gname ~= "" then
						nm[n] = gname
						ks[#ks + 1] = n
					end
				end
				table.sort(ks)
				for _, n in ipairs(ks) do ps[#ps + 1] = tostring(n) .. "=" .. tostring(gameNames[n]) end
				api.gameNamesStr = table.concat(ps, ", ")
				api.namesFromGame = true
			end
		end
		-- [PATCH] jaring pengaman: nomor tier apa pun yang ada di data tapi belum bernama TIDAK dibuang lagi
		do
			local nums, seenN, maxKnown = {}, {}, -math.huge
			for n in pairs(nm) do if n > maxKnown then maxKnown = n end end
			for _, f in pairs(best) do
				if type(f.rar) == "number" and not nm[f.rar] and not seenN[f.rar] then
					seenN[f.rar] = true
					nums[#nums + 1] = f.rar
				end
			end
			table.sort(nums)
			local used = {}
			for _, rn in pairs(nm) do used[rn] = true end
			local EXTRA = { "Secret", "Exotic", "Divine", "Godly", "Unique" }
			local ei = 1
			for _, n in ipairs(nums) do
				local nameX
				if n > maxKnown then
					while ei <= #EXTRA and used[EXTRA[ei]] do ei = ei + 1 end
					nameX = EXTRA[ei]
					if nameX then ei = ei + 1 end
				end
				nameX = nameX or ("Rarity " .. tostring(n))
				used[nameX] = true
				nm[n] = nameX
			end
		end
		numName = nm
		api.tierNames = nm -- dipakai NPC resolver untuk atribut Tier numerik
		do
			local ks = {}
			for n in pairs(nm) do ks[#ks + 1] = n end
			table.sort(ks)
			local ps = {}
			for _, n in ipairs(ks) do ps[#ps + 1] = tostring(n) .. "=" .. tostring(nm[n]) end
			api.tierMapInfo = table.concat(ps, ", ")
		end

		rarMap, keysByLen = {}, {}
		local count = 0
		local numericN = 0
		for k, f in pairs(best) do
			local rn
			if type(f.rar) == "number" then
				numericN = numericN + 1
				rn = numName[f.rar] -- [FIX] tanpa fallback "Tier N": angka tak dikenal diabaikan
			else
				local w = wordIn(f.rar)
				rn = w and cap(w) or tostring(f.rar)
			end
			if rn and not string.match(rn, "^[Tt]ier%s*%d+$") then
				rarMap[k] = rn
				count = count + 1
				if #k >= 5 then table.insert(keysByLen, k) end
			end
		end
		table.sort(keysByLen, function(a, b) return #a > #b end)
		rebuildMeta()
		local calApplied = (calOk and calCount == 4 and epicN) and true or false
		api.tierGuess = numericN > 0 and not calApplied -- nomor tier diterjemahkan pakai urutan standar (tebakan)

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


	-- ---------- PROFIL PER GAME: hasil deteksi disimpan di <saveFolder>/rarity_<GameId>.json ----------
	-- Kunjungan berikutnya di game yang sama langsung memakai profil (tanpa require modul game).
	-- Profil dianggap basi setelah PROFILE_MAX_AGE detik; tombol SCAN selalu membaca ulang dari game.
	local HttpSvc = game:GetService("HttpService")
	local PROFILE_MAX_AGE = 7 * 24 * 3600

	local function profilePath()
		return settings.path("rarity_" .. tostring(game.GameId) .. ".json")
	end

	local function notifyListeners()
		api.version = api.version + 1
		for _, fn in ipairs(api.listeners) do pcall(fn) end
	end

	local function applyMap(map)
		rarMap, keysByLen = {}, {}
		local n = 0
		for k, rn in pairs(map) do
			if type(k) == "string" and type(rn) == "string" and k ~= "" and not string.match(rn, "^[Tt]ier%s*%d+$") then
				rarMap[k] = rn
				n = n + 1
				if #k >= 5 then table.insert(keysByLen, k) end
			end
		end
		table.sort(keysByLen, function(a, b) return #a > #b end)
		return n
	end

	local function loadProfile()
		if not (readfile and isfile) then return false end
		local p = profilePath()
		local okE, exists = pcall(isfile, p)
		if not (okE and exists) then return false end
		local okR, raw = pcall(readfile, p)
		if not okR then return false end
		local okD, d = pcall(function() return HttpSvc:JSONDecode(raw) end)
		if not (okD and type(d) == "table" and type(d.map) == "table" and type(d.t) == "number") then return false end
		if d.v ~= 5 then return false end -- [FIX] profil versi lama dibuang
		if os.time() - d.t > PROFILE_MAX_AGE then return false end
		local n = applyMap(d.map)
		if n == 0 then return false end
		rebuildMeta()
		api.tierGuess = d.tg == true
		api.mushOnly = d.mo == true
		api.srcInfo = type(d.si) == "string" and d.si or nil
		cache = {}
		api.count = n
		api.loading = false
		api.failed = false
		api.ready = true
		api.source = "profil tersimpan"
		notifyListeners()
		return true
	end

	local function saveProfile()
		if not (writefile and api.ready) then return end
		pcall(function()
			if makefolder and isfolder and not isfolder(settings.saveFolder) then
				pcall(makefolder, settings.saveFolder)
			end
			local map = {}
			for k, rn in pairs(rarMap) do map[k] = rn end
			settings.save("rarity_" .. tostring(game.GameId) .. ".json", HttpSvc:JSONEncode({ v = 5, t = os.time(), gid = game.GameId, count = api.count, tg = api.tierGuess == true, mo = api.mushOnly == true, si = api.srcInfo, map = map }))
		end)
	end

	-- Pembungkus tunggal: profil dulu (kecuali force), lalu baca dari modul game. Error ditangkap ke api.error.
	local function loadData(force)
		if api.loading or unloaded then return end
		api.error = nil
		if not force and loadProfile() then return end
		local ok, err = pcall(loadCore)
		if not ok then
			api.loading = false
			api.ready = false
			api.failed = true
			api.error = tostring(err)
			notifyListeners()
			return
		end
		if api.ready then
			api.source = "modul game"
			saveProfile()
		end
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

	-- Baca ulang paksa dari modul game (dipakai tombol SCAN, supaya hasilnya = mesin yang dipakai dropdown).
	function api.reload()
		local t0 = os.clock()
		while api.loading and not unloaded and os.clock() - t0 < 90 do task.wait(0.1) end
		if unloaded then return end
		loadData(true)
	end

	function api.summary()
		local c = {}
		for _, rn in pairs(rarMap) do c[rn] = (c[rn] or 0) + 1 end
		return c
	end

	function api.byRarity(n)
		local out = {}
		local ks = {}
		for k in pairs(rarMap) do ks[#ks + 1] = k end
		table.sort(ks)
		for _, k in ipairs(ks) do
			local rn = rarMap[k]
			out[rn] = out[rn] or {}
			if #out[rn] < n then out[rn][#out[rn] + 1] = k end
		end
		return out
	end

	function api.sample(n)
		local ks = {}
		for k in pairs(rarMap) do ks[#ks + 1] = k end
		table.sort(ks)
		local out = {}
		for i = 1, math.min(n, #ks) do out[i] = ks[i] .. " -> " .. rarMap[ks[i]] end
		return out
	end

	settings.rarityApi = api
	-- Saat database rarity selesai dimuat, cocokkan ulang NPC yang sudah terdeteksi.
	local npcRarityState = settings.npcRarityState
	if npcRarityState and npcRarityState.refreshRarity then
		api.listeners[#api.listeners + 1] = function()
			if unloaded then return end
			pcall(npcRarityState.refreshRarity)
			if npcRarityState.refreshRarityDropdown then pcall(npcRarityState.refreshRarityDropdown) end
			if npcRarityState.refreshRows then pcall(npcRarityState.refreshRows) end
		end
	end

	-- AUTO: baca data rarity sendiri begitu script jalan (profil dulu, kalau tidak ada baru baca modul game).
	-- Kalau gagal, coba sekali lagi 20 detik kemudian (sebagian game mengisi ReplicatedStorage belakangan).
	-- Selama auto, toast "Data rarity tidak ditemukan" ditahan; hasilnya bisa dicek lewat tombol SCAN.
	if settings.autoRarity ~= false then
		task.spawn(function()
			if not game:IsLoaded() then game.Loaded:Wait() end
			task.wait(4)
			if unloaded then return end
			api.silentFail = true
			local function waitDone()
				api.ensure()
				local t0 = os.clock()
				while api.loading and not unloaded and os.clock() - t0 < 120 do task.wait(0.25) end
			end
			waitDone()
			if api.failed and not unloaded then
				task.wait(20)
				if not unloaded then
					api.failed = false
					waitDone()
				end
			end
			api.silentFail = false
		end)
	end
end, warn)

sectionLabel(pages.ESP, 4, "Loot & Item ESP")

do

-- ---------- UI ----------
local scannerCard = makeCard(pages.ESP, 296, 5)

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
local selectAllBtn = smallButton(actionRow, "Pilih hasil", UDim2.new(0.2, -5, 1, 0), 1)
local clearSelBtn = smallButton(actionRow, "Kosongkan", UDim2.new(0.2, -5, 1, 0), 2)
local dotsBtn = smallButton(actionRow, "Titik: ON", UDim2.new(0.2, -5, 1, 0), 3)
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
local LABEL_MAX_DIST = 100000    -- label tampil sampai jarak ini (studs); praktis tanpa batas, yang membatasi hanya streaming game
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
local DB, LB = 120, 1000         -- jumlah bucket histogram jarak (titik / label)

local COL_DOT = T.accent2
local COL_SEL = T.good

local CLASS_CAT: { [string]: string } = {
	ProximityPrompt = "Prompt",
	ClickDetector = "Klik",
	Tool = "Tool",
}
local PRI: { [string]: number } = { Prompt = 4, Klik = 3, Tool = 2, Sentuh = 1, Nama = 0 }

-- Nama part yang terlalu umum -> pakai nama induknya
local GENERIC: { [string]: boolean } = {
	Handle = true, Part = true, MeshPart = true, Union = true, UnionOperation = true,
	Main = true, Root = true, Hitbox = true, Attachment = true, Base = true, Body = true,
	Mesh = true, Primary = true, PrimaryPart = true, Hit = true, Trigger = true,
	Collider = true, Prompt = true, Interact = true,
}

-- ---------- [SCAN+] DETEKSI BERDASAR NAMA ----------
-- Banyak game (rumah/horor/dalang) menaruh kunci, linggis, senter, dll sebagai Model biasa
-- tanpa ProximityPrompt/ClickDetector/Tool, jadi scan lama tidak melihatnya.
-- Di sini nama Model/Part dicocokkan dengan kamus kata (utuh per kata, bukan potongan: "Monkey" tidak dianggap "key").
local NM: any = { cache = {}, size = 14 }
NM.key = {
	key = true, keys = true, keycard = true, kunci = true, padlock = true, gembok = true,
	lockpick = true, passkey = true, kuncinya = true,
}
NM.tool = {
	crowbar = true, linggis = true, pickaxe = true, hammer = true, palu = true, axe = true, kapak = true,
	screwdriver = true, obeng = true, wrench = true, pliers = true, tang = true, shovel = true, sekop = true,
	flashlight = true, senter = true, torch = true, lantern = true, lentera = true, knife = true, pisau = true,
	saw = true, gergaji = true, scissors = true, gunting = true, bolt = true, cutter = true, lighter = true, korek = true,
	crowbars = true, machete = true, parang = true, golok = true, sickle = true, sabit = true,
	rod = true, pancing = true, joran = true, net = true, jaring = true, bait = true, umpan = true,
}
NM.misc = {
	battery = true, baterai = true, fuse = true, sekring = true, medkit = true, bandage = true, perban = true,
	rope = true, tali = true, keypad = false,
	bag = true, backpack = true, tas = true, ransel = true,
}
NM.titles = { key = "🔑 Kunci & Akses", tool = "🛠 Alat & Senjata", misc = "🎒 Perlengkapan" }
NM.PFX = "📁 "
NM.other = "📦 Item Lainnya"
NM.many = "🧱 Banyak / Dekorasi"
NM.custom = {}
NM.ccache = {}
do
	local ig = settings.itemGroups
	if type(ig) == "table" then
		for title, words in pairs(ig) do
			if type(title) == "string" and type(words) == "table" then
				for _, w in ipairs(words) do
					if type(w) == "string" and w ~= "" then
						local lw = string.lower(w)
						NM.custom[lw] = NM.PFX .. title
						NM.misc[lw] = true -- ikut terdeteksi lewat nama
					end
				end
			end
		end
	end
end
-- nama folder yang terlalu umum untuk dijadikan judul grup
NM.skipFolder = {
	map = true, world = true, workspace = true, items = true, item = true, loot = true, objects = true, object = true,
	folder = true, model = true, models = true, game = true, assets = true, spawns = true, spawn = true, spawned = true,
	pickups = true, pickup = true, drops = true, drop = true, debris = true, ignore = true, level = true, lobby = true,
	interactables = true, interactable = true, props = true, prop = true, decor = true, environment = true,
	structures = true, buildings = true, effects = true, vfx = true, camera = true, terrain = true,
}
-- kata yang berarti BUKAN barang yang bisa diambil (pintu, ruangan, lubang kunci, dll)
NM.block = {
	door = true, pintu = true, gate = true, gerbang = true, room = true, ruang = true, ruangan = true,
	shop = true, store = true, toko = true, cabinet = true, lemari = true, safe = true, brankas = true,
	hole = true, keyhole = true, slot = true, holder = true, rack = true, spawn = true, spawner = true,
	zone = true, area = true, trigger = true, region = true, sign = true, poster = true, lock = true,
}
for _, w in ipairs((settings.itemWords :: any) or {}) do
	if type(w) == "string" and w ~= "" then NM.misc[string.lower(w)] = true end
end

function NM.tokens(n: string): { string }
	local spaced = string.gsub(n, "(%l)(%u)", "%1 %2")
	spaced = string.lower(spaced)
	local t = {}
	for w in string.gmatch(spaced, "%a+") do t[#t + 1] = w end
	return t
end

-- "key" | "tool" | "misc" | false
function NM.customTitle(n: string): string?
	if next(NM.custom) == nil then return nil end
	local c = NM.ccache[n]
	if c ~= nil then return c or nil end
	local res: any = false
	for _, w in ipairs(NM.tokens(n)) do
		if NM.custom[w] then res = NM.custom[w]; break end
	end
	if not res then
		local compact = string.lower((string.gsub(n, "[^%a]", "")))
		if NM.custom[compact] then res = NM.custom[compact] end
	end
	NM.ccache[n] = res
	return res or nil
end

function NM.kind(n: string): any
	local c = NM.cache[n]
	if c ~= nil then return c end
	local res: any = false
	local toks = NM.tokens(n)
	local blocked = false
	for _, w in ipairs(toks) do
		if NM.block[w] then blocked = true; break end
	end
	if not blocked then
		local compact = string.lower((string.gsub(n, "[^%a]", "")))
		local cand = { compact }
		for _, w in ipairs(toks) do
			cand[#cand + 1] = w
			if #w > 3 and string.sub(w, -1) == "s" then cand[#cand + 1] = string.sub(w, 1, -2) end
		end
		for _, w in ipairs(cand) do
			if NM.key[w] then res = "key"; break end
		end
		if not res then
			for _, w in ipairs(cand) do
				if NM.tool[w] then res = "tool"; break end
			end
		end
		if not res then
			for _, w in ipairs(cand) do
				if NM.misc[w] then res = "misc"; break end
			end
		end
	end
	NM.cache[n] = res
	return res
end

-- Judul grup otomatis dari FOLDER tempat item berada di workspace (mis. Workspace.Fish.Salmon -> "Fish").
-- Berlaku untuk game apa pun; nama folder yang terlalu umum / berangka (Zone1, Spawn_3) dilewati.
function NM.container(part: Instance): string?
	local cur: Instance? = part.Parent
	for _ = 1, 8 do
		if not cur or cur == (workspace :: Instance) then return nil end
		if cur:IsA("Folder") then
			local nm = cur.Name
			if #nm >= 3 and not string.find(nm, "%d") then
				local generic = false
				for _, w in ipairs(NM.tokens(nm)) do
					if NM.skipFolder[w] then generic = true; break end
				end
				if not generic then
					local clean = string.gsub(nm, "[_%-]+", " ")
					local al = settings.groupAlias
					if type(al) == "table" and type(al[nm]) == "string" then clean = al[nm] end
					clean = string.match(clean, "^%s*(.-)%s*$") or clean
					if clean ~= "" then return NM.PFX .. string.sub(clean, 1, 24) end
				end
			end
		end
		cur = cur.Parent
	end
	return nil
end

local function tooBig(inst: Instance): boolean
	local ok, sz = pcall(function()
		if inst:IsA("Model") then return (inst :: Model):GetExtentsSize() end
		return (inst :: BasePart).Size
	end)
	if not ok or not sz then return false end
	return math.max(sz.X, sz.Y, sz.Z) > NM.size
end

-- kategori kandidat: kelas pemicu biasa, atau "Nama" bila namanya cocok kamus (Model / Part lepas)
local function candidateCat(inst: Instance): string?
	local c = CLASS_CAT[inst.ClassName]
	if c then return c end
	if settings.nameDetect == false then return nil end
	local isModel = inst:IsA("Model")
	if not (isModel or inst:IsA("BasePart")) then return nil end
	if not NM.kind(inst.Name) then return nil end
	local p = inst.Parent
	if p and p:IsA("Model") and NM.kind(p.Name) then return nil end -- induknya sudah mewakili
	return "Nama"
end

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

-- [PATCH] Mode "hanya jamur" (aktif bila data jamur acuan ditemukan di game ini).
-- Jamur di dunia selalu membawa atribut spesies "Sp" pada modelnya; pisau/alat/pintu tidak.
local function mushGate(): boolean
	if settings.mushroomOnly == false then return false end
	local api = settings.rarityApi
	return (api and api.ready and api.mushOnly) == true
end

local function instMush(e: any): boolean?
	if e.mushC ~= nil then return e.mushC end
	local ok, r = pcall(function()
		local tr = e.trig
		local m = tr and (tr:IsA("Tool") and tr or tr:FindFirstAncestorOfClass("Model")) or e.part
		if not m then return false end
		return type(m:GetAttribute("Sp")) == "string"
	end)
	if ok then e.mushC = (r == true) end
	return e.mushC
end

-- untuk satu entri ESP di dunia
local function mushOkE(e: any): boolean
	if not mushGate() then return true end
	if itemSel[e.name] == true then return true end -- item non-jamur (pisau/alat) yang dicentang manual lewat pencarian tetap di-ESP
	return instMush(e) ~= false
end

-- untuk satu nama item di daftar: pakai instance di dunia bila ada, kalau tidak pakai data jamur
local function mushOk(name: string): boolean
	if not mushGate() then return true end
	local g = groups[name]
	local e1 = g and g.list[1]
	if e1 then return instMush(e1) ~= false end
	return rarityOf(name) ~= nil
end

-- [SCAN+] GRUP DAFTAR (universal): judul grup dibuat otomatis dari data game itu sendiri, bukan tema tertentu.
--   1) folder tempat item berada di workspace (Fish / Rods / Bags / ... apa pun namanya di game itu)
--   2) kata kunci umum: kunci, alat/senjata, perlengkapan
--   3) sisanya -> "Item Lainnya"
local GRP: any = {
	rank = {}, frames = {}, ver = -1, rdy = false,
	sel = {}, selN = 0, open = {}, openNow = {}, forced = false,
	manyCand = {}, counts = {}, list = {},
	th = (tonumber(settings.manyThreshold) or 60) > 0 and (tonumber(settings.manyThreshold) or 60) or math.huge,
	autoOpenMax = 30,
}
function GRP.of(name: string): string
	local ct = NM.customTitle(name)
	if ct then return ct end
	local k = NM.kind(name)
	if k then return NM.titles[k] end
	local cg = catalog[name]
	if cg and type(cg.grp) == "string" then return cg.grp end
	if cg and cg.cats and cg.cats.Tool then return NM.titles.tool end
	local g = groups[name]
	if g and #g.list >= GRP.th and itemSel[name] ~= true then return NM.many end
	return NM.other
end
function GRP.tier(t: string): number
	if string.sub(t, 1, #NM.PFX) == NM.PFX then return 1 end
	if t == NM.titles.key then return 2 end
	if t == NM.titles.tool then return 3 end
	if t == NM.titles.misc then return 4 end
	if t == NM.many then return 6 end
	return 5
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
		Text = ((mushGate() and instMush(e) == false) and "[ALAT] " or "") .. e.name,
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
	if cg.grp == nil then
		local gt = NM.container(part)
		cg.grp = gt or false
		if gt then orderDirty = true; persistDirty = true end
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
	if cat == "Nama" then
		if inst:IsA("BasePart") then return inst :: BasePart, inst end
		return firstPart(inst), inst
	end
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
	local cat = candidateCat(inst)
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

	if cat == "Nama" then
		-- sudah punya Prompt/Klik sendiri -> biar pemicu aslinya yang mendaftar (hindari ganda)
		if inst:FindFirstChildWhichIsA("ProximityPrompt", true) or inst:FindFirstChildWhichIsA("ClickDetector", true) then return end
		if inst:FindFirstChildOfClass("Humanoid") then return end
		if tooBig(inst) then return end
	end

	if cat == "Sentuh" then
		if part.CanTouch == false then return end
		local par = part.Parent
		if par and par:FindFirstChildOfClass("Humanoid") then return end -- bagian tubuh NPC
	end

	if cat == "Prompt" then
		local at = string.lower((inst :: ProximityPrompt).ActionText)
		for _, w in ipairs({ "open", "close", "sit", "talk", "enter", "exit", "buy", "sell", "shop", "toggle", "switch", "lever", "door", "pintu", "buka", "tutup", "duduk", "bicara", "beli", "jual", "masuk", "keluar" }) do
			if string.find(at, w, 1, true) then return end
		end
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
	elseif cat == "Tool" or cat == "Nama" then
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
		if candidateCat(inst) then
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
	-- non-jamur (pisau/alat) HANYA muncul kalau dicari manual (kotak pencarian tidak kosong)
	local isMush = mushOk(g.name)
	if not isMush and not hasQuery then return false end
	if hasQuery then
		local hit = false
		for i = 1, #terms do
			if string.find(g.lower, terms[i], 1, true) then hit = true; break end
		end
		if not hit then return false end
	end
	-- Di tab Terpilih, item yang dicentang manual tetap tampil walau rarity-nya di luar filter
	if rarSelN > 0 and isMush and not (filterMode == "Terpilih" and itemSel[g.name] == true) then
		local rapi = settings.rarityApi
		if rapi and not rapi.failed then
			local r = rarityOf(g.name)
			if not (r and rarSel[r]) then return false end
		end
	end
	-- filter dropdown Grup (pencarian menembus semua grup; tab Terpilih menampilkan semua yang dicentang)
	if GRP.selN > 0 and not hasQuery and not (filterMode == "Terpilih" and itemSel[g.name] == true) then
		if not GRP.sel[GRP.rank[g.name] or NM.other] then return false end
	end
	if GRP.selN == 0 and not hasQuery and filterMode ~= "Terpilih" and settings.groupHideMany ~= false
		and GRP.rank[g.name] == NM.many then
		return false
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
				r.btn.LayoutOrder = i * 2
			end
		end
		layoutDirty = false
	end
end

local function rebuildOrder()
	table.clear(order)
	local rk, cnt = {}, {}
	GRP.manyCand = {}
	for name in pairs(catalog) do
		order[#order + 1] = name
		local t = GRP.of(name)
		rk[name] = t
		cnt[t] = (cnt[t] or 0) + 1
		local g = groups[name]
		GRP.manyCand[name] = g ~= nil and #g.list >= GRP.th
	end
	-- grup folder yang isinya cuma 1 jenis dilebur ke "Item Lainnya" supaya header tidak kebanyakan
	for name, t in pairs(rk) do
		if cnt[t] == 1 and GRP.tier(t) == 1 then
			rk[name] = NM.other
			cnt[t] = nil
			cnt[NM.other] = (cnt[NM.other] or 0) + 1
		end
	end
	table.sort(order, function(a, b)
		local la, lb = catalog[a].lower, catalog[b].lower
		if la ~= lb then return la < lb end
		return a < b
	end)
	GRP.rank = rk
	GRP.counts = cnt
	local list = {}
	for t in pairs(cnt) do list[#list + 1] = t end
	table.sort(list, function(a, b)
		local ta, tb = GRP.tier(a), GRP.tier(b)
		if ta ~= tb then return ta < tb end
		return a < b
	end)
	GRP.list = list
	-- buang pilihan grup yang sudah tidak ada (mis. pindah game)
	local n = 0
	for t in pairs(GRP.sel) do
		if cnt[t] then n += 1 else GRP.sel[t] = nil end
	end
	GRP.selN = n
	orderDirty = false
	if GRP.menuRefresh then GRP.menuRefresh() end
end

local function flushUI()
	do
		local rapi = settings.rarityApi
		local ver = rapi and rapi.version or 0
		local rdy = (rapi and rapi.ready) == true
		if GRP.ver ~= ver or GRP.rdy ~= rdy then
			GRP.ver, GRP.rdy = ver, rdy
			orderDirty = true -- data jamur baru siap -> kelompok diurut ulang
		end
		for name in pairs(dirtyNames) do
			local g = groups[name]
			local want = g ~= nil and #g.list >= GRP.th
			if want ~= (GRP.manyCand[name] == true) then orderDirty = true; break end
		end
	end
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
			if candidateCat(inst) then
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
			local stInfo = "Streaming: MATI"
			if workspace.StreamingEnabled then
				local okR, rad = pcall(function() return workspace.StreamingTargetRadius end)
				stInfo = "Streaming: AKTIF" .. (okR and (" (radius " .. tostring(rad) .. ")") or "")
			end
			toast(string.format("Scan selesai: %d jenis, %d objek · %s", #order, totalObjs, stInfo))
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
GRP.refresh = onFilterChanged

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

-- ---------- dropdown GRUP (universal): isinya otomatis mengikuti game yang dimainkan ----------
do
	local grpBtn = smallButton(actionRow, "Grup ▼", UDim2.new(0.2, -5, 1, 0), 4)
	grpBtn.TextSize = 10
	local ROW_H, GAP = 22, 2
	local PANEL_MAX_H = 8 + 6 * ROW_H + 5 * GAP -- maksimal 6 baris terlihat, sisanya di-scroll
	local panel = new("ScrollingFrame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -14, 0, 158),
		Size = UDim2.fromOffset(190, 40),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.accent,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		BackgroundColor3 = T.card,
		BorderSizePixel = 0,
		Active = true,
		Visible = false,
		ZIndex = 30,
	}, scannerCard)
	round(panel, 8)
	stroke(panel, T.stroke, 1, 0.2)
	new("UIListLayout", { Padding = UDim.new(0, GAP), SortOrder = Enum.SortOrder.LayoutOrder }, panel)
	new("UIPadding", {
		PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4),
		PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4),
	}, panel)
	GRP.panel = panel

	local btns: { any } = {}
	local items: { string } = {}
	local refreshMenu
	refreshMenu = function()
		items = { "Semua" }
		for _, t in ipairs(GRP.list) do items[#items + 1] = t end
		for i = 1, #items do
			local b = btns[i]
			if not b then
				b = new("TextButton", {
					LayoutOrder = i,
					Size = UDim2.new(1, 0, 0, ROW_H),
					BackgroundColor3 = T.bg,
					Text = "",
					TextColor3 = T.text,
					Font = Enum.Font.GothamMedium,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
					AutoButtonColor = false,
					BorderSizePixel = 0,
					ZIndex = 31,
				}, panel)
				round(b, 6)
				new("UIPadding", { PaddingLeft = UDim.new(0, 8) }, b)
				btns[i] = b
				b.MouseButton1Click:Connect(function()
					local n = items[i]
					if not n then return end
					if n == "Semua" then
						table.clear(GRP.sel)
						GRP.selN = 0
						panel.Visible = false
					elseif GRP.sel[n] then
						GRP.sel[n] = nil
						GRP.selN -= 1
					else
						GRP.sel[n] = true
						GRP.selN += 1
					end
					refreshMenu()
					onFilterChanged()
				end)
			end
			local n = items[i]
			local chk = (i == 1 and GRP.selN == 0) or GRP.sel[n] == true
			local base = i == 1 and "Semua" or (n .. "  (" .. tostring(GRP.counts[n] or 0) .. ")")
			b.Text = base .. (chk and "   ✓" or "")
			b.BackgroundColor3 = chk and T.cardSel or T.bg
			b.Visible = true
		end
		for i = #items + 1, #btns do btns[i].Visible = false end
		panel.Size = UDim2.fromOffset(190, math.min(PANEL_MAX_H, 8 + #items * (ROW_H + GAP)))
		local lb = "Grup"
		if GRP.selN == 1 then lb = "1 grup" elseif GRP.selN > 1 then lb = GRP.selN .. " grup" end
		grpBtn.Text = lb .. (panel.Visible and " ▲" or " ▼")
		grpBtn.BackgroundColor3 = GRP.selN > 0 and T.accent or T.bg
		grpBtn.TextColor3 = GRP.selN > 0 and WHITE or T.sub
	end
	GRP.menuRefresh = refreshMenu

	-- roda mouse di atas panel hanya menggulir panel itu sendiri
	local function lockBehind(lock: boolean)
		lootScroll.ScrollingEnabled = not lock
		pages.ESP.ScrollingEnabled = not lock
	end
	panel.MouseEnter:Connect(function() lockBehind(true) end)
	panel.MouseLeave:Connect(function() lockBehind(false) end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if not panel.Visible then lockBehind(false) end
	end)

	grpBtn.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
		if panel.Visible and GRP.rarPanel then GRP.rarPanel.Visible = false end
		refreshMenu()
	end)
	refreshMenu()
end

-- ---------- dropdown RARITY: filter daftar; warna label & titik ikut rarity ----------
do
	local api = settings.rarityApi
	if api then
		-- Isi dropdown mengikuti data game (api.names). Sebelum data dimuat: 6 nama bawaan.
		local MAXR = 12
		local RN = { "Semua" }
		local function loadRN()
			RN = { "Semua" }
			for _, n in ipairs(api.names) do
				if #RN < MAXR + 1 then RN[#RN + 1] = n end
			end
		end
		loadRN()

		local rarBtn = smallButton(actionRow, "Rarity ▼", UDim2.new(0.2, -5, 1, 0), 5)
		rarBtn.TextSize = 10

		local ROW_H, GAP = 22, 2
		-- [FIX] panel = ScrollingFrame yang selalu dimulai DI BAWAH tombol Rarity (tidak pernah menutupinya),
		-- tinggi dibatasi (PANEL_MAX_H) dan bisa di-scroll kalau rarity-nya banyak.
		local PANEL_TOP, PANEL_MAX_H = 158, 8 + 5 * ROW_H + 4 * GAP -- maksimal 5 baris terlihat, sisanya di-scroll di dalam panel
		local panel = new("ScrollingFrame", {
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14, 0, PANEL_TOP),
			Size = UDim2.fromOffset(150, math.min(PANEL_MAX_H, 8 + #RN * ROW_H + (#RN - 1) * GAP)),
			CanvasSize = UDim2.fromOffset(0, 8 + #RN * ROW_H + (#RN - 1) * GAP),
			ScrollBarThickness = 4,
			ScrollBarImageColor3 = T.accent,
			ScrollingDirection = Enum.ScrollingDirection.Y,
			ElasticBehavior = Enum.ElasticBehavior.Never,
			BackgroundColor3 = T.card,
			BorderSizePixel = 0,
			Active = true, -- cegah klik tembus ke daftar di bawahnya
			Visible = false,
			ZIndex = 30,
		}, scannerCard)
		round(panel, 8)
		stroke(panel, T.stroke, 1, 0.2)

		GRP.rarPanel = panel
		local rbtn = {}
		for i = 1, MAXR + 1 do
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

		-- susun ulang panel sesuai jumlah rarity; baris berlebih disembunyikan
		local function layoutPanel()
			local cnt = #RN
			local h = 8 + cnt * ROW_H + (cnt - 1) * GAP
			panel.Size = UDim2.fromOffset(150, math.min(h, PANEL_MAX_H))
			panel.CanvasSize = UDim2.fromOffset(0, h)
			panel.Position = UDim2.new(1, -14, 0, PANEL_TOP)
			for i = 1, MAXR + 1 do
				rbtn[i].Visible = RN[i] ~= nil
			end
		end

		-- ambil daftar terbaru dari loader, buang pilihan yang sudah tidak ada
		local function syncRar()
			loadRN()
			local valid = {}
			for i = 2, #RN do valid[RN[i]] = true end
			for k in pairs(rarSel) do
				if not valid[k] then
					rarSel[k] = nil
					rarSelN = rarSelN - 1
				end
			end
			layoutPanel()
		end

		local function refreshRar()
			for i = 1, MAXR + 1 do
				local n = RN[i]
				if n then
					local chk = (n == "Semua" and rarSelN == 0) or rarSel[n] == true
					local col = api.colors[n] or WHITE
					rbtn[i].Text = string.format('<font color="#%s">●</font>  %s%s', col:ToHex(), n, chk and "   ✓" or "")
					rbtn[i].BackgroundColor3 = chk and T.cardSel or T.bg
				end
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

		for i = 1, MAXR + 1 do
			rbtn[i].MouseButton1Click:Connect(function()
				local n = RN[i]
				if not n then return end
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

		-- [FIX] roda mouse di atas panel Rarity hanya menggulir panel itu sendiri; daftar item di belakangnya
		-- dan halaman ESP dikunci sementara supaya tidak ikut ter-scroll.
		local overPanel = false
		local function lockBehind(lock: boolean)
			lootScroll.ScrollingEnabled = not lock
			pages.ESP.ScrollingEnabled = not lock
		end
		panel.MouseEnter:Connect(function()
			overPanel = true
			lockBehind(true)
		end)
		panel.MouseLeave:Connect(function()
			overPanel = false
			lockBehind(false)
		end)
		panel:GetPropertyChangedSignal("Visible"):Connect(function()
			if not panel.Visible then
				overPanel = false
				lockBehind(false)
			end
		end)

		rarBtn.MouseButton1Click:Connect(function()
			panel.Visible = not panel.Visible
			if panel.Visible and GRP.panel and GRP.panel.Visible then
				GRP.panel.Visible = false
				if GRP.menuRefresh then GRP.menuRefresh() end
			end
			if panel.Visible then api.ensure() end
			refreshRar()
		end)

		-- data rarity selesai dimuat -> warnai ulang daftar & label, terapkan filter
		api.listeners[#api.listeners + 1] = function()
			if unloaded then return end
			if api.failed and not api.silentFail then toast("Data rarity tidak ditemukan di game ini") end
			syncRar()
			refreshRar()
			for name, r in pairs(rows) do
				if r.nmL then r.nmL.TextColor3 = rarityColor(name) or T.text end
			end
			markDue = true
			onFilterChanged()
		end

		syncRar()
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
		local sel = itemSel[e.name] == true and mushOkE(e)
		if d <= DOT_MAX_DIST and (sel or (not settings.dotsSelectedOnly and e.cat ~= "Sentuh")) then
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
		local sel = itemSel[e.name] == true and mushOkE(e)
		local eligible = sel or (not settings.dotsSelectedOnly and e.cat ~= "Sentuh")

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
		BASE_CH = 26, BASE_NS = 12, BASE_IS = 11, BASE_XS = 16, BASE_ZH = 20,
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
		K.ZH = math.max(12, math.floor(K.BASE_ZH * s + 0.5))
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

	K.zr = new("TextLabel", {
		BackgroundTransparency = 1,
		RichText = true,
		Text = "",
		Font = Enum.Font.GothamBold,
		TextSize = K.NS,
		TextColor3 = T.text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(K.AREA_L, K.PAD),
		Size = UDim2.new(1, -(K.AREA_L + K.AREA_R), 0, K.ZH),
		Visible = false,
	}, bar)
	-- X luar: menutup seluruh pop-up (baris daerah + semua kotak). X di tiap kotak = hapus item saja.
	K.xAll = new("TextButton", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -5, 0, K.PAD),
		Size = UDim2.fromOffset(K.ZH, K.ZH),
		BackgroundColor3 = T.off,
		Text = "X",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 9,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
	}, bar)
	new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, K.xAll)
	hover(K.xAll, T.off)
	K.want = function(): boolean
		return not pin.closed and (#pin.list > 0 or (pin.zoneText ~= nil and pin.zoneText ~= ""))
	end

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
		local n = #pin.list
		-- semua kotak selebar nama terpanjang (maks 230); bilah melebar ke kanan
		local cw = 0
		for _, name in ipairs(pin.list) do
			local want = math.ceil(textW(name, Enum.Font.GothamBold, K.NS)) + K.IW + K.XS + 32
			if want > cw then cw = want end
		end
		cw = math.min(cw, 230)
		-- TINGGI DIKUNCI maks 3 baris kotak (tidak pernah bertambah ke bawah). Item ke-4 dst masuk kolom baru ke kanan.
		-- Ukuran manual (grip) hanya MEMPERPANJANG ke kanan: kotak ikut melebar, tidak pernah turun jadi baris baru.
		local rows = math.max(1, math.min(3, n))
		local cols = math.max(1, math.ceil(n / rows))
		pin.w = clampBar(math.max(220, K.AREA_L + K.AREA_R + cols * cw + (cols - 1) * K.GAP, pin.userW or 0), pin.h)
		local innerW = pin.w - K.AREA_L - K.AREA_R
		cw = math.max(cw, math.floor((innerW - (cols - 1) * K.GAP) / cols))
		local r = rows - 1
		for i, name in ipairs(pin.list) do
			local c = chips[name]
			if c then
				local col, row = math.floor((i - 1) / rows), (i - 1) % rows -- isi ke bawah dulu (maks 3), lalu kolom berikutnya
				c.chip.Position = UDim2.fromOffset(col * (cw + K.GAP), row * (K.CH + K.GAP))
				c.chip.Size = UDim2.fromOffset(cw, K.CH)
				c.holder.Size = UDim2.new(1, -(K.XS + 8), 1, 0)
				c.nm.TextSize = K.NS
				c.nm.Size = UDim2.new(1, -(8 + K.IW + 8), 1, 0)
				c.info.TextSize = K.IS
				c.info.Size = UDim2.new(0, K.IW, 1, 0)
				c.x.Size = UDim2.fromOffset(K.XS, K.XS)
				c.x.TextSize = math.max(7, K.NS - 3)
			end
		end
		local showZ = pin.zoneText ~= nil and pin.zoneText ~= ""
		local nRows = (#pin.list > 0) and (r + 1) or 0
		local chipsH = nRows > 0 and (nRows * K.CH + (nRows - 1) * K.GAP) or 0
		local topH = showZ and K.ZH or 0
		local gapH = (showZ and nRows > 0) and K.GAP or 0
		K.zr.Visible = showZ
		K.zr.TextSize = K.NS
		K.zr.Size = UDim2.new(1, -(K.AREA_L + K.ZH + 10), 0, K.ZH)
		K.xAll.Visible = showZ
		K.xAll.Size = UDim2.fromOffset(K.ZH, K.ZH)
		K.xAll.TextSize = math.max(7, K.NS - 3)
		area.Position = UDim2.fromOffset(K.AREA_L, K.PAD + topH + gapH)
		area.Size = UDim2.new(1, -(K.AREA_L + K.AREA_R), 1, -(2 * K.PAD + topH + gapH))
		if nRows == 0 and not showZ then chipsH = K.CH end
		pin.h = topH + gapH + chipsH + 2 * K.PAD
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
		bar.Visible = K.want()
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
			if os.clock() - (pin.lastClick or 0) < 0.35 then
				pin.userW = nil
				persistDirty = true
				relayout()
			end
			pin.lastClick = os.clock()
		end
	end)
	track(UIS.InputChanged:Connect(function(input)
		if resizing and isMove(input) then
			local d = input.Position - sMouse
			if math.abs(d.X) > 3 then pin.userW = sW + d.X end
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
		if pin.set[name] and pin.closed then pin.setClosed(false) end
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

	-- Label daerah di baris atas pop-up (diisi dari blok LABEL DAERAH)
	K.esc = function(s: string): string
		s = string.gsub(s, "&", "&amp;")
		s = string.gsub(s, "<", "&lt;")
		s = string.gsub(s, ">", "&gt;")
		return s
	end
	K.hex = function(c: Color3): string
		return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
	end
	pin.setZone = function(z: string?, p: string?)
		if z == pin.zoneText and p == pin.placeText then return end
		pin.zoneText, pin.placeText = z, p
		local txt = ""
		if z and z ~= "" then
			txt = K.esc(z)
			if p and p ~= "" then
				txt ..= '  <font color="' .. K.hex(T.sub) .. '">' .. K.esc(p) .. "</font>"
			end
		end
		K.zr.Text = txt
		bar.Visible = K.want()
		relayout()
	end
	pin.setClosed = function(v: boolean, silent: boolean?)
		pin.closed = v
		bar.Visible = K.want()
		if not silent and pin.onClosed then pin.onClosed(v) end
	end
	K.xAll.MouseButton1Click:Connect(function()
		pin.setClosed(true)
	end)
	settings.pin = pin

	local accT = 0
	track(RunService.Heartbeat:Connect(function(dt)
		accT += dt
		if accT < 0.5 then return end
		accT = 0
		if bar.Visible then tickBar() end
	end))
end

local catName = "items_" .. tostring(game.GameId) .. ".json"

local function saveCatalog()
	if unloaded or not writefile then return end
	local names = {}
	for _, cg in pairs(catalog) do
		local cats = {}
		for c in pairs(cg.cats) do cats[#cats + 1] = c end
		names[#names + 1] = { n = cg.name, c = cats, g = type(cg.grp) == "string" and cg.grp or nil }
	end
	local sel = {}
	for nm, v in pairs(itemSel) do
		if v then sel[#sel + 1] = nm end
	end
	local okJ, json = pcall(function() return HttpService:JSONEncode({ names = names, sel = sel, pins = pin.list, pinW = pin.w, pinH = pin.h, pinS = pin.sc, pinU = pin.userW }) end)
	if not okJ then return end
	pcall(settings.save, catName, json)
	persistDirty = false
end

local loadedCatalog = false
do
	local data = settings.load(catName)
	if type(data) == "table" then
		if type(data.names) == "table" then
			for _, it in ipairs(data.names) do
				if type(it) == "table" and type(it.n) == "string" and it.n ~= "" then
					local cats = {}
					if type(it.c) == "table" then
						for _, c in ipairs(it.c) do
							if type(c) == "string" and PRI[c] then cats[c] = true end
						end
					end
					local hasOther = false
					for c in pairs(cats) do
						if c ~= "Sentuh" then hasOther = true end
					end
					if next(cats) == nil or hasOther then
						catalog[it.n] = { name = it.n, lower = string.lower(it.n), cats = cats, grp = type(it.g) == "string" and it.g or nil }
					end
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
		if type(data.pinU) == "number" then pin.userW = data.pinU end
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
	local hopFile = "hop_visited.json"
	local HOP_SKIP_SECONDS = 1800 -- server yang baru dikunjungi tidak dipilih lagi selama 30 menit
	local hopMode = "Sepi"
	local hopping = false

	-- Dipindah dari tab ESP ke tab Teleport, ditaruh paling bawah (LayoutOrder besar, di bawah daftar waypoint)
	sectionLabel(teleportPage, 100, "Pindah Server")
	local hopCard = makeCard(teleportPage, 56, 101)

	local hopBtn = new("TextButton", {
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.new(1, -28 - 98, 0, 32),
		BackgroundColor3 = T.accent,
		Text = "🌐 HOP SERVER",
		TextColor3 = WHITE,
		Font = Enum.Font.GothamBold,
		TextSize = 12,
		AutoButtonColor = false,
		BorderSizePixel = 0,
	}, hopCard)
	round(hopBtn, 8)
	hover(hopBtn, T.accent)

	local modeBtn = smallButton(hopCard, "Mode: Sepi", UDim2.fromOffset(90, 32), 0)
	modeBtn.AnchorPoint = Vector2.new(1, 0)
	modeBtn.Position = UDim2.new(1, -14, 0, 12)
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
		do
			local d = settings.load(hopFile)
			if type(d) == "table" then
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
			pcall(settings.save, hopFile, HttpService:JSONEncode(visited))
			pcall(settings.flush) -- [FIX] simpan SEMUA file (item, waypoint, settings, NPC) sebelum pindah server

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

settings.flushers.items = function()
	if persistDirty then saveCatalog() end
end
local saveAcc = 0
track(RunService.Heartbeat:Connect(function(dt: number)
	if unloaded then return end
	saveAcc += dt
	if saveAcc >= 1 then -- [FIX] cek tiap 1 detik (sebelumnya 3)
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

sectionLabel(teleportPage, 6, "Waypoint")

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

-- ---------- Pop-up "Keybind sudah dipakai" (satu local saja, supaya batas local level atas aman) ----------
local keyConflictUI: any = {
	open = false,
	titles = {},
	order = { "toggleKey", "saveKey", "tpKey", "cycleKey", "floatUpKey", "floatDownKey", "followKey", "autoCutKey", "recordMiniKey" },
}
do
	local ui = keyConflictUI
	local overlay = new("TextButton", {
		Name = "KeyConflict",
		-- tanpa latar gelap: area ini hanya seukuran kartu (transparan) supaya klik tidak tembus ke belakang pop-up
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 176),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = "",
		AutoButtonColor = false,
		Visible = false,
		ZIndex = 40,
	}, gui)

	local card = new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(300, 176),
		BackgroundColor3 = T.bg,
		BorderSizePixel = 0,
	}, overlay)
	round(card, 14)
	grad(stroke(card, WHITE, 1.5, 0.1), T.accent, T.accent2, 45)

	local icon = new("Frame", {
		Position = UDim2.fromOffset(16, 16),
		Size = UDim2.fromOffset(30, 30),
		BackgroundColor3 = T.danger,
		BorderSizePixel = 0,
	}, card)
	round(icon, 15)
	text(icon, {
		Size = UDim2.fromScale(1, 1),
		Text = "!",
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextXAlignment = Enum.TextXAlignment.Center,
	})
	text(card, {
		Text = "Keybind sudah dipakai",
		Font = Enum.Font.GothamBold,
		TextSize = 15,
		Position = UDim2.fromOffset(56, 16),
		Size = UDim2.new(1, -72, 0, 30),
	})
	local msg = text(card, {
		RichText = true,
		TextWrapped = true,
		TextSize = 12,
		TextColor3 = T.sub,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(16, 56),
		Size = UDim2.new(1, -32, 0, 56),
	})

	local retryInfo: any = nil

	local function makeBtn(label: string, x: number, w: number, bg: Color3)
		local b = new("TextButton", {
			Position = UDim2.new(0, x, 1, -16),
			AnchorPoint = Vector2.new(0, 1),
			Size = UDim2.new(0, w, 0, 32),
			BackgroundColor3 = bg,
			Text = label,
			TextColor3 = T.text,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			AutoButtonColor = false,
		}, card)
		round(b, 8)
		hover(b, bg)
		return b
	end
	local retryBtn = makeBtn("Pilih Tombol Lain", 16, 150, T.accent)
	local closeBtn = makeBtn("Tutup", 174, 110, T.card2)

	ui.close = function()
		overlay.Visible = false
		ui.open = false
	end

	retryBtn.MouseButton1Click:Connect(function()
		ui.close()
		if retryInfo then
			listening = { name = retryInfo.name, allowClear = retryInfo.allowClear }
			refreshKeyUI()
		end
	end)
	closeBtn.MouseButton1Click:Connect(function() ui.close() end)

	-- cari fungsi lain yang sudah memakai tombol ini
	ui.find = function(name: string, kc: Enum.KeyCode): string?
		for _, n in ipairs(ui.order) do
			if n ~= name and settings[n] == kc then return n end
		end
		return nil
	end

	ui.show = function(kc: Enum.KeyCode, owner: string, info: any)
		retryInfo = info
		msg.Text = "<b>[" .. kc.Name .. "]</b> sudah dipakai oleh <b>" .. tostring(ui.titles[owner] or owner)
			.. "</b>.\nSatu tombol hanya boleh untuk satu fungsi. Pilih tombol lain, atau kosongkan dulu yang lama."
		ui.open = true
		overlay.Visible = true
		card.Size = UDim2.fromOffset(280, 164)
		tween(card, { Size = UDim2.fromOffset(300, 176) }, 0.15)
		-- kedipkan tombol pemilik keybind
		local ob = keyButtons[owner]
		if ob then
			ob.BackgroundColor3 = T.danger
			tween(ob, { BackgroundColor3 = T.bg }, 0.7)
		end
	end

	-- dipakai saat memuat setelan tersimpan: kalau ada tombol ganda, yang belakangan dikosongkan
	ui.dedupe = function(): boolean
		local seen: { [any]: boolean } = {}
		local cleared = false
		for _, n in ipairs(ui.order) do
			local kc = settings[n]
			if kc then
				if seen[kc] then
					settings[n] = nil
					cleared = true
				else
					seen[kc] = true
				end
			end
		end
		return cleared
	end
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
	keyConflictUI.titles[name] = title
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
addKeyRow(7, "Follow: Mulai / Stop", "Mulai ikuti (target terakhir / nama di kotak / teman terdekat) atau berhenti. Backspace untuk mengosongkan.", "followKey", true)
if settings.miniGameOk then
	addKeyRow(8, "Auto Cut: ON / OFF", "Nyalakan atau matikan Auto Cut (Mini Game). Belum diatur = kosong. Backspace untuk mengosongkan.", "autoCutKey", true)
end
addKeyRow(9, "Rekam Minigame: ON / OFF", "Mulai atau hentikan perekaman minigame. Bisa diganti sesuai tombol pilihanmu.", "recordMiniKey", true)
refreshKeyUI()

local sizeCard = makeCard(settingsPage, 78, 9)
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

-- Anti-AFK (aktif sejak awal; sebelumnya di tab Visual)
sectionLabel(settingsPage, 200, "Utilitas")
addToggleCard(settingsPage, 201, "Anti-AFK", "Mencegah kick karena diam 20 menit. Aktif sejak awal.", "antiAfk")
switches.antiAfk.Set(true)

local offAllBtn = makeButton(settingsPage, 300, "Matikan Semua Fitur", T.accent, 40)
hover(offAllBtn, T.accent)
offAllBtn.MouseButton1Click:Connect(function()
	disableAllFeatures()
end)

local unloadBtn = makeButton(settingsPage, 301, "Unload & Bersihkan Semua", T.off, 40)
text(settingsPage, {
	LayoutOrder = 302,
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
local KEY_NAMES = { "toggleKey", "saveKey", "tpKey", "cycleKey", "floatUpKey", "floatDownKey", "followKey", "autoCutKey", "recordMiniKey" }

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
		if keyConflictUI.dedupe() then
			toast("Ada keybind ganda, yang bentrok dikosongkan")
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

sectionLabel(settingsPage, 20, "Config")
local cfgTop = makeCard(configPage, 168, 21)
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
	LayoutOrder = 22,
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
		LayoutOrder = 30 + i,
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
-- GUI: HALAMAN MINI GAME (Auto Cut + Auto Minigame)
-- Dibungkus fungsi sendiri supaya local-nya TIDAK menghabiskan jatah 200 local script utama.
-- Membaca MainUI.Harvest.Bar (Marker + Zone.Perfect), lalu meniru tombol Space saat marker
-- diperkirakan tepat di tengah zona Perfect. Tidak memanggil remote, tidak mengubah data game.
-- Nilai LEAD (ms) = state values.cutLead -> ikut tersimpan di settings.json & slot Config.
-- =====================================================
do
	local function buildMiniGame()
		local VIM: any = nil
		pcall(function() VIM = game:GetService("VirtualInputManager") end)

		-- singkirkan Auto Cut versi mandiri lama (kalau masih jalan) supaya tidak menekan dobel
		do
			local e = (getgenv and getgenv()) or _G
			if type(e.__R4MEN_CUT_UNLOAD) == "function" then pcall(e.__R4MEN_CUT_UNLOAD) end
			e.__R4MEN_CUT_UNLOAD = nil
			local oldGui = playerGui:FindFirstChild("R4MEN_AutoCut")
			if oldGui then oldGui:Destroy() end
		end

		local LEAD_MAX = 25 -- ms. Batas atas penyesuaian (0.025 dtk). Ubah angka ini kalau mau lebih besar.
		local C: any = {
			MARGIN = 0.15,      -- marker harus di dalam zona Perfect (dikurangi 15% tiap sisi)
			HIST_WINDOW = 0.12, -- detik riwayat untuk hitung kecepatan
			DEBOUNCE = 0.9,     -- jeda minimal antar tekanan pada zona yang SAMA
			MIN_GAP = 0.15,     -- jeda minimal bila zona sudah pindah (potongan berikutnya)
			STABLE_FOR = 0.2,   -- bar harus stabil segini lama sebelum menekan
			HOLD = 0.03,        -- lama Space ditahan
			FAST_SETTLE = 0.03, -- jalur tekan langsung: zona cukup diam segini lama (2 frame) sebelum ditekan
			FAST_GAP = 0.06,    -- jalur tekan langsung: jeda minimal setelah tekanan sebelumnya
			presses = 0, lastErr = nil, lastPress = 0,
			lastBarW = 0, barChangedAt = 0, lastUi = 0,
			lastCx = nil, zoneX = -1e9, zoneChangedAt = 0, pressZoneX = -1e9,
			hist = {}, cache = {}, msg = "Menunggu minigame...",
		}

		local function shown(inst: Instance): boolean
			local cur: Instance? = inst
			while cur and cur ~= playerGui do
				if cur:IsA("GuiObject") and not cur.Visible then return false end
				if cur:IsA("ScreenGui") and not cur.Enabled then return false end
				cur = cur.Parent
			end
			return cur == playerGui
		end

		local function findPath(path: string): any
			local c = C.cache[path]
			if c and c.Parent then return c end
			local cur: any = playerGui
			for part in string.gmatch(path, "[^%.]+") do
				cur = cur and cur:FindFirstChild(part)
			end
			C.cache[path] = cur
			return cur
		end

		local function pressSpace()
			local ok = false
			if VIM then
				ok = pcall(function()
					VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
					task.wait(C.HOLD)
					VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
				end)
			end
			if not ok and keypress and keyrelease then
				pcall(keypress, 0x20)
				task.wait(C.HOLD)
				pcall(keyrelease, 0x20)
			end
		end

		-- ---------- halaman (satu kartu ringkas: toggle + LEAD + status) ----------
		local page = pages["Mini Game"]

		local card = makeCard(page, 112, 2)
		text(card, {
			Text = "Auto Cut (Jamur)",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			Position = UDim2.fromOffset(14, 10),
			Size = UDim2.new(1, -84, 0, 18),
		})
		text(card, {
			Text = "Space otomatis di zona Perfect. Telat: +, cepat: -",
			TextSize = 11,
			TextColor3 = T.sub,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(14, 30),
			Size = UDim2.new(1, -84, 0, 14),
		})
		switches.autoCut = makeSwitch(card, UDim2.new(1, -14, 0, 25), false, function(on)
			state.autoCut = on
			effects.autoCut(on)
			refreshActive()
		end, cardGlow(card))

		local minus = makeButton(card, 0, "-", T.off, 26)
		minus.Size = UDim2.fromOffset(34, 26)
		minus.Position = UDim2.fromOffset(14, 52)
		hover(minus, T.off)

		local plus = makeButton(card, 0, "+", T.off, 26)
		plus.AnchorPoint = Vector2.new(1, 0)
		plus.Size = UDim2.fromOffset(34, 26)
		plus.Position = UDim2.new(1, -14, 0, 52)
		hover(plus, T.off)

		local box = new("TextBox", {
			Position = UDim2.fromOffset(54, 52),
			Size = UDim2.new(1, -108, 0, 26),
			BackgroundColor3 = T.bg,
			TextColor3 = T.text,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			ClearTextOnFocus = false,
			BorderSizePixel = 0,
			Text = "",
		}, card)
		round(box, 8)
		stroke(box, T.stroke, 1, 0.3)

		local function setLead(ms: number)
			ms = math.clamp(math.floor(ms * 10 + 0.5) / 10, 0, LEAD_MAX)
			values.cutLead = ms
			box.Text = string.format("LEAD  %.3f dtk", ms / 1000)
		end
		sliderSetters.cutLead = setLead -- supaya ikut dimuat dari settings.json / slot Config
		setLead(values.cutLead)

		minus.MouseButton1Click:Connect(function() setLead(values.cutLead - 1) end)
		plus.MouseButton1Click:Connect(function() setLead(values.cutLead + 1) end)
		box.FocusLost:Connect(function()
			local raw = string.gsub(box.Text, ",", ".")
			local n = tonumber(string.match(raw, "%d+%.?%d*") or "")
			if n then
				setLead(n * 1000) -- ketik dalam detik, mis. 0.005 atau 0,005
			else
				setLead(values.cutLead)
			end
		end)
		box.Focused:Connect(function()
			box.Text = string.format("%.3f", values.cutLead / 1000)
		end)

		local sLbl = text(card, {
			Text = C.msg,
			TextSize = 10,
			TextColor3 = T.sub,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(14, 88),
			Size = UDim2.new(1, -28, 0, 14),
		})

		-- ---------- efek toggle ----------
		effects.autoCut = function(on: boolean)
			table.clear(C.hist)
			C.lastBarW = 0
			C.msg = on and "Aktif. Tekan E di jamur." or "Dimatikan."
			sLbl.Text = C.msg
		end

		-- ---------- logika (satu koneksi, ikut dibersihkan oleh unload lewat track) ----------
		track(RunService.RenderStepped:Connect(function()
			if unloaded then return end
			local hist = C.hist
			local now = os.clock()

			if not state.autoCut then
				if #hist > 0 then table.clear(hist) end
				return
			end

			local bar = findPath("MainUI.Harvest.Bar")
			local marker = findPath("MainUI.Harvest.Bar.Marker")
			local target = findPath("MainUI.Harvest.Bar.Zone.Perfect")
			if not (bar and marker and target) or not shown(marker) then
				table.clear(hist)
				if now - C.lastUi > 0.25 then
					C.lastUi = now
					sLbl.Text = "Menunggu minigame... | tekan: " .. C.presses
				end
				return
			end

			-- tunggu animasi muncul selesai (lebar bar berhenti berubah)
			local bw = bar.AbsoluteSize.X
			if math.abs(bw - C.lastBarW) > 0.5 then
				C.lastBarW, C.barChangedAt = bw, now
				table.clear(hist)
				return
			end
			if now - C.barChangedAt < C.STABLE_FOR then return end

			local cx = marker.AbsolutePosition.X + marker.AbsoluteSize.X / 2
			-- marker melompat jauh dalam 1 frame (reset setelah potongan): buang riwayat lama
			if C.lastCx and math.abs(cx - C.lastCx) > bw * 0.3 then table.clear(hist) end
			C.lastCx = cx
			hist[#hist + 1] = { now, cx }
			while #hist > 0 and now - hist[1][1] > C.HIST_WINDOW do table.remove(hist, 1) end
			-- riwayat belum cukup (mis. marker baru melompat): jalur "tekan langsung" di bawah tetap boleh jalan,
			-- jalur prediksi (butuh kecepatan) otomatis nonaktif karena vel = 0
			local first = hist[1]
			local dt = now - first[1]
			local vel = (#hist >= 3 and dt > 0) and (cx - first[2]) / dt or 0

			local pw = target.AbsoluteSize.X
			if pw < 6 then return end
			local pl = target.AbsolutePosition.X + pw * C.MARGIN
			local pr = target.AbsolutePosition.X + pw * (1 - C.MARGIN)
			local center = target.AbsolutePosition.X + pw / 2

			local lead = (values.cutLead or 5) / 1000

			-- zona Perfect pindah = potongan berikutnya; tunggu zona diam sebentar sebelum menekan
			local zx = target.AbsolutePosition.X
			if math.abs(zx - C.zoneX) > 0.5 then C.zoneX, C.zoneChangedAt = zx, now end
			local zoneSettled = now - C.zoneChangedAt > 0.08
			-- [FIX] zona dianggap "sudah pindah" (= potongan baru) walau hanya bergeser sedikit (>0.5 px) atau
			-- ukurannya berubah. Dulu ambangnya 3 px: geseran kecil tidak dikenali, sehingga harus menunggu
			-- DEBOUNCE 0.9 dtk (melewatkan satu putaran marker) baru bisa perfect lagi.
			local zoneMoved = math.abs(zx - C.pressZoneX) > 0.2 or math.abs(pw - (C.pressZoneW or pw)) > 0.2

			-- [FIX] sinyal kedua yang TIDAK bergantung pada zona: setelah menekan, begitu marker menjauh dari
			-- titik tekan (lebih dari 1x lebar zona Perfect) lalu kembali, itu pasti putaran/potongan baru,
			-- jadi boleh ditekan lagi walau zona tidak bergeser sama sekali.
			if C.pressCenter and not C.left and math.abs(cx - C.pressCenter) > math.max(pw, 10) then
				C.left = true
			end
			local rearmed = zoneMoved or C.left == true

			-- waktu sampai marker tiba di TENGAH Perfect (negatif = sudah lewat / menjauh)
			local tta = math.huge
			if math.abs(vel) > 5 then tta = (center - cx) / vel end

			if now - C.lastUi > 0.1 then
				C.lastUi = now
				local errTxt = "-"
				if C.lastErr then
					errTxt = string.format("%+.1f px (%s)", C.lastErr, C.lastErr > 0 and "telat" or "cepat")
				end
				sLbl.Text = string.format("marker %.0f/%.0f | tekan: %d | selisih: %s",
					cx, center, C.presses, errTxt)
			end

			local frame = 1 / 60

			-- [FIX] JALUR "TEKAN LANGSUNG": zona Perfect baru saja pindah/bergeser (potongan baru) dan marker
			-- SEDANG berada di dalam zona -> tekan sekarang juga, tanpa menunggu marker memutar satu putaran.
			-- Satu zona hanya ditekan sekali (pressZoneX dicatat), jadi tidak bisa dobel.
			if zoneMoved and cx >= pl and cx <= pr
				and now - C.zoneChangedAt > C.FAST_SETTLE
				and now - C.lastPress > C.FAST_GAP then
				C.lastPress = now
				C.pressZoneX = zx
				C.pressZoneW = pw
				C.pressCenter = center
				C.left = false
				C.lastErr = (cx - center) * (vel >= 0 and 1 or -1)
				C.presses += 1
				task.spawn(pressSpace)
				return
			end

			if tta >= math.min(-frame, lead - frame) and tta <= lead + frame * 0.5
				and cx >= pl - math.abs(vel) * lead and cx <= pr + math.abs(vel) * lead
				and zoneSettled
				and (now - C.lastPress > C.DEBOUNCE or (rearmed and now - C.lastPress > C.MIN_GAP)) then
				C.lastPress = now
				C.pressZoneX = zx
				C.pressZoneW = pw
				C.pressCenter = center
				C.left = false
				-- positif = terlambat (lewat tengah searah gerak), negatif = terlalu cepat
				C.lastErr = (cx - center) * (vel >= 0 and 1 or -1)
				C.presses += 1
				task.spawn(pressSpace)
			end
		end))
	end
	local function buildUniversalAuto()
		local VIM: any = nil
		pcall(function() VIM = game:GetService("VirtualInputManager") end)

		local A: any = {
			pins = {}, halfWidth = 22, lastAngle = nil, lastT = 0,
			speed = 0, direction = 0, lastAttempt = {},
			lastUi = 0, wasActive = false, remoteReady = false,
			msg = "Memindai minigame...",
		}

		local page = pages["Mini Game"]
		local card = makeCard(page, 112, 1)
		text(card, {
			Text = "Auto Minigame",
			Font = Enum.Font.GothamBold,
			TextSize = 14,
			Position = UDim2.fromOffset(14, 9),
			Size = UDim2.new(1, -82, 0, 20),
		})
		text(card, {
			Text = "Deteksi jenis minigame otomatis • Lockpick dan Safe Dial.",
			TextSize = 11,
			TextColor3 = T.sub,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(14, 32),
			Size = UDim2.new(1, -28, 0, 28),
		})
		local sLbl = text(card, {
			Text = A.msg,
			TextSize = 10,
			TextColor3 = T.sub,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			Position = UDim2.fromOffset(14, 68),
			Size = UDim2.new(1, -28, 0, 32),
		})

		local function setStatus(s: string)
			A.msg = s
			if not unloaded and sLbl.Parent then sLbl.Text = s end
		end

		local function captureLockpick(value: any, depth: number): any
			if type(value) ~= "table" or depth > 4 then return nil end
			if value.kind == "Lockpick" and type(value.puzzle) == "table" then
				return value
			end
			for _, child in pairs(value) do
				if type(child) == "table" then
					local found = captureLockpick(child, depth + 1)
					if found then return found end
				end
			end
			return nil
		end

		local function acceptStart(...)
			local payload = nil
			for i = 1, select("#", ...) do
				payload = captureLockpick(select(i, ...), 0)
				if payload then break end
			end
			if not payload then return end

			local puzzle = payload.puzzle
			local pins = puzzle and puzzle.pins
			if type(pins) ~= "table" then return end
			local parsed = {}
			for key, pin in pairs(pins) do
				local index = tonumber(key)
				if type(pin) == "table" and index
					and type(pin.sweet) == "number"
					and type(pin.speed) == "number"
					and type(pin.dir) == "number" then
					parsed[#parsed + 1] = {
						index = index,
						sweet = pin.sweet % 360,
						speed = math.abs(pin.speed),
						dir = pin.dir >= 0 and 1 or -1,
					}
				end
			end
			table.sort(parsed, function(a, b) return a.index < b.index end)
			if #parsed == 0 then return end

			A.pins = parsed
			A.halfWidth = math.clamp(tonumber(puzzle.halfWidth) or 22, 1, 90)
			A.lastAngle, A.lastT = nil, 0
			A.speed, A.direction = 0, 0
			table.clear(A.lastAttempt)
			setStatus(string.format("Lockpick terbaca: %d pin • target siap", #parsed))
		end

		local function hookStartRemote(inst: Instance)
			if A.remoteReady or not inst:IsA("RemoteEvent") or inst.Name ~= "MinigameStart" then return end
			A.remoteReady = true
			track(inst.OnClientEvent:Connect(function(...)
				acceptStart(...)
			end))
			setStatus("Detektor siap • menunggu Lockpick / Safe Dial")
		end

		local existingRemote = ReplicatedStorage:FindFirstChild("MinigameStart", true)
		if existingRemote then hookStartRemote(existingRemote) end
		track(ReplicatedStorage.DescendantAdded:Connect(function(inst)
			if inst.Name == "MinigameStart" then hookStartRemote(inst) end
		end))

		local function isVisible(inst: Instance): boolean
			local cur: Instance? = inst
			while cur and cur ~= playerGui do
				if cur:IsA("GuiObject") and not cur.Visible then return false end
				if cur:IsA("ScreenGui") and not cur.Enabled then return false end
				cur = cur.Parent
			end
			return cur == playerGui
		end

		local function sendSpace()
			local down = false
			if VIM then
				down = pcall(function()
					VIM:SendKeyEvent(true, Enum.KeyCode.Space, false, game)
				end)
			end
			if not down and keypress and keyrelease then pcall(keypress, 0x20) end
			task.wait(0.10)
			if VIM and down then
				pcall(function() VIM:SendKeyEvent(false, Enum.KeyCode.Space, false, game) end)
			elseif not down and keyrelease then
				pcall(keyrelease, 0x20)
			end
		end

		switches.autoMinigame = makeSwitch(card, UDim2.new(1, -14, 0, 25), false, function(on)
			state.autoMinigame = on
			A.lastAngle, A.lastT = nil, 0
			if on then
				setStatus(#A.pins > 0 and "Aktif • modul Lockpick siap" or "Aktif • memindai Lockpick / Safe Dial")
				toast("Auto Minigame: ON")
			else
				setStatus("Dimatikan.")
				toast("Auto Minigame: OFF")
			end
			refreshActive()
		end, cardGlow(card))

		track(RunService.RenderStepped:Connect(function()
			if unloaded or not state.autoMinigame then return end
			local gui = playerGui:FindFirstChild("MinigameGui")
			-- Fallback lintas game: cari ScreenGui lain yang bernama minigame/puzzle
			-- atau memiliki node Lockpick/SafeDial di dalam hierarkinya.
			if not gui then
				for _, candidate in ipairs(playerGui:GetChildren()) do
					if candidate:IsA("ScreenGui") then
						local lowerName = string.lower(candidate.Name)
						if string.find(lowerName, "minigame", 1, true)
							or string.find(lowerName, "puzzle", 1, true)
						or candidate:FindFirstChild("Lockpick", true)
						or candidate:FindFirstChild("SafeDial", true) then
							gui = candidate
							break
						end
					end
				end
			end
			local lockpick = gui and gui:FindFirstChild("Lockpick", true)
			local lock = lockpick and lockpick:FindFirstChild("Lock", true)
			local pick = lock and lock:FindFirstChild("Pick", true)
			local pickImage = pick and pick:FindFirstChild("lockpick_pick", true)
			local safeDial = gui and gui:FindFirstChild("SafeDial", true)

			if not (gui and isVisible(gui)) then
				if A.wasActive then setStatus("Minigame ditutup • menunggu sesi berikutnya") end
				A.wasActive = false
				A.lastAngle, A.lastT, A.speed, A.direction = nil, 0, 0, 0
				return
			end
			A.wasActive = true

			-- Klasifikasi visual berdasar struktur UI. Safe Dial berbeda dari Lockpick:
			-- rekaman menunjukkan Rotor.Number + ContactPulse + panel Readout.
			-- Belum ada bukti cukup untuk menebak kombinasi/arah/jeda tombol yang benar,
			-- jadi modul hanya mengenali dan melaporkan Safe Dial, bukan menekan A/D secara acak.
			if safeDial and isVisible(safeDial) then
				local dial = safeDial:FindFirstChild("Dial")
				local rotor = dial and dial:FindFirstChild("Rotor")
				local number = rotor and rotor:FindFirstChild("Number")
				local pulse = dial and dial:FindFirstChild("ContactPulse")
				local panel = safeDial:FindFirstChild("Panel")
				local readoutRow = panel and panel:FindFirstChild("ReadoutRow")
				local readout = readoutRow and readoutRow:FindFirstChild("Readout")
				if number and pulse and readout and readout:IsA("TextLabel") then
					local txt = tostring(readout.Text or "Safe Dial")
					if os.clock() - A.lastUi > 0.35 then
						A.lastUi = os.clock()
						setStatus("Safe Dial terdeteksi • " .. txt .. " • pola auto belum tervalidasi")
					end
				else
					if os.clock() - A.lastUi > 0.35 then
						A.lastUi = os.clock()
						setStatus("Safe Dial terdeteksi • menunggu struktur rotor lengkap")
					end
				end
				return
			end

			if not (pick and pickImage) then
				if os.clock() - A.lastUi > 0.35 then
					A.lastUi = os.clock()
					setStatus("Minigame terdeteksi • jenis belum didukung")
				end
				return
			end

			if #A.pins == 0 then
				if os.clock() - A.lastUi > 0.2 then
					A.lastUi = os.clock()
					setStatus("Lockpick terdeteksi • menunggu data MinigameStart")
				end
				return
			end

			local now = os.clock()
			-- Sudut needle = rotasi Frame Pick + offset rotasi ImageLabel lockpick_pick.
			local angle = (pick.Rotation + pickImage.Rotation) % 360
			if A.lastAngle ~= nil and A.lastT > 0 then
				local dt = now - A.lastT
				if dt > 0 and dt < 0.25 then
					local delta = angle - A.lastAngle
					if delta > 180 then delta -= 360 end
					if delta < -180 then delta += 360 end
					local velocity = delta / dt
					if math.abs(velocity) > 35 then
						local measured = math.abs(velocity)
						A.speed = A.speed == 0 and measured or (A.speed * 0.55 + measured * 0.45)
						A.direction = velocity >= 0 and 1 or -1
					end
				end
			end
			A.lastAngle, A.lastT = angle, now

			if A.speed < 35 or A.direction == 0 then
				if now - A.lastUi > 0.15 then
					A.lastUi = now
					setStatus("Lockpick aktif • membaca arah dan kecepatan...")
				end
				return
			end

			-- Pilih pin dari kombinasi speed + direction yang sedang terbaca.
			local activePin, bestDiff = nil, math.huge
			for _, pin in ipairs(A.pins) do
				if pin.dir == A.direction then
					local diff = math.abs(A.speed - pin.speed)
					if diff < bestDiff then activePin, bestDiff = pin, diff end
				end
			end
			if not activePin or bestDiff > math.max(38, activePin.speed * 0.25) then
				if now - A.lastUi > 0.15 then
					A.lastUi = now
					setStatus(string.format("Membaca gerakan pick • %.0f°/dtk", A.speed))
				end
				return
			end

			local signedDiff = (activePin.sweet - angle + 540) % 360 - 180
			local gate = math.min(A.halfWidth * 0.5, 10)
			if now - A.lastUi > 0.10 then
				A.lastUi = now
				setStatus(string.format("Pin %d/%d • sudut %.1f° • target %.1f° • selisih %+.1f°",
					activePin.index, #A.pins, angle, activePin.sweet, signedDiff))
			end

			-- Satu percobaan per lintasan; bila gagal, boleh mencoba lagi pada putaran berikutnya.
			local lastTry = A.lastAttempt[activePin.index] or 0
			if math.abs(signedDiff) <= gate and now - lastTry > 1.5 then
				A.lastAttempt[activePin.index] = now
				task.spawn(sendSpace)
				setStatus(string.format("Pin %d • Space dikirim pada sweet window", activePin.index))
			end
		end))
	end

	-- Auto Minigame (Lockpick / Safe Dial) hanya dibuat di game yang GameId-nya ada di
	-- settings.autoMiniGameIds. Di game lain kartunya tidak ada (Rekam Minigame tetap ada).
	if settings.autoMiniOk then
		sectionLabel(pages["Mini Game"], 0, "Auto Mini Game")
		buildUniversalAuto()
	end
	if settings.miniGameOk then
		buildMiniGame()
	end
end

-- =====================================================
-- GUI: CATUR (Mini Game)
--  * Tanpa jendela: script membaca papan in-game PlayerGui["2DBoard"].Main (Board = kotak a1..h8,
--    Pieces = bidak "White_Pawn", "Black_Knight", dst). Kotak & bidak dicocokkan lewat posisi layar.
--  * Mesin: aturan lengkap + AI minimax alpha-beta di makeEngine() (murni, tanpa API Roblox).
--  * Langkah musuh = kotak oranye; SARAN balasanmu = kotak + panah hijau di atas papan game;
--    bidakmu yang terancam = titik merah. Sisi milikmu = sisi yang rajanya di bawah layar.
-- Dibungkus do ... end + fungsi supaya tidak menghabiskan jatah 200 local script utama.
-- =====================================================
do
local function makeEngine()
	local CH = {}
	local abs = math.abs
	local tclone = table.clone or function(t)
		local n = {}
		for i = 1, #t do n[i] = t[i] end
		return n
	end
	local wait = (task and task.wait) or function() end

	-- Kode bidak: 1 Pion, 2 Kuda, 3 Gajah, 4 Benteng, 5 Menteri, 6 Raja. Putih positif, hitam negatif.
	-- Kotak 1..64: sq = rank*8 + file + 1 (a1 = 1, h1 = 8, a8 = 57, h8 = 64).
	local VAL = { 100, 320, 330, 500, 900, 0 }
	CH.NAMES = { "Pion", "Kuda", "Gajah", "Benteng", "Menteri", "Raja" }
	local INF, MATE = 1000000, 100000
	CH.MATE = MATE

	local FILE, RANK = {}, {}
	for s = 1, 64 do
		FILE[s] = (s - 1) % 8
		RANK[s] = (s - 1) // 8
	end
	CH.FILE, CH.RANK = FILE, RANK

	local function build(dirs, slide)
		local out = {}
		for s = 1, 64 do
			local lists = {}
			for _, d in ipairs(dirs) do
				local ray = {}
				local nf, nr = FILE[s] + d[1], RANK[s] + d[2]
				while nf >= 0 and nf <= 7 and nr >= 0 and nr <= 7 do
					ray[#ray + 1] = nr * 8 + nf + 1
					if not slide then break end
					nf, nr = nf + d[1], nr + d[2]
				end
				if #ray > 0 then lists[#lists + 1] = ray end
			end
			out[s] = lists
		end
		return out
	end
	local KNR = build({ { 1, 2 }, { 2, 1 }, { 2, -1 }, { 1, -2 }, { -1, -2 }, { -2, -1 }, { -2, 1 }, { -1, 2 } }, false)
	local KGR = build({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }, false)
	local BR = build({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }, true)
	local RR = build({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }, true)

	-- Tabel nilai posisi (sudut pandang putih, baris pertama = rank 8)
	local PST = {
		{ 0, 0, 0, 0, 0, 0, 0, 0, 50, 50, 50, 50, 50, 50, 50, 50, 10, 10, 20, 30, 30, 20, 10, 10, 5, 5, 10, 25, 25, 10, 5, 5,
			0, 0, 0, 20, 20, 0, 0, 0, 5, -5, -10, 0, 0, -10, -5, 5, 5, 10, 10, -20, -20, 10, 10, 5, 0, 0, 0, 0, 0, 0, 0, 0 },
		{ -50, -40, -30, -30, -30, -30, -40, -50, -40, -20, 0, 0, 0, 0, -20, -40, -30, 0, 10, 15, 15, 10, 0, -30, -30, 5, 15, 20, 20, 15, 5, -30,
			-30, 0, 15, 20, 20, 15, 0, -30, -30, 5, 10, 15, 15, 10, 5, -30, -40, -20, 0, 5, 5, 0, -20, -40, -50, -40, -30, -30, -30, -30, -40, -50 },
		{ -20, -10, -10, -10, -10, -10, -10, -20, -10, 0, 0, 0, 0, 0, 0, -10, -10, 0, 5, 10, 10, 5, 0, -10, -10, 5, 5, 10, 10, 5, 5, -10,
			-10, 0, 10, 10, 10, 10, 0, -10, -10, 10, 10, 10, 10, 10, 10, -10, -10, 5, 0, 0, 0, 0, 5, -10, -20, -10, -10, -10, -10, -10, -10, -20 },
		{ 0, 0, 0, 0, 0, 0, 0, 0, 5, 10, 10, 10, 10, 10, 10, 5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5,
			-5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, -5, 0, 0, 0, 0, 0, 0, -5, 0, 0, 0, 5, 5, 0, 0, 0 },
		{ -20, -10, -10, -5, -5, -10, -10, -20, -10, 0, 0, 0, 0, 0, 0, -10, -10, 0, 5, 5, 5, 5, 0, -10, -5, 0, 5, 5, 5, 5, 0, -5,
			0, 0, 5, 5, 5, 5, 0, -5, -10, 5, 5, 5, 5, 5, 0, -10, -10, 0, 5, 0, 0, 0, 0, -10, -20, -10, -10, -5, -5, -10, -10, -20 },
		{ -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30, -30, -40, -40, -50, -50, -40, -40, -30,
			-20, -30, -30, -40, -40, -30, -30, -20, -10, -20, -20, -20, -20, -20, -20, -10, 20, 20, 0, 0, 0, 0, 20, 20, 20, 30, 10, 0, 0, 10, 30, 20 },
	}
	local KEG = { -50, -40, -30, -20, -20, -30, -40, -50, -30, -20, -10, 0, 0, -10, -20, -30, -30, -10, 20, 30, 30, 20, -10, -30, -30, -10, 30, 40, 40, 30, -10, -30,
		-30, -10, 30, 40, 40, 30, -10, -30, -30, -10, 20, 30, 30, 20, -10, -30, -30, -30, 0, 0, 0, 0, -30, -30, -50, -30, -30, -30, -30, -30, -30, -50 }

	-- Hak rokade: 1 = putih sisi raja, 2 = putih sisi menteri, 4 = hitam sisi raja, 8 = hitam sisi menteri
	local CLRBITS = { [1] = { 2 }, [5] = { 1, 2 }, [8] = { 1 }, [57] = { 8 }, [61] = { 4, 8 }, [64] = { 4 } }
	local function hasBit(r, m) return (r // m) % 2 == 1 end
	local function clearRights(r, s)
		local l = CLRBITS[s]
		if l then
			for i = 1, #l do
				local m = l[i]
				if (r // m) % 2 == 1 then r = r - m end
			end
		end
		return r
	end

	-- Apakah kotak s diserang oleh warna `by`?
	local function attacked(b, s, by)
		local f, r = FILE[s], RANK[s]
		local pr = r - by
		if pr >= 0 and pr <= 7 then
			if f > 0 and b[pr * 8 + f] == by then return true end
			if f < 7 and b[pr * 8 + f + 2] == by then return true end
		end
		local n, k, bi, ro, q = 2 * by, 6 * by, 3 * by, 4 * by, 5 * by
		local rays = KNR[s]
		for i = 1, #rays do
			if b[rays[i][1]] == n then return true end
		end
		rays = KGR[s]
		for i = 1, #rays do
			if b[rays[i][1]] == k then return true end
		end
		rays = BR[s]
		for i = 1, #rays do
			local ray = rays[i]
			for j = 1, #ray do
				local p = b[ray[j]]
				if p ~= 0 then
					if p == bi or p == q then return true end
					break
				end
			end
		end
		rays = RR[s]
		for i = 1, #rays do
			local ray = rays[i]
			for j = 1, #ray do
				local p = b[ray[j]]
				if p ~= 0 then
					if p == ro or p == q then return true end
					break
				end
			end
		end
		return false
	end
	CH.attacked = attacked

	-- Nilai bidak penyerang TERENDAH yang menyerang kotak s (nil bila tidak ada)
	local function lowAtt(b, s, by)
		local best = nil
		local function upd(v)
			if not best or v < best then best = v end
		end
		local f, r = FILE[s], RANK[s]
		local pr = r - by
		if pr >= 0 and pr <= 7 then
			if f > 0 and b[pr * 8 + f] == by then upd(100) end
			if f < 7 and b[pr * 8 + f + 2] == by then upd(100) end
		end
		for _, ray in ipairs(KNR[s]) do
			if b[ray[1]] == 2 * by then upd(320) end
		end
		for _, ray in ipairs(KGR[s]) do
			if b[ray[1]] == 6 * by then upd(20000) end
		end
		for _, ray in ipairs(BR[s]) do
			for j = 1, #ray do
				local p = b[ray[j]]
				if p ~= 0 then
					if p == 3 * by then upd(330) elseif p == 5 * by then upd(900) end
					break
				end
			end
		end
		for _, ray in ipairs(RR[s]) do
			for j = 1, #ray do
				local p = b[ray[j]]
				if p ~= 0 then
					if p == 4 * by then upd(500) elseif p == 5 * by then upd(900) end
					break
				end
			end
		end
		return best
	end

	-- Bidak `color` yang terancam: diserang lawan dan (tidak dilindungi ATAU diserang bidak lebih murah)
	function CH.threatened(pos, color)
		local out = {}
		local b = pos.b
		for s = 1, 64 do
			local pc = b[s]
			if pc ~= 0 and pc * color > 0 and abs(pc) ~= 6 then
				local la = lowAtt(b, s, -color)
				if la then
					local val = VAL[abs(pc)]
					local def = lowAtt(b, s, color)
					if not def or la < val then out[#out + 1] = s end
				end
			end
		end
		return out
	end

	-- Bangkitkan langkah pseudo-legal (belum dicek raja sendiri skak atau tidak)
	local function gen(pos, capsOnly)
		local b, turn = pos.b, pos.turn
		local out, n = {}, 0
		for s = 1, 64 do
			local pc = b[s]
			if pc ~= 0 and pc * turn > 0 then
				local t = pc * turn
				if t == 1 then
					local f, r = FILE[s], RANK[s]
					local nr = r + turn
					local promo = (nr == 7 or nr == 0)
					for df = -1, 1, 2 do
						local nf = f + df
						if nf >= 0 and nf <= 7 then
							local ts = nr * 8 + nf + 1
							local tp = b[ts]
							if tp ~= 0 and tp * turn < 0 then
								if promo then
									for _, pp in ipairs({ 5, 4, 3, 2 }) do
										n = n + 1
										out[n] = { f = s, t = ts, p = pp }
									end
								else
									n = n + 1
									out[n] = { f = s, t = ts }
								end
							elseif tp == 0 and ts == pos.ep then
								n = n + 1
								out[n] = { f = s, t = ts, fl = 2 }
							end
						end
					end
					local ts = nr * 8 + f + 1
					if b[ts] == 0 then
						if promo then
							if capsOnly then
								n = n + 1
								out[n] = { f = s, t = ts, p = 5 }
							else
								for _, pp in ipairs({ 5, 4, 3, 2 }) do
									n = n + 1
									out[n] = { f = s, t = ts, p = pp }
								end
							end
						elseif not capsOnly then
							n = n + 1
							out[n] = { f = s, t = ts }
							local startR = (turn == 1) and 1 or 6
							if r == startR then
								local ts2 = (r + 2 * turn) * 8 + f + 1
								if b[ts2] == 0 then
									n = n + 1
									out[n] = { f = s, t = ts2, fl = 1 }
								end
							end
						end
					end
				elseif t == 2 or t == 6 then
					local rays = (t == 2) and KNR[s] or KGR[s]
					for i = 1, #rays do
						local ts = rays[i][1]
						local tp = b[ts]
						if tp == 0 then
							if not capsOnly then
								n = n + 1
								out[n] = { f = s, t = ts }
							end
						elseif tp * turn < 0 then
							n = n + 1
							out[n] = { f = s, t = ts }
						end
					end
					if t == 6 and not capsOnly then
						local home = (turn == 1) and 5 or 61
						if s == home then
							local kb, qb = (turn == 1) and 1 or 4, (turn == 1) and 2 or 8
							local opp = -turn
							if hasBit(pos.cr, kb) and b[home + 1] == 0 and b[home + 2] == 0 and b[home + 3] == 4 * turn
								and not attacked(b, home, opp) and not attacked(b, home + 1, opp) and not attacked(b, home + 2, opp) then
								n = n + 1
								out[n] = { f = home, t = home + 2, fl = 3 }
							end
							if hasBit(pos.cr, qb) and b[home - 1] == 0 and b[home - 2] == 0 and b[home - 3] == 0 and b[home - 4] == 4 * turn
								and not attacked(b, home, opp) and not attacked(b, home - 1, opp) and not attacked(b, home - 2, opp) then
								n = n + 1
								out[n] = { f = home, t = home - 2, fl = 4 }
							end
						end
					end
				else
					local sets
					if t == 3 then sets = { BR[s] } elseif t == 4 then sets = { RR[s] } else sets = { BR[s], RR[s] } end
					for si = 1, #sets do
						local rays = sets[si]
						for i = 1, #rays do
							local ray = rays[i]
							for j = 1, #ray do
								local ts = ray[j]
								local tp = b[ts]
								if tp == 0 then
									if not capsOnly then
										n = n + 1
										out[n] = { f = s, t = ts }
									end
								else
									if tp * turn < 0 then
										n = n + 1
										out[n] = { f = s, t = ts }
									end
									break
								end
							end
						end
					end
				end
			end
		end
		return out
	end

	local function apply(pos, m)
		local b = tclone(pos.b)
		local turn = pos.turn
		local pc = b[m.f]
		local capture = b[m.t] ~= 0
		b[m.f] = 0
		if m.fl == 2 then
			b[RANK[m.f] * 8 + FILE[m.t] + 1] = 0
			capture = true
		elseif m.fl == 3 then
			b[m.f + 3] = 0
			b[m.f + 1] = 4 * turn
		elseif m.fl == 4 then
			b[m.f - 4] = 0
			b[m.f - 1] = 4 * turn
		end
		if m.p then b[m.t] = m.p * turn else b[m.t] = pc end
		local np = {
			b = b,
			turn = -turn,
			cr = clearRights(clearRights(pos.cr, m.f), m.t),
			ep = (m.fl == 1) and ((m.f + m.t) // 2) or 0,
			hm = (abs(pc) == 1 or capture) and 0 or (pos.hm + 1),
			fm = pos.fm + ((turn == -1) and 1 or 0),
			kw = pos.kw,
			kb = pos.kb,
		}
		if abs(pc) == 6 then
			if turn == 1 then np.kw = m.t else np.kb = m.t end
		end
		return np
	end
	CH.apply = apply

	local function kingSq(pos, color) return (color == 1) and pos.kw or pos.kb end

	-- Daftar langkah legal
	function CH.legal(pos)
		local out = {}
		local ms = gen(pos, false)
		for i = 1, #ms do
			local np = apply(pos, ms[i])
			if not attacked(np.b, kingSq(np, pos.turn), -pos.turn) then out[#out + 1] = ms[i] end
		end
		return out
	end

	function CH.start()
		local b = {}
		for i = 1, 64 do b[i] = 0 end
		local back = { 4, 2, 3, 5, 6, 3, 2, 4 }
		for f = 0, 7 do
			b[f + 1] = back[f + 1]
			b[8 + f + 1] = 1
			b[48 + f + 1] = -1
			b[56 + f + 1] = -back[f + 1]
		end
		return { b = b, turn = 1, cr = 15, ep = 0, hm = 0, fm = 1, kw = 5, kb = 61 }
	end

	function CH.fromFen(fen)
		local parts = {}
		for w in tostring(fen):gmatch("%S+") do parts[#parts + 1] = w end
		if #parts < 2 then return nil end
		local b = {}
		for i = 1, 64 do b[i] = 0 end
		local map = { p = 1, n = 2, b = 3, r = 4, q = 5, k = 6 }
		local r, f = 7, 0
		local kw, kb = 0, 0
		for c in parts[1]:gmatch(".") do
			if c == "/" then
				r = r - 1
				f = 0
			elseif c:match("%d") then
				f = f + tonumber(c)
			else
				local t = map[c:lower()]
				if not t or r < 0 or f > 7 then return nil end
				local color = (c == c:lower()) and -1 or 1
				local s = r * 8 + f + 1
				b[s] = t * color
				if t == 6 then
					if color == 1 then kw = s else kb = s end
				end
				f = f + 1
			end
		end
		if kw == 0 or kb == 0 then return nil end
		local cs = parts[3] or "-"
		local cr = 0
		if cs:find("K") then cr = cr + 1 end
		if cs:find("Q") then cr = cr + 2 end
		if cs:find("k") then cr = cr + 4 end
		if cs:find("q") then cr = cr + 8 end
		local ep = 0
		if parts[4] and parts[4] ~= "-" and #parts[4] >= 2 then
			local ef = parts[4]:byte(1) - 96
			local er = tonumber(parts[4]:sub(2, 2))
			if er and ef >= 1 and ef <= 8 then ep = (er - 1) * 8 + ef end
		end
		return {
			b = b, turn = (parts[2] == "b") and -1 or 1, cr = cr, ep = ep,
			hm = tonumber(parts[5]) or 0, fm = tonumber(parts[6]) or 1, kw = kw, kb = kb,
		}
	end

	local function insufficient(b)
		local minors = 0
		for s = 1, 64 do
			local t = abs(b[s])
			if t == 1 or t == 4 or t == 5 then return false end
			if t == 2 or t == 3 then minors = minors + 1 end
		end
		return minors <= 1
	end

	-- "ok" | "check" | "mate" | "stalemate" | "draw50" | "insufficient"  (+ apakah sedang skak)
	function CH.status(pos)
		local check = attacked(pos.b, kingSq(pos, pos.turn), -pos.turn)
		if #CH.legal(pos) == 0 then return check and "mate" or "stalemate", check end
		if pos.hm >= 100 then return "draw50", check end
		if insufficient(pos.b) then return "insufficient", check end
		return check and "check" or "ok", check
	end

	function CH.key(pos)
		return table.concat(pos.b, ",") .. "|" .. pos.turn .. "|" .. pos.cr .. "|" .. pos.ep
	end

	function CH.sqName(s) return string.char(97 + FILE[s]) .. tostring(RANK[s] + 1) end

	-- Deskripsi langkah, mis. "Kuda g8 ke f6 (tangkap Pion)"
	function CH.describe(pos, m)
		local pc = abs(pos.b[m.f])
		local txt = CH.NAMES[pc] .. " " .. CH.sqName(m.f) .. " ke " .. CH.sqName(m.t)
		if m.fl == 3 then
			txt = "Rokade pendek (Raja " .. CH.sqName(m.f) .. " ke " .. CH.sqName(m.t) .. ")"
		elseif m.fl == 4 then
			txt = "Rokade panjang (Raja " .. CH.sqName(m.f) .. " ke " .. CH.sqName(m.t) .. ")"
		end
		local cap = abs(pos.b[m.t])
		if m.fl == 2 then cap = 1 end
		if cap ~= 0 then txt = txt .. " (tangkap " .. CH.NAMES[cap] .. ")" end
		if m.p then txt = txt .. " jadi " .. CH.NAMES[m.p] end
		return txt
	end

	-- ===== Zobrist hash + tabel transposisi + buku pembukaan =====
	local bxor = bit32.bxor
	local ZP, ZT, ZC, ZE = {}, nil, {}, {}
	do
		local function r16() return math.random(0, 65535) end
		local function r32() return r16() * 65536 + r16() end
		for s = 1, 64 do
			local row = {}
			for k = 1, 12 do row[k] = { r32(), r32() % 2097152 } end
			ZP[s] = row
		end
		ZT = { r32(), r32() % 2097152 }
		for i = 0, 15 do ZC[i] = { r32(), r32() % 2097152 } end
		for i = 0, 64 do ZE[i] = { r32(), r32() % 2097152 } end
	end

	local function hashPos(pos)
		local b = pos.b
		local h1, h2 = 0, 0
		for s = 1, 64 do
			local pc = b[s]
			if pc ~= 0 then
				local z = ZP[s][(pc > 0) and pc or (6 - pc)]
				h1 = bxor(h1, z[1])
				h2 = bxor(h2, z[2])
			end
		end
		if pos.turn == -1 then
			h1 = bxor(h1, ZT[1])
			h2 = bxor(h2, ZT[2])
		end
		local zc = ZC[pos.cr]
		h1 = bxor(h1, zc[1])
		h2 = bxor(h2, zc[2])
		local ze = ZE[pos.ep]
		h1 = bxor(h1, ze[1])
		h2 = bxor(h2, ze[2])
		return h1 + h2 * 4294967296
	end
	CH.hash = hashPos

	local TT, ttN = {}, 0

	-- ===== Evaluasi =====
	local PASSB = { 0, 10, 20, 35, 60, 100, 150, 0 }

	local function centerDist(s)
		local f, r = FILE[s], RANK[s]
		return math.max(3 - f, f - 4) + math.max(3 - r, r - 4)
	end

	local function evaluate(pos)
		local b = pos.b
		local npm = 0
		for s = 1, 64 do
			local t = abs(b[s])
			if t > 1 and t < 6 then npm = npm + VAL[t] end
		end
		local endg = npm <= 2600
		local score = 0
		local wp, bp = { 0, 0, 0, 0, 0, 0, 0, 0 }, { 0, 0, 0, 0, 0, 0, 0, 0 }
		local wmin, bmax = { 8, 8, 8, 8, 8, 8, 8, 8 }, { -1, -1, -1, -1, -1, -1, -1, -1 }
		local pawns, np = {}, 0
		local rooks, nr = {}, 0
		local wB, bB, wMat, bMat = 0, 0, 0, 0
		for s = 1, 64 do
			local pc = b[s]
			if pc ~= 0 then
				local t = abs(pc)
				local f, r = FILE[s], RANK[s]
				local idx = (pc > 0) and ((7 - r) * 8 + f + 1) or (r * 8 + f + 1)
				local tbl = PST[t]
				if t == 6 and endg then tbl = KEG end
				local v = VAL[t] + tbl[idx]
				if t == 1 then
					np = np + 1
					pawns[np] = s
					if pc > 0 then
						wp[f + 1] = wp[f + 1] + 1
						if r < wmin[f + 1] then wmin[f + 1] = r end
					else
						bp[f + 1] = bp[f + 1] + 1
						if r > bmax[f + 1] then bmax[f + 1] = r end
					end
				elseif t == 2 then
					local mob = 0
					local rays = KNR[s]
					for i = 1, #rays do
						local q = b[rays[i][1]]
						if q == 0 or q * pc < 0 then mob = mob + 1 end
					end
					v = v + (mob - 4) * 4
				elseif t == 3 or t == 4 or t == 5 then
					local rays = (t == 4) and RR[s] or BR[s]
					local mob = 0
					for i = 1, #rays do
						local ray = rays[i]
						for j = 1, #ray do
							local q = b[ray[j]]
							if q == 0 then
								mob = mob + 1
							else
								if q * pc < 0 then mob = mob + 1 end
								break
							end
						end
					end
					if t == 3 then
						v = v + (mob - 6) * 3
						if pc > 0 then wB = wB + 1 else bB = bB + 1 end
					elseif t == 4 then
						v = v + (mob - 7) * 2
						nr = nr + 1
						rooks[nr] = s
					end
				end
				if t > 1 and t < 6 then
					if pc > 0 then wMat = wMat + VAL[t] else bMat = bMat + VAL[t] end
				end
				if pc > 0 then score = score + v else score = score - v end
			end
		end
		if wB >= 2 then score = score + 30 end
		if bB >= 2 then score = score - 30 end

		-- struktur pion: ganda, terisolasi, pion bebas
		for i = 1, np do
			local s = pawns[i]
			local pc = b[s]
			local f, r = FILE[s] + 1, RANK[s]
			local sc = 0
			if pc > 0 then
				if wp[f] > 1 then sc = sc - 8 end
				if (f == 1 or wp[f - 1] == 0) and (f == 8 or wp[f + 1] == 0) then sc = sc - 14 end
				local passed = true
				for ff = f - 1, f + 1 do
					if ff >= 1 and ff <= 8 and bmax[ff] > r then passed = false end
				end
				if passed then
					local bonus = PASSB[r + 1]
					if endg then bonus = bonus + bonus // 2 end
					sc = sc + bonus
				end
				score = score + sc
			else
				if bp[f] > 1 then sc = sc - 8 end
				if (f == 1 or bp[f - 1] == 0) and (f == 8 or bp[f + 1] == 0) then sc = sc - 14 end
				local passed = true
				for ff = f - 1, f + 1 do
					if ff >= 1 and ff <= 8 and wmin[ff] < r then passed = false end
				end
				if passed then
					local bonus = PASSB[(7 - r) + 1]
					if endg then bonus = bonus + bonus // 2 end
					sc = sc + bonus
				end
				score = score - sc
			end
		end

		-- benteng di kolom terbuka / setengah terbuka
		for i = 1, nr do
			local s = rooks[i]
			local f = FILE[s] + 1
			if b[s] > 0 then
				if wp[f] == 0 then score = score + ((bp[f] == 0) and 20 or 10) end
			else
				if bp[f] == 0 then score = score - ((wp[f] == 0) and 20 or 10) end
			end
		end

		-- keamanan raja (perisai pion) saat belum endgame
		if not endg then
			local ks = pos.kw
			local kf, kr = FILE[ks], RANK[ks]
			if kr <= 1 then
				local sh = 0
				for ff = kf - 1, kf + 1 do
					if ff >= 0 and ff <= 7 then
						if b[(kr + 1) * 8 + ff + 1] == 1 then sh = sh + 10
						elseif kr + 2 <= 7 and b[(kr + 2) * 8 + ff + 1] == 1 then sh = sh + 5
						else sh = sh - 12 end
					end
				end
				score = score + sh
			end
			ks = pos.kb
			kf, kr = FILE[ks], RANK[ks]
			if kr >= 6 then
				local sh = 0
				for ff = kf - 1, kf + 1 do
					if ff >= 0 and ff <= 7 then
						if b[(kr - 1) * 8 + ff + 1] == -1 then sh = sh + 10
						elseif kr - 2 >= 0 and b[(kr - 2) * 8 + ff + 1] == -1 then sh = sh + 5
						else sh = sh - 12 end
					end
				end
				score = score - sh
			end
		else
			-- endgame menang: dorong raja lawan ke tepi, dekatkan raja sendiri
			if bMat == 0 and wMat >= 500 then
				local dk = abs(FILE[pos.kw] - FILE[pos.kb]) + abs(RANK[pos.kw] - RANK[pos.kb])
				score = score + 47 * centerDist(pos.kb) // 10 + 16 * (14 - dk) // 10
			elseif wMat == 0 and bMat >= 500 then
				local dk = abs(FILE[pos.kw] - FILE[pos.kb]) + abs(RANK[pos.kw] - RANK[pos.kb])
				score = score - (47 * centerDist(pos.kw) // 10 + 16 * (14 - dk) // 10)
			end
		end
		return score * pos.turn
	end

	-- ===== Urutan langkah =====
	local function orderMoves(pos, ms, ttm, st, ply)
		local b = pos.b
		local k1, k2
		local hist
		if st then
			local k = st.kill[ply]
			if k then k1, k2 = k[1], k[2] end
			hist = st.hist
		end
		local side = (pos.turn == 1) and 0 or 4096
		for i = 1, #ms do
			local m = ms[i]
			local v = 0
			local cap = b[m.t]
			if ttm and m.f == ttm.f and m.t == ttm.t and m.p == ttm.p then
				v = 2000000
			elseif cap ~= 0 then
				v = 10000 + 10 * VAL[abs(cap)] - VAL[abs(b[m.f])]
			elseif m.fl == 2 then
				v = 10000 + 900
			elseif k1 and m.f == k1.f and m.t == k1.t then
				v = 9500
			elseif k2 and m.f == k2.f and m.t == k2.t then
				v = 9400
			elseif hist then
				local hv = hist[side + (m.f - 1) * 64 + m.t] or 0
				v = (hv > 7000) and 7000 or hv
			end
			if m.p then v = v + 9000 + VAL[m.p] end
			m.o = v
		end
		table.sort(ms, function(x, y) return x.o > y.o end)
	end

	local function tick(st)
		st.nodes = st.nodes + 1
		if st.nodes % 256 == 0 then
			local now = os.clock()
			if now >= st.deadline then
				st.abort = true
				return
			end
			if now - st.lastYield > 0.03 then
				wait()
				st.lastYield = os.clock()
				if st.cancel and st.cancel() then st.abort = true end
			end
		end
	end

	local function quiesce(st, pos, alpha, beta, qd)
		tick(st)
		if st.abort then return 0 end
		local stand = evaluate(pos)
		if stand >= beta then return stand end
		if stand > alpha then alpha = stand end
		if qd >= 6 then return stand end
		local ms = gen(pos, true)
		orderMoves(pos, ms)
		local turn = pos.turn
		local b = pos.b
		for i = 1, #ms do
			local m = ms[i]
			local cap = abs(b[m.t])
			if m.fl == 2 then cap = 1 end
			-- delta pruning: tangkapan kecil yang tak mungkin menaikkan alpha dilewati
			if m.p or cap == 0 or stand + VAL[cap] + 200 >= alpha then
				local np = apply(pos, m)
				if not attacked(np.b, kingSq(np, turn), -turn) then
					local sc = -quiesce(st, np, -beta, -alpha, qd + 1)
					if st.abort then return 0 end
					if sc >= beta then return sc end
					if sc > alpha then alpha = sc end
				end
			end
		end
		return alpha
	end

	local function hasPieces(pos)
		local b, turn = pos.b, pos.turn
		for s = 1, 64 do
			local v = b[s] * turn
			if v > 1 and v < 6 then return true end
		end
		return false
	end

	local negamax
	negamax = function(st, pos, depth, alpha, beta, ply, canNull)
		tick(st)
		if st.abort then return 0 end
		if pos.hm >= 100 then return 0 end
		local turn = pos.turn
		local h = hashPos(pos)
		if ply > 0 then
			-- pengulangan posisi (di jalur pencarian ini atau yang sudah terjadi di partai) = remis
			if st.path[h] or (st.game[h] or 0) >= 1 then return 0 end
		end
		local inCheck = attacked(pos.b, kingSq(pos, turn), -turn)
		if inCheck and ply < 12 then depth = depth + 1 end
		if depth <= 0 then return quiesce(st, pos, alpha, beta, 0) end

		local alpha0 = alpha
		local ttm
		local e = TT[h]
		if e then
			ttm = e.m
			if e.d >= depth and ply > 0 then
				local sc = e.s
				if sc > MATE - 1000 then sc = sc - ply elseif sc < -MATE + 1000 then sc = sc + ply end
				if e.f == 0 then return sc end
				if e.f == 1 and sc >= beta then return sc end
				if e.f == 2 and sc <= alpha then return sc end
			end
		end

		-- null-move pruning
		if canNull and not inCheck and depth >= 3 and beta < MATE - 1000 and hasPieces(pos) then
			local R = (depth >= 6) and 3 or 2
			local nn = { b = pos.b, turn = -turn, cr = pos.cr, ep = 0, hm = pos.hm + 1, fm = pos.fm, kw = pos.kw, kb = pos.kb }
			local sc = -negamax(st, nn, depth - 1 - R, -beta, -beta + 1, ply + 1, false)
			if st.abort then return 0 end
			if sc >= beta then return beta end
		end

		local ms = gen(pos, false)
		orderMoves(pos, ms, ttm, st, ply)
		local legal, best, bestM = 0, -INF, nil
		local b = pos.b
		local side = (turn == 1) and 0 or 4096
		local fut = false
		if depth <= 2 and (not inCheck) and alpha > -MATE + 1000 and alpha < MATE - 1000 then
			if evaluate(pos) + ((depth == 1) and 200 or 450) <= alpha then fut = true end
		end
		st.path[h] = true
		for i = 1, #ms do
			local m = ms[i]
			local np = apply(pos, m)
			if not attacked(np.b, kingSq(np, turn), -turn) then
				legal = legal + 1
				local quiet = (b[m.t] == 0) and (not m.p) and m.fl ~= 2
				if fut and quiet and legal > 1 and not attacked(np.b, kingSq(np, -turn), turn) then
					-- futility: langkah tenang tanpa skak tidak mungkin menaikkan alpha
					if best < alpha then best = alpha end
				else
				local d1 = depth - 1
				local sc
				if legal > 4 and depth >= 3 and quiet and not inCheck then
					sc = -negamax(st, np, d1 - 1, -alpha - 1, -alpha, ply + 1, true)
					if (not st.abort) and sc > alpha then
						sc = -negamax(st, np, d1, -beta, -alpha, ply + 1, true)
					end
				elseif legal > 1 then
					sc = -negamax(st, np, d1, -alpha - 1, -alpha, ply + 1, true)
					if (not st.abort) and sc > alpha and sc < beta then
						sc = -negamax(st, np, d1, -beta, -alpha, ply + 1, true)
					end
				else
					sc = -negamax(st, np, d1, -beta, -alpha, ply + 1, true)
				end
				if st.abort then return 0 end
				if sc > best then best, bestM = sc, m end
				if sc > alpha then alpha = sc end
				if alpha >= beta then
					if quiet then
						local k = st.kill[ply]
						if not k then k = {}; st.kill[ply] = k end
						if not (k[1] and k[1].f == m.f and k[1].t == m.t) then
							k[2] = k[1]
							k[1] = m
						end
						local hi = side + (m.f - 1) * 64 + m.t
						st.hist[hi] = (st.hist[hi] or 0) + depth * depth
					end
					break
				end
				end
			end
		end
		st.path[h] = nil
		if legal == 0 then return inCheck and (-MATE + ply) or 0 end

		local flag = 0
		if best <= alpha0 then flag = 2 elseif best >= beta then flag = 1 end
		local ss = best
		if ss > MATE - 1000 then ss = ss + ply elseif ss < -MATE + 1000 then ss = ss - ply end
		if ttN > 300000 then TT, ttN = {}, 0 end
		if not TT[h] then ttN = ttN + 1 end
		local bm = ttm
		if bestM and flag ~= 2 then bm = { f = bestM.f, t = bestM.t, p = bestM.p } end
		TT[h] = { d = depth, s = ss, f = flag, m = bm }
		return best
	end

	-- Cari langkah terbaik. Iterative deepening dengan batas waktu (detik).
	-- game = tabel hash posisi yang sudah terjadi di partai (untuk deteksi pengulangan), boleh nil.
	-- Mengembalikan: langkah, skor (sudut pandang pemain yang jalan), kedalaman selesai.
	-- Mengembalikan nil bila dibatalkan lewat cancelFn atau tidak ada langkah legal.
	function CH.search(pos, maxDepth, timeLimit, cancelFn, game)
		local st = {
			nodes = 0, abort = false, deadline = os.clock() + timeLimit, lastYield = os.clock(), cancel = cancelFn,
			path = {}, kill = {}, hist = {}, game = game or {},
		}
		local turn = pos.turn
		local root = {}
		local ms = gen(pos, false)
		orderMoves(pos, ms)
		for i = 1, #ms do
			local np = apply(pos, ms[i])
			if not attacked(np.b, kingSq(np, turn), -turn) then root[#root + 1] = { m = ms[i], np = np } end
		end
		if #root == 0 then return nil end
		if #root == 1 then return root[1].m, 0, 0 end
		local t0 = os.clock()
		local hroot = hashPos(pos)
		local bestMove, bestScore, doneDepth = root[1].m, 0, 0
		for d = 1, maxDepth do
			local alpha, itBest, itScore, itIdx, itAdj = -INF, nil, nil, 1, nil
			st.path = { [hroot] = true }
			for i = 1, #root do
				local sc = -negamax(st, root[i].np, d - 1, -INF, -alpha, 1, true)
				if st.abort then break end
				-- bonus kecil untuk promosi supaya promosi tidak ditunda tanpa alasan
				local adj = sc + (root[i].m.p == 5 and 25 or 0)
				if not itAdj or adj > itAdj then itBest, itScore, itIdx, itAdj = root[i], sc, i, adj end
				if sc > alpha then alpha = sc end
			end
			if st.abort then break end
			bestMove, bestScore, doneDepth = itBest.m, itScore, d
			table.remove(root, itIdx)
			table.insert(root, 1, itBest)
			if abs(itScore) > MATE - 100 then break end
			-- iterasi berikutnya biasanya >2x lebih lama: kalau sudah lewat ~40% waktu, cukup
			if d >= 4 and os.clock() - t0 > timeLimit * 0.4 then break end
		end
		if cancelFn and cancelFn() then return nil end
		return bestMove, bestScore, doneDepth
	end

	-- ===== Buku pembukaan (garis utama teori master; koordinat dari-ke) =====
	local BOOK = {}
	local function sqOf(str)
		return (str:byte(1) - 96) + (tonumber(str:sub(2, 2)) - 1) * 8
	end
	function CH.addLine(line)
		local pos = CH.start()
		for mv in line:gmatch("%S+") do
			local f, t = sqOf(mv:sub(1, 2)), sqOf(mv:sub(3, 4))
			local found
			for _, m in ipairs(CH.legal(pos)) do
				if m.f == f and m.t == t then found = m break end
			end
			if not found then return false, mv end
			local h = hashPos(pos)
			local lst = BOOK[h]
			if not lst then lst = {}; BOOK[h] = lst end
			local dup = false
			for _, x in ipairs(lst) do
				if x.f == f and x.t == t then x.w = x.w + 1; dup = true; break end
			end
			if not dup then lst[#lst + 1] = { f = f, t = t, w = 1 } end
			pos = apply(pos, found)
		end
		return true
	end
	-- Langkah buku untuk posisi ini (acak berbobot), atau nil bila di luar buku.
	function CH.bookMove(pos)
		local lst = BOOK[hashPos(pos)]
		if not lst then return nil end
		local legal = CH.legal(pos)
		local cands, total = {}, 0
		for _, x in ipairs(lst) do
			for _, m in ipairs(legal) do
				if m.f == x.f and m.t == x.t then
					cands[#cands + 1] = { m = m, w = x.w }
					total = total + x.w
					break
				end
			end
		end
		if total == 0 then return nil end
		local r = math.random(1, total)
		for _, c in ipairs(cands) do
			r = r - c.w
			if r <= 0 then return c.m end
		end
		return cands[1].m
	end

	local LINES = {
		-- 1.e4 e5
		"e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f8e7 f1e1 b7b5 a4b3 d7d6 c2c3 e8g8 h2h3",
		"e2e4 e7e5 g1f3 b8c6 f1b5 a7a6 b5a4 g8f6 e1g1 f6e4 d2d4 b7b5 a4b3 d7d5 d4e5 c8e6",
		"e2e4 e7e5 g1f3 b8c6 f1b5 g8f6 e1g1 f6e4 d2d4 e4d6 b5c6 d7c6 d4e5 d6f5 d1d8 e8d8",
		"e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d4 e5d4 c3d4 c5b4 b1c3 f6e4 e1g1 b4c3 b2c3 d7d5",
		"e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d3 d7d6 e1g1 e8g8 f1e1 a7a6",
		"e2e4 e7e5 g1f3 b8c6 f1c4 g8f6 f3g5 d7d5 e4d5 c6a5 c4b5 c7c6 d5c6 b7c6 b5e2 h7h6 g5f3 e5e4 f3e5 f8d6",
		"e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 g8f6 d4c6 b7c6 e4e5 d8e7 d1e2 f6d5 c2c4 c8a6",
		"e2e4 e7e5 g1f3 b8c6 d2d4 e5d4 f3d4 f8c5 c1e3 d8f6 c2c3 g8e7 f1c4 e8g8",
		"e2e4 e7e5 g1f3 g8f6 f3e5 d7d6 e5f3 f6e4 d2d4 d6d5 f1d3 f8e7 e1g1 b8c6 f1e1 c8g4 c2c4 e4f6",
		"e2e4 e7e5 g1f3 d7d6 d2d4 g8f6 b1c3 b8d7 f1c4 f8e7 e1g1 e8g8",
		"e2e4 e7e5 b1c3 g8f6 g2g3 d7d5 e4d5 f6d5 f1g2 d5b6 g1f3 b8c6 e1g1 f8e7",
		-- Sisilia
		"e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 a7a6 c1e3 e7e5 d4b3 c8e6 f2f3 f8e7 d1d2 e8g8 e1c1 b8d7",
		"e2e4 c7c5 g1f3 d7d6 d2d4 c5d4 f3d4 g8f6 b1c3 g7g6 c1e3 f8g7 f2f3 e8g8 d1d2 b8c6 e1c1",
		"e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 g8f6 b1c3 e7e5 d4b5 d7d6 c1g5 a7a6 b5a3 b7b5 g5f6 g7f6 c3d5 f6f5",
		"e2e4 c7c5 g1f3 b8c6 d2d4 c5d4 f3d4 g8f6 b1c3 d7d6 c1g5 e7e6 d1d2 a7a6 e1c1 c8d7",
		"e2e4 c7c5 b1c3 b8c6 g2g3 g7g6 f1g2 f8g7 d2d3 d7d6 c1e3 e7e6",
		"e2e4 c7c5 c2c3 g8f6 e4e5 f6d5 d2d4 c5d4 g1f3 b8c6 c3d4 d7d6 f1c4 d5b6 c4b5 d6e5 f3e5 c8d7",
		"e2e4 c7c5 g1f3 e7e6 d2d4 c5d4 f3d4 a7a6 f1d3 g8f6 e1g1 d8c7 f2f4 b8c6",
		-- Prancis
		"e2e4 e7e6 d2d4 d7d5 b1c3 g8f6 c1g5 f8e7 e4e5 f6d7 g5e7 d8e7 f2f4 e8g8 g1f3 c7c5",
		"e2e4 e7e6 d2d4 d7d5 b1c3 f8b4 e4e5 c7c5 a2a3 b4c3 b2c3 g8e7 d1g4 d8c7 g4g7 h8g8 g7h7 c5d4",
		"e2e4 e7e6 d2d4 d7d5 b1d2 g8f6 e4e5 f6d7 f1d3 c7c5 c2c3 b8c6 g1e2 c5d4 c3d4 f7f6",
		"e2e4 e7e6 d2d4 d7d5 e4e5 c7c5 c2c3 b8c6 g1f3 d8b6 a2a3 c5c4",
		-- Caro-Kann
		"e2e4 c7c6 d2d4 d7d5 b1c3 d5e4 c3e4 c8f5 e4g3 f5g6 h2h4 h7h6 g1f3 b8d7 h4h5 g6h7 f1d3 h7d3 d1d3 e7e6",
		"e2e4 c7c6 d2d4 d7d5 e4e5 c8f5 g1f3 e7e6 f1e2 c6c5 e1g1 b8c6 c2c3",
		"e2e4 c7c6 d2d4 d7d5 e4d5 c6d5 c2c4 g8f6 b1c3 e7e6 g1f3 f8e7 c4d5 f6d5 f1d3 b8c6 e1g1 e8g8",
		-- lain-lain vs e4
		"e2e4 d7d5 e4d5 d8d5 b1c3 d5a5 d2d4 g8f6 g1f3 c7c6 f1c4 c8f5",
		"e2e4 d7d6 d2d4 g8f6 b1c3 g7g6 g1f3 f8g7 f1e2 e8g8 e1g1 c7c6",
		"e2e4 g8f6 e4e5 f6d5 d2d4 d7d6 g1f3 c8g4 f1e2 e7e6 e1g1 f8e7 c2c4 d5b6",
		-- 1.d4
		"d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c1g5 f8e7 e2e3 e8g8 g1f3 b8d7 a1c1 c7c6 f1d3 d5c4 d3c4 f6d5 g5e7 d8e7 e1g1",
		"d2d4 d7d5 c2c4 e7e6 b1c3 g8f6 c4d5 e6d5 c1g5 c7c6 e2e3 f8e7 f1d3 b8d7 d1c2 e8g8 g1e2 f8e8",
		"d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 d5c4 a2a4 c8f5 e2e3 e7e6 f1c4 f8b4 e1g1 e8g8 d1e2 b8d7",
		"d2d4 d7d5 c2c4 c7c6 g1f3 g8f6 b1c3 e7e6 e2e3 b8d7 f1d3 d5c4 d3c4 b7b5 c4d3 a7a6 e3e4 c6c5",
		"d2d4 d7d5 c2c4 d5c4 g1f3 g8f6 e2e3 e7e6 f1c4 c7c5 e1g1 a7a6 d1e2 b7b5 c4b3 c8b7 f1d1 b8d7",
		"d2d4 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 g1f3 e8g8 f1e2 e7e5 e1g1 b8c6 d4d5 c6e7",
		"d2d4 g8f6 c2c4 g7g6 b1c3 d7d5 c4d5 f6d5 e2e4 d5c3 b2c3 f8g7 g1f3 c7c5 f1e2 e8g8 e1g1 b8c6",
		"d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 e2e3 e8g8 f1d3 d7d5 g1f3 c7c5 e1g1 b8c6 a2a3 b4c3 b2c3 d5c4 d3c4 d8c7",
		"d2d4 g8f6 c2c4 e7e6 b1c3 f8b4 d1c2 e8g8 a2a3 b4c3 c2c3 b7b6 c1g5 c8b7 e2e3 d7d6",
		"d2d4 g8f6 c2c4 e7e6 g1f3 b7b6 g2g3 c8b7 f1g2 f8e7 e1g1 e8g8 b1c3 f6e4 d1c2 e4c3 c2c3 c7c5",
		"d2d4 g8f6 c2c4 e7e6 g2g3 d7d5 f1g2 f8e7 g1f3 e8g8 e1g1 d5c4 d1c2 a7a6 c2c4 b7b5 c4c2 c8b7",
		"d2d4 d7d5 g1f3 g8f6 c1f4 e7e6 e2e3 c7c5 c2c3 b8c6 b1d2 f8d6 f4g3 e8g8 f1d3 d8c7",
		"d2d4 g8f6 g1f3 g7g6 c1f4 f8g7 e2e3 e8g8 h2h3 d7d6 f1e2 b8d7",
		"d2d4 f7f5 g2g3 g8f6 f1g2 e7e6 g1f3 f8e7 e1g1 e8g8 c2c4 d7d6 b1c3 d8e8",
		-- 1.c4 / 1.Nf3
		"c2c4 e7e5 b1c3 g8f6 g1f3 b8c6 g2g3 d7d5 c4d5 f6d5 f1g2 d5b6 e1g1 f8e7",
		"c2c4 c7c5 b1c3 b8c6 g2g3 g7g6 f1g2 f8g7 g1f3 e7e6 e1g1 g8e7 d2d4 c5d4 f3d4 e8g8",
		"g1f3 d7d5 g2g3 g8f6 f1g2 e7e6 e1g1 f8e7 d2d4 e8g8 c2c4 d5c4",
		"g1f3 g8f6 c2c4 g7g6 b1c3 f8g7 e2e4 d7d6 d2d4 e8g8",
		"g1f3 d7d5 d2d4 g8f6 c2c4 e7e6 b1c3 f8e7 c1g5 e8g8",
	}
	for _, ln in ipairs(LINES) do
		local ok, bad = CH.addLine(ln)
		if not ok and warn then warn("[Catur] buku: langkah tidak valid " .. tostring(bad)) end
	end

	return CH
end

local function buildChess()
	local CH = makeEngine()
	local page = pages["Mini Game"]
	local BASE_DESC = "Scan papan catur in-game, tandai langkah balasan terbaik (panah hijau). Langkah musuh = oranye."
	local PCODE = { Pawn = 1, Knight = 2, Bishop = 3, Rook = 4, Queen = 5, King = 6 }
	local C_HINT, C_OPP, C_THREAT = T.good, Color3.fromRGB(255, 160, 50), T.danger

	sectionLabel(page, 9, "Catur")
	local descLbl = addToggleCard(page, 10, "Saran Langkah Catur", BASE_DESC, "chess")
	addSliderCard(page, 11, "Waktu Berpikir Saran", "Batas detik sebelum saran muncul (1-10). Kecil = cepat, besar = lebih akurat", "chessTime", 1, 10, 10, true)

	local A: any = {
		pos = nil, mine = nil, info = nil, hint = nil, hintTxt = "", lastOpp = nil, threat = {},
		sid = 0, hist = {}, stableKey = nil, stableN = 0, sig = nil, on = false, remotePos = nil, hooked = {}, warned = false,
	}

	local function setDesc(s: string)
		if not unloaded and descLbl and descLbl.Parent then descLbl.Text = s end
	end

	-- ---------- overlay: ScreenGui sendiri, tidak menyentuh UI game ----------
	local ov = new("ScreenGui", {
		Name = "UU_CHESS", ResetOnSpawn = false, DisplayOrder = 1000,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false,
	}, playerGui)
	local layer = new("Frame", {
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
	}, ov)
	local hud = new("TextLabel", {
		AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = T.bg, BackgroundTransparency = 0.15, BorderSizePixel = 0, Text = "",
		TextColor3 = C_HINT, Font = Enum.Font.GothamBold, TextSize = 14, Visible = false, Active = false,
	}, ov)
	round(hud, 8)
	stroke(hud, C_HINT, 1.2, 0.3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, hud)

	-- ---------- baca papan in-game ----------
	-- Papan: PlayerGui["2DBoard"].Main.Board.<a1..h8> (kotak), Main.Pieces.<Warna>_<Jenis> (bidak, ImageButton).
	-- Kotak & bidak dicocokkan lewat posisi layar (titik tengah), jadi tidak peduli papan diputar / dibalik.
	local function scan()
		local g = playerGui:FindFirstChild("2DBoard")
		local main = g and g:FindFirstChild("Main")
		local board = main and main:FindFirstChild("Board")
		local pieces = main and main:FindFirstChild("Pieces")
		if not (g and board and pieces) then return nil, "nogui" end
		if g:IsA("ScreenGui") and not g.Enabled then return nil, "nogui" end
		if main:IsA("GuiObject") and not main.Visible then return nil, "nogui" end

		local cen: { [number]: Vector2 } = {}
		local size, cnt = 0, 0
		for _, c in ipairs(board:GetChildren()) do
			local f, r = string.match(c.Name, "^([a-h])([1-8])$")
			if f and c:IsA("GuiObject") then
				local sq = (tonumber(r) - 1) * 8 + (string.byte(f) - 96)
				if not cen[sq] then cnt += 1 end
				cen[sq] = c.AbsolutePosition + c.AbsoluteSize / 2
				size = c.AbsoluteSize.X
			end
		end
		if cnt ~= 64 or size < 8 then return nil, "nogui" end

		local b = {}
		for i = 1, 64 do b[i] = 0 end
		for _, p in ipairs(pieces:GetChildren()) do
			if p:IsA("GuiObject") and p.Visible then
				local col, typ = string.match(p.Name, "^(%a+)_(%a+)$")
				local code = typ and PCODE[typ]
				if code and (col == "White" or col == "Black") then
					local pc = p.AbsolutePosition + p.AbsoluteSize / 2
					local best, bd = nil, math.huge
					for sq, c in pairs(cen) do
						local d = (c - pc).Magnitude
						if d < bd then best, bd = sq, d end
					end
					if bd <= size * 0.3 then
						if b[best] ~= 0 then return nil, "dup" end -- dua bidak di satu kotak = animasi tangkap
						b[best] = (col == "White") and code or -code
					elseif bd <= size * 0.75 then
						return nil, "anim" -- bidak sedang meluncur
					end -- lebih jauh dari itu: bidak di luar papan (tertangkap), diabaikan
				end
			end
		end
		local inset = false
		if g:IsA("ScreenGui") then inset = g.IgnoreGuiInset end
		return b, { cen = cen, size = size, inset = inset }
	end

	local function sameBoard(a: any, c: any): boolean
		for i = 1, 64 do
			if a[i] ~= c[i] then return false end
		end
		return true
	end

	-- warna milikku = sisi yang rajanya ada di BAWAH layar
	local function myColorOf(b: any, cen: any): number?
		local yw, yb = nil, nil
		for s = 1, 64 do
			if b[s] == 6 then yw = cen[s].Y elseif b[s] == -6 then yb = cen[s].Y end
		end
		if yw and yb and math.abs(yw - yb) > 1 then return (yw > yb) and 1 or -1 end
		return nil
	end

	local function fromScan(b: any, turn: number): any
		local kw, kb = 0, 0
		for s = 1, 64 do
			if b[s] == 6 then kw = s elseif b[s] == -6 then kb = s end
		end
		if kw == 0 or kb == 0 then return nil end
		local cr = 0
		if kw == 5 then
			if b[8] == 4 then cr += 1 end
			if b[1] == 4 then cr += 2 end
		end
		if kb == 61 then
			if b[64] == -4 then cr += 4 end
			if b[57] == -4 then cr += 8 end
		end
		return { b = b, turn = turn, cr = cr, ep = 0, hm = 0, fm = 1, kw = kw, kb = kb }
	end

	-- Lacak posisi: cari langkah legal (1 lalu 2 langkah) yang mengubah posisi lama jadi papan sekarang.
	-- Dari sini giliran, hak rokade, en passant, dan langkah terakhir musuh diketahui pasti.
	local function trackTo(b: any, mine: number)
		local P = A.pos
		local newPos, oppMove = nil, nil
		if P then
			local sides = { P.turn, -P.turn }
			for _, t in ipairs(sides) do
				local S = P
				if t ~= P.turn then
					S = table.clone(P)
					S.turn, S.ep = t, 0
				end
				for _, m in ipairs(CH.legal(S)) do
					local np = CH.apply(S, m)
					if sameBoard(np.b, b) then
						newPos = np
						if t ~= mine then oppMove = m end
						break
					end
				end
				if newPos then break end
			end
			if not newPos then
				for _, t in ipairs(sides) do
					local S = P
					if t ~= P.turn then
						S = table.clone(P)
						S.turn, S.ep = t, 0
					end
					for _, m1 in ipairs(CH.legal(S)) do
						local n1 = CH.apply(S, m1)
						for _, m2 in ipairs(CH.legal(n1)) do
							local n2 = CH.apply(n1, m2)
							if sameBoard(n2.b, b) then
								newPos = n2
								oppMove = (t ~= mine) and m1 or m2
								break
							end
						end
						if newPos then break end
					end
					if newPos then break end
				end
			end
		end
		if not newPos then
			-- tidak cocok (script baru jalan di tengah game / game baru): bangun dari papan
			A.lastOpp = nil
			A.hist = {}
			oppMove = nil
			local start = CH.start()
			local rp = A.remotePos
			if sameBoard(b, start.b) then
				newPos = start
			elseif rp and sameBoard(rp.b, b) then
				newPos = rp -- FEN dari server: giliran & hak rokade pasti
			else
				newPos = fromScan(b, mine) -- anggap sekarang giliranmu
			end
		end
		if oppMove then A.lastOpp = oppMove end
		A.pos = newPos
	end

	local function evalText(sc: number): string
		if sc > CH.MATE - 100 then return " [skakmat!]" end
		if sc < -(CH.MATE - 100) then return " [bahaya skakmat]" end
		return string.format(" [%+.1f]", sc / 100)
	end

	local function think()
		local sid, pos = A.sid, A.pos
		setDesc("Giliranmu - menghitung saran...")
		-- 1) buku pembukaan (langkah teori master)
		local okB, bm = pcall(CH.bookMove, pos)
		if okB and bm then
			A.hint = bm
			A.hintTxt = CH.describe(pos, bm) .. " [buku pembukaan]"
			A.sig = nil
			setDesc("Saran: " .. A.hintTxt)
			toast("Saran: " .. CH.describe(pos, bm))
			return
		end
		-- 2) mesin: iterative deepening sampai 12 ply / 4 detik, sadar pengulangan posisi
		task.spawn(function()
			local m, sc, dd = CH.search(pos, 16, math.clamp(values.chessTime or 3, 1, 10), function()
				return unloaded or A.sid ~= sid or not state.chess
			end, A.hist)
			if unloaded or A.sid ~= sid or not state.chess then return end
			if not m then
				setDesc("Tidak ada langkah legal.")
				return
			end
			A.hint = m
			A.hintTxt = CH.describe(pos, m) .. evalText(sc) .. " d" .. tostring(dd or 0)
			A.sig = nil
			setDesc("Saran: " .. A.hintTxt)
			toast("Saran: " .. CH.describe(pos, m))
		end)
	end

	local function onNewPosition()
		A.sid += 1
		A.hint, A.hintTxt, A.sig = nil, "", nil
		local pos = A.pos
		do
			local okH, hk = pcall(CH.hash, pos)
			if okH then A.hist[hk] = (A.hist[hk] or 0) + 1 end
		end
		local st = CH.status(pos)
		A.threat = {}
		if st == "mate" or st == "stalemate" or st == "draw50" or st == "insufficient" then
			setDesc(st == "mate" and "Skakmat - permainan selesai." or "Remis - permainan selesai.")
			return
		end
		A.threat = CH.threatened(pos, A.mine)
		if pos.turn == A.mine then
			think()
		else
			setDesc("Giliran musuh - menunggu langkahnya...")
		end
	end

	-- ---------- gambar tanda di atas papan game ----------
	local function redraw()
		local info = A.info
		if not info then return end
		local cen, s = info.cen, info.size
		local lo = layer.AbsolutePosition
		local hint, opp = A.hint, A.lastOpp
		local thr = A.threat or {}
		local c1, c64 = cen[1], cen[64]
		local sig = string.format("%.1f|%.1f|%.1f|%.1f|%.1f|%.1f|%d|%d|%d|%d|%d",
			lo.X, lo.Y, c1.X, c1.Y, c64.X, c64.Y,
			hint and hint.f or 0, hint and hint.t or 0, opp and opp.f or 0, opp and opp.t or 0, #thr)
		if sig == A.sig then return end
		A.sig = sig
		layer:ClearAllChildren()

		local function sqBox(sq: number, color: Color3, tr: number, thick: number)
			local c = cen[sq] - lo
			local f = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y),
				Size = UDim2.fromOffset(s, s), BackgroundColor3 = color, BackgroundTransparency = tr,
				BorderSizePixel = 0, Active = false, ZIndex = 5,
			}, layer)
			stroke(f, color, thick, 0)
		end

		if opp then
			sqBox(opp.f, C_OPP, 0.75, 2)
			sqBox(opp.t, C_OPP, 0.6, 3)
		end
		for _, sq in ipairs(thr) do
			local c = cen[sq] - lo + Vector2.new(s * 0.3, -s * 0.3)
			local d = new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(c.X, c.Y),
				Size = UDim2.fromOffset(s * 0.2, s * 0.2), BackgroundColor3 = C_THREAT,
				BorderSizePixel = 0, Active = false, ZIndex = 7,
			}, layer)
			new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, d)
			stroke(d, WHITE, 1, 0.2)
		end
		if hint then
			sqBox(hint.f, C_HINT, 0.6, 3)
			sqBox(hint.t, C_HINT, 0.35, 4)
			local p1, p2 = cen[hint.f] - lo, cen[hint.t] - lo
			local d = p2 - p1
			local len = d.Magnitude
			if len > 1 then
				local u = d / len
				local ang = math.deg(math.atan2(d.Y, d.X))
				local sP, hP = p1 + u * s * 0.25, p2 - u * s * 0.22
				local L = math.max(2, (hP - sP).Magnitude)
				new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((sP.X + hP.X) / 2, (sP.Y + hP.Y) / 2),
					Size = UDim2.fromOffset(L, 8), Rotation = ang, BackgroundColor3 = C_HINT,
					BackgroundTransparency = 0.15, BorderSizePixel = 0, Active = false, ZIndex = 8,
				}, layer)
				new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(hP.X, hP.Y),
					Size = UDim2.fromOffset(s * 0.28, s * 0.28), Rotation = ang + 45, BackgroundColor3 = C_HINT,
					BackgroundTransparency = 0.15, BorderSizePixel = 0, Active = false, ZIndex = 8,
				}, layer)
			end
		end

		-- teks saran di atas papan
		if hint and A.hintTxt ~= "" then
			local minY, sx, n = math.huge, 0, 0
			for _, c in pairs(cen) do
				minY = math.min(minY, c.Y)
				sx += c.X
				n += 1
			end
			hud.Text = "Saran: " .. A.hintTxt
			hud.Position = UDim2.fromOffset(sx / n - lo.X, math.max(30, minY - s / 2 - lo.Y - 6))
			hud.Visible = true
		else
			hud.Visible = false
		end
	end

	local function clearAll()
		layer:ClearAllChildren()
		hud.Visible = false
		A.sig = nil
	end

	-- ---------- langkah utama (dipanggil ~8x per detik) ----------
	local function step()
		local b, info = scan()
		if not b then
			A.stableN = 0
			if info == "nogui" and (A.pos or A.info) then
				A.pos, A.info, A.hint, A.lastOpp = nil, nil, nil, nil
				A.sid += 1
				clearAll()
				setDesc("Papan 2DBoard tidak terlihat. Buka game catur dulu.")
			end
			return
		end
		local key = table.concat(b, ",")
		if key == A.stableKey then
			A.stableN += 1
		else
			A.stableKey, A.stableN = key, 1
		end
		if A.stableN < 2 then return end -- papan harus diam dulu (animasi gerak bidak selesai)

		A.info = info
		local mine = myColorOf(b, info.cen) or A.mine or 1
		if A.mine ~= mine then
			A.mine = mine
			A.pos = nil -- warna/arah berubah (game baru): lacak ulang
		end
		ov.IgnoreGuiInset = info.inset

		if not (A.pos and sameBoard(A.pos.b, b)) then
			local ok, err = pcall(trackTo, b, mine)
			if not ok or not A.pos then
				A.pos = nil
				if not A.warned then
					A.warned = true
					warn("[Catur] " .. tostring(err))
				end
				return
			end
			onNewPosition()
		end
		redraw()
	end

	-- ---------- remote server: FEN lengkap bila ada (hanya dipakai saat memulai di tengah game) ----------
	local function hookRemote(inst: Instance)
		if not inst:IsA("RemoteEvent") or A.hooked[inst] then return end
		if not string.find(inst.Name, "^MoveMade") then return end
		A.hooked[inst] = true
		track(inst.OnClientEvent:Connect(function(...)
			for i = 1, select("#", ...) do
				local v = select(i, ...)
				if type(v) == "string" and string.find(v, "/", 1, true) then
					local okF, p = pcall(CH.fromFen, v)
					if okF and p then A.remotePos = p end
					break
				end
			end
		end))
	end
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do hookRemote(d) end
	track(ReplicatedStorage.DescendantAdded:Connect(hookRemote))

	effects.chess = function(on: boolean)
		A.sid += 1
		A.on = on
		A.pos, A.info, A.hint, A.lastOpp, A.sig = nil, nil, nil, nil, nil
		A.threat = {}
		A.stableKey, A.stableN = nil, 0
		clearAll()
		ov.Enabled = on
		setDesc(on and "Menunggu papan 2DBoard..." or BASE_DESC)
	end

	local acc = 0
	track(RunService.Heartbeat:Connect(function(dt: number)
		if unloaded then return end
		if not state.chess then
			if A.on then effects.chess(false) end -- mis. "Matikan Semua Fitur"
			return
		end
		if not A.on then effects.chess(true) end
		acc += dt
		if acc < 0.12 then return end
		acc = 0
		local ok, err = pcall(step)
		if not ok and not A.warned then
			A.warned = true
			warn("[Catur] " .. tostring(err))
		end
	end))
end

buildChess()
end

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

	local function readJson(name: string): any
		return settings.load(name) -- pembaca terpusat (otomatis pakai .bak kalau file utama rusak)
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

	local function saveAll()
		local eg = encode(globalData())
		if eg and eg ~= lastG then
			lastG = eg
			pcall(settings.save, "settings.json", eg)
		end

		local ew = encode(wpData())
		if ew and ew ~= lastW then
			lastW = ew
			pcall(settings.save, wpFile, ew)
		end

		if not remote then
			local es = encode(slots)
			if es and es ~= lastS then
				lastS = es
				pcall(settings.save, "slots.json", es)
			end
		end
	end
	settings.flushers.config = saveAll -- dipanggil settings.flush() saat hop / unload / teleport

	while not unloaded do
		task.wait(1) -- [FIX] sebelumnya 3 detik
		if unloaded then break end
		pcall(saveAll)
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
-- TAB SCAN: SCAN RARITY + REKAM MINIGAME (dari SCANNER_MINI_GAME.txt)
-- Menggantikan "Tes Deteksi Rarity" dan "Scan Mini Game" yang lama.
-- Dibungkus do...end + fungsi supaya tidak menambah jumlah local di level atas.
-- =====================================================
do
local function buildScan()
	local RS = game:GetService("ReplicatedStorage")
	local Marketplace = game:GetService("MarketplaceService")
	local PPS = game:GetService("ProximityPromptService")

	local CFG = {
		folder = "UniversalUI_Scan", -- folder file di workspace executor
		maxObjs = 2500,        -- objek UI yang dipantau
		maxSamples = 250000,   -- total sampel posisi (batas memori)
		maxEvents = 6000,      -- kejadian (teks, tampil/sembunyi, model hilang, dll)
		maxTrials = 400,       -- jumlah tekanan yang dicatat
		flushEvery = 2,        -- detik: tulis buffer ke file
		reportMaxChars = 58000, -- batas ringkasan di clipboard (file tetap lengkap)
		tableMaxRows = 70,     -- baris tabel tekan di ringkasan
	}

	-- ---------- fungsi executor (opsional, semua dicek) ----------
	local ENV: any = _G
	do
		local ok, e = pcall(function() return (getgenv :: any)() end)
		if ok and type(e) == "table" then ENV = e end
	end
	local fsWrite: any, fsAppend: any = ENV.writefile, ENV.appendfile
	local fsMake: any, fsIsFolder: any = ENV.makefolder, ENV.isfolder
	local clipFn: any = ENV.setclipboard or ENV.toclipboard

	local folderReady = false
	local function ensureFolder()
		if folderReady then return end
		folderReady = true
		pcall(function()
			if fsMake and fsIsFolder and not fsIsFolder(CFG.folder) then fsMake(CFG.folder) end
		end)
	end
	local function fpath(name: string): string
		return CFG.folder .. "/" .. name
	end
	local function saveFile(name: string, content: string): boolean
		if not fsWrite then return false end
		ensureFolder()
		return (pcall(fsWrite, fpath(name), content))
	end
	local function appendFile(name: string, content: string): boolean
		if not fsAppend then return false end
		ensureFolder()
		return (pcall(fsAppend, fpath(name), content))
	end
	local function copyText(s: string): boolean
		if not clipFn then return false end
		return (pcall(clipFn, s))
	end

	-- ---------- util umum ----------
	local lastYield = os.clock()
	local function maybeYield()
		if os.clock() - lastYield > 0.008 then
			task.wait()
			lastYield = os.clock()
		end
	end

	local function relPath(inst: Instance): string
		local full = inst:GetFullName()
		local r = string.gsub(full, "^Players%.[^%.]+%.PlayerGui%.", "")
		return r
	end

	local function shown(inst: Instance): boolean
		local cur: Instance? = inst
		local rootLayer: LayerCollector? = nil
		while cur and cur ~= playerGui do
			if cur:IsA("GuiObject") and not cur.Visible then return false end
			if cur:IsA("LayerCollector") then
				rootLayer = cur :: LayerCollector
				if not rootLayer.Enabled then return false end
				break
			end
			cur = cur.Parent
		end
		return (cur == playerGui and rootLayer ~= nil) or (rootLayer ~= nil and rootLayer.Parent ~= nil)
	end

	local function cut(s: any, n: number): string
		local str = tostring(s)
		str = string.gsub(str, "[\r\n|]+", " ")
		if #str > n then str = string.sub(str, 1, n) .. "~" end
		return str
	end

	local function norm(s: any): string
		return (string.gsub(string.lower(tostring(s)), "[^%a]", ""))
	end

	local function median(t: { number }): number
		local n = #t
		if n == 0 then return 0 end
		local c = table.clone(t)
		table.sort(c)
		if n % 2 == 1 then return c[(n + 1) // 2] end
		return (c[n // 2] + c[n // 2 + 1]) / 2
	end

	-- =================================================================================
	-- A) SCAN RARITY (generik)
	-- =================================================================================
	local RW_STRONG: { [string]: boolean } = {}
	for _, w in ipairs({ "common", "uncommon", "rare", "epic", "legendary", "mythic", "mythical", "godly", "divine",
		"secret", "exotic", "ultra", "ancient", "celestial", "transcendent", "immortal", "cosmic", "supreme", "omega",
		"biasa", "langka", "epik", "legendaris", "mitos", "dewa", "rahasia" }) do
		RW_STRONG[w] = true
	end
	local RW_WEAK: { [string]: boolean } = {}
	for _, w in ipairs({ "basic", "normal", "ordinary", "special", "unique", "limited", "event", "relic", "artifact",
		"collector", "superrare", "ultrarare", "masterwork" }) do
		RW_WEAK[w] = true
	end
	local RW_ORDER: { [string]: number } = {
		basic = 0, normal = 0, ordinary = 0, common = 1, biasa = 1, uncommon = 2, rare = 3, langka = 3, epic = 4, epik = 4,
		legendary = 5, legendaris = 5, mythic = 6, mythical = 6, mitos = 6, godly = 7, divine = 7, dewa = 7, secret = 8, rahasia = 8,
	}
	local function isRW(s: any): boolean
		local n = norm(s)
		return RW_STRONG[n] == true or RW_WEAK[n] == true
	end
	local function isRKey(k: any): boolean
		if type(k) ~= "string" then return false end
		local l = string.lower(k)
		return string.find(l, "rarity", 1, true) ~= nil or l == "rare" or l == "tier" or l == "grade" or l == "quality" or l == "rank"
	end
	local MOD_WORDS = { "rarity", "item", "data", "config", "drop", "loot", "shop", "tool", "mushroom", "fish", "pet", "crop",
		"ore", "gem", "seed", "product", "catalog", "registry", "zone", "tier", "recipe", "stat", "resource", "collect",
		"harvest", "world" }

	local function brief(v: any): string
		local ty = typeof(v)
		if ty == "string" then return '"' .. string.sub(v, 1, 30) .. '"' end
		if ty == "number" or ty == "boolean" then return tostring(v) end
		if ty == "Color3" then return "#" .. v:ToHex() end
		return ty
	end
	local function briefTable(t: any): string
		local parts, n = {}, 0
		for k, v in pairs(t) do
			if type(v) ~= "table" and type(v) ~= "function" then
				n += 1
				if n > 8 then break end
				parts[#parts + 1] = tostring(k) .. "=" .. brief(v)
			end
		end
		return table.concat(parts, " ")
	end

	local function safeRequire(m: Instance): any
		local done, res = false, nil
		task.spawn(function()
			local ok, r = pcall(require, m)
			if ok then res = r end
			done = true
		end)
		local t0 = os.clock()
		while not done and os.clock() - t0 < 1.5 do task.wait() end
		return res
	end

	-- menelusuri tabel data: cari (a) daftar urutan rarity, (b) kamus rarity->detail, (c) item ber-rarity
	local function walkData(root: any, modName: string, ctx: any)
		local seen: { [any]: boolean } = {}
		local function walk(t: any, path: string, depth: number)
			if depth > 5 or ctx.nodes > 40000 or seen[t] then return end
			seen[t] = true
			ctx.nodes += 1

			if t[1] ~= nil then
				local words, nStrong = {}, 0
				for i = 1, math.min(#t, 30) do
					local v = t[i]
					if type(v) == "string" and isRW(v) then
						words[#words + 1] = v
						if RW_STRONG[norm(v)] then nStrong += 1 end
					end
				end
				if #words >= 3 and nStrong >= 2 and #ctx.orders < 6 then
					ctx.orders[#ctx.orders + 1] = { path = modName .. path, list = words }
				end
			end

			local rows, nDef = {}, 0
			for k, v in pairs(t) do
				if type(k) == "string" and isRW(k) and (type(v) == "number" or type(v) == "table" or type(v) == "string") then
					nDef += 1
					if type(v) == "table" then
						rows[#rows + 1] = k .. " { " .. briefTable(v) .. " }"
					else
						rows[#rows + 1] = k .. " = " .. brief(v)
					end
				end
			end
			if nDef >= 3 and #ctx.defs < 8 then
				ctx.defs[#ctx.defs + 1] = { path = modName .. path, rows = rows }
			end

			for k, v in pairs(t) do
				if type(v) == "table" then
					local rv, nm = nil, nil
					for fk, fv in pairs(v) do
						if type(fk) == "string" then
							if rv == nil and isRKey(fk) and (type(fv) == "string" or type(fv) == "number") then rv = fv end
							local lf = string.lower(fk)
							if nm == nil and (lf == "name" or lf == "displayname" or lf == "id") and type(fv) == "string" then nm = fv end
						end
					end
					if rv ~= nil and ctx.nItems < 4000 then
						ctx.nItems += 1
						ctx.items[#ctx.items + 1] = { n = nm or tostring(k), r = rv, src = modName }
					end
					walk(v, path .. "." .. tostring(k), depth + 1)
				elseif type(v) == "string" and type(k) == "string" and isRW(v) and not isRW(k) and ctx.nItems < 4000 then
					ctx.nItems += 1
					ctx.items[#ctx.items + 1] = { n = k, r = v, src = modName }
				end
			end
		end
		walk(root, "", 0)
	end

	local function runRarity(setStatus: (string) -> ()): (string, string, Color3)
		local L: { string } = {}
		local function add(s: string) L[#L + 1] = s end

		add("== UNIVERSAL UI SCAN: RARITY ==")
		add("GameId: " .. tostring(game.GameId) .. " | PlaceId: " .. tostring(game.PlaceId))
		local placeName = "?"
		local okP, info = pcall(function() return Marketplace:GetProductInfo(game.PlaceId) end)
		if okP and type(info) == "table" and info.Name then placeName = tostring(info.Name) end
		add("Place: " .. placeName)

		local ch = player.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?

		-- ---------- 1) item di dunia (ProximityPrompt) ----------
		setStatus("Memindai item di dunia...")
		local prompts: { ProximityPrompt } = {}
		for _, d in ipairs(workspace:GetDescendants()) do
			maybeYield()
			if d:IsA("ProximityPrompt") then
				prompts[#prompts + 1] = d
				if #prompts >= 600 then break end
			end
		end

		local function evidence(inst: Instance, outList: { string }, label: string)
			for k, v in pairs(inst:GetAttributes()) do
				if (isRKey(k) and (type(v) == "string" or type(v) == "number")) or (type(v) == "string" and isRW(v)) then
					outList[#outList + 1] = label .. " attr " .. tostring(k) .. "=" .. tostring(v)
				end
			end
			if inst:IsA("ValueBase") then
				local okv, val = pcall(function() return (inst :: any).Value end)
				if okv and (isRKey(inst.Name) or (type(val) == "string" and isRW(val))) then
					outList[#outList + 1] = label .. " value " .. inst.Name .. "=" .. tostring(val)
				end
			end
			if inst:IsA("TextLabel") and isRW((inst :: any).Text) then
				outList[#outList + 1] = label .. " teks '" .. (inst :: any).Text .. "'"
			end
			if isRW(inst.Name) then outList[#outList + 1] = label .. " nama '" .. inst.Name .. "'" end
		end

		local worldRows: { any } = {}
		local withEv, seenModels = 0, {}
		for _, pr in ipairs(prompts) do
			maybeYield()
			local m: Instance = pr:FindFirstAncestorOfClass("Model") or pr.Parent or pr
			if not seenModels[m] then
				seenModels[m] = true
				local ev: { string } = {}
				evidence(m, ev, "model")
				evidence(pr, ev, "prompt")
				local n = 0
				for _, d in ipairs(m:GetDescendants()) do
					n += 1
					if n > 150 then break end
					evidence(d, ev, d.ClassName)
				end
				local dist = -1
				if hrp then
					local okD, pv = pcall(function() return (m :: any):GetPivot().Position end)
					if okD then dist = math.floor((pv - hrp.Position).Magnitude) end
				end
				local ak = {}
				for k, v in pairs(m:GetAttributes()) do
					if #ak < 10 then ak[#ak + 1] = tostring(k) .. "=" .. cut(v, 20) end
				end
				table.sort(ak)
				worldRows[#worldRows + 1] = {
					name = m.Name, text = pr.ObjectText, dist = dist, ev = ev, attrs = ak,
				}
				if #ev > 0 then withEv += 1 end
			end
		end
		table.sort(worldRows, function(a, b)
			if (a.dist < 0) ~= (b.dist < 0) then return a.dist >= 0 end
			return a.dist < b.dist
		end)

		add("")
		add("[1] ITEM DI DUNIA (ProximityPrompt): " .. #worldRows .. " item dicek, " .. withEv .. " membawa info rarity")
		if #worldRows == 0 then
			add("  Tidak ada item ber-prompt yang termuat. Dekati area item lalu scan lagi.")
		else
			add("  10 terdekat (nama | prompt | jarak | info rarity | atribut):")
			for i = 1, math.min(10, #worldRows) do
				local r = worldRows[i]
				add(string.format("  %d. %s | '%s' | %d st | %s | %s", i, r.name, tostring(r.text), r.dist,
					#r.ev > 0 and cut(r.ev[1], 70) or "tanpa info rarity", #r.attrs > 0 and table.concat(r.attrs, ", ") or "(tanpa atribut)"))
			end
		end

		-- ---------- 2) ReplicatedStorage ----------
		setStatus("Memindai ReplicatedStorage...")
		local rsHits: { string } = {}
		local mods: { ModuleScript } = {}
		local folders: { string } = {}
		for _, d in ipairs(RS:GetDescendants()) do
			maybeYield()
			for k, v in pairs(d:GetAttributes()) do
				if (type(v) == "string" or type(v) == "number") and (isRKey(k) or (type(v) == "string" and isRW(v))) and #rsHits < 40 then
					rsHits[#rsHits + 1] = d:GetFullName() .. " [attr " .. tostring(k) .. "=" .. tostring(v) .. "]"
				end
			end
			if d:IsA("ValueBase") then
				local okv, val = pcall(function() return (d :: any).Value end)
				if okv and (type(val) == "string" or type(val) == "number") and (isRKey(d.Name) or (type(val) == "string" and isRW(val))) and #rsHits < 40 then
					rsHits[#rsHits + 1] = d:GetFullName() .. " [value " .. tostring(val) .. "]"
				end
			end
			if d:IsA("ModuleScript") then mods[#mods + 1] = d end
			if (d:IsA("Folder") or d:IsA("Configuration")) and isRW(d.Name) and #folders < 20 then
				folders[#folders + 1] = d:GetFullName() .. " (" .. #d:GetChildren() .. " isi)"
			end
		end

		-- ---------- 3) modul data ----------
		setStatus("Membaca modul data game...")
		local cand: { any } = {}
		local skipped: { string } = {}
		for _, m in ipairs(mods) do
			local l = string.lower(m.Name)
			local score = 0
			for _, w in ipairs(MOD_WORDS) do
				if string.find(l, w, 1, true) then
					score = math.max(score, w == "rarity" and 3 or (w == "item" or w == "config" or w == "data") and 2 or 1)
				end
			end
			if score > 0 then cand[#cand + 1] = { m = m, s = score } elseif #skipped < 40 then skipped[#skipped + 1] = m.Name end
		end
		table.sort(cand, function(a, b) return a.s > b.s end)
		local ctx: any = { nodes = 0, orders = {}, defs = {}, items = {}, nItems = 0 }
		local modLog: { string } = {}
		for i, c in ipairs(cand) do
			if i > 60 then
				modLog[#modLog + 1] = "(+" .. (#cand - 60) .. " modul kandidat lain tidak dibaca)"
				break
			end
			setStatus(string.format("Membaca modul %d/%d: %s", i, math.min(#cand, 60), c.m.Name))
			local before = ctx.nItems + #ctx.orders + #ctx.defs
			local res = safeRequire(c.m)
			if type(res) == "table" then
				pcall(walkData, res, c.m.Name, ctx)
				local got = ctx.nItems + #ctx.orders + #ctx.defs - before
				modLog[#modLog + 1] = c.m:GetFullName() .. (got > 0 and (" -> " .. got .. " temuan") or " -> tidak ada info rarity")
			else
				modLog[#modLog + 1] = c.m:GetFullName() .. " -> tidak bisa dimuat / bukan tabel"
			end
		end

		-- urutan rarity
		add("")
		add("[2] URUTAN RARITY DARI DATA GAME")
		if #ctx.orders == 0 and #ctx.defs == 0 then
			add("  (tidak ditemukan daftar urutan rarity di modul)")
		end
		for _, o in ipairs(ctx.orders) do
			add("  daftar: " .. o.path .. " -> " .. table.concat(o.list, " < "))
		end
		for _, d in ipairs(ctx.defs) do
			add("  detail: " .. d.path)
			for _, r in ipairs(d.rows) do add("     " .. r) end
		end

		-- item per rarity
		local groups: { [string]: any } = {}
		for _, it in ipairs(ctx.items) do
			local key, label, rank
			if type(it.r) == "number" then
				key, label, rank = "tier" .. tostring(it.r), "tier " .. tostring(it.r), 100 + it.r
			else
				key = norm(it.r)
				label = tostring(it.r)
				rank = RW_ORDER[key] or 50
			end
			local g = groups[key]
			if not g then
				g = { label = label, rank = rank, n = 0, names = {}, seen = {}, tier = type(it.r) == "number" and it.r or nil }
				groups[key] = g
			end
			g.n += 1
			if #g.names < 12 and not g.seen[it.n] then
				g.seen[it.n] = true
				g.names[#g.names + 1] = it.n
			end
		end
		local glist: { any } = {}
		for _, g in pairs(groups) do glist[#glist + 1] = g end
		table.sort(glist, function(a, b)
			if a.rank ~= b.rank then return a.rank < b.rank end
			return a.label < b.label
		end)
		add("")
		add("[3] ITEM PER RARITY (dari modul data): " .. #ctx.items .. " entri")
		if #glist == 0 then add("  (tidak ada entri item ber-rarity di modul)") end
		local firstOrder = ctx.orders[1]
		for _, g in ipairs(glist) do
			local extra = ""
			if g.tier and firstOrder and firstOrder.list[g.tier] then
				extra = " (kemungkinan = " .. tostring(firstOrder.list[g.tier]) .. ", cocokkan dengan item yang Anda tahu)"
			end
			add(string.format("  %s%s: %d item | %s", g.label, extra, g.n, table.concat(g.names, ", ")))
		end

		-- sumber lain
		add("")
		add("[4] SUMBER LAIN DI REPLICATEDSTORAGE")
		add("  Atribut/Value berinfo rarity: " .. #rsHits)
		for i = 1, math.min(#rsHits, 8) do add("   - " .. rsHits[i]) end
		add("  Folder bernama rarity: " .. #folders)
		for i = 1, math.min(#folders, 8) do add("   - " .. folders[i]) end
		add("  Modul dibaca:")
		for _, ln in ipairs(modLog) do add("   - " .. ln) end
		if #skipped > 0 then add("  Modul tidak dibaca (nama tidak mirip data): " .. table.concat(skipped, ", ")) end

		-- warna rarity di UI
		setStatus("Membaca warna rarity di UI...")
		add("")
		add("[5] WARNA RARITY DI UI (label/bingkai yang bernama rarity)")
		local colorRows, seenW = {}, {}
		for _, d in ipairs(playerGui:GetDescendants()) do
			maybeYield()
			if #colorRows >= 30 then break end
			if not d:IsDescendantOf(gui) then
				local word, col
				if d:IsA("TextLabel") or d:IsA("TextButton") then
					if isRW(d.Text) then word, col = d.Text, d.TextColor3 end
				end
				if not word and (d:IsA("Frame") or d:IsA("ImageLabel")) and isRW(d.Name) then
					word, col = d.Name, (d :: any).BackgroundColor3
				end
				if word and col and not seenW[norm(word) .. col:ToHex()] then
					seenW[norm(word) .. col:ToHex()] = true
					colorRows[#colorRows + 1] = string.format("  %s -> #%s (%s)", tostring(word), col:ToHex(), relPath(d))
				end
			end
		end
		if #colorRows == 0 then add("  (tidak ada; buka menu inventory/koleksi lalu scan lagi)") end
		for _, r in ipairs(colorRows) do add(r) end

		-- lokasi ringkas
		add("")
		add("[6] LOKASI & STATUS")
		if hrp then
			local pp = hrp.Position
			add(string.format("  Posisi: %.0f, %.0f, %.0f", pp.X, pp.Y, pp.Z))
		end
		local function attrs(label: string, inst: Instance?)
			if not inst then return end
			for k, v in pairs(inst:GetAttributes()) do add("  " .. label .. " attr " .. tostring(k) .. " = " .. cut(v, 40)) end
		end
		attrs("Player", player)
		attrs("Character", player.Character)
		attrs("Workspace", workspace)
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			for _, v in ipairs(ls:GetChildren()) do
				local okv, val = pcall(function() return (v :: any).Value end)
				add("  leaderstats " .. v.Name .. " = " .. tostring(okv and val or "?"))
			end
		end

		local verdict, col
		if #ctx.items > 0 or #ctx.orders > 0 or #ctx.defs > 0 then
			verdict = string.format("TERDETEKSI: %d item ber-rarity, %d daftar urutan, %d tabel detail rarity.", #ctx.items, #ctx.orders, #ctx.defs)
			col = T.good
		elseif withEv > 0 or #rsHits > 0 or #folders > 0 then
			verdict = "SEBAGIAN: ada petunjuk rarity (atribut/folder/item) tapi belum ada data lengkap. Salin hasilnya untuk dicek."
			col = Color3.fromRGB(255, 176, 72)
		else
			verdict = "TIDAK TERDETEKSI: game tampaknya menyembunyikan rarity (server-side) sampai item didapat. Salin hasilnya tetap berguna."
			col = T.danger
		end
		add("")
		add("KESIMPULAN: " .. verdict)
		return table.concat(L, "\n"), verdict, col
	end

	-- =================================================================================
	-- B) REKAM MINIGAME
	-- =================================================================================
	local R: any = { rec = false, conns = {}, mode = "Bebas", ctx = "", fileName = nil, fileOk = nil, hasData = false, tEnd = 0 }

	local function resetData()
		R.objs, R.nObjs, R.nSamples, R.samplesFull, R.nTexts = {}, 0, 0, false, 0
		R.hot, R.vis = {}, {}
		R.events, R.nEvents, R.eventsFull = {}, 0, false
		R.trials, R.trialsFull = {}, false
		R.rate, R.prompts = {}, {}
		R.outbuf, R.keep = {}, {}
		R.idSeq = 0
		R.pendingNote = nil
		R.nValueHooks = 0
		R.t0 = os.clock()
		R.tEnd = 0
		R.lastFlush = os.clock()
		R.hasData = false
	end
	resetData()

	local function now(): number
		return os.clock() - R.t0
	end

	local function stripDigits(s: string): string
		return (string.gsub(string.lower(s), "%d+", "#"))
	end

	-- ---------- penulisan file (streaming) ----------
	local function out(line: string)
		R.outbuf[#R.outbuf + 1] = line
		if not fsAppend and #R.keep < 400000 then R.keep[#R.keep + 1] = line end
	end

	local function flushOut(force: boolean)
		if not R.fileName then return end
		if fsAppend then
			if #R.outbuf == 0 then return end
			R.fileOk = appendFile(R.fileName, table.concat(R.outbuf, "\n") .. "\n")
			table.clear(R.outbuf)
		elseif fsWrite then
			-- tanpa appendfile: tulis ulang seluruh file jarang-jarang (tiap 10 dtk) dan saat berhenti
			if force or os.clock() - R.lastFlush >= 10 then
				R.fileOk = saveFile(R.fileName, table.concat(R.keep, "\n") .. "\n")
				R.lastFlush = os.clock()
			end
			table.clear(R.outbuf)
		else
			table.clear(R.outbuf)
		end
	end

	local function addEvent(kind: string, msg: string, sig: string?)
		if R.nEvents >= CFG.maxEvents then
			R.eventsFull = true
			return
		end
		local t = now()
		R.nEvents += 1
		R.events[R.nEvents] = { t = t, k = kind, m = msg, s = sig or stripDigits(msg) }
		out(string.format("E|%.3f|%s|%s", t, kind, cut(msg, 220)))
	end

	-- pembatas laju: teks/remote yang berubah sangat cepat (timer) tidak membanjiri catatan
	local function rateOk(key: any, limit: number, label: string): boolean
		local t = os.clock()
		local r = R.rate[key]
		if not r then
			r = { w = t, n = 0, flagged = false }
			R.rate[key] = r
		end
		if t - r.w > 1 then
			if r.n <= limit then r.flagged = false end
			r.w, r.n = t, 0
		end
		r.n += 1
		if r.n > limit then
			if not r.flagged then
				r.flagged = true
				addEvent("RAMAI", label .. " berubah sangat cepat (timer/ticker); selebihnya tidak dicatat", "ramai:" .. label)
			end
			return false
		end
		return true
	end

	local function addConn(c: RBXScriptConnection)
		R.conns[#R.conns + 1] = c
	end
	local function stopConns()
		for _, c in ipairs(R.conns) do pcall(function() c:Disconnect() end) end
		table.clear(R.conns)
	end

	local function ser(v: any, depth: number): string
		local ty = typeof(v)
		if ty == "string" then
			return '"' .. string.sub(v, 1, 40) .. '"'
		elseif ty == "table" then
			if depth >= 2 then return "{...}" end
			local parts, n = {}, 0
			for k, x in pairs(v) do
				n += 1
				if n > 6 then parts[#parts + 1] = "..." break end
				parts[#parts + 1] = tostring(k) .. "=" .. ser(x, depth + 1)
			end
			return "{" .. table.concat(parts, ", ") .. "}"
		elseif ty == "Instance" then
			local ok, nm = pcall(function() return v:GetFullName() end)
			return ok and nm or "Instance"
		end
		return tostring(v)
	end


	-- Recorder V2: bounded independent evidence; legacy five-column samples stay compatible.
	local V2 = {lines={}, bytes=0, count=0, limit=90000, full=false, held={}, last={}}
	function V2.reset()
		V2.lines={}; V2.bytes=0; V2.count=0; V2.full=false; V2.held={}; V2.last={}
	end
	function V2.own(inst)
		local p=inst
		while p and p~=playerGui do
			if p==gui or p.Name=="UU_NPC" or p.Name=="UU_ITEMS" or p.Name=="UU_RARITY" or p.Name=="UU_ZONE" or p.Name=="UU_CHESS" then return true end
			p=p.Parent
		end
		return false
	end
	function V2.put(line)
		if V2.bytes+#line+1>V2.limit then V2.full=true; return end
		V2.lines[#V2.lines+1]=line; V2.bytes+=#line+1
		out("V2|"..line)
	end
	function V2.encode(value)
		local budget=2500
		local seen={}
		local function walk(v,depth)
			budget-=1
			if budget<=0 then return "<node limit>" end
			local ty=typeof(v)
			if ty=="string" then return string.sub(v,1,600) end
			if ty=="number" then return (v==v and math.abs(v)<math.huge) and v or tostring(v) end
			if ty=="boolean" or ty=="nil" then return v end
			if ty~="table" then return tostring(v) end
			if seen[v] then return "<cycle>" end
			if depth>=7 then return "<depth limit>" end
			seen[v]=true
			local r={}; local n=0
			for k,x in pairs(v) do
				n+=1; if n>100 then r["__truncated"]="key limit"; break end
				r[tostring(k)]=walk(x,depth+1)
			end
			seen[v]=nil; return r
		end
		local ok,encoded=pcall(function() return game:GetService("HttpService"):JSONEncode(walk(value,0)) end)
		return ok and string.sub(encoded,1,14000) or "<serialization failed>"
	end
	function V2.prop(inst,o,prop,t)
		if V2.full or not R.rec or V2.own(inst) then return end
		local ok,value=pcall(function() return (inst :: any)[prop] end)
		if not ok then return end
		local encoded
		local ty=typeof(value)
		if ty=="Color3" then encoded=value:ToHex()
		elseif ty=="Vector2" or ty=="UDim2" or ty=="Vector3" then encoded=tostring(value)
		elseif ty=="string" then encoded=string.sub(value,1,220)
		else encoded=tostring(value) end
		V2.put(string.format("PROP|%d|%.4f|%s|%s",o.id,t or now(),prop,string.gsub(encoded,"[\r\n|]"," ")))
	end
	function V2.sample(inst,o,t,force)
		if V2.full or not R.rec or V2.own(inst) then return end
		local last=V2.last[inst]
		if not force and last and t-last.t<0.033 then return end
		local p,z=inst.AbsolutePosition,inst.AbsoluteSize
		local rot=inst.Rotation
		local absrot=rot; pcall(function() absrot=inst.AbsoluteRotation end)
		local row=string.format("%.2f|%.2f|%.2f|%.2f|%.3f|%.3f",p.X+z.X/2,p.Y+z.Y/2,z.X,z.Y,rot,absrot)
		if not force and last and last.row==row then return end
		if not last then
			V2.put("OBJECT|"..o.id.."|"..o.path.."|"..o.cls.."|attrs="..V2.encode(inst:GetAttributes()))
			-- Snapshot detailed properties only for likely puzzle UI; live changes remain watched globally.
			local lp=string.lower(o.path)
			local relevant=false
			for _,word in ipairs({"minigame","puzzle","challenge","stage","lock","pin","marker","target","sweet","perfect","zone","bar","dial","wheel","sequence","memory","timer","prompt"}) do
				if string.find(lp,word,1,true) then relevant=true break end
			end
			if relevant or inst:IsA("TextButton") or inst:IsA("ImageButton") then
				if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
					V2.prop(inst,o,"Text",t); V2.prop(inst,o,"TextColor3",t); V2.prop(inst,o,"TextTransparency",t); V2.prop(inst,o,"TextSize",t)
				end
				if inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
					V2.prop(inst,o,"Image",t); V2.prop(inst,o,"ImageColor3",t); V2.prop(inst,o,"ImageTransparency",t)
				end
				local bgOk,bg=pcall(function() return inst.BackgroundTransparency end)
				if bgOk and bg<0.98 then V2.prop(inst,o,"BackgroundColor3",t); V2.prop(inst,o,"BackgroundTransparency",t) end
			end
		end
		V2.last[inst]={t=t,row=row}; V2.count+=1
		V2.put(string.format("POSE|%d|%.4f|%s",o.id,t,row))
	end

	-- ---------- pemantauan posisi objek UI ----------
	local promote: any, sampleObj: any

	local function connectVis(a: Instance)
		if R.vis[a] or a == playerGui or not R.rec then return end
		R.vis[a] = true
		local prop = nil
		if a:IsA("LayerCollector") then prop = "Enabled" elseif a:IsA("GuiObject") then prop = "Visible" end
		if not prop or a:IsDescendantOf(gui) then return end
		addConn(a:GetPropertyChangedSignal(prop):Connect(function()
			if not R.rec then return end
			if not rateOk(a, 6, a.Name) then return end
			local on = (a :: any)[prop]
			addEvent(on and "TAMPIL" or "SEMBUNYI", relPath(a), (on and "tampil:" or "sembunyi:") .. a.Name)
		end))
	end

	local function baseline(inst: Instance)
		local g: Instance? = inst.Parent
		if g and g.Parent and g.Parent ~= playerGui then g = g.Parent end
		if not g then return end
		local n = 0
		for _, d in ipairs(g:GetDescendants()) do
			n += 1
			if n > 80 then break end
			local o = R.objs[d]
			if o and not o.base and shown(d) then
				o.base = true
				sampleObj(d, o, now())
			end
		end
	end

	promote = function(inst: any, o: any)
		o.hot = true
		R.hot[#R.hot + 1] = inst
		local cur = inst.Parent
		while cur and cur ~= playerGui do
			connectVis(cur)
			cur = cur.Parent
		end
		baseline(inst)
	end

	sampleObj = function(inst: any, o: any, t: number)
		if not R.rec then return end
		V2.sample(inst, o, t, false)
		local p, s = inst.AbsolutePosition, inst.AbsoluteSize
		if s.X < 1 and s.Y < 1 then return end
		local cx, cy = p.X + s.X / 2, p.Y + s.Y / 2
		local sr = o.series
		local n = #sr
		if n >= 5 and math.abs(sr[n - 3] - cx) < 0.01 and math.abs(sr[n - 2] - cy) < 0.01
			and math.abs(sr[n - 1] - s.X) < 0.01 and math.abs(sr[n] - s.Y) < 0.01 then
			return
		end
		if R.nSamples >= CFG.maxSamples then
			R.samplesFull = true
			return
		end
		if not o.written then
			o.written = true
			out(string.format("O|%d|%s|%s|#%s", o.id, o.path, o.cls, o.color))
		end
		sr[n + 1], sr[n + 2], sr[n + 3], sr[n + 4], sr[n + 5] = t, cx, cy, s.X, s.Y
		R.nSamples += 1
		o.cnt += 1
		out(string.format("S|%d|%.3f|%.2f|%.2f|%.2f|%.2f", o.id, t, cx, cy, s.X, s.Y))
		if not o.hot and o.cnt >= 3 then promote(inst, o) end
	end

	local function onText(inst: any)
		if not R.rec or V2.own(inst) then return end
		local txt = inst.Text
		if txt == "" or not shown(inst) then return end
		if not rateOk(inst, 6, inst.Name) then return end
		addEvent("TEKS", inst.Name .. ": '" .. cut(txt, 80) .. "' (" .. cut(relPath(inst), 60) .. ")", "teks:" .. stripDigits(cut(txt, 60)))
	end

	local function consider(inst: Instance)
		if R.objs[inst] or R.nObjs >= CFG.maxObjs or not R.rec then return end
		if not inst:IsA("GuiObject") or V2.own(inst) then return end
		local cls = inst.ClassName
		if cls == "ScrollingFrame" or cls == "ViewportFrame" then return end
		local i: any = inst
		local vp = viewport()
		local sz = i.AbsoluteSize
		if sz.X >= vp.X * 0.9 and sz.Y >= vp.Y * 0.9 then return end

		R.idSeq += 1
		local o: any = {
			id = R.idSeq, path = relPath(inst), cls = cls, color = i.BackgroundColor3:ToHex(),
			series = {}, written = false, hot = false, base = false, cnt = 0,
		}
		R.objs[inst] = o
		R.nObjs += 1

		local function onChange()
			if R.rec and inst.Parent and shown(inst) then sampleObj(inst, o, now()) end
		end
		addConn(i:GetPropertyChangedSignal("AbsolutePosition"):Connect(onChange))
		addConn(i:GetPropertyChangedSignal("AbsoluteSize"):Connect(onChange))
		addConn(i:GetPropertyChangedSignal("Rotation"):Connect(onChange))
		pcall(function() addConn(i:GetPropertyChangedSignal("AbsoluteRotation"):Connect(onChange)) end)
		addConn(i.AttributeChanged:Connect(function(name)
			if R.rec and not V2.full then V2.put(string.format("ATTR|%d|%.4f|%s|%s",o.id,now(),name,V2.encode(i:GetAttribute(name)))) end
		end))
		-- Capture non-positional UI changes too: text, image, tint, transparency and button state.
		local watchProps={"BackgroundColor3","BackgroundTransparency","ZIndex","LayoutOrder","AnchorPoint"}
		if inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox") then
			for _,prop in ipairs({"Text","TextColor3","TextTransparency","TextScaled","TextSize"}) do watchProps[#watchProps+1]=prop end
		elseif inst:IsA("ImageLabel") or inst:IsA("ImageButton") then
			for _,prop in ipairs({"Image","ImageColor3","ImageTransparency","ImageRectOffset","ImageRectSize"}) do watchProps[#watchProps+1]=prop end
		end
		for _,prop in ipairs(watchProps) do
			local okSignal,signal=pcall(function() return i:GetPropertyChangedSignal(prop) end)
			if okSignal and signal then
				addConn(signal:Connect(function()
					if R.rec and rateOk(tostring(inst)..":"..prop,18,inst.Name..":"..prop) then
						V2.prop(i,o,prop,now())
						addEvent("UI_PROPERTY",o.path.."."..prop.."="..cut(V2.encode((function() local ok,v=pcall(function() return (i :: any)[prop] end); return ok and v or "?" end)()),100),"uiprop:"..prop)
					end
				end))
			end
		end
		if inst:IsA("GuiButton") then
			addConn((inst :: GuiButton).Activated:Connect(function()
				if R.rec then addEvent("BUTTON_ACTIVATED",o.path,"button:"..o.path); V2.put(string.format("BUTTON|%.4f|%d|%s",now(),o.id,o.path)) end
			end))
		end
		if shown(inst) then V2.sample(i,o,now(),true) end


		if (cls == "TextLabel" or cls == "TextButton") and R.nTexts < 3000 then
			R.nTexts += 1
			addConn(i:GetPropertyChangedSignal("Text"):Connect(function() onText(inst) end))
		end

		local depth, cur = 0, inst.Parent
		while cur and cur ~= playerGui do
			depth += 1
			cur = cur.Parent
		end
		if depth <= 3 then connectVis(inst) end
	end

	-- ---------- target terdekat (jenis objek/item yang sedang diproses) ----------
	local function nearestTarget(): (string, string)
		local ch = player.Character
		local hrp = ch and ch:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then return "", "" end
		local best: ProximityPrompt? = nil
		local bd = 25
		for pr in pairs(R.prompts) do
			if pr.Parent then
				local par: any = pr.Parent
				local pos: Vector3? = nil
				if par:IsA("BasePart") then
					pos = par.Position
				elseif par:IsA("Attachment") then
					pos = par.WorldPosition
				else
					local m = pr:FindFirstAncestorOfClass("Model")
					if m then
						local ok, pv = pcall(function() return m:GetPivot().Position end)
						if ok then pos = pv end
					end
				end
				if pos then
					local d = (pos - hrp.Position).Magnitude
					if d < bd then
						bd, best = d, pr
					end
				end
			else
				R.prompts[pr] = nil
			end
		end
		if not best then return "", "" end
		local m = best:FindFirstAncestorOfClass("Model")
		local name = m and m.Name or (best.Parent and best.Parent.Name) or best.Name
		local ak = {}
		if m then
			for k, v in pairs(m:GetAttributes()) do
				if #ak < 6 then ak[#ak + 1] = tostring(k) .. "=" .. cut(v, 18) end
			end
			table.sort(ak)
		end
		return name, string.format("%s | prompt '%s' | %.1f st%s", name, best.ObjectText, bd, #ak > 0 and (" | " .. table.concat(ak, ",")) or "")
	end

	local function recordTrial(label: string)
		if #R.trials >= CFG.maxTrials then
			R.trialsFull = true
			return
		end
		local t = now()
		for _, inst in ipairs(R.hot) do
			local o = R.objs[inst]
			if o and inst.Parent and shown(inst) then sampleObj(inst, o, t) end
		end
		local nm, nInfo = nearestTarget()
		local tr = {
			id = #R.trials + 1, t = t, key = label, mode = R.mode, ctx = R.ctx,
			near = nm, nearInfo = nInfo, note = R.pendingNote or "",
		}
		R.pendingNote = nil
		R.trials[tr.id] = tr
		out(string.format("T|%d|%.3f|%s|%s|%s|%s", tr.id, t, label, R.mode, cut(R.ctx, 60), cut(nInfo, 160)))
	end

	local function hookRemote(d: Instance)
		if not d:IsA("RemoteEvent") then return end
		addConn((d :: any).OnClientEvent:Connect(function(...)
			if not R.rec or not rateOk(d, 20, d.Name) then return end
			local args = table.pack(...)
			if string.find(string.lower(d.Name),"minigame",1,true) then
				V2.put(string.format("REMOTE_DETAIL|%.4f|%s|%s",now(),d:GetFullName(),V2.encode(args)))
			end

			local parts = {}
			for i = 1, math.min(args.n, 6) do parts[#parts + 1] = ser(args[i], 0) end
			addEvent("REMOTE", d.Name .. "(" .. cut(table.concat(parts, ", "), 160) .. ")", "remote:" .. d.Name)
		end))
	end

	local function stopRec() end -- diisi di bawah (butuh buildMini)
	local function hookValue(inst: Instance)
		if not inst:IsA("ValueBase") or V2.held[inst] or R.nValueHooks>=450 then return end
		V2.held[inst]=true
		R.nValueHooks+=1
		local ok,value=pcall(function() return (inst :: any).Value end)
		if ok and R.rec then V2.put("VALUE_INIT|"..relPath(inst).."|"..V2.encode(value)) end
		addConn((inst :: any):GetPropertyChangedSignal("Value"):Connect(function()
			if not R.rec or not rateOk(inst,24,inst.Name) then return end
			local good,newValue=pcall(function() return (inst :: any).Value end)
			if good then
				V2.put("VALUE|"..string.format("%.4f",now()).."|"..relPath(inst).."|"..V2.encode(newValue))
				addEvent("VALUE_CHANGED",relPath(inst).."="..cut(V2.encode(newValue),100),"value:"..inst.Name)
			end
		end))
	end
	local function startRec()
		stopConns()
		resetData()
		V2.reset()
		R.stamp = tostring(os.time())
		pcall(function() R.stamp = os.date("!%Y%m%d_%H%M%S") end)
		R.fileName = string.format("minigame_%s_%s.csv", tostring(game.GameId), R.stamp)
		R.summaryName = string.format("minigame_%s_%s_ringkasan.txt", tostring(game.GameId), R.stamp)
		R.rec = true
		R.hasData = true
		local vp = viewport()
		out("# UNIVERSAL UI SCAN MINIGAME | GameId " .. tostring(game.GameId) .. " | PlaceId " .. tostring(game.PlaceId)
			.. string.format(" | layar %dx%d", math.floor(vp.X), math.floor(vp.Y)))
		out("# format: O|id|path|kelas|warna  S|id|t|cx|cy|w|h (px absolut)  T|no|t|tombol|mode|konteks|target  E|t|jenis|pesan")
		flushOut(true)

		-- masukan: tiap tekan/klik = satu percobaan (putaran)
		addConn(UIS.InputBegan:Connect(function(input)
			if not R.rec then return end
			local ut = input.UserInputType
			local label: string? = nil
			if ut == Enum.UserInputType.MouseButton1 then label = "Klik-Kiri"
			elseif ut == Enum.UserInputType.MouseButton2 then label = "Klik-Kanan"
			elseif ut == Enum.UserInputType.MouseButton3 then label = "Klik-Tengah"
			elseif ut == Enum.UserInputType.Touch then label = "Tap"
			elseif ut == Enum.UserInputType.Keyboard then
				if input.KeyCode == settings.toggleKey then return end
				label = input.KeyCode.Name
			elseif string.find(tostring(ut),"Gamepad",1,true) then
				label = "Gamepad:" .. input.KeyCode.Name
			end
			if not label or UIS:GetFocusedTextBox() then return end
			if ut ~= Enum.UserInputType.Keyboard then
				local okG, hit = pcall(function() return playerGui:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) end)
				if okG then
					for _, g in ipairs(hit) do
						if g:IsDescendantOf(gui) then return end -- klik pada panel ini: bukan tekanan minigame
					end
				end
			end
			recordTrial(label)
			V2.held[label]={t=now(),id=#R.trials}
			V2.put(string.format("INPUT_DOWN|%.4f|%s|trial=%d|pointer=%s",now(),label,#R.trials,tostring(input.Position)))
			for obj,info in pairs(R.objs) do
				if obj.Parent and shown(obj) and string.find(string.lower(info.path),"minigame",1,true) then V2.sample(obj,info,now(),true) end
			end

		end))

		addConn(UIS.InputEnded:Connect(function(input)
			if not R.rec then return end
			local ty=input.UserInputType
			local label=ty==Enum.UserInputType.Keyboard and input.KeyCode.Name
				or (ty==Enum.UserInputType.MouseButton1 and "Klik-Kiri")
				or (ty==Enum.UserInputType.MouseButton2 and "Klik-Kanan")
				or (ty==Enum.UserInputType.MouseButton3 and "Klik-Tengah")
				or (ty==Enum.UserInputType.Touch and "Tap")
				or (string.find(tostring(ty),"Gamepad",1,true) and ("Gamepad:"..input.KeyCode.Name))
			local h=label and V2.held[label]
			if h then
				V2.put(string.format("INPUT_UP|%.4f|%s|trial=%d|hold=%.4f",now(),label,h.id,now()-h.t))
				V2.held[label]=nil
			end
		end))
		-- Continuous pointer/analog movement: sampled at a bounded rate for drag, swipe and stick minigames.
		addConn(UIS.InputChanged:Connect(function(input)
			if not R.rec then return end
			local ty=input.UserInputType
			if ty==Enum.UserInputType.MouseMovement or ty==Enum.UserInputType.MouseWheel or ty==Enum.UserInputType.Touch or string.find(tostring(ty),"Gamepad",1,true) then
				if rateOk("pointer-move",12,"pointer-move") then
					local pos=input.Position
					local delta=input.Delta
					V2.put(string.format("INPUT_MOVE|%.4f|%s|pos=%s|delta=%s",now(),tostring(ty),tostring(pos),tostring(delta)))
				end
			end
		end))

		-- GUI baru
		addConn(playerGui.DescendantAdded:Connect(function(d)
			task.defer(function()
				if not R.rec then return end
				consider(d)
				if d.Parent == playerGui and d ~= gui and not d:IsDescendantOf(gui) then
					addEvent("GUI BARU", d.Name, "guibaru:" .. d.Name)
				end
			end)
		end))

		-- server -> client (hanya mendengarkan)
		for _, d in ipairs(RS:GetDescendants()) do
			hookRemote(d)
			hookValue(d)
		end
		addConn(RS.DescendantAdded:Connect(function(d) hookRemote(d); hookValue(d) end))
		for _,d in ipairs(playerGui:GetDescendants()) do hookValue(d) end
		addConn(playerGui.DescendantAdded:Connect(function(d) task.defer(function() if R.rec then hookValue(d) end end) end))

		-- prompt: objek/item yang sedang ditarget
		addConn(workspace.DescendantAdded:Connect(function(d)
			if d:IsA("ProximityPrompt") then R.prompts[d] = true end
			hookValue(d)
			if d:IsA("GuiObject") then task.defer(function() if R.rec then consider(d) end end) end
		end))
		local function pname(pr: ProximityPrompt): string
			local m = pr:FindFirstAncestorOfClass("Model")
			return (m and m.Name or (pr.Parent and pr.Parent.Name) or "?") .. " '" .. pr.ObjectText .. "'"
		end
		addConn(PPS.PromptButtonHoldBegan:Connect(function(pr) addEvent("PROMPT", "tahan mulai: " .. pname(pr), "prompt:tahan mulai") end))
		addConn(PPS.PromptButtonHoldEnded:Connect(function(pr) addEvent("PROMPT", "tahan lepas: " .. pname(pr), "prompt:tahan lepas") end))
		addConn(PPS.PromptTriggered:Connect(function(pr) addEvent("PROMPT", "terpicu: " .. pname(pr), "prompt:terpicu") end))

		-- hasil di sisi pemain: statistik, atribut, item masuk
		addConn(player.AttributeChanged:Connect(function(a)
			if R.rec and rateOk("pa" .. a, 6, a) then
				addEvent("ATRIBUT", "player." .. a .. "=" .. cut(player:GetAttribute(a), 40), "atribut:" .. a)
			end
		end))
		local ls = player:FindFirstChild("leaderstats")
		if ls then
			for _, v in ipairs(ls:GetChildren()) do
				if v:IsA("ValueBase") then
					local last = (v :: any).Value
					addConn((v :: any):GetPropertyChangedSignal("Value"):Connect(function()
						local nv = (v :: any).Value
						addEvent("STAT", v.Name .. ": " .. tostring(last) .. " -> " .. tostring(nv), "stat:" .. v.Name)
						last = nv
					end))
				end
			end
		end
		local bp = player:FindFirstChildOfClass("Backpack")
		if bp then
			addConn(bp.ChildAdded:Connect(function(c) addEvent("ITEM", "+ " .. c.Name, "item+:" .. stripDigits(c.Name)) end))
			addConn(bp.ChildRemoved:Connect(function(c) addEvent("ITEM", "- " .. c.Name, "item-:" .. stripDigits(c.Name)) end))
		end

		-- model/benda di dekat yang hilang (mis. objek rusak/diambil)
		addConn(workspace.DescendantRemoving:Connect(function(d)
			if not R.rec then return end
			local isM = d:IsA("Model")
			if not (isM or (d:IsA("BasePart") and d.Parent and not d.Parent:IsA("Model"))) then return end
			local chr = player.Character
			if not chr or d == chr or d:IsDescendantOf(chr) then return end
			local hrp = chr:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not hrp then return end
			local ok, pos = pcall(function()
				if isM then return (d :: any):GetPivot().Position end
				return (d :: any).Position
			end)
			if not ok then return end
			local dist = (pos - hrp.Position).Magnitude
			if dist > 60 or not rateOk("rm", 20, "model hilang") then return end
			addEvent("MODEL HILANG", string.format("%s (%s, %d st)", d.Name, d.ClassName, math.floor(dist)), "hilang:" .. stripDigits(d.Name))
		end))

		-- pemindaian awal (dipecah supaya tidak membuat game patah-patah)
		task.spawn(function()
			for _, d in ipairs(playerGui:GetDescendants()) do
				if not R.rec then return end
				consider(d)
				maybeYield()
			end
			for _, sg in ipairs(playerGui:GetChildren()) do
				if R.rec then connectVis(sg) end
			end
		end)
		task.spawn(function()
			for _, d in ipairs(workspace:GetDescendants()) do
				if not R.rec then return end
				if d:IsA("ProximityPrompt") then R.prompts[d] = true end
				hookValue(d)
				if d:IsA("GuiObject") then consider(d) end -- SurfaceGui/BillboardGui minigames in the 3D world
				maybeYield()
			end
		end)
	end

	-- ---------- analisis ----------
	-- posisi objek pada waktu t (tahan nilai terakhir; marker diekstrapolasi < 0.1 dtk dengan kecepatannya)
	local function stateAt(o: any, t: number): (number?, number?, number, number)
		local sr = o.series
		local n = math.floor(#sr / 5)
		if n == 0 then return nil, nil, 0, 1e9 end
		local lo, hi, k = 1, n, 0
		while lo <= hi do
			local mid = (lo + hi) // 2
			if sr[(mid - 1) * 5 + 1] <= t then
				k = mid
				lo = mid + 1
			else
				hi = mid - 1
			end
		end
		if k == 0 then return nil, nil, 0, 1e9 end
		local b = (k - 1) * 5
		local t0, x0, w0 = sr[b + 1], sr[b + 2], sr[b + 4]
		local vel = 0
		if k >= 2 then
			local bj = (math.max(1, k - 2) - 1) * 5
			local dt = t0 - sr[bj + 1]
			if dt > 0 and dt < 0.3 then vel = (x0 - sr[bj + 2]) / dt end
		end
		local age = t - t0
		local x = x0
		if age > 0 and age < 0.1 then x = x0 + vel * age end
		return x, w0, vel, age
	end

	local function fnum(v: number, d: number?): string
		return string.format("%." .. tostring(d or 1) .. "f", v)
	end

	-- V3 layers 2-4: heuristic classifier, cross-signal analysis and implementation-ready evidence.
	local function buildV3Analysis(full:boolean,limit:number):string
		local L={}; local function add(x) L[#L+1]=x end
		local stats={horizontal=0,vertical=0,rotation=0,resize=0,objects=0,pose=0,properties=0,values=0,buttons=0,remote=0,moves=0,inputs=0}
		local candidates={}; local rotRanges={}
		for _,line in ipairs(V2.lines) do
			if string.sub(line,1,5)=="POSE|" then
				stats.pose+=1
				local id,rot,absrot=string.match(line,"^POSE|(%d+)|[^|]+|[^|]+|[^|]+|[^|]+|[^|]+|([^|]+)|([^|]+)")
				if id and rot then local key=tonumber(id); local v=tonumber(rot); if key and v then local rr=rotRanges[key] or {lo=v,hi=v}; rr.lo=math.min(rr.lo,v); rr.hi=math.max(rr.hi,v); rotRanges[key]=rr end end
			elseif string.sub(line,1,7)=="OBJECT|" then stats.objects+=1
			elseif string.sub(line,1,5)=="PROP|" then stats.properties+=1
			elseif string.sub(line,1,6)=="VALUE|" then stats.values+=1
			elseif string.sub(line,1,7)=="BUTTON|" then stats.buttons+=1
			elseif string.sub(line,1,14)=="REMOTE_DETAIL|" then stats.remote+=1
			elseif string.sub(line,1,11)=="INPUT_MOVE|" then stats.moves+=1
			elseif string.sub(line,1,11)=="INPUT_DOWN|" then stats.inputs+=1 end
		end
		for _,o in pairs(R.objs) do
			local sr=o.series; local n=math.floor(#sr/5)
			if n>=3 then
				local minX,maxX,minY,maxY,minW,maxW,minH,maxH=math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge,math.huge,-math.huge
				for k=1,n do local b=(k-1)*5; local x,y,w,h=sr[b+2],sr[b+3],sr[b+4],sr[b+5]
					minX=math.min(minX,x); maxX=math.max(maxX,x); minY=math.min(minY,y); maxY=math.max(maxY,y)
					minW=math.min(minW,w); maxW=math.max(maxW,w); minH=math.min(minH,h); maxH=math.max(maxH,h)
				end
				local rr=rotRanges[o.id] or {lo=0,hi=0}; local minR,maxR=rr.lo,rr.hi
				local rx,ry,rw,rh=maxX-minX,maxY-minY,maxW-minW,maxH-minH
				if rx>18 then stats.horizontal+=1 end; if ry>18 then stats.vertical+=1 end
				if maxR-minR>20 then stats.rotation+=1 end; if rw>8 or rh>8 then stats.resize+=1 end
				local path=string.lower(o.path); local score=rx+ry+(maxR-minR)*0.8+rw+rh
				if string.find(path,"marker",1,true) or string.find(path,"needle",1,true) or string.find(path,"pick",1,true) or string.find(path,"cursor",1,true) or string.find(path,"arrow",1,true) then score+=80 end
				if string.find(path,"target",1,true) or string.find(path,"sweet",1,true) or string.find(path,"perfect",1,true) or string.find(path,"zone",1,true) then score+=45 end
				if score>15 then candidates[#candidates+1]={o=o,n=n,rx=rx,ry=ry,rr=maxR-minR,rw=rw,rh=rh,score=score} end
			end
		end
		table.sort(candidates,function(a,b) return a.score>b.score end)
		local blob=""
		for _,line in ipairs(V2.lines) do blob..=" "..string.lower(line) end
		local function hasAny(words) for _,w in ipairs(words) do if string.find(blob,w,1,true) then return true end end return false end
		local likely={}
		if hasAny({"lockpick","sweet","pin"}) then likely[#likely+1]="Lockpick / target sudut" end
		if stats.rotation>0 or hasAny({"rotation","needle","dial","wheel","spinner"}) then likely[#likely+1]="Rotasi / timing sudut" end
		if stats.horizontal>0 or hasAny({"marker","bar","slider","progress"}) then likely[#likely+1]="Timing horizontal" end
		if stats.vertical>0 then likely[#likely+1]="Timing vertikal / gerak Y" end
		if stats.values>0 or hasAny({"sequence","memory","pattern","order","stage"}) then likely[#likely+1]="Urutan / state / memory (perlu verifikasi)" end
		if stats.moves>0 then likely[#likely+1]="Drag / swipe / input analog" end
		if stats.properties>0 or hasAny({"color","colour","image","button"}) then likely[#likely+1]="Perubahan visual / tombol" end
		if #likely==0 then likely[1]="Belum cukup bukti untuk mengklasifikasikan" end
		add("== REKAM MINIGAME ==")
		add("LAPISAN 1 - CAPTURE: posisi/ukuran/rotasi UI (ScreenGui/SurfaceGui/BillboardGui), teks/gambar/warna/transparansi, atribut, ValueBase, tombol, input keyboard/mouse/touch/gamepad, RemoteEvent inbound (server->client), prompt, hasil/stat sederhana.")
		add(string.format("Bukti: objek=%d pose=%d perubahan-properti=%d ValueBase=%d tombol-UI=%d detail-remote=%d input-down=%d gerak-pointer=%d",stats.objects,stats.pose,stats.properties,stats.values,stats.buttons,stats.remote,stats.inputs,stats.moves))
		add("LAPISAN 2 - CLASSIFIER (heuristik, bukan kepastian): "..table.concat(likely,"; "))
		add(string.format("Objek dengan gerak terukur: X=%d | Y=%d | rotasi=%d | resize=%d",stats.horizontal,stats.vertical,stats.rotation,stats.resize))
		add("LAPISAN 3 - PATTERN ANALYZER: korelasikan input, perubahan properti/nilai, gerak objek dan event sekitar waktu tekanan. Bandingkan ronde Tepat/Cepat/Telat dan catatan hasil untuk mencari aturan yang konsisten.")
		add("LAPISAN 4 - AUTO MODULE SPEC: gunakan kandidat dan jejak di bawah untuk membuat modul khusus. Recorder tidak mengaktifkan auto-input universal secara otomatis; modul harus divalidasi pada game/minigame terkait.")
		add("KANDIDAT OBJEK BERGERAK (koordinat px absolut; range rotasi dihitung dari sampel POSE):")
		if #candidates==0 then add("  (belum ada kandidat dengan gerak cukup)") end
		for i,c in ipairs(candidates) do if i>math.min(full and 30 or 12,#candidates) then break end
			add(string.format("  #%d id=%d %s | sampel=%d | rangeX=%.1f rangeY=%.1f rangeRot=%.1f° | rangeSize=%.1fx%.1f | skor=%.1f",i,c.o.id,cut(c.o.path,110),c.n,c.rx,c.ry,c.rr,c.rw,c.rh,c.score))
		end
		add("KORELASI INPUT (event relevan dari 0.25 dtk sebelum hingga 1.25 dtk sesudah tekanan):")
		for ti,tr in ipairs(R.trials) do
			if ti>math.min(full and 30 or 12,#R.trials) then break end
			add(string.format("  #%d t=%.3f input=%s mode=%s catatan=%s",tr.id,tr.t,tr.key,tr.mode,cut(tr.note~="" and tr.note or "-",70)))
			local shownEvents=0
			for _,e in ipairs(R.events) do
				if e.t>=tr.t-0.25 and e.t<=tr.t+1.25 and (e.k=="UI_PROPERTY" or e.k=="VALUE_CHANGED" or e.k=="BUTTON_ACTIVATED" or e.k=="REMOTE" or e.k=="TAMPIL" or e.k=="SEMBUNYI" or e.k=="STAT") then
					if shownEvents<5 then add(string.format("    %+0.3fs %s %s",e.t-tr.t,e.k,cut(e.m,100))); shownEvents+=1 end
				end
			end
			if shownEvents==0 then add("    (tidak ada event relevan di jendela ini)") end
			local shownObjects=0
			for ci,c in ipairs(candidates) do
				if ci>3 then break end
				local sr=c.o.series; local best,bestAge=nil,math.huge
				for k=1,c.n do local b=(k-1)*5; local age=math.abs(sr[b+1]-tr.t); if age<bestAge then bestAge=age; best={x=sr[b+2],y=sr[b+3],t=sr[b+1]} end end
				if best and bestAge<=0.35 then add(string.format("    obj#%d %s @input x=%.1f y=%.1f (sampel %.0fms)",c.o.id,cut(c.o.path,55),best.x,best.y,bestAge*1000)); shownObjects+=1 end
			end
			if shownObjects==0 then add("    (tidak ada pose dekat waktu input)") end
		end
		add("INPUT & HASIL: tiap tekanan memiliki timestamp dan label; gunakan mode Tepat/Cepat/Telat serta catatan manual untuk membedakan target yang benar. Tekanan tanpa hasil/catatan tidak cukup untuk menyimpulkan tombol solusi.")
		return table.concat(L,"\n")
	end

	local function buildMini(full: boolean): string
		local L: { string } = {}
		local chars = 0
		local function add(s: string)
			L[#L + 1] = s
			chars += #s + 1
		end
		add("== REKAM MINIGAME: EVIDENCE ==")
		add("POSE columns: object id | time seconds | centerX | centerY | width | height | Rotation degrees | AbsoluteRotation degrees")
		add("Rotation/vertical evidence is independent from legacy horizontal marker detection. Zero active marker trials does NOT prove minigame inactive.")
		add("Bounded detail: 90000 bytes; JSON max depth 7, 100 keys/table, 2500 nodes, 14000 chars/event. Truncation may occur.")
		add("V2 samples: "..tostring(V2.count).." | detail full: "..tostring(V2.full).." | raw file write: "..tostring(R.fileOk))
		local v3ok,v3report=pcall(buildV3Analysis,full,CFG.reportMaxChars)
		if v3ok then add(v3report) else add("V3 analysis unavailable: "..tostring(v3report)) end
		add("== RAW V2 EVIDENCE (may be truncated by evidence budget) ==")
		for _,line in ipairs(V2.lines) do add(line) end
		add("== LEGACY HORIZONTAL ANALYSIS (may not apply to rotation/vertical puzzles) ==")
		local limit = full and 1e9 or CFG.reportMaxChars
		local dur = R.rec and now() or R.tEnd
		local vp = viewport()

		-- 1) klasifikasi objek
		local list: { any } = {}
		for _, o in pairs(R.objs) do
			local sr = o.series
			local n = math.floor(#sr / 5)
			if n >= 1 then
				local xmin, xmax, wmin, wmax = math.huge, -math.huge, math.huge, -math.huge
				local steps, speeds, dts, allDx = {}, {}, {}, {}
				local rev, lastSign, nd, distinct = 0, 0, 0, {}
				for k = 1, n do
					local b = (k - 1) * 5
					local x, w = sr[b + 2], sr[b + 4]
					if x < xmin then xmin = x end
					if x > xmax then xmax = x end
					if w < wmin then wmin = w end
					if w > wmax then wmax = w end
					local key = math.floor(x + 0.5)
					if not distinct[key] then
						distinct[key] = true
						nd += 1
					end
					if k > 1 then
						local dt, dx = sr[b + 1] - sr[b - 4], x - sr[b - 3]
						allDx[#allDx + 1] = math.abs(dx)
						if dt > 0 and dt <= 0.12 then
							steps[#steps + 1] = math.abs(dx)
							speeds[#speeds + 1] = math.abs(dx) / dt
							dts[#dts + 1] = dt
						end
						local sg = (dx > 0.05 and 1) or (dx < -0.05 and -1) or 0
						if sg ~= 0 then
							if lastSign ~= 0 and sg ~= lastSign then rev += 1 end
							lastSign = sg
						end
					end
				end
				local range = xmax - xmin
				local wrap = 0
				for _, dx in ipairs(allDx) do
					if range > 20 and dx > 0.5 * range then wrap += 1 end
				end
				local medStep = median(steps)
				local continuous = n >= 25 and #steps >= 20 and medStep > 0.3 and range > 20
				list[#list + 1] = {
					o = o, n = n, xmin = xmin, xmax = xmax, wmin = wmin, wmax = wmax, nd = nd, range = range,
					medStep = medStep, medSpeed = median(speeds), medDt = median(dts), rev = rev, wrap = wrap,
					continuous = continuous, score = continuous and n * range or 0,
				}
			end
		end

		local M: any = nil
		for _, c in ipairs(list) do
			if c.continuous and (c.rev + c.wrap >= 1 or c.n >= 60) and (not M or c.score > M.score) then M = c end
		end
		local zones: { any } = {}
		if M then
			for _, c in ipairs(list) do
				if c ~= M and c.xmax >= M.xmin - 20 and c.xmin <= M.xmax + 20 and c.wmax >= 2 and c.wmax < 0.9 * M.range then
					zones[#zones + 1] = c
				end
			end
			table.sort(zones, function(a, b)
				if a.nd ~= b.nd then return a.nd > b.nd end
				return a.wmax < b.wmax
			end)
			while #zones > 4 do table.remove(zones) end
		end

		-- 2) evaluasi tiap tekanan
		local trials: { any } = R.trials
		local rows: { any } = {}
		local j0 = 1
		for idx, tr in ipairs(trials) do
			local row: any = { tr = tr, ev = {}, sigs = {} }
			if M then
				local mx, mw, mv, age = stateAt(M.o, tr.t)
				if mx and age <= 0.25 then
					row.m = { x = mx, w = mw, v = mv }
					row.z = {}
					local sign = mv >= 0 and 1 or -1
					for zi, z in ipairs(zones) do
						local zx, zw = stateAt(z.o, tr.t)
						if zx and zw then
							local off = mx - zx
							row.z[zi] = {
								x = zx, w = zw, off = off, late = off * sign,
								ms = off * sign / math.max(math.abs(mv), 1) * 1000,
								inside = math.abs(off) <= zw / 2,
								pct = M.range > 0 and (zx - M.xmin) / M.range * 100 or 0,
							}
						end
					end
				end
			end
			local upper = tr.t + 2.5
			if trials[idx + 1] then upper = math.min(upper, trials[idx + 1].t - 0.02) end
			while R.events[j0] and R.events[j0].t < tr.t - 0.05 do j0 += 1 end
			local j = j0
			while R.events[j] and R.events[j].t <= upper do
				local e = R.events[j]
				if e.k ~= "KONTEKS" and e.k ~= "CATATAN" then
					row.ev[#row.ev + 1] = e
					row.sigs[e.k .. ":" .. e.s] = true
				end
				j += 1
			end
			rows[idx] = row
		end

		local active: { any } = {}
		for _, r in ipairs(rows) do
			if r.m then active[#active + 1] = r end
		end
		local nAct = #active

		-- kejadian konstan (muncul hampir tiap tekan) tidak dipakai untuk membedakan hasil
		local freq: { [string]: number } = {}
		for _, r in ipairs(active) do
			for s in pairs(r.sigs) do freq[s] = (freq[s] or 0) + 1 end
		end
		local constant: { [string]: boolean } = {}
		local constList: { string } = {}
		for s, c in pairs(freq) do
			if nAct >= 5 and c >= 0.9 * nAct then
				constant[s] = true
				constList[#constList + 1] = s
			end
		end
		table.sort(constList)

		-- zona utama: namanya mengandung perfect/hit/target/sweet; kalau tidak ada, yang paling dekat dengan titik tekan
		local pz = 1
		do
			local found = false
			for zi, z in ipairs(zones) do
				local lp = string.lower(z.o.path)
				if string.find(lp, "perfect", 1, true) or string.find(lp, "sweet", 1, true) or string.find(lp, "hit", 1, true) or string.find(lp, "target", 1, true) then
					pz, found = zi, true
					break
				end
			end
			if not found then
				local bestMed = math.huge
				for zi in ipairs(zones) do
					local vals = {}
					for _, r in ipairs(active) do
						if r.z and r.z[zi] then vals[#vals + 1] = math.abs(r.z[zi].off) end
					end
					if #vals > 0 then
						local md = median(vals)
						if md < bestMed then bestMed, pz = md, zi end
					end
				end
			end
		end

		local function resultOf(r: any): string
			local parts = {}
			for _, e in ipairs(r.ev) do
				if e.k ~= "RAMAI" and not constant[e.k .. ":" .. e.s] then
					local p = e.k .. " " .. cut(e.m, 50)
					if #parts < 3 then parts[#parts + 1] = p end
				end
			end
			return #parts > 0 and table.concat(parts, "; ") or "(tidak ada kejadian)"
		end
		local function clusterKey(r: any): string
			local ks = {}
			for s in pairs(r.sigs) do
				if not constant[s] and string.sub(s, 1, 6) ~= "RAMAI:" then ks[#ks + 1] = s end
			end
			table.sort(ks)
			while #ks > 3 do table.remove(ks) end
			return #ks > 0 and cut(table.concat(ks, " + "), 90) or "(tidak ada kejadian)"
		end

		-- ================= LAPORAN =================
		add("== UNIVERSAL UI SCAN: MINIGAME ==")
		add("GameId: " .. tostring(game.GameId) .. " | PlaceId: " .. tostring(game.PlaceId) .. string.format(" | layar %dx%d", math.floor(vp.X), math.floor(vp.Y)))
		add(string.format("Durasi: %.1f dtk | tekan dicatat: %d (aktif saat minigame: %d) | objek: %d | sampel: %d | kejadian: %d",
			dur, #trials, nAct, R.nObjs, R.nSamples, R.nEvents))
		if R.samplesFull or R.eventsFull or R.trialsFull then
			add("PERINGATAN BATAS: " .. (R.samplesFull and "sampel penuh; " or "") .. (R.eventsFull and "kejadian penuh; " or "")
				.. (R.trialsFull and "tekan penuh; " or "") .. "data setelahnya tidak masuk. Rekam ulang lebih pendek.")
		end
		if R.fileName then add("File data mentah lengkap: " .. fpath(R.fileName) .. (R.fileOk == false and " (GAGAL ditulis)" or "")) end

		add("")
		add("## OBJEK UTAMA")
		if not M then
			add("marker: TIDAK TERDETEKSI (tidak ada objek yang bergerak kontinu). Pastikan minigame dimainkan saat Rekam ON.")
		else
			add(string.format("marker (tebakan): %s | warna #%s | %d sampel | X %.0f..%.0f (jalur %.0f px) | lebar %.0f..%.0f",
				M.o.path, M.o.color, M.n, M.xmin, M.xmax, M.range, M.wmin, M.wmax))
			add(string.format("  kecepatan median: %.0f px/dtk (%.2f jalur/dtk) | sampling median: %.1f ms (~%.0f Hz) | balik arah: %d | lompat balik: %d",
				M.medSpeed, M.range > 0 and M.medSpeed / M.range or 0, M.medDt * 1000, M.medDt > 0 and 1 / M.medDt or 0, M.rev, M.wrap))
			for zi, z in ipairs(zones) do
				add(string.format("zona kandidat %d%s: %s | warna #%s | %d sampel, %d posisi berbeda | X %.0f..%.0f | lebar %.0f..%.0f",
					zi, zi == pz and " (UTAMA)" or "", z.o.path, z.o.color, z.n, z.nd, z.xmin, z.xmax, z.wmin, z.wmax))
			end
		end
		add("lainnya yang bergerak/berubah:")
		table.sort(list, function(a, b) return a.n > b.n end)
		local shownOther = 0
		for _, c in ipairs(list) do
			if c ~= M and not table.find(zones, c) and c.n >= 3 then
				shownOther += 1
				if shownOther > 8 then break end
				add(string.format("  - %s | #%s | %d sampel | X %.0f..%.0f | lebar %.0f..%.0f", c.o.path, c.o.color, c.n, c.xmin, c.xmax, c.wmin, c.wmax))
			end
		end
		if shownOther == 0 then add("  (tidak ada)") end
		if #constList > 0 then
			add("kejadian yang muncul hampir tiap tekan (tidak dipakai membedakan hasil):")
			for i = 1, math.min(#constList, 6) do add("  - " .. cut(constList[i], 100)) end
		end

		-- 3) kelompok hasil + batas Perfect
		local clusters: { [string]: any } = {}
		local clist: { any } = {}
		for _, r in ipairs(active) do
			local zz = r.z and r.z[pz]
			if zz then
				local key = clusterKey(r)
				local c = clusters[key]
				if not c then
					c = { key = key, lates = {}, ms = {}, modes = {}, abs = {} }
					clusters[key] = c
					clist[#clist + 1] = c
				end
				c.lates[#c.lates + 1] = zz.late
				c.ms[#c.ms + 1] = zz.ms
				c.abs[#c.abs + 1] = math.abs(zz.late)
				c.modes[r.tr.mode] = (c.modes[r.tr.mode] or 0) + 1
			end
		end
		for _, c in ipairs(clist) do
			c.n = #c.lates
			c.meanAbs = 0
			for _, v in ipairs(c.abs) do c.meanAbs += v end
			c.meanAbs /= math.max(c.n, 1)
			c.min, c.max = math.huge, -math.huge
			c.msMin, c.msMax = math.huge, -math.huge
			for i, v in ipairs(c.lates) do
				if v < c.min then c.min = v end
				if v > c.max then c.max = v end
				if c.ms[i] < c.msMin then c.msMin = c.ms[i] end
				if c.ms[i] > c.msMax then c.msMax = c.ms[i] end
			end
		end
		table.sort(clist, function(a, b) return a.meanAbs < b.meanAbs end)

		add("")
		add("## KELOMPOK HASIL (selisih marker vs zona utama; + = telat, - = terlalu cepat)")
		if #clist == 0 then add("(belum ada tekanan yang bisa dihitung selisihnya)") end
		for _, c in ipairs(clist) do
			local md = {}
			for m, n in pairs(c.modes) do md[#md + 1] = m .. " " .. n end
			table.sort(md)
			add(string.format("- %s | %d tekan | selisih %.1f..%.1f px (%+.0f..%+.0f ms) | mode: %s",
				c.key, c.n, c.min, c.max, c.msMin, c.msMax, table.concat(md, ", ")))
		end

		add("")
		add("## BATAS ZONA TERBAIK / PERFECT (perkiraan dari variasi tekan Anda)")
		if #clist >= 2 then
			local P = clist[1]
			local lowOut, highOut = -math.huge, math.huge
			local lowMs, highMs = 0, 0
			for _, r in ipairs(active) do
				local zz = r.z and r.z[pz]
				if zz and clusterKey(r) ~= P.key then
					if zz.late < P.min and zz.late > lowOut then lowOut, lowMs = zz.late, zz.ms end
					if zz.late > P.max and zz.late < highOut then highOut, highMs = zz.late, zz.ms end
				end
			end
			add("kelompok terdekat ke pusat (dianggap Perfect): " .. P.key)
			add(string.format("  tekan Perfect tercatat dari %.1f sampai %.1f px (%+.0f sampai %+.0f ms)", P.min, P.max, P.msMin, P.msMax))
			add(string.format("  batas CEPAT: di antara %s dan %.1f px", lowOut > -math.huge and fnum(lowOut) or "(tak ada tekan lebih cepat)", P.min))
			add(string.format("  batas TELAT: di antara %.1f dan %s px", P.max, highOut < math.huge and fnum(highOut) or "(tak ada tekan lebih telat)"))
			if lowOut > -math.huge and highOut < math.huge then
				add(string.format("  => lebar toleransi Perfect: antara %.1f dan %.1f px (%.0f..%.0f ms total)", P.max - P.min, highOut - lowOut,
					P.msMax - P.msMin, highMs - lowMs))
			end
			local pzone = zones[pz]
			if pzone then
				add(string.format("  bandingkan: lebar visual zona utama = %.0f..%.0f px", pzone.wmin, pzone.wmax))
			end
		else
			add("Belum cukup variasi hasil. Perlu tekan yang tepat DAN yang sengaja terlalu cepat / telat (masing-masing beberapa kali).")
		end

		-- 4) kesulitan per konteks / per target
		local function groupBy(title: string, keyFn: (any) -> string)
			local g: { [string]: any } = {}
			local order: { string } = {}
			for _, r in ipairs(active) do
				local k = keyFn(r)
				if not g[k] then
					g[k] = { n = 0, zw = {}, sp = {}, hit = 0 }
					order[#order + 1] = k
				end
				local e = g[k]
				e.n += 1
				e.sp[#e.sp + 1] = math.abs(r.m.v)
				local zz = r.z and r.z[pz]
				if zz then
					e.zw[#e.zw + 1] = zz.w
					if zz.inside then e.hit += 1 end
				end
			end
			if #order <= 1 and order[1] == "(tanpa)" then return end
			add("")
			add("## " .. title)
			table.sort(order)
			for _, k in ipairs(order) do
				local e = g[k]
				add(string.format("- %s | %d tekan | lebar zona median %.0f px | kecepatan marker median %.0f px/dtk | tekan di dalam zona: %d", k, e.n, median(e.zw), median(e.sp), e.hit))
			end
		end
		groupBy("KESULITAN PER KONTEKS (jenis/level yang Anda isi)", function(r) return r.tr.ctx ~= "" and r.tr.ctx or "(tanpa)" end)
		groupBy("KESULITAN PER TARGET (objek terdekat saat tekan)", function(r) return r.tr.near ~= "" and r.tr.near or "(tanpa)" end)

		-- 5) tabel tekan
		add("")
		add("## TABEL TEKAN (zona utama; semua selisih: + telat, - cepat)")
		add("no|t(dtk)|tombol|mode|konteks|target|marker x|kec px/dtk|zona x|zona w|zona %jalur|selisih px|selisih ms|dalam|hasil|zona lain|catatan")
		local tableBudget = full and 1e9 or limit * 0.62
		local shownRows, skippedRows = 0, 0
		for _, r in ipairs(rows) do
			local tr = r.tr
			local line
			local zz = r.z and r.z[pz]
			if r.m and zz then
				local others = {}
				for zi, z in pairs(r.z) do
					if zi ~= pz then others[#others + 1] = string.format("z%d:%+.1f", zi, z.late) end
				end
				table.sort(others)
				line = string.format("%d|%.2f|%s|%s|%s|%s|%.1f|%+.0f|%.1f|%.0f|%.0f|%+.1f|%+.0f|%s|%s|%s|%s",
					tr.id, tr.t, tr.key, tr.mode, cut(tr.ctx, 24), cut(tr.near, 24), r.m.x, r.m.v, zz.x, zz.w, zz.pct, zz.late, zz.ms,
					zz.inside and "ya" or "tidak", resultOf(r), table.concat(others, " "), cut(tr.note, 60))
			else
				line = string.format("%d|%.2f|%s|%s|%s|%s|-|-|-|-|-|-|-|-|%s|-|%s (tanpa minigame aktif)", tr.id, tr.t, tr.key, tr.mode,
					cut(tr.ctx, 24), cut(tr.near, 24), resultOf(r), cut(tr.note, 60))
			end
			if shownRows < CFG.tableMaxRows or full then
				if chars + #line < tableBudget then
					add(line)
					shownRows += 1
				else
					skippedRows += 1
				end
			else
				skippedRows += 1
			end
		end
		if skippedRows > 0 then add("... (" .. skippedRows .. " baris lagi ada di file mentah)") end

		-- 6) sampel mentah di sekitar tekanan (bukti resolusi waktu)
		if M and #active > 0 then
			add("")
			add("## SAMPEL MENTAH MARKER DI SEKITAR TEKAN (ms relatif terhadap tekan : x px)")
			local shownRaw = 0
			for _, r in ipairs(active) do
				if shownRaw >= 3 then break end
				shownRaw += 1
				local parts = {}
				local sr = M.o.series
				for k = 1, math.floor(#sr / 5) do
					local b = (k - 1) * 5
					local rel = (sr[b + 1] - r.tr.t) * 1000
					if rel >= -250 and rel <= 100 and #parts < 26 then parts[#parts + 1] = string.format("%+d:%.1f", math.floor(rel + 0.5), sr[b + 2]) end
				end
				add(string.format("tekan #%d: %s", r.tr.id, table.concat(parts, " ")))
			end
		end

		-- 7) kejadian kronologis
		add("")
		add("## KEJADIAN (kronologis)")
		local evBudget = full and 1e9 or limit * 0.97
		local nEv = 0
		for _, e in ipairs(R.events) do
			if e.k ~= "RAMAI" or full then
				local line = string.format("[%7.2f] %s %s", e.t, e.k, cut(e.m, 110))
				if chars + #line >= evBudget then break end
				add(line)
				nEv += 1
			end
		end
		if nEv < R.nEvents then add("... (kejadian lain ada di file mentah)") end
		if #R.events == 0 then add("(tidak ada)") end
		return table.concat(L, "\n")
	end

	-- ---------- berhenti merekam + simpan ringkasan ----------
	stopRec = function()
		if not R.rec then return end
		R.rec = false
		R.tEnd = now()
		stopConns()
		flushOut(true)
		local ok, rep = pcall(buildMini, true)
		if ok then
			R.lastFull = rep
			R.fileSummaryOk = R.summaryName and saveFile(R.summaryName, rep) or false
		else
			warn("[Scan] gagal membuat ringkasan: " .. tostring(rep))
		end
	end

	-- =================================================================================
	-- C) UI  (bagian Scan di tab "Mini Game")
	-- =================================================================================
	local page = pages["Mini Game"] -- Scan digabung ke tab Mini Game; LayoutOrder 100+ supaya di bawah Auto Cut
	local RARITY: any = { report = "", busy = false }

	-- ---- Scan Rarity ----
	sectionLabel(page, 100, "Scan Rarity")
	local rCard = makeCard(page, 132, 101)
	text(rCard, {
		Text = "Scan Rarity",
		Font = Enum.Font.GothamBold,
		TextSize = 14,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 18),
	})
	text(rCard, {
		Text = "Baca urutan & jenis rarity dari data game, tanpa memetik item. Dekati area item dulu agar ikut terbaca.",
		TextSize = 11,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 30),
		Size = UDim2.new(1, -28, 0, 28),
	})
	local rBtn = makeButton(rCard, 0, "🔎 SCAN RARITY", T.accent, 30)
	rBtn.Position = UDim2.fromOffset(14, 64)
	rBtn.Size = UDim2.new(1, -28, 0, 30)
	local rStatus = text(rCard, {
		Text = "Belum ada hasil.",
		TextSize = 10,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 100),
		Size = UDim2.new(1, -28, 0, 26),
	})

	rBtn.MouseButton1Click:Connect(function()
		if RARITY.busy or unloaded then return end
		RARITY.busy = true
		rBtn.Text = "⏳ Memindai..."
		task.spawn(function()
			local ok, rep, verdict, col = pcall(runRarity, function(s: string)
				if not unloaded then rStatus.Text = s end
			end)
			if unloaded then return end
			if ok then
				RARITY.report = rep
				rStatus.Text = verdict
				rStatus.TextColor3 = col
				saveFile("rarity_" .. tostring(game.GameId) .. ".txt", rep)
				toast("Scan rarity selesai")
			else
				rStatus.Text = "Scan error: " .. tostring(rep)
				rStatus.TextColor3 = T.danger
				warn("[Scan] rarity: " .. tostring(rep))
			end
			rBtn.Text = "🔎 SCAN RARITY"
			RARITY.busy = false
		end)
	end)

	-- ---- Rekam Minigame ----
	sectionLabel(page, 102, "Rekam Minigame")
	state.scanRec = false
	effects.scanRec = function(on: boolean)
		if on then
			startRec()
			toast("Merekam... file mentah ditulis otomatis")
		elseif R.rec then
			stopRec()
			toast("Rekaman selesai & tersimpan. Tekan Salin Semua Hasil")
		end
	end
	local recDesc = addToggleCard(page, 103, "Rekam Minigame", "Perekam universal untuk berbagai tipe minigame. Nyalakan sebelum minigame dimulai, lalu mainkan seperti biasa.", "scanRec")
	recDesc.Text = "Rekam posisi, rotasi, teks, warna, nilai, tombol & event dari berbagai tipe minigame. Pilih mode sebelum tiap input; coba 3-5 ronde Tepat/Cepat/Telat dan catat hasilnya, lalu Salin Minigame. Toggle juga bisa lewat keybind Settings."

	local cCard = makeCard(page, 184, 104)
	text(cCard, {
		Text = "Mode tekan (dicap ke tiap tekanan berikutnya)",
		TextSize = 11,
		TextColor3 = T.sub,
		Position = UDim2.fromOffset(14, 10),
		Size = UDim2.new(1, -28, 0, 14),
	})
	local modeRow = new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 28),
		Size = UDim2.new(1, -28, 0, 28),
	}, cCard)
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, modeRow)
	local modeBtns: { [string]: any } = {}
	local function setMode(name: string)
		R.mode = name
		for n, b in pairs(modeBtns) do
			tween(b, { BackgroundColor3 = (n == name) and T.accent or T.off }, 0.12)
		end
	end
	for i, name in ipairs({ "Tepat", "Cepat", "Telat", "Bebas" }) do
		local b = new("TextButton", {
			LayoutOrder = i,
			Size = UDim2.new(0.25, -3, 1, 0),
			BackgroundColor3 = T.off,
			Text = name,
			TextColor3 = WHITE,
			Font = Enum.Font.GothamBold,
			TextSize = 12,
			AutoButtonColor = false,
		}, modeRow)
		round(b, 8)
		modeBtns[name] = b
		b.MouseButton1Click:Connect(function() setMode(name) end)
	end
	setMode("Bebas")

	local function makeBox(y: number, placeholder: string): any
		local box = new("TextBox", {
			Position = UDim2.fromOffset(14, y),
			Size = UDim2.new(1, -28, 0, 28),
			BackgroundColor3 = T.bg,
			TextColor3 = T.text,
			PlaceholderText = placeholder,
			PlaceholderColor3 = T.sub,
			Font = Enum.Font.Gotham,
			TextSize = 12,
			ClearTextOnFocus = false,
			BorderSizePixel = 0,
			Text = "",
			TextXAlignment = Enum.TextXAlignment.Left,
		}, cCard)
		round(box, 8)
		stroke(box, T.stroke, 1, 0.3)
		new("UIPadding", { PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8) }, box)
		return box
	end
	local ctxBox = makeBox(64, "Jenis / level / tingkat kesulitan (mis. level 2, tipe A) - berlaku sampai diganti")
	local noteBox = makeBox(98, "Catatan ronde terakhir (mis. gagal, item rusak) lalu Enter")
	local liveLbl = text(cCard, {
		Text = "Rekam OFF.",
		TextSize = 10,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 134),
		Size = UDim2.new(1, -28, 0, 44),
	})

	ctxBox.FocusLost:Connect(function()
		R.ctx = ctxBox.Text
		if R.rec then addEvent("KONTEKS", "konteks = '" .. cut(R.ctx, 80) .. "'") end
	end)
	noteBox.FocusLost:Connect(function(enter: boolean)
		local txt = noteBox.Text
		if txt == "" or not enter then return end
		noteBox.Text = ""
		if not R.rec and not R.hasData then
			toast("Nyalakan Rekam dulu")
			return
		end
		local last = R.trials[#R.trials]
		if last then
			last.note = (last.note ~= "" and (last.note .. " / ") or "") .. txt
			out(string.format("N|%d|%.3f|%s", last.id, now(), cut(txt, 200)))
			addEvent("CATATAN", "tekan #" .. last.id .. ": " .. cut(txt, 100))
			toast("Catatan disimpan ke tekan #" .. last.id)
		else
			R.pendingNote = txt
			toast("Catatan akan dipasang di tekan berikutnya")
		end
	end)

	-- ---- Hasil ----
	sectionLabel(page, 105, "Hasil")
	local hCard = makeCard(page, 168, 106)
	local allBtn = makeButton(hCard, 0, "📋 SALIN SEMUA HASIL", T.accent, 34)
	allBtn.Position = UDim2.fromOffset(14, 12)
	allBtn.Size = UDim2.new(1, -28, 0, 34)

	local cpR = makeButton(hCard, 0, "Salin Rarity", T.accent2, 28)
	cpR.Position = UDim2.fromOffset(14, 54)
	cpR.Size = UDim2.new(0.5, -18, 0, 28)
	local cpM = makeButton(hCard, 0, "Salin Minigame", T.accent2, 28)
	cpM.AnchorPoint = Vector2.new(1, 0)
	cpM.Position = UDim2.new(1, -14, 0, 54)
	cpM.Size = UDim2.new(0.5, -18, 0, 28)

	local clrBtn = makeButton(hCard, 0, "Hapus Rekaman", T.off, 28)
	clrBtn.Position = UDim2.fromOffset(14, 90)
	clrBtn.Size = UDim2.new(1, -28, 0, 28)

	local hLbl = text(hCard, {
		Text = "Data mentah lengkap otomatis tersimpan di folder " .. CFG.folder .. " (workspace executor).",
		TextSize = 10,
		TextColor3 = T.sub,
		TextWrapped = true,
		TextYAlignment = Enum.TextYAlignment.Top,
		Position = UDim2.fromOffset(14, 124),
		Size = UDim2.new(1, -28, 0, 38),
	})

	local function miniText(): string?
		if not R.hasData then return nil end
		local ok, rep = pcall(buildMini, false)
		if not ok then
			warn("[Scan] ringkasan: " .. tostring(rep))
			return "(gagal membuat ringkasan: " .. tostring(rep) .. ")"
		end
		return rep
	end

	local function doCopy(text_: string, label: string)
		local ok = copyText(text_)
		if ok then
			hLbl.Text = string.format("%s disalin (%d karakter).", label, #text_)
			toast(label .. " disalin")
		else
			hLbl.Text = "Executor tidak bisa menyalin. Ambil file di folder " .. CFG.folder .. " (rarity_*.txt / minigame_*_ringkasan.txt)."
			toast("Tidak bisa menyalin; lihat file")
		end
	end

	cpR.MouseButton1Click:Connect(function()
		if RARITY.report == "" then toast("Belum ada hasil Scan Rarity") return end
		doCopy(RARITY.report, "Hasil rarity")
	end)
	cpM.MouseButton1Click:Connect(function()
		if R.rec then setFeature("scanRec", false) end
		local m = miniText()
		if not m then toast("Belum ada rekaman minigame") return end
		doCopy(m, "Hasil minigame")
	end)
	allBtn.MouseButton1Click:Connect(function()
		if R.rec then setFeature("scanRec", false) end
		local m = miniText()
		if RARITY.report == "" and not m then toast("Belum ada hasil untuk disalin") return end
		local parts = {}
		if RARITY.report ~= "" then parts[#parts + 1] = RARITY.report end
		if m then parts[#parts + 1] = m end
		local all = table.concat(parts, "\n\n")
		saveFile("semua_" .. tostring(game.GameId) .. ".txt", all)
		doCopy(all, "Semua hasil")
	end)
	clrBtn.MouseButton1Click:Connect(function()
		if R.rec then setFeature("scanRec", false) end
		resetData()
		V2.reset()
		R.fileName = nil
		liveLbl.Text = "Rekaman dihapus (file di folder tidak ikut terhapus)."
		toast("Rekaman dihapus")
	end)

	-- status langsung + tulis buffer berkala
	local acc, accFlush = 0, 0
	track(RunService.Heartbeat:Connect(function(dt)
		if unloaded then return end
		acc += dt
		accFlush += dt
		if R.rec and accFlush >= CFG.flushEvery then
			accFlush = 0
			flushOut(false)
		end
		if acc >= 0.3 then
			acc = 0
			if R.rec then
				liveLbl.Text = string.format("MEREKAM %.0f dtk | tekan: %d | objek: %d | sampel: %d | kejadian: %d | file: %s%s",
					now(), #R.trials, R.nObjs, R.nSamples, R.nEvents, R.fileOk == false and "GAGAL" or (fsWrite and "OK" or "tidak didukung"),
					(R.samplesFull or R.eventsFull or R.trialsFull) and " | BATAS PENUH" or "")
			elseif R.hasData then
				liveLbl.Text = string.format("Selesai: %d tekan, %d objek, %d kejadian. File: %s", #R.trials, R.nObjs, R.nEvents,
					R.fileSummaryOk and (CFG.folder .. "/" .. tostring(R.summaryName)) or "(tidak tersimpan, salin saja)")
			end
		end
	end))

	settings.scanShutdown = function()
		R.rec = false
		stopConns()
	end
end
buildScan()
end


-- =====================================================
-- KEYBIND
-- =====================================================
track(UIS.InputBegan:Connect(function(input, processed)
	-- pop-up "keybind sudah dipakai" sedang tampil: Esc / Enter menutup, tombol lain diabaikan
	if keyConflictUI.open then
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.Return then
			keyConflictUI.close()
		end
		return
	end

	if listening then
		if input.UserInputType == Enum.UserInputType.Keyboard then
			local info = listening
			listening = nil
			if input.KeyCode == Enum.KeyCode.Escape then
				-- batal
			elseif input.KeyCode == Enum.KeyCode.Backspace and info.allowClear then
				settings[info.name] = nil
			elseif info.name == "autoCutKey" and input.KeyCode == Enum.KeyCode.Space then
				-- Auto Cut sendiri menekan Space; kalau Space jadi keybind-nya, tiap potongan akan mematikannya
				toast("Space dipakai Auto Cut untuk memotong, pilih tombol lain")
			else
				local owner = keyConflictUI.find(info.name, input.KeyCode)
				if owner then
					keyConflictUI.show(input.KeyCode, owner, info)
				else
					settings[info.name] = input.KeyCode
				end
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
	elseif kc == settings.followKey then
		follow.toggle()
	elseif kc == settings.autoCutKey and settings.miniGameOk then
		setFeature("autoCut", not state.autoCut)
		toast(state.autoCut and "Auto Cut: ON" or "Auto Cut: OFF")
	elseif kc == settings.recordMiniKey then
		setFeature("scanRec", not state.scanRec)
		toast(state.scanRec and "Rekam Minigame: ON" or "Rekam Minigame: OFF")
	end
end))

-- =====================================================
-- LABEL DAERAH (pop-up pin): dipindah dari kartu rarity lama ke kartu kecil sendiri di tab Settings (bagian Config)
-- =====================================================
xpcall(function()
	local zoneCard = makeCard(configPage, 44, 23)
	-- ---------- [PATCH] LABEL DAERAH: selalu tampil, bisa digeser, ada tombol ✕ ----------
	-- Nama daerah dibaca dari fungsi bawaan game (WorldConfig.zoneAt / RootData.placeAt) berdasarkan posisimu.
	-- Kalau fungsi itu tidak memberi nama, dipakai cadangan: atribut Zone pada jamur terdekat (diberi tanda "perkiraan").
	do
		local HttpSvc = game:GetService("HttpService")
		local zpath = "zone_label.json"
		local Z: any = { W = nil, R = nil, loaded = false, zCall = nil, pCall = nil, hidden = false, fx = nil, fy = nil, fbAt = 0, fbName = nil }
		do
			local d = settings.load(zpath)
			if type(d) == "table" then
				if type(d.fx) == "number" then Z.fx = d.fx end
				if type(d.fy) == "number" then Z.fy = d.fy end
				Z.hidden = d.v == 2 and d.hidden == true -- status lama (v1) diabaikan supaya label tampil lagi
			end
		end

		-- Label daerah SEKARANG menyatu di pop-up item (pin.setZone): satu UI, tidak terpisah lagi.
		local zoneL: any = { Text = "📍 Memuat..." }
		local placeL: any = { Text = "" }
		local frame: any = { Visible = not Z.hidden }
		Z.fit = function()
			local P: any = settings.pin
			if not (P and P.setZone) then return end
			P.setZone(zoneL.Text, placeL.Text)
		end

		-- tombol tampil/sembunyi di kartu Config
		local zoneTog = new("TextButton", {
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 28),
			BackgroundColor3 = T.bg,
			Text = "",
			TextColor3 = T.sub,
			Font = Enum.Font.GothamMedium,
			TextSize = 12,
			AutoButtonColor = false,
			BorderSizePixel = 0,
		}, zoneCard)
		round(zoneTog, 8)
		stroke(zoneTog, T.stroke, 1, 0.3)
		local function refreshTog()
			zoneTog.Text = Z.hidden and "📍 Pop-up Pin + Daerah: SEMBUNYI (klik = tampil)" or "📍 Pop-up Pin + Daerah: TAMPIL (klik = sembunyi)"
		end
		refreshTog()

		-- hanya status tampil/sembunyi yang disimpan (posisi & ukuran ikut pop-up item)
		local function saveZ()
			pcall(function()
				settings.save(zpath, HttpSvc:JSONEncode({ hidden = Z.hidden, v = 2 }))
			end)
		end
		settings.flushers["zone_label"] = saveZ

		-- X luar & tombol Config sama-sama membuka/menutup pop-up gabungan
		local P0: any = settings.pin
		if P0 then
			P0.onClosed = function(v: boolean)
				Z.hidden = v
				frame.Visible = not v
				refreshTog()
				saveZ()
			end
			P0.setClosed(Z.hidden, true)
		else
			warn("R4MEN: pop-up pin tidak ditemukan (label daerah tidak bisa ditempel)")
		end
		Z.fit()
		zoneTog.MouseButton1Click:Connect(function()
			local P: any = settings.pin
			if P then P.setClosed(not P.closed) end
		end)


		-- ---------- membaca nama daerah ----------
		task.spawn(function()
			local function getMod(nm: string): any
				for _, d in ipairs(ReplicatedStorage:GetDescendants()) do
					if d:IsA("ModuleScript") and d.Name == nm then
						local done, res = false, nil
						task.spawn(function()
							local ok, r = pcall(require, d)
							if ok then res = r end
							done = true
						end)
						local t0 = os.clock()
						while not done and os.clock() - t0 < 3 do task.wait() end
						return res
					end
				end
				return nil
			end
			Z.W = getMod("WorldConfig")
			Z.R = getMod("RootData")
			Z.loaded = true
		end)

		local NAME_KEYS = { "name", "Name", "title", "Title", "label", "Label", "zone", "Zone", "place", "Place", "id", "Id", "key" }
		local function nameOf(r: any, tbl: any): string?
			if type(r) == "string" and r ~= "" then
				-- kalau hasilnya kunci di tabel ZONES yang punya nama tampilan, pakai itu
				local e = (type(tbl) == "table" and type(tbl.ZONES) == "table") and tbl.ZONES[r] or nil
				if type(e) == "table" then
					for _, k in ipairs({ "name", "Name", "title", "Title", "label", "Label" }) do
						if type(e[k]) == "string" and e[k] ~= "" then return e[k] end
					end
				end
				return r
			elseif type(r) == "table" then
				for _, k in ipairs(NAME_KEYS) do
					if type(r[k]) == "string" and r[k] ~= "" then return r[k] end
				end
				if type(r[1]) == "string" then return r[1] end
			elseif type(r) == "number" and type(tbl) == "table" and type(tbl.ZONES) == "table" then
				local e = tbl.ZONES[r]
				if e ~= nil then return nameOf(e, nil) end
			end
			return nil
		end

		local function query(tbl: any, fn: string, pos: Vector3, memo: string): string?
			if type(tbl) ~= "table" or type(tbl[fn]) ~= "function" then return nil end
			local f = tbl[fn]
			local variants = {
				function() return f(pos) end,
				function() return f(pos.X, pos.Z) end,
				function() return f(tbl, pos) end,
			}
			local order = {}
			if Z[memo] then order[1] = Z[memo] end
			for i = 1, #variants do
				if i ~= Z[memo] then order[#order + 1] = i end
			end
			for _, i in ipairs(order) do
				local ok, r = pcall(variants[i])
				if ok then
					local n = nameOf(r, tbl)
					if n then
						Z[memo] = i
						return n
					end
				end
			end
			return nil
		end

		-- cadangan: zona jamur terdekat (hanya bila fungsi game tidak memberi nama)
		local function fallbackZone(pos: Vector3): string?
			local mf = workspace:FindFirstChild("Mushrooms")
			if not mf then return nil end
			local best, bd = nil, 250
			local function visit(inst: Instance, depth: number)
				for _, m in ipairs(inst:GetChildren()) do
					if m:IsA("Model") then
						local z = m:GetAttribute("Zone")
						if type(z) == "string" then
							local okp, pv = pcall(function() return (m :: Model):GetPivot().Position end)
							if okp then
								local d = (pv - pos).Magnitude
								if d < bd then bd, best = d, z end
							end
						end
					elseif depth < 2 and (m:IsA("Folder")) then
						visit(m, depth + 1)
					end
				end
			end
			visit(mf, 1)
			return best
		end

		local function fmt(sv: string): string
			return (string.gsub(sv, "(%l)(%u)", "%1 %2"))
		end

		local acc, fbBusy = 0, false
		track(RunService.Heartbeat:Connect(function(dt)
			if unloaded then return end
			acc += dt
			if acc < 0.4 or Z.hidden or not frame.Visible or not Z.loaded then return end
			acc = 0
			local hrp = getRoot()
			if not hrp then return end
			local pos = hrp.Position
			local okQ = pcall(function()
				local zn = query(Z.W, "zoneAt", pos, "zCall")
				local pl = query(Z.R, "placeAt", pos, "pCall")
				local tag = ""
				if not zn then
					if not fbBusy and os.clock() - Z.fbAt > 3 then
						fbBusy = true
						Z.fbAt = os.clock()
						task.spawn(function()
							local okF, nm = pcall(fallbackZone, pos)
							Z.fbName = okF and nm or nil
							fbBusy = false
						end)
					end
					zn = Z.fbName
					if zn then tag = " (perkiraan)" end
				end
				zoneL.Text = "📍 " .. (zn and (fmt(zn) .. tag) or "Wilayah tidak dikenal")
				placeL.Text = pl and ("🏞 " .. fmt(pl)) or ""
				Z.fit()
			end)
			if not okQ then
				zoneL.Text = "📍 (gagal membaca lokasi)"
				placeL.Text = ""
				Z.fit()
			end
		end))
	end
end, warn)

-- =====================================================
-- UNLOAD
-- =====================================================
local function unload()
	if unloaded then return end
	pcall(settings.flush) -- [FIX] simpan semua dulu sebelum apa pun dimatikan
	unloaded = true

	if settings.scanShutdown then pcall(settings.scanShutdown) end
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

	do
		local hf = workspace:FindFirstChild("UU_NPC_HL")
		if hf then hf:Destroy() end
	end
	for _, n in ipairs({ "UU_ITEMS", "UU_NPC", "UU_RARITY", "UU_ZONE", "UU_CHESS" }) do
		local f = playerGui:FindFirstChild(n)
		if f then f:Destroy() end
	end

	gui:Destroy()
end

unloadFn = unload
-- Simpan paksa saat game memulai teleport sendiri, atau saat pemain keluar / game ditutup
pcall(function()
	track(player.OnTeleport:Connect(function()
		pcall(settings.flush)
	end))
end)
track(Players.PlayerRemoving:Connect(function(p)
	if p == player then pcall(settings.flush) end
end))
pcall(function()
	game:BindToClose(function()
		pcall(settings.flush)
	end)
end)
do
	local env = (getgenv and getgenv()) or _G
	env.__R4MEN_UNLOAD = unload
end

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
