--[[
=====================================================================
  增量模拟器 | 合并版 · 第一部分（共两部分）
  包含：UI框架 / 金钱HUD / 管理员面板 / 加载界面 / 城市生成 / 工作系统 / 4种工作
  运行环境：Delta Executor 手机端 LocalScript
  把两部分拼成一个文件后一次粘贴执行
=====================================================================
]]

-- ================== 0. 清理旧实例 ==================
local CoreGui      = game:GetService("CoreGui")
local Players      = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService   = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local HttpService  = game:GetService("HttpService")
local Lighting     = game:GetService("Lighting")
local Workspace    = workspace
local LocalPlayer  = Players.LocalPlayer

for _, g in ipairs(CoreGui:GetChildren()) do
    if g:IsA("ScreenGui") and g.Name == "IncSim_GUI" then g:Destroy() end
    if g:IsA("ScreenGui") and g.Name == "IncSim_Loading" then g:Destroy() end
end
for _, name in ipairs({"IncSim_City", "IncSim_Blur"}) do
    local obj = Workspace:FindFirstChild(name) or Lighting:FindFirstChild(name)
    if obj then obj:Destroy() end
end

-- ================== 1. 全局状态 ==================
_G.IncSim = _G.IncSim or {}
local S = _G.IncSim

S.Money      = 0
S.Cooldowns  = {}
S.Unlocked   = {}
S.Rates      = {
    invest=0.5, stock=0.5, gamble=0.5, lottery=0.05,
    mining=0.10, fishing=0.10, moneyMultiplier=1,
}
S.Passive    = { stock=false, house=false, company=false }
S.PassiveRates = { stock=5, house=15, company=35 }
S.AdminOK    = false
S.CurrentJob = nil
S.SAVE_VERSION = 2
S.JobBuilders = {}
S.NearbyPoints = {}
S.InteractRange = 12

-- ================== 2. 工具函数 ==================
local function fmtMoney(n)
    n = math.floor(n or 0)
    local neg = n < 0
    n = math.abs(n)
    local s = tostring(n)
    local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
    out = out:gsub("^,", "")
    return (neg and "-$" or "$") .. out
end
S.FmtMoney = fmtMoney

local function applyGlass(f, radius, strokeTr, bg)
    f.BackgroundColor3 = bg or Color3.fromRGB(30,34,44)
    f.BackgroundTransparency = 0.35
    f.BorderSizePixel = 0
    local c = f:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 22); c.Parent = f
    local s = f:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
    s.Color = Color3.fromRGB(255,255,255)
    s.Transparency = strokeTr or 0.72
    s.Thickness = 1
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent = f
    return f
end
S.ApplyGlass = applyGlass

local function makeDraggable(frame)
    local dragging, dragStart, startPos
    frame.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
            dragging=true; dragStart=i.Position; startPos=frame.Position
            i.Changed:Connect(function()
                if i.UserInputState==Enum.UserInputState.End then dragging=false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if dragging and (i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch) then
            local d = i.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset+d.X,
                                       startPos.Y.Scale, startPos.Y.Offset+d.Y)
        end
    end)
end
S.MakeDraggable = makeDraggable

local function mkButton(parent, text, size, pos, order, bg)
    local b = Instance.new("TextButton")
    b.Size=size or UDim2.fromScale(0.9,0.08)
    b.Position=pos or UDim2.fromScale(0.05,0)
    b.BackgroundColor3=bg or Color3.fromRGB(45,52,68)
    b.BackgroundTransparency=0.25
    b.BorderSizePixel=0
    b.Text=text
    b.TextColor3=Color3.fromRGB(240,245,255)
    b.TextScaled=true
    b.Font=Enum.Font.GothamBold
    b.AutoButtonColor=false
    b.Active=true
    b.ZIndex=2
    b.LayoutOrder=order or 0
    b.Parent=parent
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,16); c.Parent=b
    local s=Instance.new("UIStroke"); s.Color=Color3.fromRGB(255,255,255)
    s.Transparency=0.7; s.Thickness=1; s.Parent=b
    local p=Instance.new("UIPadding")
    p.PaddingLeft=UDim.new(0,8); p.PaddingRight=UDim.new(0,8); p.Parent=b
    local baseSize, baseBg = size or UDim2.fromScale(0.9,0.08), b.BackgroundTransparency
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b,TweenInfo.new(0.08),{
            Size=UDim2.new(baseSize.X.Scale*0.96,baseSize.X.Offset*0.96,
                           baseSize.Y.Scale*0.96,baseSize.Y.Offset*0.96),
            BackgroundTransparency=0.08,
        }):Play()
    end)
    local function up()
        TweenService:Create(b,TweenInfo.new(0.12),{
            Size=baseSize, BackgroundTransparency=baseBg,
        }):Play()
    end
    b.MouseButton1Up:Connect(up)
    b.MouseLeave:Connect(up)
    return b
end
S.MkButton = mkButton

-- ================== 3. ScreenGui ==================
local gui = Instance.new("ScreenGui")
gui.Name="IncSim_GUI"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.DisplayOrder=9999
gui.Parent=CoreGui

local blur = Instance.new("BlurEffect")
blur.Name="IncSim_Blur"; blur.Size=0; blur.Parent=Lighting

-- ================== 4. 金钱 HUD ==================
local hud = Instance.new("Frame")
hud.Size=UDim2.fromScale(0.42,0.07)
hud.Position=UDim2.new(0.02,0,0.03,0)
hud.ZIndex=3
hud.Parent=gui
applyGlass(hud,18,0.7)

local moneyLbl=Instance.new("TextLabel")
moneyLbl.Size=UDim2.fromScale(0.72,1)
moneyLbl.Position=UDim2.fromScale(0.06,0)
moneyLbl.BackgroundTransparency=1
moneyLbl.Text="$0"
moneyLbl.TextColor3=Color3.fromRGB(255,230,130)
moneyLbl.TextScaled=true
moneyLbl.Font=Enum.Font.GothamBold
moneyLbl.TextXAlignment=Enum.TextXAlignment.Left
moneyLbl.ZIndex=4
moneyLbl.Parent=hud

local minBtn=mkButton(hud,"—",UDim2.fromScale(0.2,0.7),UDim2.fromScale(0.76,0.15),0,
    Color3.fromRGB(60,68,88))
minBtn.ZIndex=5

local bubble=Instance.new("TextButton")
bubble.Size=UDim2.fromOffset(70,70)
bubble.Position=UDim2.new(0.02,0,0.03,0)
bubble.BackgroundColor3=Color3.fromRGB(40,48,62)
bubble.BackgroundTransparency=0.2
bubble.Text="$"; bubble.TextColor3=Color3.fromRGB(255,230,130)
bubble.TextScaled=true; bubble.Font=Enum.Font.GothamBold
bubble.Active=true; bubble.Visible=false; bubble.ZIndex=10; bubble.Parent=gui
local bc=Instance.new("UICorner"); bc.CornerRadius=UDim.new(1,0); bc.Parent=bubble
makeDraggable(bubble)

function S.RefreshMoney()
    moneyLbl.Text=fmtMoney(S.Money)
end
minBtn.Activated:Connect(function() hud.Visible=false; bubble.Visible=true end)
bubble.Activated:Connect(function() bubble.Visible=false; hud.Visible=true end)

function S.AddMoney(a)
    if a==0 then return end
    S.Money=math.max(0,S.Money+a)
    S.RefreshMoney()
    if S.Notify then
        if a>0 then S.Notify("+$"..math.floor(a), Color3.fromRGB(80,220,120))
        else        S.Notify("-$"..math.floor(-a), Color3.fromRGB(255,100,100)) end
    end
end
function S.SetMoney(a) S.Money=math.max(0,math.floor(a)); S.RefreshMoney() end

-- ================== 5. 通知栏 ==================
local nc=Instance.new("Frame")
nc.Size=UDim2.fromScale(0.42,0.5)
nc.Position=UDim2.new(0.56,0,0.05,0)
nc.BackgroundTransparency=1
nc.ZIndex=20
nc.Parent=gui
local nl=Instance.new("UIListLayout")
nl.SortOrder=Enum.SortOrder.LayoutOrder
nl.Padding=UDim.new(0,6)
nl.HorizontalAlignment=Enum.HorizontalAlignment.Right
nl.Parent=nc

function S.Notify(text, color)
    color = color or Color3.fromRGB(220,230,255)
    local n=Instance.new("Frame")
    n.Size=UDim2.fromScale(0.95,0.09)
    n.BackgroundColor3=Color3.fromRGB(30,34,44)
    n.BackgroundTransparency=0.25
    n.ZIndex=21
    n.Parent=nc
    applyGlass(n,14,0.7)
    local l=Instance.new("TextLabel")
    l.Size=UDim2.fromScale(0.9,1)
    l.Position=UDim2.fromScale(0.05,0)
    l.BackgroundTransparency=1
    l.Text=text; l.TextColor3=color; l.TextScaled=true
    l.Font=Enum.Font.GothamBold
    l.TextXAlignment=Enum.TextXAlignment.Right
    l.ZIndex=22; l.Parent=n
    n.Position=UDim2.fromScale(1.2,0)
    TweenService:Create(n,TweenInfo.new(0.18),{Position=UDim2.fromScale(0,0)}):Play()
    task.delay(2,function()
        if n.Parent then
            local t=TweenService:Create(n,TweenInfo.new(0.18),{Position=UDim2.fromScale(1.2,0)})
            t:Play(); t.Completed:Connect(function() n:Destroy() end)
        end
    end)
end

-- ================== 6. 任务 HUD ==================
local taskHud=Instance.new("Frame")
taskHud.Size=UDim2.fromScale(0.5,0.06)
taskHud.Position=UDim2.new(0.25,0,0.02,0)
taskHud.Visible=false; taskHud.ZIndex=4; taskHud.Parent=gui
applyGlass(taskHud,14,0.7)

local taskLbl=Instance.new("TextLabel")
taskLbl.Size=UDim2.fromScale(0.94,1)
taskLbl.Position=UDim2.fromScale(0.03,0)
taskLbl.BackgroundTransparency=1
taskLbl.Text="当前任务：无"
taskLbl.TextColor3=Color3.fromRGB(220,230,255)
taskLbl.TextScaled=true
taskLbl.Font=Enum.Font.GothamMedium
taskLbl.ZIndex=5
taskLbl.Parent=taskHud

function S.SetTask(text)
    if text and text~="" then
        taskLbl.Text="当前任务："..text; taskHud.Visible=true
    else taskHud.Visible=false end
end

-- ================== 7. 管理员悬浮球 ==================
local adminBall=Instance.new("TextButton")
adminBall.Size=UDim2.fromOffset(60,60)
adminBall.Position=UDim2.new(0.9,0,0.8,0)
adminBall.BackgroundColor3=Color3.fromRGB(80,60,140)
adminBall.BackgroundTransparency=0.15
adminBall.Text="⚙"; adminBall.TextColor3=Color3.fromRGB(255,255,255)
adminBall.TextScaled=true; adminBall.Font=Enum.Font.GothamBold
adminBall.Active=true; adminBall.ZIndex=30; adminBall.Parent=gui
local ac=Instance.new("UICorner"); ac.CornerRadius=UDim.new(1,0); ac.Parent=adminBall
local as=Instance.new("UIStroke"); as.Color=Color3.fromRGB(255,255,255)
as.Transparency=0.5; as.Thickness=1.5; as.Parent=adminBall
makeDraggable(adminBall)

-- ================== 8. 管理员面板 ==================
local adminPanel=Instance.new("Frame")
adminPanel.Name="AdminPanel"
adminPanel.Size=UDim2.fromScale(0.9,0.75)
adminPanel.Position=UDim2.fromScale(0.05,0.125)
adminPanel.Visible=false
adminPanel.ZIndex=40
adminPanel.Parent=gui
applyGlass(adminPanel,24,0.65,Color3.fromRGB(24,28,38))

local titleBar=Instance.new("TextLabel")
titleBar.Size=UDim2.fromScale(0.9,0.07)
titleBar.Position=UDim2.fromScale(0.05,0.015)
titleBar.BackgroundTransparency=1
titleBar.Text="管理员面板"
titleBar.TextColor3=Color3.fromRGB(255,255,255)
titleBar.TextScaled=true
titleBar.Font=Enum.Font.GothamBold
titleBar.ZIndex=41
titleBar.Parent=adminPanel

local closeBtn=mkButton(adminPanel,"✕",UDim2.fromScale(0.1,0.06),UDim2.fromScale(0.86,0.02),0,
    Color3.fromRGB(120,50,50))
closeBtn.ZIndex=42
closeBtn.Activated:Connect(function()
    adminPanel.Visible=false
    blur.Size=0
end)

local pwBox=Instance.new("TextBox")
pwBox.Size=UDim2.fromScale(0.7,0.07)
pwBox.Position=UDim2.fromScale(0.05,0.10)
pwBox.BackgroundColor3=Color3.fromRGB(40,46,58)
pwBox.BackgroundTransparency=0.2
pwBox.Text=""
pwBox.PlaceholderText="输入密码"
pwBox.TextColor3=Color3.fromRGB(240,245,255)
pwBox.PlaceholderColor3=Color3.fromRGB(160,170,190)
pwBox.TextScaled=true
pwBox.Font=Enum.Font.GothamMedium
pwBox.ClearTextOnFocus=false
pwBox.TextEditable=true
pwBox.ZIndex=42
pwBox.Parent=adminPanel
local pwc=Instance.new("UICorner"); pwc.CornerRadius=UDim.new(0,14); pwc.Parent=pwBox

local pwBtn=mkButton(adminPanel,"验证",UDim2.fromScale(0.18,0.07),UDim2.fromScale(0.77,0.10),0)
pwBtn.ZIndex=42

local content=Instance.new("ScrollingFrame")
content.Size=UDim2.fromScale(0.9,0.78)
content.Position=UDim2.fromScale(0.05,0.19)
content.BackgroundTransparency=1
content.BorderSizePixel=0
content.ScrollBarThickness=4
content.ScrollBarImageColor3=Color3.fromRGB(180,190,220)
content.CanvasSize=UDim2.new(0,0,0,0)
content.AutomaticCanvasSize=Enum.AutomaticSize.Y
content.ClipsDescendants=true
content.ZIndex=41
content.Parent=adminPanel
local contentLayout=Instance.new("UIListLayout")
contentLayout.Padding=UDim.new(0,6)
contentLayout.SortOrder=Enum.SortOrder.LayoutOrder
contentLayout.Parent=content

local function contentBtn(text, order, bg, cb)
    local b=mkButton(content,text,UDim2.new(1,-8,0,52),UDim2.fromOffset(4,0),order,bg)
    b.ZIndex=42
    b.Activated:Connect(cb)
    return b
end

local adminBtnList = {}
local function reg(v) table.insert(adminBtnList, v); return v end

pwBtn.Activated:Connect(function()
    if pwBox.Text=="6767" then
        S.AdminOK=true
        S.Notify("管理员验证通过",Color3.fromRGB(120,220,160))
        for _,c in ipairs(adminBtnList) do c.Visible=true end
    else
        S.Notify("密码错误",Color3.fromRGB(255,120,120))
    end
end)

-- --- 金钱管理 ---
local moneyInput=Instance.new("TextBox")
moneyInput.Size=UDim2.new(1,-8,0,48)
moneyInput.Position=UDim2.fromOffset(4,0)
moneyInput.BackgroundColor3=Color3.fromRGB(40,46,58)
moneyInput.BackgroundTransparency=0.2
moneyInput.Text=""
moneyInput.PlaceholderText="输入金额"
moneyInput.TextColor3=Color3.fromRGB(240,245,255)
moneyInput.TextScaled=true
moneyInput.Font=Enum.Font.GothamMedium
moneyInput.ClearTextOnFocus=false
moneyInput.TextEditable=true
moneyInput.LayoutOrder=1
moneyInput.Visible=false
moneyInput.ZIndex=42
moneyInput.Parent=content
local mic=Instance.new("UICorner"); mic.CornerRadius=UDim.new(0,14); mic.Parent=moneyInput
reg(moneyInput)

local function numOf(str)
    local n = tonumber(str); if not n then return nil end
    return math.floor(n)
end

reg(contentBtn("加钱",2,nil,function()
    local n=numOf(moneyInput.Text)
    if not n then S.Notify("请输入数字",Color3.fromRGB(255,120,120)); return end
    S.AddMoney(n)
end))
reg(contentBtn("设为",3,nil,function()
    local n=numOf(moneyInput.Text)
    if not n then S.Notify("请输入数字",Color3.fromRGB(255,120,120)); return end
    S.SetMoney(n)
end))
reg(contentBtn("清空金钱",4,Color3.fromRGB(120,50,50),function()
    S.SetMoney(0)
end))

-- --- 概率调整 ---
local rateKeys={"invest","stock","gamble","lottery","mining","fishing"}
local rateNames={invest="投资",stock="股市",gamble="赌博",lottery="彩票",mining="挖矿",fishing="钓鱼"}
for i,k in ipairs(rateKeys) do
    local label=Instance.new("TextButton")
    label.Size=UDim2.new(1,-8,0,46)
    label.Position=UDim2.fromOffset(4,0)
    label.BackgroundColor3=Color3.fromRGB(40,46,58)
    label.BackgroundTransparency=0.2
    label.Text=rateNames[k].."："..math.floor(S.Rates[k]*100).."%"
    label.TextScaled=true
    label.Font=Enum.Font.GothamMedium
    label.TextColor3=Color3.fromRGB(230,235,250)
    label.LayoutOrder=10+i
    label.Visible=false
    label.Active=true
    label.ZIndex=42
    label.Parent=content
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,14); c.Parent=label
    reg(label)
    label.Activated:Connect(function()
        local v = S.Rates[k] + 0.1
        if v > 1.0 + 1e-6 then v = 0.1 end
        S.Rates[k] = v
        label.Text = rateNames[k].."："..math.floor(v*100+0.5).."%"
        S.Notify(rateNames[k].." → "..math.floor(v*100+0.5).."%")
    end)
end

local multBtn=Instance.new("TextButton")
multBtn.Size=UDim2.new(1,-8,0,46)
multBtn.Position=UDim2.fromOffset(4,0)
multBtn.BackgroundColor3=Color3.fromRGB(40,46,58)
multBtn.BackgroundTransparency=0.2
multBtn.Text="全局倍率："..S.Rates.moneyMultiplier.."x"
multBtn.TextScaled=true
multBtn.Font=Enum.Font.GothamMedium
multBtn.TextColor3=Color3.fromRGB(230,235,250)
multBtn.LayoutOrder=20
multBtn.Visible=false
multBtn.Active=true
multBtn.ZIndex=42
multBtn.Parent=content
local mc2=Instance.new("UICorner"); mc2.CornerRadius=UDim.new(0,14); mc2.Parent=multBtn
reg(multBtn)
multBtn.Activated:Connect(function()
    S.Rates.moneyMultiplier = (S.Rates.moneyMultiplier + 5)
    if S.Rates.moneyMultiplier > 100 then S.Rates.moneyMultiplier = 1 end
    multBtn.Text = "全局倍率："..S.Rates.moneyMultiplier.."x"
end)

-- --- 工作相关 ---
reg(contentBtn("解锁全部工作",30,nil,function()
    for i=1,30 do S.Unlocked[i]=true end
    S.Notify("已解锁全部工作")
    if S.RebuildJobList then S.RebuildJobList() end
end))
reg(contentBtn("重置工作冷却",31,nil,function()
    S.Cooldowns={}
    S.Notify("冷却已重置")
end))
reg(contentBtn("一键完成当前任务",32,nil,function()
    if S.CompleteCurrentJob then S.CompleteCurrentJob() end
end))

-- --- 玩家/系统 ---
reg(contentBtn("显示当前坐标",40,nil,function()
    local p=LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if p then
        S.Notify(string.format("X:%d Y:%d Z:%d",
            math.floor(p.Position.X),math.floor(p.Position.Y),math.floor(p.Position.Z)))
    else
        S.Notify("角色未加载",Color3.fromRGB(255,120,120))
    end
end))

reg(contentBtn("查看被动收入状态",41,nil,function()
    local t=""
    for k,v in pairs(S.Passive) do t=t..k.."="..(v and "开" or "关").." " end
    S.Notify(t~="" and t or "无被动")
end))

-- 存档区
local saveBox=Instance.new("TextBox")
saveBox.Size=UDim2.new(1,-8,0,120)
saveBox.Position=UDim2.fromOffset(4,0)
saveBox.BackgroundColor3=Color3.fromRGB(40,46,58)
saveBox.BackgroundTransparency=0.2
saveBox.Text=""
saveBox.PlaceholderText="存档码"
saveBox.TextColor3=Color3.fromRGB(240,245,255)
saveBox.TextScaled=false
saveBox.TextSize=14
saveBox.TextWrapped=true
saveBox.MultiLine=true
saveBox.ClearTextOnFocus=false
saveBox.TextEditable=true
saveBox.LayoutOrder=50
saveBox.Visible=false
saveBox.ZIndex=42
saveBox.Parent=content
local sbc=Instance.new("UICorner"); sbc.CornerRadius=UDim.new(0,14); sbc.Parent=saveBox
reg(saveBox)

S.SerializeSave = function()
    local data = {
        version=S.SAVE_VERSION, savedAt=os.time(),
        money=S.Money, unlocked=S.Unlocked,
        passive=S.Passive, rates=S.Rates, cooldowns=S.Cooldowns,
    }
    local ok,js=pcall(function() return HttpService:JSONEncode(data) end)
    return ok and js or nil
end

S.DeserializeSave = function(str)
    local ok,data=pcall(function() return HttpService:JSONDecode(str) end)
    if not ok or type(data)~="table" then return false,"存档码无效" end
    if data.money and type(data.money)=="number" then S.SetMoney(data.money) end
    if data.unlocked and type(data.unlocked)=="table" then S.Unlocked=data.unlocked end
    if data.passive and type(data.passive)=="table" then
        for k,v in pairs(S.Passive) do
            if data.passive[k]~=nil then S.Passive[k]=data.passive[k] and true or false end
        end
    end
    if data.rates and type(data.rates)=="table" then
        for k,v in pairs(S.Rates) do
            if type(data.rates[k])=="number" then S.Rates[k]=data.rates[k] end
        end
    end
    if data.cooldowns and type(data.cooldowns)=="table" then
        S.Cooldowns={}
        for k,v in pairs(data.cooldowns) do
            if type(v)=="number" then S.Cooldowns[k]=v end
        end
    end
    return true
end

reg(contentBtn("导出存档",51,nil,function()
    local js=S.SerializeSave()
    if js then saveBox.Text=js; S.Notify("已导出到下方文本框")
    else S.Notify("导出失败",Color3.fromRGB(255,120,120)) end
end))
reg(contentBtn("导入存档",52,nil,function()
    if saveBox.Text=="" then S.Notify("请先粘贴存档码",Color3.fromRGB(255,180,120)); return end
    local ok,err=S.DeserializeSave(saveBox.Text)
    if ok then S.Notify("存档已导入",Color3.fromRGB(120,220,160))
    else S.Notify(err or "导入失败",Color3.fromRGB(255,120,120)) end
end))
reg(contentBtn("重置全部进度",53,Color3.fromRGB(120,50,50),function()
    S.Money=0; S.Cooldowns={}; S.Unlocked={}
    S.Passive={stock=false,house=false,company=false}
    S.Rates={invest=0.5,stock=0.5,gamble=0.5,lottery=0.05,mining=0.10,fishing=0.10,moneyMultiplier=1}
    S.RefreshMoney()
    S.Notify("全部进度已重置")
end))

adminBall.Activated:Connect(function()
    adminPanel.Visible=true
    blur.Size=14
end)

-- ================== 9. 城市容器 ==================
local cityFolder = Instance.new("Folder")
cityFolder.Name = "IncSim_City"
cityFolder.Parent = workspace

local roadsFolder    = Instance.new("Folder"); roadsFolder.Name="Roads";    roadsFolder.Parent=cityFolder
local buildingsFolder= Instance.new("Folder"); buildingsFolder.Name="Buildings"; buildingsFolder.Parent=cityFolder
local propsFolder    = Instance.new("Folder"); propsFolder.Name="Props";   propsFolder.Parent=cityFolder
local markersFolder  = Instance.new("Folder"); markersFolder.Name="Markers"; markersFolder.Parent=cityFolder

-- ================== 10. 加载界面 ==================
local loadingGui = Instance.new("ScreenGui")
loadingGui.Name="IncSim_Loading"
loadingGui.ResetOnSpawn=false
loadingGui.DisplayOrder=10000
loadingGui.IgnoreGuiInset=true
loadingGui.Parent=CoreGui

local loadBg = Instance.new("Frame")
loadBg.Size=UDim2.fromScale(1,1)
loadBg.BackgroundColor3=Color3.fromRGB(12,14,20)
loadBg.BorderSizePixel=0
loadBg.ZIndex=1
loadBg.Parent=loadingGui

local loadCard = Instance.new("Frame")
loadCard.Size=UDim2.fromScale(0.85,0.35)
loadCard.Position=UDim2.fromScale(0.075,0.325)
loadCard.BackgroundColor3=Color3.fromRGB(30,34,44)
loadCard.BackgroundTransparency=0.25
loadCard.BorderSizePixel=0
loadCard.ZIndex=2
loadCard.Parent=loadingGui
applyGlass(loadCard,26,0.6)

local loadTitle=Instance.new("TextLabel")
loadTitle.Size=UDim2.fromScale(0.9,0.22)
loadTitle.Position=UDim2.fromScale(0.05,0.1)
loadTitle.BackgroundTransparency=1
loadTitle.Text="正在加载地图组件"
loadTitle.TextColor3=Color3.fromRGB(240,245,255)
loadTitle.TextScaled=true
loadTitle.Font=Enum.Font.GothamBold
loadTitle.ZIndex=3
loadTitle.Parent=loadCard

local loadCount=Instance.new("TextLabel")
loadCount.Size=UDim2.fromScale(0.9,0.16)
loadCount.Position=UDim2.fromScale(0.05,0.36)
loadCount.BackgroundTransparency=1
loadCount.Text="已加载 0 / 0"
loadCount.TextColor3=Color3.fromRGB(200,210,235)
loadCount.TextScaled=true
loadCount.Font=Enum.Font.GothamMedium
loadCount.ZIndex=3
loadCount.Parent=loadCard

local loadHint=Instance.new("TextLabel")
loadHint.Size=UDim2.fromScale(0.9,0.14)
loadHint.Position=UDim2.fromScale(0.05,0.55)
loadHint.BackgroundTransparency=1
loadHint.Text="准备中…"
loadHint.TextColor3=Color3.fromRGB(170,180,205)
loadHint.TextScaled=true
loadHint.Font=Enum.Font.Gotham
loadHint.ZIndex=3
loadHint.Parent=loadCard

local barBg=Instance.new("Frame")
barBg.Size=UDim2.fromScale(0.9,0.08)
barBg.Position=UDim2.fromScale(0.05,0.78)
barBg.BackgroundColor3=Color3.fromRGB(50,56,70)
barBg.BackgroundTransparency=0.2
barBg.BorderSizePixel=0
barBg.ZIndex=3
barBg.Parent=loadCard
local barBgC=Instance.new("UICorner"); barBgC.CornerRadius=UDim.new(1,0); barBgC.Parent=barBg

local barFill=Instance.new("Frame")
barFill.Size=UDim2.fromScale(0,1)
barFill.BackgroundColor3=Color3.fromRGB(120,190,255)
barFill.BorderSizePixel=0
barFill.ZIndex=4
barFill.Parent=barBg
local barFillC=Instance.new("UICorner"); barFillC.CornerRadius=UDim.new(1,0); barFillC.Parent=barFill

local loadTotal = 0
local loadDone  = 0
local function addTotal(n) loadTotal = loadTotal + (n or 1) end
local function tickProgress(hint)
    loadDone = loadDone + 1
    if loadDone > loadTotal then loadDone = loadTotal end
    loadCount.Text = string.format("已加载 %d / %d", loadDone, loadTotal)
    local ratio = loadTotal > 0 and (loadDone/loadTotal) or 0
    barFill.Size = UDim2.fromScale(ratio, 1)
    if hint then loadHint.Text = hint end
end

-- ================== 11. 材质与配色 ==================
local COL = {
    road=Color3.fromRGB(48,48,52), roadLine=Color3.fromRGB(235,235,210),
    roadDash=Color3.fromRGB(230,230,210), sidewalk=Color3.fromRGB(170,170,175),
    curb=Color3.fromRGB(120,120,125), crosswalk=Color3.fromRGB(240,240,235),
    grass=Color3.fromRGB(80,140,80),
    bldA=Color3.fromRGB(120,140,170), bldB=Color3.fromRGB(150,140,130),
    bldC=Color3.fromRGB(180,180,190), bldD=Color3.fromRGB(110,120,140),
    glass=Color3.fromRGB(140,180,220), roof=Color3.fromRGB(90,90,100),
    shop=Color3.fromRGB(200,140,90), warehouse=Color3.fromRGB(150,150,155),
    lampPole=Color3.fromRGB(60,60,65), lampHead=Color3.fromRGB(255,240,180),
    treeTrunk=Color3.fromRGB(90,60,40), treeLeaf=Color3.fromRGB(60,140,70),
}

local function newPart(parent, size, cframe, color, material, shape)
    local p = Instance.new("Part")
    p.Size=size; p.CFrame=cframe; p.Color=color
    p.Material=material or Enum.Material.SmoothPlastic
    p.Anchored=true; p.CanCollide=true
    p.TopSurface=Enum.SurfaceType.Smooth; p.BottomSurface=Enum.SurfaceType.Smooth
    if shape then p.Shape=shape end
    p.Parent=parent
    return p
end

-- ================== 12. 城市参数 ==================
local GRID      = 5
local CELL      = 220
local MAIN_W    = 50
local SUB_W     = 26
local SIDEWALK  = 10
local ROAD_Y    = 1
local SW_Y      = 1.5
local TOTAL     = GRID * CELL
local half      = TOTAL / 2

addTotal(GRID * 2 + 2)
addTotal(GRID + 1)
addTotal(GRID * 2)
addTotal(GRID * GRID * 4)
addTotal(GRID * GRID)
addTotal(GRID * GRID * 4)

-- 地面
addTotal(1)
newPart(cityFolder, Vector3.new(TOTAL+400, 2, TOTAL+400),
    CFrame.new(TOTAL/2, 0, TOTAL/2), COL.grass, Enum.Material.Grass)
tickProgress("正在铺设地面…")

-- 主干道
local function buildMainRoad(cx, cz, horizontal)
    local w,l
    if horizontal then w,l = Vector3.new(TOTAL+400,0.4,MAIN_W)
    else w,l = Vector3.new(MAIN_W,0.4,TOTAL+400) end
    newPart(roadsFolder, w, CFrame.new(cx, ROAD_Y, cz), COL.road, Enum.Material.Asphalt)
    local dashLen, gap = 20, 20
    local start = -TOTAL/2
    local i = start
    while i < TOTAL/2 do
        if horizontal then
            newPart(roadsFolder, Vector3.new(dashLen,0.05,1.2),
                CFrame.new(cx+i+dashLen/2, ROAD_Y+0.21, cz), COL.roadDash)
        else
            newPart(roadsFolder, Vector3.new(1.2,0.05,dashLen),
                CFrame.new(cx, ROAD_Y+0.21, cz+i+dashLen/2), COL.roadDash)
        end
        i = i + dashLen + gap
    end
    local off = MAIN_W/2 - 3
    for s=-1,1,2 do
        if horizontal then
            newPart(roadsFolder, Vector3.new(TOTAL,0.05,1),
                CFrame.new(cx, ROAD_Y+0.21, cz+s*off), COL.roadLine)
        else
            newPart(roadsFolder, Vector3.new(1,0.05,TOTAL),
                CFrame.new(cx+s*off, ROAD_Y+0.21, cz), COL.roadLine)
        end
    end
end

buildMainRoad(TOTAL/2, TOTAL/2, true)
tickProgress("正在生成主干道…")
buildMainRoad(TOTAL/2, TOTAL/2, false)
tickProgress("正在生成主干道…")

-- 街区地块 + 人行道
for gx=0, GRID-1 do
    for gz=0, GRID-1 do
        local cx = gx*CELL + CELL/2
        local cz = gz*CELL + CELL/2
        newPart(cityFolder, Vector3.new(CELL-SUB_W, 0.3, CELL-SUB_W),
            CFrame.new(cx, 0.4, cz), COL.grass, Enum.Material.Grass)
        local sw = SIDEWALK
        newPart(roadsFolder, Vector3.new(CELL,0.4,sw),
            CFrame.new(cx, SW_Y, cz-(CELL-SUB_W)/2-sw/2), COL.sidewalk, Enum.Material.Concrete)
        newPart(roadsFolder, Vector3.new(CELL,0.4,sw),
            CFrame.new(cx, SW_Y, cz+(CELL-SUB_W)/2+sw/2), COL.sidewalk, Enum.Material.Concrete)
        newPart(roadsFolder, Vector3.new(sw,0.4,CELL),
            CFrame.new(cx-(CELL-SUB_W)/2-sw/2, SW_Y, cz), COL.sidewalk, Enum.Material.Concrete)
        newPart(roadsFolder, Vector3.new(sw,0.4,CELL),
            CFrame.new(cx+(CELL-SUB_W)/2+sw/2, SW_Y, cz), COL.sidewalk, Enum.Material.Concrete)
        tickProgress()
    end
end

-- 次干道
for gx=0, GRID do
    for gz=0, GRID-1 do
        local x = gx*CELL
        if x > 0 and x < TOTAL then
            newPart(roadsFolder, Vector3.new(SUB_W,0.35,CELL),
                CFrame.new(x, ROAD_Y, gz*CELL+CELL/2), COL.road, Enum.Material.Asphalt)
            tickProgress()
        end
    end
