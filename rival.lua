-- サービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ContextActionService = game:GetService("ContextActionService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- モバイル判定
local IS_MOBILE = UserInputService.TouchEnabled

-- 設定（GUIから変更可能）
local Settings = {
    ESP = {
        Enabled = true,
        Box = true,
        BoxColor = Color3.fromRGB(0, 255, 0),
        Tracer = true,
        Name = true,
        Distance = true,
        TeamCheck = true,
        MaxDistance = 1000
    },
    
    Aimbot = {
        Enabled = false,
        TouchToAim = IS_MOBILE,
        TargetPart = "Head",
        Smoothness = 0.25,
        FOV = 80,
        ShowFOV = true,
        TeamCheck = true,
        AutoShoot = false,
        AutoShootDelay = 0.2,
        Prediction = 0.15
    },
    
    Misc = {
        Crosshair = true,
        CrosshairSize = IS_MOBILE and 20 or 12,
        CrosshairColor = Color3.fromRGB(255, 255, 255),
        NoRecoil = false,
        RapidFire = false,
        SpeedHack = false,
        SpeedMultiplier = 1.5
    }
}

-- グローバル変数
local ESPObjects = {}
local CurrentTarget = nil
local GUI = nil
local Crosshair = nil
local FOVCircle = nil
local AutoShootActive = false
local MobileControls = nil

-- ユーティリティ関数
local function IsTeamMate(player)
    if not Settings.ESP.TeamCheck then return false end
    return player.Team == LocalPlayer.Team
end

local function GetClosestPlayer()
    local closestDistance = Settings.Aimbot.FOV
    local closestPlayer = nil
    local closestPart = nil
    
    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        if IsTeamMate(player) and Settings.Aimbot.TeamCheck then continue end
        
        local character = player.Character
        if not character then continue end
        
        local humanoid = character:FindFirstChild("Humanoid")
        if not humanoid or humanoid.Health <= 0 then continue end
        
        local targetPart = character:FindFirstChild(Settings.Aimbot.TargetPart)
        if not targetPart then continue end
        
        local screenPoint, onScreen = Camera:WorldToViewportPoint(targetPart.Position)
        if not onScreen then continue end
        
        local distance = (Vector2.new(screenPoint.X, screenPoint.Y) - 
                         Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)).Magnitude
        
        if distance < closestDistance then
            closestDistance = distance
            closestPlayer = player
            closestPart = targetPart
        end
    end
    
    return closestPlayer, closestPart
end

-- Aimbot機能
local function AimAt(targetPart)
    if not targetPart then return end
    
    local targetPosition = targetPart.Position
    
    -- 予測機能
    if Settings.Aimbot.Prediction > 0 then
        local character = targetPart.Parent
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            targetPosition = targetPosition + (humanoidRootPart.Velocity * Settings.Aimbot.Prediction)
        end
    end
    
    -- スムージング
    local cameraCFrame = Camera.CFrame
    local toTarget = (targetPosition - cameraCFrame.Position).Unit
    local lookVector = cameraCFrame.LookVector
    
    local newLook = lookVector:Lerp(toTarget, 1 - Settings.Aimbot.Smoothness)
    Camera.CFrame = CFrame.new(cameraCFrame.Position, cameraCFrame.Position + newLook)
end

-- ESP機能
local function CreateESP(player)
    if player == LocalPlayer then return end
    
    local highlight = Instance.new("Highlight")
    highlight.Name = "ESP_" .. player.Name
    highlight.FillColor = Settings.ESP.BoxColor
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.7
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    
    ESPObjects[player] = highlight
    
    -- キャラクターにアタッチ
    local function attachESP()
        if player.Character then
            highlight.Adornee = player.Character
            highlight.Enabled = Settings.ESP.Enabled and not (IsTeamMate(player) and Settings.ESP.TeamCheck)
            highlight.Parent = player.Character
        end
    end
    
    attachESP()
    player.CharacterAdded:Connect(attachESP)
    
    return highlight
end

