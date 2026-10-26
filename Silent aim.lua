local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

if not L then L = {} end
if not L.SilentAim then L.SilentAim = {} end
local SA = L.SilentAim

L.silentAim = L.silentAim or {}

local function c3rgb(r, g, b)
    return Color3.fromRGB(r, g, b)
end

local function createGUI()
    local parentFolder = CoreGui:FindFirstChild("RobloxGui") or LocalPlayer:WaitForChild("PlayerGui")
    if parentFolder:FindFirstChild("SilentAimGui") then
        parentFolder.SilentAimGui:Destroy()
    end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "SilentAimGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.Parent = parentFolder

    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = UDim2.new(0, 220, 0, 410)
    MainFrame.Position = UDim2.new(0.05, 0, 0.2, 0)
    MainFrame.BackgroundColor3 = c3rgb(25, 25, 25)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active = true
    MainFrame.Draggable = true
    MainFrame.Parent = ScreenGui

    local UICorner = Instance.new("UICorner", MainFrame)
    UICorner.CornerRadius = UDim.new(0, 8)

    local Title = Instance.new("TextLabel", MainFrame)
    Title.Size = UDim2.new(1, 0, 0, 35)
    Title.BackgroundTransparency = 1
    Title.Text = "Silent Aim Control"
    Title.TextColor3 = c3rgb(255, 255, 255)
    Title.TextSize = 16
    Title.Font = Enum.Font.SourceSansBold

    local ScrollFrame = Instance.new("ScrollingFrame", MainFrame)
    ScrollFrame.Size = UDim2.new(1, -20, 1, -45)
    ScrollFrame.Position = UDim2.new(0, 10, 0, 40)
    ScrollFrame.BackgroundTransparency = 1
    ScrollFrame.ScrollBarThickness = 4
    ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 360)

    local UIListLayout = Instance.new("UIListLayout", ScrollFrame)
    UIListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    UIListLayout.Padding = UDim.new(0, 6)

    local function createToggleButton(text, defaultState, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = defaultState and c3rgb(40, 140, 60) or c3rgb(50, 50, 50)
        btn.Text = text .. ": " .. (defaultState and "ON" or "OFF")
        btn.TextColor3 = c3rgb(255, 255, 255)
        btn.Font = Enum.Font.SourceSans
        btn.TextSize = 14
        btn.Parent = ScrollFrame

        local corner = Instance.new("UICorner", btn)
        corner.CornerRadius = UDim.new(0, 4)

        local state = defaultState
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.BackgroundColor3 = state and c3rgb(40, 140, 60) or c3rgb(50, 50, 50)
            btn.Text = text .. ": " .. (state and "ON" or "OFF")
            callback(state)
        end)
        return btn
    end

    -- Settings Toggles
    createToggleButton("Use FOV", SA.SILENT_AIM_USE_FOV or false, function(state)
        SA.SILENT_AIM_USE_FOV = state
    end)

    createToggleButton("Show FOV", SA.SILENT_AIM_SHOW_FOV or false, function(state)
        SA.SILENT_AIM_SHOW_FOV = state
        if SA.UpdateSilentAimFovCircle then
            SA.UpdateSilentAimFovCircle()
        end
    end)

    createToggleButton("Wall Check", SA.CHECK_WALLS or true, function(state)
        SA.CHECK_WALLS = state
    end)

    createToggleButton("Prediction", SA.PREDICTION_ENABLED or false, function(state)
        SA.PREDICTION_ENABLED = state
    end)

    -- Zombie Type Toggles
    local types = {
        {"Bomber", "bomber"},
        {"Cuirassier", "cuirassier"},
        {"Runner", "runner"},
        {"Zapper", "zapper"},
        {"Igniter", "igniter"},
        {"Shambler", "shambler"},
        {"Headless", "headless"}
    }

    for _, tData in ipairs(types) do
        local label, key = tData[1], tData[2]
        createToggleButton(label, L.silentAim[key] or false, function(state)
            L.silentAim[key] = state
            if typeof(SA.updateSilentAimSelection) == "function" then
                SA.updateSilentAimSelection()
            end
        end)
    end
end

createGUI()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

