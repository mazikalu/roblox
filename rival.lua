-- Mobile Optimized Combat Control System
-- モバイル最適化コンバットコントロールシステム

-- メインサービス
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera
local Mouse = LocalPlayer:GetMouse()

-- タッチ入力用グローバル変数
local TouchInput = {
    Active = false,
    StartPosition = Vector2.new(0, 0),
    CurrentPosition = Vector2.new(0, 0)
}

-- 設定（モバイル用に最適化）
local Config = {
    ESP = {
        Enabled = true,
        BoxColor = Color3.fromRGB(0, 255, 0),
        TextColor = Color3.fromRGB(255, 255, 255),
        HealthBar = true,
        MaxDistance = 500, -- モバイルでは距離を短く
        UpdateRate = 0.2 -- 更新間隔を長く（パフォーマンス対策）
    },
    
    AimAssist = {
        Enabled = false,
        FOV = 150, -- モバイルではFOVを小さく
        Smoothing = 0.15, -- スムージングを強く
        TargetPart = "Head",
        AutoShoot = false,
        TouchZone = UDim2.new(0.6, 0, 0.3, 0, 0.6, 0, 0.6, 0) -- タッチ制御エリア
    },
    
    Target = {
        Mode = "Nearest",
        Selected = nil,
        LockDistance = 50 -- ロック距離（ピクセル）
    },
    
    UI = {
        Scale = 1.2, -- モバイル用にUIを大きく
        Transparency = 0.8,
        Position = UDim2.new(0.02, 0, 0.02, 0)
    }
}

-- 状態管理
local State = {
    Status = "Ready",
    LastUpdate = tick(),
    TargetList = {},
    VisiblePlayers = {},
    ESPObjects = {},
    AimingAt = nil
}