local function UpdateESP()
    for player, highlight in pairs(ESPObjects) do
        if player.Character and highlight.Adornee ~= player.Character then
            highlight.Adornee = player.Character
            highlight.Parent = player.Character
        end
        
        highlight.Enabled = Settings.ESP.Enabled and not (IsTeamMate(player) and Settings.ESP.TeamCheck)
        
        if Settings.ESP.Enabled then
            local distance = (Camera.CFrame.Position - player.Character:GetPivot().Position).Magnitude
            highlight.Enabled = distance <= Settings.ESP.MaxDistance
        end
    end
end

-- クロスヘア
local function CreateCrosshair()
    if Crosshair then Crosshair:Remove() end
    
    Crosshair = Drawing.new("Square")
    Crosshair.Visible = Settings.Misc.Crosshair
    Crosshair.Color = Settings.Misc.CrosshairColor
    Crosshair.Thickness = 2
    Crosshair.Size = Vector2.new(Settings.Misc.CrosshairSize, Settings.Misc.CrosshairSize)
    Crosshair.Filled = true
    Crosshair.Position = Vector2.new(
        Camera.ViewportSize.X / 2 - Settings.Misc.CrosshairSize / 2,
        Camera.ViewportSize.Y / 2 - Settings.Misc.CrosshairSize / 2
    )
end

-- FOV円
local function CreateFOVCircle()
    if FOVCircle then FOVCircle:Remove() end
    
    FOVCircle = Drawing.new("Circle")
    FOVCircle.Visible = Settings.Aimbot.ShowFOV
    FOVCircle.Color = Color3.fromRGB(255, 255, 255)
    FOVCircle.Thickness = 1
    FOVCircle.NumSides = 32
    FOVCircle.Radius = Settings.Aimbot.FOV
    FOVCircle.Filled = false
    FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
end