end

-- 斑马线
for gx=1, GRID-1 do
    for gz=1, GRID-1 do
        local x = gx*CELL
        local z = gz*CELL
        for i=-3,3 do
            newPart(roadsFolder, Vector3.new(4,0.06,40),
                CFrame.new(x+i*6, ROAD_Y+0.22, z), COL.crosswalk)
            newPart(roadsFolder, Vector3.new(40,0.06,4),
                CFrame.new(x, ROAD_Y+0.22, z+i*6), COL.crosswalk)
        end
    end
end
tickProgress("正在铺设斑马线…")

-- 路灯
local function buildLamp(x, z, facing)
    local pole = newPart(propsFolder, Vector3.new(0.6,12,0.6),
        CFrame.new(x, 6, z), COL.lampPole, Enum.Material.Metal)
    local head = newPart(propsFolder, Vector3.new(3,0.8,1.5),
        CFrame.new(x+facing.X*2, 11.5, z+facing.Z*2), COL.lampHead, Enum.Material.Neon)
    local distToCenter = (Vector3.new(x,0,z)-Vector3.new(half,0,half)).Magnitude
    if distToCenter < CELL * 2.5 then
        local pt=Instance.new("PointLight")
        pt.Range=26; pt.Brightness=1.2; pt.Color=COL.lampHead; pt.Parent=head
    end
end

for gx=0, GRID do
    for gz=0, GRID do
        local x = gx*CELL
        local z = gz*CELL
        if x<=TOTAL and z<=TOTAL then
            buildLamp(x+6, z+6, Vector3.new(1,0,1))
            buildLamp(x-6, z-6, Vector3.new(-1,0,-1))
            tickProgress()
        end
    end
    task.wait()
end

-- ================== 13. 建筑 ==================
local function buildBuilding(cx, cz, w, d, h, baseColor, style)
    newPart(buildingsFolder, Vector3.new(w,h,d),
        CFrame.new(cx, h/2, cz), baseColor, Enum.Material.Concrete)

    local winW, winH = 3, 3
    local winColor = style=="office" and COL.glass or Color3.fromRGB(200,220,240)
    local floors = math.floor(h/8)
    local colsFront = math.max(1, math.floor(w/6))
    local colsSide  = math.max(1, math.floor(d/6))
    for f=1, floors do
        local y = f*8 - 3
        for i=1, colsFront do
            local x = cx - w/2 + (i-0.5)*(w/colsFront)
            newPart(buildingsFolder, Vector3.new(winW,winH,0.4),
                CFrame.new(x, y, cz+d/2+0.2), winColor,
                style=="office" and Enum.Material.Glass or Enum.Material.SmoothPlastic)
            newPart(buildingsFolder, Vector3.new(winW,winH,0.4),
                CFrame.new(x, y, cz-d/2-0.2), winColor,
                style=="office" and Enum.Material.Glass or Enum.Material.SmoothPlastic)
        end
        for i=1, colsSide do
            local z = cz - d/2 + (i-0.5)*(d/colsSide)
            newPart(buildingsFolder, Vector3.new(0.4,winH,winW),
                CFrame.new(cx+w/2+0.2, y, z), winColor,
                style=="office" and Enum.Material.Glass or Enum.Material.SmoothPlastic)
            newPart(buildingsFolder, Vector3.new(0.4,winH,winW),
                CFrame.new(cx-w/2-0.2, y, z), winColor,
                style=="office" and Enum.Material.Glass or Enum.Material.SmoothPlastic)
        end
    end

    newPart(buildingsFolder, Vector3.new(w+1,1,d+1),
        CFrame.new(cx, h+0.5, cz), COL.roof, Enum.Material.Slate)

    local doorW, doorH = 4, 6
    local door = newPart(buildingsFolder, Vector3.new(doorW,doorH,0.6),
        CFrame.new(cx, doorH/2+0.5, cz+d/2+0.3),
        Color3.fromRGB(60,40,30), Enum.Material.Wood)
    door.CanCollide = false

    local sign = newPart(buildingsFolder, Vector3.new(math.min(w-2,12),2.4,0.4),
        CFrame.new(cx, doorH+2.5, cz+d/2+0.5),
        style=="shop" and COL.shop or (style=="warehouse" and COL.warehouse or baseColor),
        Enum.Material.SmoothPlastic)
    sign.CanCollide = false

    local sg=Instance.new("SurfaceGui")
    sg.Face=Enum.NormalId.Front
    sg.CanvasSize=Vector2.new(200,60)
    sg.Parent=sign
    local tl=Instance.new("TextLabel")
    tl.Size=UDim2.fromScale(1,1)
    tl.BackgroundTransparency=1
    tl.Text=string.format("%d号楼", math.random(1,99))
    tl.TextColor3=Color3.fromRGB(20,20,20)
    tl.TextScaled=true
    tl.Font=Enum.Font.GothamBold
    tl.Parent=sg
end

local totalCells = GRID * GRID
local builtCount = 0

for gx=0, GRID-1 do
    for gz=0, GRID-1 do
        local cx = gx*CELL + CELL/2
        local cz = gz*CELL + CELL/2
        local plotHalf = (CELL - SUB_W - SIDEWALK) / 2
        local style = "shop"
        if gx<=1 and gz<=1 then style="office"
        elseif gx>=3 and gz>=3 then style="warehouse"
        elseif (gx+gz)%2==0 then style="residential"
        else style="shop" end

        local count = math.random(1,3)
        local subW = plotHalf*2/count
        for i=1, count do
            local bx = cx - plotHalf + (i-0.5)*subW
            local bz = cz + math.random(-8,8)
            local w = subW*0.85
            local d = math.min(subW*0.85, CELL*0.6)
            local h
            if style=="office" then h=math.random(40,70)
            elseif style=="warehouse" then h=math.random(10,16)
            else h=math.random(14,28) end

            local colorPick
            local r=math.random(1,4)
            if r==1 then colorPick=COL.bldA
            elseif r==2 then colorPick=COL.bldB
            elseif r==3 then colorPick=COL.bldC
            else colorPick=COL.bldD end

            addTotal(1)
            buildBuilding(bx, bz, w, d, h, colorPick, style)
            tickProgress()
            builtCount = builtCount + 1
        end
        task.wait()
    end
end

-- 街道细节
local function buildTree(x, z)
    newPart(propsFolder, Vector3.new(1.6,8,1.6), CFrame.new(x,4,z), COL.treeTrunk, Enum.Material.Wood)
    for i=0,2 do
        local r = 3.6 - i*0.6
        newPart(propsFolder, Vector3.new(r*2,r*2,r*2),
            CFrame.new(x, 9+i*1.6, z), COL.treeLeaf, Enum.Material.LeafyGrass, Enum.PartType.Ball)
    end
end
local function buildBench(x, z)
    newPart(propsFolder, Vector3.new(4,0.4,1.4), CFrame.new(x,2.2,z), Color3.fromRGB(120,80,50), Enum.Material.Wood)
    for _,s in ipairs({-1.4,1.4}) do
        newPart(propsFolder, Vector3.new(0.4,1.6,1.2), CFrame.new(x+s,1.2,z), Color3.fromRGB(60,60,65), Enum.Material.Metal)
    end
end
local function buildTrash(x, z)
    newPart(propsFolder, Vector3.new(2,3,2), CFrame.new(x,1.9,z), Color3.fromRGB(70,80,70), Enum.Material.Metal, Enum.PartType.Cylinder)
end

for gx=0, GRID do
    for gz=0, GRID do
        local x = gx*CELL
        local z = gz*CELL
        if x>20 and x<TOTAL-20 and z>20 and z<TOTAL-20 then
            if math.random()<0.5 then buildTree(x+math.random(-20,20), z+math.random(-20,20)) end
            if math.random()<0.4 then buildBench(x+15, z+15) end
            if math.random()<0.4 then buildTrash(x-15, z-15) end
        end
    end
end
tickProgress("正在放置街道设施…")

-- 记录地块坐标
S.MapCells = {}
for gx=0, GRID-1 do
    for gz=0, GRID-1 do
        table.insert(S.MapCells, Vector3.new(gx*CELL+CELL/2, 3, gz*CELL+CELL/2))
    end
end

local plaza = Instance.new("Part")
plaza.Name="CentralPlaza"
plaza.Size=Vector3.new(60,1,60)
plaza.Position=Vector3.new(TOTAL/2, 1, TOTAL/2)
plaza.Color=Color3.fromRGB(200,190,150)
plaza.Material=Enum.Material.Marble
plaza.Anchored=true
plaza.Parent=markersFolder

-- ================== 14. 昼夜 ==================
Lighting.ClockTime = 14
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(120,120,130)
Lighting.OutdoorAmbient = Color3.fromRGB(140,140,150)
Lighting.GlobalShadows = true

S.DayNightRunning = true
task.spawn(function()
    while S.DayNightRunning do
        task.wait(2.5)
        Lighting.ClockTime = (Lighting.ClockTime + 1) % 24
    end
end)

-- ================== 15. 加载完成 ==================
loadHint.Text = "加载完成！"
barFill.Size = UDim2.fromScale(1,1)
loadCount.Text = string.format("已加载 %d / %d", loadTotal, loadTotal)

task.wait(0.6)
TweenService:Create(loadBg, TweenInfo.new(0.6), {BackgroundTransparency=1}):Play()
TweenService:Create(loadCard, TweenInfo.new(0.6), {BackgroundTransparency=1}):Play()
task.wait(0.7)
loadingGui:Destroy()

pcall(function()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp then hrp.CFrame = CFrame.new(TOTAL/2, 8, TOTAL/2 + 40) end
end)

S.Notify("城市已加载：" .. builtCount .. " 栋建筑", Color3.fromRGB(120,220,160))

-- ================== 16. 交互按钮 ==================
local actionBtn = Instance.new("TextButton")
actionBtn.Name="ActionBtn"
actionBtn.Size=UDim2.fromScale(0.6,0.09)
actionBtn.Position=UDim2.fromScale(0.2,0.86)
actionBtn.BackgroundColor3=Color3.fromRGB(70,140,220)
actionBtn.BackgroundTransparency=0.15
actionBtn.Text="交互"
actionBtn.TextColor3=Color3.fromRGB(255,255,255)
actionBtn.TextScaled=true
actionBtn.Font=Enum.Font.GothamBold
actionBtn.Active=true
actionBtn.Visible=false
actionBtn.ZIndex=60
actionBtn.Parent=gui
applyGlass(actionBtn,20,0.6,Color3.fromRGB(60,120,200))

local actionHint = Instance.new("TextLabel")
actionHint.Size=UDim2.fromScale(0.6,0.035)
actionHint.Position=UDim2.fromScale(0.2,0.82)
actionHint.BackgroundTransparency=1
actionHint.Text=""
actionHint.TextColor3=Color3.fromRGB(240,245,255)
actionHint.TextScaled=true
actionHint.Font=Enum.Font.GothamBold
actionHint.Visible=false
actionHint.ZIndex=60
actionHint.Parent=gui

local currentAction = nil
function S.ShowAction(data)
    currentAction = data
    actionBtn.Text = data.label or "交互"
    actionHint.Text = data.hint or ""
    actionHint.Visible = (data.hint ~= nil and data.hint ~= "")
    actionBtn.Visible = true
end
function S.HideAction()
    currentAction = nil
    actionBtn.Visible = false
    actionHint.Visible = false
end

actionBtn.Activated:Connect(function()
    if currentAction and currentAction.action then
        currentAction.action()
    end
end)

-- ================== 17. 头顶标识 ==================
local tagGui = Instance.new("BillboardGui")
tagGui.Name="IncSim_TaskTag"
tagGui.Size=UDim2.fromOffset(220,60)
tagGui.StudsOffset=Vector3.new(0,3.5,0)
tagGui.AlwaysOnTop=true
tagGui.Enabled=false
tagGui.Parent=gui

local tagLbl = Instance.new("TextLabel")
tagLbl.Size=UDim2.fromScale(1,1)
tagLbl.BackgroundColor3=Color3.fromRGB(30,34,44)
tagLbl.BackgroundTransparency=0.2
tagLbl.Text=""
tagLbl.TextColor3=Color3.fromRGB(255,240,180)
tagLbl.TextScaled=true
tagLbl.Font=Enum.Font.GothamBold
tagLbl.Parent=tagGui
local tagCorner=Instance.new("UICorner"); tagCorner.CornerRadius=UDim.new(0,12); tagCorner.Parent=tagLbl
local tagStroke=Instance.new("UIStroke"); tagStroke.Color=Color3.fromRGB(255,255,255)
tagStroke.Transparency=0.5; tagStroke.Parent=tagLbl

local function attachTagToCharacter()
    local char = LocalPlayer.Character
    if not char then return end
    local head = char:FindFirstChild("Head")
    if head then tagGui.Adornee = head end
end
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1); attachTagToCharacter()
end)
task.spawn(function() task.wait(2); attachTagToCharacter() end)

function S.SetHeadTag(text)
    if text and text~="" then
        tagLbl.Text=text
        tagGui.Enabled=true
        attachTagToCharacter()
    else
        tagGui.Enabled=false
    end
end

-- ================== 18. 世界标记 ==================
local function makeWorldMarker(pos, color, label)
    local beam = Instance.new("Part")
    beam.Size=Vector3.new(4,40,4)
    beam.Position=pos + Vector3.new(0,20,0)
    beam.Color=color
    beam.Material=Enum.Material.Neon
    beam.Transparency=0.55
    beam.CanCollide=false
    beam.Anchored=true
    beam.Name="JobMarker"
    beam.Parent=markersFolder

    local ring = Instance.new("Part")
    ring.Shape=Enum.PartType.Cylinder
    ring.Size=Vector3.new(0.4,12,12)
    ring.CFrame=CFrame.new(pos.X, pos.Y+0.3, pos.Z)*CFrame.Angles(0,0,math.rad(90))
    ring.Color=color
    ring.Material=Enum.Material.Neon
    ring.Transparency=0.3
    ring.CanCollide=false
    ring.Anchored=true
    ring.Name="JobMarker"
    ring.Parent=markersFolder

    if label then
        local bb=Instance.new("BillboardGui")
        bb.Size=UDim2.fromOffset(200,50)
        bb.StudsOffset=Vector3.new(0,26,0)
        bb.AlwaysOnTop=true
        bb.Parent=beam
        local tl=Instance.new("TextLabel")
        tl.Size=UDim2.fromScale(1,1)
        tl.BackgroundTransparency=1
        tl.Text=label
        tl.TextColor3=color
        tl.TextScaled=true
        tl.Font=Enum.Font.GothamBold
        tl.TextStrokeTransparency=0
        tl.Parent=bb
    end
    return { beam=beam, ring=ring }
end

local function clearWorldMarkers()
    for _, obj in ipairs(markersFolder:GetDescendants()) do
        if obj.Name == "JobMarker" then obj:Destroy() end
    end
end

-- ================== 19. 距离检测 ==================
function S.RegisterPoint(key, pos, label, hint, onInteract)
    S.NearbyPoints[key] = { pos=pos, label=label, hint=hint, onInteract=onInteract }
end
function S.UnregisterPoint(key) S.NearbyPoints[key] = nil end

local function getPlayerPos()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.Position or nil
end

task.spawn(function()
    while true do
        task.wait(0.25)
        local ppos = getPlayerPos()
        if ppos and not currentAction then
            local nearestKey, nearestDist, nearestData
            for key, data in pairs(S.NearbyPoints) do
                local d = (ppos - data.pos).Magnitude
                if d < S.InteractRange and (not nearestDist or d < nearestDist) then
                    nearestKey, nearestDist, nearestData = key, d, data
                end
            end
            if nearestData then
                S.ShowAction({
                    label=nearestData.label, hint=nearestData.hint, key=nearestKey,
                    action=function() nearestData.onInteract() end,
                })
            end
        elseif currentAction then
            local ppos2 = getPlayerPos()
            if ppos2 then
                local stillNear=false
                for _, data in pairs(S.NearbyPoints) do
                    if (ppos2 - data.pos).Magnitude < S.InteractRange then stillNear=true; break end
                end
                if not stillNear then S.HideAction() end
            else S.HideAction() end
        end
    end
end)

-- ================== 20. 冷却 ==================
local function isOnCooldown(jobId)
    local until_ = S.Cooldowns[jobId]
    return until_ and os.time() < until_ or false
end
local function setCooldown(jobId, seconds)
    S.Cooldowns[jobId] = os.time() + seconds
end