-- モバイルUIの作成
local function CreateMobileUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CombatControlMobile"
    screenGui.DisplayOrder = 100
    screenGui.ResetOnSpawn = false
    
    -- メインコンテナ
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainPanel"
    mainFrame.Size = UDim2.new(0.3, 0, 0.4, 0)
    mainFrame.Position = Config.UI.Position
    mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = screenGui
    
    -- タイトル
    local title = Instance.new("TextLabel")
    title.Text = "戦闘コントロール"
    title.Size = UDim2.new(1, 0, 0.1, 0)
    title.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 18 * Config.UI.Scale
    title.Parent = mainFrame
    
    -- ESPトグルボタン
    local espButton = Instance.new("TextButton")
    espButton.Name = "ESPToggle"
    espButton.Text = "ESP: ON"
    espButton.Size = UDim2.new(0.45, 0, 0.08, 0)
    espButton.Position = UDim2.new(0.025, 0, 0.12, 0)
    espButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
    espButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    espButton.Font = Enum.Font.Gotham
    espButton.TextSize = 14 * Config.UI.Scale
    espButton.Parent = mainFrame
    
    -- エイムアシストトグル
    local aimButton = Instance.new("TextButton")
    aimButton.Name = "AimToggle"
    aimButton.Text = "AIM: OFF"
    aimButton.Size = UDim2.new(0.45, 0, 0.08, 0)
    aimButton.Position = UDim2.new(0.525, 0, 0.12, 0)
    aimButton.BackgroundColor3 = Color3.fromRGB(150, 0, 0)
    aimButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    aimButton.Font = Enum.Font.Gotham
    aimButton.TextSize = 14 * Config.UI.Scale
    aimButton.Parent = mainFrame
    
    -- FOVスライダー
    local fovLabel = Instance.new("TextLabel")
    fovLabel.Text = "FOV: " .. Config.AimAssist.FOV
    fovLabel.Size = UDim2.new(0.95, 0, 0.06, 0)
    fovLabel.Position = UDim2.new(0.025, 0, 0.22, 0)
    fovLabel.BackgroundTransparency = 1
    fovLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    fovLabel.Font = Enum.Font.Gotham
    fovLabel.TextSize = 14 * Config.UI.Scale
    fovLabel.Name = "FOVLabel"
    fovLabel.Parent = mainFrame
    
    local fovSlider = Instance.new("Frame")
    fovSlider.Name = "FOVSlider"
    fovSlider.Size = UDim2.new(0.95, 0, 0.03, 0)
    fovSlider.Position = UDim2.new(0.025, 0, 0.28, 0)
    fovSlider.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    fovSlider.BorderSizePixel = 0
    fovSlider.Parent = mainFrame
    
    local fovFill = Instance.new("Frame")
    fovFill.Name = "FOVFill"
    fovFill.Size = UDim2.new(Config.AimAssist.FOV / 300, 0, 1, 0)
    fovFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    fovFill.BorderSizePixel = 0
    fovFill.Parent = fovSlider
    
    -- ターゲットモード
    local targetLabel = Instance.new("TextLabel")
    targetLabel.Text = "ターゲットモード:"
    targetLabel.Size = UDim2.new(0.95, 0, 0.05, 0)
    targetLabel.Position = UDim2.new(0.025, 0, 0.33, 0)
    targetLabel.BackgroundTransparency = 1
    targetLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    targetLabel.Font = Enum.Font.Gotham
    targetLabel.TextSize = 13 * Config.UI.Scale
    targetLabel.Parent = mainFrame
    
    local nearestButton = Instance.new("TextButton")
    nearestButton.Name = "NearestMode"
    nearestButton.Text = "最接近"
    nearestButton.Size = UDim2.new(0.45, 0, 0.06, 0)
    nearestButton.Position = UDim2.new(0.025, 0, 0.39, 0)
    nearestButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    nearestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    nearestButton.Font = Enum.Font.Gotham
    nearestButton.TextSize = 12 * Config.UI.Scale
    nearestButton.Parent = mainFrame
    
    local selectedButton = Instance.new("TextButton")
    selectedButton.Name = "SelectedMode"
    selectedButton.Text = "手動選択"
    selectedButton.Size = UDim2.new(0.45, 0, 0.06, 0)
    selectedButton.Position = UDim2.new(0.525, 0, 0.39, 0)
    selectedButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    selectedButton.TextColor3 = Color3.fromRGB(200, 200, 200)
    selectedButton.Font = Enum.Font.Gotham
    selectedButton.TextSize = 12 * Config.UI.Scale
    selectedButton.Parent = mainFrame
    
    -- プレイヤーリスト（スクロール）
    local listFrame = Instance.new("Frame")
    listFrame.Name = "PlayerList"
    listFrame.Size = UDim2.new(0.95, 0, 0.35, 0)
    listFrame.Position = UDim2.new(0.025, 0, 0.48, 0)
    listFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    listFrame.BorderSizePixel = 0
    listFrame.ClipsDescendants = true
    listFrame.Parent = mainFrame
    
    local uiListLayout = Instance.new("UIListLayout")
    uiListLayout.Padding = UDim.new(0, 2)
    uiListLayout.Parent = listFrame
    
    -- ステータス表示
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Name = "StatusLabel"
    statusLabel.Text = "状態: " .. State.Status
    statusLabel.Size = UDim2.new(0.95, 0, 0.06, 0)
    statusLabel.Position = UDim2.new(0.025, 0, 0.85, 0)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
    statusLabel.Font = Enum.Font.GothamBold
    statusLabel.TextSize = 14 * Config.UI.Scale
    statusLabel.Parent = mainFrame
    
    -- タッチエイムゾーン（透明なボタン）
    local aimZone = Instance.new("TextButton")
    aimZone.Name = "AimZone"
    aimZone.Text = ""
    aimZone.Size = UDim2.new(0.4, 0, 0.4, 0)
    aimZone.Position = UDim2.new(0.6, 0, 0.3, 0)
    aimZone.BackgroundTransparency = 0.9
    aimZone.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    aimZone.BorderSizePixel = 0
    aimZone.Parent = screenGui
    
    -- UIイベントハンドラ
    espButton.MouseButton1Click:Connect(function()
        Config.ESP.Enabled = not Config.ESP.Enabled
        espButton.Text = "ESP: " .. (Config.ESP.Enabled and "ON" or "OFF")
        espButton.BackgroundColor3 = Config.ESP.Enabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    end)
    
    aimButton.MouseButton1Click:Connect(function()
        Config.AimAssist.Enabled = not Config.AimAssist.Enabled
        aimButton.Text = "AIM: " .. (Config.AimAssist.Enabled and "ON" or "OFF")
        aimButton.BackgroundColor3 = Config.AimAssist.Enabled and Color3.fromRGB(0, 150, 0) or Color3.fromRGB(150, 0, 0)
    end)
    
    nearestButton.MouseButton1Click:Connect(function()
        Config.Target.Mode = "Nearest"
        nearestButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
        selectedButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    end)
    
    selectedButton.MouseButton1Click:Connect(function()
        Config.Target.Mode = "Selected"
        nearestButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
        selectedButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    end)
    
    -- FOVスライダー用タッチハンドリング
    local function updateFOV(value)
        Config.AimAssist.FOV = math.clamp(value, 50, 300)
        fovLabel.Text = "FOV: " .. Config.AimAssist.FOV
        fovFill.Size = UDim2.new(Config.AimAssist.FOV / 300, 0, 1, 0)
    end
    
    fovSlider.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
            local xPos = input.Position.X - fovSlider.AbsolutePosition.X
            local percent = math.clamp(xPos / fovSlider.AbsoluteSize.X, 0, 1)
            updateFOV(percent * 300)
        end
    end)
    
    fovSlider.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseMovement then
            if input.UserInputState == Enum.UserInputState.Change then
                local xPos = input.Position.X - fovSlider.AbsolutePosition.X
                local percent = math.clamp(xPos / fovSlider.AbsoluteSize.X, 0, 1)
                updateFOV(percent * 300)
            end
        end
    end)
    
    -- タッチエイムゾーンの処理
    aimZone.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            TouchInput.Active = true
            TouchInput.StartPosition = Vector2.new(input.Position.X, input.Position.Y)
            TouchInput.CurrentPosition = TouchInput.StartPosition
            
            if Config.AimAssist.Enabled and Config.AimAssist.AutoShoot then
                -- 自動射撃のロジック（必要に応じて実装）
            end
        end
    end)
    
    aimZone.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch and TouchInput.Active then
            TouchInput.CurrentPosition = Vector2.new(input.Position.X, input.Position.Y)
        end
    end)
    
    aimZone.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.Touch then
            TouchInput.Active = false
        end
    end)
    
    screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
    
    return {
        ScreenGui = screenGui,
        UpdateStatus = function(status)
            State.Status = status
            statusLabel.Text = "状態: " .. status
            
            -- 色を変更
            if status == "Ready" then
                statusLabel.TextColor3 = Color3.fromRGB(0, 255, 0)
            elseif status == "Aiming" then
                statusLabel.TextColor3 = Color3.fromRGB(255, 255, 0)
            elseif status == "Locked" then
                statusLabel.TextColor3 = Color3.fromRGB(255, 0, 0)
            elseif status == "Error" then
                statusLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
            end
        end,
        
        UpdatePlayerList = function(players)
            -- 既存のアイテムをクリア
            for _, child in pairs(listFrame:GetChildren()) do
                if child:IsA("TextButton") then
                    child:Destroy()
                end
            end
            
            -- 新しいプレイヤーリストを追加
            for _, player in pairs(players) do
                if player ~= LocalPlayer then
                    local button = Instance.new("TextButton")
                    button.Text = player.Name
                    button.Size = UDim2.new(1, -10, 0, 30 * Config.UI.Scale)
                    button.Position = UDim2.new(0, 5, 0, 0)
                    button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                    button.TextColor3 = Color3.fromRGB(200, 200, 200)
                    button.Font = Enum.Font.Gotham
                    button.TextSize = 12 * Config.UI.Scale
                    button.Parent = listFrame
                    
                    button.MouseButton1Click:Connect(function()
                        Config.Target.Selected = player
                        Config.Target.Mode = "Selected"
                        nearestButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
                        selectedButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
                    end)
                end
            end
        end
    }