if not L then L = {} end
if not L.SilentAim then L.SilentAim = {} end
local SA = L.SilentAim

local v3new = Vector3.new
local v2new = Vector2.new
local c3rgb = Color3.fromRGB
local osClock = os.clock
local mathMax = math.max
local mathCeil = math.ceil
local mathMin = math.min
local mathAbs = math.abs
local mathFloor = math.floor
local tick_ = tick

function L.sharedGetCurrentBulletSpeed() return 1000 end
function L.sharedGetPing() return 50 end
function L.isHeadlessModel(model) return model.Name == "Headless" end
function L.onCharacterAdded(cb) LocalPlayer.CharacterAdded:Connect(cb) end

function L.ensureAimAnchor(sa, name)
    if not sa.indicatorPart or not sa.indicatorPart.Parent then
        local p = Instance.new("Part")
        p.Name = name
        p.Anchored = true
        p.CanCollide = false
        p.Transparency = 1
        p.Size = Vector3.new(0.2, 0.2, 0.2)
        p.Parent = workspace
        sa.indicatorPart = p
    end
end

function L.buildAimBillboard(sa)
    local bill = Instance.new("BillboardGui")
    bill.Size = UDim2.new(0, 30, 0, 30)
    bill.AlwaysOnTop = true
    bill.Adornee = sa.indicatorPart
    bill.Parent = sa.indicatorPart

    local container = Instance.new("Frame", bill)
    container.Size = UDim2.new(1, 0, 1, 0)
    container.BackgroundTransparency = 1

    local outer = Instance.new("Frame", container)
    outer.Size = UDim2.new(1, 0, 1, 0)
    outer.BackgroundTransparency = 1
    local outerStroke = Instance.new("UIStroke", outer)
    outerStroke.Thickness = 2

    local inner = Instance.new("Frame", container)
    inner.Size = UDim2.new(0.5, 0, 0.5, 0)
    inner.Position = UDim2.new(0.25, 0, 0.25, 0)
    inner.BackgroundTransparency = 1
    local innerStroke = Instance.new("UIStroke", inner)
    innerStroke.Thickness = 1.5

    return bill, container, outer, outerStroke, inner, innerStroke
end

function L.teardownAimVisual(sa)
    if sa.indicatorData and sa.indicatorData.billboard then
        sa.indicatorData.billboard:Destroy()
        sa.indicatorData = nil
    end
    if sa.indicatorPart then
        sa.indicatorPart:Destroy()
        sa.indicatorPart = nil
    end
end

SA.Enabled = false
SA.SilentAimSelectedTypes = {}
SA.SilentAimEnabledTypes = {}
SA.SilentAimZombieTypes = { "Bomber", "Cuirassier", "Runner", "Zapper", "Igniter", "Shambler" }
SA.SILENT_AIM_USE_FOV = false
SA.SILENT_AIM_SHOW_FOV = false
SA.SILENT_AIM_MOBILE_FOV = false
SA.SILENT_AIM_FOV_SIZE = 50
SA.SilentAimCurrentTarget = nil
SA.SilentAimCurrentModel = nil
SA.SilentAimUpdateConn = nil
SA.oldFire = nil
SA.CHECK_WALLS = true
SA.MAX_TARGET_RANGE = 200
SA.PREDICTION_ENABLED = false
SA.SCAN_INTERVAL = 0.12
SA._lastEnum = 0
SA._enumZombies = nil
SA._enumHeadless = nil
SA._headlessConn = nil

SA.indicatorData = nil
SA.indicatorPart = nil

L.silentAim = L.silentAim or {}
L.silentAim.bomber = false
L.silentAim.cuirassier = false
L.silentAim.runner = false
L.silentAim.zapper = false
L.silentAim.igniter = false
L.silentAim.shambler = false
L.silentAim.headless = false

for _, t in SA.SilentAimZombieTypes do SA.SilentAimEnabledTypes[t] = false end

local function getCurrentBulletSpeed() return L.sharedGetCurrentBulletSpeed() end
local function getPing() return L.sharedGetPing() end

