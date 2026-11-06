-- ============================================================
--  Rainbow Tower Rush (レインボータワーラッシュ)
--  NAWOMIDOU / オリジナルのタワー登りアスレチック
--  設置場所: ServerScriptService に Script を作って全文を貼る
--  ・ランダム生成タワー(6ステージ) / チェックポイントなし
--  ・制限時間内に頂上のゴールを目指す。勝ち数は自動保存
-- ============================================================

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

-- ===== 設定 =====
local ROUND_TIME = 300          -- 1ラウンドの秒数(5分)
local STAGE_COUNT = 6           -- タワーの段数
local STAGE_H = 16              -- 1ステージの高さ
local STOPS = 10                -- 1ステージの足場数
local RADIUS = 11               -- 螺旋の半径
local TOWER_X, TOWER_Z = 90, 0  -- タワーの中心
local winsStore = DataStoreService:GetDataStore("RainbowTowerRush_Wins_v1")

local PALETTE = {
	Color3.fromRGB(239, 83, 80),   -- 赤
	Color3.fromRGB(255, 167, 38),  -- 橙
	Color3.fromRGB(255, 238, 88),  -- 黄
	Color3.fromRGB(102, 187, 106), -- 緑
	Color3.fromRGB(66, 165, 245),  -- 青
	Color3.fromRGB(171, 71, 188),  -- 紫
	Color3.fromRGB(236, 64, 122),  -- 桃
	Color3.fromRGB(38, 198, 218),  -- 水
}
local LAVA_COLOR = Color3.fromRGB(255, 64, 32)

-- ===== 小物関数 =====
local function makePart(parent, size, cf, color, material, extra)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if extra then
		for k, v in pairs(extra) do p[k] = v end
	end
	p.Parent = parent
	return p
end

local function stopPos(i) -- 螺旋の足場位置(タワー中心からの相対)
	local a = math.rad(i * (360 / STOPS))
	return math.cos(a) * RADIUS, math.sin(a) * RADIUS
end
local function stopY(i) return i * (STAGE_H / STOPS) end

-- ===== 状態 =====
local towerModel = nil
local animParts = {}
local wonSet = {}
local roundStart = os.clock()
local lastHit = {}

local function teleportToLobby(plr)
	local char = plr.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.AssemblyLinearVelocity = Vector3.zero
		hrp.CFrame = CFrame.new(0, 4, 6)
	end
end

local function onKillTouch(hit)
	local hum = hit.Parent and hit.Parent:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	local plr = Players:GetPlayerFromCharacter(hit.Parent)
	if not plr then return end
	if lastHit[plr] and tick() - lastHit[plr] < 1 then return end
	lastHit[plr] = tick()
	teleportToLobby(plr)
end

local function makeKill(parent, size, cf)
	local p = makePart(parent, size, cf, LAVA_COLOR, Enum.Material.Neon)
	p.Touched:Connect(onKillTouch)
	return p
end