end

-- ESPシステム（モバイル最適化）
local function CreateESPSystem()
    local ESP = {
        Objects = {},
        Connections = {}
    }
    
    -- プレイヤー追加時の処理
    local function onPlayerAdded(player)
        if player == LocalPlayer then return end
        
        ESP.Objects[player] = {
            Box = nil,
            Name = nil,
            HealthBar = nil,
            Connection = nil
        }
        
        -- キャラクター追加時の処理
        local function onCharacterAdded(character)
            wait(1) -- キャラクターのロードを待つ
            
            -- 既存のオブジェクトをクリア
            if ESP.Objects[player].Box then
                ESP.Objects[player].Box:Destroy()
            end
            if ESP.Objects[player].Name then
                ESP.Objects[player].Name:Destroy()
            end
            if ESP.Objects[player].HealthBar then
                ESP.Objects[player].HealthBar:Destroy()
            end
            
            -- Drawingオブジェクトを作成
            local box = Drawing.new("Square")
            box.Visible = false
            box.Color = Config.ESP.BoxColor
            box.Thickness = 1
            box.Filled = false
            
            local name = Drawing.new("Text")
            name.Visible = false
            name.Color = Config.ESP.TextColor
            name.Size = 12 * Config.UI.Scale
            name.Center = true
            name.Outline = true
            
            local healthBar = Drawing.new("Square")
            healthBar.Visible = false
            healthBar.Color = Color3.fromRGB(255, 0, 0)
            healthBar.Thickness = 1
            healthBar.Filled = true
            
            ESP.Objects[player] = {
                Box = box,
                Name = name,
                HealthBar = healthBar,
                Character = character
            }
        end
        
        ESP.Objects[player].Connection = player.CharacterAdded:Connect(onCharacterAdded)
        
        if player.Character then
            onCharacterAdded(player.Character)
        end
    end
    
    -- プレイヤー削除時の処理
    local function onPlayerRemoving(player)
        if ESP.Objects[player] then
            if ESP.Objects[player].Box then
                ESP.Objects[player].Box:Destroy()
            end
            if ESP.Objects[player].Name then
                ESP.Objects[player].Name:Destroy()
            end
            if ESP.Objects[player].HealthBar then
                ESP.Objects[player].HealthBar:Destroy()
            end
            if ESP.Objects[player].Connection then
                ESP.Objects[player].Connection:Disconnect()
            end
            ESP.Objects[player] = nil
        end
    end
    
    -- 初期化
    for _, player in pairs(Players:GetPlayers()) do
        onPlayerAdded(player)
    end
    
    Players.PlayerAdded:Connect(onPlayerAdded)
    Players.PlayerRemoving:Connect(onPlayerRemoving)
    
    -- 更新関数
    function ESP.Update()
        if not Config.ESP.Enabled then
            for player, data in pairs(ESP.Objects) do
                if data.Box then data.Box.Visible = false end
                if data.Name then data.Name.Visible = false end
                if data.HealthBar then data.HealthBar.Visible = false end
            end
            return
        end
        
        for player, data in pairs(ESP.Objects) do
            local character = data.Character or player.Character
            
            if character and character:FindFirstChild("HumanoidRootPart") then
                local hrp = character.HumanoidRootPart
                local humanoid = character:FindFirstChildOfClass("Humanoid")
                
                -- スクリーン位置を取得
                local screenPosition, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                local distance = (hrp.Position - Camera.CFrame.Position).Magnitude
                
                if onScreen and distance <= Config.ESP.MaxDistance then
                    -- サイズを計算（距離に応じて調整）
                    local scale = 1000 / screenPosition.Z
                    local width = 3 * scale
                    local height = 5 * scale
                    
                    -- ボックスを更新
                    data.Box.Size = Vector2.new(width, height)
                    data.Box.Position = Vector2.new(
                        screenPosition.X - width/2,
                        screenPosition.Y - height/2
                    )
                    data.Box.Visible = true
                    
                    -- 名前を更新
                    data.Name.Text = player.Name .. " [" .. math.floor(distance) .. "m]"
                    data.Name.Position = Vector2.new(
                        screenPosition.X,
                        screenPosition.Y - height/2 - 15
                    )
                    data.Name.Visible = true
                    
                    -- ヘルスバーを更新
                    if humanoid and Config.ESP.HealthBar then
                        local healthPercent = humanoid.Health / humanoid.MaxHealth
                        local barHeight = height * healthPercent
                        local barWidth = 3
                        
                        data.HealthBar.Size = Vector2.new(barWidth, barHeight)
                        data.HealthBar.Position = Vector2.new(
                            screenPosition.X - width/2 - barWidth - 2,
                            screenPosition.Y - height/2 + (height - barHeight)
                        )
                        
                        -- ヘルスに応じて色を変更
                        if healthPercent > 0.5 then
                            data.HealthBar.Color = Color3.fromRGB(0, 255, 0)
                        elseif healthPercent > 0.25 then
                            data.HealthBar.Color = Color3.fromRGB(255, 255, 0)
                        else
                            data.HealthBar.Color = Color3.fromRGB(255, 0, 0)
                        end
                        
                        data.HealthBar.Visible = true
                    else
                        data.HealthBar.Visible = false
                    end
                else
                    data.Box.Visible = false
                    data.Name.Visible = false
                    data.HealthBar.Visible = false
                end
            else
                data.Box.Visible = false
                data.Name.Visible = false
                data.HealthBar.Visible = false
            end
        end
    end
    
    -- クリーンアップ
    function ESP.Cleanup()
        for player, data in pairs(ESP.Objects) do
            onPlayerRemoving(player)
        end
        ESP.Objects = {}
    end
    
    return ESP