-- GUI作成（スマホ対応）
local function CreateGUI()
    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "FPS_Mobile_Suite"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    
    -- メインフレーム（スマホ用に最適化）
    local MainFrame = Instance.new("Frame")
    MainFrame.Name = "MainFrame"
    MainFrame.Size = IS_MOBILE and UDim2.new(0, 350, 0, 500) or UDim2.new(0, 400, 0, 500)
    MainFrame.Position = IS_MOBILE and UDim2.new(0.02, 0, 0.3, 0) or UDim2.new(0.05, 0, 0.3, 0)
    MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
    MainFrame.BackgroundTransparency = 0.1
    MainFrame.BorderSizePixel = 0
    MainFrame.ClipsDescendants = true
    
    local UICorner = Instance.new("UICorner")
    UICorner.CornerRadius = UDim.new(0, 8)
    UICorner.Parent = MainFrame
    
    -- タイトルバー
    local TitleBar = Instance.new("Frame")
    TitleBar.Name = "TitleBar"
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(20, 20, 25)
    TitleBar.BorderSizePixel = 0
    
    local TitleLabel = Instance.new("TextLabel")
    TitleLabel.Name = "TitleLabel"
    TitleLabel.Size = UDim2.new(0.7, 0, 1, 0)
    TitleLabel.Position = UDim2.new(0.05, 0, 0, 0)
    TitleLabel.BackgroundTransparency = 1
    TitleLabel.Text = "📱 FPS Mobile Suite"
    TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    TitleLabel.Font = Enum.Font.GothamBold
    TitleLabel.TextSize = IS_MOBILE and 14 or 16
    
    local ToggleButton = Instance.new("TextButton")
    ToggleButton.Name = "ToggleButton"
    ToggleButton.Size = IS_MOBILE and UDim2.new(0, 60, 0, 30) or UDim2.new(0, 30, 0, 30)
    ToggleButton.Position = UDim2.new(1, -70, 0, 5)
    ToggleButton.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    ToggleButton.Text = "−"
    ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    ToggleButton.Font = Enum.Font.GothamBold
    ToggleButton.TextSize = 20
    
    -- コンテンツフレーム
    local ContentFrame = Instance.new("ScrollingFrame")
    ContentFrame.Name = "ContentFrame"
    ContentFrame.Size = UDim2.new(1, 0, 1, -50)
    ContentFrame.Position = UDim2.new(0, 0, 0, 50)
    ContentFrame.BackgroundTransparency = 1
    ContentFrame.CanvasSize = UDim2.new(0, 0, 0, 800)
    ContentFrame.ScrollBarThickness = 3
    
    -- タッチしやすい大きなボタンを作成する関数
    local function CreateMobileToggle(name, settingCategory, settingKey, default, yPosition)
        local toggleFrame = Instance.new("Frame")
        toggleFrame.Size = UDim2.new(0.9, 0, 0, IS_MOBILE and 50 or 40)
        toggleFrame.Position = UDim2.new(0.05, 0, 0, yPosition)
        toggleFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
        toggleFrame.BorderSizePixel = 0
        
        local toggleCorner = Instance.new("UICorner")
        toggleCorner.CornerRadius = UDim.new(0, 6)
        toggleCorner.Parent = toggleFrame
        
        local toggleLabel = Instance.new("TextLabel")
        toggleLabel.Size = UDim2.new(0.7, 0, 1, 0)
        toggleLabel.BackgroundTransparency = 1
        toggleLabel.Text = name
        toggleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleLabel.Font = Enum.Font.Gotham
        toggleLabel.TextSize = IS_MOBILE and 14 or 12
        toggleLabel.TextXAlignment = Enum.TextXAlignment.Left
        toggleLabel.Position = UDim2.new(0.05, 0, 0, 0)
        
        local toggleButton = Instance.new("TextButton")
        toggleButton.Size = IS_MOBILE and UDim2.new(0, 60, 0, 30) or UDim2.new(0, 50, 0, 25)
        toggleButton.Position = UDim2.new(1, -70, 0.5, -15)
        toggleButton.BackgroundColor3 = default and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(60, 60, 65)
        toggleButton.Text = default and "ON" or "OFF"
        toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        toggleButton.Font = Enum.Font.GothamBold
        toggleButton.TextSize = IS_MOBILE and 12 or 10
        
        local buttonCorner = Instance.new("UICorner")
        buttonCorner.CornerRadius = UDim.new(0, 4)
        buttonCorner.Parent = toggleButton
        
        -- 設定を更新する関数
        local function updateToggle()
            local currentValue = Settings[settingCategory][settingKey]
            toggleButton.Text = currentValue and "ON" or "OFF"
            toggleButton.BackgroundColor3 = currentValue and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(60, 60, 65)
        end
        
        -- 初期値設定
        Settings[settingCategory][settingKey] = Settings[settingCategory][settingKey] or default
        updateToggle()
        
        -- クリックイベント
        toggleButton.MouseButton1Click:Connect(function()
            Settings[settingCategory][settingKey] = not Settings[settingCategory][settingKey]
            updateToggle()
            
            -- 特定の設定に対する特別な処理
            if settingKey == "Crosshair" then
                if Crosshair then
                    Crosshair.Visible = Settings.Misc.Crosshair
                end
            elseif settingKey == "ShowFOV" then
                if FOVCircle then
                    FOVCircle.Visible = Settings.Aimbot.ShowFOV
                end
            end
        end)
        
        -- タッチイベント（モバイル用）
        if IS_MOBILE then
            toggleFrame.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    Settings[settingCategory][settingKey] = not Settings[settingCategory][settingKey]
                    updateToggle()
                end
            end)
        end
        
        toggleLabel.Parent = toggleFrame
        toggleButton.Parent = toggleFrame
        toggleFrame.Parent = ContentFrame
        
        return toggleFrame
    end
    
    -- スライダー作成関数
    local function CreateMobileSlider(name, settingCategory, settingKey, min, max, default, yPosition)
        local sliderFrame = Instance.new("Frame")
        sliderFrame.Size = UDim2.new(0.9, 0, 0, IS_MOBILE and 70 or 60)
        sliderFrame.Position = UDim2.new(0.05, 0, 0, yPosition)
        sliderFrame.BackgroundTransparency = 1
        
        local sliderLabel = Instance.new("TextLabel")
        sliderLabel.Size = UDim2.new(1, 0, 0, 20)
        sliderLabel.BackgroundTransparency = 1
        sliderLabel.Text = name .. ": " .. tostring(Settings[settingCategory][settingKey] or default)
        sliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        sliderLabel.Font = Enum.Font.Gotham
        sliderLabel.TextSize = IS_MOBILE and 14 or 12
        sliderLabel.TextXAlignment = Enum.TextXAlignment.Left
        
        local sliderBar = Instance.new("Frame")
        sliderBar.Size = UDim2.new(1, 0, 0, 10)
        sliderBar.Position = UDim2.new(0, 0, 0, 30)
        sliderBar.BackgroundColor3 = Color3.fromRGB(60, 60, 65)
        sliderBar.BorderSizePixel = 0
        
        local sliderCorner = Instance.new("UICorner")
        sliderCorner.CornerRadius = UDim.new(0, 5)
        sliderCorner.Parent = sliderBar
        
        local sliderFill = Instance.new("Frame")
        sliderFill.Size = UDim2.new(
            ((Settings[settingCategory][settingKey] or default) - min) / (max - min), 
            0, 1, 0
        )
        sliderFill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        sliderFill.BorderSizePixel = 0
        
        local fillCorner = Instance.new("UICorner")
        fillCorner.CornerRadius = UDim.new(0, 5)
        fillCorner.Parent = sliderFill
        
        sliderFill.Parent = sliderBar
        
        -- スライダー制御
        local dragging = false
        
        local function updateSlider(value)
            local clampedValue = math.clamp(value, min, max)
            Settings[settingCategory][settingKey] = clampedValue
            sliderLabel.Text = name .. ": " .. tostring(math.floor(clampedValue * 10) / 10)
            sliderFill.Size = UDim2.new((clampedValue - min) / (max - min), 0, 1, 0)
        end
        
        -- スライダーのインタラクション
        local function onInput(input)
            local relativeX = (input.Position.X - sliderBar.AbsolutePosition.X) / sliderBar.AbsoluteSize.X
            relativeX = math.clamp(relativeX, 0, 1)
            local value = min + (max - min) * relativeX
            updateSlider(value)
        end
        
        sliderBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                onInput(input)
            end
        end)
        
        sliderBar.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
               input.UserInputType == Enum.UserInputType.Touch) then
                onInput(input)
            end
        end)
        
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or 
               input.UserInputType == Enum.UserInputType.Touch then
                dragging = false
            end
        end)
        
        -- 初期値設定
        updateSlider(Settings[settingCategory][settingKey] or default)
        
        sliderLabel.Parent = sliderFrame
        sliderBar.Parent = sliderFrame
        sliderFrame.Parent = ContentFrame
        
        return sliderFrame
    end
    
    -- 各種コントロールを追加
    local yOffset = 0
    local spacing = IS_MOBILE and 60 or 50
    
    -- ESP セクション
    local espLabel = Instance.new("TextLabel")
    espLabel.Size = UDim2.new(0.9, 0, 0, 30)
    espLabel.Position = UDim2.new(0.05, 0, 0, yOffset)
    espLabel.BackgroundTransparency = 1
    espLabel.Text = "👁️ ESP SETTINGS"
    espLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
    espLabel.Font = Enum.Font.GothamBold
    espLabel.TextSize = IS_MOBILE and 16 or 14
    espLabel.Parent = ContentFrame
    yOffset = yOffset + 35
    
    CreateMobileToggle("ESP Enabled", "ESP", "Enabled", true, yOffset)
    yOffset = yOffset + spacing
    
    CreateMobileToggle("Box ESP", "ESP", "Box", true, yOffset)
    yOffset = yOffset + spacing
    
    CreateMobileToggle("Show Names", "ESP", "Name", true, yOffset)
    yOffset = yOffset + spacing
    
    CreateMobileToggle("Team Check", "ESP", "TeamCheck", true, yOffset)
    yOffset = yOffset + spacing + 20
    
    -- Aimbot セクション
    local aimbotLabel = Instance.new("TextLabel")
    aimbotLabel.Size = UDim2.new(0.9, 0, 0, 30)
    aimbotLabel.Position = UDim2.new(0.05, 0, 0, yOffset)
    aimbotLabel.BackgroundTransparency = 1
    aimbotLabel.Text = "🎯 AIMBOT SETTINGS"
    aimbotLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
    aimbotLabel.Font = Enum.Font.GothamBold
    aimbotLabel.TextSize = IS_MOBILE and 16 or 14
    aimbotLabel.Parent = ContentFrame
    yOffset = yOffset + 35
    
    CreateMobileToggle("Aimbot Enabled", "Aimbot", "Enabled", false, yOffset)
    yOffset = yOffset + spacing
    
    CreateMobileToggle("Auto Shoot", "Aimbot", "AutoShoot", false, yOffset)
    yOffset = yOffset + spacing
    
    CreateMobileToggle("Show FOV Circle", "Aimbot", "ShowFOV", true, yOffset)
    yOffset = yOffset + spacing
    
    CreateMobileSlider("FOV Size", "Aimbot", "FOV", 10, 200, 80, yOffset)
    yOffset = yOffset + (IS_MOBILE and 80 : 70)
    
    CreateMobileSlider("Smoothness", "Aimbot", "Smoothness", 0, 1, 0.25, yOffset)
    yOffset = yOffset + (IS_MOBILE and 80 : 70) + 20
    
    -- その他の設定
    local miscLabel = Instance.new("TextLabel")
    miscLabel.Size = UDim2.new(0.9, 0, 0, 30)
    miscLabel.Position = UDim2.new(0.05, 0, 0, yOffset)
    miscLabel.BackgroundTransparency = 1
    miscLabel.Text = "⚙️ OTHER SETTINGS"
    miscLabel.TextColor3 = Color3.fromRGB(0, 170, 255)
    miscLabel.Font = Enum.Font.GothamBold
    miscLabel.TextSize = IS_MOBILE and 16 or 14
    miscLabel.Parent = ContentFrame
    yOffset = yOffset + 35
    
    CreateMobileToggle("Crosshair", "Misc", "Crosshair", true, yOffset)
    yOffset = yOffset + spacing
    
    CreateMobileToggle("No Recoil", "Misc", "NoRecoil", false, yOffset)
    yOffset = yOffset + spacing
    
    CreateMobileToggle("Rapid Fire", "Misc", "RapidFire", false, yOffset)
    yOffset = yOffset + spacing
    
    -- 親設定
    TitleLabel.Parent = TitleBar
    ToggleButton.Parent = TitleBar
    TitleBar.Parent = MainFrame
    ContentFrame.Parent = MainFrame
    MainFrame.Parent = ScreenGui
    
    -- ドラッグ機能
    local dragging = false
    local dragStart = nil
    local startPos = nil
    
    local function updateInput(input)
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, 
                                      startPos.Y.Scale, startPos.Y.Offset + delta.Y)
    end
    
    TitleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = MainFrame.Position
        end
    end)
    
    TitleBar.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
           input.UserInputType == Enum.UserInputType.Touch) then
            updateInput(input)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or 
           input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    
    -- トグルボタン
    ToggleButton.MouseButton1Click:Connect(function()
        ContentFrame.Visible = not ContentFrame.Visible
        if ContentFrame.Visible then
            MainFrame.Size = IS_MOBILE and UDim2.new(0, 350, 0, 500) or UDim2.new(0, 400, 0, 500)
            ToggleButton.Text = "−"
        else
            MainFrame.Size = UDim2.new(0, MainFrame.Size.X.Offset, 0, 50)
            ToggleButton.Text = "+"
        end
    end)
    
    -- モバイル用簡易コントロールを追加
    if IS_MOBILE then
        local QuickControls = Instance.new("Frame")
        QuickControls.Name = "QuickControls"
        QuickControls.Size = UDim2.new(0, 120, 0, 120)
        QuickControls.Position = UDim2.new(1, -130, 0.7, 0)
        QuickControls.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
        QuickControls.BackgroundTransparency = 0.2
        QuickControls.BorderSizePixel = 0
        
        local quickCorner = Instance.new("UICorner")
        quickCorner.CornerRadius = UDim.new(0, 8)
        quickCorner.Parent = QuickControls
        
        -- クイックAimbotトグル
        local quickAimBtn = Instance.new("TextButton")
        quickAimBtn.Name = "QuickAim"
        quickAimBtn.Size = UDim2.new(0.8, 0, 0, 40)
        quickAimBtn.Position = UDim2.new(0.1, 0, 0.1, 0)
        quickAimBtn.BackgroundColor3 = Settings.Aimbot.Enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(60, 60, 65)
        quickAimBtn.Text = Settings.Aimbot.Enabled and "AIM: ON" or "AIM: OFF"
        quickAimBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        quickAimBtn.Font = Enum.Font.GothamBold
        quickAimBtn.TextSize = 12
        
        quickAimBtn.MouseButton1Click:Connect(function()
            Settings.Aimbot.Enabled = not Settings.Aimbot.Enabled
            quickAimBtn.Text = Settings.Aimbot.Enabled and "AIM: ON" or "AIM: OFF"
            quickAimBtn.BackgroundColor3 = Settings.Aimbot.Enabled and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(60, 60, 65)
        end)
        
        quickAimBtn.Parent = QuickControls
        QuickControls.Parent = ScreenGui
    end
    
    ScreenGui.Parent = game.CoreGui
    return ScreenGui