-- ===== ロビー =====
local function buildLobby()
	local lobby = Instance.new("Model")
	lobby.Name = "Lobby"
	lobby.Parent = workspace

	makePart(lobby, Vector3.new(46, 1, 46), CFrame.new(0, -0.5, 0), Color3.fromRGB(120, 200, 120), Enum.Material.Grass)
	-- タワーへの橋
	makePart(lobby, Vector3.new(58, 1, 8), CFrame.new(52, -0.5, 0), Color3.fromRGB(200, 170, 120), Enum.Material.WoodPlanks)
	-- スポーン
	local spawn = Instance.new("SpawnLocation")
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, 0.5, 6)
	spawn.Color = Color3.fromRGB(255, 255, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Parent = lobby
	-- 表彰台(飾り)
	makePart(lobby, Vector3.new(6, 3, 6), CFrame.new(-14, 1.5, 16), Color3.fromRGB(255, 215, 0), Enum.Material.Metal)
	makePart(lobby, Vector3.new(6, 2, 6), CFrame.new(-7, 1, 16), Color3.fromRGB(192, 192, 192), Enum.Material.Metal)
	makePart(lobby, Vector3.new(6, 1, 6), CFrame.new(-21, 0.5, 16), Color3.fromRGB(205, 127, 50), Enum.Material.Metal)

	-- 看板
	local function sign(pos, title, body)
		local board = makePart(lobby, Vector3.new(16, 9, 1), CFrame.new(pos), Color3.fromRGB(40, 40, 60), Enum.Material.SmoothPlastic)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Back
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.Size = UDim2.new(1, 0, 1, 0)
		label.BackgroundTransparency = 1
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.Text = title .. "\n" .. body
		label.Parent = gui
		makePart(lobby, Vector3.new(1, 5, 1), CFrame.new(pos.X, pos.Y - 7, pos.Z), Color3.fromRGB(90, 70, 40), Enum.Material.Wood)
	end
	sign(Vector3.new(0, 7, -18), "🌈 Rainbow Tower Rush",
		"Climb the random tower!\nNo checkpoints. 5 minutes.\nタワーを登って頂上を目指そう!")
	sign(Vector3.new(-20, 7, -6), "How to play",
		"Red = danger! Touch = back to lobby.\nPink pads bounce you up.\n赤は危険、ピンクは大ジャンプ")
end

-- ===== ステージ定義(全12種・ランダムに6つ) =====
local stageBuilders = {}

local function stageHelpers(model, baseY, stageIdx)
	local color = PALETTE[((stageIdx - 1) % #PALETTE) + 1]
	local H = {}
	H.model = model
	H.baseY = baseY
	H.color = color
	function H.plat(i, w, d, col, mat)
		local lx, lz = stopPos(i)
		return makePart(model, Vector3.new(w or 7, 1, d or 5),
			CFrame.new(TOWER_X + lx, baseY + stopY(i), TOWER_Z + lz), col or color, mat)
	end
	function H.kill(i, w, d, offT)
		local lx, lz = stopPos(i)
		local a = math.rad(i * (360 / STOPS))
		local tx, tz = -math.sin(a), math.cos(a) -- 接線方向
		return makeKill(model, Vector3.new(w or 7, 1, d or 2),
			CFrame.new(TOWER_X + lx + tx * (offT or 0), baseY + stopY(i) + 0.05, TOWER_Z + lz + tz * (offT or 0)))
	end
	function H.raw(size, lx, ly, lz, col, mat, extra)
		return makePart(model, size, CFrame.new(TOWER_X + lx, baseY + ly, TOWER_Z + lz), col, mat, extra)
	end
	function H.killRadial(i, dist, w, d) -- 足場の外側の端に溶岩帯
		local lx, lz = stopPos(i)
		local a = math.rad(i * (360 / STOPS))
		return makeKill(model, Vector3.new(w, 1.1, d),
			CFrame.new(TOWER_X + lx + math.cos(a) * dist, baseY + stopY(i) + 0.03, TOWER_Z + lz + math.sin(a) * dist))
	end
	return H
end

stageBuilders[1] = function(H) -- 基本の螺旋
	for i = 1, STOPS do H.plat(i) end
end
stageBuilders[2] = function(H) -- 細い梁
	for i = 1, STOPS do H.plat(i, 7, 2.6) end
end
stageBuilders[3] = function(H) -- 小さな四角
	for i = 1, STOPS do H.plat(i, 4.6, 4.6) end
end
stageBuilders[4] = function(H) -- 足場の端に溶岩帯
	for i = 1, STOPS do
		H.plat(i)
		if i % 2 == 1 then H.killRadial(i, 3.4, 2, 5) end
	end
end
stageBuilders[5] = function(H) -- 溶岩の双子(隣に偽の足場)
	for i = 1, STOPS do
		H.plat(i)
		if i == 3 or i == 6 or i == 9 then H.kill(i, 7, 5, 6.4) end
	end
end
stageBuilders[6] = function(H) -- 動く足場
	for i = 1, STOPS do
		local p = H.plat(i)
		if i == 3 or i == 6 or i == 9 then
			local a = math.rad(i * (360 / STOPS))
			table.insert(animParts, {part = p, kind = "slide",
				base = p.Position, dir = Vector3.new(math.cos(a), 0, math.sin(a)), amp = 2.6, speed = 1.7})
		end
	end
end
stageBuilders[7] = function(H) -- 点滅する足場
	for i = 1, STOPS do
		local p = H.plat(i)
		table.insert(animParts, {part = p, kind = "blink", phase = (i % 2) * 1.6, period = 3.2})
	end
end
stageBuilders[8] = function(H) -- 回転バー
	for i = 1, STOPS do H.plat(i) end
	H.raw(Vector3.new(2, STAGE_H, 2), 0, STAGE_H / 2, 0, Color3.fromRGB(60, 60, 60), Enum.Material.Metal)
	local bar = makeKill(H.model, Vector3.new(25, 1, 1),
		CFrame.new(TOWER_X, H.baseY + 8.5, TOWER_Z)) -- 以後の位置はアニメーションで設定
	bar.Name = "SpinnerBar"
	bar:SetAttribute("SpinY", 8.5)
	bar:SetAttribute("BaseY", H.baseY)
	table.insert(animParts, {part = bar, kind = "spin",
		center = Vector3.new(TOWER_X, 0, TOWER_Z), speed = 0.65})
end
stageBuilders[9] = function(H) -- バウンスパッド
	for i = 1, STOPS do
		if i == 2 or i == 6 then
			local p = H.plat(i, 7, 5, Color3.fromRGB(255, 80, 200), Enum.Material.Neon)
			local lastBounce = {}
			p.Touched:Connect(function(hit)
				local hrp = hit.Parent and hit.Parent:FindFirstChild("HumanoidRootPart")
				if not hrp then return end
				if lastBounce[hrp] and tick() - lastBounce[hrp] < 0.5 then return end
				lastBounce[hrp] = tick()
				hrp.AssemblyLinearVelocity = Vector3.new(0, 58, 0)
			end)
		else
			H.plat(i)
		end
	end
end
stageBuilders[10] = function(H) -- 遠いジャンプ(半径を広げた小さな足場)
	for i = 1, STOPS do
		local lx, lz = stopPos(i)
		H.raw(Vector3.new(5, 1, 5), lx * 1.14, stopY(i), lz * 1.14, H.color)
	end
end
stageBuilders[11] = function(H) -- 急な階段
	local heights = {2.2, 4.4, 6.6, 8.8, 11, 12.4, 13.8, 14.6, 15.4, 16}
	for i = 1, STOPS do
		local lx, lz = stopPos(i)
		H.raw(Vector3.new(7, 1, 5), lx, heights[i], lz, PALETTE[5])
	end
end
stageBuilders[12] = function(H) -- チェッカー溶岩
	for i = 1, STOPS do
		H.plat(i)
		if i == 4 or i == 7 then H.kill(i, 3.5, 5, 3.2) end
	end
end

-- ===== タワー生成 =====
local function buildTower()
	if towerModel then towerModel:Destroy() end
	animParts = {}
	towerModel = Instance.new("Model")
	towerModel.Name = "Tower"
	towerModel.Parent = workspace

	-- 土台
	makePart(towerModel, Vector3.new(26, 1, 26), CFrame.new(TOWER_X, -0.5, TOWER_Z),
		Color3.fromRGB(150, 150, 160), Enum.Material.Concrete)

	-- ステージをシャッフルして6つ
	local order = {}
	for i = 1, #stageBuilders do table.insert(order, i) end
	for i = #order, 2, -1 do
		local j = math.random(i)
		order[i], order[j] = order[j], order[i]
	end
	for s = 1, STAGE_COUNT do
		local baseY = (s - 1) * STAGE_H
		local H = stageHelpers(towerModel, baseY, order[s])
		stageBuilders[order[s]](H)
	end
	-- ゴール
	local topY = STAGE_COUNT * STAGE_H
	local goal = makePart(towerModel, Vector3.new(13, 1, 13), CFrame.new(TOWER_X, topY + 0.5, TOWER_Z),
		Color3.fromRGB(255, 215, 0), Enum.Material.Neon)
	goal.Name = "GoalPad"
	local signPart = makePart(towerModel, Vector3.new(10, 5, 1), CFrame.new(TOWER_X, topY + 4, TOWER_Z - 7),
		Color3.fromRGB(40, 40, 60), Enum.Material.SmoothPlastic)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = signPart
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 230, 0)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Text = "🏆 GOAL!"
	label.Parent = gui

	goal.Touched:Connect(function(hit)
		local plr = Players:GetPlayerFromCharacter(hit.Parent)
		if not plr or wonSet[plr] then return end
		local hum = hit.Parent:FindFirstChildOfClass("Humanoid")
		if not hum or hum.Health <= 0 then return end
		wonSet[plr] = true
		local stats = plr:FindFirstChild("leaderstats")
		if stats and stats:FindFirstChild("Wins") then
			stats.Wins.Value = stats.Wins.Value + 1
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local g = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("TowerGui")
			if g and g:FindFirstChild("Announce") then
				g.Announce.Text = "🏆 " .. plr.DisplayName .. " reached the top!"
			end
		end
		task.delay(1.2, function() teleportToLobby(plr) end)
		task.delay(4, function()
			for _, p in ipairs(Players:GetPlayers()) do
				local g = p:FindFirstChild("PlayerGui") and p.PlayerGui:FindFirstChild("TowerGui")
				if g and g:FindFirstChild("Announce") then g.Announce.Text = "" end
			end
		end)
	end)
end

-- ===== GUI =====
local function makeLabel(gui, name, pos, size, textSize, color)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = pos
	l.Size = size
	l.BackgroundTransparency = 0.35
	l.BackgroundColor3 = Color3.fromRGB(20, 20, 30)
	l.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.Text = ""
	l.Parent = gui
	return l
end

local function setupPlayer(plr)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Value = 0
	wins.Parent = stats
	stats.Parent = plr

	local ok, data = pcall(function()
		return winsStore:GetAsync("Wins_" .. plr.UserId)
	end)
	if ok and type(data) == "number" then wins.Value = data end

	local gui = Instance.new("ScreenGui")
	gui.Name = "TowerGui"
	gui.ResetOnSpawn = false
	gui.Parent = plr:WaitForChild("PlayerGui")
	makeLabel(gui, "Timer", UDim2.new(0.5, -70, 0, 8), UDim2.new(0, 140, 0, 34), 22)
	makeLabel(gui, "Stage", UDim2.new(0.5, -70, 0, 46), UDim2.new(0, 140, 0, 26), 16, Color3.fromRGB(180, 230, 255))
	local ann = makeLabel(gui, "Announce", UDim2.new(0.5, -260, 0.3, 0), UDim2.new(0, 520, 0, 44), 26, Color3.fromRGB(255, 230, 0))
	ann.BackgroundTransparency = 1

	-- スポーン直後に必ずロビーへ置く(開始直後の落下防止)
	plr.CharacterAdded:Connect(function(char)
		local hrp = char:WaitForChild("HumanoidRootPart", 5)
		if hrp then
			task.wait(0.2)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.CFrame = CFrame.new(0, 4, 6)
		end
	end)
	if plr.Character then
		task.spawn(function()
			local hrp = plr.Character:WaitForChild("HumanoidRootPart", 5)
			if hrp then hrp.CFrame = CFrame.new(0, 4, 6) end
		end)
	end
end

local function saveWins(plr)
	local stats = plr:FindFirstChild("leaderstats")
	if not stats or not stats:FindFirstChild("Wins") then return end
	pcall(function()
		winsStore:SetAsync("Wins_" .. plr.UserId, stats.Wins.Value)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
Players.PlayerRemoving:Connect(saveWins)
game:BindToClose(function()
	for _, plr in ipairs(Players:GetPlayers()) do saveWins(plr) end
end)

-- ===== アニメーションと落下チェック =====
RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()
	for _, a in ipairs(animParts) do
		if a.kind == "slide" then
			a.part.Position = a.base + a.dir * (math.sin(t * a.speed) * a.amp)
		elseif a.kind == "blink" then
			local on = (math.floor((t + a.phase) / (a.period / 2)) % 2) == 0
			a.part.CanCollide = on
			a.part.Transparency = on and 0 or 0.6
		elseif a.kind == "spin" then
			a.angle = (a.angle or 0) + a.speed * dt
			local y = a.part:GetAttribute("SpinY") or 8.5
			-- スピナーの属するステージの底は part のタグ BaseY 属性(未設定時は0)
			local baseY = a.part:GetAttribute("BaseY") or 0
			a.part.CFrame = CFrame.new(a.center.X, baseY + y, a.center.Z) * CFrame.Angles(0, a.angle, 0)
		end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
		if hrp and hrp.Position.Y < -12 then teleportToLobby(plr) end
	end
end)

-- ===== ラウンド管理 =====
buildLobby()
buildTower()
roundStart = os.clock()

task.spawn(function()
	while true do
		task.wait(1)
		local remain = ROUND_TIME - (os.clock() - roundStart)
		if remain <= 0 then
			wonSet = {}
			buildTower()
			roundStart = os.clock()
			for _, plr in ipairs(Players:GetPlayers()) do teleportToLobby(plr) end
			remain = ROUND_TIME
		end
		local mm = math.floor(remain / 60)
		local ss = math.floor(remain % 60)
		for _, plr in ipairs(Players:GetPlayers()) do
			local g = plr:FindFirstChild("PlayerGui") and plr.PlayerGui:FindFirstChild("TowerGui")
			if g then
				if g:FindFirstChild("Timer") then
					g.Timer.Text = string.format("⏰ %d:%02d", mm, ss)
				end
				local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
				if g:FindFirstChild("Stage") and hrp then
					if math.abs(hrp.Position.X - TOWER_X) < 30 and hrp.Position.Y > 0 then
						local st = math.clamp(math.floor(hrp.Position.Y / STAGE_H) + 1, 1, STAGE_COUNT)
						g.Stage.Text = "Stage " .. st .. " / " .. STAGE_COUNT
					else
						g.Stage.Text = "Lobby"
					end
				end
			end
		end
	end
end)

print("Rainbow Tower Rush: started")