-- ================== 21. 工作定义 ==================
local CELLS = S.MapCells
local function pickCell(offset)
    offset = offset or 0
    if #CELLS == 0 then return Vector3.new(0,3,0) end
    local idx = math.random(1, #CELLS)
    return CELLS[idx] + Vector3.new(offset, 0, 0)
end

local function makeJob(def)
    return function()
        local pickup  = pickCell(def.off1 or 0)
        local deliver = pickCell(def.off2 or 20)
        local reward  = math.random(def.rMin or 60, def.rMax or 120)
        return {
            id=def.id, name=def.name,
            getPoint=function() return pickup end,
            deliverPoint=function() return deliver end,
            getLabel=def.getLabel, deliverLabel=def.deliverLabel,
            reward=function() return reward end,
            cooldown=def.cooldown or 15,
        }
    end
end

table.insert(S.JobBuilders, makeJob{ id="delivery", name="送外卖", getLabel="🍔 取餐口", deliverLabel="🏠 客户地址", off1=0, off2=30, rMin=60, rMax=120, cooldown=15 })
table.insert(S.JobBuilders, makeJob{ id="parcel", name="送快递", getLabel="📦 快递站", deliverLabel="🏢 收件地址", off1=-25, off2=35, rMin=80, rMax=160, cooldown=18 })
table.insert(S.JobBuilders, makeJob{ id="taxi", name="开出租", getLabel="🚕 乘客招手", deliverLabel="📍 乘客目的地", off1=20, off2=-40, rMin=100, rMax=200, cooldown=20 })
table.insert(S.JobBuilders, makeJob{ id="market", name="超市打工", getLabel="🛒 后仓", deliverLabel="📦 货架", off1=10, off2=-10, rMin=50, rMax=90, cooldown=12 })

-- ================== 22. 任务状态机 ==================
S.JobState = nil
S.JobData  = nil

local function startJob(jobBuilder)
    if S.JobState then
        S.Notify("已有任务进行中", Color3.fromRGB(255,180,120)); return
    end
    local job = jobBuilder()
    if isOnCooldown(job.id) then
        local left = math.ceil(S.Cooldowns[job.id]-os.time())
        S.Notify(job.name.." 冷却中（"..left.." 秒）", Color3.fromRGB(255,180,120)); return
    end

    S.JobData = job
    S.JobState = "pickup"
    S.CurrentJob = { id=job.id, name=job.name, phase="pickup" }

    clearWorldMarkers()
    local gp = job.getPoint()
    S.JobData.marker = makeWorldMarker(gp, Color3.fromRGB(120,220,160), job.getLabel)

    S.RegisterPoint("current_job_pickup", gp, "接单", job.getLabel, function()
        S.HideAction()
        S.UnregisterPoint("current_job_pickup")
        if S.JobData.marker then
            S.JobData.marker.beam:Destroy()
            S.JobData.marker.ring:Destroy()
        end
        S.JobState = "deliver"
        S.CurrentJob.phase = "deliver"
        S.SetHeadTag(job.name.." 配送中")
        S.SetTask(job.name.." → 前往 "..job.deliverLabel)
        S.Notify("已接单："..job.name, Color3.fromRGB(120,220,160))

        local dp = job.deliverPoint()
        S.JobData.marker = makeWorldMarker(dp, Color3.fromRGB(255,200,120), job.deliverLabel)
        S.RegisterPoint("current_job_deliver", dp, "交付", job.deliverLabel, function()
            S.HideAction()
            S.UnregisterPoint("current_job_deliver")
            if S.JobData.marker then
                S.JobData.marker.beam:Destroy()
                S.JobData.marker.ring:Destroy()
            end
            local r = math.floor(job.reward() * (S.Rates.moneyMultiplier or 1))
            S.AddMoney(r)
            S.SetHeadTag(""); S.SetTask("")
            S.Notify("完成 "..job.name.."，获得 $"..r, Color3.fromRGB(120,220,160))
            setCooldown(job.id, job.cooldown)
            S.JobState = nil; S.JobData = nil; S.CurrentJob = nil
        end)
    end)

    S.SetHeadTag("前往 "..job.getLabel)
    S.SetTask(job.name.." → 前往 "..job.getLabel)
    S.Notify("新任务："..job.name, Color3.fromRGB(180,220,255))
end

function S.CompleteCurrentJob()
    if not S.JobData or S.JobState~="deliver" then
        S.Notify("当前无进行中的任务", Color3.fromRGB(255,180,120)); return
    end
    local job = S.JobData
    S.HideAction()
    S.UnregisterPoint("current_job_deliver")
    if job.marker then job.marker.beam:Destroy(); job.marker.ring:Destroy() end
    local r = math.floor(job.reward() * (S.Rates.moneyMultiplier or 1))
    S.AddMoney(r)
    S.SetHeadTag(""); S.SetTask("")
    S.Notify("已强制完成，获得 $"..r, Color3.fromRGB(120,220,160))
    setCooldown(job.id, job.cooldown)
    S.JobState = nil; S.JobData = nil; S.CurrentJob = nil
end

-- ================== 23. 工作按钮列表 ==================
local jobsPanel = Instance.new("Frame")
jobsPanel.Name="JobsPanel"
jobsPanel.Size=UDim2.fromScale(0.32,0.6)
jobsPanel.Position=UDim2.new(0.02,0,0.14,0)
jobsPanel.ZIndex=3
jobsPanel.Parent=gui
applyGlass(jobsPanel,20,0.7)

local jobsTitle = Instance.new("TextLabel")
jobsTitle.Size=UDim2.fromScale(0.9,0.09)
jobsTitle.Position=UDim2.fromScale(0.05,0.02)
jobsTitle.BackgroundTransparency=1
jobsTitle.Text="工作列表"
jobsTitle.TextColor3=Color3.fromRGB(240,245,255)
jobsTitle.TextScaled=true
jobsTitle.Font=Enum.Font.GothamBold
jobsTitle.ZIndex=4
jobsTitle.Parent=jobsPanel

local jobsScroll = Instance.new("ScrollingFrame")
jobsScroll.Name="JobsScroll"
jobsScroll.Size=UDim2.fromScale(0.9,0.85)
jobsScroll.Position=UDim2.fromScale(0.05,0.12)
jobsScroll.BackgroundTransparency=1
jobsScroll.BorderSizePixel=0
jobsScroll.ScrollBarThickness=4
jobsScroll.ScrollBarImageColor3=Color3.fromRGB(180,190,220)
jobsScroll.CanvasSize=UDim2.new(0,0,0,0)
jobsScroll.AutomaticCanvasSize=Enum.AutomaticSize.Y
jobsScroll.ClipsDescendants=true
jobsScroll.ZIndex=4
jobsScroll.Parent=jobsPanel

local jobsLayout = Instance.new("UIListLayout")
jobsLayout.Padding=UDim.new(0,6)
jobsLayout.SortOrder=Enum.SortOrder.LayoutOrder
jobsLayout.Parent=jobsScroll

local function buildJobList()
    for _, c in ipairs(jobsScroll:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local order = 0
    for i, builder in ipairs(S.JobBuilders) do
        order = order + 1
        local sample = builder()
        local jobName = sample.name
        local jobId   = sample.id
        local b = mkButton(jobsScroll, jobName, UDim2.new(1,-8,0,56), UDim2.fromOffset(4,0), order)
        b.ZIndex = 6
        b.Activated:Connect(function()
            if S.JobState then S.Notify("请先完成当前任务", Color3.fromRGB(255,180,120)); return end
            if isOnCooldown(jobId) then
                local left = math.ceil(S.Cooldowns[jobId]-os.time())
                S.Notify(jobName.." 冷却中（"..left.."s）", Color3.fromRGB(255,180,120)); return
            end
            startJob(builder)
        end)
    end
end

S.RebuildJobList = buildJobList
buildJobList()

-- ================== 24. 小地图 ==================
local minimapSize = 180
local minimapBg = Instance.new("Frame")
minimapBg.Name="Minimap"
minimapBg.Size=UDim2.fromOffset(minimapSize,minimapSize)
minimapBg.Position=UDim2.new(1,-minimapSize-12,0,12)
minimapBg.BackgroundColor3=Color3.fromRGB(20,24,32)
minimapBg.BackgroundTransparency=0.3
minimapBg.BorderSizePixel=0
minimapBg.ZIndex=5
minimapBg.Parent=gui
applyGlass(minimapBg,18,0.7)

local minimapClip = Instance.new("Frame")
minimapClip.Size=UDim2.fromScale(1,1)
minimapClip.BackgroundTransparency=1
minimapClip.ClipsDescendants=true
minimapClip.ZIndex=5
minimapClip.Parent=minimapBg
local minimapCorner=Instance.new("UICorner")
minimapCorner.CornerRadius=UDim.new(0,18)
minimapCorner.Parent=minimapClip

local playerDot = Instance.new("Frame")
playerDot.Size=UDim2.fromOffset(8,8)
playerDot.BackgroundColor3=Color3.fromRGB(120,220,255)
playerDot.BorderSizePixel=0
playerDot.ZIndex=6
playerDot.Parent=minimapClip
local pdc=Instance.new("UICorner"); pdc.CornerRadius=UDim.new(1,0); pdc.Parent=playerDot

local targetDot = Instance.new("Frame")
targetDot.Size=UDim2.fromOffset(10,10)
targetDot.BackgroundColor3=Color3.fromRGB(255,180,80)
targetDot.BorderSizePixel=0
targetDot.Visible=false
targetDot.ZIndex=6
targetDot.Parent=minimapClip
local tdc=Instance.new("UICorner"); tdc.CornerRadius=UDim.new(1,0); tdc.Parent=targetDot

local MAP_RANGE = 500
task.spawn(function()
    while true do
        task.wait(0.2)
        local ppos = getPlayerPos()
        if ppos then
            playerDot.Position = UDim2.fromScale(0.5,0.5) - UDim2.fromOffset(4,4)
            local targetPos
            if S.JobState=="pickup" and S.JobData then targetPos = S.JobData.getPoint()
            elseif S.JobState=="deliver" and S.JobData then targetPos = S.JobData.deliverPoint() end
            if targetPos then
                local rel = targetPos - ppos
                local nx = math.clamp(0.5 + (rel.X/(MAP_RANGE*2)), 0.03, 0.97)
                local nz = math.clamp(0.5 + (rel.Z/(MAP_RANGE*2)), 0.03, 0.97)
                targetDot.Position = UDim2.fromScale(nx,nz) - UDim2.fromOffset(5,5)
                targetDot.Visible = true
            else
                targetDot.Visible = false
            end
        end
    end
end)

S.RefreshMoney()
S.Notify("第一部分加载完成（UI+城市+工作框架）", Color3.fromRGB(120,220,160))
print("[IncSim] 第一部分加载完成")
--[[
=====================================================================
  增量模拟器 | 合并版 · 第二部分（接第一部分末尾）
  包含：被动收入 + 投资系统 + 剩余 21 种工作 + 自检 + 收尾
=====================================================================
]]

-- 复用第一部分的 S / gui 等（都在同一个 chunk 里，直接访问）

-- ================== 25. 剩余 21 种工作 ==================
-- 用第一部分的 pickCell / makeJob 模板继续注册

table.insert(S.JobBuilders, makeJob{ id="waiter",   name="餐厅服务员", getLabel="🍳 后厨取菜",   deliverLabel="🍽️ 指定餐桌", off1=0,   off2=15, rMin=70,  rMax=130, cooldown=14 })
table.insert(S.JobBuilders, makeJob{ id="cashier",  name="便利店收银", getLabel="🧾 收银台",     deliverLabel="📦 补货位",   off1=0,   off2=8,  rMin=55,  rMax=95,  cooldown=10 })
table.insert(S.JobBuilders, makeJob{ id="cleaner",  name="清洁工",     getLabel="🧹 工具间",     deliverLabel="🗑️ 清洁点",   off1=-15, off2=25, rMin=45,  rMax=80,  cooldown=12 })
table.insert(S.JobBuilders, makeJob{ id="brick",    name="搬砖",       getLabel="🧱 材料堆",     deliverLabel="🏗️ 工地",     off1=-20, off2=30, rMin=90,  rMax=150, cooldown=16 })
table.insert(S.JobBuilders, makeJob{ id="carwash",  name="洗车",       getLabel="🚿 工具区",     deliverLabel="🚗 待洗车辆", off1=0,   off2=10, rMin=60,  rMax=110, cooldown=13 })
table.insert(S.JobBuilders, makeJob{ id="pizza",    name="披萨配送",   getLabel="🍕 披萨店",     deliverLabel="🏠 客户地址", off1=5,   off2=35, rMin=85,  rMax=160, cooldown=17 })
table.insert(S.JobBuilders, makeJob{ id="dock",     name="码头搬运",   getLabel="🚢 码头货堆",   deliverLabel="📦 货船",     off1=-30, off2=40, rMin=110, rMax=180, cooldown=18 })
table.insert(S.JobBuilders, makeJob{ id="mail",     name="邮差",       getLabel="📮 邮局取信",   deliverLabel="📬 送信信箱", off1=0,   off2=20, rMin=70,  rMax=120, cooldown=14 })
table.insert(S.JobBuilders, makeJob{ id="dogwalk",  name="遛狗",       getLabel="🐕 宠物店领狗", deliverLabel="🌳 公园遛完", off1=10,  off2=45, rMin=60,  rMax=100, cooldown=15 })
table.insert(S.JobBuilders, makeJob{ id="nurse",    name="医院护士",   getLabel="🏥 急诊室",     deliverLabel="🛏️ 病房",     off1=0,   off2=15, rMin=90,  rMax=160, cooldown=16 })
table.insert(S.JobBuilders, makeJob{ id="security", name="保安巡逻",   getLabel="🛡️ 保安室",     deliverLabel="📍 巡逻打卡点", off1=-10, off2=25, rMin=70, rMax=130, cooldown=14 })
table.insert(S.JobBuilders, makeJob{ id="builder",  name="建筑工人",   getLabel="🏗️ 材料堆",     deliverLabel="🏗️ 施工点",   off1=-20, off2=30, rMin=110, rMax=180, cooldown=18 })
table.insert(S.JobBuilders, makeJob{ id="sorter",   name="快递分拣",   getLabel="📦 传送带",     deliverLabel="🚚 对应货车", off1=0,   off2=8,  rMin=60,  rMax=100, cooldown=10 })
table.insert(S.JobBuilders, makeJob{ id="gas",      name="加油站员工", getLabel="⛽ 加油站仓库", deliverLabel="🚗 指定加油位", off1=-8, off2=20, rMin=75, rMax=130, cooldown=14 })
table.insert(S.JobBuilders, makeJob{ id="lifeguard",name="救生员",     getLabel="🏖️ 救生站",     deliverLabel="🌊 巡逻点",   off1=5,   off2=40, rMin=80,  rMax=140, cooldown=16 })
table.insert(S.JobBuilders, makeJob{ id="petgroom", name="宠物美容",   getLabel="🐩 宠物店",     deliverLabel="✂️ 美容台",   off1=0,   off2=8,  rMin=85,  rMax=150, cooldown=15 })
table.insert(S.JobBuilders, makeJob{ id="florist",  name="花店配送",   getLabel="💐 花店",       deliverLabel="🏠 客户地址", off1=5,   off2=30, rMin=90,  rMax=160, cooldown=15 })
table.insert(S.JobBuilders, makeJob{ id="library",  name="图书管理",   getLabel="📚 还书箱",     deliverLabel="📖 书架",     off1=0,   off2=10, rMin=50,  rMax=90,  cooldown=10 })
table.insert(S.JobBuilders, makeJob{ id="airport",  name="机场地勤",   getLabel="🧳 行李区",     deliverLabel="🛫 登机口",   off1=-15, off2=25, rMin=120, rMax=200, cooldown=20 })
table.insert(S.JobBuilders, makeJob{ id="drone",    name="无人机操作", getLabel="🛸 无人机站",   deliverLabel="📦 空投点",   off1=0,   off2=50, rMin=100, rMax=180, cooldown=18 })
table.insert(S.JobBuilders, makeJob{ id="designated",name="代驾",      getLabel="🍺 酒吧门口",   deliverLabel="🏠 客户家",   off1=-30, off2=45, rMin=130, rMax=220, cooldown=20 })

S.RebuildJobList()
S.Notify(string.format("工作总数：%d 种", #S.JobBuilders), Color3.fromRGB(180,220,255))

-- ================== 26. 被动收入建筑 ==================
local CITY_CENTER = Vector3.new(TOTAL/2, 0, TOTAL/2)

local passiveFolder = Instance.new("Folder")
passiveFolder.Name = "PassiveBuildings"
passiveFolder.Parent = cityFolder

local function buildSpecial(parent, pos, size, color, signText, signColor)
    local body = newPart(parent, size, pos + Vector3.new(0, size.Y/2, 0), color, Enum.Material.SmoothPlastic)

    local glass = newPart(parent, Vector3.new(size.X*1.02, size.Y*0.7, 0.3),
        pos + Vector3.new(0, size.Y/2, -size.Z/2-0.3),
        Color3.fromRGB(140,180,220), Enum.Material.Glass)
    glass.Transparency = 0.5
    glass.CanCollide = false

    local sign = newPart(parent, Vector3.new(size.X*0.9, 3, 0.4),
        pos + Vector3.new(0, size.Y+2.5, -size.Z/2-0.4),
        signColor, Enum.Material.Neon)
    sign.CanCollide = false

    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(500, 100)
    sg.Parent = sign
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1,1)
    tl.BackgroundTransparency = 1
    tl.Text = signText
    tl.TextColor3 = Color3.fromRGB(255,255,255)
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.TextStrokeTransparency = 0.3
    tl.Parent = sg

    local marker = Instance.new("Part")
    marker.Shape = Enum.PartType.Cylinder
    marker.Size = Vector3.new(0.4, 10, 10)
    marker.CFrame = CFrame.new(pos.X, pos.Y+0.3, pos.Z+size.Z/2+6) * CFrame.Angles(0,0,math.rad(90))
    marker.Color = signColor
    marker.Material = Enum.Material.Neon
    marker.Transparency = 0.4
    marker.Anchored = true
    marker.CanCollide = false
    marker.Parent = parent

    return { body = body, interactPos = pos + Vector3.new(0, 3, size.Z/2 + 6) }
end

local bStock   = buildSpecial(passiveFolder, CITY_CENTER + Vector3.new( 90,0,-60),
    Vector3.new(36,50,36), Color3.fromRGB(120,140,180),
    "STOCK EXCHANGE 股票交易所", Color3.fromRGB(90,200,255))
local bHouse   = buildSpecial(passiveFolder, CITY_CENTER + Vector3.new(-90,0,-60),
    Vector3.new(30,26,30), Color3.fromRGB(160,140,120),
    "REAL ESTATE 房产中介", Color3.fromRGB(255,200,120))
local bCompany = buildSpecial(passiveFolder, CITY_CENTER + Vector3.new(  0,0, 90),
    Vector3.new(40,60,40), Color3.fromRGB(140,120,160),
    "CORP TOWER 公司大楼", Color3.fromRGB(200,140,255))

local function tryBuy(key, name, cost)
    if S.Passive[key] then
        S.Notify(name .. " 已在运营中", Color3.fromRGB(255,180,120)); return
    end
    if S.Money < cost then
        S.Notify("金钱不足，需要 $" .. cost, Color3.fromRGB(255,120,120)); return
    end
    S.AddMoney(-cost)
    S.Passive[key] = true
    S.Notify("购买成功：" .. name .. "（每秒 +$" .. S.PassiveRates[key] .. "）",
        Color3.fromRGB(120,220,160))
end

S.RegisterPoint("passive_stock", bStock.interactPos, "购买股票业务",
    "股票交易所 $5,000", function() tryBuy("stock", "股票交易所", 5000) end)
S.RegisterPoint("passive_house", bHouse.interactPos, "购买房产",
    "房产中介 $12,000", function() tryBuy("house", "房产中介", 12000) end)
S.RegisterPoint("passive_company", bCompany.interactPos, "购买公司",
    "公司大楼 $30,000", function() tryBuy("company", "公司大楼", 30000) end)

task.spawn(function()
    while true do
        task.wait(1)
        local total = 0
        for k, v in pairs(S.Passive) do
            if v then total = total + (S.PassiveRates[k] or 0) end
        end
        if total > 0 then
            total = total * (S.Rates.moneyMultiplier or 1)
            S.Money = S.Money + total
            S.RefreshMoney()
        end
    end
end)

-- 被动收入小条
local passiveHud = Instance.new("Frame")
passiveHud.Name = "PassiveHUD"
passiveHud.Size = UDim2.fromScale(0.28, 0.05)
passiveHud.Position = UDim2.new(0.7, 0, 0.94, 0)
passiveHud.ZIndex = 5
passiveHud.Parent = gui
applyGlass(passiveHud, 14, 0.7)

local passiveLbl = Instance.new("TextLabel")
passiveLbl.Size = UDim2.fromScale(0.94, 1)
passiveLbl.Position = UDim2.fromScale(0.03, 0)
passiveLbl.BackgroundTransparency = 1
passiveLbl.Text = "被动收入：无"
passiveLbl.TextColor3 = Color3.fromRGB(220,230,255)
passiveLbl.TextScaled = true
passiveLbl.Font = Enum.Font.GothamMedium
passiveLbl.ZIndex = 6
passiveLbl.Parent = passiveHud

task.spawn(function()
    while true do
        task.wait(1)
        local active = {}
        for k,v in pairs(S.Passive) do if v then table.insert(active, k) end end
        if #active == 0 then
            passiveLbl.Text = "被动收入：无"
        else
            local total = 0
            for _,k in ipairs(active) do total = total + (S.PassiveRates[k] or 0) end
            total = total * (S.Rates.moneyMultiplier or 1)
            passiveLbl.Text = string.format("被动收入：+$%d/s (%d 项)", math.floor(total), #active)
        end
    end
end)

-- ================== 27. 投资 / 下注系统 ==================
local investFolder = Instance.new("Folder")
investFolder.Name = "InvestBuildings"
investFolder.Parent = cityFolder

local bStockInv = buildSpecial(investFolder, CITY_CENTER + Vector3.new(-120,0,60),
    Vector3.new(30,40,30), Color3.fromRGB(100,110,160),
    "INVEST 投资所", Color3.fromRGB(100,200,255))
local bCasino   = buildSpecial(investFolder, CITY_CENTER + Vector3.new( 120,0,60),
    Vector3.new(34,28,34), Color3.fromRGB(180,60,90),
    "CASINO 赌场", Color3.fromRGB(255,120,160))
local bLottery  = buildSpecial(investFolder, CITY_CENTER + Vector3.new(   0,0,-120),
    Vector3.new(20,20,20), Color3.fromRGB(200,180,80),
    "LOTTERY 彩票站", Color3.fromRGB(255,230,120))
local bMine     = buildSpecial(investFolder, CITY_CENTER + Vector3.new(-150,0,-150),
    Vector3.new(26,18,26), Color3.fromRGB(120,90,60),
    "MINE 矿场", Color3.fromRGB(200,160,100))
local bFishing  = buildSpecial(investFolder, CITY_CENTER + Vector3.new( 150,0,-150),
    Vector3.new(24,16,24), Color3.fromRGB(80,140,180),
    "FISHING 渔场", Color3.fromRGB(120,200,255))

local investPanel = Instance.new("Frame")
investPanel.Name = "InvestPanel"
investPanel.Size = UDim2.fromScale(0.7,0.42)
investPanel.Position = UDim2.fromScale(0.15,0.29)
investPanel.Visible = false
investPanel.ZIndex = 70
investPanel.Parent = gui
applyGlass(investPanel, 24, 0.6, Color3.fromRGB(24,28,38))

local invTitle = Instance.new("TextLabel")
invTitle.Size = UDim2.fromScale(0.9,0.14)
invTitle.Position = UDim2.fromScale(0.05,0.05)
invTitle.BackgroundTransparency = 1
invTitle.Text = "投资"
invTitle.TextColor3 = Color3.fromRGB(240,245,255)
invTitle.TextScaled = true
invTitle.Font = Enum.Font.GothamBold
invTitle.ZIndex = 71
invTitle.Parent = investPanel

local invInfo = Instance.new("TextLabel")
invInfo.Size = UDim2.fromScale(0.9,0.12)
invInfo.Position = UDim2.fromScale(0.05,0.20)
invInfo.BackgroundTransparency = 1
invInfo.Text = ""
invInfo.TextColor3 = Color3.fromRGB(200,210,235)
invInfo.TextScaled = true
invInfo.Font = Enum.Font.GothamMedium
invInfo.ZIndex = 71
invInfo.Parent = investPanel

local invInput = Instance.new("TextBox")
invInput.Size = UDim2.fromScale(0.7,0.14)
invInput.Position = UDim2.fromScale(0.05,0.36)
invInput.BackgroundColor3 = Color3.fromRGB(40,46,58)
invInput.BackgroundTransparency = 0.2
invInput.Text = ""
invInput.PlaceholderText = "输入金额"
invInput.TextColor3 = Color3.fromRGB(240,245,255)
invInput.PlaceholderColor3 = Color3.fromRGB(150,160,185)
invInput.TextScaled = true
invInput.Font = Enum.Font.GothamMedium
invInput.ClearTextOnFocus = false
invInput.TextEditable = true
invInput.ZIndex = 72
invInput.Parent = investPanel
local invc = Instance.new("UICorner"); invc.CornerRadius = UDim.new(0,14); invc.Parent = invInput

local invConfirm = mkButton(investPanel, "确认", UDim2.fromScale(0.2,0.14),
    UDim2.fromScale(0.77,0.36), 0, Color3.fromRGB(60,140,90))
invConfirm.ZIndex = 72

local invClose = mkButton(investPanel, "✕", UDim2.fromScale(0.1,0.1),
    UDim2.fromScale(0.85,0.05), 0, Color3.fromRGB(120,50,50))
invClose.ZIndex = 72
invClose.Activated:Connect(function() investPanel.Visible = false end)

local function openInvest(kind, title, info)
    investPanel.Visible = true
    invTitle.Text = title
    invInfo.Text = info
    invInput.Text = ""
    investPanel:SetAttribute("kind", kind)
end

invConfirm.Activated:Connect(function()
    local kind = investPanel:GetAttribute("kind")
    if not kind then return end
    local n = tonumber(invInput.Text)
    if not n or n <= 0 then
        S.Notify("请输入有效金额", Color3.fromRGB(255,120,120)); return
    end
    n = math.floor(n)
    if S.Money < n then
        S.Notify("金钱不足", Color3.fromRGB(255,120,120)); return
    end

    S.AddMoney(-n)
    local rate = S.Rates[kind] or 0.5
    local mult = S.Rates.moneyMultiplier or 1
    local won = math.random() < rate

    local payoutMult
    if kind=="invest" then payoutMult=1.8
    elseif kind=="stock" then payoutMult=2.0
    elseif kind=="gamble" then payoutMult=2.2
    elseif kind=="lottery" then payoutMult=20
    elseif kind=="mining" then payoutMult=3.5
    elseif kind=="fishing" then payoutMult=2.8
    else payoutMult=1.5 end

    if won then
        local win = math.floor(n * payoutMult * mult)
        S.AddMoney(win)
        S.Notify(string.format("中奖！押 $%d → 赢 $%d", n, win), Color3.fromRGB(120,220,160))
    else
        S.Notify(string.format("未中奖，损失 $%d", n), Color3.fromRGB(255,120,120))
    end
    investPanel.Visible = false
end)

S.RegisterPoint("invest_stock", bStockInv.interactPos, "投资股票",
    string.format("成功率 %d%%", math.floor(S.Rates.stock*100)),
    function() openInvest("stock","投资股票",
        string.format("成功率 %d%%，赢 2.0 倍", math.floor(S.Rates.stock*100))) end)
S.RegisterPoint("invest_gamble", bCasino.interactPos, "赌博",
    string.format("胜率 %d%%", math.floor(S.Rates.gamble*100)),
    function() openInvest("gamble","赌博",
        string.format("胜率 %d%%，赢 2.2 倍", math.floor(S.Rates.gamble*100))) end)
S.RegisterPoint("invest_lottery", bLottery.interactPos, "买彩票",
    string.format("中奖率 %d%%", math.floor(S.Rates.lottery*100)),
    function() openInvest("lottery","彩票",
        string.format("中奖率 %d%%，赢 20 倍", math.floor(S.Rates.lottery*100))) end)
S.RegisterPoint("invest_mine", bMine.interactPos, "挖矿",
    string.format("稀有率 %d%%", math.floor(S.Rates.mining*100)),
    function() openInvest("mining","挖矿",
        string.format("稀有率 %d%%，赢 3.5 倍", math.floor(S.Rates.mining*100))) end)
S.RegisterPoint("invest_fish", bFishing.interactPos, "钓鱼",
    string.format("稀有率 %d%%", math.floor(S.Rates.fishing*100)),
    function() openInvest("fishing","钓鱼",
        string.format("稀有率 %d%%，赢 2.8 倍", math.floor(S.Rates.fishing*100))) end)

-- ================== 28. 自检 + 一键测试 ==================
local function selfCheck()
    print("========== IncSim 自检 ==========")
    print("金钱：", S.FmtMoney(S.Money))
    print("工作数：", #S.JobBuilders)
    print("被动：", S.Passive.stock, S.Passive.house, S.Passive.company)
    print("概率：投资",S.Rates.invest,"股市",S.Rates.stock,
        "赌博",S.Rates.gamble,"彩票",S.Rates.lottery,
        "挖矿",S.Rates.mining,"钓鱼",S.Rates.fishing)
    print("倍率：", S.Rates.moneyMultiplier .. "x")
    print("注册交互点：")
    for k,v in pairs(S.NearbyPoints) do print("  -", k, v.pos) end
    print("=================================")
end
S.SelfCheck = selfCheck

local scBtn = mkButton(content, "运行自检（输出到控制台）",
    UDim2.new(1,-8,0,52), UDim2.fromOffset(4,0), 999, Color3.fromRGB(60,80,120))
scBtn.ZIndex = 42
table.insert(adminBtnList, scBtn)
scBtn.Activated:Connect(function()
    selfCheck()
    S.Notify("自检完成，请看控制台", Color3.fromRGB(120,220,160))
end)

local testBtn = mkButton(content, "▶ 一键测试流程",
    UDim2.new(1,-8,0,56), UDim2.fromOffset(4,0), 1000, Color3.fromRGB(120,90,180))
testBtn.ZIndex = 42
table.insert(adminBtnList, testBtn)
testBtn.Activated:Connect(function()
    S.SetMoney(100000)
    S.Notify("① 已设置金钱 $100,000", Color3.fromRGB(180,220,255))
    task.wait(0.8)
    S.Passive.stock = true
    S.Passive.house = true
    S.Passive.company = true
    S.Notify("② 被动收入全部开启", Color3.fromRGB(180,220,255))
    task.wait(0.8)
    S.Notify("③ 请手动点开管理员面板调概率", Color3.fromRGB(180,220,255))
    task.wait(0.8)
    S.Notify("④ 现在从左侧工作面板接任意任务", Color3.fromRGB(180,220,255))
    task.wait(0.8)
    S.Notify("⑤ 完成后到管理员面板导出存档", Color3.fromRGB(180,220,255))
    selfCheck()
end)

-- 验证通过后需要让新增按钮也显示
local origPwHandler
pwBtn.Activated:Connect(function()
    if S.AdminOK then
        for _, c in ipairs(adminBtnList) do c.Visible = true end
    end
end)

-- ================== 29. 版本水印 ==================
local versionLbl = Instance.new("TextLabel")
versionLbl.Size = UDim2.fromScale(0.3, 0.025)
versionLbl.Position = UDim2.new(0.02, 0, 0.985, 0)
versionLbl.BackgroundTransparency = 1
versionLbl.Text = "IncSim 合并版 · 25 工作"
versionLbl.TextColor3 = Color3.fromRGB(160,170,190)
versionLbl.TextScaled = true
versionLbl.Font = Enum.Font.Gotham
versionLbl.TextXAlignment = Enum.TextXAlignment.Left
versionLbl.ZIndex = 60
versionLbl.Parent = gui

-- ================== 30. 完成 ==================
S.Notify("全部加载完成，共 25 种工作", Color3.fromRGB(120,220,160))
print("[IncSim] 合并版全部加载完成")
--[[
=====================================================================
  Part 3A：时间放缓 / UI 缩小 / 动态玻璃 / 生存系统 / 小地图升级
  接在合并版末尾
=====================================================================
]]

-- ================== A1. 时间放慢 ==================
S.DayNightRunning = false
task.wait(0.1)

S.GameDayMinutes = S.GameDayMinutes or 0
S.DayStartClock  = S.DayStartClock  or 8
S.GameDayCount   = S.GameDayCount   or 1

local function applyLightingByTime(hour)
    if hour >= 6 and hour < 18 then
        Lighting.Brightness = 3
        Lighting.Ambient = Color3.fromRGB(140,145,155)
        Lighting.OutdoorAmbient = Color3.fromRGB(155,160,170)
        Lighting.ColorShift_Top = Color3.fromRGB(255,250,240)
        Lighting.FogEnd = 3000
        Lighting.FogColor = Color3.fromRGB(200,215,235)
    elseif hour >= 18 and hour < 20 then
        local t = (hour - 18) / 2
        Lighting.Brightness = 2 - t
        Lighting.Ambient = Color3.fromRGB(140,120,100):Lerp(Color3.fromRGB(80,70,90), t)
        Lighting.OutdoorAmbient = Color3.fromRGB(180,140,100):Lerp(Color3.fromRGB(80,80,110), t)
        Lighting.ColorShift_Top = Color3.fromRGB(255,180,120):Lerp(Color3.fromRGB(120,100,160), t)
        Lighting.FogEnd = 2500
        Lighting.FogColor = Color3.fromRGB(220,160,120):Lerp(Color3.fromRGB(60,60,90), t)
    elseif hour >= 20 or hour < 5 then
        Lighting.Brightness = 0.8
        Lighting.Ambient = Color3.fromRGB(40,45,65)
        Lighting.OutdoorAmbient = Color3.fromRGB(50,55,80)
        Lighting.ColorShift_Top = Color3.fromRGB(80,100,150)
        Lighting.FogEnd = 2000
        Lighting.FogColor = Color3.fromRGB(20,25,45)
    else
        local t = (hour - 5)
        Lighting.Brightness = 0.8 + t * 2
        Lighting.Ambient = Color3.fromRGB(40,45,65):Lerp(Color3.fromRGB(140,145,155), t)
        Lighting.OutdoorAmbient = Color3.fromRGB(50,55,80):Lerp(Color3.fromRGB(155,160,170), t)
        Lighting.ColorShift_Top = Color3.fromRGB(120,100,160):Lerp(Color3.fromRGB(255,220,180), t)
        Lighting.FogEnd = 2000 + t * 1000
        Lighting.FogColor = Color3.fromRGB(60,60,90):Lerp(Color3.fromRGB(220,200,180), t)
    end
end

local windowLights = {}
local function collectWindows()
    local c = Workspace:FindFirstChild("IncSim_City")
    if not c then return end
    local bf = c:FindFirstChild("Buildings")
    if not bf then return end
    for _, p in ipairs(bf:GetChildren()) do
        if p:IsA("Part") and p.Material == Enum.Material.Glass then
            table.insert(windowLights, p)
        end
    end
end

local function updateWindowLights(isNight)
    for i, w in ipairs(windowLights) do
        if not w.Parent then
            windowLights[i] = nil
        else
            if isNight then
                if not w:GetAttribute("Lit") then
                    local lit = math.random() < 0.6
                    w:SetAttribute("Lit", lit)
                    if lit then
                        w.Material = Enum.Material.Neon
                        w.Color = Color3.fromRGB(255,220,140)
                    end
                end
            else
                if w:GetAttribute("Lit") then
                    w.Material = Enum.Material.Glass
                    w.Color = Color3.fromRGB(140,180,220)
                    w:SetAttribute("Lit", false)
                end
            end
        end
    end
end

task.spawn(collectWindows)

local timeHud = Instance.new("TextLabel")
timeHud.Name = "TimeHUD"
timeHud.Size = UDim2.fromScale(0.14, 0.032)
timeHud.Position = UDim2.new(0.02, 0, 0.11, 0)
timeHud.BackgroundColor3 = Color3.fromRGB(30,34,44)
timeHud.BackgroundTransparency = 0.5
timeHud.Text = "第 1 天 08:00"
timeHud.TextColor3 = Color3.fromRGB(240,240,255)
timeHud.TextScaled = true
timeHud.Font = Enum.Font.GothamBold
timeHud.ZIndex = 5
timeHud.Parent = gui
applyGlass(timeHud, 12, 0.8)

task.spawn(function()
    while true do
        task.wait(1)
        S.GameDayMinutes = S.GameDayMinutes + 1
        if S.GameDayMinutes >= 24 * 60 then
            S.GameDayMinutes = 0
            S.GameDayCount = S.GameDayCount + 1
        end
        local gameHour = S.DayStartClock + (S.GameDayMinutes / 60)
        gameHour = gameHour % 24
        Lighting.ClockTime = gameHour
        applyLightingByTime(gameHour)

        local hh = math.floor(gameHour)
        local mm = math.floor((gameHour - hh) * 60)
        timeHud.Text = string.format("第 %d 天 %02d:%02d", S.GameDayCount, hh, mm)

        if S.GameDayMinutes % 30 == 0 then
            local isNight = gameHour >= 19 or gameHour < 6
            updateWindowLights(isNight)
        end
    end
end)

-- ================== A2. UI 缩小 ==================
if hud then hud.Size = UDim2.fromScale(0.34, 0.042) end
if bubble then bubble.Size = UDim2.fromOffset(46, 46) end
if adminBall then adminBall.Size = UDim2.fromOffset(42, 42) end
if adminPanel then
    adminPanel.Size = UDim2.fromScale(0.8, 0.6)
    adminPanel.Position = UDim2.fromScale(0.1, 0.2)
end
if jobsPanel then
    jobsPanel.Size = UDim2.fromScale(0.26, 0.5)
    jobsPanel.Position = UDim2.new(0.02, 0, 0.16, 0)
end
if jobsScroll then
    for _, c in ipairs(jobsScroll:GetChildren()) do
        if c:IsA("TextButton") then
            c.Size = UDim2.new(1, -6, 0, 36)
        end
    end
    S.JobButtonHeight = 36
end
if taskHud then
    taskHud.Size = UDim2.fromScale(0.4, 0.045)
    taskHud.Position = UDim2.new(0.3, 0, 0.015, 0)
end
if actionBtn then
    actionBtn.Size = UDim2.fromScale(0.42, 0.07)
    actionBtn.Position = UDim2.fromScale(0.29, 0.88)
end
if actionHint then
    actionHint.Size = UDim2.fromScale(0.42, 0.03)
    actionHint.Position = UDim2.fromScale(0.29, 0.85)
end

S.Notify("UI 尺寸已缩小", Color3.fromRGB(180,220,255))

-- ================== A3. 动态玻璃 ==================
local function addRipple(btn)
    btn.Activated:Connect(function()
        local r = Instance.new("Frame")
        r.AnchorPoint = Vector2.new(0.5, 0.5)
        r.Position = UDim2.fromScale(0.5, 0.5)
        r.Size = UDim2.fromScale(0, 0)
        r.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        r.BackgroundTransparency = 0.5
        r.BorderSizePixel = 0
        r.ZIndex = btn.ZIndex + 1
        r.Parent = btn
        local rc = Instance.new("UICorner")
        rc.CornerRadius = UDim.new(1, 0)
        rc.Parent = r
        local size = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y)
        local tween = TweenService:Create(r, TweenInfo.new(0.5, Enum.EasingStyle.Quad), {
            Size = UDim2.fromOffset(size * 2.2, size * 2.2),
            BackgroundTransparency = 1,
        })
        tween:Play()
        tween.Completed:Connect(function() r:Destroy() end)
    end)
end

task.spawn(function()
    task.wait(0.5)
    for _, d in ipairs(gui:GetDescendants()) do
        if d:IsA("TextButton") and not d:GetAttribute("HasRipple") then
            d:SetAttribute("HasRipple", true)
            addRipple(d)
        end
    end
end)

local function addFlowStroke(frame)
    if frame:GetAttribute("HasFlow") then return end
    frame:SetAttribute("HasFlow", true)
    local stroke = frame:FindFirstChildOfClass("UIStroke")
    if not stroke then return end
    task.spawn(function()
        while frame.Parent do
            local t1 = TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
                Transparency = 0.4,
            })
            t1:Play()
            t1.Completed:Wait()
            if not frame.Parent then break end
            local t2 = TweenService:Create(stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine), {
                Transparency = 0.85,
            })
            t2:Play()
            t2.Completed:Wait()
        end
    end)
end

task.spawn(function()
    task.wait(1)
    for _, name in ipairs({"MoneyHUD", "AdminPanel", "JobsPanel", "TaskHUD", "TimeHUD"}) do
        local f = gui:FindFirstChild(name)
        if f then addFlowStroke(f) end
    end
end)

local function animateOpen(frame, fromScale)
    fromScale = fromScale or 0.85
    frame.Visible = true
    local origX, origY = frame.Size.X, frame.Size.Y
    frame.Size = UDim2.new(origX.Scale * fromScale, origX.Offset,
                           origY.Scale * fromScale, origY.Offset)
    TweenService:Create(frame, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        Size = UDim2.new(origX.Scale, origX.Offset, origY.Scale, origY.Offset),
    }):Play()
end
S.AnimateOpen = animateOpen

adminBall.Activated:Connect(function()
    if not adminPanel.Visible then
        animateOpen(adminPanel, 0.88)
        TweenService:Create(blur, TweenInfo.new(0.3), {Size = 16}):Play()
    else
        adminPanel.Visible = false
        TweenService:Create(blur, TweenInfo.new(0.3), {Size = 0}):Play()
    end
end)

-- ================== A4. 生存系统 ==================
S.Survival = S.Survival or {
    health = 100,
    hunger = 100,
    thirst = 100,
    lastHungerTick = os.time(),
    lastThirstTick = os.time(),
    isDead = false,
}
local surv = S.Survival

local survFrame = Instance.new("Frame")
survFrame.Name = "SurvivalHUD"
survFrame.Size = UDim2.fromScale(0.26, 0.055)
survFrame.Position = UDim2.new(0.02, 0, 0.92, 0)
survFrame.BackgroundTransparency = 1
survFrame.ZIndex = 5
survFrame.Parent = gui

local survLayout = Instance.new("UIListLayout")
survLayout.FillDirection = Enum.FillDirection.Horizontal
survLayout.Padding = UDim.new(0, 6)
survLayout.SortOrder = Enum.SortOrder.LayoutOrder
survLayout.Parent = survFrame

local function makeStatBar(order, icon, color)
    local bar = Instance.new("Frame")
    bar.Size = UDim2.fromScale(0.32, 1)
    bar.BackgroundColor3 = Color3.fromRGB(30,34,44)
    bar.BackgroundTransparency = 0.45
    bar.BorderSizePixel = 0
    bar.LayoutOrder = order
    bar.ZIndex = 6
    bar.Parent = survFrame
    applyGlass(bar, 10, 0.75)

    local fill = Instance.new("Frame")
    fill.Size = UDim2.fromScale(1, 1)
    fill.BackgroundColor3 = color
    fill.BorderSizePixel = 0
    fill.ZIndex = 7
    fill.Parent = bar
    local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(0,10); fc.Parent = fill

    local lbl = Instance.new("TextLabel")
    lbl.Size = UDim2.fromScale(1,1)
    lbl.BackgroundTransparency = 1
    lbl.Text = icon .. " 100"
    lbl.TextColor3 = Color3.fromRGB(255,255,255)
    lbl.TextScaled = true
    lbl.Font = Enum.Font.GothamBold
    lbl.TextStrokeTransparency = 0.4
    lbl.ZIndex = 8
    lbl.Parent = bar

    return { bar = bar, fill = fill, lbl = lbl, icon = icon }
end

local healthBar = makeStatBar(1, "❤️", Color3.fromRGB(220,80,80))
local hungerBar = makeStatBar(2, "🍖", Color3.fromRGB(230,140,60))
local thirstBar = makeStatBar(3, "💧", Color3.fromRGB(80,150,230))

local function refreshStat(b, val)
    val = math.clamp(val, 0, 100)
    b.fill.Size = UDim2.fromScale(val / 100, 1)
    b.lbl.Text = string.format("%s %d", b.icon, math.floor(val))
    if val < 30 then
        if not b.lbl:GetAttribute("Flashing") then
            b.lbl:SetAttribute("Flashing", true)
            task.spawn(function()
                while b.lbl:GetAttribute("Flashing") do
                    b.lbl.TextTransparency = 0.6
                    task.wait(0.35)
                    b.lbl.TextTransparency = 0
                    task.wait(0.35)
                    local v = (b.bar == healthBar.bar and surv.health)
                           or (b.bar == hungerBar.bar and surv.hunger)
                           or surv.thirst
                    if v >= 30 then b.lbl:SetAttribute("Flashing", false) end
                end
                b.lbl.TextTransparency = 0
            end)
        end
    else
        b.lbl:SetAttribute("Flashing", false)
        b.lbl.TextTransparency = 0
    end
end

local function bindHumanoid()
    local char = LocalPlayer.Character
    if not char then return end
    local hum = char:WaitForChild("Humanoid", 5)
    if not hum then return end
    hum.MaxHealth = 100

    hum.HealthChanged:Connect(function(h)
        surv.health = h
        refreshStat(healthBar, h)
        if h <= 0 and not surv.isDead then
            surv.isDead = true
            local lost = math.floor(S.Money * 0.1)
            S.SetMoney(S.Money - lost)
            S.Notify("死亡，损失 $"..lost, Color3.fromRGB(255,100,100))
            task.wait(3)
            surv.health = 100
            surv.hunger = math.max(surv.hunger, 40)
            surv.thirst = math.max(surv.thirst, 40)
            surv.isDead = false
            refreshStat(healthBar, 100)
            refreshStat(hungerBar, surv.hunger)
            refreshStat(thirstBar, surv.thirst)
        end
    end)
end

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    bindHumanoid()
end)
task.spawn(function() task.wait(2); bindHumanoid() end)