end

-- 初期化
local function Initialize()
    -- GUI作成
    GUI = CreateGUI()
    
    -- ESP初期化
    for _, player in ipairs(Players:GetPlayers()) do
        CreateESP(player)
    end
    
    Players.PlayerAdded:Connect(CreateESP)
    Players.PlayerRemoving:Connect(function(player)
        if ESPObjects[player] then
            ESPObjects[player]:Destroy()
            ESPObjects[player] = nil
        end
    end)
    
    -- 視覚効果作成
    CreateCrosshair()
    CreateFOVCircle()
    
    -- メインループ
    RunService.RenderStepped:Connect(function()
        -- ESP更新
        UpdateESP()
        
        -- クロスヘア更新
        if Crosshair then
            Crosshair.Visible = Settings.Misc.Crosshair
            Crosshair.Position = Vector2.new(
                Camera.ViewportSize.X / 2 - Settings.Misc.CrosshairSize / 2,
                Camera.ViewportSize.Y / 2 - Settings.Misc.CrosshairSize / 2
            )
        end
        
        -- FOV円更新
        if FOVCircle then
            FOVCircle.Position = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
            FOVCircle.Radius = Settings.Aimbot.FOV
            FOVCircle.Visible = Settings.Aimbot.ShowFOV
        end
        
        -- Aimbot実行
        if Settings.Aimbot.Enabled then
            local targetPlayer, targetPart = GetClosestPlayer()
            if targetPlayer and targetPart then
                AimAt(targetPart)
                CurrentTarget = targetPlayer
                
                -- 自動射撃
                if Settings.Aimbot.AutoShoot and LocalPlayer.Character then
                    local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                    if tool then
                        tool:Activate()
                        task.wait(Settings.Aimbot.AutoShootDelay)
                    end
                end
            end
        else
            CurrentTarget = nil
        end
        
        -- リコイル制御
        if Settings.Misc.NoRecoil and LocalPlayer.Character then
            -- リコイル軽減処理
        end
    end)
    
    -- GUI表示/非表示キー
    UserInputService.InputBegan:Connect(function(input, processed)
        if processed then return end
        
        if input.KeyCode == Enum.KeyCode.Insert or 
           (IS_MOBILE and input.UserInputType == Enum.UserInputType.Touch and 
            input.Position.X < 50 and input.Position.Y < 50) then
            
            if GUI and GUI.Parent then
                GUI.Parent = nil
            else
                if not GUI then
                    GUI = CreateGUI()
                else
                    GUI.Parent = game.CoreGui
                end
            end
        end
    end)
end

-- スクリプト開始
Initialize()

-- 通知
task.wait(1)
print("📱 Mobile FPS Suite Loaded!")
print("Insertキーまたは画面左上タップでGUI表示/非表示")