end

-- エイムアシストシステム
local function CreateAimAssistSystem()
    local AimAssist = {
        CurrentTarget = nil,
        LastUpdate = 0
    }
    
    -- ターゲット取得
    function AimAssist.GetTarget()
        if Config.Target.Mode == "Selected" and Config.Target.Selected then
            local player = Config.Target.Selected
            if player and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                return player
            end
        end
        
        -- 最接近ターゲットを取得
        local closest = nil
        local closestDistance = Config.AimAssist.FOV
        
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                local hrp = player.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(hrp.Position)
                    
                    if onScreen then
                        local distance
                        if TouchInput.Active then
                            -- タッチ位置からの距離を計算
                            distance = (Vector2.new(screenPos.X, screenPos.Y) - TouchInput.CurrentPosition).Magnitude
                        else
                            -- 画面中央からの距離を計算
                            distance = (Vector2.new(screenPos.X, screenPos.Y) - Vector2.new(Camera.ViewportSize.X/2, Camera.ViewportSize.Y/2)).Magnitude
                        end
                        
                        if distance < closestDistance then
                            closestDistance = distance
                            closest = player
                        end
                    end
                end
            end
        end
        
        return closest
    end
    
    -- ターゲットロック
    function AimAssist.LockToTarget()
        if not Config.AimAssist.Enabled then
            AimAssist.CurrentTarget = nil
            return
        end
        
        local target = AimAssist.GetTarget()
        
        if target and target.Character then
            local targetPart = target.Character:FindFirstChild(Config.AimAssist.TargetPart) or target.Character:FindFirstChild("HumanoidRootPart")
            
            if targetPart then
                AimAssist.CurrentTarget = target
                
                -- カメラの向きをスムーズに変更
                local currentCFrame = Camera.CFrame
                local targetPosition = targetPart.Position
                
                -- プレディクション（移動予測）
                local humanoid = target.Character:FindFirstChildOfClass("Humanoid")
                if humanoid then
                    targetPosition = targetPosition + (humanoid.MoveDirection * 0.2)
                end
                
                local lookVector = (targetPosition - currentCFrame.Position).Unit
                local newCFrame = CFrame.new(currentCFrame.Position, currentCFrame.Position + lookVector)
                
                -- スムージングを適用
                Camera.CFrame = currentCFrame:Lerp(newCFrame, Config.AimAssist.Smoothing)
                
                return true
            end
        end
        
        AimAssist.CurrentTarget = nil
        return false
    end
    
    -- タッチベースのエイム補助
    function AimAssist.HandleTouchAim()
        if not TouchInput.Active or not Config.AimAssist.Enabled then
            return
        end
        
        -- タッチ移動量に基づいてカメラを回転
        local delta = TouchInput.CurrentPosition - TouchInput.StartPosition
        local sensitivity = 0.002
        
        -- カメラ回転（制限付き）
        local currentCFrame = Camera.CFrame
        local rotation = CFrame.fromEulerAnglesYXZ(
            -delta.Y * sensitivity,
            -delta.X * sensitivity,
            0
        )
        
        Camera.CFrame = currentCFrame * rotation
    end
    
    return AimAssist