task.spawn(function()
    while true do
        task.wait(1)
        local now = os.time()

        if now - surv.lastHungerTick >= 180 then
            surv.lastHungerTick = now
            surv.hunger = math.max(0, surv.hunger - 1)
            refreshStat(hungerBar, surv.hunger)
        end

        if now - surv.lastThirstTick >= 120 then
            surv.lastThirstTick = now
            surv.thirst = math.max(0, surv.thirst - 1)
            refreshStat(thirstBar, surv.thirst)
        end

        if (surv.hunger <= 0 or surv.thirst <= 0) and now % 5 == 0 then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum then hum:TakeDamage(1) end
        end

        if surv.hunger > 50 and surv.thirst > 50 and now % 10 == 0 then
            local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
            if hum and hum.Health < 100 then
                hum.Health = math.min(100, hum.Health + 1)
            end
        end

        local char = LocalPlayer.Character
        if char then
            local hum = char:FindFirstChildOfClass("Humanoid")
            if hum then
                hum.WalkSpeed = surv.hunger < 30 and 10 or 16
            end
        end

        if surv.thirst < 30 then
            blur.Size = math.max(blur.Size, 6)
        elseif not adminPanel.Visible then
            TweenService:Create(blur, TweenInfo.new(0.5), {Size = 0}):Play()
        end

        if surv.health < 30 then
            local pulse = Instance.new("Frame")
            pulse.Size = UDim2.fromScale(1,1)
            pulse.BackgroundColor3 = Color3.fromRGB(255, 0, 0)
            pulse.BackgroundTransparency = 0.85
            pulse.BorderSizePixel = 0
            pulse.ZIndex = 90
            pulse.Parent = gui
            TweenService:Create(pulse, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            task.delay(0.55, function() pulse:Destroy() end)
        end
    end
end)

refreshStat(healthBar, surv.health)
refreshStat(hungerBar, surv.hunger)
refreshStat(thirstBar, surv.thirst)

function S.FeedHunger(amount)
    surv.hunger = math.clamp(surv.hunger + (amount or 10), 0, 100)
    refreshStat(hungerBar, surv.hunger)
    S.Notify("🍖 +"..(amount or 10).." 饥饿", Color3.fromRGB(230,180,120))
end
function S.DrinkThirst(amount)
    surv.thirst = math.clamp(surv.thirst + (amount or 10), 0, 100)
    refreshStat(thirstBar, surv.thirst)
    S.Notify("💧 +"..(amount or 10).." 口渴", Color3.fromRGB(120,180,255))
end
function S.HealPlayer(amount)
    local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = math.min(100, hum.Health + (amount or 20)) end
end

S.Notify("生存系统已加载", Color3.fromRGB(200,140,140))

-- ================== A5. 小地图升级 ==================
for _, name in ipairs({"Minimap", "MinimapFull", "NavArrow"}) do
    local old = gui:FindFirstChild(name)
    if old then old:Destroy() end
end

local MM_SIZE = 0.2

local mmFrame = Instance.new("Frame")
mmFrame.Name = "Minimap"
mmFrame.Size = UDim2.fromScale(MM_SIZE, MM_SIZE)
mmFrame.Position = UDim2.new(1 - MM_SIZE - 0.01, 0, 0.01, 0)
mmFrame.BackgroundColor3 = Color3.fromRGB(20,24,32)
mmFrame.BackgroundTransparency = 0.35
mmFrame.BorderSizePixel = 0
mmFrame.ZIndex = 7
mmFrame.Parent = gui
applyGlass(mmFrame, 14, 0.7)

local mmClip = Instance.new("Frame")
mmClip.Size = UDim2.fromScale(1,1)
mmClip.BackgroundTransparency = 1
mmClip.ClipsDescendants = true
mmClip.ZIndex = 7
mmClip.Parent = mmFrame
local mcc = Instance.new("UICorner"); mcc.CornerRadius = UDim.new(0,14); mcc.Parent = mmClip

local roadH = Instance.new("Frame")
roadH.Size = UDim2.fromScale(1, 0.08)
roadH.Position = UDim2.fromScale(0, 0.46)
roadH.BackgroundColor3 = Color3.fromRGB(90,90,100)
roadH.BackgroundTransparency = 0.3
roadH.BorderSizePixel = 0
roadH.ZIndex = 8
roadH.Parent = mmClip

local roadV = Instance.new("Frame")
roadV.Size = UDim2.fromScale(0.08, 1)
roadV.Position = UDim2.fromScale(0.46, 0)
roadV.BackgroundColor3 = Color3.fromRGB(90,90,100)
roadV.BackgroundTransparency = 0.3
roadV.BorderSizePixel = 0
roadV.ZIndex = 8
roadV.Parent = mmClip

local playerArrow = Instance.new("TextLabel")
playerArrow.Size = UDim2.fromOffset(14,14)
playerArrow.AnchorPoint = Vector2.new(0.5,0.5)
playerArrow.Position = UDim2.fromScale(0.5, 0.5)
playerArrow.BackgroundTransparency = 1
playerArrow.Text = "▲"
playerArrow.TextColor3 = Color3.fromRGB(120,220,255)
playerArrow.TextScaled = true
playerArrow.Font = Enum.Font.GothamBold
playerArrow.ZIndex = 10
playerArrow.Parent = mmClip

local mmTarget = Instance.new("Frame")
mmTarget.Size = UDim2.fromOffset(12,12)
mmTarget.AnchorPoint = Vector2.new(0.5,0.5)
mmTarget.BackgroundColor3 = Color3.fromRGB(255,220,80)
mmTarget.BorderSizePixel = 0
mmTarget.Visible = false
mmTarget.ZIndex = 9
mmTarget.Parent = mmClip
local mtc = Instance.new("UICorner"); mtc.CornerRadius = UDim.new(1,0); mtc.Parent = mmTarget

local placesFolder = Instance.new("Folder")
placesFolder.Name = "Places"
placesFolder.Parent = mmClip

S.Places = S.Places or {}

local function addPlaceIcon(name, worldPos, color)
    local icon = Instance.new("Frame")
    icon.Name = "Place_"..name
    icon.Size = UDim2.fromOffset(8,8)
    icon.AnchorPoint = Vector2.new(0.5,0.5)
    icon.BackgroundColor3 = color
    icon.BorderSizePixel = 0
    icon.ZIndex = 9
    icon.Visible = false
    icon.Parent = placesFolder
    local ic = Instance.new("UICorner"); ic.CornerRadius = UDim.new(1,0); ic.Parent = icon
    table.insert(S.Places, { name=name, pos=worldPos, icon=icon, color=color })
end
S.AddPlaceIcon = addPlaceIcon

task.spawn(function()
    while mmTarget.Parent do
        if mmTarget.Visible then
            mmTarget.BackgroundTransparency = 0
            task.wait(0.4)
            mmTarget.BackgroundTransparency = 0.6
            task.wait(0.4)
        else
            task.wait(0.3)
        end
    end
end)

local MM_RANGE = 400

local function getPlayerCFrame()
    local char = LocalPlayer.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    return hrp and hrp.CFrame
end

task.spawn(function()
    while mmFrame.Parent do
        task.wait(0.15)
        local cf = getPlayerCFrame()
        if cf then
            local ppos = cf.Position
            local look = cf.LookVector
            local angle = math.atan2(look.X, look.Z) * 180 / math.pi
            playerArrow.Rotation = -angle

            local targetPos
            if S.JobState == "pickup" and S.JobData then
                targetPos = S.JobData.getPoint()
            elseif S.JobState == "deliver" and S.JobData then
                targetPos = S.JobData.deliverPoint()
            end

            if targetPos then
                local rel = targetPos - ppos
                local nx = math.clamp(0.5 + (rel.X / (MM_RANGE*2)), 0.03, 0.97)
                local nz = math.clamp(0.5 + (rel.Z / (MM_RANGE*2)), 0.03, 0.97)
                mmTarget.Position = UDim2.fromScale(nx, nz)
                mmTarget.Visible = true
            else
                mmTarget.Visible = false
            end

            for _, p in ipairs(S.Places) do
                if p.icon and p.icon.Parent then
                    local rel = p.pos - ppos
                    local d = rel.Magnitude
                    if d > MM_RANGE * 1.5 then
                        p.icon.Visible = false
                    else
                        local nx = math.clamp(0.5 + (rel.X / (MM_RANGE*2)), 0.02, 0.98)
                        local nz = math.clamp(0.5 + (rel.Z / (MM_RANGE*2)), 0.02, 0.98)
                        p.icon.Position = UDim2.fromScale(nx, nz)
                        p.icon.Visible = true
                    end
                end
            end
        end
    end
end)

-- 点击小地图展开全屏大地图
local bigMap = Instance.new("Frame")
bigMap.Name = "MinimapFull"
bigMap.Size = UDim2.fromScale(0.9, 0.85)
bigMap.Position = UDim2.fromScale(0.05, 0.075)
bigMap.BackgroundColor3 = Color3.fromRGB(20,24,32)
bigMap.BackgroundTransparency = 0.15
bigMap.BorderSizePixel = 0
bigMap.Visible = false
bigMap.ZIndex = 100
bigMap.Parent = gui
applyGlass(bigMap, 24, 0.6)

local bigTitle = Instance.new("TextLabel")
bigTitle.Size = UDim2.fromScale(0.9,0.06)
bigTitle.Position = UDim2.fromScale(0.05,0.02)
bigTitle.BackgroundTransparency = 1
bigTitle.Text = "城市地图"
bigTitle.TextColor3 = Color3.fromRGB(255,255,255)
bigTitle.TextScaled = true
bigTitle.Font = Enum.Font.GothamBold
bigTitle.ZIndex = 101
bigTitle.Parent = bigMap

local bigClose = mkButton(bigMap, "✕", UDim2.fromScale(0.08,0.055),
    UDim2.fromScale(0.88,0.02), 0, Color3.fromRGB(120,50,50))
bigClose.ZIndex = 102
bigClose.Activated:Connect(function() bigMap.Visible = false end)

local bigCanvas = Instance.new("Frame")
bigCanvas.Size = UDim2.fromScale(0.9,0.85)
bigCanvas.Position = UDim2.fromScale(0.05,0.1)
bigCanvas.BackgroundColor3 = Color3.fromRGB(40,46,58)
bigCanvas.BackgroundTransparency = 0.3
bigCanvas.BorderSizePixel = 0
bigCanvas.ClipsDescendants = true
bigCanvas.ZIndex = 101
bigCanvas.Parent = bigMap
local bcc = Instance.new("UICorner"); bcc.CornerRadius = UDim.new(0,16); bcc.Parent = bigCanvas

local bigRoadH = Instance.new("Frame")
bigRoadH.Size = UDim2.fromScale(1,0.06)
bigRoadH.Position = UDim2.fromScale(0,0.47)
bigRoadH.BackgroundColor3 = Color3.fromRGB(90,90,100)
bigRoadH.BorderSizePixel = 0
bigRoadH.ZIndex = 102
bigRoadH.Parent = bigCanvas

local bigRoadV = Instance.new("Frame")
bigRoadV.Size = UDim2.fromScale(0.06,1)
bigRoadV.Position = UDim2.fromScale(0.47,0)
bigRoadV.BackgroundColor3 = Color3.fromRGB(90,90,100)
bigRoadV.BorderSizePixel = 0
bigRoadV.ZIndex = 102
bigRoadV.Parent = bigCanvas

local bigPlayer = Instance.new("TextLabel")
bigPlayer.Size = UDim2.fromOffset(20,20)
bigPlayer.AnchorPoint = Vector2.new(0.5,0.5)
bigPlayer.Position = UDim2.fromScale(0.5,0.5)
bigPlayer.BackgroundTransparency = 1
bigPlayer.Text = "▲"
bigPlayer.TextColor3 = Color3.fromRGB(120,220,255)
bigPlayer.TextScaled = true
bigPlayer.Font = Enum.Font.GothamBold
bigPlayer.ZIndex = 105
bigPlayer.Parent = bigCanvas

local BIG_RANGE = 3000

task.spawn(function()
    while bigMap.Parent do
        task.wait(0.2)
        if bigMap.Visible then
            local cf = getPlayerCFrame()
            if cf then
                local ppos = cf.Position
                local look = cf.LookVector
                bigPlayer.Rotation = -math.atan2(look.X, look.Z) * 180 / math.pi

                for _, p in ipairs(S.Places) do
                    if not p.bigIcon then
                        local bi = Instance.new("Frame")
                        bi.Size = UDim2.fromOffset(12,12)
                        bi.AnchorPoint = Vector2.new(0.5,0.5)
                        bi.BackgroundColor3 = p.color
                        bi.BorderSizePixel = 0
                        bi.ZIndex = 104
                        bi.Parent = bigCanvas
                        local bic = Instance.new("UICorner"); bic.CornerRadius = UDim.new(1,0); bic.Parent = bi
                        p.bigIcon = bi
                    end
                    local rel = p.pos - ppos
                    local nx = math.clamp(0.5 + (rel.X / (BIG_RANGE*2)), 0.02, 0.98)
                    local nz = math.clamp(0.5 + (rel.Z / (BIG_RANGE*2)), 0.02, 0.98)
                    p.bigIcon.Position = UDim2.fromScale(nx, nz)
                end
            end
        end
    end
end)

mmFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
    or input.UserInputType == Enum.UserInputType.Touch then
        bigMap.Visible = true
        animateOpen(bigMap, 0.9)
    end
end)

S.Notify("Part 3A 加载完成：时间/UI/动态玻璃/生存/小地图", Color3.fromRGB(120,220,160))
print("[IncSim] Part 3A 加载完成")
--[[
=====================================================================
  Part 3B：建筑内饰 / 门动画 / 电梯 / 可交互家具
  接在 Part 3A 末尾
=====================================================================
]]

-- ================== B1. 门系统 ==================
local doorFolder = Instance.new("Folder")
doorFolder.Name = "Doors"
doorFolder.Parent = cityFolder

local function makeHingedDoor(parent, pos, size, color, material, swingAngle)
    local frame = Instance.new("Part")
    frame.Size = Vector3.new(size.X + 0.4, size.Y + 0.4, 0.4)
    frame.Position = pos
    frame.Color = Color3.fromRGB(50,50,55)
    frame.Material = Enum.Material.Metal
    frame.Anchored = true
    frame.CanCollide = false
    frame.Parent = parent

    local door = Instance.new("Part")
    door.Size = size
    door.CFrame = CFrame.new(pos) * CFrame.new(-size.X/2, 0, 0)
    door.Color = color or Color3.fromRGB(180,210,230)
    door.Material = material or Enum.Material.Glass
    door.Transparency = (material == Enum.Material.Glass) and 0.4 or 0
    door.Anchored = true
    door.CanCollide = true
    door.Name = "HingedDoor"
    door.Parent = parent
    door:SetAttribute("IsOpen", false)

    local hingePos = pos + Vector3.new(-size.X/2, 0, 0)
    local closedCF = CFrame.new(hingePos) * CFrame.new(size.X/2, 0, 0)
    local angle = swingAngle or math.rad(90)

    local function setOpen(open)
        if door:GetAttribute("IsOpen") == open then return end
        door:SetAttribute("IsOpen", open)
        local target
        if open then
            target = CFrame.new(hingePos) * CFrame.Angles(0, angle, 0) * CFrame.new(size.X/2, 0, 0)
        else
            target = closedCF
        end
        TweenService:Create(door, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {CFrame = target}):Play()
    end

    task.spawn(function()
        while door.Parent do
            task.wait(0.3)
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - door.Position).Magnitude
                if d < 8 then setOpen(true)
                elseif d > 12 then setOpen(false) end
            end
        end
    end)
    return { frame=frame, door=door }
end

local function makeRollupDoor(parent, pos, size, color)
    local frame = Instance.new("Part")
    frame.Size = Vector3.new(size.X + 0.6, size.Y + 0.6, 0.4)
    frame.Position = pos
    frame.Color = Color3.fromRGB(60,60,65)
    frame.Material = Enum.Material.Metal
    frame.Anchored = true
    frame.CanCollide = false
    frame.Parent = parent

    local door = Instance.new("Part")
    door.Size = size
    door.Position = pos + Vector3.new(0, 0, 0.25)
    door.Color = color or Color3.fromRGB(130,130,140)
    door.Material = Enum.Material.Metal
    door.Anchored = true
    door.CanCollide = true
    door.Name = "RollupDoor"
    door.Parent = parent
    door:SetAttribute("IsOpen", false)
    local closedPos = door.Position

    local function setOpen(open)
        if door:GetAttribute("IsOpen") == open then return end
        door:SetAttribute("IsOpen", open)
        local target = open and closedPos + Vector3.new(0, size.Y - 0.5, 0) or closedPos
        TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {Position = target}):Play()
    end

    task.spawn(function()
        while door.Parent do
            task.wait(0.4)
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - door.Position).Magnitude
                if d < 10 then setOpen(true)
                elseif d > 14 then setOpen(false) end
            end
        end
    end)
    return { frame=frame, door=door }
end

local function makeRevolvingDoor(parent, pos, size, color)
    local frame = Instance.new("Part")
    frame.Shape = Enum.PartType.Cylinder
    frame.Size = Vector3.new(0.6, size.Y * 1.1, size.Y * 1.1)
    frame.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
    frame.Color = Color3.fromRGB(80,80,90)
    frame.Material = Enum.Material.Metal
    frame.Transparency = 0.3
    frame.Anchored = true
    frame.CanCollide = false
    frame.Parent = parent

    local pivot = Instance.new("Part")
    pivot.Size = Vector3.new(0.4, size.Y * 1.05, 0.4)
    pivot.Position = pos
    pivot.Transparency = 1
    pivot.CanCollide = false
    pivot.Anchored = true
    pivot.Parent = parent

    local bladeList = {}
    for i = 1, 4 do
        local blade = Instance.new("Part")
        blade.Size = Vector3.new(size.Y, size.Y * 0.9, 0.15)
        blade.CFrame = CFrame.new(pos) * CFrame.Angles(0, (i-1) * math.pi/2, 0) * CFrame.new(size.Y/2, 0, 0)
        blade.Color = color or Color3.fromRGB(180,210,230)
        blade.Material = Enum.Material.Glass
        blade.Transparency = 0.45
        blade.Anchored = true
        blade.CanCollide = false
        blade.Parent = parent
        table.insert(bladeList, blade)
    end

    task.spawn(function()
        local angle = 0
        while pivot.Parent do
            task.wait(0.06)
            angle = angle + math.rad(3)
            for i, b in ipairs(bladeList) do
                if not b.Parent then break end
                b.CFrame = CFrame.new(pos) * CFrame.Angles(0, angle + (i-1) * math.pi/2, 0) * CFrame.new(size.Y/2, 0, 0)
            end
        end
    end)
    return { frame=frame }
end

S.MakeHingedDoor = makeHingedDoor
S.MakeRollupDoor = makeRollupDoor
S.MakeRevolvingDoor = makeRevolvingDoor

-- ================== B2. 通用内饰工具 ==================
local interiorFolder = Instance.new("Folder")
interiorFolder.Name = "Interiors"
interiorFolder.Parent = cityFolder

local function buildFloor(parent, center, w, d, y, color, material)
    local f = Instance.new("Part")
    f.Size = Vector3.new(w, 0.4, d)
    f.Position = center + Vector3.new(0, y, 0)
    f.Color = color or Color3.fromRGB(180,175,165)
    f.Material = material or Enum.Material.Concrete
    f.Anchored = true
    f.Parent = parent
    return f
end

local function buildCeiling(parent, center, w, d, y, color)
    local c = Instance.new("Part")
    c.Size = Vector3.new(w, 0.4, d)
    c.Position = center + Vector3.new(0, y, 0)
    c.Color = color or Color3.fromRGB(230,230,235)
    c.Material = Enum.Material.SmoothPlastic
    c.Anchored = true
    c.Parent = parent
    return c
end

local function buildWall(parent, pos, size, color, material, transparency)
    local w = Instance.new("Part")
    w.Size = size
    w.Position = pos
    w.Color = color or Color3.fromRGB(200,200,205)
    w.Material = material or Enum.Material.Concrete
    w.Transparency = transparency or 0
    w.Anchored = true
    w.Parent = parent
    return w
end

local function buildLight(parent, pos)
    local bulb = Instance.new("Part")
    bulb.Shape = Enum.PartType.Ball
    bulb.Size = Vector3.new(1.4, 1.4, 1.4)
    bulb.Position = pos
    bulb.Color = Color3.fromRGB(255,240,200)
    bulb.Material = Enum.Material.Neon
    bulb.Anchored = true
    bulb.CanCollide = false
    bulb.Parent = parent
    local light = Instance.new("PointLight")
    light.Range = 24
    light.Brightness = 1.6
    light.Color = Color3.fromRGB(255,240,200)
    light.Shadows = true
    light.Parent = bulb
    return bulb
end

local function buildFluorescent(parent, pos, length)
    local t = Instance.new("Part")
    t.Size = Vector3.new(length or 6, 0.3, 0.8)
    t.Position = pos
    t.Color = Color3.fromRGB(230,240,255)
    t.Material = Enum.Material.Neon
    t.Anchored = true
    t.CanCollide = false
    t.Parent = parent
    local light = Instance.new("PointLight")
    light.Range = 20
    light.Brightness = 1.4
    light.Color = Color3.fromRGB(220,230,255)
    light.Parent = t
    return t
end

local function buildTable(parent, pos, size, color)
    local top = Instance.new("Part")
    top.Size = Vector3.new(size.X, 0.3, size.Z)
    top.Position = pos + Vector3.new(0, size.Y, 0)
    top.Color = color or Color3.fromRGB(120,80,50)
    top.Material = Enum.Material.Wood
    top.Anchored = true
    top.Parent = parent
    for dx = -1, 1, 2 do
        for dz = -1, 1, 2 do
            local leg = Instance.new("Part")
            leg.Size = Vector3.new(0.3, size.Y, 0.3)
            leg.Position = pos + Vector3.new(dx * (size.X/2 - 0.3), size.Y/2, dz * (size.Z/2 - 0.3))
            leg.Color = Color3.fromRGB(80,60,40)
            leg.Material = Enum.Material.Wood
            leg.Anchored = true
            leg.Parent = parent
        end
    end
end

local function buildChair(parent, pos, color)
    local seat = Instance.new("Part")
    seat.Size = Vector3.new(1.6, 0.3, 1.6)
    seat.Position = pos + Vector3.new(0, 1.5, 0)
    seat.Color = color or Color3.fromRGB(80,80,90)
    seat.Material = Enum.Material.SmoothPlastic
    seat.Anchored = true
    seat.Parent = parent

    local back = Instance.new("Part")
    back.Size = Vector3.new(1.6, 1.6, 0.2)
    back.Position = pos + Vector3.new(0, 2.3, 0.7)
    back.Color = color or Color3.fromRGB(80,80,90)
    back.Material = Enum.Material.SmoothPlastic
    back.Anchored = true
    back.Parent = parent

    for dx = -1, 1, 2 do
        for dz = -1, 1, 2 do
            local leg = Instance.new("Part")
            leg.Size = Vector3.new(0.15, 1.5, 0.15)
            leg.Position = pos + Vector3.new(dx*0.6, 0.75, dz*0.6)
            leg.Color = Color3.fromRGB(50,50,55)
            leg.Material = Enum.Material.Metal
            leg.Anchored = true
            leg.Parent = parent
        end
    end
end

local function buildBed(parent, pos)
    local base = Instance.new("Part")
    base.Size = Vector3.new(4, 0.6, 7)
    base.Position = pos + Vector3.new(0, 1, 0)
    base.Color = Color3.fromRGB(90,60,40)
    base.Material = Enum.Material.Wood
    base.Anchored = true
    base.Parent = parent

    local mattress = Instance.new("Part")
    mattress.Size = Vector3.new(3.8, 0.6, 6.8)
    mattress.Position = pos + Vector3.new(0, 1.6, 0)
    mattress.Color = Color3.fromRGB(240,240,250)
    mattress.Material = Enum.Material.Fabric
    mattress.Anchored = true
    mattress.Parent = parent

    local pillow = Instance.new("Part")
    pillow.Size = Vector3.new(3, 0.4, 1.6)
    pillow.Position = pos + Vector3.new(0, 2.1, -2.4)
    pillow.Color = Color3.fromRGB(255,255,255)
    pillow.Material = Enum.Material.Fabric
    pillow.Anchored = true
    pillow.Parent = parent
end

local function buildShelf(parent, pos, size, color)
    local body = Instance.new("Part")
    body.Size = size
    body.Position = pos + Vector3.new(0, size.Y/2, 0)
    body.Color = color or Color3.fromRGB(140,110,80)
    body.Material = Enum.Material.Wood
    body.Anchored = true
    body.Parent = parent

    for i = 1, 3 do
        local y = (size.Y / 4) * i
        local board = Instance.new("Part")
        board.Size = Vector3.new(size.X - 0.2, 0.2, size.Z - 0.2)
        board.Position = pos + Vector3.new(0, y, 0)
        board.Color = Color3.fromRGB(100,80,60)
        board.Material = Enum.Material.Wood
        board.Anchored = true
        board.Parent = parent
    end
end

local function buildTV(parent, pos)
    local stand = Instance.new("Part")
    stand.Size = Vector3.new(4, 2, 1.5)
    stand.Position = pos + Vector3.new(0, 1, 0)
    stand.Color = Color3.fromRGB(40,40,45)
    stand.Material = Enum.Material.Wood
    stand.Anchored = true
    stand.Parent = parent

    local screen = Instance.new("Part")
    screen.Size = Vector3.new(6, 3.6, 0.2)
    screen.Position = pos + Vector3.new(0, 3, 0)
    screen.Color = Color3.fromRGB(20,25,40)
    screen.Material = Enum.Material.SmoothPlastic
    screen.Anchored = true
    screen.Parent = parent

    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(400,240)
    sg.Parent = screen
    local img = Instance.new("Frame")
    img.Size = UDim2.fromScale(1,1)
    img.BackgroundColor3 = Color3.fromRGB(80,120,200)
    img.BorderSizePixel = 0
    img.Parent = sg
    local noise = Instance.new("TextLabel")
    noise.Size = UDim2.fromScale(1,1)
    noise.BackgroundTransparency = 1
    noise.Text = "▶ 直播中"
    noise.TextColor3 = Color3.fromRGB(255,255,255)
    noise.TextScaled = true
    noise.Font = Enum.Font.GothamBold
    noise.Parent = sg
end

local function buildCashier(parent, pos, facing)
    local counter = Instance.new("Part")
    counter.Size = Vector3.new(8, 3, 2)
    counter.Position = pos + Vector3.new(0, 1.5, 0)
    counter.Color = Color3.fromRGB(90,70,50)
    counter.Material = Enum.Material.Wood
    counter.Anchored = true
    counter.Parent = parent

    local reg = Instance.new("Part")
    reg.Size = Vector3.new(2, 1.2, 1.5)
    reg.Position = pos + Vector3.new(2, 3.6, -0.5)
    reg.Color = Color3.fromRGB(50,50,55)
    reg.Material = Enum.Material.SmoothPlastic
    reg.Anchored = true
    reg.Parent = parent
end

local function buildFridge(parent, pos, size)
    local f = Instance.new("Part")
    f.Size = size
    f.Position = pos + Vector3.new(0, size.Y/2, 0)
    f.Color = Color3.fromRGB(230,230,235)
    f.Material = Enum.Material.Glass
    f.Transparency = 0.4
    f.Anchored = true
    f.Parent = parent

    local inner = Instance.new("Part")
    inner.Size = size - Vector3.new(0.4,0.4,0.4)
    inner.Position = f.Position
    inner.Color = Color3.fromRGB(180,220,255)
    inner.Material = Enum.Material.Neon
    inner.Transparency = 0.7
    inner.Anchored = true
    inner.CanCollide = false
    inner.Parent = parent
end

local function buildStove(parent, pos)
    local stove = Instance.new("Part")
    stove.Size = Vector3.new(5, 2, 3)
    stove.Position = pos + Vector3.new(0, 1, 0)
    stove.Color = Color3.fromRGB(60,60,65)
    stove.Material = Enum.Material.Metal
    stove.Anchored = true
    stove.Parent = parent

    for i = 1, 4 do
        local burner = Instance.new("Part")
        burner.Shape = Enum.PartType.Cylinder
        burner.Size = Vector3.new(0.2, 1.2, 1.2)
        burner.CFrame = CFrame.new(pos + Vector3.new(-1.2 + ((i-1)%2)*2.4, 2.05, -0.6 + math.floor((i-1)/2)*1.2)) * CFrame.Angles(0,0,math.rad(90))
        burner.Color = Color3.fromRGB(30,30,35)
        burner.Material = Enum.Material.Metal
        burner.Anchored = true
        burner.Parent = parent
    end
end

local function buildDesk(parent, pos, facing)
    buildTable(parent, pos, Vector3.new(5, 2.5, 2.5), Color3.fromRGB(80,60,45))
    local monitor = Instance.new("Part")
    monitor.Size = Vector3.new(2, 1.4, 0.15)
    monitor.Position = pos + Vector3.new(0, 4.2, -0.8)
    monitor.Color = Color3.fromRGB(20,25,40)
    monitor.Material = Enum.Material.SmoothPlastic
    monitor.Anchored = true
    monitor.Parent = parent
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(200,140)
    sg.Parent = monitor
    local screen = Instance.new("Frame")
    screen.Size = UDim2.fromScale(1,1)
    screen.BackgroundColor3 = Color3.fromRGB(40,80,140)
    screen.BorderSizePixel = 0
    screen.Parent = sg
end

local function buildElevator(parent, pos, size)
    -- 电梯井
    local shaft = Instance.new("Part")
    shaft.Size = Vector3.new(size.X+1, size.Y, size.Z+1)
    shaft.Position = pos + Vector3.new(0, size.Y/2, 0)
    shaft.Color = Color3.fromRGB(80,80,90)
    shaft.Material = Enum.Material.Metal
    shaft.Transparency = 0.85
    shaft.Anchored = true
    shaft.CanCollide = false
    shaft.Parent = parent

    -- 电梯门（双开）
    local leftDoor = Instance.new("Part")
    leftDoor.Size = Vector3.new(size.X/2 - 0.2, size.Y, 0.3)
    leftDoor.Position = pos + Vector3.new(-size.X/4, size.Y/2, size.Z/2 + 0.2)
    leftDoor.Color = Color3.fromRGB(180,185,200)
    leftDoor.Material = Enum.Material.Metal
    leftDoor.Anchored = true
    leftDoor.Parent = parent
    leftDoor:SetAttribute("IsOpen", false)

    local rightDoor = Instance.new("Part")
    rightDoor.Size = Vector3.new(size.X/2 - 0.2, size.Y, 0.3)
    rightDoor.Position = pos + Vector3.new(size.X/4, size.Y/2, size.Z/2 + 0.2)
    rightDoor.Color = Color3.fromRGB(180,185,200)
    rightDoor.Material = Enum.Material.Metal
    rightDoor.Anchored = true
    rightDoor.Parent = parent
    rightDoor:SetAttribute("IsOpen", false)

    local leftClosed = leftDoor.Position
    local rightClosed = rightDoor.Position

    local function setOpen(open)
        if leftDoor:GetAttribute("IsOpen") == open then return end
        leftDoor:SetAttribute("IsOpen", open)
        rightDoor:SetAttribute("IsOpen", open)
        local lo = open and leftClosed + Vector3.new(-size.X/2 + 0.3, 0, 0) or leftClosed
        local ro = open and rightClosed + Vector3.new(size.X/2 - 0.3, 0, 0) or rightClosed
        TweenService:Create(leftDoor, TweenInfo.new(0.5), {Position=lo}):Play()
        TweenService:Create(rightDoor, TweenInfo.new(0.5), {Position=ro}):Play()
    end

    task.spawn(function()
        while leftDoor.Parent do
            task.wait(0.3)
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local d = (hrp.Position - pos).Magnitude
                if d < 8 then setOpen(true)
                elseif d > 12 then setOpen(false) end
            end
        end
    end)

    -- 电梯面板按钮（视觉）
    local panel = Instance.new("Part")
    panel.Size = Vector3.new(0.2, 3, 1)
    panel.Position = pos + Vector3.new(size.X/2 + 0.5, 3, size.Z/2 + 0.2)
    panel.Color = Color3.fromRGB(50,50,60)
    panel.Material = Enum.Material.Metal
    panel.Anchored = true
    panel.CanCollide = false
    panel.Parent = parent
    return { leftDoor=leftDoor, rightDoor=rightDoor }
end

S.BuildFloor = buildFloor
S.BuildCeiling = buildCeiling
S.BuildWall = buildWall
S.BuildLight = buildLight
S.BuildFluorescent = buildFluorescent
S.BuildTable = buildTable
S.BuildChair = buildChair
S.BuildBed = buildBed
S.BuildShelf = buildShelf
S.BuildTV = buildTV
S.BuildCashier = buildCashier
S.BuildFridge = buildFridge
S.BuildStove = buildStove
S.BuildDesk = buildDesk
S.BuildElevator = buildElevator

-- ================== B3. 建筑内部生成器 ==================
-- 每栋建筑都用同一套接口：buildInterior(type, center, w, d, h, doorFacing)

local function makeApartmentInterior(center, w, d, h, doorZ)
    local f = interiorFolder
    local floors = math.max(1, math.floor(h / 8))

    -- 大堂
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(200,190,175), Enum.Material.Marble)
    buildCeiling(f, center, w-1, d-1, 8, Color3.fromRGB(230,230,235))
    buildLight(f, center + Vector3.new(0, 7.5, 0))
    buildLight(f, center + Vector3.new(0, 7.5, d/3))

    -- 前台
    buildTable(f, center + Vector3.new(0, 0, -d/3), Vector3.new(6, 2.5, 2), Color3.fromRGB(100,80,60))
    -- 信箱
    for i = 1, 8 do
        local box = Instance.new("Part")
        box.Size = Vector3.new(0.8, 1.2, 0.6)
        box.Position = center + Vector3.new(-w/2 + 2 + i*0.9, 4, -d/2 + 1)
        box.Color = Color3.fromRGB(150,150,160)
        box.Material = Enum.Material.Metal
        box.Anchored = true
        box.Parent = f
    end
    -- 电梯
    buildElevator(f, center + Vector3.new(w/4, 0, -d/4), Vector3.new(4, 8, 4))

    -- 楼上：走廊 + 每层 3 户
    for floor = 1, floors - 1 do
        local y = floor * 8
        -- 走廊地板
        buildFloor(f, center + Vector3.new(0, 0, 0), w-1, d-1, y + 0.6, Color3.fromRGB(180,175,165))
        -- 走廊天花板
        buildCeiling(f, center, w-1, d-1, y + 4, Color3.fromRGB(220,220,225))
        -- 走廊灯
        for i = 0, 2 do
            buildFluorescent(f, center + Vector3.new(-w/2 + 4 + i*((w-8)/2), y + 3.7, 0), 3)
        end
        -- 每层房间（3 户）
        for room = 1, 3 do
            local rx = -w/4 + (room-1) * (w/4)
            local roomCenter = center + Vector3.new(rx, y, d/4)
            -- 房间墙
            buildWall(f, roomCenter + Vector3.new(0, 2, -d/4+0.5), Vector3.new(w/4-0.5, 4, 0.3), Color3.fromRGB(220,215,205))
            -- 家具
            buildBed(f, roomCenter + Vector3.new(-1, 0, 1))
            buildTable(f, roomCenter + Vector3.new(2, 0, -1), Vector3.new(3, 2, 2))
            buildChair(f, roomCenter + Vector3.new(2, 0, 0.8))
            buildTV(f, roomCenter + Vector3.new(0, 0, -d/4+1))
        end
    end
end

local function makeShopInterior(center, w, d, h)
    local f = interiorFolder
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(200,200,190), Enum.Material.Tile)
    buildCeiling(f, center, w-1, d-1, h-1, Color3.fromRGB(235,235,235))
    for i = 1, 3 do
        buildFluorescent(f, center + Vector3.new(-w/2 + i*((w-2)/3), h-2, 0), 4)
    end
    -- 货架
    for row = 1, 3 do
        buildShelf(f, center + Vector3.new(-w/3 + (row-1) * w/3, 0, 0), Vector3.new(3, 5, 2), Color3.fromRGB(140,110,80))
    end
    -- 收银台
    buildCashier(f, center + Vector3.new(w/2 - 3, 0, -d/2 + 3))
    -- 后仓门
    makeRollupDoor(f, center + Vector3.new(0, 0, -d/2 + 0.5), Vector3.new(4, 5, 0.3))
end

local function makeOfficeInterior(center, w, d, h)
    local f = interiorFolder
    local floors = math.max(1, math.floor(h / 6))
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(220,215,205), Enum.Material.Marble)
    buildCeiling(f, center, w-1, d-1, 8, Color3.fromRGB(235,235,240))
    buildLight(f, center + Vector3.new(0, 7.5, 0))
    buildElevator(f, center + Vector3.new(0, 0, -d/4), Vector3.new(4, 8, 4))

    for floor = 1, floors - 1 do
        local y = floor * 6
        buildFloor(f, center, w-1, d-1, y + 0.6)
        buildCeiling(f, center, w-1, d-1, y + 4)
        -- 办公区：3 张桌子
        for i = 1, 3 do
            buildDesk(f, center + Vector3.new(-w/4 + (i-1)*(w/4), y, 0))
            buildChair(f, center + Vector3.new(-w/4 + (i-1)*(w/4), y, 2))
        end
        -- 会议室
        buildTable(f, center + Vector3.new(0, y, d/4), Vector3.new(6, 2.5, 3), Color3.fromRGB(90,70,50))
        for i = 1, 4 do
            buildChair(f, center + Vector3.new(-2.5 + (i-1)*1.7, y, d/4 + 2), Color3.fromRGB(60,60,70))
        end
    end
end

local function makeWarehouseInterior(center, w, d, h)
    local f = interiorFolder
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(150,145,140), Enum.Material.Concrete)
    buildCeiling(f, center, w-1, d-1, h-1, Color3.fromRGB(180,180,190))
    for i = 1, 4 do
        buildFluorescent(f, center + Vector3.new(-w/3 + (i-1)*(w/4), h-2, 0), 5)
    end
    -- 货架区
    for row = 1, 4 do
        buildShelf(f, center + Vector3.new(-w/2 + row*(w/5), 0, -d/4), Vector3.new(2.5, 7, 3))
    end
    -- 装卸月台
    local dock = Instance.new("Part")
    dock.Size = Vector3.new(w-2, 1.5, 6)
    dock.Position = center + Vector3.new(0, 0.75, d/2 - 3)
    dock.Color = Color3.fromRGB(120,120,125)
    dock.Material = Enum.Material.Concrete
    dock.Anchored = true
    dock.Parent = f
    -- 卷帘门
    makeRollupDoor(f, center + Vector3.new(-w/4, 0, d/2), Vector3.new(6, 7, 0.3), Color3.fromRGB(100,100,110))
    makeRollupDoor(f, center + Vector3.new(w/4, 0, d/2), Vector3.new(6, 7, 0.3), Color3.fromRGB(100,100,110))