function SA.isWorldPosInSilentAimFov(worldPos)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local sp, onScreen = cam:WorldToViewportPoint(worldPos)
    if not onScreen then return false end
    local dx = sp.X - cam.ViewportSize.X / 2
    local dy = sp.Y - cam.ViewportSize.Y / 2
    local r = SA.SILENT_AIM_FOV_SIZE
    return dx * dx + dy * dy <= r * r
end

function SA.UpdateSilentAimFovCircle()
    local cam = workspace.CurrentCamera
    if SA.SILENT_AIM_SHOW_FOV and cam and not SA.fovCircleDrawing then
        if Drawing and Drawing.new then
            SA.fovCircleDrawing = Drawing.new("Circle")
            SA.fovCircleDrawing.Thickness = 1.5
            SA.fovCircleDrawing.NumSides = 64
            SA.fovCircleDrawing.Filled = false
            SA.fovCircleDrawing.Color = c3rgb(255, 255, 255)
            SA.fovCircleDrawing.Visible = true
        end
    elseif (not SA.SILENT_AIM_SHOW_FOV or not cam) and SA.fovCircleDrawing then
        if SA.fovCircleResizeConn then
            SA.fovCircleResizeConn:Disconnect()
            SA.fovCircleResizeConn = nil
        end
        SA.fovCircleDrawing:Remove()
        SA.fovCircleDrawing = nil
    end
    if SA.fovCircleDrawing and cam then
        SA.fovCircleDrawing.Radius = SA.SILENT_AIM_FOV_SIZE
        SA.fovCircleDrawing.Position = v2new(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        if not SA.fovCircleResizeConn then
            SA.fovCircleResizeConn = cam:GetPropertyChangedSignal("ViewportSize"):Connect(function()
                SA.UpdateSilentAimFovCircle()
            end)
        end
    end
end

local _zombieTypeCache = setmetatable({}, { __mode = "k" })
local ZOMBIE_TYPE_TTL = 0.3

local function _computeZombieTypeRaw(model)
    local parent = model.Parent
    if parent and parent.Name == "Slim" and parent.Parent and parent.Parent.Name == "Zombies" then
        return "Cuirassier"
    end
    local agent = model:FindFirstChild("Agent")
    if agent then
        local typeValue = agent:FindFirstChild("Type")
        if typeValue and typeValue:IsA("StringValue") then
            local t = string.lower(typeValue.Value or "")
            if t == "normal" then return "Shambler" end
            if t == "barrel" then return "Bomber" end
            if t == "fast" then return "Runner" end
            if t == "sapper" then return "Zapper" end
            if t == "igniter" then return "Igniter" end
            if t == "cuirassier" then return "Cuirassier" end
        end
    end
    if typeof(model.GetAttribute) == "function" then
        local t = model:GetAttribute("Type")
        if type(t) == "string" then
            local lower = string.lower(t)
            if lower == "normal" then return "Shambler" end
            if lower == "barrel" then return "Bomber" end
            if lower == "fast" then return "Runner" end
            if lower == "sapper" then return "Zapper" end
            if lower == "igniter" then return "Igniter" end
            if lower == "cuirassier" then return "Cuirassier" end
        end
    end
    if model:FindFirstChild("Barrel", true) then return "Bomber" end
    if model:FindFirstChild("Whale Oil Lantern", true) then return "Igniter" end
    if model:FindFirstChild("Sword", true) then return "Cuirassier" end
    if model:FindFirstChild("Axe", true) and model:FindFirstChild("Head", true) then return "Zapper" end
    if model:FindFirstChild("Eye", true) and not model:FindFirstChild("Axe", true) then return "Runner" end
    return "Shambler"
end

local function GetZombieTypeFromModel(model)
    if not model or not model:IsA("Model") then return nil end
    local now = osClock()
    local c = _zombieTypeCache[model]
    if c and now - c.t < ZOMBIE_TYPE_TTL then
        return c.v
    end
    local v = _computeZombieTypeRaw(model)
    _zombieTypeCache[model] = { t = now, v = v }
    return v
end

local function getWallCheckOrigin()
    if LocalPlayer.Character and LocalPlayer.Character.Parent then
        local head = LocalPlayer.Character:FindFirstChild("Head")
        if head and head:IsA("BasePart") then return head.Position end
    end
    local cam = workspace.CurrentCamera
    return cam and cam.CFrame.Position or nil
end

local _baseIgnoreCache = {}
local _baseIgnoreTime = 0
local BASE_IGNORE_TTL = 0.2

local function buildBaseIgnore()
    local now = osClock()
    if now - _baseIgnoreTime < BASE_IGNORE_TTL and #_baseIgnoreCache > 0 then
        return _baseIgnoreCache
    end
    _baseIgnoreTime = now
    local baseIgnore = _baseIgnoreCache
    local n = 0
    for _, pl in Players:GetPlayers() do
        local ch = pl.Character
        if ch and ch:IsA("Model") then
            n = n + 1
            baseIgnore[n] = ch
        end
    end
    local camFolderInst = workspace:FindFirstChild("Camera")
    if camFolderInst then
        for _, d in camFolderInst:GetDescendants() do
            if d and d:IsA("Model") and d.Name == "m_Zombie" then
                n = n + 1
                baseIgnore[n] = d
            end
        end
    end
    for i = n + 1, #baseIgnore do
        baseIgnore[i] = nil
    end
    return baseIgnore
end

local WALL_CHECK_TRANSPARENCY_THRESHOLD = 0.95
local WALL_CHECK_SAMPLE_AXIS_SCALE = 0.35
local WALL_CHECK_MIN_SAMPLE_OFFSET = 0.4
local WALL_CHECK_MAX_SAMPLE_OFFSET = 2.75
local WALL_CHECK_REQUIRED_CLEAR_RATIO = 0.6
local EPS = 1e-4

local function getWallCheckSamplePositions(part, aimPosOverride)
    if not part or not part.Parent then return {} end
    local basePos = aimPosOverride or part.Position
    local cf = part.CFrame
    local size = part.Size or v3new(1,1,1)
    local function axisOffset(comp)
        local scaled = comp * WALL_CHECK_SAMPLE_AXIS_SCALE
        if scaled < WALL_CHECK_MIN_SAMPLE_OFFSET then scaled = WALL_CHECK_MIN_SAMPLE_OFFSET end
        if scaled > WALL_CHECK_MAX_SAMPLE_OFFSET then scaled = WALL_CHECK_MAX_SAMPLE_OFFSET end
        return scaled
    end
    local xOff = axisOffset(size.X)
    local yOff = axisOffset(size.Y)
    local zOff = axisOffset(size.Z)
    local offsets = {
        v3new(0,0,0),
        v3new(0, yOff, 0),
        v3new(0, -yOff, 0),
        v3new(xOff, 0, 0),
        v3new(-xOff, 0, 0),
        v3new(0, 0, zOff),
        v3new(0, 0, -zOff)
    }
    local samples = {}
    for _, offset in offsets do
        samples[#samples+1] = basePos + cf:VectorToWorldSpace(offset)
    end
    return samples
end

local obstructParams = nil

local function isObstructedBetweenIterative(origin, targetPos, targetModel, baseIgnore)
    if not SA.CHECK_WALLS then return false end
    if not targetPos then return false end
    local actualOrigin = origin
    if LocalPlayer.Character then
        local head = LocalPlayer.Character:FindFirstChild("Head")
        if head and head:IsA("BasePart") then actualOrigin = head.Position end
    end
    if not actualOrigin then return false end
    local dir = targetPos - actualOrigin
    local dist = dir.Magnitude
    if dist <= 0 then return false end
    if not obstructParams then
        obstructParams = RaycastParams.new()
        obstructParams.FilterType = Enum.RaycastFilterType.Exclude
    end
    local params = obstructParams
    local filter = {}
    if baseIgnore then for i = 1, #baseIgnore do filter[#filter+1] = baseIgnore[i] end end
    if LocalPlayer.Character then table.insert(filter, LocalPlayer.Character) end
    params.FilterDescendantsInstances = filter
    local maxIter = 16
    local remaining = dist
    local originPos = actualOrigin
    local dirUnit = dir.Unit
    local epsilon = 0.25
    for _ = 1, maxIter do
        local ok, result = pcall(function() return workspace:Raycast(originPos, dirUnit * remaining, params) end)
        if not ok or not result then return false end
        local hit = result.Instance
        if not hit then return false end
        if targetModel and hit:IsDescendantOf(targetModel) then return false end
        local isBase = hit:IsA("BasePart")
        local transparency = isBase and hit.Transparency or 0
        local canCollide = isBase and hit.CanCollide
        local nonBlocking = false
        if isBase and (not canCollide or transparency >= WALL_CHECK_TRANSPARENCY_THRESHOLD) then nonBlocking = true end
        local ancestor = hit
        while ancestor and ancestor.Parent do
            if ancestor:IsA("Model") and ancestor.Name == "m_Zombie" then nonBlocking = true; break end
            ancestor = ancestor.Parent
        end
        for _, pl in Players:GetPlayers() do
            local ch = pl.Character
            if ch and hit:IsDescendantOf(ch) then nonBlocking = true; break end
        end
        if nonBlocking then
            table.insert(params.FilterDescendantsInstances, hit)
            local advance = result.Position + dirUnit * epsilon
            if (advance - actualOrigin).Magnitude >= dist - EPS then return false end
            originPos = advance
            remaining = (targetPos - originPos).Magnitude
        else
            return true
        end
    end
    return true
end

local function hasClearShotOnPart(originPos, aimPart, targetModel, baseIgnore, aimPosOverride)
    if not SA.CHECK_WALLS then return true end
    if not originPos or not aimPart or not aimPart.Parent then return false end
    local samples = getWallCheckSamplePositions(aimPart, aimPosOverride)
    if #samples == 0 then return false end
    local required = mathMax(1, mathCeil(#samples * WALL_CHECK_REQUIRED_CLEAR_RATIO))
    local clear = 0
    for _, sample in samples do
        if not isObstructedBetweenIterative(originPos, sample, targetModel, baseIgnore) then
            clear = clear + 1
            if clear >= required then return true end
        end
    end
    return false
end

local function isZombieSpawning(model)
    if not model then return false end
    local state = model:FindFirstChild("State")
    if state and state:IsA("StringValue") and state.Value == "Spawn" then return true end
    local agent = model:FindFirstChild("Agent")
    if agent then
        local agentState = agent:FindFirstChild("State")
        if agentState and agentState:IsA("StringValue") and agentState.Value == "Spawn" then return true end
    end
    return false
end

local _aimPartCache = setmetatable({}, { __mode = "k" })
local AIM_PART_TTL = 0.3

local function _computeAimPartRaw(zombie)
    local head = zombie:FindFirstChild("Head", true)
    if head then return head end
    local torso = zombie:FindFirstChild("Torso") or zombie:FindFirstChild("UpperTorso") or zombie:FindFirstChild("HumanoidRootPart")
    if torso then return torso end
    local barrel = zombie:FindFirstChild("Barrel", true)
    if barrel then return barrel end
    return zombie.PrimaryPart
end

local function findBestAimPart(zombie)
    if not zombie or not zombie.Parent then return nil end
    local now = osClock()
    local c = _aimPartCache[zombie]
    if c and now - c.t < AIM_PART_TTL then
        local p = c.v
        if p and p.Parent then
            return p
        end
    end
    local v = _computeAimPartRaw(zombie)
    _aimPartCache[zombie] = { t = now, v = v }
    return v
end

local function getAimPosition(part)
    if not part or not part.Parent then return nil end
    return part.Position
end

function SA.updateIndicator(aimPos, hasTarget)
    if not aimPos then
        L.teardownAimVisual(SA)
        return
    end

    L.ensureAimAnchor(SA, "SilentAimIndicatorAnchor")
    SA.indicatorPart.Position = aimPos

    if not SA.indicatorData or not SA.indicatorData.billboard or not SA.indicatorData.billboard.Parent then
        local bill, container, outer, outerStroke, inner, innerStroke = L.buildAimBillboard(SA)

        SA.indicatorData = {
            billboard = bill,
            container = container,
            outer = outer,
            outerStroke = outerStroke,
            inner = inner,
            innerStroke = innerStroke,
            hasTarget = false,
        }

        task.spawn(function()
            while SA.indicatorData and SA.indicatorData.billboard and SA.indicatorData.billboard.Parent do
                local target = SA.indicatorData.hasTarget
                local breath = (math.sin(tick_() * 4) + 1) / 2 * 0.2 + 0.15
                local breath2 = (math.sin(tick_() * 4 + 0.5) + 1) / 2 * 0.25 + 0.2

                if target then
                    local g = 0.7 + (math.sin(tick_() * 2) + 1) / 2 * 0.3
                    local color = c3rgb(0, mathFloor(g * 255), 80)
                    if SA.indicatorData.outerStroke then
                        SA.indicatorData.outerStroke.Color = color
                        SA.indicatorData.outerStroke.Transparency = breath
                    end
                    if SA.indicatorData.innerStroke then
                        SA.indicatorData.innerStroke.Color = color
                        SA.indicatorData.innerStroke.Transparency = breath2
                    end
                else
                    local white = c3rgb(255, 255, 255)
                    if SA.indicatorData.outerStroke then
                        SA.indicatorData.outerStroke.Color = white
                        SA.indicatorData.outerStroke.Transparency = breath
                    end
                    if SA.indicatorData.innerStroke then
                        SA.indicatorData.innerStroke.Color = white
                        SA.indicatorData.innerStroke.Transparency = breath2
                    end
                end
                task.wait(0.02)
            end
        end)
    else
        if SA.indicatorData.billboard.Adornee ~= SA.indicatorPart then
            SA.indicatorData.billboard.Adornee = SA.indicatorPart
        end
        SA.indicatorData.hasTarget = hasTarget
    end
end

function SA.hideIndicator()
    L.teardownAimVisual(SA)
end

local function predictAimPos(aimPos, origin, model, d)
    local predictedPos = aimPos
    if SA.PREDICTION_ENABLED then
        local bulletSpeed = getCurrentBulletSpeed()
        if bulletSpeed and bulletSpeed > 0 then
            local ping = getPing()
            local delay = (ping or 0) / 2000
            local targetRoot = model:FindFirstChild("HumanoidRootPart")
            if targetRoot then
                local vel = targetRoot.AssemblyLinearVelocity
                if vel.Magnitude > 0.05 then
                    local dirToTarget = (aimPos - origin).Unit
                    local moveDir = vel.Unit
                    local cosAngle = dirToTarget:Dot(moveDir)
                    local angleFactor = 1 - mathAbs(cosAngle) * 0.5
                    local referenceDist = 60
                    local distanceFactor = mathMin(1.2, d / referenceDist)
                    local coefficient = (0.2 + 0.8 * distanceFactor) * 1.2
                    local travelTime = d / bulletSpeed + delay
                    local lead = vel * travelTime * coefficient * angleFactor
                    for _ = 1, 2 do
                        travelTime = ((aimPos + lead - origin).Magnitude) / bulletSpeed + delay
                        lead = vel * travelTime * coefficient * angleFactor
                    end
                    local predictedOffset = lead
                    local maxOffset = mathMin(d * 0.15 + 2, 35)
                    if predictedOffset.Magnitude > maxOffset then
                        predictedOffset = predictedOffset.Unit * maxOffset
                    end
                    predictedPos = aimPos + predictedOffset
                end
            end
        end
    end
    return predictedPos
end

function SA.StartSilentAimLoop()
    if SA.SilentAimUpdateConn then return end
    if not SA._headlessConn then
        SA._enumHeadless = SA._enumHeadless or {}
        for _, model in workspace:GetDescendants() do
            if model:IsA("Model") and L.isHeadlessModel(model) then
                table.insert(SA._enumHeadless, model)
            end
        end
        SA._headlessConn = workspace.DescendantAdded:Connect(function(d)
            if d:IsA("Model") and L.isHeadlessModel(d) then
                local hl = SA._enumHeadless
                if hl then
                    for _, m in ipairs(hl) do
                        if m == d then return end
                    end
                    table.insert(hl, d)
                end
            end
        end)
    end
    SA.SilentAimUpdateConn = RunService.Heartbeat:Connect(function()
        local hasSelection = SA.En