end

-- メインループ
local function Initialize()
    -- UI作成
    local MobileUI = CreateMobileUI()
    
    -- システム初期化
    local ESP = CreateESPSystem()
    local AimAssist = CreateAimAssistSystem()
    
    -- プレイヤーリスト更新関数
    local function UpdatePlayerList()
        local playerArray = {}
        for _, player in pairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                table.insert(playerArray, player)
            end
        end
        MobileUI.UpdatePlayerList(playerArray)
    end
    
    -- メインループ
    local lastESPCheck = 0
    local lastAimCheck = 0
    
    RunService.RenderStepped:Connect(function(deltaTime)
        local now = tick()
        
        -- ESP更新（パフォーマンス対策で間隔をあける）
        if now - lastESPCheck >= Config.ESP.UpdateRate then
            ESP.Update()
            lastESPCheck = now
        end
        
        -- エイムアシスト更新
        if now - lastAimCheck >= 0.05 then
            AimAssist.HandleTouchAim()
            
            if Config.AimAssist.Enabled then
                if AimAssist.LockToTarget() then
                    MobileUI.UpdateStatus("Locked")
                else
                    MobileUI.UpdateStatus("Aiming")
                end
            else
                MobileUI.UpdateStatus("Ready")
            end
            
            lastAimCheck = now
        end
    end)
    
    -- 初期化
    UpdatePlayerList()
    MobileUI.UpdateStatus("Ready")
    
    -- プレイヤー接続/切断時の処理
    Players.PlayerAdded:Connect(UpdatePlayerList)
    Players.PlayerRemoving:Connect(UpdatePlayerList)
    
    -- クリーンアップ関数
    return function()
        ESP.Cleanup()
        if MobileUI.ScreenGui then
            MobileUI.ScreenGui:Destroy()
        end
    end
end

-- スクリプト実行
local cleanup = Initialize()

-- スクリプト終了時のクリーンアップ
game:GetService("UserInputService").WindowFocusReleased:Connect(function()
    if cleanup then
        cleanup()
    end
end)