end

local function makeRestaurantInterior(center, w, d, h)
    local f = interiorFolder
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(200,180,150), Enum.Material.WoodPlanks)
    buildCeiling(f, center, w-1, d-1, h-1, Color3.fromRGB(240,230,220))
    for i = 1, 3 do
        buildLight(f, center + Vector3.new(-w/3 + (i-1)*(w/3), h-2, 0))
    end

    -- 用餐区（6 张带编号的桌）
    for i = 1, 6 do
        local tx = -w/3 + ((i-1) % 3) * (w/3)
        local tz = -d/4 + math.floor((i-1)/3) * (d/2)
        local tp = center + Vector3.new(tx, 0, tz)
        buildTable(f, tp, Vector3.new(3, 2.5, 3), Color3.fromRGB(110,70,50))
        buildChair(f, tp + Vector3.new(2, 0, 0))
        buildChair(f, tp + Vector3.new(-2, 0, 0))

        -- 桌号
        local num = Instance.new("Part")
        num.Size = Vector3.new(0.6, 0.6, 0.1)
        num.Position = tp + Vector3.new(0, 3, -1.4)
        num.Color = Color3.fromRGB(250,240,200)
        num.Material = Enum.Material.SmoothPlastic
        num.Anchored = true
        num.Parent = f
        local sg = Instance.new("SurfaceGui")
        sg.Face = Enum.NormalId.Front
        sg.CanvasSize = Vector2.new(60,60)
        sg.Parent = num
        local tl = Instance.new("TextLabel")
        tl.Size = UDim2.fromScale(1,1)
        tl.BackgroundTransparency = 1
        tl.Text = tostring(i)
        tl.TextColor3 = Color3.fromRGB(60,40,20)
        tl.TextScaled = true
        tl.Font = Enum.Font.GothamBold
        tl.Parent = sg
    end

    -- 后厨
    buildWall(f, center + Vector3.new(0, 3, d/3), Vector3.new(w-1, 6, 0.3), Color3.fromRGB(200,195,190))
    buildStove(f, center + Vector3.new(-w/4, 0, d/2 - 2))
    buildFridge(f, center + Vector3.new(w/4, 0, d/2 - 2), Vector3.new(3, 6, 2.5))
    -- 后厨门
    makeHingedDoor(f, center + Vector3.new(0, 0, d/3), Vector3.new(4, 6, 0.3), Color3.fromRGB(150,150,150), Enum.Material.Metal, math.rad(90))
end

local function makeConvenienceStoreInterior(center, w, d, h)
    local f = interiorFolder
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(235,235,235), Enum.Material.Tile)
    buildCeiling(f, center, w-1, d-1, h-1, Color3.fromRGB(245,245,245))
    for i = 1, 3 do
        buildFluorescent(f, center + Vector3.new(-w/3 + (i-1)*(w/3), h-2, 0), 4)
    end
    -- 货架 4 排
    for row = 1, 4 do
        buildShelf(f, center + Vector3.new(-w/2 + row*(w/5), 0, 0), Vector3.new(2.5, 4, 2))
    end
    -- 冰柜
    buildFridge(f, center + Vector3.new(-w/2 + 2, 0, -d/2 + 2), Vector3.new(2.5, 5, 3))
    buildFridge(f, center + Vector3.new(-w/2 + 5, 0, -d/2 + 2), Vector3.new(2.5, 5, 3))
    -- 收银台
    buildCashier(f, center + Vector3.new(w/2 - 3, 0, -d/2 + 3))
    -- 后仓
    makeRollupDoor(f, center + Vector3.new(w/2 - 3, 0, d/2 - 0.5), Vector3.new(3, 5, 0.3))
end

local function makeHospitalInterior(center, w, d, h)
    local f = interiorFolder
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(240,240,245), Enum.Material.Tile)
    buildCeiling(f, center, w-1, d-1, h-1, Color3.fromRGB(250,250,255))
    for i = 1, 4 do
        buildFluorescent(f, center + Vector3.new(-w/3 + (i-1)*(w/4), h-2, 0), 4)
    end
    -- 大厅座椅
    for i = 1, 6 do
        buildChair(f, center + Vector3.new(-w/2 + 2 + i*1.8, 0, -d/4), Color3.fromRGB(80,120,160))
    end
    -- 挂号处
    buildCashier(f, center + Vector3.new(0, 0, -d/2 + 3))
    -- 诊室桌子
    buildDesk(f, center + Vector3.new(-w/4, 0, d/4))
    buildDesk(f, center + Vector3.new(w/4, 0, d/4))
    -- 病床
    buildBed(f, center + Vector3.new(-w/4 + 2, 0, d/2 - 3))
    buildBed(f, center + Vector3.new(w/4 - 2, 0, d/2 - 3))
end

local function makePoliceInterior(center, w, d, h)
    local f = interiorFolder
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(190,190,200), Enum.Material.Concrete)
    buildCeiling(f, center, w-1, d-1, h-1, Color3.fromRGB(220,220,230))
    for i = 1, 3 do
        buildFluorescent(f, center + Vector3.new(-w/3 + (i-1)*(w/3), h-2, 0), 4)
    end
    -- 前台
    buildCashier(f, center + Vector3.new(0, 0, -d/2 + 3))
    -- 办公桌
    for i = 1, 3 do
        buildDesk(f, center + Vector3.new(-w/3 + (i-1)*(w/3), 0, 0))
    end
    -- 拘留室（铁栅栏）
    for i = 1, 6 do
        local bar = Instance.new("Part")
        bar.Size = Vector3.new(0.15, 6, 0.15)
        bar.Position = center + Vector3.new(w/2 - 1 - i*0.4, 3, d/4)
        bar.Color = Color3.fromRGB(80,80,90)
        bar.Material = Enum.Material.Metal
        bar.Anchored = true
        bar.Parent = f
    end
end

local function makeGasStationInterior(center, w, d, h)
    local f = interiorFolder
    buildFloor(f, center, w-1, d-1, 0.6, Color3.fromRGB(220,220,225), Enum.Material.Tile)
    buildCeiling(f, center, w-1, d-1, h-1, Color3.fromRGB(240,240,245))
    buildFluorescent(f, center, h-2, 5)
    -- 便利店内部
    buildShelf(f, center + Vector3.new(-w/4, 0, 0), Vector3.new(2, 4, 4))
    buildFridge(f, center + Vector3.new(w/4, 0, -d/4), Vector3.new(2.5, 5, 2.5))
    buildCashier(f, center + Vector3.new(w/4 + 1, 0, d/4))
    -- 员工休息室门
    makeHingedDoor(f, center + Vector3.new(0, 0, d/2 - 0.5), Vector3.new(3, 6, 0.3), Color3.fromRGB(150,140,130), Enum.Material.Wood, math.rad(90))
end

-- 主入口：替换第 2 段建的建筑，给每栋楼加内饰
-- 我们用遍历的方式：找到每栋建筑体，根据风格生成内饰
S.InteriorBuilders = {
    apartment = makeApartmentInterior,
    shop = makeShopInterior,
    office = makeOfficeInterior,
    warehouse = makeWarehouseInterior,
    restaurant = makeRestaurantInterior,
    convenience = makeConvenienceStoreInterior,
    hospital = makeHospitalInterior,
    police = makePoliceInterior,
    gas = makeGasStationInterior,
}

-- 给玩家附近的地块生成带内饰的建筑
-- 因为第一部分建筑已经建好，这里额外给"入口"位置放一个可识别的门
-- 并且在地图上标记可进入的建筑
S.InteriorSpawned = S.InteriorSpawned or {}

local function addEnterableBuilding(type_, center, w, d, h)
    local key = string.format("%d_%d", center.X, center.Z)
    if S.InteriorSpawned[key] then return end
    S.InteriorSpawned[key] = true

    -- 在主建筑正面开门
    local doorPos = center + Vector3.new(0, 0, d/2 + 0.3)
    if type_ == "warehouse" or type_ == "shop" or type_ == "convenience" then
        makeRollupDoor(interiorFolder, doorPos, Vector3.new(4, 6, 0.3))
    elseif type_ == "office" then
        makeRevolvingDoor(interiorFolder, doorPos, Vector3.new(0, 3, 3), Color3.fromRGB(180,200,230))
    else
        makeHingedDoor(interiorFolder, doorPos, Vector3.new(4, 6, 0.3), Color3.fromRGB(180,210,230), Enum.Material.Glass, math.rad(90))
    end

    -- 生成内饰
    local builder = S.InteriorBuilders[type_]
    if builder then builder(center, w, d, h) end
end

S.AddEnterableBuilding = addEnterableBuilding

-- 立即给城市中的部分建筑生成内饰（限制数量避免卡顿）
task.spawn(function()
    task.wait(1)
    local CELLS = S.MapCells or {}
    local spawned = 0
    local maxInteriors = 20  -- 首批生成 20 栋（后续通过距离触发加载）

    -- 优先玩家附近的
    local playerPos = (LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.Position) or Vector3.new(550,0,550)
    table.sort(CELLS, function(a,b)
        return (a-playerPos).Magnitude < (b-playerPos).Magnitude
    end)

    for i, c in ipairs(CELLS) do
        if spawned >= maxInteriors then break end
        local types = {"shop", "office", "restaurant", "convenience", "hospital", "police", "gas", "warehouse"}
        local t = types[(i % #types) + 1]
        addEnterableBuilding(t, c, 18, 18, 14)
        spawned = spawned + 1
        if spawned % 3 == 0 then task.wait() end
    end
    S.Notify("已生成 "..spawned.." 栋可进入建筑", Color3.fromRGB(120,220,160))
end)

S.Notify("Part 3B 加载完成：内饰/门/电梯", Color3.fromRGB(120,220,160))
print("[IncSim] Part 3B 加载完成")
--[[
=====================================================================
  Part 3C：5000×5000 大地图 / 8 大区域 / 高速公路 / 立交桥 / 隧道
  接在 Part 3B 末尾
=====================================================================
]]

-- ================== C1. 大地图参数 ==================
S.BIG_MAP_SIZE = 5000
S.BIG_MAP_CENTER = Vector3.new(2500, 0, 2500)
S.BIG_REGIONS = {}

local MAP = S.BIG_MAP_SIZE
local CEN = S.BIG_MAP_CENTER

-- 区域划分（按方位 + 功能）
-- 每个区域: name, x1,z1,x2,z2, 主色, 建筑风格
local REGIONS = {
    { name="Downtown 市中心",  x1=1750, z1=1750, x2=3250, z2=3250, color=Color3.fromRGB(150,160,180), style="office" },
    { name="Commercial 商业区", x1=3250, z1=1750, x2=4250, z2=3250, color=Color3.fromRGB(180,140,120), style="shop" },
    { name="Residential 住宅区",x1= 750, z1=1750, x2=1750, z2=3250, color=Color3.fromRGB(140,160,140), style="residential" },
    { name="Industrial 工业区", x1=1750, z1=3250, x2=3250, z2=4250, color=Color3.fromRGB(120,120,125), style="warehouse" },
    { name="Port 港口区",       x1= 750, z1=3250, x2=1750, z2=4250, color=Color3.fromRGB(100,140,180), style="warehouse" },
    { name="Airport 机场区",    x1=3250, z1=3250, x2=4250, z2=4250, color=Color3.fromRGB(200,200,210), style="warehouse" },
    { name="Entertainment 娱乐区", x1= 750, z1= 750, x2=1750, z2=1750, color=Color3.fromRGB(200,120,180), style="shop" },
    { name="Suburb 郊区",       x1=1750, z1= 750, x2=4250, z2=1750, color=Color3.fromRGB(160,180,140), style="residential" },
}
S.BIG_REGIONS = REGIONS

-- ================== C2. 大地图地面 ==================
local bigGround = newPart(cityFolder, Vector3.new(MAP, 4, MAP),
    CFrame.new(CEN), Color3.fromRGB(70,120,70), Enum.Material.Grass)
bigGround.Name = "BigGround"

-- 每个区域铺不同材质的地表
for _, r in ipairs(REGIONS) do
    local cx = (r.x1 + r.x2) / 2
    local cz = (r.z1 + r.z2) / 2
    local w = r.x2 - r.x1
    local d = r.z2 - r.z1
    local mat = Enum.Material.Concrete
    if r.style == "residential" then mat = Enum.Material.Grass
    elseif r.style == "warehouse" then mat = Enum.Material.Concrete
    elseif r.style == "shop" then mat = Enum.Material.Brick
    elseif r.style == "office" then mat = Enum.Material.Marble end

    local ground = newPart(cityFolder, Vector3.new(w, 0.6, d),
        CFrame.new(cx, 2.5, cz), r.color, mat)
    ground.Name = "RegionGround_"..r.name
    ground.Transparency = 0.55
    ground.CanCollide = false
end

-- ================== C3. 高速公路环线 ==================
-- 外环：距中心 2000，宽度 100
local function buildHighway(centerX, centerZ, sizeX, sizeZ, width, name)
    local halfX = sizeX / 2
    local halfZ = sizeZ / 2
    local Y = 20  -- 高速公路抬高 20 studs

    -- 四条边（带坡道支撑）
    local function highwaySide(pos, size, horiz)
        -- 桥面
        local deck = newPart(cityFolder, size, CFrame.new(pos.X, Y, pos.Z),
            Color3.fromRGB(60,60,65), Enum.Material.Concrete)
        deck.Name = name.."_Deck_"..(horiz and "H" or "V")

        -- 护栏
        if horiz then
            newPart(cityFolder, Vector3.new(size.X, 2, 1),
                CFrame.new(pos.X, Y + size.Y/2 + 1, pos.Z - size.Z/2 + 0.5),
                Color3.fromRGB(200,200,210), Enum.Material.Metal).CanCollide = false
            newPart(cityFolder, Vector3.new(size.X, 2, 1),
                CFrame.new(pos.X, Y + size.Y/2 + 1, pos.Z + size.Z/2 - 0.5),
                Color3.fromRGB(200,200,210), Enum.Material.Metal).CanCollide = false
        else
            newPart(cityFolder, Vector3.new(1, 2, size.Z),
                CFrame.new(pos.X - size.X/2 + 0.5, Y + size.Y/2 + 1, pos.Z),
                Color3.fromRGB(200,200,210), Enum.Material.Metal).CanCollide = false
            newPart(cityFolder, Vector3.new(1, 2, size.Z),
                CFrame.new(pos.X + size.X/2 - 0.5, Y + size.Y/2 + 1, pos.Z),
                Color3.fromRGB(200,200,210), Enum.Material.Metal).CanCollide = false
        end

        -- 虚线
        if horiz then
            local i = -halfX
            while i < halfX do
                newPart(cityFolder, Vector3.new(15, 0.2, 1.2),
                    CFrame.new(pos.X + i, Y + size.Y/2 + 0.15, pos.Z),
                    Color3.fromRGB(255,255,200)).CanCollide = false
                i = i + 30
            end
        else
            local i = -halfZ
            while i < halfZ do
                newPart(cityFolder, Vector3.new(1.2, 0.2, 15),
                    CFrame.new(pos.X, Y + size.Y/2 + 0.15, pos.Z + i),
                    Color3.fromRGB(255,255,200)).CanCollide = false
                i = i + 30
            end
        end
    end

    -- 四条边
    highwaySide(Vector3.new(centerX, 0, centerZ - halfZ), Vector3.new(sizeX, 1, width), true)
    highwaySide(Vector3.new(centerX, 0, centerZ + halfZ), Vector3.new(sizeX, 1, width), true)
    highwaySide(Vector3.new(centerX - halfX, 0, centerZ), Vector3.new(width, 1, sizeZ), false)
    highwaySide(Vector3.new(centerX + halfX, 0, centerZ), Vector3.new(width, 1, sizeZ), false)

    -- 支撑柱（每 200 studs 一根）
    for i = 0, math.floor(sizeX / 200) do
        for _, z in ipairs({centerZ - halfZ, centerZ + halfZ}) do
            local x = centerX - halfX + i * 200
            newPart(cityFolder, Vector3.new(6, Y, 6),
                CFrame.new(x, Y/2, z), Color3.fromRGB(120,120,125), Enum.Material.Concrete)
        end
    end
    for i = 0, math.floor(sizeZ / 200) do
        for _, x in ipairs({centerX - halfX, centerX + halfX}) do
            local z = centerZ - halfZ + i * 200
            newPart(cityFolder, Vector3.new(6, Y, 6),
                CFrame.new(x, Y/2, z), Color3.fromRGB(120,120,125), Enum.Material.Concrete)
        end
    end

    -- 坡道（连接地面和高速）—— 四个角
    local rampLength = 80
    local corners = {
        {x = centerX - halfX, z = centerZ - halfZ, dir = Vector3.new(-1,0,-1)},
        {x = centerX + halfX, z = centerZ - halfZ, dir = Vector3.new( 1,0,-1)},
        {x = centerX - halfX, z = centerZ + halfZ, dir = Vector3.new(-1,0, 1)},
        {x = centerX + halfX, z = centerZ + halfZ, dir = Vector3.new( 1,0, 1)},
    }
    for _, c in ipairs(corners) do
        local ramp = newPart(cityFolder, Vector3.new(60, 1, rampLength),
            CFrame.new(c.x + c.dir.X * rampLength/2, Y/2, c.z + c.dir.Z * rampLength/2)
            * CFrame.Angles(math.rad(-15) * c.dir.Z, 0, 0),
            Color3.fromRGB(60,60,65), Enum.Material.Concrete)
        ramp.CanCollide = true
    end
end

-- 外环
buildHighway(CEN.X, CEN.Z, 4000, 4000, 100, "HighwayOuter")
-- 内环
buildHighway(CEN.X, CEN.Z, 2500, 2500, 80, "HighwayInner")

S.Notify("高速公路环线已生成", Color3.fromRGB(120,220,255))

-- ================== C4. 立交桥 ==================
-- 在主干道和高速公路交叉处造立交
local function buildOverpass(x, z, orient)
    local Y = 20
    -- 主桥（跨越）
    if orient == "H" then
        newPart(cityFolder, Vector3.new(200, 2, 30),
            CFrame.new(x, Y, z), Color3.fromRGB(70,70,75), Enum.Material.Concrete)
        newPart(cityFolder, Vector3.new(200, 1.5, 1),
            CFrame.new(x, Y + 1.5, z - 14), Color3.fromRGB(200,200,210), Enum.Material.Metal).CanCollide = false
        newPart(cityFolder, Vector3.new(200, 1.5, 1),
            CFrame.new(x, Y + 1.5, z + 14), Color3.fromRGB(200,200,210), Enum.Material.Metal).CanCollide = false
    else
        newPart(cityFolder, Vector3.new(30, 2, 200),
            CFrame.new(x, Y, z), Color3.fromRGB(70,70,75), Enum.Material.Concrete)
        newPart(cityFolder, Vector3.new(1, 1.5, 200),
            CFrame.new(x - 14, Y + 1.5, z), Color3.fromRGB(200,200,210), Enum.Material.Metal).CanCollide = false
        newPart(cityFolder, Vector3.new(1, 1.5, 200),
            CFrame.new(x + 14, Y + 1.5, z), Color3.fromRGB(200,200,210), Enum.Material.Metal).CanCollide = false
    end

    -- 下穿隧道口
    if orient == "H" then
        newPart(cityFolder, Vector3.new(60, 8, 14),
            CFrame.new(x - 60, 4, z - 18), Color3.fromRGB(80,80,85), Enum.Material.Concrete, Enum.PartType.Block).Transparency = 0
        newPart(cityFolder, Vector3.new(60, 8, 14),
            CFrame.new(x + 60, 4, z + 18), Color3.fromRGB(80,80,85), Enum.Material.Concrete, Enum.PartType.Block).Transparency = 0
    end

    -- 支撑柱
    newPart(cityFolder, Vector3.new(4, Y, 4),
        CFrame.new(x - 60, Y/2, z), Color3.fromRGB(120,120,125), Enum.Material.Concrete)
    newPart(cityFolder, Vector3.new(4, Y, 4),
        CFrame.new(x + 60, Y/2, z), Color3.fromRGB(120,120,125), Enum.Material.Concrete)
end

-- 沿外环高速的 4 个立交
buildOverpass(CEN.X - 2000, CEN.Z, "H")
buildOverpass(CEN.X + 2000, CEN.Z, "H")
buildOverpass(CEN.X, CEN.Z - 2000, "V")
buildOverpass(CEN.X, CEN.Z + 2000, "V")
-- 内环 4 个
buildOverpass(CEN.X - 1250, CEN.Z, "H")
buildOverpass(CEN.X + 1250, CEN.Z, "H")
buildOverpass(CEN.X, CEN.Z - 1250, "V")
buildOverpass(CEN.X, CEN.Z + 1250, "V")

S.Notify("立交桥已生成", Color3.fromRGB(120,220,255))

-- ================== C5. 隧道 ==================
local function buildTunnel(x1, z1, x2, z2, width, height)
    local dx = x2 - x1
    local dz = z2 - z1
    local length = math.sqrt(dx*dx + dz*dz)
    local midX = (x1 + x2) / 2
    local midZ = (z1 + z2) / 2
    local angle = math.atan2(dx, dz)

    -- 隧道顶
    newPart(cityFolder, Vector3.new(width + 4, 2, length),
        CFrame.new(midX, -2, midZ) * CFrame.Angles(0, angle, 0),
        Color3.fromRGB(90,90,95), Enum.Material.Concrete)

    -- 隧道两侧墙
    local function sideWall(sign)
        local sideCFrame = CFrame.new(midX, -height/2 - 4, midZ) * CFrame.Angles(0, angle, 0)
            * CFrame.new(sign * (width/2 + 1), 0, 0)
        newPart(cityFolder, Vector3.new(2, height, length),
            sideCFrame, Color3.fromRGB(100,100,105), Enum.Material.Concrete)
    end
    sideWall(-1)
    sideWall(1)

    -- 隧道地面
    newPart(cityFolder, Vector3.new(width, 1, length),
        CFrame.new(midX, -6, midZ) * CFrame.Angles(0, angle, 0),
        Color3.fromRGB(50,50,55), Enum.Material.Asphalt)

    -- 隧道灯
    local steps = math.floor(length / 40)
    for i = 1, steps do
        local t = i / steps
        local lx = x1 + dx * t
        local lz = z1 + dz * t
        local lamp = newPart(cityFolder, Vector3.new(0.5, 0.5, 3),
            CFrame.new(lx, -1.5, lz) * CFrame.Angles(0, angle, 0),
            Color3.fromRGB(255,240,200), Enum.Material.Neon)
        lamp.CanCollide = false
        local light = Instance.new("PointLight")
        light.Range = 30
        light.Brightness = 1.2
        light.Color = Color3.fromRGB(255,240,200)
        light.Parent = lamp
    end
end

-- 穿越市中心的隧道
buildTunnel(CEN.X - 400, CEN.Z - 400, CEN.X + 400, CEN.Z + 400, 30, 10)
buildTunnel(CEN.X + 400, CEN.Z - 400, CEN.X - 400, CEN.Z + 400, 30, 10)

S.Notify("隧道已生成", Color3.fromRGB(120,220,255))

-- ================== C6. 8 大区域建筑填充 ==================
-- 每个区域按风格撒建筑
local buildingStyles = {
    office = function(cx, cz, w, d, h) 
        -- 高层办公楼
        local body = newPart(buildingsFolder, Vector3.new(w, h, d), CFrame.new(cx, h/2, cz),
            Color3.fromRGB(150,160,180), Enum.Material.Concrete)
        -- 玻璃幕墙
        for i = 1, math.floor(h / 6) do
            newPart(buildingsFolder, Vector3.new(w + 0.4, 4, 0.3),
                CFrame.new(cx, i * 6 - 2, cz + d/2 + 0.2),
                Color3.fromRGB(140,180,220), Enum.Material.Glass).Transparency = 0.4
            newPart(buildingsFolder, Vector3.new(w + 0.4, 4, 0.3),
                CFrame.new(cx, i * 6 - 2, cz - d/2 - 0.2),
                Color3.fromRGB(140,180,220), Enum.Material.Glass).Transparency = 0.4
        end
        newPart(buildingsFolder, Vector3.new(w+1, 1, d+1), CFrame.new(cx, h+0.5, cz),
            Color3.fromRGB(90,90,100), Enum.Material.Slate)
    end,
    shop = function(cx, cz, w, d, h)
        newPart(buildingsFolder, Vector3.new(w, h, d), CFrame.new(cx, h/2, cz),
            Color3.fromRGB(180,140,120), Enum.Material.Brick)
        newPart(buildingsFolder, Vector3.new(w, 1.5, d), CFrame.new(cx, h + 0.75, cz),
            Color3.fromRGB(120,90,80), Enum.Material.Wood)
        -- 招牌
        newPart(buildingsFolder, Vector3.new(w - 2, 2, 0.4),
            CFrame.new(cx, h - 1, cz + d/2 + 0.3),
            Color3.fromRGB(200,100,100), Enum.Material.Neon)
    end,
    residential = function(cx, cz, w, d, h)
        newPart(buildingsFolder, Vector3.new(w, h, d), CFrame.new(cx, h/2, cz),
            Color3.fromRGB(160,180,160), Enum.Material.Concrete)
        -- 窗
        for f = 1, math.floor(h / 7) do
            for i = 1, 2 do
                newPart(buildingsFolder, Vector3.new(2, 2.5, 0.3),
                    CFrame.new(cx - w/4 + i * w/2, f * 7 - 2, cz + d/2 + 0.2),
                    Color3.fromRGB(200,220,240), Enum.Material.Glass)
                newPart(buildingsFolder, Vector3.new(2, 2.5, 0.3),
                    CFrame.new(cx - w/4 + i * w/2, f * 7 - 2, cz - d/2 - 0.2),
                    Color3.fromRGB(200,220,240), Enum.Material.Glass)
            end
        end
        newPart(buildingsFolder, Vector3.new(w+1, 1, d+1), CFrame.new(cx, h+0.5, cz),
            Color3.fromRGB(90,90,100), Enum.Material.Slate)
    end,
    warehouse = function(cx, cz, w, d, h)
        newPart(buildingsFolder, Vector3.new(w, h, d), CFrame.new(cx, h/2, cz),
            Color3.fromRGB(150,150,155), Enum.Material.CorrodedMetal)
        -- 铁皮屋顶
        newPart(buildingsFolder, Vector3.new(w + 2, 1.5, d + 2), CFrame.new(cx, h + 0.75, cz),
            Color3.fromRGB(100,100,110), Enum.Material.CorrodedMetal)
        -- 烟囱
        newPart(buildingsFolder, Vector3.new(2.5, h + 4, 2.5),
            CFrame.new(cx + w/3, (h+4)/2, cz + d/3),
            Color3.fromRGB(80,80,85), Enum.Material.Brick)
    end,
}

local function fillRegion(r)
    local style = buildingStyles[r.style] or buildingStyles.shop
    local cellSize = 80
    local margin = 20
    local gridX = math.floor((r.x2 - r.x1 - margin*2) / cellSize)
    local gridZ = math.floor((r.z2 - r.z1 - margin*2) / cellSize)
    local count = 0

    for gx = 0, gridX - 1 do
        for gz = 0, gridZ - 1 do
            if math.random() < 0.7 then
                local cx = r.x1 + margin + gx * cellSize + cellSize/2
                local cz = r.z1 + margin + gz * cellSize + cellSize/2
                local w = math.random(30, 60)
                local d = math.random(30, 60)
                local h
                if r.style == "office" then h = math.random(60, 120)
                elseif r.style == "warehouse" then h = math.random(15, 25)
                elseif r.style == "residential" then h = math.random(20, 40)
                else h = math.random(15, 30) end
                style(cx, cz, w, d, h)
                count = count + 1
                if count % 5 == 0 then task.wait() end
            end
        end
    end
    return count
end

local totalRegionBuildings = 0
for _, r in ipairs(REGIONS) do
    local c = fillRegion(r)
    totalRegionBuildings = totalRegionBuildings + c
    S.Notify("区域 " .. r.name .. "：" .. c .. " 栋建筑", Color3.fromRGB(180,220,255))
    task.wait(0.2)
end

S.Notify("大地图共生成 " .. totalRegionBuildings .. " 栋区域建筑", Color3.fromRGB(120,220,160))

-- ================== C7. 机场跑道 ==================
local runway = newPart(cityFolder, Vector3.new(500, 1, 60),
    CFrame.new(3700, 3, 3750), Color3.fromRGB(45,45,50), Enum.Material.Concrete)
runway.Name = "AirportRunway"
-- 跑道中线
for i = -240, 240, 30 do
    newPart(cityFolder, Vector3.new(15, 0.2, 2),
        CFrame.new(3700 + i, 3.6, 3750), Color3.fromRGB(255,255,255)).CanCollide = false
end
-- 跑道灯
for i = -240, 240, 40 do
    local lamp = newPart(cityFolder, Vector3.new(0.6, 0.6, 0.6),
        CFrame.new(3700 + i, 3.5, 3720), Color3.fromRGB(255,220,80), Enum.Material.Neon)
    lamp.CanCollide = false
    local lamp2 = newPart(cityFolder, Vector3.new(0.6, 0.6, 0.6),
        CFrame.new(3700 + i, 3.5, 3780), Color3.fromRGB(255,220,80), Enum.Material.Neon)
    lamp2.CanCollide = false
end

-- 航站楼
newPart(cityFolder, Vector3.new(120, 25, 50),
    CFrame.new(3700, 12.5, 3600), Color3.fromRGB(200,200,210), Enum.Material.Glass)

-- ================== C8. 港口 ==================
local dockArea = { x = 1250, z = 3750 }

-- 码头地面
newPart(cityFolder, Vector3.new(400, 2, 100),
    CFrame.new(dockArea.x, 3, dockArea.z), Color3.fromRGB(140,140,145), Enum.Material.Concrete)

-- 货船
local ship = newPart(cityFolder, Vector3.new(200, 20, 40),
    CFrame.new(dockArea.x, 12, dockArea.z - 100), Color3.fromRGB(150,50,50), Enum.Material.Metal)
ship.Name = "CargoShip"
-- 集装箱
for i = 1, 8 do
    newPart(cityFolder, Vector3.new(12, 10, 10),
        CFrame.new(dockArea.x - 60 + i * 15, 27, dockArea.z - 100),
        Color3.fromHSV(i/8, 0.8, 0.9), Enum.Material.Metal)
end

-- 起重机
local crane = newPart(cityFolder, Vector3.new(3, 60, 3),
    CFrame.new(dockArea.x - 150, 30, dockArea.z), Color3.fromRGB(220,200,50), Enum.Material.Metal)
newPart(cityFolder, Vector3.new(60, 3, 3),
    CFrame.new(dockArea.x - 120, 58, dockArea.z), Color3.fromRGB(220,200,50), Enum.Material.Metal)

S.Notify("机场跑道 + 港口已生成", Color3.fromRGB(120,220,255))

-- ================== C9. 8 区域地标标记（供小地图/传送用） ==================
for _, r in ipairs(REGIONS) do
    local cx = (r.x1 + r.x2) / 2
    local cz = (r.z1 + r.z2) / 2
    local markerPos = Vector3.new(cx, 5, cz)
    S.AddPlaceIcon(r.name, markerPos, r.color)
end

-- 特殊地标
S.AddPlaceIcon("机场", Vector3.new(3700, 5, 3750), Color3.fromRGB(255,220,100))
S.AddPlaceIcon("港口", Vector3.new(1250, 5, 3750), Color3.fromRGB(100,180,255))
S.AddPlaceIcon("中央广场", CEN, Color3.fromRGB(255,240,120))

-- ================== C10. 让玩家可以开车横穿（传送点） ==================
S.RegisterPoint("highway_teleport_north", Vector3.new(CEN.X, 3, CEN.Z - 2000),
    "上高速（北）", "通往郊区", function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(CEN.X, 25, CEN.Z - 1950)
            S.Notify("已上传送北区高速", Color3.fromRGB(120,220,255))
        end
    end)

S.RegisterPoint("airport_teleport", Vector3.new(3700, 3, 3600),
    "前往机场", "机场区", function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(3700, 10, 3700)
            S.Notify("已传送到机场", Color3.fromRGB(120,220,255))
        end
    end)

S.RegisterPoint("port_teleport", Vector3.new(1250, 3, 3750),
    "前往港口", "港口区", function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(1250, 10, 3750)
            S.Notify("已传送到港口", Color3.fromRGB(120,220,255))
        end
    end)

S.Notify("Part 3C 加载完成：5000×5000 / 8 区域 / 高速 / 立交 / 隧道", Color3.fromRGB(120,220,160))
print("[IncSim] Part 3C 加载完成")
--[[
=====================================================================
  Part 3D：NPC / 车辆 / 天气 / 城市声音
  接在 Part 3C 末尾
=====================================================================
]]

-- ================== D1. NPC 系统 ==================
local npcFolder = Instance.new("Folder")
npcFolder.Name = "NPCs"
npcFolder.Parent = cityFolder

S.NPCs = S.NPCs or {}

-- NPC 外观随机池
local SKIN_COLORS = {
    Color3.fromRGB(255,220,180), Color3.fromRGB(240,200,160),
    Color3.fromRGB(200,160,120), Color3.fromRGB(160,120,90),
    Color3.fromRGB(120,80,60),
}
local SHIRT_COLORS = {
    Color3.fromRGB(200,60,60), Color3.fromRGB(60,120,200),
    Color3.fromRGB(60,180,80), Color3.fromRGB(220,200,80),
    Color3.fromRGB(150,80,180), Color3.fromRGB(80,80,90),
    Color3.fromRGB(255,140,60),
}
local PANTS_COLORS = {
    Color3.fromRGB(40,40,60), Color3.fromRGB(80,60,40),
    Color3.fromRGB(60,60,70), Color3.fromRGB(30,30,40),
}

local function makeNPCModel(name)
    local model = Instance.new("Model")
    model.Name = name

    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Color = SHIRT_COLORS[math.random(1,#SHIRT_COLORS)]
    torso.Material = Enum.Material.SmoothPlastic
    torso.Parent = model

    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.6, 1.6, 1.6)
    head.Color = SKIN_COLORS[math.random(1,#SKIN_COLORS)]
    head.Parent = model

    local larm = Instance.new("Part")
    larm.Name = "Left Arm"
    larm.Size = Vector3.new(1, 2, 1)
    larm.Color = torso.Color
    larm.Parent = model

    local rarm = Instance.new("Part")
    rarm.Name = "Right Arm"
    rarm.Size = Vector3.new(1, 2, 1)
    rarm.Color = torso.Color
    rarm.Parent = model

    local lleg = Instance.new("Part")
    lleg.Name = "Left Leg"
    lleg.Size = Vector3.new(1, 2, 1)
    lleg.Color = PANTS_COLORS[math.random(1,#PANTS_COLORS)]
    lleg.Parent = model

    local rleg = Instance.new("Part")
    rleg.Name = "Right Leg"
    rleg.Size = Vector3.new(1, 2, 1)
    rleg.Color = lleg.Color
    rleg.Parent = model

    local hrp = Instance.new("Part")
    hrp.Name = "HumanoidRootPart"
    hrp.Size = Vector3.new(2, 2, 1)
    hrp.Transparency = 1
    hrp.Parent = model

    local hum = Instance.new("Humanoid")
    hum.RigType = Enum.HumanoidRigType.R6
    hum.Parent = model

    -- 用 Motor6D 连接（R6 标准骨架）
    local function motor(name, part0, part1, c0)
        local m = Instance.new("Motor6D")
        m.Name = name
        m.Part0 = part0
        m.Part1 = part1
        m.C0 = c0
        m.Parent = part0
    end

    motor("RootJoint", hrp, torso, CFrame.new(0,0,0))
    motor("Neck", torso, head, CFrame.new(0, 1, 0))
    motor("Left Shoulder", torso, larm, CFrame.new(-1, 0.5, 0))
    motor("Right Shoulder", torso, rarm, CFrame.new(1, 0.5, 0))
    motor("Left Hip", torso, lleg, CFrame.new(-0.5, -1, 0))
    motor("Right Hip", torso, rleg, CFrame.new(0.5, -1, 0))

    return model
end

-- 让 NPC 走路（用 Humanoid:MoveTo）
local function makeNPCWalk(npc, waypoints)
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if not hum then return end
    local idx = 1
    task.spawn(function()
        while npc.Parent and hum.Health > 0 do
            local wp = waypoints[idx]
            hum:MoveTo(wp)
            local startT = tick()
            while (npc.HumanoidRootPart.Position - wp).Magnitude > 4 and tick() - startT < 15 do
                task.wait(0.3)
            end
            idx = idx % #waypoints + 1
            task.wait(0.2)
        end
    end)
end

-- 在道路上生成行人
local function spawnPedestrian(pos)
    local npc = makeNPCModel("Pedestrian")
    local hrp = npc.HumanoidRootPart
    hrp.CFrame = CFrame.new(pos)
    npc.Parent = npcFolder

    -- 随机 4 个路径点
    local wps = {}
    for i = 1, 4 do
        table.insert(wps, pos + Vector3.new(math.random(-80,80), 0, math.random(-80,80)))
    end
    makeNPCWalk(npc, wps)

    table.insert(S.NPCs, { model=npc, type="pedestrian" })
    return npc
end

-- 醉汉：摇晃走路
local function spawnDrunk(pos)
    local npc = spawnPedestrian(pos)
    npc.Name = "Drunk"
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 6 end
    -- 摇晃
    task.spawn(function()
        while npc.Parent do
            task.wait(0.5)
            local hrp = npc:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = hrp.CFrame * CFrame.Angles(0, math.rad(math.random(-15,15)), 0)
            end
        end
    end)
    for _, e in ipairs(S.NPCs) do
        if e.model == npc then e.type = "drunk" end
    end
end

-- 警察：在警局附近巡逻
local function spawnCop(pos)
    local npc = spawnPedestrian(pos)
    npc.Name = "Cop"
    local torso = npc:FindFirstChild("Torso")
    if torso then
        torso.Color = Color3.fromRGB(40,60,120)
        npc["Left Arm"].Color = Color3.fromRGB(40,60,120)
        npc["Right Arm"].Color = Color3.fromRGB(40,60,120)
    end
    for _, e in ipairs(S.NPCs) do
        if e.model == npc then e.type = "cop" end
    end
end

-- 店员（站立，有交互）
local function spawnClerk(pos, shopName)
    local npc = makeNPCModel("Clerk")
    npc.HumanoidRootPart.CFrame = CFrame.new(pos)
    npc.Parent = npcFolder
    local hum = npc:FindFirstChildOfClass("Humanoid")
    if hum then hum.WalkSpeed = 0 end
    -- 头顶名字
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(120, 30)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = npc:FindFirstChild("Head")
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1,1)
    tl.BackgroundTransparency = 1
    tl.Text = "店员"
    tl.TextColor3 = Color3.fromRGB(255,255,200)
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.Parent = bb

    table.insert(S.NPCs, { model=npc, type="clerk", name=shopName })
    return npc
end

-- 批量生成：在城市里随机撒 NPC
local function spawnNPCBatch()
    local region = S.BIG_REGIONS or {}
    if #region == 0 then return end
    local types = {"pedestrian", "pedestrian", "pedestrian", "drunk", "cop"}
    local spawned = 0

    for i = 1, 60 do
        local r = region[math.random(1, #region)]
        local x = math.random(r.x1, r.x2)
        local z = math.random(r.z1, r.z2)
        local pos = Vector3.new(x, 3, z)
        local t = types[math.random(1, #types)]
        if t == "drunk" then spawnDrunk(pos)
        elseif t == "cop" then spawnCop(pos)
        else spawnPedestrian(pos) end
        spawned = spawned + 1
        if spawned % 5 == 0 then task.wait() end
    end
    S.Notify("已生成 "..spawned.." 个 NPC", Color3.fromRGB(200,180,255))
end

task.spawn(spawnNPCBatch)

-- ================== D2. 车辆系统 ==================
local vehicleFolder = Instance.new("Folder")
vehicleFolder.Name = "Vehicles"
vehicleFolder.Parent = cityFolder

S.Vehicles = S.Vehicles or {}

-- 30 种车型参数
local CAR_TYPES = {
    -- { name, color, sizeX, sizeY, sizeZ, topSpeed }
    {"轿车 A",    Color3.fromRGB(200,50,50),   6, 3, 12, 60},
    {"轿车 B",    Color3.fromRGB(50,100,200),  6, 3, 12, 60},
    {"轿车 C",    Color3.fromRGB(200,200,200), 6, 3, 12, 60},
    {"SUV A",     Color3.fromRGB(80,80,80),    7, 4, 14, 55},
    {"SUV B",     Color3.fromRGB(150,120,60),  7, 4, 14, 55},
    {"跑车 A",    Color3.fromRGB(220,30,30),   6, 2.5, 12, 90},
    {"跑车 B",    Color3.fromRGB(30,220,100),  6, 2.5, 12, 90},
    {"卡车 A",    Color3.fromRGB(100,100,100), 8, 6, 18, 45},
    {"卡车 B",    Color3.fromRGB(60,80,120),   8, 6, 18, 45},
    {"公交车",    Color3.fromRGB(200,180,60),  8, 7, 24, 40},
    {"出租车",    Color3.fromRGB(255,220,50),  6, 3, 12, 60},
    {"警车",      Color3.fromRGB(20,30,80),    6, 3, 12, 70},
    {"救护车",    Color3.fromRGB(240,240,240), 7, 5, 14, 65},
    {"消防车",    Color3.fromRGB(220,40,40),   8, 6, 18, 50},
    {"摩托车 A",  Color3.fromRGB(30,30,30),    2, 3, 5, 80},
    {"摩托车 B",  Color3.fromRGB(200,50,100),  2, 3, 5, 80},
    {"皮卡",      Color3.fromRGB(120,80,60),   7, 4, 14, 55},
    {"厢式货车",  Color3.fromRGB(230,230,230), 7, 6, 16, 50},
    {"面包车",    Color3.fromRGB(180,180,200), 7, 5, 14, 55},
    {"敞篷车",    Color3.fromRGB(230,100,180), 6, 2.5, 12, 75},
    {"越野车",    Color3.fromRGB(80,120,60),   7, 4, 14, 60},
    {"豪华车 A",  Color3.fromRGB(20,20,20),    6, 3, 13, 70},
    {"豪华车 B",  Color3.fromRGB(200,180,120), 6, 3, 13, 70},
    {"运钞车",    Color3.fromRGB(80,80,100),   7, 5, 14, 55},
    {"垃圾车",    Color3.fromRGB(70,100,70),   8, 6, 18, 40},
    {"清障车",    Color3.fromRGB(240,180,60),  8, 6, 18, 45},
    {"出租车 B",  Color3.fromRGB(240,200,30),  6, 3, 12, 60},
    {"校车",      Color3.fromRGB(240,200,30),  8, 7, 22, 40},
    {"跑车 C",    Color3.fromRGB(80,20,80),    6, 2.5, 12, 95},
    {"摩托警车",  Color3.fromRGB(240,240,240), 2, 3, 5, 85},
}

-- 生成车辆模型
local function makeCarModel(carDef)
    local name, color, sx, sy, sz, topSpeed = table.unpack(carDef)
    local model = Instance.new("Model")
    model.Name = name
    model:SetAttribute("TopSpeed", topSpeed)

    local body = Instance.new("Part")
    body.Size = Vector3.new(sx, sy, sz)
    body.Color = color
    body.Material = Enum.Material.SmoothPlastic
    body.Name = "Body"
    body.Parent = model

    -- 车窗
    local windshield = Instance.new("Part")
    windshield.Size = Vector3.new(sx * 0.9, sy * 0.5, sz * 0.4)
    windshield.Color = Color3.fromRGB(60,80,120)
    windshield.Material = Enum.Material.Glass
    windshield.Transparency = 0.4
    windshield.CanCollide = false
    windshield.Name = "Windshield"
    windshield.Parent = model

    -- 车灯
    local hl = Instance.new("Part")
    hl.Size = Vector3.new(0.6, 0.6, 0.3)
    hl.Color = Color3.fromRGB(255,240,200)
    hl.Material = Enum.Material.Neon
    hl.Name = "HeadlightL"
    hl.Parent = model

    local hr = Instance.new("Part")
    hr.Size = Vector3.new(0.6, 0.6, 0.3)
    hr.Color = Color3.fromRGB(255,240,200)
    hr.Material = Enum.Material.Neon
    hr.Name = "HeadlightR"
    hr.Parent = model

    -- 尾灯
    local tl = Instance.new("Part")
    tl.Size = Vector3.new(0.6, 0.6, 0.3)
    tl.Color = Color3.fromRGB(255,40,40)
    tl.Material = Enum.Material.Neon
    tl.Name = "TaillightL"
    tl.Parent = model

    local tr = Instance.new("Part")
    tr.Size = Vector3.new(0.6, 0.6, 0.3)
    tr.Color = Color3.fromRGB(255,40,40)
    tr.Material = Enum.Material.Neon
    tr.Name = "TaillightR"
    tr.Parent = model

    -- 轮子
    local wheelPositions = {
        {-sx/2 + 0.5, -sy/2 + 0.5, -sz/3},  -- 前左
        { sx/2 - 0.5, -sy/2 + 0.5, -sz/3},  -- 前右
        {-sx/2 + 0.5, -sy/2 + 0.5,  sz/3},  -- 后左
        { sx/2 - 0.5, -sy/2 + 0.5,  sz/3},  -- 后右
    }
    local wheels = {}
    for i, wp in ipairs(wheelPositions) do
        local w = Instance.new("Part")
        w.Shape = Enum.PartType.Cylinder
        w.Size = Vector3.new(1.2, 2.4, 2.4)
        w.CFrame = CFrame.new(wp) * CFrame.Angles(0, 0, math.rad(90))
        w.Color = Color3.fromRGB(30,30,30)
        w.Material = Enum.Material.Rubber
        w.CanCollide = false
        w.Name = "Wheel"..i
        w.Parent = model
        table.insert(wheels, w)
    end

    -- 用焊接把部件固定在 body 上
    local function weld(part, offset, lookAt)
        part.CFrame = body.CFrame * CFrame.new(table.unpack(offset))
        local wc = Instance.new("WeldConstraint")
        wc.Part0 = body
        wc.Part1 = part
        wc.Parent = part
    end
    weld(windshield, {0, sy * 0.3, 0})
    weld(hl, {-sx/2 + 0.5, 0, -sz/2 - 0.2})
    weld(hr, { sx/2 - 0.5, 0, -sz/2 - 0.2})
    weld(tl, {-sx/2 + 0.5, 0,  sz/2 + 0.2})
    weld(tr, { sx/2 - 0.5, 0,  sz/2 + 0.2})
    for i, w in ipairs(wheels) do
        local wc = Instance.new("WeldConstraint")
        wc.Part0 = body
        wc.Part1 = w
        wc.Parent = w
    end

    model.PrimaryPart = body
    return model
end

-- 沿道路自动行驶
local function driveVehicleAlong(vehicle, waypoints, speed)
    local body = vehicle.PrimaryPart
    local topSpeed = vehicle:GetAttribute("TopSpeed") or speed
    local idx = 1
    task.spawn(function()
        while body.Parent do
            local target = waypoints[idx]
            local start = body.Position
            local distance = (target - start).Magnitude
            if distance < 4 then
                idx = idx % #waypoints + 1
            else
                local dir = (target - start).Unit
                local step = topSpeed * 0.15
                body.CFrame = CFrame.new(start + dir * step, target)
                task.wait(0.05)
            end
        end
    end)
end

-- 生成路边停车
local function spawnParkedCar(pos, rotation)
    local carDef = CAR_TYPES[math.random(1, #CAR_TYPES)]
    local car = makeCarModel(carDef)
    car.PrimaryPart.Anchored = true
    car.PrimaryPart.CFrame = CFrame.new(pos) * CFrame.Angles(0, rotation, 0)
    car.Parent = vehicleFolder
    table.insert(S.Vehicles, { model=car, type="parked" })
    return car
end

-- 生成行驶车辆
local function spawnMovingCar(startPos, endPos)
    local carDef = CAR_TYPES[math.random(1, #CAR_TYPES)]
    local car = makeCarModel(carDef)
    car.PrimaryPart.Anchored = true
    car.PrimaryPart.CFrame = CFrame.new(startPos, endPos)
    car.Parent = vehicleFolder
    driveVehicleAlong(car, {startPos, endPos, startPos}, car:GetAttribute("TopSpeed") or 60)
    table.insert(S.Vehicles, { model=car, type="moving" })
    return car
end

-- 批量撒车
local function spawnVehicleBatch()
    local region = S.BIG_REGIONS or {}
    if #region == 0 then return end

    -- 40 辆路边停车
    for i = 1, 40 do
        local r = region[math.random(1, #region)]
        local x = math.random(r.x1, r.x2)
        local z = math.random(r.z1, r.z2)
        spawnParkedCar(Vector3.new(x, 4, z), math.random() * math.pi * 2)
        if i % 8 == 0 then task.wait() end
    end

    -- 20 辆行驶车
    for i = 1, 20 do
        local r = region[math.random(1, #region)]
        local x1 = r.x1
        local z1 = math.random(r.z1, r.z2)
        local x2 = r.x2
        spawnMovingCar(Vector3.new(x1, 4, z1), Vector3.new(x2, 4, z1))
        if i % 5 == 0 then task.wait() end
    end

    S.Notify("已生成 40 辆停车 + 20 辆行驶车", Color3.fromRGB(200,180,255))
end

task.spawn(spawnVehicleBatch)

-- 玩家可以上车（靠近车辆交互）
local function makeVehicleDrivable(car)
    local body = car.PrimaryPart
    local seat = Instance.new("VehicleSeat")
    seat.Size = Vector3.new(2, 1, 2)
    seat.CFrame = body.CFrame * CFrame.new(0, body.Size.Y/2 + 0.5, 0)
    seat.Color = body.Color
    seat.Transparency = 1
    seat.Parent = car

    local wc = Instance.new("WeldConstraint")
    wc.Part0 = body
    wc.Part1 = seat
    wc.Parent = seat
end

for _, v in ipairs(S.Vehicles) do
    if v.model and v.model.PrimaryPart then
        makeVehicleDrivable(v.model)
    end
end

-- ================== D3. 天气系统 ==================
S.Weather = "sunny"

local weatherNames = {sunny="晴天", cloudy="阴天", rainy="雨天", foggy="雾天"}
local weatherColors = {
    sunny = Color3.fromRGB(200,215,235),
    cloudy = Color3.fromRGB(150,160,175),
    rainy = Color3.fromRGB(80,90,110),
    foggy = Color3.fromRGB(200,200,205),
}

local rainFolder = Instance.new("Folder")
rainFolder.Name = "Rain"
rainFolder.Parent = cityFolder

local function setWeather(w)
    S.Weather = w
    -- 天空颜色
    Lighting.FogColor = weatherColors[w] or Color3.fromRGB(200,215,235)
    if w == "sunny" then
        Lighting.FogEnd = 4000
        Lighting.Brightness = 3
    elseif w == "cloudy" then
        Lighting.FogEnd = 3000
        Lighting.Brightness = 2
    elseif w == "rainy" then
        Lighting.FogEnd = 1500
        Lighting.Brightness = 1.2
    elseif w == "foggy" then
        Lighting.FogEnd = 500
        Lighting.Brightness = 1.5
    end

    -- 雨滴
    for _, r in ipairs(rainFolder:GetChildren()) do r:Destroy() end
    if w == "rainy" then
        local char = LocalPlayer.Character
        if char then
            local hrp = char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for i = 1, 300 do
                    local drop = Instance.new("Part")
                    drop.Size = Vector3.new(0.1, 0.8, 0.1)
                    drop.Color = Color3.fromRGB(180,200,240)
                    drop.Material = Enum.Material.SmoothPlastic
                    drop.Transparency = 0.5
                    drop.Anchored = true
                    drop.CanCollide = false
                    drop.Position = hrp.Position + Vector3.new(math.random(-60,60), 30, math.random(-60,60))
                    drop.Parent = rainFolder
                    table.insert(S.RainDrops or {}, drop)
                end
            end
        end
    end

    S.Notify("天气变化："..weatherNames[w], Color3.fromRGB(180,220,255))
end

S.SetWeather = setWeather

-- 雨滴下落循环
task.spawn(function()
    while true do
        task.wait(0.1)
        if S.Weather == "rainy" then
            local char = LocalPlayer.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                for _, d in ipairs(rainFolder:GetChildren()) do
                    if d:IsA("Part") then
                        d.Position = d.Position - Vector3.new(0, 3, 0)
                        if d.Position.Y < hrp.Position.Y - 5 then
                            d.Position = hrp.Position + Vector3.new(math.random(-60,60), 30, math.random(-60,60))
                        end
                    end
                end
            end
        end
    end
end)

-- 天气自动切换（每 2 分钟换一次）
task.spawn(function()
    local weathers = {"sunny", "sunny", "cloudy", "rainy", "foggy"}
    while true do
        task.wait(120)
        local w = weathers[math.random(1, #weathers)]
        setWeather(w)
    end
end)

-- 天气影响工作收益
local origReward = S.JobBuilders and S.JobBuilders[1]
-- 不改结构，只加一个全局倍率
S.GetWeatherMultiplier = function()
    if S.Weather == "rainy" then return 1.5 end  -- 下雨天收益 +
    if S.Weather == "foggy" then return 1.2 end
    return 1.0
end

-- ================== D4. 城市环境音 ==================
local soundFolder = Instance.new("Folder")
soundFolder.Name = "AmbientSounds"
soundFolder.Parent = cityFolder

-- 由于 Delta 环境不能拉取外部音频资源，我们用 Roblox 内置音效
-- 如果这些 ID 失效，用 pcall 保护
local AMBIENT_IDS = {
    traffic = "rbxassetid://9046339243",  -- 城市交通
    birds   = "rbxassetid://5159133434",  -- 鸟叫
    people  = "rbxassetid://1837995080",  -- 人群
}

local function makeSoundLoop(id, volume, name)
    local s = Instance.new("Sound")
    s.SoundId = id
    s.Volume = volume
    s.Looped = true
    s.Name = name
    s.Parent = soundFolder
    -- 挂在 SoundService
    local SoundService = game:GetService("SoundService")
    s.Parent = SoundService
    pcall(function() s:Play() end)
    return s
end

pcall(function()
    makeSoundLoop(AMBIENT_IDS.traffic, 0.15, "TrafficSound")
    makeSoundLoop(AMBIENT_IDS.birds,   0.10, "BirdsSound")
    makeSoundLoop(AMBIENT_IDS.people,  0.08, "PeopleSound")
end)

S.Notify("城市环境音已加载", Color3.fromRGB(200,180,255))

-- ================== D5. NPC / 车辆数量上限保护 ==================
-- 定期清理远处的 NPC/车辆（防止无限增长）
task.spawn(function()
    while true do
        task.wait(30)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local ppos = hrp.Position
            -- 清理超出 2000 studs 的 NPC
            for _, n in ipairs(S.NPCs) do
                if n.model and n.model.Parent then
                    local nrp = n.model:FindFirstChild("HumanoidRootPart")
                    if nrp and (nrp.Position - ppos).Magnitude > 2000 then
                        -- 传送回玩家附近 800-1500 studs 范围内的随机点
                        local angle = math.random() * math.pi * 2
                        local dist = math.random(600, 1200)
                        nrp.CFrame = CFrame.new(ppos + Vector3.new(math.cos(angle) * dist, 3, math.sin(angle) * dist))
                    end
                end
            end
        end
    end
end)

S.Notify("Part 3D 加载完成：NPC/车辆/天气/声音", Color3.fromRGB(120,220,160))
print("[IncSim] Part 3D 加载完成")
--[[
=====================================================================
  Part 3E：枪械店 / 50 枪 / 射击系统 / 靶场
  接在 Part 3D 末尾
=====================================================================
]]

-- ================== E1. 枪械数据表（50 种） ==================
-- 字段: id, name, type, damage, fireRate(发/秒), magSize, reload(s), recoil, price, range
-- type: ar 突击 / smg 冲锋 / sniper 狙击 / pistol 手枪 / shotgun 霰弹 / lmg 机枪 / explosive 爆炸 / special 特殊

S.GUNS = {
    -- ============ 突击步枪 10 种 ============
    {id="m4a1",   name="M4A1",     type="ar", damage=28, fireRate=10, magSize=30, reload=2.2, recoil=1.2, price=5000,  range=500},
    {id="ak47",   name="AK-47",    type="ar", damage=35, fireRate=9,  magSize=30, reload=2.4, recoil=1.8, price=5500,  range=500},
    {id="scar",   name="SCAR-L",   type="ar", damage=30, fireRate=9,  magSize=30, reload=2.3, recoil=1.4, price=6000,  range=520},
    {id="aug",    name="AUG",      type="ar", damage=27, fireRate=10, magSize=30, reload=2.1, recoil=1.1, price=5800,  range=500},
    {id="famas",  name="FAMAS",    type="ar", damage=25, fireRate=11, magSize=30, reload=2.0, recoil=1.3, price=5200,  range=480},
    {id="g36",    name="G36C",     type="ar", damage=29, fireRate=9,  magSize=30, reload=2.2, recoil=1.3, price=5600,  range=500},
    {id="tar21",  name="TAR-21",   type="ar", damage=31, fireRate=9,  magSize=30, reload=2.4, recoil=1.5, price=6200,  range=520},
    {id="ar15",   name="AR-15",    type="ar", damage=32, fireRate=8,  magSize=20, reload=2.2, recoil=1.6, price=5900,  range=520},
    {id="m16",    name="M16A4",    type="ar", damage=33, fireRate=7,  magSize=30, reload=2.5, recoil=1.7, price=6100,  range=550},
    {id="hk416",  name="HK416",    type="ar", damage=30, fireRate=10, magSize=30, reload=2.2, recoil=1.2, price=6800,  range=520},

    -- ============ 冲锋枪 8 种 ============
    {id="mp5",    name="MP5",      type="smg",damage=20, fireRate=13, magSize=30, reload=1.8, recoil=0.8, price=3500,  range=350},
    {id="uzi",    name="UZI",      type="smg",damage=18, fireRate=15, magSize=25, reload=1.7, recoil=0.9, price=3000,  range=320},
    {id="p90",    name="P90",      type="smg",damage=22, fireRate=14, magSize=50, reload=2.0, recoil=0.7, price=4200,  range=380},
    {id="vector", name="Vector",   type="smg",damage=21, fireRate=16, magSize=25, reload=1.9, recoil=0.6, price=4500,  range=350},
    {id="mp7",    name="MP7",      type="smg",damage=19, fireRate=15, magSize=40, reload=1.8, recoil=0.8, price=4000,  range=340},
    {id="mac10",  name="MAC-10",   type="smg",damage=17, fireRate=17, magSize=30, reload=1.6, recoil=1.0, price=2800,  range=300},
    {id="ump45",  name="UMP-45",   type="smg",damage=24, fireRate=11, magSize=25, reload=1.9, recoil=0.9, price=3800,  range=380},
    {id="thompson",name="汤普森",  type="smg",damage=23, fireRate=12, magSize=30, reload=2.2, recoil=1.1, price=3600,  range=350},

    -- ============ 狙击枪 6 种 ============
    {id="awp",    name="AWP",      type="sniper",damage=180,fireRate=0.8,magSize=5, reload=3.5, recoil=5.0, price=15000, range=1200},
    {id="barrett",name="巴雷特",   type="sniper",damage=250,fireRate=0.6,magSize=10,reload=4.5, recoil=6.5, price=22000, range=1500},
    {id="m24",    name="M24",      type="sniper",damage=160,fireRate=1.0,magSize=5, reload=3.2, recoil=4.5, price=12000, range=1000},
    {id="svd",    name="SVD",      type="sniper",damage=120,fireRate=1.5,magSize=10,reload=3.0, recoil=3.5, price=10000, range=900},
    {id="kar98",  name="Kar98k",   type="sniper",damage=170,fireRate=0.9,magSize=5, reload=3.3, recoil=4.8, price=13000, range=1100},
    {id="intervention",name="干预者",type="sniper",damage=200,fireRate=0.7,magSize=5,reload=3.8,recoil=5.5,price=18000,range=1300},

    -- ============ 手枪 8 种 ============
    {id="glock",  name="格洛克 17", type="pistol",damage=18,fireRate=8, magSize=17,reload=1.5,recoil=0.6, price=1200,  range=250},
    {id="deagle", name="沙漠之鹰",  type="pistol",damage=65,fireRate=3, magSize=7, reload=2.0,recoil=2.5, price=2500,  range=350},
    {id="usp",    name="USP",       type="pistol",damage=22,fireRate=7, magSize=12,reload=1.6,recoil=0.7, price=1500,  range=280},
    {id="revolver",name="左轮",     type="pistol",damage=75,fireRate=2, magSize=6, reload=2.4,recoil=3.0, price=3000,  range=380},
    {id="beretta",name="贝瑞塔 M9", type="pistol",damage=20,fireRate=8, magSize=15,reload=1.6,recoil=0.6, price=1300,  range=260},
    {id="five7",  name="FN Five-seveN",type="pistol",damage=24,fireRate=8,magSize=20,reload=1.7,recoil=0.6,price=1800,range=300},
    {id="p226",   name="P226",      type="pistol",damage=23,fireRate=8, magSize=15,reload=1.6,recoil=0.6, price=1400,  range=270},
    {id="p250",   name="P250",      type="pistol",damage=19,fireRate=7, magSize=13,reload=1.6,recoil=0.7, price=1000,  range=250},

    -- ============ 霰弹枪 5 种 ============
    {id="pump",   name="泵动式霰弹枪", type="shotgun",damage=45,fireRate=1.5,magSize=6, reload=2.8, recoil=3.0, price=4500, range=150},
    {id="semi_shot",name="半自动霰弹枪",type="shotgun",damage=35,fireRate=3,magSize=8,reload=3.0, recoil=2.5, price=5500, range=160},
    {id="double", name="双管霰弹枪",type="shotgun",damage=80,fireRate=1.0,magSize=2,reload=3.5, recoil=4.5, price=3200, range=140},
    {id="saiga",  name="Saiga-12", type="shotgun",damage=30,fireRate=4, magSize=8, reload=3.2, recoil=2.2, price=6500, range=150},
    {id="spas",   name="SPAS-12",  type="shotgun",damage=40,fireRate=2, magSize=8, reload=3.0, recoil=2.8, price=5000, range=155},

    -- ============ 机枪 4 种 ============
    {id="minigun",name="加特林",   type="lmg",damage=22,fireRate=25,magSize=200,reload=5.0, recoil=2.5, price=25000, range=400},
    {id="m249",   name="M249",     type="lmg",damage=32,fireRate=12,magSize=100,reload=4.5, recoil=2.0, price=14000, range=500},
    {id="pkm",    name="PKM",      type="lmg",damage=38,fireRate=11,magSize=100,reload=5.0, recoil=2.3, price=13000, range=520},
    {id="m60",    name="M60",      type="lmg",damage=40,fireRate=10,magSize=100,reload=5.5, recoil=2.4, price=12500, range=510},

    -- ============ 爆炸武器 4 种 ============
    {id="rpg",    name="火箭发射器",type="explosive",damage=250,fireRate=0.5,magSize=1,reload=5.0, recoil=8.0, price=35000, range=800},
    {id="grenade_launcher",name="榴弹发射器",type="explosive",damage=180,fireRate=1.5,magSize=6,reload=4.0,recoil=5.0, price=28000, range=600},
    {id="c4",     name="C4",       type="explosive",damage=400,fireRate=0.3,magSize=1,reload=6.0, recoil=0.0, price=8000,  range=30},
    {id="claymore",name="阔剑地雷",type="explosive",damage=300,fireRate=0.3,magSize=1,reload=5.0, recoil=0.0, price=6000,  range=20},

    -- ============ 特殊武器 5 种 ============
    {id="taser",  name="电击枪",   type="special",damage=15,fireRate=1, magSize=1, reload=3.0, recoil=0.5, price=4000,  range=150},
    {id="tranq",  name="麻醉枪",   type="special",damage=10,fireRate=1, magSize=1, reload=3.0, recoil=0.5, price=5500,  range=300},
    {id="flamer", name="火焰喷射器",type="special",damage=12,fireRate=20,magSize=200,reload=4.5,recoil=0.5, price=20000, range=100},
    {id="crossbow",name="十字弩",  type="special",damage=120,fireRate=1, magSize=1, reload=3.5, recoil=1.5, price=9000,  range=700},
    {id="railgun",name="电磁炮",   type="special",damage=350,fireRate=0.4,magSize=5,reload=5.0,recoil=4.0, price=45000, range=1500},
}

S.GunIndex = {}
for _, g in ipairs(S.GUNS) do S.GunIndex[g.id] = g end

-- ================== E2. 几何枪械模型生成器 ==================
-- 由于 Delta 环境不能加载外部模型，用几何拼装

local function makeGunModel(gunDef)
    local m = Instance.new("Model")
    m.Name = "Gun_"..gunDef.id

    local bodyColor = Color3.fromRGB(50,50,55)
    local accentColor = Color3.fromRGB(80,60,40)
    if gunDef.type == "sniper" then bodyColor = Color3.fromRGB(40,45,40)
    elseif gunDef.type == "explosive" then bodyColor = Color3.fromRGB(60,60,30)
    elseif gunDef.type == "special" then bodyColor = Color3.fromRGB(80,80,90) end

    -- 主体
    local len = 3
    if gunDef.type == "pistol" then len = 1.5
    elseif gunDef.type == "smg" then len = 2.2
    elseif gunDef.type == "ar" then len = 2.8
    elseif gunDef.type == "sniper" then len = 4
    elseif gunDef.type == "lmg" then len = 3.5
    elseif gunDef.type == "explosive" then len = 4
    end

    local body = Instance.new("Part")
    body.Size = Vector3.new(0.4, 0.5, len)
    body.Color = bodyColor
    body.Material = Enum.Material.Metal
    body.Name = "Body"
    body.Parent = m

    -- 枪管
    local barrel = Instance.new("Part")
    barrel.Shape = Enum.PartType.Cylinder
    barrel.Size = Vector3.new(len * 0.4, 0.25, 0.25)
    barrel.CFrame = CFrame.new(0, 0.1, -len/2 - len*0.2) * CFrame.Angles(0, math.rad(90), 0)
    barrel.Color = Color3.fromRGB(30,30,35)
    barrel.Material = Enum.Material.Metal
    barrel.Name = "Barrel"
    barrel.Parent = m

    -- 弹匣
    local mag = Instance.new("Part")
    mag.Size = Vector3.new(0.3, 0.8, 0.5)
    mag.Position = Vector3.new(0, -0.6, len * 0.1)
    mag.Color = accentColor
    mag.Material = Enum.Material.Metal
    mag.Name = "Magazine"
    mag.Parent = m

    -- 握把
    local grip = Instance.new("Part")
    grip.Size = Vector3.new(0.3, 0.7, 0.35)
    grip.Position = Vector3.new(0, -0.6, len * 0.3)
    grip.Color = accentColor
    grip.Material = Enum.Material.Wood
    grip.Name = "Grip"
    grip.Parent = m

    -- 瞄准镜（狙击枪 + 部分步枪）
    if gunDef.type == "sniper" or gunDef.type == "ar" then
        local scope = Instance.new("Part")
        scope.Shape = Enum.PartType.Cylinder
        scope.Size = Vector3.new(0.8, 0.3, 0.3)
        scope.CFrame = CFrame.new(0, 0.5, 0) * CFrame.Angles(0, math.rad(90), 0)
        scope.Color = Color3.fromRGB(25,25,30)
        scope.Material = Enum.Material.Metal
        scope.Name = "Scope"
        scope.Parent = m
    end

    -- 弹匣/弹鼓（LMG）
    if gunDef.type == "lmg" then
        local drum = Instance.new("Part")
        drum.Shape = Enum.PartType.Cylinder
        drum.Size = Vector3.new(0.7, 1.0, 1.0)
        drum.CFrame = CFrame.new(0, -0.8, 0) * CFrame.Angles(0, 0, math.rad(90))
        drum.Color = accentColor
        drum.Material = Enum.Material.Metal
        drum.Name = "Drum"
        drum.Parent = m
    end

    -- 爆炸武器特殊外观
    if gunDef.type == "explosive" then
        local tube = Instance.new("Part")
        tube.Shape = Enum.PartType.Cylinder
        tube.Size = Vector3.new(len * 0.9, 0.7, 0.7)
        tube.CFrame = CFrame.new(0, 0, -len * 0.1) * CFrame.Angles(0, math.rad(90), 0)
        tube.Color = Color3.fromRGB(50,60,40)
        tube.Material = Enum.Material.Metal
        tube.Name = "Tube"
        tube.Parent = m
    end

    -- 特殊武器外观差异
    if gunDef.id == "flamer" then
        local nozzle = Instance.new("Part")
        nozzle.Shape = Enum.PartType.Cylinder
        nozzle.Size = Vector3.new(1, 0.4, 0.4)
        nozzle.CFrame = CFrame.new(0, 0.1, -len/2 - 0.5) * CFrame.Angles(0, math.rad(90), 0)
        nozzle.Color = Color3.fromRGB(200,80,30)
        nozzle.Material = Enum.Material.Metal
        nozzle.Parent = m
    elseif gunDef.id == "railgun" then
        for i = -1, 1, 2 do
            local rail = Instance.new("Part")
            rail.Size = Vector3.new(0.15, 0.15, len)
            rail.Position = Vector3.new(i * 0.3, 0.15, 0)
            rail.Color = Color3.fromRGB(80,150,255)
            rail.Material = Enum.Material.Neon
            rail.Parent = m
        end
    elseif gunDef.id == "crossbow" then
        local bow = Instance.new("Part")
        bow.Size = Vector3.new(1.5, 0.15, 0.15)
        bow.Position = Vector3.new(0, 0, -len/2)
        bow.Color = Color3.fromRGB(60,40,20)
        bow.Material = Enum.Material.Wood
        bow.Parent = m
    end

    -- 主部件
    m.PrimaryPart = body
    return m
end

S.MakeGunModel = makeGunModel

-- ================== E3. 枪械店（3 家） ==================
local gunShopFolder = Instance.new("Folder")
gunShopFolder.Name = "GunShops"
gunShopFolder.Parent = cityFolder

local function buildGunShop(pos, shopName, tier)
    -- 建筑主体
    local body = newPart(gunShopFolder, Vector3.new(30, 12, 24),
        CFrame.new(pos + Vector3.new(0, 6, 0)), Color3.fromRGB(60,55,50), Enum.Material.Concrete)

    -- 招牌
    local sign = newPart(gunShopFolder, Vector3.new(24, 3, 0.4),
        CFrame.new(pos + Vector3.new(0, 13, -12.2)),
        Color3.fromRGB(160,40,40), Enum.Material.Neon)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(500, 80)
    sg.Parent = sign
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1,1)
    tl.BackgroundTransparency = 1
    tl.Text = "🔫 " .. shopName
    tl.TextColor3 = Color3.fromRGB(255,255,255)
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.TextStrokeTransparency = 0
    tl.Parent = sg

    -- 门
    makeHingedDoor(gunShopFolder, pos + Vector3.new(0, 0, -12), Vector3.new(4, 6, 0.3),
        Color3.fromRGB(150,200,230), Enum.Material.Glass, math.rad(90))

    -- 内部
    S.BuildFloor(gunShopFolder, pos, 28, 22, 0.6, Color3.fromRGB(120,110,100), Enum.Material.Concrete)
    S.BuildCeiling(gunShopFolder, pos, 28, 22, 10, Color3.fromRGB(180,180,190))
    for i = 1, 3 do
        S.BuildFluorescent(gunShopFolder, pos + Vector3.new(-8 + (i-1)*8, 9, 0), 4)
    end

    -- 展示柜（3 排）
    for row = 1, 3 do
        local cabinet = newPart(gunShopFolder, Vector3.new(12, 3, 2),
            CFrame.new(pos + Vector3.new(0, 2, -6 + row * 4)), Color3.fromRGB(80,70,60), Enum.Material.Wood)
        cabinet.CanCollide = false
        -- 玻璃顶
        local glass = newPart(gunShopFolder, Vector3.new(12, 0.2, 2),
            CFrame.new(pos + Vector3.new(0, 3.5, -6 + row * 4)), Color3.fromRGB(200,220,240), Enum.Material.Glass)
        glass.Transparency = 0.5
        glass.CanCollide = false
    end

    -- 收银台
    S.BuildCashier(gunShopFolder, pos + Vector3.new(8, 0, 8))

    -- 靶场（后墙）
    local targetBase = newPart(gunShopFolder, Vector3.new(20, 8, 0.5),
        CFrame.new(pos + Vector3.new(0, 4, 11)), Color3.fromRGB(100,100,110), Enum.Material.Concrete)
    -- 靶子
    for i = 1, 3 do
        local target = newPart(gunShopFolder, Vector3.new(2, 2, 0.2),
            CFrame.new(pos + Vector3.new(-6 + i*6, 5, 10.5)), Color3.fromRGB(255,240,230), Enum.Material.SmoothPlastic)
        target.Name = "Target"
        target:SetAttribute("IsTarget", true)
        -- 靶心
        newPart(gunShopFolder, Vector3.new(0.6, 0.6, 0.1),
            CFrame.new(pos + Vector3.new(-6 + i*6, 5, 10.3)), Color3.fromRGB(220,40,40), Enum.Material.SmoothPlastic)
    end

    return { pos = pos, tier = tier, name = shopName }
end

local gunShops = {}
table.insert(gunShops, buildGunShop(Vector3.new(3200, 3, 2000), "洛圣都枪械店", 1))
table.insert(gunShops, buildGunShop(Vector3.new(2000, 3, 3000), "市中心武器行", 2))
table.insert(gunShops, buildGunShop(Vector3.new(1000, 3, 2000), "黑市军火", 3))

S.AddPlaceIcon("枪店1", Vector3.new(3200,5,2000), Color3.fromRGB(255,100,100))
S.AddPlaceIcon("枪店2", Vector3.new(2000,5,3000), Color3.fromRGB(255,100,100))
S.AddPlaceIcon("枪店3", Vector3.new(1000,5,2000), Color3.fromRGB(255,100,100))

-- ================== E4. 枪械店购买 UI ==================
local gunShopUI = Instance.new("Frame")
gunShopUI.Name = "GunShopUI"
gunShopUI.Size = UDim2.fromScale(0.85, 0.7)
gunShopUI.Position = UDim2.fromScale(0.075, 0.15)
gunShopUI.Visible = false
gunShopUI.ZIndex = 80
gunShopUI.Parent = gui
applyGlass(gunShopUI, 24, 0.6, Color3.fromRGB(24,28,38))

local gsTitle = Instance.new("TextLabel")
gsTitle.Size = UDim2.fromScale(0.85, 0.06)
gsTitle.Position = UDim2.fromScale(0.05, 0.02)
gsTitle.BackgroundTransparency = 1
gsTitle.Text = "🔫 枪械店"
gsTitle.TextColor3 = Color3.fromRGB(240,245,255)
gsTitle.TextScaled = true
gsTitle.Font = Enum.Font.GothamBold
gsTitle.ZIndex = 81
gsTitle.Parent = gunShopUI

local gsClose = mkButton(gunShopUI, "✕", UDim2.fromScale(0.08, 0.055),
    UDim2.fromScale(0.88, 0.015), 0, Color3.fromRGB(120,50,50))
gsClose.ZIndex = 82
gsClose.Activated:Connect(function() gunShopUI.Visible = false end)

-- 分类标签
local gsTabs = Instance.new("Frame")
gsTabs.Size = UDim2.fromScale(0.9, 0.06)
gsTabs.Position = UDim2.fromScale(0.05, 0.09)
gsTabs.BackgroundTransparency = 1
gsTabs.ZIndex = 81
gsTabs.Parent = gunShopUI
local gsTabsLayout = Instance.new("UIListLayout")
gsTabsLayout.FillDirection = Enum.FillDirection.Horizontal
gsTabsLayout.Padding = UDim.new(0, 4)
gsTabsLayout.Parent = gsTabs

-- 枪械列表
local gsList = Instance.new("ScrollingFrame")
gsList.Size = UDim2.fromScale(0.9, 0.68)
gsList.Position = UDim2.fromScale(0.05, 0.17)
gsList.BackgroundTransparency = 1
gsList.BorderSizePixel = 0
gsList.ScrollBarThickness = 4
gsList.CanvasSize = UDim2.new(0,0,0,0)
gsList.AutomaticCanvasSize = Enum.AutomaticSize.Y
gsList.ClipsDescendants = true
gsList.ZIndex = 81
gsList.Parent = gunShopUI
local gsListLayout = Instance.new("UIListLayout")
gsListLayout.Padding = UDim.new(0,4)
gsListLayout.SortOrder = Enum.SortOrder.LayoutOrder
gsListLayout.Parent = gsList

-- 玩家背包
S.Inventory = S.Inventory or {}
S.EquippedGun = S.EquippedGun or nil

local function refreshGunList(filter)
    for _, c in ipairs(gsList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local order = 0
    for _, g in ipairs(S.GUNS) do
        if not filter or g.type == filter then
            order = order + 1
            local owned = S.Inventory[g.id]
            local text = string.format("%s  [%s]  伤害%d  弹匣%d  射速%.1f  $%d%s",
                g.name, g.type, g.damage, g.magSize, g.fireRate, g.price,
                owned and "  ✅已拥有" or "")
            local btn = mkButton(gsList, text, UDim2.new(1,-8,0,36), UDim2.fromOffset(4,0), order,
                owned and Color3.fromRGB(50,100,60) or Color3.fromRGB(50,60,80))
            btn.ZIndex = 82
            btn.Activated:Connect(function()
                if owned then
                    S.EquippedGun = g.id
                    S.Notify("已装备 "..g.name, Color3.fromRGB(120,220,160))
                    if S.UpdateGunHUD then S.UpdateGunHUD() end
                else
                    if S.Money < g.price then
                        S.Notify("金钱不足，需要 $"..g.price, Color3.fromRGB(255,120,120))
                        return
                    end
                    S.AddMoney(-g.price)
                    S.Inventory[g.id] = true
                    S.EquippedGun = g.id
                    S.Notify("购买并装备 "..g.name, Color3.fromRGB(120,220,160))
                    refreshGunList(filter)
                    if S.UpdateGunHUD then S.UpdateGunHUD() end
                end
            end)
        end
    end
end

local categories = {
    {key=nil,       label="全部"},
    {key="ar",      label="突击"},
    {key="smg",     label="冲锋"},
    {key="sniper",  label="狙击"},
    {key="pistol",  label="手枪"},
    {key="shotgun", label="霰弹"},
    {key="lmg",     label="机枪"},
    {key="explosive",label="爆炸"},
    {key="special", label="特殊"},
}
for i, cat in ipairs(categories) do
    local tb = mkButton(gsTabs, cat.label, UDim2.fromScale(0.105, 1), UDim2.fromScale(0,0), i,
        Color3.fromRGB(60,80,120))
    tb.ZIndex = 82
    tb.Activated:Connect(function()
        refreshGunList(cat.key)
    end)
end

-- 打开枪店
function S.OpenGunShop()
    gunShopUI.Visible = true
    refreshGunList(nil)
end

-- 注册 3 家枪店交互点
for i, shop in ipairs(gunShops) do
    local interactPos = shop.pos + Vector3.new(0, 3, -14)
    S.RegisterPoint("gunshop_"..i, interactPos, "进入枪店", shop.name, function()
        S.OpenGunShop()
    end)
end

-- ================== E5. 准心 + 射击系统 ==================
-- 准心（屏幕中心）
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.Size = UDim2.fromOffset(30, 30)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.BackgroundTransparency = 1
crosshair.ZIndex = 100
crosshair.Visible = false
crosshair.Parent = gui

-- 四根准心线
for _, dir in ipairs({
    {x=0, y=-1}, {x=0, y=1}, {x=-1, y=0}, {x=1, y=0},
}) do
    local line = Instance.new("Frame")
    line.Size = dir.x ~= 0 and UDim2.fromOffset(10, 2) or UDim2.fromOffset(2, 10)
    line.AnchorPoint = Vector2.new(0.5, 0.5)
    line.Position = UDim2.new(0.5, dir.x * 10, 0.5, dir.y * 10)
    line.BackgroundColor3 = Color3.fromRGB(80,255,80)
    line.BorderSizePixel = 0
    line.ZIndex = 101
    line.Parent = crosshair
end

local crosshairDot = Instance.new("Frame")
crosshairDot.Size = UDim2.fromOffset(2,2)
crosshairDot.AnchorPoint = Vector2.new(0.5,0.5)
crosshairDot.Position = UDim2.fromScale(0.5,0.5)
crosshairDot.BackgroundColor3 = Color3.fromRGB(255,255,255)
crosshairDot.BorderSizePixel = 0
crosshairDot.ZIndex = 101
crosshairDot.Parent = crosshair

-- 枪械 HUD（右下角）
local gunHUD = Instance.new("Frame")
gunHUD.Name = "GunHUD"
gunHUD.Size = UDim2.fromScale(0.26, 0.09)
gunHUD.Position = UDim2.new(0.72, 0, 0.88, 0)
gunHUD.BackgroundTransparency = 1
gunHUD.ZIndex = 60
gunHUD.Visible = false
gunHUD.Parent = gui

local gunNameLbl = Instance.new("TextLabel")
gunNameLbl.Size = UDim2.fromScale(1, 0.4)
gunNameLbl.BackgroundTransparency = 1
gunNameLbl.Text = ""
gunNameLbl.TextColor3 = Color3.fromRGB(240,240,255)
gunNameLbl.TextScaled = true
gunNameLbl.Font = Enum.Font.GothamBold
gunNameLbl.TextStrokeTransparency = 0.3
gunNameLbl.ZIndex = 61
gunNameLbl.Parent = gunHUD

local ammoLbl = Instance.new("TextLabel")
ammoLbl.Size = UDim2.fromScale(1, 0.6)
ammoLbl.Position = UDim2.fromScale(0, 0.4)
ammoLbl.BackgroundTransparency = 1
ammoLbl.Text = "30 / 30"
ammoLbl.TextColor3 = Color3.fromRGB(255,220,120)
ammoLbl.TextScaled = true
ammoLbl.Font = Enum.Font.GothamBold
ammoLbl.TextStrokeTransparency = 0.3
ammoLbl.ZIndex = 61
ammoLbl.Parent = gunHUD

S.CurrentAmmo = 0
S.MaxAmmo = 0
S.IsReloading = false
S.LastShotTime = 0

function S.UpdateGunHUD()
    if not S.EquippedGun then
        gunHUD.Visible = false
        crosshair.Visible = false
        return
    end
    local g = S.GunIndex[S.EquippedGun]
    if not g then gunHUD.Visible = false; crosshair.Visible = false; return end
    gunHUD.Visible = true
    crosshair.Visible = true
    gunNameLbl.Text = g.name
    S.MaxAmmo = g.magSize
    if S.CurrentAmmo == 0 or S.CurrentAmmo > S.MaxAmmo then S.CurrentAmmo = S.MaxAmmo end
    ammoLbl.Text = string.format("%d / %d", S.CurrentAmmo, S.MaxAmmo)
end

-- 换弹按钮（屏幕右侧）
local reloadBtn = mkButton(gui, "🔄 换弹", UDim2.fromScale(0.14,0.055),
    UDim2.new(0.84, 0, 0.84, 0), 0, Color3.fromRGB(80,80,100))
reloadBtn.Visible = false
reloadBtn.Activated:Connect(function()
    if not S.EquippedGun or S.IsReloading then return end
    S.IsReloading = true
    S.Notify("换弹中…", Color3.fromRGB(255,220,120))
    local g = S.GunIndex[S.EquippedGun]
    task.wait(g.reload)
    S.CurrentAmmo = g.magSize
    S.IsReloading = false
    S.UpdateGunHUD()
end)

-- 开镜按钮
local adsBtn = mkButton(gui, "🔭 开镜", UDim2.fromScale(0.14,0.055),
    UDim2.new(0.84, 0, 0.775, 0), 0, Color3.fromRGB(80,80,100))
adsBtn.Visible = false
S.IsADS = false
adsBtn.Activated:Connect(function()
    S.IsADS = not S.IsADS
    local cam = workspace.CurrentCamera
    if S.IsADS then
        cam.FieldOfView = 30
    else
        cam.FieldOfView = 70
    end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(0.2)
        if S.EquippedGun then
            reloadBtn.Visible = true
            adsBtn.Visible = true
        else
            reloadBtn.Visible = false
            adsBtn.Visible = false
        end
    end
end)

-- ================== E6. 子弹与弹孔 ==================
local bulletFolder = Instance.new("Folder")
bulletFolder.Name = "Bullets"
bulletFolder.Parent = cityFolder

local function makeBulletHole(pos, normal)
    local hole = Instance.new("Part")
    hole.Size = Vector3.new(0.4, 0.4, 0.1)
    hole.CFrame = CFrame.new(pos, pos + normal) * CFrame.Angles(0, 0, math.random() * math.pi * 2)
    hole.Color = Color3.fromRGB(20,20,20)
    hole.Material = Enum.Material.SmoothPlastic
    hole.Anchored = true
    hole.CanCollide = false
    hole.Parent = bulletFolder
    -- 5 秒后消失
    task.delay(5, function() if hole.Parent then hole:Destroy() end end)
end

local function makeMuzzleFlash(origin, dir)
    local flash = Instance.new("Part")
    flash.Shape = Enum.PartType.Ball
    flash.Size = Vector3.new(1.2, 1.2, 1.2)
    flash.Position = origin + dir * 2
    flash.Color = Color3.fromRGB(255,220,100)
    flash.Material = Enum.Material.Neon
    flash.Anchored = true
    flash.CanCollide = false
    flash.Parent = bulletFolder
    local light = Instance.new("PointLight")
    light.Range = 12
    light.Brightness = 3
    light.Parent = flash
    task.delay(0.05, function() if flash.Parent then flash:Destroy() end end)
end

local function makeShellEffect(origin)
    local shell = Instance.new("Part")
    shell.Size = Vector3.new(0.15, 0.15, 0.3)
    shell.Position = origin
    shell.Color = Color3.fromRGB(200,160,80)
    shell.Material = Enum.Material.Metal
    shell.Anchored = false
    shell.CanCollide = false
    shell.Parent = bulletFolder
    shell.Velocity = Vector3.new(math.random(-10,10), math.random(5,10), math.random(-10,10))
    task.delay(2, function() if shell.Parent then shell:Destroy() end end)
end

-- ================== E7. 射击主逻辑 ==================
local function getMouseHit()
    local cam = workspace.CurrentCamera
    local mouse = LocalPlayer:GetMouse()
    local screenPos
    if UserInputService.TouchEnabled then
        screenPos = Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
    else
        screenPos = Vector2.new(mouse.X, mouse.Y)
    end

    local ray = cam:ViewportPointToRay(screenPos.X, screenPos.Y)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character, cityFolder }
    local result = workspace:Raycast(ray.Origin, ray.Direction * 2000, params)
    return result, ray
end

local function showDamageNumber(worldPos, dmg, isCrit)
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.1,0.1,0.1)
    part.Transparency = 1
    part.Anchored = true
    part.CanCollide = false
    part.Position = worldPos
    part.Parent = bulletFolder

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(100, 40)
    bb.StudsOffset = Vector3.new(0, 1, 0)
    bb.AlwaysOnTop = true
    bb.Parent = part
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1,1)
    tl.BackgroundTransparency = 1
    tl.Text = tostring(math.floor(dmg))
    tl.TextColor3 = isCrit and Color3.fromRGB(255,220,60) or Color3.fromRGB(255,80,80)
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.TextStrokeTransparency = 0.3
    tl.Parent = bb

    task.spawn(function()
        local startY = part.Position.Y
        for i = 1, 15 do
            task.wait(0.03)
            part.Position = part.Position + Vector3.new(0, 0.15, 0)
            tl.TextTransparency = i / 15
        end
        part:Destroy()
    end)
end

local function fireOnce()
    if not S.EquippedGun or S.IsReloading then return end
    local g = S.GunIndex[S.EquippedGun]
    if not g then return end

    local now = tick()
    if now - S.LastShotTime < 1 / g.fireRate then return end
    S.LastShotTime = now

    if S.CurrentAmmo <= 0 then
        S.Notify("弹匣空，请换弹", Color3.fromRGB(255,180,120))
        return
    end
    S.CurrentAmmo = S.CurrentAmmo - 1
    S.UpdateGunHUD()

    -- 获取枪口位置
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local origin = hrp.Position + Vector3.new(0, 1.5, 0)
    local hit, ray = getMouseHit()
    local dir = ray.Direction

    -- 枪口火焰 + 弹壳
    makeMuzzleFlash(origin, dir.Unit)
    makeShellEffect(origin + dir.Unit * 1)

    -- 射线检测
    if hit then
        makeBulletHole(hit.Position, hit.Normal)
        local dmg = g.damage
        local isCrit = math.random() < 0.15
        if isCrit then dmg = dmg * 1.5 end
        showDamageNumber(hit.Position, dmg, isCrit)

        -- 命中目标（靶子/靶心）
        if hit.Instance:GetAttribute("IsTarget") then
            S.Notify("命中靶心！"..math.floor(dmg).." 伤害", Color3.fromRGB(120,220,160))
        end

        -- 命中 NPC（这里 NPC 是客户端生成的，可以被"击中"——只是视觉反馈）
        local npcModel
        local parent = hit.Instance
        while parent and parent ~= workspace do
            if parent:IsA("Model") and parent:FindFirstChildOfClass("Humanoid") then
                npcModel = parent
                break
            end
            parent = parent.Parent
        end
        if npcModel then
            local hum = npcModel:FindFirstChildOfClass("Humanoid")
            if hum then
                hum:TakeDamage(dmg)
            end
        end
    end

    -- 后坐力（相机抖动）
    local cam = workspace.CurrentCamera
    local recoilX = math.rad(math.random(-g.recoil, g.recoil) * 0.4)
    local recoilY = math.rad(math.random(-g.recoil, g.recoil) * 0.4)
    local origCF = cam.CFrame
    cam.CFrame = origCF * CFrame.Angles(recoilX, recoilY, 0)
    task.spawn(function()
        task.wait(0.08)
        if cam then cam.CFrame = origCF end
    end)

    -- 准心闪烁
    crosshairDot.BackgroundColor3 = Color3.fromRGB(255,100,100)
    task.delay(0.1, function()
        crosshairDot.BackgroundColor3 = Color3.fromRGB(255,255,255)
    end)
end

-- ================== E8. 触摸/鼠标点击射击 ==================
-- 手机：屏幕右下"射击"大按钮
local fireBtn = mkButton(gui, "🔥 射击", UDim2.fromScale(0.18, 0.08),
    UDim2.new(0.80, 0, 0.70, 0), 0, Color3.fromRGB(200,60,60))
fireBtn.Visible = false
S.Firing = false

fireBtn.MouseButton1Down:Connect(function()
    S.Firing = true
end)
fireBtn.MouseButton1Up:Connect(function()
    S.Firing = false
end)
fireBtn.MouseLeave:Connect(function()
    S.Firing = false
end)
fireBtn.TouchLongPress:Connect(function()
    S.Firing = true
end)

task.spawn(function()
    while gui.Parent do
        task.wait(0.05)
        if S.Firing and S.EquippedGun then
            fireOnce()
        end
    end
end)

task.spawn(function()
    while gui.Parent do
        task.wait(0.3)
        fireBtn.Visible = S.EquippedGun ~= nil
    end
end)

-- PC：鼠标左键
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 and not UserInputService.TouchEnabled then
        if S.EquippedGun then fireOnce() end
    end
end)

-- 键盘 R 换弹
UserInputService.InputBegan:Connect(function(input, gp)
    if gp then return end
    if input.KeyCode == Enum.KeyCode.R and S.EquippedGun and not S.IsReloading then
        S.IsReloading = true
        local g = S.GunIndex[S.EquippedGun]
        task.wait(g.reload)
        S.CurrentAmmo = g.magSize
        S.IsReloading = false
        S.UpdateGunHUD()
    end
    -- 右键开镜
    if input.UserInputType == Enum.UserInputType.MouseButton2 and S.EquippedGun then
        S.IsADS = not S.IsADS
        workspace.CurrentCamera.FieldOfView = S.IsADS and 30 or 70
    end
end)

-- ================== E9. 靶场练习 ==================
-- 已在 E3 生成过靶子，这里再加一个"无限靶场"传送点
S.RegisterPoint("range_teleport", Vector3.new(2000, 3, 3040),
    "进入靶场", "练习射击", function()
        local char = LocalPlayer.Character
        if char and char:FindFirstChild("HumanoidRootPart") then
            char.HumanoidRootPart.CFrame = CFrame.new(2000, 5, 3060)
            S.Notify("已进入靶场（枪店2后墙）", Color3.fromRGB(120,220,160))
        end
    end)

S.Notify("Part 3E 加载完成：3 枪店 / 50 枪 / 完整射击系统", Color3.fromRGB(120,220,160))
print("[IncSim] Part 3E 加载完成")
--[[
=====================================================================
  Part 3F：超市 / 货架商品 / 购物车 / 收银员 / 结算 / 背包
  接在 Part 3E 末尾
=====================================================================
]]

-- ================== F1. 商品数据表 ==================
-- category: food 食物 / drink 饮料 / daily 日用品 / medicine 药品
-- effect: { hunger=X } 或 { thirst=X } 或 { health=X }
S.PRODUCTS = {
    -- ============ 食物 ============
    {id="bread",    name="面包",     category="food", price=15,  effect={hunger=15}, color=Color3.fromRGB(200,160,100)},
    {id="burger",   name="汉堡",     category="food", price=35,  effect={hunger=30}, color=Color3.fromRGB(180,120,60)},
    {id="pizza",    name="披萨",     category="food", price=45,  effect={hunger=40}, color=Color3.fromRGB(220,180,80)},
    {id="sushi",    name="寿司",     category="food", price=55,  effect={hunger=35}, color=Color3.fromRGB(240,240,240)},
    {id="apple",    name="苹果",     category="food", price=8,   effect={hunger=10}, color=Color3.fromRGB(220,50,50)},
    {id="banana",   name="香蕉",     category="food", price=10,  effect={hunger=12}, color=Color3.fromRGB(240,220,80)},
    {id="salad",    name="蔬菜沙拉", category="food", price=25,  effect={hunger=20}, color=Color3.fromRGB(100,180,80)},
    {id="steak",    name="牛排",     category="food", price=90,  effect={hunger=60}, color=Color3.fromRGB(140,60,50)},

    -- ============ 饮料 ============
    {id="water",    name="矿泉水",   category="drink", price=5,   effect={thirst=25}, color=Color3.fromRGB(180,220,255)},
    {id="cola",     name="可乐",     category="drink", price=8,   effect={thirst=20}, color=Color3.fromRGB(80,30,20)},
    {id="juice",    name="果汁",     category="drink", price=12,  effect={thirst=25}, color=Color3.fromRGB(255,150,60)},
    {id="coffee",   name="咖啡",     category="drink", price=15,  effect={thirst=15, health=5}, color=Color3.fromRGB(70,40,20)},
    {id="energy",   name="能量饮料", category="drink", price=25,  effect={thirst=30, health=10}, color=Color3.fromRGB(80,220,120)},
    {id="milk",     name="牛奶",     category="drink", price=10,  effect={thirst=20, hunger=5}, color=Color3.fromRGB(250,250,250)},

    -- ============ 日用品 ============
    {id="soap",     name="肥皂",     category="daily", price=6,   effect={}, color=Color3.fromRGB(230,200,150)},
    {id="toothpaste",name="牙膏",    category="daily", price=8,   effect={}, color=Color3.fromRGB(180,220,255)},
    {id="tissue",   name="纸巾",     category="daily", price=4,   effect={}, color=Color3.fromRGB(250,250,250)},
    {id="towel",    name="毛巾",     category="daily", price=12,  effect={}, color=Color3.fromRGB(200,180,220)},

    -- ============ 药品 ============
    {id="bandaid",  name="创可贴",   category="medicine", price=10,  effect={health=10}, color=Color3.fromRGB(240,200,180)},
    {id="painkiller",name="止痛药",  category="medicine", price=30,  effect={health=25}, color=Color3.fromRGB(240,240,240)},
    {id="firstaid", name="急救包",   category="medicine", price=80,  effect={health=60}, color=Color3.fromRGB(220,40,40)},
    {id="antibiotic",name="抗生素",  category="medicine", price=50,  effect={health=40}, color=Color3.fromRGB(150,200,220)},
}

S.ProductIndex = {}
for _, p in ipairs(S.PRODUCTS) do S.ProductIndex[p.id] = p end

-- ================== F2. 超市建筑生成器 ==================
local supermarketFolder = Instance.new("Folder")
supermarketFolder.Name = "Supermarkets"
supermarketFolder.Parent = cityFolder

-- 生成一个商品模型（简单几何）
local function makeProductModel(parent, product, pos)
    local p = Instance.new("Part")
    p.Size = Vector3.new(0.6, 0.8, 0.6)
    p.Position = pos + Vector3.new(0, 0.4, 0)
    p.Color = product.color
    p.Material = Enum.Material.SmoothPlastic
    p.Anchored = true
    p.CanCollide = false
    p.Parent = parent
    p.Name = "Product_"..product.id
    p:SetAttribute("ProductId", product.id)
    p:SetAttribute("ProductName", product.name)
    p:SetAttribute("ProductPrice", product.price)

    -- 用 ClickDetector 也能用，但为了手机端我用 ProximityPrompt
    local prompt = Instance.new("ProximityPrompt")
    prompt.ActionText = "加入购物车"
    prompt.ObjectText = product.name .. " $" .. product.price
    prompt.MaxActivationDistance = 10
    prompt.RequiresLineOfSight = false
    prompt.HoldDuration = 0
    prompt.Parent = p

    prompt.Triggered:Connect(function(player)
        if player == LocalPlayer then
            S.AddToCart(product.id)
        end
    end)

    return p
end

-- 生成货架 + 商品
local function buildShelfWithProducts(parent, shelfPos, shelfSize, products, facing)
    -- 货架
    local shelf = newPart(parent, shelfSize, CFrame.new(shelfPos + Vector3.new(0, shelfSize.Y/2, 0)),
        Color3.fromRGB(140,120,100), Enum.Material.Wood)

    -- 层板
    for i = 1, 3 do
        local y = (shelfSize.Y / 4) * i
        newPart(parent, Vector3.new(shelfSize.X, 0.2, shelfSize.Z),
            CFrame.new(shelfPos + Vector3.new(0, y, 0)),
            Color3.fromRGB(100,80,60), Enum.Material.Wood)
    end

    -- 商品摆到层板上
    local cols = math.max(2, math.floor(shelfSize.X / 1.5))
    local productIdx = 1
    for layer = 1, 3 do
        local y = (shelfSize.Y / 4) * layer + 0.5
        for col = 1, cols do
            if productIdx > #products then break end
            local x = shelfPos.X - shelfSize.X/2 + 0.8 + (col-1) * 1.5
            local z = shelfPos.Z
            local p = products[productIdx]
            makeProductModel(parent, p, Vector3.new(x, y, z))
            productIdx = productIdx + 1
        end
    end
end

-- 分类商品
local catFood = {}
local catDrink = {}
local catDaily = {}
local catMedicine = {}
for _, p in ipairs(S.PRODUCTS) do
    if p.category == "food" then table.insert(catFood, p)
    elseif p.category == "drink" then table.insert(catDrink, p)
    elseif p.category == "daily" then table.insert(catDaily, p)
    elseif p.category == "medicine" then table.insert(catMedicine, p) end
end

-- 构建一个超市
local function buildSupermarket(pos, name)
    local parent = supermarketFolder

    -- 建筑外壳
    newPart(parent, Vector3.new(60, 12, 40),
        CFrame.new(pos + Vector3.new(0, 6, 0)),
        Color3.fromRGB(200,200,210), Enum.Material.Concrete)
    -- 屋顶
    newPart(parent, Vector3.new(62, 1, 42),
        CFrame.new(pos + Vector3.new(0, 12.5, 0)),
        Color3.fromRGB(80,80,90), Enum.Material.Slate)
    -- 玻璃门（正面）
    makeHingedDoor(parent, pos + Vector3.new(0, 0, -20.3), Vector3.new(6, 6, 0.3),
        Color3.fromRGB(180,210,230), Enum.Material.Glass, math.rad(90))

    -- 招牌
    local sign = newPart(parent, Vector3.new(50, 3, 0.5),
        CFrame.new(pos + Vector3.new(0, 13.5, -20.5)),
        Color3.fromRGB(60,160,90), Enum.Material.Neon)
    local sg = Instance.new("SurfaceGui")
    sg.Face = Enum.NormalId.Front
    sg.CanvasSize = Vector2.new(800, 100)
    sg.Parent = sign
    local tl = Instance.new("TextLabel")
    tl.Size = UDim2.fromScale(1,1)
    tl.BackgroundTransparency = 1
    tl.Text = "🛒 " .. name
    tl.TextColor3 = Color3.fromRGB(255,255,255)
    tl.TextScaled = true
    tl.Font = Enum.Font.GothamBold
    tl.TextStrokeTransparency = 0.3
    tl.Parent = sg

    -- 内部地板
    S.BuildFloor(parent, pos, 58, 38, 0.6, Color3.fromRGB(240,240,245), Enum.Material.Tile)
    -- 天花板
    S.BuildCeiling(parent, pos, 58, 38, 10, Color3.fromRGB(250,250,255))

    -- 灯
    for i = 1, 4 do
        for j = 1, 2 do
            S.BuildFluorescent(parent,
                pos + Vector3.new(-20 + (i-1)*13, 9.5, -10 + (j-1)*20), 5)
        end
    end

    -- 分区货架（4 类）
    -- 食品区（左前）
    buildShelfWithProducts(parent, pos + Vector3.new(-18, 0, -10),
        Vector3.new(12, 6, 3), catFood)
    buildShelfWithProducts(parent, pos + Vector3.new(-18, 0, -4),
        Vector3.new(12, 6, 3), catFood)

    -- 饮料区（右前）
    buildShelfWithProducts(parent, pos + Vector3.new(18, 0, -10),
        Vector3.new(12, 6, 3), catDrink)
    buildShelfWithProducts(parent, pos + Vector3.new(18, 0, -4),
        Vector3.new(12, 6, 3), catDrink)

    -- 日用品区（左后）
    buildShelfWithProducts(parent, pos + Vector3.new(-18, 0, 5),
        Vector3.new(12, 6, 3), catDaily)
    buildShelfWithProducts(parent, pos + Vector3.new(-18, 0, 11),
        Vector3.new(12, 6, 3), catDaily)

    -- 药品区（右后）
    buildShelfWithProducts(parent, pos + Vector3.new(18, 0, 5),
        Vector3.new(12, 6, 3), catMedicine)
    buildShelfWithProducts(parent, pos + Vector3.new(18, 0, 11),
        Vector3.new(12, 6, 3), catMedicine)

    -- 冰柜（靠后墙）
    S.BuildFridge(parent, pos + Vector3.new(-8, 0, 16), Vector3.new(4, 6, 3))
    S.BuildFridge(parent, pos + Vector3.new(-3, 0, 16), Vector3.new(4, 6, 3))
    S.BuildFridge(parent, pos + Vector3.new( 2, 0, 16), Vector3.new(4, 6, 3))

    -- 收银台（正面）
    S.BuildCashier(parent, pos + Vector3.new(0, 0, -15))

    -- 收银员 NPC
    local clerk = Instance.new("Model")
    clerk.Name = "Cashier"
    local torso = Instance.new("Part")
    torso.Name = "Torso"
    torso.Size = Vector3.new(2, 2, 1)
    torso.Color = Color3.fromRGB(60,140,90)
    torso.CFrame = CFrame.new(pos + Vector3.new(0, 3.5, -13))
    torso.Anchored = true
    torso.Parent = clerk
    local head = Instance.new("Part")
    head.Name = "Head"
    head.Shape = Enum.PartType.Ball
    head.Size = Vector3.new(1.6,1.6,1.6)
    head.Color = Color3.fromRGB(255,220,180)
    head.Position = torso.Position + Vector3.new(0, 1.8, 0)
    head.Anchored = true
    head.Parent = clerk
    clerk.PrimaryPart = torso
    clerk.Parent = parent

    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.fromOffset(160, 30)
    bb.StudsOffset = Vector3.new(0, 3, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head
    local tl2 = Instance.new("TextLabel")
    tl2.Size = UDim2.fromScale(1,1)
    tl2.BackgroundTransparency = 1
    tl2.Text = "收银员 · 点我结算"
    tl2.TextColor3 = Color3.fromRGB(255,255,200)
    tl2.TextScaled = true
    tl2.Font = Enum.Font.GothamBold
    tl2.Parent = bb

    -- 收银员交互
    local cashierPos = torso.Position
    S.RegisterPoint("supermarket_cashier_"..name, cashierPos,
        "结算购物车", name, function()
            S.OpenCheckout()
        end)

    -- 记录超市中心位置
    return {
        pos = pos, name = name, center = pos,
        enterPos = pos + Vector3.new(0, 3, -22),  -- 门口外侧
        exitPos  = pos + Vector3.new(0, 3,  22),  -- 后门外侧
    }
end

-- 生成 2 家超市
local supermarkets = {}
table.insert(supermarkets, buildSupermarket(Vector3.new(1200, 3, 1200), "便利店"))
table.insert(supermarkets, buildSupermarket(Vector3.new(3800, 3, 2200), "大型超市"))

S.Supermarkets = supermarkets

-- 小地图标记
for _, sm in ipairs(supermarkets) do
    S.AddPlaceIcon("超市_"..sm.name, sm.pos + Vector3.new(0,5,0), Color3.fromRGB(80,220,140))
end

-- ================== F3. 购物车数据 ==================
S.Cart = S.Cart or {}    -- { [productId] = count }
S.Inventory = S.Inventory or {}

function S.AddToCart(productId)
    local product = S.ProductIndex[productId]
    if not product then return end
    S.Cart[productId] = (S.Cart[productId] or 0) + 1
    S.Notify("已加入购物车："..product.name, Color3.fromRGB(120,220,160))
    if S.RefreshCartUI then S.RefreshCartUI() end

    -- 音效（用 Roblox 内置）
    pcall(function()
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://6042053626"
        s.Volume = 0.5
        s.Parent = game:GetService("SoundService")
        s:Play()
        task.delay(1, function() s:Destroy() end)
    end)
end

function S.RemoveFromCart(productId)
    if not S.Cart[productId] then return end
    S.Cart[productId] = S.Cart[productId] - 1
    if S.Cart[productId] <= 0 then S.Cart[productId] = nil end
    if S.RefreshCartUI then S.RefreshCartUI() end
end

function S.ClearCart()
    S.Cart = {}
    if S.RefreshCartUI then S.RefreshCartUI() end
end

function S.GetCartTotal()
    local total = 0
    for id, count in pairs(S.Cart) do
        local p = S.ProductIndex[id]
        if p then total = total + p.price * count end
    end
    return total
end

-- ================== F4. 购物车 UI（右侧） ==================
local cartFrame = Instance.new("Frame")
cartFrame.Name = "CartUI"
cartFrame.Size = UDim2.fromScale(0.24, 0.5)
cartFrame.Position = UDim2.new(0.74, 0, 0.25, 0)
cartFrame.BackgroundColor3 = Color3.fromRGB(24,28,38)
cartFrame.BackgroundTransparency = 0.4
cartFrame.BorderSizePixel = 0
cartFrame.Visible = false
cartFrame.ZIndex = 70
cartFrame.Parent = gui
applyGlass(cartFrame, 18, 0.65)

local cartTitle = Instance.new("TextLabel")
cartTitle.Size = UDim2.fromScale(0.9, 0.08)
cartTitle.Position = UDim2.fromScale(0.05, 0.02)
cartTitle.BackgroundTransparency = 1
cartTitle.Text = "🛒 购物车"
cartTitle.TextColor3 = Color3.fromRGB(240,245,255)
cartTitle.TextScaled = true
cartTitle.Font = Enum.Font.GothamBold
cartTitle.ZIndex = 71
cartTitle.Parent = cartFrame

local cartList = Instance.new("ScrollingFrame")
cartList.Size = UDim2.fromScale(0.9, 0.62)
cartList.Position = UDim2.fromScale(0.05, 0.11)
cartList.BackgroundTransparency = 1
cartList.BorderSizePixel = 0
cartList.ScrollBarThickness = 3
cartList.CanvasSize = UDim2.new(0,0,0,0)
cartList.AutomaticCanvasSize = Enum.AutomaticSize.Y
cartList.ClipsDescendants = true
cartList.ZIndex = 71
cartList.Parent = cartFrame
local cartListLayout = Instance.new("UIListLayout")
cartListLayout.Padding = UDim.new(0,3)
cartListLayout.SortOrder = Enum.SortOrder.LayoutOrder
cartListLayout.Parent = cartList

local cartTotalLbl = Instance.new("TextLabel")
cartTotalLbl.Size = UDim2.fromScale(0.9, 0.08)
cartTotalLbl.Position = UDim2.fromScale(0.05, 0.75)
cartTotalLbl.BackgroundTransparency = 1
cartTotalLbl.Text = "总价：$0"
cartTotalLbl.TextColor3 = Color3.fromRGB(255,220,120)
cartTotalLbl.TextScaled = true
cartTotalLbl.Font = Enum.Font.GothamBold
cartTotalLbl.ZIndex = 71
cartTotalLbl.Parent = cartFrame

local cartCheckoutBtn = mkButton(cartFrame, "结算", UDim2.fromScale(0.4, 0.09),
    UDim2.fromScale(0.05, 0.86), 0, Color3.fromRGB(60,140,90))
cartCheckoutBtn.ZIndex = 72
cartCheckoutBtn.Activated:Connect(function()
    S.OpenCheckout()
end)

local cartClearBtn = mkButton(cartFrame, "清空", UDim2.fromScale(0.4, 0.09),
    UDim2.fromScale(0.55, 0.86), 0, Color3.fromRGB(140,60,60))
cartClearBtn.ZIndex = 72
cartClearBtn.Activated:Connect(function()
    S.ClearCart()
    S.Notify("购物车已清空", Color3.fromRGB(255,180,120))
end)

function S.RefreshCartUI()
    for _, c in ipairs(cartList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local order = 0
    for id, count in pairs(S.Cart) do
        local p = S.ProductIndex[id]
        if p then
            order = order + 1
            local text = string.format("%s ×%d  $%d", p.name, count, p.price * count)
            local b = mkButton(cartList, text, UDim2.new(1,-6,0,28), UDim2.fromOffset(3,0), order,
                Color3.fromRGB(50,60,80))
            b.ZIndex = 72
            b.Activated:Connect(function()
                S.RemoveFromCart(id)
            end)
        end
    end
    cartTotalLbl.Text = "总价：$" .. S.GetCartTotal()
end

-- ================== F5. 进入超市自动开启购物模式 ==================
local shoppingMode = false
task.spawn(function()
    while true do
        task.wait(0.5)
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local inShop = false
            for _, sm in ipairs(supermarkets) do
                local d = (hrp.Position - sm.pos).Magnitude
                if d < 35 then inShop = true; break end
            end
            if inShop and not shoppingMode then
                shoppingMode = true
                cartFrame.Visible = true
                S.Notify("进入超市 · 购物模式已开启", Color3.fromRGB(120,220,160))
                S.RefreshCartUI()
            elseif not inShop and shoppingMode then
                shoppingMode = false
                cartFrame.Visible = false
                S.Notify("离开超市", Color3.fromRGB(180,180,200))
            end
        end
    end
end)

-- ================== F6. 结算界面 ==================
local checkoutUI = Instance.new("Frame")
checkoutUI.Name = "CheckoutUI"
checkoutUI.Size = UDim2.fromScale(0.6, 0.6)
checkoutUI.Position = UDim2.fromScale(0.2, 0.2)
checkoutUI.BackgroundColor3 = Color3.fromRGB(24,28,38)
checkoutUI.BackgroundTransparency = 0.15
checkoutUI.BorderSizePixel = 0
checkoutUI.Visible = false
checkoutUI.ZIndex = 85
checkoutUI.Parent = gui
applyGlass(checkoutUI, 22, 0.6)

local coTitle = Instance.new("TextLabel")
coTitle.Size = UDim2.fromScale(0.9, 0.08)
coTitle.Position = UDim2.fromScale(0.05, 0.03)
coTitle.BackgroundTransparency = 1
coTitle.Text = "💰 结算"
coTitle.TextColor3 = Color3.fromRGB(240,245,255)
coTitle.TextScaled = true
coTitle.Font = Enum.Font.GothamBold
coTitle.ZIndex = 86
coTitle.Parent = checkoutUI

local coClose = mkButton(checkoutUI, "✕", UDim2.fromScale(0.08,0.06),
    UDim2.fromScale(0.88, 0.025), 0, Color3.fromRGB(120,50,50))
coClose.ZIndex = 86
coClose.Activated:Connect(function() checkoutUI.Visible = false end)

local coList = Instance.new("ScrollingFrame")
coList.Size = UDim2.fromScale(0.9, 0.55)
coList.Position = UDim2.fromScale(0.05, 0.12)
coList.BackgroundTransparency = 1
coList.BorderSizePixel = 0
coList.ScrollBarThickness = 3
coList.CanvasSize = UDim2.new(0,0,0,0)
coList.AutomaticCanvasSize = Enum.AutomaticSize.Y
coList.ClipsDescendants = true
coList.ZIndex = 86
coList.Parent = checkoutUI
local coListLayout = Instance.new("UIListLayout")
coListLayout.Padding = UDim.new(0,3)
coListLayout.SortOrder = Enum.SortOrder.LayoutOrder
coListLayout.Parent = coList

local coTotal = Instance.new("TextLabel")
coTotal.Size = UDim2.fromScale(0.9, 0.08)
coTotal.Position = UDim2.fromScale(0.05, 0.7)
coTotal.BackgroundTransparency = 1
coTotal.Text = "总价：$0"
coTotal.TextColor3 = Color3.fromRGB(255,220,120)
coTotal.TextScaled = true
coTotal.Font = Enum.Font.GothamBold
coTotal.ZIndex = 86
coTotal.Parent = checkoutUI

local coConfirm = mkButton(checkoutUI, "确认支付", UDim2.fromScale(0.5, 0.1),
    UDim2.fromScale(0.25, 0.82), 0, Color3.fromRGB(60,140,90))
coConfirm.ZIndex = 87

function S.OpenCheckout()
    if next(S.Cart) == nil then
        S.Notify("购物车是空的", Color3.fromRGB(255,180,120))
        return
    end
    checkoutUI.Visible = true

    for _, c in ipairs(coList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local order = 0
    for id, count in pairs(S.Cart) do
        local p = S.ProductIndex[id]
        if p then
            order = order + 1
            local text = string.format("%s ×%d   $%d", p.name, count, p.price * count)
            local b = mkButton(coList, text, UDim2.new(1,-6,0,32), UDim2.fromOffset(3,0), order,
                Color3.fromRGB(45,55,75))
            b.ZIndex = 87
        end
    end
    coTotal.Text = "总价：$" .. S.GetCartTotal()
end

coConfirm.Activated:Connect(function()
    local total = S.GetCartTotal()
    if total <= 0 then
        S.Notify("购物车是空的", Color3.fromRGB(255,180,120))
        return
    end
    if S.Money < total then
        S.Notify("金钱不足，需要 $"..total, Color3.fromRGB(255,120,120))
        return
    end
    S.AddMoney(-total)
    -- 放入背包
    for id, count in pairs(S.Cart) do
        S.Inventory[id] = (S.Inventory[id] or 0) + count
    end
    S.ClearCart()
    checkoutUI.Visible = false
    S.Notify("结算成功，商品已入背包", Color3.fromRGB(120,220,160))
end)

-- ================== F7. 背包 UI ==================
local bagBtn = mkButton(gui, "🎒 背包", UDim2.fromScale(0.12, 0.05),
    UDim2.new(0.88, 0, 0.62, 0), 0, Color3.fromRGB(80,80,140))
bagBtn.ZIndex = 60

local bagUI = Instance.new("Frame")
bagUI.Name = "BagUI"
bagUI.Size = UDim2.fromScale(0.6, 0.65)
bagUI.Position = UDim2.fromScale(0.2, 0.175)
bagUI.BackgroundColor3 = Color3.fromRGB(24,28,38)
bagUI.BackgroundTransparency = 0.15
bagUI.BorderSizePixel = 0
bagUI.Visible = false
bagUI.ZIndex = 85
bagUI.Parent = gui
applyGlass(bagUI, 22, 0.6)

local bagTitle = Instance.new("TextLabel")
bagTitle.Size = UDim2.fromScale(0.9, 0.08)
bagTitle.Position = UDim2.fromScale(0.05, 0.03)
bagTitle.BackgroundTransparency = 1
bagTitle.Text = "🎒 背包"
bagTitle.TextColor3 = Color3.fromRGB(240,245,255)
bagTitle.TextScaled = true
bagTitle.Font = Enum.Font.GothamBold
bagTitle.ZIndex = 86
bagTitle.Parent = bagUI

local bagClose = mkButton(bagUI, "✕", UDim2.fromScale(0.08,0.06),
    UDim2.fromScale(0.88, 0.025), 0, Color3.fromRGB(120,50,50))
bagClose.ZIndex = 86
bagClose.Activated:Connect(function() bagUI.Visible = false end)

local bagList = Instance.new("ScrollingFrame")
bagList.Size = UDim2.fromScale(0.9, 0.82)
bagList.Position = UDim2.fromScale(0.05, 0.12)
bagList.BackgroundTransparency = 1
bagList.BorderSizePixel = 0
bagList.ScrollBarThickness = 3
bagList.CanvasSize = UDim2.new(0,0,0,0)
bagList.AutomaticCanvasSize = Enum.AutomaticSize.Y
bagList.ClipsDescendants = true
bagList.ZIndex = 86
bagList.Parent = bagUI
local bagListLayout = Instance.new("UIListLayout")
bagListLayout.Padding = UDim.new(0,3)
bagListLayout.SortOrder = Enum.SortOrder.LayoutOrder
bagListLayout.Parent = bagList

local function useItem(id)
    local p = S.ProductIndex[id]
    if not p then return end
    if not S.Inventory[id] or S.Inventory[id] <= 0 then return end
    S.Inventory[id] = S.Inventory[id] - 1
    if S.Inventory[id] <= 0 then S.Inventory[id] = nil end

    if p.effect.hunger and S.FeedHunger then S.FeedHunger(p.effect.hunger) end
    if p.effect.thirst and S.DrinkThirst then S.DrinkThirst(p.effect.thirst) end
    if p.effect.health and S.HealPlayer then S.HealPlayer(p.effect.health) end
    S.Notify("已使用 "..p.name, Color3.fromRGB(120,220,160))

    S.RefreshBagUI()
end

function S.RefreshBagUI()
    for _, c in ipairs(bagList:GetChildren()) do
        if c:IsA("TextButton") then c:Destroy() end
    end
    local order = 0
    for id, count in pairs(S.Inventory) do
        local p = S.ProductIndex[id]
        if p then
            order = order + 1
            local text = string.format("%s ×%d   [点击使用]", p.name, count)
            local b = mkButton(bagList, text, UDim2.new(1,-6,0,36), UDim2.fromOffset(3,0), order,
                Color3.fromRGB(45,55,75))
            b.ZIndex = 87
            b.Activated:Connect(function()
                useItem(id)
            end)
        end
    end
end

bagBtn.Activated:Connect(function()
    bagUI.Visible = not bagUI.Visible
    if bagUI.Visible then S.RefreshBagUI() end
end)

S.Notify("Part 3F 加载完成：超市 / 购物 / 结算 / 背包", Color3.fromRGB(120,220,160))
print("[IncSim] Part 3F 加载完成")
--[[
=====================================================================
  Part 3G：技能系统 / 成就系统 / 每日任务 / 黑市 / 最终收尾
  接在 Part 3F 末尾（全脚本最后一段）
=====================================================================
]]

-- ================== G1. 技能系统 ==================
S.Skills = S.Skills or {
    driving = { level=1, exp=0, name="驾驶",  desc="提升车辆速度" },
    shooting= { level=1, exp=0, name="射击",  desc="降低后坐力" },
    stamina = { level=1, exp=0, name="体力",  desc="提升移动速度" },
    trading = { level=1, exp=0, name="交易",  desc="提升任务收益" },
}
S.SkillExpMax = function(lv) return 100 * lv end

function S.AddSkillExp(skillKey, amount)
    local sk = S.Skills[skillKey]
    if not sk then return end
    sk.exp = sk.exp + (amount or 1)
    while sk.exp >= S.SkillExpMax(sk.level) do
        sk.exp = sk.exp - S.SkillExpMax(sk.level)
        sk.level = sk.level + 1
        S.Notify(string.format("技能提升：%s Lv.%d", sk.name, sk.level), Color3.fromRGB(255,220,120))
    end
end

-- 技能影响：射击技能降低后坐力
local origFireOnce = nil
task.spawn(function()
    task.wait(0.5)
    -- 挂钩：每次做任务 +1 交易经验
    if S.JobBuilders then
        local origAddMoney = S.AddMoney
        S.AddMoney = function(a)
            origAddMoney(a)
            if a > 0 and math.random() < 0.3 then
                S.AddSkillExp("trading", 1)
            end
        end
    end
    -- 每 10 秒行走获得体力经验
    task.spawn(function()
        while true do
            task.wait(10)
            local char = LocalPlayer.Character
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            if hum and hum.MoveDirection.Magnitude > 0.1 then
                S.AddSkillExp("stamina", 1)
            end
        end
    end)
end)

-- 技能 UI（在管理员面板加一个按钮显示技能状态）
local skillBtn = mkButton(content, "查看技能等级", UDim2.new(1,-8,0,44),
    UDim2.fromOffset(4,0), 1100, Color3.fromRGB(80,80,140))
skillBtn.ZIndex = 42
table.insert(adminBtnList, skillBtn)
skillBtn.Activated:Connect(function()
    local lines = {}
    for k, sk in pairs(S.Skills) do
        table.insert(lines, string.format("%s Lv.%d (%d/%d)", sk.name, sk.level, sk.exp, S.SkillExpMax(sk.level)))
    end
    S.Notify(table.concat(lines, " | "), Color3.fromRGB(180,220,255))
end)

-- ================== G2. 成就系统 ==================
S.Achievements = S.Achievements or {}
S.AchievementDefs = {
    {id="first_job",   name="第一桶金",   desc="完成第一个工作"},
    {id="money_10k",   name="万元户",     desc="拥有 $10,000"},
    {id="money_100k",  name="十万富翁",   desc="拥有 $100,000"},
    {id="money_1m",    name="百万富翁",   desc="拥有 $1,000,000"},
    {id="job_10",      name="勤勤恳恳",   desc="完成 10 个工作"},
    {id="job_50",      name="劳模",       desc="完成 50 个工作"},
    {id="gun_owner",   name="枪械爱好者", desc="购买第一把枪"},
    {id="passive_all", name="投资达人",   desc="购买全部被动收入"},
    {id="shopper",     name="购物达人",   desc="超市结算一次"},
    {id="survivor",    name="生存者",     desc="生命、饥饿、口渴全部保持 50+"},
}

function S.UnlockAchievement(id)
    if S.Achievements[id] then return end
    local def
    for _, d in ipairs(S.AchievementDefs) do
        if d.id == id then def = d; break end
    end
    if not def then return end
    S.Achievements[id] = os.time()
    S.Notify("🏆 成就解锁："..def.name, Color3.fromRGB(255,220,80))
end

-- 成就触发器
S.JobCompleteCount = S.JobCompleteCount or 0
local origCompleteJob = S.CompleteCurrentJob
if origCompleteJob then
    S.CompleteCurrentJob = function()
        origCompleteJob()
        S.JobCompleteCount = S.JobCompleteCount + 1
        S.UnlockAchievement("first_job")
        if S.JobCompleteCount >= 10 then S.UnlockAchievement("job_10") end
        if S.JobCompleteCount >= 50 then S.UnlockAchievement("job_50") end
    end
end

task.spawn(function()
    while true do
        task.wait(2)
        if S.Money >= 10000 then S.UnlockAchievement("money_10k") end
        if S.Money >= 100000 then S.UnlockAchievement("money_100k") end
        if S.Money >= 1000000 then S.UnlockAchievement("money_1m") end
        if S.Passive.stock and S.Passive.house and S.Passive.company then
            S.UnlockAchievement("passive_all")
        end
        if S.Survival and S.Survival.health >= 50 and S.Survival.hunger >= 50 and S.Survival.thirst >= 50 then
            S.UnlockAchievement("survivor")
        end
    end
end)

local achBtn = mkButton(content, "查看成就", UDim2.new(1,-8,0,44),
    UDim2.fromOffset(4,0), 1101, Color3.fromRGB(180,140,60))
achBtn.ZIndex = 42
table.insert(adminBtnList, achBtn)
achBtn.Activated:Connect(function()
    local unlocked = 0
    for _ in pairs(S.Achievements) do unlocked = unlocked + 1 end
    S.Notify(string.format("成就：%d / %d 已解锁", unlocked, #S.AchievementDefs), Color3.fromRGB(255,220,120))
end)

-- ================== G3. 每日任务 ==================
S.DailyQuests = S.DailyQuests or {}
S.LastDailyReset = S.LastDailyReset or 0

local function genDailyQuests()
    local jobs = {"送外卖","送快递","开出租","超市打工","餐厅服务员","搬砖","洗车"}
    local pick1 = jobs[math.random(1, #jobs)]
    local pick2 = jobs[math.random(1, #jobs)]
    S.DailyQuests = {
        { id="daily_1", text="完成 3 次「"..pick1.."」", job=pick1, need=3, have=0, reward=500 },
        { id="daily_2", text="完成 2 次「"..pick2.."」", job=pick2, need=2, have=0, reward=800 },
        { id="daily_3", text="赚取 $5000",               type="money",    need=5000, have=0, reward=1500 },
    }
    S.LastDailyReset = os.time()
    S.Notify("每日任务已刷新", Color3.fromRGB(120,220,255))
end

genDailyQuests()

-- 每 24 分钟真实时间刷新一次
task.spawn(function()
    while true do
        task.wait(60)
        if os.time() - S.LastDailyReset > 24 * 60 then
            genDailyQuests()
        end
    end
end)

-- 每日任务进度更新
local origCompleteJob2 = S.CompleteCurrentJob
if origCompleteJob2 then
    local prevName = nil
    S.CompleteCurrentJob = function()
        -- 记录当前任务名
        local curName
        if S.JobData then curName = S.JobData.name end
        origCompleteJob2()
        -- 更新每日
        for _, q in ipairs(S.DailyQuests) do
            if q.job and curName and q.job == curName then
                q.have = q.have + 1
                if q.have >= q.need then
                    S.AddMoney(q.reward)
                    S.Notify("每日任务完成："..q.text.." +$"..q.reward, Color3.fromRGB(120,220,160))
                end
            end
        end
    end
end

local dailyBtn = mkButton(content, "查看每日任务", UDim2.new(1,-8,0,44),
    UDim2.fromOffset(4,0), 1102, Color3.fromRGB(100,140,180))
dailyBtn.ZIndex = 42
table.insert(adminBtnList, dailyBtn)
dailyBtn.Activated:Connect(function()
    local lines = {}
    for _, q in ipairs(S.DailyQuests) do
        table.insert(lines, string.format("%s (%d/%d)", q.text, q.have, q.need))
    end
    S.Notify(table.concat(lines, " | "), Color3.fromRGB(180,220,255))
end)

-- ================== G4. 黑市（高风险高回报） ==================
local blackMarketPos = Vector3.new(850, 3, 3150)  -- 港口附近

local bmBody = newPart(cityFolder, Vector3.new(16, 8, 12),
    CFrame.new(blackMarketPos + Vector3.new(0, 4, 0)),
    Color3.fromRGB(40,35,35), Enum.Material.Concrete)

local bmSign = newPart(cityFolder, Vector3.new(12, 2, 0.4),
    CFrame.new(blackMarketPos + Vector3.new(0, 9, -6.2)),
    Color3.fromRGB(180,40,180), Enum.Material.Neon)

S.RegisterPoint("black_market", blackMarketPos + Vector3.new(0, 3, -8),
    "进入黑市", "风险交易", function()
        S.Notify("黑市：下注 $1000 赢 $5000（成功率 "..math.floor(S.Rates.gamble*100).."%）",
            Color3.fromRGB(255,120,255))
        task.wait(1)
        if S.Money < 1000 then
            S.Notify("金钱不足", Color3.fromRGB(255,120,120))
            return
        end
        S.AddMoney(-1000)
        if math.random() < S.Rates.gamble * 0.7 then  -- 黑市成功率更低
            S.AddMoney(5000)
            S.Notify("黑市交易成功 +$5000", Color3.fromRGB(120,220,160))
        else
            S.Notify("黑市交易失败 -$1000", Color3.fromRGB(255,120,120))
        end
    end)

S.AddPlaceIcon("黑市", blackMarketPos + Vector3.new(0,5,0), Color3.fromRGB(255,80,255))

-- ================== G5. 存档扩展（含新系统数据） ==================
local origSerialize = S.SerializeSave
S.SerializeSave = function()
    local base = origSerialize and origSerialize() or nil
    if not base then return nil end
    local ok, data = pcall(function() return HttpService:JSONDecode(base) end)
    if not ok then return base end
    data.skills = S.Skills
    data.achievements = S.Achievements
    data.dailyQuests = S.DailyQuests
    data.lastDailyReset = S.LastDailyReset
    data.inventory = S.Inventory
    data.equippedGun = S.EquippedGun
    data.survival = S.Survival
    data.gameDayCount = S.GameDayCount
    data.gameDayMinutes = S.GameDayMinutes
    local ok2, str = pcall(function() return HttpService:JSONEncode(data) end)
    return ok2 and str or base
end

local origDeserialize = S.DeserializeSave
S.DeserializeSave = function(str)
    local ok, err = origDeserialize and origDeserialize(str) or false, nil
    if not ok then return false, err end
    local ok2, data = pcall(function() return HttpService:JSONDecode(str) end)
    if not ok2 or type(data) ~= "table" then return true end
    if data.skills and type(data.skills) == "table" then S.Skills = data.skills end
    if data.achievements and type(data.achievements) == "table" then S.Achievements = data.achievements end
    if data.dailyQuests and type(data.dailyQuests) == "table" then S.DailyQuests = data.dailyQuests end
    if data.lastDailyReset then S.LastDailyReset = data.lastDailyReset end
    if data.inventory and type(data.inventory) == "table" then S.Inventory = data.inventory end
    if data.equippedGun then S.EquippedGun = data.equippedGun; S.UpdateGunHUD() end
    if data.survival and type(data.survival) == "table" then
        for k, v in pairs(data.survival) do
            if type(v) == "number" or type(v) == "boolean" then S.Survival[k] = v end
        end
    end
    if data.gameDayCount then S.GameDayCount = data.gameDayCount end
    if data.gameDayMinutes then S.GameDayMinutes = data.gameDayMinutes end
    return true
end

-- ================== G6. 最终自检 ==================
S.FinalSelfCheck = function()
    print("========== IncSim 最终自检 ==========")
    print("金钱：", S.FmtMoney(S.Money))
    print("工作数：", #S.JobBuilders)
    print("枪械数：", #S.GUNS)
    print("商品数：", #S.PRODUCTS)
    print("超市数：", #(S.Supermarkets or {}))
    print("NPC 数：", #S.NPCs)
    print("车辆数：", #S.Vehicles)
    print("区域数：", #S.BIG_REGIONS)
    print("地图尺寸：", S.BIG_MAP_SIZE, "×", S.BIG_MAP_SIZE)
    print("天气：", S.Weather)
    print("时间：第", S.GameDayCount, "天", math.floor(S.GameDayMinutes/60), ":", S.GameDayMinutes % 60)
    print("被动：stock=", S.Passive.stock, "house=", S.Passive.house, "company=", S.Passive.company)
    print("技能：")
    for k, sk in pairs(S.Skills) do
        print("  -", sk.name, "Lv."..sk.level, sk.exp.."/"..S.SkillExpMax(sk.level))
    end
    local achCount = 0
    for _ in pairs(S.Achievements) do achCount = achCount + 1 end
    print("成就：", achCount, "/", #S.AchievementDefs)
    print("背包物品：")
    for id, c in pairs(S.Inventory) do print("  -", id, "×"..c) end
    print("已装备：", S.EquippedGun or "无")
    print("=================================")
end

local finalSelfBtn = mkButton(content, "🔍 最终自检（输出到控制台）",
    UDim2.new(1,-8,0,44), UDim2.fromOffset(4,0), 1200, Color3.fromRGB(100,60,140))
finalSelfBtn.ZIndex = 42
table.insert(adminBtnList, finalSelfBtn)
finalSelfBtn.Activated:Connect(function()
    S.FinalSelfCheck()
    S.Notify("最终自检完成，请看控制台", Color3.fromRGB(120,220,160))
end)

-- ================== G7. 完 ==================
S.Notify("✅ 全部系统加载完成", Color3.fromRGB(120,220,160))
S.Notify(string.format("工作 %d · 枪械 %d · 商品 %d · 区域 %d",
    #S.JobBuilders, #S.GUNS, #S.PRODUCTS, #S.BIG_REGIONS), Color3.fromRGB(200,220,255))

print("[IncSim] Part 3G 加载完成 — 全部系统就绪")
print("============================================================")
print("  IncSim 增量模拟器 · 完整版加载成功")
print("  地图 "..S.BIG_MAP_SIZE.."×"..S.BIG_MAP_SIZE.." · 8 区域 · 高速公路 · 立交 · 隧道")
print("  工作 "..#S.JobBuilders.." 种 · 枪械 "..#S.GUNS.." 把 · 商品 "..#S.PRODUCTS.." 种")
print("  NPC "..#S.NPCs.." 个 · 车辆 "..#S.Vehicles.." 辆 · 超市 "..#(S.Supermarkets or {}).." 家")
print("  管理员面板密码：6767")
print("============================================================")