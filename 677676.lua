--[[IncSim 完整版·单文件 | 粘贴执行一次 | 密码6767]]
do local c=game:GetService("CoreGui") for _,g in ipairs(c:GetChildren())do if g:IsA("ScreenGui")and(g.Name=="IncSim_GUI"or g.Name=="IncSim_Load")then g:Destroy()end end
local o=workspace:FindFirstChild("IncSim_City")if o then o:Destroy()end
local b=game:GetService("Lighting"):FindFirstChild("IncSim_Blur")if b then b:Destroy()end end

CG=game:GetService("CoreGui")PL=game:GetService("Players")TS=game:GetService("TweenService")
UIS=game:GetService("UserInputService")HS=game:GetService("HttpService")LT=game:GetService("Lighting")
WS=workspace LP=PL.LocalPlayer SS=game:GetService("SoundService")

S={}S.Money=0 S.Cool={}S.Rate={invest=.5,stock=.5,gamble=.5,lottery=.05,mining=.1,fishing=.1,mult=1}
S.Pass={stock=false,house=false,company=false}S.PR={stock=5,house=15,company=35}
S.Surv={health=100,hunger=100,thirst=100,lastH=os.time(),lastT=os.time(),dead=false}
S.JS=nil S.JD=nil S.Cells={}S.Inv={}S.Equip=nil
S.Sk={drive=1,shoot=1,stamina=1,trade=1}S.SkE={drive=0,shoot=0,stamina=0,trade=0}
S.Ach={}S.Daily={}S.DayC=1 S.GMin=0 S.Weather="sunny"S.BigMap=5000
S.SaveV=2 S.NPCs={}S.Cars={}S.Shops={}

function FmtM(n)n=math.floor(n or 0)local ng=n<0 n=math.abs(n)
local s=tostring(n)s=s:reverse():gsub("(%d%d%d)","%1,"):reverse():gsub("^,","")
return(ng and "-$"or"$")..s end

function Glass(f,r,tr,bg)f.BackgroundColor3=bg or Color3.fromRGB(30,34,44)
f.BackgroundTransparency=.4 f.BorderSizePixel=0
local c=f:FindFirstChildOfClass("UICorner")or Instance.new("UICorner")
c.CornerRadius=UDim.new(0,r or 20)c.Parent=f
local s=f:FindFirstChildOfClass("UIStroke")or Instance.new("UIStroke")
s.Color=Color3.fromRGB(255,255,255)s.Transparency=tr or .72 s.Thickness=1
s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border s.Parent=f end

function Noti(t,c)c=c or Color3.fromRGB(220,230,255)
local n=Instance.new("Frame")n.Size=UDim2.fromScale(.9,.08)n.BackgroundColor3=Color3.fromRGB(30,34,44)
n.BackgroundTransparency=.3 n.ZIndex=21 n.Parent=NL Glass(n,12,.7)
local l=Instance.new("TextLabel")l.Size=UDim2.fromScale(.94,1)l.Position=UDim2.fromScale(.03,0)
l.BackgroundTransparency=1 l.Text=t l.TextColor3=c l.TextScaled=true l.Font=Enum.Font.GothamBold
l.TextXAlignment=Enum.TextXAlignment.Right l.ZIndex=22 l.Parent=n
n.Position=UDim2.fromScale(1.2,0)TS:Create(n,TweenInfo.new(.18),{Position=UDim2.fromScale(0,0)}):Play()
task.delay(2,function()if n.Parent then local t2=TS:Create(n,TweenInfo.new(.18),{Position=UDim2.fromScale(1.2,0)})
t2:Play()t2.Completed:Connect(function()n:Destroy()end)end end)end

function RefM()if MLbl then MLbl.Text=FmtM(S.Money)end end
function AddM(a)if a==0 then return end S.Money=math.max(0,S.Money+a)RefM()
if a>0 then Noti("+$"..math.floor(a),Color3.fromRGB(80,220,120))else Noti("-$"..math.floor(-a),Color3.fromRGB(255,100,100))end end
function SetM(a)S.Money=math.max(0,math.floor(a))RefM()end

function MkBtn(p,t,sz,pos,ord,bg)local b=Instance.new("TextButton")
b.Size=sz or UDim2.fromScale(.9,.08)b.Position=pos or UDim2.fromScale(.05,0)
b.BackgroundColor3=bg or Color3.fromRGB(45,52,68)b.BackgroundTransparency=.25
b.BorderSizePixel=0 b.Text=t b.TextColor3=Color3.fromRGB(240,245,255)b.TextScaled=true
b.Font=Enum.Font.GothamBold b.AutoButtonColor=false b.Active=true b.ZIndex=2 b.LayoutOrder=ord or 0 b.Parent=p
local c=Instance.new("UICorner")c.CornerRadius=UDim.new(0,14)c.Parent=b
local s=Instance.new("UIStroke")s.Color=Color3.fromRGB(255,255,255)s.Transparency=.7 s.Thickness=1 s.Parent=b
local pd=Instance.new("UIPadding")pd.PaddingLeft=UDim.new(0,6)pd.PaddingRight=UDim.new(0,6)pd.Parent=b
local bs,bb=b.Size,b.BackgroundTransparency
b.MouseButton1Down:Connect(function()TS:Create(b,TweenInfo.new(.08),{Size=UDim2.new(bs.X.Scale*.96,bs.X.Offset*.96,bs.Y.Scale*.96,bs.Y.Offset*.96),BackgroundTransparency=.08}):Play()end)
local function up()TS:Create(b,TweenInfo.new(.12),{Size=bs,BackgroundTransparency=bb}):Play()end
b.MouseButton1Up:Connect(up)b.MouseLeave:Connect(up)return b end

function Drag(f)local dg,ds,sp f.InputBegan:Connect(function(i)
if i.UserInputType==Enum.UserInputType.MouseButton1 or i.UserInputType==Enum.UserInputType.Touch then
dg=true ds=i.Position sp=f.Position i.Changed:Connect(function()if i.UserInputState==Enum.UserInputState.End then dg=false end end)end end)
UIS.InputChanged:Connect(function(i)if dg and(i.UserInputType==Enum.UserInputType.MouseMovement or i.UserInputType==Enum.UserInputType.Touch)then
local d=i.Position-ds f.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)end end)end

function PP()local c=LP.Character if not c then return nil end
local h=c:FindFirstChild("HumanoidRootPart")return h and h.Position or nil end
function PCF()local c=LP.Character if not c then return nil end
local h=c:FindFirstChild("HumanoidRootPart")return h and h.CFrame or nil end

-- ============== UI ==============
gui=Instance.new("ScreenGui")gui.Name="IncSim_GUI"gui.ResetOnSpawn=false
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling gui.DisplayOrder=9999 gui.Parent=CG
blur=Instance.new("BlurEffect")blur.Name="IncSim_Blur"blur.Size=0 blur.Parent=LT

MH=Instance.new("Frame")MH.Size=UDim2.fromScale(.34,.045)MH.Position=UDim2.new(.02,0,.03,0)
MH.ZIndex=3 MH.Parent=gui Glass(MH,16,.7)
MLbl=Instance.new("TextLabel")MLbl.Size=UDim2.fromScale(.72,1)MLbl.Position=UDim2.fromScale(.06,0)
MLbl.BackgroundTransparency=1 MLbl.Text="$0"MLbl.TextColor3=Color3.fromRGB(255,230,130)
MLbl.TextScaled=true MLbl.Font=Enum.Font.GothamBold MLbl.TextXAlignment=Enum.TextXAlignment.Left MLbl.ZIndex=4 MLbl.Parent=MH
local mBtn=MkBtn(MH,"—",UDim2.fromScale(.2,.7),UDim2.fromScale(.76,.15),0,Color3.fromRGB(60,68,88))mBtn.ZIndex=5
MBub=Instance.new("TextButton")MBub.Size=UDim2.fromOffset(48,48)MBub.Position=UDim2.new(.02,0,.03,0)
MBub.BackgroundColor3=Color3.fromRGB(40,48,62)MBub.BackgroundTransparency=.2 MBub.Text="$"
MBub.TextColor3=Color3.fromRGB(255,230,130)MBub.TextScaled=true MBub.Font=Enum.Font.GothamBold
MBub.Active=true MBub.Visible=false MBub.ZIndex=10 MBub.Parent=gui
local c2=Instance.new("UICorner")c2.CornerRadius=UDim.new(1,0)c2.Parent=MBub Drag(MBub)
mBtn.Activated:Connect(function()MH.Visible=false MBub.Visible=true end)
MBub.Activated:Connect(function()MBub.Visible=false MH.Visible=true end)

NB=Instance.new("Frame")NB.Size=UDim2.fromScale(.42,.5)NB.Position=UDim2.new(.56,0,.05,0)
NB.BackgroundTransparency=1 NB.ZIndex=20 NB.Parent=gui
local nll=Instance.new("UIListLayout")nll.SortOrder=Enum.SortOrder.LayoutOrder nll.Padding=UDim.new(0,6)
nll.HorizontalAlignment=Enum.HorizontalAlignment.Right nll.Parent=NB NL=NB

TH=Instance.new("Frame")TH.Size=UDim2.fromScale(.4,.045)TH.Position=UDim2.new(.3,0,.015,0)
TH.Visible=false TH.ZIndex=4 TH.Parent=gui Glass(TH,12,.7)
TLbl=Instance.new("TextLabel")TLbl.Size=UDim2.fromScale(.94,1)TLbl.Position=UDim2.fromScale(.03,0)
TLbl.BackgroundTransparency=1 TLbl.Text="无任务"TLbl.TextColor3=Color3.fromRGB(220,230,255)
TLbl.TextScaled=true TLbl.Font=Enum.Font.GothamMedium TLbl.ZIndex=5 TLbl.Parent=TH
function SetTask(t)if t and t~=""then TLbl.Text="任务："..t TH.Visible=true else TH.Visible=false end end

TimeH=Instance.new("TextLabel")TimeH.Size=UDim2.fromScale(.16,.032)TimeH.Position=UDim2.new(.02,0,.085,0)
TimeH.BackgroundColor3=Color3.fromRGB(30,34,44)TimeH.BackgroundTransparency=.5 TimeH.Text="第1天 08:00"
TimeH.TextColor3=Color3.fromRGB(240,240,255)TimeH.TextScaled=true TimeH.Font=Enum.Font.GothamBold
TimeH.ZIndex=5 TimeH.Parent=gui Glass(TimeH,10,.8)

ABall=Instance.new("TextButton")ABall.Size=UDim2.fromOffset(44,44)ABall.Position=UDim2.new(.9,0,.78,0)
ABall.BackgroundColor3=Color3.fromRGB(80,60,140)ABall.BackgroundTransparency=.15 ABall.Text="⚙"
ABall.TextColor3=Color3.fromRGB(255,255,255)ABall.TextScaled=true ABall.Font=Enum.Font.GothamBold
ABall.Active=true ABall.ZIndex=30 ABall.Parent=gui
local c3=Instance.new("UICorner")c3.CornerRadius=UDim.new(1,0)c3.Parent=ABall
local s3=Instance.new("UIStroke")s3.Color=Color3.fromRGB(255,255,255)s3.Transparency=.5 s3.Thickness=1.5 s3.Parent=ABall Drag(ABall)

APanel=Instance.new("Frame")APanel.Size=UDim2.fromScale(.82,.62)APanel.Position=UDim2.fromScale(.09,.19)
APanel.Visible=false APanel.ZIndex=40 APanel.Parent=gui Glass(APanel,22,.6,Color3.fromRGB(24,28,38))
local aT=Instance.new("TextLabel")aT.Size=UDim2.fromScale(.9,.07)aT.Position=UDim2.fromScale(.05,.015)
aT.BackgroundTransparency=1 aT.Text="管理员面板"aT.TextColor3=Color3.fromRGB(255,255,255)aT.TextScaled=true
aT.Font=Enum.Font.GothamBold aT.ZIndex=41 aT.Parent=APanel
local aX=MkBtn(APanel,"✕",UDim2.fromScale(.1,.07),UDim2.fromScale(.86,.02),0,Color3.fromRGB(120,50,50))aX.ZIndex=42
aX.Activated:Connect(function()APanel.Visible=false blur.Size=0 end)
local pW=Instance.new("TextBox")pW.Size=UDim2.fromScale(.7,.07)pW.Position=UDim2.fromScale(.05,.1)
pW.BackgroundColor3=Color3.fromRGB(40,46,58)pW.BackgroundTransparency=.2 pW.Text=""
pW.PlaceholderText="密码"pW.TextColor3=Color3.fromRGB(240,245,255)pW.PlaceholderColor3=Color3.fromRGB(160,170,190)
pW.TextScaled=true pW.Font=Enum.Font.GothamMedium pW.ClearTextOnFocus=false pW.TextEditable=true pW.ZIndex=42 pW.Parent=APanel
local pc=Instance.new("UICorner")pc.CornerRadius=UDim.new(0,12)pc.Parent=pW
local pB=MkBtn(APanel,"验证",UDim2.fromScale(.18,.07),UDim2.fromScale(.77,.1),0)pB.ZIndex=42
AC=Instance.new("ScrollingFrame")AC.Size=UDim2.fromScale(.9,.78)AC.Position=UDim2.fromScale(.05,.19)
AC.BackgroundTransparency=1 AC.BorderSizePixel=0 AC.ScrollBarThickness=4
AC.ScrollBarImageColor3=Color3.fromRGB(180,190,220)AC.CanvasSize=UDim2.new(0,0,0,0)
AC.AutomaticCanvasSize=Enum.AutomaticSize.Y AC.ClipsDescendants=true AC.ZIndex=41 AC.Parent=APanel
local acl=Instance.new("UIListLayout")acl.Padding=UDim.new(0,6)acl.SortOrder=Enum.SortOrder.LayoutOrder acl.Parent=AC
ABtns={}function RegB(v)table.insert(ABtns,v)return v end
function CBt(t,o,bg,cb)local b=MkBtn(AC,t,UDim2.new(1,-8,0,44),UDim2.fromOffset(4,0),o,bg)b.ZIndex=42 b.Activated:Connect(cb)return b end
pB.Activated:Connect(function()if pW.Text=="6767"then for _,c in ipairs(ABtns)do c.Visible=true end Noti("验证通过",Color3.fromRGB(120,220,160))else Noti("密码错误",Color3.fromRGB(255,120,120))end end)
ABall.Activated:Connect(function()APanel.Visible=not APanel.Visible blur.Size=APanel.Visible and 14 or 0 end)

MIn=Instance.new("TextBox")MIn.Size=UDim2.new(1,-8,0,42)MIn.Position=UDim2.fromOffset(4,0)
MIn.BackgroundColor3=Color3.fromRGB(40,46,58)MIn.BackgroundTransparency=.2 MIn.Text=""
MIn.PlaceholderText="输入金额"MIn.TextColor3=Color3.fromRGB(240,245,255)MIn.TextScaled=true
MIn.Font=Enum.Font.GothamMedium MIn.ClearTextOnFocus=false MIn.TextEditable=true MIn.LayoutOrder=1 MIn.Visible=false MIn.ZIndex=42 MIn.Parent=AC
local mi=Instance.new("UICorner")mi.CornerRadius=UDim.new(0,12)mi.Parent=MIn RegB(MIn)
RegB(CBt("加钱",2,nil,function()local n=tonumber(MIn.Text)if not n then Noti("请输入数字",Color3.fromRGB(255,120,120))return end AddM(math.floor(n))end))
RegB(CBt("设为",3,nil,function()local n=tonumber(MIn.Text)if not n then Noti("请输入数字",Color3.fromRGB(255,120,120))return end SetM(n)end))
RegB(CBt("清空",4,Color3.fromRGB(120,50,50),function()SetM(0)end))
local RN={invest="投资",stock="股市",gamble="赌博",lottery="彩票",mining="挖矿",fishing="钓鱼"}
local ri=0 for k,nm in pairs(RN)do ri=ri+1 local key=k
local lb=Instance.new("TextButton")lb.Size=UDim2.new(1,-8,0,40)lb.Position=UDim2.fromOffset(4,0)
lb.BackgroundColor3=Color3.fromRGB(40,46,58)lb.BackgroundTransparency=.2
lb.Text=nm.."："..math.floor(S.Rate[key]*100).."%"lb.TextScaled=true lb.Font=Enum.Font.GothamMedium
lb.TextColor3=Color3.fromRGB(230,235,250)lb.LayoutOrder=10+ri lb.Visible=false lb.Active=true lb.ZIndex=42 lb.Parent=AC
local lc=Instance.new("UICorner")lc.CornerRadius=UDim.new(0,12)lc.Parent=lb RegB(lb)
lb.Activated:Connect(function()local v=S.Rate[key]+.1 if v>1.000001 then v=.1 end S.Rate[key]=v lb.Text=nm.."："..math.floor(v*100+.5).."%"end)end
local mB=Instance.new("TextButton")mB.Size=UDim2.new(1,-8,0,40)mB.Position=UDim2.fromOffset(4,0)
mB.BackgroundColor3=Color3.fromRGB(40,46,58)mB.BackgroundTransparency=.2
mB.Text="倍率："..S.Rate.mult.."x"mB.TextScaled=true mB.Font=Enum.Font.GothamMedium mB.TextColor3=Color3.fromRGB(230,235,250)
mB.LayoutOrder=20 mB.Visible=false mB.Active=true mB.ZIndex=42 mB.Parent=AC
local mc=Instance.new("UICorner")mc.CornerRadius=UDim.new(0,12)mc.Parent=mB RegB(mB)
mB.Activated:Connect(function()S.Rate.mult=S.Rate.mult+5 if S.Rate.mult>100 then S.Rate.mult=1 end mB.Text="倍率："..S.Rate.mult.."x"end)
RegB(CBt("重置冷却",30,nil,function()S.Cool={}Noti("冷却已重置")end))
RegB(CBt("完成当前",31,nil,function()if S.JD and S.JS=="deliver"then local r=math.floor(S.JD.reward()*S.Rate.mult)AddM(r)SetTask("")SetHead("")S.Cool[S.JD.id]=os.time()+S.JD.cooldown S.JS=nil S.JD=nil
if WM then WM.beam:Destroy()WM.ring:Destroy()WM=nil end if WM2 then WM2.beam:Destroy()WM2.ring:Destroy()WM2=nil end
UnRegPt("jp")UnRegPt("jd")Noti("完成 +$"..r)else Noti("无任务",Color3.fromRGB(255,180,120))end end))
RegB(CBt("坐标",32,nil,function()local p=PP()if p then Noti(string.format("X:%d Y:%d Z:%d",p.X,p.Y,p.Z))end end))
RegB(CBt("被动",33,nil,function()Noti("stock="..tostring(S.Pass.stock).." house="..tostring(S.Pass.house).." comp="..tostring(S.Pass.company))end))
RegB(CBt("技能",34,nil,function()Noti(string.format("驾驶%d 射击%d 体力%d 交易%d",S.Sk.drive,S.Sk.shoot,S.Sk.stamina,S.Sk.trade))end))
RegB(CBt("成就",35,nil,function()local c=0 for _ in pairs(S.Ach)do c=c+1 end Noti("成就 "..c.."/10")end))
RegB(CBt("每日任务",36,nil,function()if #S.Daily==0 then Noti("无每日任务")else for _,q in ipairs(S.Daily)do Noti(string.format("%s (%d/%d)",q.text,q.have,q.need))end end end))
SB=Instance.new("TextBox")SB.Size=UDim2.new(1,-8,0,110)SB.Position=UDim2.fromOffset(4,0)
SB.BackgroundColor3=Color3.fromRGB(40,46,58)SB.BackgroundTransparency=.2 SB.Text=""
SB.PlaceholderText="存档码"SB.TextColor3=Color3.fromRGB(240,245,255)SB.TextSize=11 SB.TextWrapped=true
SB.MultiLine=true SB.ClearTextOnFocus=false SB.TextEditable=true SB.LayoutOrder=40 SB.Visible=false SB.ZIndex=42 SB.Parent=AC
local sbc=Instance.new("UICorner")sbc.CornerRadius=UDim.new(0,12)sbc.Parent=SB RegB(SB)
RegB(CBt("导出",41,nil,function()local d={v=S.SaveV,money=S.Money,rate=S.Rate,pass=S.Pass,cool=S.Cool,inv=S.Inv,ach=S.Ach,sk=S.Sk,skE=S.SkE,day=S.DayC,gmin=S.GMin}
local ok,js=pcall(function()return HS:JSONEncode(d)end)if ok then SB.Text=js Noti("已导出")end end))
RegB(CBt("导入",42,nil,function()local ok,d=pcall(function()return HS:JSONDecode(SB.Text)end)
if not ok or type(d)~="table"then Noti("无效",Color3.fromRGB(255,120,120))return end
if d.money then SetM(d.money)end if d.rate then for k,v in pairs(d.rate)do if S.Rate[k]then S.Rate[k]=v end end end
if d.pass then for k,v in pairs(d.pass)do S.Pass[k]=v and true or false end end if d.cool then S.Cool=d.cool end
if d.inv then S.Inv=d.inv end if d.ach then S.Ach=d.ach end if d.sk then S.Sk=d.sk end if d.skE then S.SkE=d.skE end
if d.day then S.DayC=d.day end if d.gmin then S.GMin=d.gmin end Noti("已导入")end))
RegB(CBt("重置全部",43,Color3.fromRGB(120,50,50),function()S.Money=0 S.Cool={}S.Pass={stock=false,house=false,company=false}
S.Rate={invest=.5,stock=.5,gamble=.5,lottery=.05,mining=.1,fishing=.1,mult=1}S.Inv={}RefM()Noti("已重置")end))

AB=Instance.new("TextButton")AB.Size=UDim2.fromScale(.44,.07)AB.Position=UDim2.fromScale(.28,.88)
AB.BackgroundColor3=Color3.fromRGB(70,140,220)AB.BackgroundTransparency=.15 AB.Text="交互"
AB.TextColor3=Color3.fromRGB(255,255,255)AB.TextScaled=true AB.Font=Enum.Font.GothamBold
AB.Active=true AB.Visible=false AB.ZIndex=60 AB.Parent=gui Glass(AB,18,.6,Color3.fromRGB(60,120,200))
AH=Instance.new("TextLabel")AH.Size=UDim2.fromScale(.44,.03)AH.Position=UDim2.fromScale(.28,.85)
AH.BackgroundTransparency=1 AH.Text=""AH.TextColor3=Color3.fromRGB(240,245,255)AH.TextScaled=true
AH.Font=Enum.Font.GothamBold AH.Visible=false AH.ZIndex=60 AH.Parent=gui
CA=nil function ShowAction(d)CA=d AB.Text=d.label or "交互"AH.Text=d.hint or ""AH.Visible=d.hint and d.hint~=""AB.Visible=true end
function HideAction()CA=nil AB.Visible=false AH.Visible=false end
AB.Activated:Connect(function()if CA and CA.action then CA.action()end end)

TGui=Instance.new("BillboardGui")TGui.Size=UDim2.fromOffset(200,50)TGui.StudsOffset=Vector3.new(0,3.5,0)
TGui.AlwaysOnTop=true TGui.Enabled=false TGui.Parent=gui
TL=Instance.new("TextLabel")TL.Size=UDim2.fromScale(1,1)TL.BackgroundColor3=Color3.fromRGB(30,34,44)
TL.BackgroundTransparency=.2 TL.Text=""TL.TextColor3=Color3.fromRGB(255,240,180)TL.TextScaled=true
TL.Font=Enum.Font.GothamBold TL.Parent=TGui
local tc=Instance.new("UICorner")tc.CornerRadius=UDim.new(0,10)tc.Parent=TL
function AttTag()local c=LP.Character local h=c and c:FindFirstChild("Head")if h then TGui.Adornee=h end end
LP.CharacterAdded:Connect(function()task.wait(1)AttTag()end)task.spawn(function()task.wait(2)AttTag()end)
function SetHead(t)if t and t~=""then TL.Text=t TGui.Enabled=true AttTag()else TGui.Enabled=false end end

Pts={}function RegPt(k,pos,lb,ht,cb)Pts[k]={pos=pos,label=lb,hint=ht,cb=cb}end
function UnRegPt(k)Pts[k]=nil end
task.spawn(function()while true do task.wait(.25)local p=PP()
if p then local nk,nd,nb for k,d in pairs(Pts)do local dist=(p-d.pos).Magnitude
if dist<12 and(not nd or dist<nd)then nk,nd,nb=k,dist,d end end
if nb then ShowAction({label=nb.label,hint=nb.hint,action=nb.cb})else HideAction()end end end end)

WM=nil WM2=nil
function MkMark(pos,col,lb)local beam=Instance.new("Part")beam.Size=Vector3.new(4,40,4)
beam.Position=pos+Vector3.new(0,20,0)beam.Color=col beam.Material=Enum.Material.Neon
beam.Transparency=.55 beam.CanCollide=false beam.Anchored=true beam.Name="WM"beam.Parent=WS
local ring=Instance.new("Part")ring.Shape=Enum.PartType.Cylinder ring.Size=Vector3.new(.4,12,12)
ring.CFrame=CFrame.new(pos.X,pos.Y+.3,pos.Z)*CFrame.Angles(0,0,math.rad(90))
ring.Color=col ring.Material=Enum.Material.Neon ring.Transparency=.3 ring.CanCollide=false ring.Anchored=true ring.Parent=WS
if lb then local bb=Instance.new("BillboardGui")bb.Size=UDim2.fromOffset(200,50)bb.StudsOffset=Vector3.new(0,26,0)
bb.AlwaysOnTop=true bb.Parent=beam local t=Instance.new("TextLabel")t.Size=UDim2.fromScale(1,1)
t.BackgroundTransparency=1 t.Text=lb t.TextColor3=col t.TextScaled=true t.Font=Enum.Font.GothamBold
t.TextStrokeTransparency=0 t.Parent=bb end
return{beam=beam,ring=ring}end
function ClearMarks()for _,o in ipairs(WS:GetDescendants())do if o.Name=="WM"then o:Destroy()end end end

-- ============== 加载界面 ==============
LG=Instance.new("ScreenGui")LG.Name="IncSim_Load"LG.ResetOnSpawn=false
LG.DisplayOrder=10000 LG.IgnoreGuiInset=true LG.Parent=CG
local lbg=Instance.new("Frame")lbg.Size=UDim2.fromScale(1,1)lbg.BackgroundColor3=Color3.fromRGB(12,14,20)
lbg.BorderSizePixel=0 lbg.ZIndex=1 lbg.Parent=LG
local lc=Instance.new("Frame")lc.Size=UDim2.fromScale(.8,.3)lc.Position=UDim2.fromScale(.1,.35)
lc.BackgroundColor3=Color3.fromRGB(30,34,44)lc.BackgroundTransparency=.2 lc.BorderSizePixel=0 lc.ZIndex=2 lc.Parent=LG
Glass(lc,22,.6)
local lt=Instance.new("TextLabel")lt.Size=UDim2.fromScale(.9,.22)lt.Position=UDim2.fromScale(.05,.1)
lt.BackgroundTransparency=1 lt.Text="加载中"lt.TextColor3=Color3.fromRGB(240,245,255)
lt.TextScaled=true lt.Font=Enum.Font.GothamBold lt.ZIndex=3 lt.Parent=lc
local lcnt=Instance.new("TextLabel")lcnt.Size=UDim2.fromScale(.9,.15)lcnt.Position=UDim2.fromScale(.05,.4)
lcnt.BackgroundTransparency=1 lcnt.Text="0/0"lcnt.TextColor3=Color3.fromRGB(200,210,235)
lcnt.TextScaled=true lcnt.Font=Enum.Font.GothamMedium lcnt.ZIndex=3 lcnt.Parent=lc
local lh=Instance.new("TextLabel")lh.Size=UDim2.fromScale(.9,.13)lh.Position=UDim2.fromScale(.05,.57)
lh.BackgroundTransparency=1 lh.Text="准备中"lh.TextColor3=Color3.fromRGB(170,180,205)
lh.TextScaled=true lh.Font=Enum.Font.Gotham lh.ZIndex=3 lh.Parent=lc
local lb=Instance.new("Frame")lb.Size=UDim2.fromScale(.9,.07)lb.Position=UDim2.fromScale(.05,.8)
lb.BackgroundColor3=Color3.fromRGB(50,56,70)lb.BackgroundTransparency=.2 lb.BorderSizePixel=0 lb.ZIndex=3 lb.Parent=lc
local lbc=Instance.new("UICorner")lbc.CornerRadius=UDim.new(1,0)lbc.Parent=lb
local lf=Instance.new("Frame")lf.Size=UDim2.fromScale(0,1)lf.BackgroundColor3=Color3.fromRGB(120,190,255)
lf.BorderSizePixel=0 lf.ZIndex=4 lf.Parent=lb
local lfc=Instance.new("UICorner")lfc.CornerRadius=UDim.new(1,0)lfc.Parent=lf
LTot=0 LDone=0 function AddT(n)LTot=LTot+(n or 1)end
function Tick(h)LDone=LDone+1 if LDone>LTot then LDone=LTot end
lcnt.Text=string.format("%d/%d",LDone,LTot)local r=LTot>0 and LDone/LTot or 0
lf.Size=UDim2.fromScale(r,1)if h then lh.Text=h end end

-- ============== 城市生成 ==============
City=Instance.new("Folder")City.Name="IncSim_City"City.Parent=WS
Roads=Instance.new("Folder")Roads.Name="Roads"Roads.Parent=City
Builds=Instance.new("Folder")Builds.Name="Buildings"Builds.Parent=City
Props=Instance.new("Folder")Props.Name="Props"Props.Parent=City
Marks=Instance.new("Folder")Marks.Name="Markers"Marks.Parent=City
Inter=Instance.new("Folder")Inter.Name="Interiors"Inter.Parent=City
NPCF=Instance.new("Folder")NPCF.Name="NPCs"NPCF.Parent=City
VehF=Instance.new("Folder")VehF.Name="Vehicles"VehF.Parent=City

BIG=5000 CEN=Vector3.new(2500,0,2500)
Region={
{n="市中心",x1=1750,z1=1750,x2=3250,z2=3250,c=Color3.fromRGB(150,160,180),s="office"},
{n="商业区",x1=3250,z1=1750,x2=4250,z2=3250,c=Color3.fromRGB(180,140,120),s="shop"},
{n="住宅区",x1=750,z1=1750,x2=1750,z2=3250,c=Color3.fromRGB(140,160,140),s="res"},
{n="工业区",x1=1750,z1=3250,x2=3250,z2=4250,c=Color3.fromRGB(120,120,125),s="ware"},
{n="港口区",x1=750,z1=3250,x2=1750,z2=4250,c=Color3.fromRGB(100,140,180),s="ware"},
{n="机场区",x1=3250,z1=3250,x2=4250,z2=4250,c=Color3.fromRGB(200,200,210),s="ware"},
{n="娱乐区",x1=750,z1=750,x2=1750,z2=1750,c=Color3.fromRGB(200,120,180),s="shop"},
{n="郊区",x1=1750,z1=750,x2=4250,z2=1750,c=Color3.fromRGB(160,180,140),s="res"},
}

function NP(p,sz,cf,col,mat,shape)local q=Instance.new("Part")q.Size=sz q.CFrame=cf q.Color=col
q.Material=mat or Enum.Material.SmoothPlastic q.Anchored=true q.CanCollide=true
q.TopSurface=Enum.SurfaceType.Smooth q.BottomSurface=Enum.SurfaceType.Smooth
if shape then q.Shape=shape end q.Parent=p return q end

AddT(1)NP(City,Vector3.new(BIG,4,BIG),CFrame.new(CEN),Color3.fromRGB(70,120,70),Enum.Material.Grass)Tick("地面")
for _,r in ipairs(Region)do local cx=(r.x1+r.x2)/2 local cz=(r.z1+r.z2)/2
local w=r.x2-r.x1 local d=r.z2-r.z1 local mat=Enum.Material.Concrete
if r.s=="res"then mat=Enum.Material.Grass elseif r.s=="shop"then mat=Enum.Material.Brick
elseif r.s=="office"then mat=Enum.Material.Marble end
local g=NP(City,Vector3.new(w,.6,d),CFrame.new(cx,2.5,cz),r.c,mat)g.Transparency=.55 g.CanCollide=false end
Tick("区域地面")

function Hwy(cx,cz,sx,sz,w,nm)local hx=sx/2 local hz=sz/2 local Y=20
local function side(pos,szz,horiz)local dk=NP(City,szz,CFrame.new(pos.X,Y,pos.Z),Color3.fromRGB(60,60,65),Enum.Material.Concrete)
if horiz then NP(City,Vector3.new(szz.X,2,1),CFrame.new(pos.X,Y+szz.Y/2+1,pos.Z-szz.Z/2+.5),Color3.fromRGB(200,200,210),Enum.Material.Metal).CanCollide=false
NP(City,Vector3.new(szz.X,2,1),CFrame.new(pos.X,Y+szz.Y/2+1,pos.Z+szz.Z/2-.5),Color3.fromRGB(200,200,210),Enum.Material.Metal).CanCollide=false
local i=-hx while i<hx do NP(City,Vector3.new(15,.2,1.2),CFrame.new(pos.X+i,Y+szz.Y/2+.15,pos.Z),Color3.fromRGB(255,255,200)).CanCollide=false i=i+30 end
else NP(City,Vector3.new(1,2,szz.Z),CFrame.new(pos.X-szz.X/2+.5,Y+szz.Y/2+1,pos.Z),Color3.fromRGB(200,200,210),Enum.Material.Metal).CanCollide=false
NP(City,Vector3.new(1,2,szz.Z),CFrame.new(pos.X+szz.X/2-.5,Y+szz.Y/2+1,pos.Z),Color3.fromRGB(200,200,210),Enum.Material.Metal).CanCollide=false
local i=-hz while i<hz do NP(City,Vector3.new(1.2,.2,15),CFrame.new(pos.X,Y+szz.Y/2+.15,pos.Z+i),Color3.fromRGB(255,255,200)).CanCollide=false i=i+30 end end end
side(Vector3.new(cx,0,cz-hz),Vector3.new(sx,1,w),true)side(Vector3.new(cx,0,cz+hz),Vector3.new(sx,1,w),true)
side(Vector3.new(cx-hx,0,cz),Vector3.new(w,1,sz),false)side(Vector3.new(cx+hx,0,cz),Vector3.new(w,1,sz),false)
for i=0,math.floor(sx/200)do for _,z in ipairs({cz-hz,cz+hz})do local x=cx-hx+i*200
NP(City,Vector3.new(6,Y,6),CFrame.new(x,Y/2,z),Color3.fromRGB(120,120,125),Enum.Material.Concrete)end end
for i=0,math.floor(sz/200)do for _,x in ipairs({cx-hx,cx+hx})do local z=cz-hz+i*200
NP(City,Vector3.new(6,Y,6),CFrame.new(x,Y/2,z),Color3.fromRGB(120,120,125),Enum.Material.Concrete)end end end
end
Hwy(CEN.X,CEN.Z,4000,4000,100,"外环")Hwy(CEN.X,CEN.Z,2500,2500,80,"内环")Tick("高速")

function Overpass(x,z,o)local Y=20
if o=="H"then NP(City,Vector3.new(200,2,30),CFrame.new(x,Y,z),Color3.fromRGB(70,70,75),Enum.Material.Concrete)
NP(City,Vector3.new(200,1.5,1),CFrame.new(x,Y+1.5,z-14),Color3.fromRGB(200,200,210),Enum.Material.Metal).CanCollide=false
NP(City,Vector3.new(200,1.5,1),CFrame.new(x,Y+1.5,z+14),Color3.fromRGB(200,200,210),Enum.Material.Metal).CanCollide=false
else NP(City,Vector3.new(30,2,200),CFrame.new(x,Y,z),Color3.fromRGB(70,70,75),Enum.Material.Concrete)
NP(City,Vector3.new(1,1.5,200),CFrame.new(x-14,Y+1.5,z),Color3.fromRGB(200,200,210),Enum.Material.Metal).CanCollide=false
NP(City,Vector3.new(1,1.5,200),CFrame.new(x+14,Y+1.5,z),Color3.fromRGB(200,200,210),Enum.Material.Metal).CanCollide=false end
NP(City,Vector3.new(4,Y,4),CFrame.new(x-60,Y/2,z),Color3.fromRGB(120,120,125),Enum.Material.Concrete)
NP(City,Vector3.new(4,Y,4),CFrame.new(x+60,Y/2,z),Color3.fromRGB(120,120,125),Enum.Material.Concrete)end
Overpass(CEN.X-2000,CEN.Z,"H")Overpass(CEN.X+2000,CEN.Z,"H")Overpass(CEN.X,CEN.Z-2000,"V")Overpass(CEN.X,CEN.Z+2000,"V")
Overpass(CEN.X-1250,CEN.Z,"H")Overpass(CEN.X+1250,CEN.Z,"H")Overpass(CEN.X,CEN.Z-1250,"V")Overpass(CEN.X,CEN.Z+1250,"V")Tick("立交")

function Tunnel(x1,z1,x2,z2,w,h)local dx=x2-x1 local dz=z2-z1 local ln=math.sqrt(dx*dx+dz*dz)
local mx=(x1+x2)/2 local mz=(z1+z2)/2 local a=math.atan2(dx,dz)
NP(City,Vector3.new(w+4,2,ln),CFrame.new(mx,-2,mz)*CFrame.Angles(0,a,0),Color3.fromRGB(90,90,95),Enum.Material.Concrete)
for _,sgn in ipairs({-1,1})do local cf=CFrame.new(mx,-h/2-4,mz)*CFrame.Angles(0,a,0)*CFrame.new(sgn*(w/2+1),0,0)
NP(City,Vector3.new(2,h,ln),cf,Color3.fromRGB(100,100,105),Enum.Material.Concrete)end
NP(City,Vector3.new(w,1,ln),CFrame.new(mx,-6,mz)*CFrame.Angles(0,a,0),Color3.fromRGB(50,50,55),Enum.Material.Asphalt)
for i=1,math.floor(ln/40)do local t=i/math.floor(ln/40)local lx=x1+dx*t local lz=z1+dz*t
local lm=NP(City,Vector3.new(.5,.5,3),CFrame.new(lx,-1.5,lz)*CFrame.Angles(0,a,0),Color3.fromRGB(255,240,200),Enum.Material.Neon)lm.CanCollide=false
local li=Instance.new("PointLight")li.Range=30 li.Brightness=1.2 li.Color=Color3.fromRGB(255,240,200)li.Parent=lm end end
Tunnel(CEN.X-400,CEN.Z-400,CEN.X+400,CEN.Z+400,30,10)Tunnel(CEN.X+400,CEN.Z-400,CEN.X-400,CEN.Z+400,30,10)Tick("隧道")

-- 区域建筑
function BldOffice(cx,cz,w,d,h)NP(Builds,Vector3.new(w,h,d),CFrame.new(cx,h/2,cz),Color3.fromRGB(150,160,180),Enum.Material.Concrete)
for i=1,math.floor(h/6)do NP(Builds,Vector3.new(w+.4,4,.3),CFrame.new(cx,i*6-2,cz+d/2+.2),Color3.fromRGB(140,180,220),Enum.Material.Glass).Transparency=.4
NP(Builds,Vector3.new(w+.4,4,.3),CFrame.new(cx,i*6-2,cz-d/2-.2),Color3.fromRGB(140,180,220),Enum.Material.Glass).Transparency=.4 end
NP(Builds,Vector3.new(w+1,1,d+1),CFrame.new(cx,h+.5,cz),Color3.fromRGB(90,90,100),Enum.Material.Slate)end
function BldShop(cx,cz,w,d,h)NP(Builds,Vector3.new(w,h,d),CFrame.new(cx,h/2,cz),Color3.fromRGB(180,140,120),Enum.Material.Brick)
NP(Builds,Vector3.new(w,1.5,d),CFrame.new(cx,h+.75,cz),Color3.fromRGB(120,90,80),Enum.Material.Wood)
NP(Builds,Vector3.new(w-2,2,.4),CFrame.new(cx,h-1,cz+d/2+.3),Color3.fromRGB(200,100,100),Enum.Material.Neon)end
function BldRes(cx,cz,w,d,h)NP(Builds,Vector3.new(w,h,d),CFrame.new(cx,h/2,cz),Color3.fromRGB(160,180,160),Enum.Material.Concrete)
for f=1,math.floor(h/7)do for i=1,2 do
NP(Builds,Vector3.new(2,2.5,.3),CFrame.new(cx-w/4+i*w/2,f*7-2,cz+d/2+.2),Color3.fromRGB(200,220,240),Enum.Material.Glass)
NP(Builds,Vector3.new(2,2.5,.3),CFrame.new(cx-w/4+i*w/2,f*7-2,cz-d/2-.2),Color3.fromRGB(200,220,240),Enum.Material.Glass)end end
NP(Builds,Vector3.new(w+1,1,d+1),CFrame.new(cx,h+.5,cz),Color3.fromRGB(90,90,100),Enum.Material.Slate)end
function BldWare(cx,cz,w,d,h)NP(Builds,Vector3.new(w,h,d),CFrame.new(cx,h/2,cz),Color3.fromRGB(150,150,155),Enum.Material.CorrodedMetal)
NP(Builds,Vector3.new(w+2,1.5,d+2),CFrame.new(cx,h+.75,cz),Color3.fromRGB(100,100,110),Enum.Material.CorrodedMetal)
NP(Builds,Vector3.new(2.5,h+4,2.5),CFrame.new(cx+w/3,(h+4)/2,cz+d/3),Color3.fromRGB(80,80,85),Enum.Material.Brick)end
Blds={office=BldOffice,shop=BldShop,res=BldRes,ware=BldWare}
function FillR(r)local st=Blds[r.s]or BldShop local cs=80 local mg=20
local gx=math.floor((r.x2-r.x1-mg*2)/cs)local gz=math.floor((r.z2-r.z1-mg*2)/cs)local cnt=0
for i=0,gx-1 do for j=0,gz-1 do if math.random()<.6 then
local cx=r.x1+mg+i*cs+cs/2 local cz=r.z1+mg+j*cs+cs/2
local w=math.random(30,60)local d=math.random(30,60)local h
if r.s=="office"then h=math.random(60,120)elseif r.s=="ware"then h=math.random(15,25)
elseif r.s=="res"then h=math.random(20,40)else h=math.random(15,30)end
st(cx,cz,w,d,h)cnt=cnt+1 if cnt%5==0 then task.wait()end end end end return cnt end
for _,r in ipairs(Region)do FillR(r)task.wait(.2)end Tick("区域建筑")

-- 机场跑道
NP(City,Vector3.new(500,1,60),CFrame.new(3700,3,3750),Color3.fromRGB(45,45,50),Enum.Material.Concrete)
for i=-240,240,30 do NP(City,Vector3.new(15,.2,2),CFrame.new(3700+i,3.6,3750),Color3.fromRGB(255,255,255)).CanCollide=false end
for i=-240,240,40 do local l1=NP(City,Vector3.new(.6,.6,.6),CFrame.new(3700+i,3.5,3720),Color3.fromRGB(255,220,80),Enum.Material.Neon)l1.CanCollide=false
local l2=NP(City,Vector3.new(.6,.6,.6),CFrame.new(3700+i,3.5,3780),Color3.fromRGB(255,220,80),Enum.Material.Neon)l2.CanCollide=false end
NP(City,Vector3.new(120,25,50),CFrame.new(3700,12.5,3600),Color3.fromRGB(200,200,210),Enum.Material.Glass)Tick("机场")

-- 港口
NP(City,Vector3.new(400,2,100),CFrame.new(1250,3,3750),Color3.fromRGB(140,140,145),Enum.Material.Concrete)
NP(City,Vector3.new(200,20,40),CFrame.new(1250,12,3650),Color3.fromRGB(150,50,50),Enum.Material.Metal)
for i=1,8 do NP(City,Vector3.new(12,10,10),CFrame.new(1190+i*15,27,3650),Color3.fromHSV(i/8,.8,.9),Enum.Material.Metal)end
NP(City,Vector3.new(3,60,3),CFrame.new(1100,30,3750),Color3.fromRGB(220,200,50),Enum.Material.Metal)
NP(City,Vector3.new(60,3,3),CFrame.new(1130,58,3750),Color3.fromRGB(220,200,50),Enum.Material.Metal)Tick("港口")

-- 收集地块坐标
for _,r in ipairs(Region)do
for gx=0,5 do for gz=0,5 do
local x=r.x1+40+gx*130 local z=r.z1+40+gz*130
if x<r.x2-40 and z<r.z2-40 then table.insert(S.Cells,Vector3.new(x,3,z))end end end end

-- ============== 门/内饰 ==============
function Hinge(p,pos,sz,col,mat,sw)local fr=NP(p,Vector3.new(sz.X+.4,sz.Y+.4,.4),CFrame.new(pos),Color3.fromRGB(50,50,55),Enum.Material.Metal)fr.CanCollide=false
local d=NP(p,sz,CFrame.new(pos)*CFrame.new(-sz.X/2,0,0),col or Color3.fromRGB(180,210,230),mat or Enum.Material.Glass)
d.Transparency=mat==Enum.Material.Glass and .4 or 0 d.Name="Hinge"
local hp=pos+Vector3.new(-sz.X/2,0,0)local cc=CFrame.new(hp)*CFrame.new(sz.X/2,0,0)local ang=sw or math.rad(90)
local op=false
task.spawn(function()while d.Parent do task.wait(.3)local c=LP.Character local h=c and c:FindFirstChild("HumanoidRootPart")
if h then local dd=(h.Position-d.Position).Magnitude
if dd<8 and not op then op=true TS:Create(d,TweenInfo.new(.35),{CFrame=CFrame.new(hp)*CFrame.Angles(0,ang,0)*CFrame.new(sz.X/2,0,0)}):Play()
elseif dd>12 and op then op=false TS:Create(d,TweenInfo.new(.35),{CFrame=cc}):Play()end end end end)end
function Rollup(p,pos,sz,col)local fr=NP(p,Vector3.new(sz.X+.6,sz.Y+.6,.4),CFrame.new(pos),Color3.fromRGB(60,60,65),Enum.Material.Metal)fr.CanCollide=false
local d=NP(p,sz,CFrame.new(pos+Vector3.new(0,0,.25)),col or Color3.fromRGB(130,130,140),Enum.Material.Metal)d.Name="Roll"
local cp=d.Position local op=false
task.spawn(function()while d.Parent do task.wait(.4)local c=LP.Character local h=c and c:FindFirstChild("HumanoidRootPart")
if h then local dd=(h.Position-d.Position).Magnitude
if dd<10 and not op then op=true TS:Create(d,TweenInfo.new(.6),{Position=cp+Vector3.new(0,sz.Y-.5,0)}):Play()
elseif dd>14 and op then op=false TS:Create(d,TweenInfo.new(.6),{Position=cp}):Play()end end end end)end

function BFloor(p,ct,w,d,y,col,mat)return NP(p,Vector3.new(w,.4,d),CFrame.new(ct+Vector3.new(0,y,0)),col or Color3.fromRGB(180,175,165),mat or Enum.Material.Concrete)end
function BCeil(p,ct,w,d,y,col)return NP(p,Vector3.new(w,.4,d),CFrame.new(ct+Vector3.new(0,y,0)),col or Color3.fromRGB(230,230,235),Enum.Material.SmoothPlastic)end
function BWall(p,pos,sz,col,mat,tr)return NP(p,sz,CFrame.new(pos),col or Color3.fromRGB(200,200,205),mat or Enum.Material.Concrete,tr)end
function BLight(p,pos)local b=NP(p,Vector3.new(1.4,1.4,1.4),CFrame.new(pos),Color3.fromRGB(255,240,200),Enum.Material.Neon,Enum.PartType.Ball)b.CanCollide=false
local l=Instance.new("PointLight")l.Range=22 l.Brightness=1.6 l.Color=Color3.fromRGB(255,240,200)l.Parent=b end
function BFlour(p,pos,ln)local t=NP(p,Vector3.new(ln or 6,.3,.8),CFrame.new(pos),Color3.fromRGB(230,240,255),Enum.Material.Neon)t.CanCollide=false
local l=Instance.new("PointLight")l.Range=18 l.Brightness=1.4 l.Color=Color3.fromRGB(220,230,255)l.Parent=t end
function BTable(p,pos,sz,col)NP(p,Vector3.new(sz.X,.3,sz.Z),CFrame.new(pos+Vector3.new(0,sz.Y,0)),col or Color3.fromRGB(120,80,50),Enum.Material.Wood)
for dx=-1,1,2 do for dz=-1,1,2 do NP(p,Vector3.new(.3,sz.Y,.3),CFrame.new(pos+Vector3.new(dx*(sz.X/2-.3),sz.Y/2,dz*(sz.Z/2-.3))),Color3.fromRGB(80,60,40),Enum.Material.Wood)end end end
function BChair(p,pos,col)NP(p,Vector3.new(1.6,.3,1.6),CFrame.new(pos+Vector3.new(0,1.5,0)),col or Color3.fromRGB(80,80,90))
NP(p,Vector3.new(1.6,1.6,.2),CFrame.new(pos+Vector3.new(0,2.3,.7)),col or Color3.fromRGB(80,80,90))
for dx=-1,1,2 do for dz=-1,1,2 do NP(p,Vector3.new(.15,1.5,.15),CFrame.new(pos+Vector3.new(dx*.6,.75,dz*.6)),Color3.fromRGB(50,50,55),Enum.Material.Metal)end end end
function BBed(p,pos)NP(p,Vector3.new(4,.6,7),CFrame.new(pos+Vector3.new(0,1,0)),Color3.fromRGB(90,60,40),Enum.Material.Wood)
NP(p,Vector3.new(3.8,.6,6.8),CFrame.new(pos+Vector3.new(0,1.6,0)),Color3.fromRGB(240,240,250),Enum.Material.Fabric)
NP(p,Vector3.new(3,.4,1.6),CFrame.new(pos+Vector3.new(0,2.1,-2.4)),Color3.fromRGB(255,255,255),Enum.Material.Fabric)end
function BShelf(p,pos,sz,col)NP(p,sz,CFrame.new(pos+Vector3.new(0,sz.Y/2,0)),col or Color3.fromRGB(140,110,80),Enum.Material.Wood)
for i=1,3 do NP(p,Vector3.new(sz.X-.2,.2,sz.Z-.2),CFrame.new(pos+Vector3.new(0,sz.Y/4*i,0)),Color3.fromRGB(100,80,60),Enum.Material.Wood)end end
function BCash(p,pos)NP(p,Vector3.new(8,3,2),CFrame.new(pos+Vector3.new(0,1.5,0)),Color3.fromRGB(90,70,50),Enum.Material.Wood)
NP(p,Vector3.new(2,1.2,1.5),CFrame.new(pos+Vector3.new(2,3.6,-.5)),Color3.fromRGB(50,50,55))end
function BFridge(p,pos,sz)local f=NP(p,sz,CFrame.new(pos+Vector3.new(0,sz.Y/2,0)),Color3.fromRGB(230,230,235),Enum.Material.Glass)f.Transparency=.4
local i2=NP(p,sz-Vector3.new(.4,.4,.4),CFrame.new(f.Position),Color3.fromRGB(180,220,255),Enum.Material.Neon)i2.Transparency=.7 i2.CanCollide=false end
function BElevator(p,pos,sz)local s=NP(p,Vector3.new(sz.X+1,sz.Y,sz.Z+1),CFrame.new(pos+Vector3.new(0,sz.Y/2,0)),Color3.fromRGB(80,80,90),Enum.Material.Metal)s.Transparency=.85 s.CanCollide=false
local ld=NP(p,Vector3.new(sz.X/2-.2,sz.Y,.3),CFrame.new(pos+Vector3.new(-sz.X/4,sz.Y/2,sz.Z/2+.2)),Color3.fromRGB(180,185,200),Enum.Material.Metal)
local rd=NP(p,Vector3.new(sz.X/2-.2,sz.Y,.3),CFrame.new(pos+Vector3.new(sz.X/4,sz.Y/2,sz.Z/2+.2)),Color3.fromRGB(180,185,200),Enum.Material.Metal)
local lc,rc=ld.Position,rd.Position local op=false
task.spawn(function()while ld.Parent do task.wait(.3)local c=LP.Character local h=c and c:FindFirstChild("HumanoidRootPart")
if h then local dd=(h.Position-pos).Magnitude
if dd<8 and not op then op=true TS:Create(ld,TweenInfo.new(.5),{Position=lc+Vector3.new(-sz.X/2+.3,0,0)}):Play()
TS:Create(rd,TweenInfo.new(.5),{Position=rc+Vector3.new(sz.X/2-.3,0,0)}):Play()
elseif dd>12 and op then op=false TS:Create(ld,TweenInfo.new(.5),{Position=lc}):Play()
TS:Create(rd,TweenInfo.new(.5),{Position=rc}):Play()end end end end)end

function Interior(t,ct,w,d,h)local f=Inter
if t=="apt"then BFloor(f,ct,w-1,d-1,.6,Color3.fromRGB(200,190,175),Enum.Material.Marble)BCeil(f,ct,w-1,d-1,8)
BLight(f,ct+Vector3.new(0,7.5,0))BTable(f,ct+Vector3.new(0,0,-d/3),Vector3.new(6,2.5,2))
BElevator(f,ct+Vector3.new(w/4,0,-d/4),Vector3.new(4,8,4))
for floor=1,math.floor(h/8)-1 do local y=floor*8 BFloor(f,ct,w-1,d-1,y+.6)BCeil(f,ct,w-1,d-1,y+4)
for i=0,2 do BFlour(f,ct+Vector3.new(-w/2+4+i*((w-8)/2),y+3.7,0),3)end
for room=1,3 do local rx=-w/4+(room-1)*(w/4)local rc=ct+Vector3.new(rx,y,d/4)
BWall(f,rc+Vector3.new(0,2,-d/4+.5),Vector3.new(w/4-.5,4,.3))
BBed(f,rc+Vector3.new(-1,0,1))BTable(f,rc+Vector3.new(2,0,-1),Vector3.new(3,2,2))
BChair(f,rc+Vector3.new(2,0,.8))end end
elseif t=="shop"then BFloor(f,ct,w-1,d-1,.6,Color3.fromRGB(200,200,190),Enum.Material.Tile)BCeil(f,ct,w-1,d-1,h-1)
for i=1,3 do BFlour(f,ct+Vector3.new(-w/2+i*((w-2)/3),h-2,0),4)end
for row=1,3 do BShelf(f,ct+Vector3.new(-w/3+(row-1)*w/3,0,0),Vector3.new(3,5,2))end
BCash(f,ct+Vector3.new(w/2-3,0,-d/2+3))Rollup(f,ct+Vector3.new(0,0,-d/2+.5),Vector3.new(4,5,.3))
elseif t=="office"then BFloor(f,ct,w-1,d-1,.6,Color3.fromRGB(220,215,205),Enum.Material.Marble)BCeil(f,ct,w-1,d-1,8)
BLight(f,ct+Vector3.new(0,7.5,0))BElevator(f,ct+Vector3.new(0,0,-d/4),Vector3.new(4,8,4))
for floor=1,math.floor(h/6)-1 do local y=floor*6 BFloor(f,ct,w-1,d-1,y+.6)BCeil(f,ct,w-1,d-1,y+4)
for i=1,3 do BTable(f,ct+Vector3.new(-w/4+(i-1)*(w/4),y,0),Vector3.new(5,2.5,2.5))BChair(f,ct+Vector3.new(-w/4+(i-1)*(w/4),y,2))end end
elseif t=="ware"then BFloor(f,ct,w-1,d-1,.6,Color3.fromRGB(150,145,140),Enum.Material.Concrete)BCeil(f,ct,w-1,d-1,h-1,Color3.fromRGB(180,180,190))
for i=1,4 do BFlour(f,ct+Vector3.new(-w/3+(i-1)*(w/4),h-2,0),5)end
for row=1,4 do BShelf(f,ct+Vector3.new(-w/2+row*(w/5),0,-d/4),Vector3.new(2.5,7,3))end
Rollup(f,ct+Vector3.new(-w/4,0,d/2),Vector3.new(6,7,.3))Rollup(f,ct+Vector3.new(w/4,0,d/2),Vector3.new(6,7,.3))
elseif t=="conv"then BFloor(f,ct,w-1,d-1,.6,Color3.fromRGB(235,235,235),Enum.Material.Tile)BCeil(f,ct,w-1,d-1,h-1,Color3.fromRGB(245,245,245))
for i=1,3 do BFlour(f,ct+Vector3.new(-w/3+(i-1)*(w/3),h-2,0),4)end
for row=1,4 do BShelf(f,ct+Vector3.new(-w/2+row*(w/5),0,0),Vector3.new(2.5,4,2))end
BFridge(f,ct+Vector3.new(-w/2+2,0,-d/2+2),Vector3.new(2.5,5,3))BCash(f,ct+Vector3.new(w/2-3,0,-d/2+3))
elseif t=="rest"then BFloor(f,ct,w-1,d-1,.6,Color3.fromRGB(200,180,150),Enum.Material.WoodPlanks)BCeil(f,ct,w-1,d-1,h-1,Color3.fromRGB(240,230,220))
for i=1,3 do BLight(f,ct+Vector3.new(-w/3+(i-1)*(w/3),h-2,0))end
for i=1,6 do local tx=-w/3+((i-1)%3)*(w/3)local tz=-d/4+math.floor((i-1)/3)*(d/2)
local tp=ct+Vector3.new(tx,0,tz)BTable(f,tp,Vector3.new(3,2.5,3))BChair(f,tp+Vector3.new(2,0,0))BChair(f,tp+Vector3.new(-2,0,0))end
elseif t=="hosp"then BFloor(f,ct,w-1,d-1,.6,Color3.fromRGB(240,240,245),Enum.Material.Tile)BCeil(f,ct,w-1,d-1,h-1,Color3.fromRGB(250,250,255))
for i=1,4 do BFlour(f,ct+Vector3.new(-w/3+(i-1)*(w/4),h-2,0),4)end
for i=1,6 do BChair(f,ct+Vector3.new(-w/2+2+i*1.8,0,-d/4),Color3.fromRGB(80,120,160))end
BCash(f,ct+Vector3.new(0,0,-d/2+3))BBed(f,ct+Vector3.new(-w/4+2,0,d/2-3))BBed(f,ct+Vector3.new(w/4-2,0,d/2-3))
elseif t=="pol"then BFloor(f,ct,w-1,d-1,.6,Color3.fromRGB(190,190,200),Enum.Material.Concrete)BCeil(f,ct,w-1,d-1,h-1,Color3.fromRGB(220,220,230))
for i=1,3 do BFlour(f,ct+Vector3.new(-w/3+(i-1)*(w/3),h-2,0),4)end BCash(f,ct+Vector3.new(0,0,-d/2+3))
for i=1,3 do BTable(f,ct+Vector3.new(-w/3+(i-1)*(w/3),0,0),Vector3.new(5,2.5,2.5))end end end

function AddEnter(t,ct,w,d,h)local dp=ct+Vector3.new(0,0,d/2+.3)
if t=="ware"or t=="shop"or t=="conv"then Rollup(Inter,dp,Vector3.new(4,6,.3))
elseif t=="office"then Hinge(Inter,dp,Vector3.new(4,6,.3),Color3.fromRGB(180,200,230),Enum.Material.Glass,math.rad(90))
else Hinge(Inter,dp,Vector3.new(4,6,.3),Color3.fromRGB(180,210,230),Enum.Material.Glass,math.rad(90))end
Interior(t,ct,w,d,h)end

task.spawn(function()task.wait(1)local pp=PP()or Vector3.new(2500,0,2500)
table.sort(S.Cells,function(a,b)return(a-pp).Magnitude<(b-pp).Magnitude end)
local types={"shop","office","rest","conv","hosp","pol","ware","apt"}
for i=1,math.min(30,#S.Cells)do local c=S.Cells[i]AddEnter(types[(i-1)%#types+1],c,18,18,14)
if i%3==0 then task.wait()end end Noti("30栋内饰已生成",Color3.fromRGB(120,220,160))end)Tick("内饰")

-- ============== NPC/车/天气 ==============
SkinC={Color3.fromRGB(255,220,180),Color3.fromRGB(240,200,160),Color3.fromRGB(200,160,120),Color3.fromRGB(160,120,90)}
ShirtC={Color3.fromRGB(200,60,60),Color3.fromRGB(60,120,200),Color3.fromRGB(60,180,80),Color3.fromRGB(220,200,80),Color3.fromRGB(150,80,180),Color3.fromRGB(80,80,90)}
PantC={Color3.fromRGB(40,40,60),Color3.fromRGB(80,60,40),Color3.fromRGB(60,60,70)}
function MkNPC(nm)local m=Instance.new("Model")m.Name=nm
local tp=Instance.new("Part")tp.Name="Torso"tp.Size=Vector3.new(2,2,1)tp.Color=ShirtC[math.random(1,#ShirtC)]tp.Parent=m
local hd=Instance.new("Part")hd.Name="Head"hd.Shape=Enum.PartType.Ball hd.Size=Vector3.new(1.6,1.6,1.6)
hd.Color=SkinC[math.random(1,#SkinC)]hd.Parent=m
local la=Instance.new("Part")la.Name="Left Arm"la.Size=Vector3.new(1,2,1)la.Color=tp.Color la.Parent=m
local ra=Instance.new("Part")ra.Name="Right Arm"ra.Size=Vector3.new(1,2,1)ra.Color=tp.Color ra.Parent=m
local pc=PantC[math.random(1,#PantC)]
local ll=Instance.new("Part")ll.Name="Left Leg"ll.Size=Vector3.new(1,2,1)ll.Color=pc ll.Parent=m
local rl=Instance.new("Part")rl.Name="Right Leg"rl.Size=Vector3.new(1,2,1)rl.Color=pc rl.Parent=m
local hp=Instance.new("Part")hp.Name="HumanoidRootPart"hp.Size=Vector3.new(2,2,1)hp.Transparency=1 hp.Parent=m
local hum=Instance.new("Humanoid")hum.RigType=Enum.HumanoidRigType.R6 hum.Parent=m
local function mj(n,p0,p1,c0)local mo=Instance.new("Motor6D")mo.Name=n mo.Part0=p0 mo.Part1=p1 mo.C0=c0 mo.Parent=p0 end
mj("RootJoint",hp,tp,CFrame.new(0,0,0))mj("Neck",tp,hd,CFrame.new(0,1,0))
mj("Left Shoulder",tp,la,CFrame.new(-1,.5,0))mj("Right Shoulder",tp,ra,CFrame.new(1,.5,0))
mj("Left Hip",tp,ll,CFrame.new(-.5,-1,0))mj("Right Hip",tp,rl,CFrame.new(.5,-1,0))return m end
function NPWalk(m,wps)local h=m:FindFirstChildOfClass("Humanoid")if not h then return end
local i=1 task.spawn(function()while m.Parent and h.Health>0 do local w=wps[i]h:MoveTo(w)
local st=tick()while(m.HumanoidRootPart.Position-w).Magnitude>4 and tick()-st<15 do task.wait(.3)end
i=i%#wps+1 task.wait(.2)end end)end
function SpawnPed(pos)local m=MkNPC("Ped")m.HumanoidRootPart.CFrame=CFrame.new(pos)m.Parent=NPCF
local wps={}for i=1,4 do table.insert(wps,pos+Vector3.new(math.random(-80,80),0,math.random(-80,80)))end
NPWalk(m,wps)table.insert(S.NPCs,{model=m,type="ped"})return m end
function SpawnDrunk(pos)local m=SpawnPed(pos)m.Name="Drunk"local h=m:FindFirstChildOfClass("Humanoid")if h then h.WalkSpeed=6 end
task.spawn(function()while m.Parent do task.wait(.5)local hp=m:FindFirstChild("HumanoidRootPart")
if hp then hp.CFrame=hp.CFrame*CFrame.Angles(0,math.rad(math.random(-15,15)),0)end end end)end
function SpawnCop(pos)local m=SpawnPed(pos)m.Name="Cop"local t=m:FindFirstChild("Torso")
if t then t.Color=Color3.fromRGB(40,60,120)m["Left Arm"].Color=t.Color m["Right Arm"].Color=t.Color end end
task.spawn(function()task.wait(2)for i=1,60 do local r=Region[math.random(1,#Region)]
local pos=Vector3.new(math.random(r.x1,r.x2),3,math.random(r.z1,r.z2))
if math.random()<.15 then SpawnDrunk(pos)elseif math.random()<.15 then SpawnCop(pos)else SpawnPed(pos)end
if i%5==0 then task.wait()end end Noti("60 NPC已生成",Color3.fromRGB(200,180,255))end)Tick("NPC")

CarT={{"A",Color3.fromRGB(200,50,50),6,3,12,60},{"B",Color3.fromRGB(50,100,200),6,3,12,60},
{"C",Color3.fromRGB(200,200,200),6,3,12,60},{"SUV",Color3.fromRGB(80,80,80),7,4,14,55},
{"跑车",Color3.fromRGB(220,30,30),6,2.5,12,90},{"卡车",Color3.fromRGB(100,100,100),8,6,18,45},
{"公交",Color3.fromRGB(200,180,60),8,7,24,40},{"出租",Color3.fromRGB(255,220,50),6,3,12,60},
{"警车",Color3.fromRGB(20,30,80),6,3,12,70},{"救护",Color3.fromRGB(240,240,240),7,5,14,65},
{"消防",Color3.fromRGB(220,40,40),8,6,18,50},{"摩托",Color3.fromRGB(30,30,30),2,3,5,80},
{"皮卡",Color3.fromRGB(120,80,60),7,4,14,55},{"厢货",Color3.fromRGB(230,230,230),7,6,16,50},
{"面包",Color3.fromRGB(180,180,200),7,5,14,55},{"敞篷",Color3.fromRGB(230,100,180),6,2.5,12,75},
{"越野",Color3.fromRGB(80,120,60),7,4,14,60},{"豪华",Color3.fromRGB(20,20,20),6,3,13,70},
{"运钞",Color3.fromRGB(80,80,100),7,5,14,55},{"垃圾",Color3.fromRGB(70,100,70),8,6,18,40},
{"清障",Color3.fromRGB(240,180,60),8,6,18,45},{"校车",Color3.fromRGB(240,200,30),8,7,22,40},
{"跑车2",Color3.fromRGB(80,20,80),6,2.5,12,95},{"摩托警",Color3.fromRGB(240,240,240),2,3,5,85},
{"双层巴",Color3.fromRGB(200,60,60),8,10,24,35},{"消防2",Color3.fromRGB(240,60,60),8,6,18,50},
{"轿车D",Color3.fromRGB(150,150,100),6,3,12,60},{"轿车E",Color3.fromRGB(100,150,150),6,3,12,60},
{"SUV2",Color3.fromRGB(120,60,80),7,4,14,55},{"出租2",Color3.fromRGB(240,200,30),6,3,12,60}}
function MkCar(def)local n,col,sx,sy,sz,sp=table.unpack(def)local m=Instance.new("Model")m.Name=n
local bd=Instance.new("Part")bd.Size=Vector3.new(sx,sy,sz)bd.Color=col bd.Name="Body"bd.Parent=m
local ws=Instance.new("Part")ws.Size=Vector3.new(sx*.9,sy*.5,sz*.4)ws.Color=Color3.fromRGB(60,80,120)
ws.Material=Enum.Material.Glass ws.Transparency=.4 ws.CanCollide=false ws.Parent=m
local hl=Instance.new("Part")hl.Size=Vector3.new(.6,.6,.3)hl.Color=Color3.fromRGB(255,240,200)hl.Material=Enum.Material.Neon hl.Parent=m
local hr=Instance.new("Part")hr.Size=Vector3.new(.6,.6,.3)hr.Color=Color3.fromRGB(255,240,200)hr.Material=Enum.Material.Neon hr.Parent=m
local tl=Instance.new("Part")tl.Size=Vector3.new(.6,.6,.3)tl.Color=Color3.fromRGB(255,40,40)tl.Material=Enum.Material.Neon tl.Parent=m
local tr=Instance.new("Part")tr.Size=Vector3.new(.6,.6,.3)tr.Color=Color3.fromRGB(255,40,40)tr.Material=Enum.Material.Neon tr.Parent=m
local wp={{-sx/2+.5,-sy/2+.5,-sz/3},{sx/2-.5,-sy/2+.5,-sz/3},{-sx/2+.5,-sy/2+.5,sz/3},{sx/2-.5,-sy/2+.5,sz/3}}
for _,w in ipairs(wp)do local wh=Instance.new("Part")wh.Shape=Enum.PartType.Cylinder wh.Size=Vector3.new(1.2,2.4,2.4)
wh.CFrame=bd.CFrame*CFrame.new(w[1],w[2],w[3])*CFrame.Angles(0,0,math.rad(90))
wh.Color=Color3.fromRGB(30,30,30)wh.Material=Enum.Material.Rubber wh.CanCollide=false wh.Parent=m
local wc=Instance.new("WeldConstraint")wc.Part0=bd wc.Part1=wh wc.Parent=wh end
local function wl(p,o)p.CFrame=bd.CFrame*CFrame.new(o[1],o[2],o[3])
local wc=Instance.new("WeldConstraint")wc.Part0=bd wc.Part1=p wc.Parent=p end
wl(ws,{0,sy*.3,0})wl(hl,{-sx/2+.5,0,-sz/2-.2})wl(hr,{sx/2-.5,0,-sz/2-.2})wl(tl,{-sx/2+.5,0,sz/2+.2})wl(tr,{sx/2-.5,0,sz/2+.2})
m.PrimaryPart=bd m:SetAttribute("Speed",sp)return m end
task.spawn(function()task.wait(3)for i=1,40 do local r=Region[math.random(1,#Region)]
local c=MkCar(CarT[math.random(1,#CarT)])c.PrimaryPart.Anchored=true
c.PrimaryPart.CFrame=CFrame.new(math.random(r.x1,r.x2),4,math.random(r.z1,r.z2))*CFrame.Angles(0,math.random()*6.28,0)
c.Parent=VehF table.insert(S.Cars,c)if i%8==0 then task.wait()end end Noti("40车辆已生成",Color3.fromRGB(200,180,255))end)Tick("车辆")

RainF=Instance.new("Folder")RainF.Name="Rain"RainF.Parent=City
function SetWeather(w)S.Weather=w
local fc={sunny=Color3.fromRGB(200,215,235),cloudy=Color3.fromRGB(150,160,175),rainy=Color3.fromRGB(80,90,110),foggy=Color3.fromRGB(200,200,205)}
LT.FogColor=fc[w]or fc.sunny
if w=="sunny"then LT.FogEnd=4000 LT.Brightness=3
elseif w=="cloudy"then LT.FogEnd=3000 LT.Brightness=2
elseif w=="rainy"then LT.FogEnd=1500 LT.Brightness=1.2
else LT.FogEnd=500 LT.Brightness=1.5 end
for _,r in ipairs(RainF:GetChildren())do r:Destroy()end
if w=="rainy"then local c=LP.Character local h=c and c:FindFirstChild("HumanoidRootPart")
if h then for i=1,200 do local d=Instance.new("Part")d.Size=Vector3.new(.1,.8,.1)
d.Color=Color3.fromRGB(180,200,240)d.Transparency=.5 d.Anchored=true d.CanCollide=false
d.Position=h.Position+Vector3.new(math.random(-60,60),30,math.random(-60,60))d.Parent=RainF end end end
Noti("天气："..w)end
task.spawn(function()while true do task.wait(120)local ws={"sunny","sunny","cloudy","rainy","foggy"}
SetWeather(ws[math.random(1,#ws)])end end)Tick("天气")

task.spawn(function()task.wait(4)pcall(function()
local t=Instance.new("Sound")t.SoundId="rbxassetid://9046339243"t.Volume=.12 t.Looped=true t.Name="IncSim_traffic"t.Parent=SS t:Play()end)
pcall(function()local b=Instance.new("Sound")b.SoundId="rbxassetid://5159133434"b.Volume=.08 b.Looped=true b.Name="IncSim_birds"b.Parent=SS b:Play()end)end)

-- ============== 枪械 ==============
S.Guns={
{id="m4a1",n="M4A1",t="ar",d=28,fr=10,m=30,rl=2.2,pr=5000},
{id="ak47",n="AK-47",t="ar",d=35,fr=9,m=30,rl=2.4,pr=5500},
{id="scar",n="SCAR",t="ar",d=30,fr=9,m=30,rl=2.3,pr=6000},
{id="aug",n="AUG",t="ar",d=27,fr=10,m=30,rl=2.1,pr=5800},
{id="famas",n="FAMAS",t="ar",d=25,fr=11,m=30,rl=2.0,pr=5200},
{id="g36",n="G36C",t="ar",d=29,fr=9,m=30,rl=2.2,pr=5600},
{id="tar21",n="TAR-21",t="ar",d=31,fr=9,m=30,rl=2.4,pr=6200},
{id="ar15",n="AR-15",t="ar",d=32,fr=8,m=20,rl=2.2,pr=5900},
{id="m16",n="M16A4",t="ar",d=33,fr=7,m=30,rl=2.5,pr=6100},
{id="hk416",n="HK416",t="ar",d=30,fr=10,m=30,rl=2.2,pr=6800},
{id="mp5",n="MP5",t="smg",d=20,fr=13,m=30,rl=1.8,pr=3500},
{id="uzi",n="UZI",t="smg",d=18,fr=15,m=25,rl=1.7,pr=3000},
{id="p90",n="P90",t="smg",d=22,fr=14,m=50,rl=2.0,pr=4200},
{id="vector",n="Vector",t="smg",d=21,fr=16,m=25,rl=1.9,pr=4500},
{id="mp7",n="MP7",t="smg",d=19,fr=15,m=40,rl=1.8,pr=4000},
{id="mac10",n="MAC-10",t="smg",d=17,fr=17,m=30,rl=1.6,pr=2800},
{id="ump45",n="UMP-45",t="smg",d=24,fr=11,m=25,rl=1.9,pr=3800},
{id="thomp",n="汤普森",t="smg",d=23,fr=12,m=30,rl=2.2,pr=3600},
{id="awp",n="AWP",t="sniper",d=180,fr=.8,m=5,rl=3.5,pr=15000},
{id="barrett",n="巴雷特",t="sniper",d=250,fr=.6,m=10,rl=4.5,pr=22000},
{id="m24",n="M24",t="sniper",d=160,fr=1,m=5,rl=3.2,pr=12000},
{id="svd",n="SVD",t="sniper",d=120,fr=1.5,m=10,rl=3,pr=10000},
{id="kar98",n="Kar98k",t="sniper",d=170,fr=.9,m=5,rl=3.3,pr=13000},
{id="interv",n="干预者",t="sniper",d=200,fr=.7,m=5,rl=3.8,pr=18000},
{id="glock",n="格洛克",t="pistol",d=18,fr=8,m=17,rl=1.5,pr=1200},
{id="deagle",n="沙漠之鹰",t="pistol",d=65,fr=3,m=7,rl=2,pr=2500},
{id="usp",n="USP",t="pistol",d=22,fr=7,m=12,rl=1.6,pr=1500},
{id="revolv",n="左轮",t="pistol",d=75,fr=2,m=6,rl=2.4,pr=3000},
{id="beretta",n="贝瑞塔",t="pistol",d=20,fr=8,m=15,rl=1.6,pr=1300},
{id="five7",n="Five-seveN",t="pistol",d=24,fr=8,m=20,rl=1.7,pr=1800},
{id="p226",n="P226",t="pistol",d=23,fr=8,m=15,rl=1.6,pr=1400},
{id="p250",n="P250",t="pistol",d=19,fr=7,m=13,rl=1.6,pr=1000},
{id="pump",n="泵动霰弹",t="shotgun",d=45,fr=1.5,m=6,rl=2.8,pr=4500},
{id="semi_s",n="半自动霰弹",t="shotgun",d=35,fr=3,m=8,rl=3,pr=5500},
{id="double",n="双管",t="shotgun",d=80,fr=1,m=2,rl=3.5,pr=3200},
{id="saiga",n="Saiga-12",t="shotgun",d=30,fr=4,m=8,rl=3.2,pr=6500},
{id="spas",n="SPAS-12",t="shotgun",d=40,fr=2,m=8,rl=3,pr=5000},
{id="minigun",n="加特林",t="lmg",d=22,fr=25,m=200,rl=5,pr=25000},
{id="m249",n="M249",t="lmg",d=32,fr=12,m=100,rl=4.5,pr=14000},
{id="pkm",n="PKM",t="lmg",d=38,fr=11,m=100,rl=5,pr=13000},
{id="m60",n="M60",t="lmg",d=40,fr=10,m=100,rl=5.5,pr=12500},
{id="rpg",n="火箭筒",t="explo",d=250,fr=.5,m=1,rl=5,pr=35000},
{id="gl",n="榴弹",t="explo",d=180,fr=1.5,m=6,rl=4,pr=28000},
{id="c4",n="C4",t="explo",d=400,fr=.3,m=1,rl=6,pr=8000},
{id="clay",n="阔剑地雷",t="explo",d=300,fr=.3,m=1,rl=5,pr=6000},
{id="taser",n="电击枪",t="spec",d=15,fr=1,m=1,rl=3,pr=4000},
{id="tranq",n="麻醉枪",t="spec",d=10,fr=1,m=1,rl=3,pr=5500},
{id="flamer",n="火焰喷射",t="spec",d=12,fr=20,m=200,rl=4.5,pr=20000},
{id="cross",n="十字弩",t="spec",d=120,fr=1,m=1,rl=3.5,pr=9000},
{id="rail",n="电磁炮",t="spec",d=350,fr=.4,m=5,rl=5,pr=45000},
}
S.GIdx={}for _,g in ipairs(S.Guns)do S.GIdx[g.id]=g end

GShopF=Instance.new("Folder")GShopF.Name="GunShops"GShopF.Parent=City
function MkGunShop(pos,nm)local b=NP(GShopF,Vector3.new(30,12,24),CFrame.new(pos+Vector3.new(0,6,0)),Color3.fromRGB(60,55,50),Enum.Material.Concrete)
local s=NP(GShopF,Vector3.new(24,3,.4),CFrame.new(pos+Vector3.new(0,13,-12.2)),Color3.fromRGB(160,40,40),Enum.Material.Neon)
local sg=Instance.new("SurfaceGui")sg.Face=Enum.NormalId.Front sg.CanvasSize=Vector2.new(500,80)sg.Parent=s
local tl=Instance.new("TextLabel")tl.Size=UDim2.fromScale(1,1)tl.BackgroundTransparency=1
tl.Text="🔫 "..nm tl.TextColor3=Color3.fromRGB(255,255,255)tl.TextScaled=true tl.Font=Enum.Font.GothamBold tl.Parent=sg
Hinge(GShopF,pos+Vector3.new(0,0,-12),Vector3.new(4,6,.3),Color3.fromRGB(150,200,230),Enum.Material.Glass,math.rad(90))
BFloor(GShopF,pos,28,22,.6,Color3.fromRGB(120,110,100),Enum.Material.Concrete)BCeil(GShopF,pos,28,22,10,Color3.fromRGB(180,180,190))
for i=1,3 do BFlour(GShopF,pos+Vector3.new(-8+(i-1)*8,9,0),4)end
for row=1,3 do local cab=NP(GShopF,Vector3.new(12,3,2),CFrame.new(pos+Vector3.new(0,2,-6+row*4)),Color3.fromRGB(80,70,60),Enum.Material.Wood)
cab.CanCollide=false local gl=NP(GShopF,Vector3.new(12,.2,2),CFrame.new(pos+Vector3.new(0,3.5,-6+row*4)),Color3.fromRGB(200,220,240),Enum.Material.Glass)
gl.Transparency=.5 gl.CanCollide=false end
BCash(GShopF,pos+Vector3.new(8,0,8))
for i=1,3 do local tg=NP(GShopF,Vector3.new(2,2,.2),CFrame.new(pos+Vector3.new(-6+i*6,5,10.5)),Color3.fromRGB(255,240,230))
tg.Name="Target"tg:SetAttribute("IsTarget",true)
NP(GShopF,Vector3.new(.6,.6,.1),CFrame.new(pos+Vector3.new(-6+i*6,5,10.3)),Color3.fromRGB(220,40,40))end
return{pos=pos,nm=nm}end
GS1=MkGunShop(Vector3.new(3200,3,2000),"洛圣都枪店")
GS2=MkGunShop(Vector3.new(2000,3,3000),"市中心武器")
GS3=MkGunShop(Vector3.new(1000,3,2000),"黑市军火")Tick("枪店")

GShopUI=Instance.new("Frame")GShopUI.Size=UDim2.fromScale(.85,.72)GShopUI.Position=UDim2.fromScale(.075,.14)
GShopUI.Visible=false GShopUI.ZIndex=80 GShopUI.Parent=gui Glass(GShopUI,22,.6,Color3.fromRGB(24,28,38))
local gT=Instance.new("TextLabel")gT.Size=UDim2.fromScale(.85,.06)gT.Position=UDim2.fromScale(.05,.02)
gT.BackgroundTransparency=1 gT.Text="🔫 枪械店"gT.TextColor3=Color3.fromRGB(240,245,255)
gT.TextScaled=true gT.Font=Enum.Font.GothamBold gT.ZIndex=81 gT.Parent=GShopUI
local gX=MkBtn(GShopUI,"✕",UDim2.fromScale(.08,.055),UDim2.fromScale(.88,.015),0,Color3.fromRGB(120,50,50))gX.ZIndex=82
gX.Activated:Connect(function()GShopUI.Visible=false end)
GTabs=Instance.new("Frame")GTabs.Size=UDim2.fromScale(.9,.06)GTabs.Position=UDim2.fromScale(.05,.09)
GTabs.BackgroundTransparency=1 GTabs.ZIndex=81 GTabs.Parent=GShopUI
local gtl=Instance.new("UIListLayout")gtl.FillDirection=Enum.FillDirection.Horizontal gtl.Padding=UDim.new(0,3)gtl.Parent=GTabs
GList=Instance.new("ScrollingFrame")GList.Size=UDim2.fromScale(.9,.68)GList.Position=UDim2.fromScale(.05,.17)
GList.BackgroundTransparency=1 GList.BorderSizePixel=0 GList.ScrollBarThickness=4
GList.CanvasSize=UDim2.new(0,0,0,0)GList.AutomaticCanvasSize=Enum.AutomaticSize.Y GList.ClipsDescendants=true GList.ZIndex=81 GList.Parent=GShopUI
local gl2=Instance.new("UIListLayout")gl2.Padding=UDim.new(0,4)gl2.SortOrder=Enum.SortOrder.LayoutOrder gl2.Parent=GList
function RefGunList(flt)for _,c in ipairs(GList:GetChildren())do if c:IsA("TextButton")then c:Destroy()end end
local o=0 for _,g in ipairs(S.Guns)do if not flt or g.t==flt then o=o+1
local owned=S.Inv["gun_"..g.id]local tx=string.format("%s [%s] 伤%d 弹%d 速%.1f $%d%s",g.n,g.t,g.d,g.m,g.fr,g.pr,owned and " ✅"or"")
local b=MkBtn(GList,tx,UDim2.new(1,-8,0,32),UDim2.fromOffset(4,0),o,owned and Color3.fromRGB(50,100,60)or Color3.fromRGB(50,60,80))
b.ZIndex=82 local gg=g
b.Activated:Connect(function()if owned then S.Equip=g.id Noti("装备 "..gg.n)UpdGunHUD()
elseif S.Money<gg.pr then Noti("金钱不足",Color3.fromRGB(255,120,120))
else AddM(-gg.pr)S.Inv["gun_"..gg.id]=true S.Equip=gg.id Noti("购买装备 "..gg.n)RefGunList(flt)UpdGunHUD()end end)end end end
local cats={{nil,"全部"},{"ar","突击"},{"smg","冲锋"},{"sniper","狙击"},{"pistol","手枪"},{"shotgun","霰弹"},{"lmg","机枪"},{"explo","爆炸"},{"spec","特殊"}}
for i,ct in ipairs(cats)do local b=MkBtn(GTabs,ct[2],UDim2.fromScale(.105,1),UDim2.fromScale(0,0),i,Color3.fromRGB(60,80,120))
b.ZIndex=82 local k=ct[1]b.Activated:Connect(function()RefGunList(k)end)end
RegisterPoint("gs1",GS1.pos+Vector3.new(0,3,-14),"进入枪店","洛圣都",function()GShopUI.Visible=true RefGunList(nil)end)
RegisterPoint("gs2",GS2.pos+Vector3.new(0,3,-14),"进入枪店","市中心",function()GShopUI.Visible=true RefGunList(nil)end)
RegisterPoint("gs3",GS3.pos+Vector3.new(0,3,-14),"进入枪店","黑市",function()GShopUI.Visible=true RefGunList(nil)end)

Cross=Instance.new("Frame")Cross.Size=UDim2.fromOffset(30,30)Cross.AnchorPoint=Vector2.new(.5,.5)
Cross.Position=UDim2.fromScale(.5,.5)Cross.BackgroundTransparency=1 Cross.ZIndex=100 Cross.Visible=false Cross.Parent=gui
for _,d in ipairs({{0,-1},{0,1},{-1,0},{1,0}})do
local l=Instance.new("Frame")l.Size=d[1]~=0 and UDim2.fromOffset(10,2)or UDim2.fromOffset(2,10)
l.AnchorPoint=Vector2.new(.5,.5)l.Position=UDim2.new(.5,d[1]*10,.5,d[2]*10)
l.BackgroundColor3=Color3.fromRGB(80,255,80)l.BorderSizePixel=0 l.ZIndex=101 l.Parent=Cross end
CDot=Instance.new("Frame")CDot.Size=UDim2.fromOffset(2,2)CDot.AnchorPoint=Vector2.new(.5,.5)
CDot.Position=UDim2.fromScale(.5,.5)CDot.BackgroundColor3=Color3.fromRGB(255,255,255)CDot.BorderSizePixel=0 CDot.ZIndex=101 CDot.Parent=Cross

GHUD=Instance.new("Frame")GHUD.Size=UDim2.fromScale(.26,.09)GHUD.Position=UDim2.new(.72,0,.88,0)
GHUD.BackgroundTransparency=1 GHUD.ZIndex=60 GHUD.Visible=false GHUD.Parent=gui
local gN=Instance.new("TextLabel")gN.Size=UDim2.fromScale(1,.4)gN.BackgroundTransparency=1 gN.Text=""
gN.TextColor3=Color3.fromRGB(240,240,255)gN.TextScaled=true gN.Font=Enum.Font.GothamBold
gN.TextStrokeTransparency=.3 gN.ZIndex=61 gN.Parent=GHUD
local gA=Instance.new("TextLabel")gA.Size=UDim2.fromScale(1,.6)gA.Position=UDim2.fromScale(0,.4)
gA.BackgroundTransparency=1 gA.Text=""gA.TextColor3=Color3.fromRGB(255,220,120)
gA.TextScaled=true gA.Font=Enum.Font.GothamBold gA.TextStrokeTransparency=.3 gA.ZIndex=61 gA.Parent=GHUD
CurAmmo=0 MaxAmmo=0 Reloading=false LastShot=0
function UpdGunHUD()if not S.Equip then GHUD.Visible=false Cross.Visible=false return end
local g=S.GIdx[S.Equip]if not g then return end
GHUD.Visible=true Cross.Visible=true gN.Text=g.n MaxAmmo=g.m
if CurAmmo==0 or CurAmmo>MaxAmmo then CurAmmo=MaxAmmo end
gA.Text=CurAmmo.." / "..MaxAmmo end

RelBtn=MkBtn(gui,"🔄",UDim2.fromScale(.1,.055),UDim2.new(.88,0,.72,0),0,Color3.fromRGB(80,80,100))
RelBtn.Visible=false RelBtn.Activated:Connect(function()if not S.Equip or Reloading then return end Reloading=true
Noti("换弹",Color3.fromRGB(255,220,120))local g=S.GIdx[S.Equip]task.wait(g.rl)CurAmmo=g.m Reloading=false UpdGunHUD()end)
ADSBtn=MkBtn(gui,"🔭",UDim2.fromScale(.1,.055),UDim2.new(.88,0,.66,0),0,Color3.fromRGB(80,80,100))
ADSBtn.Visible=false IsADS=false
ADSBtn.Activated:Connect(function()IsADS=not IsADS workspace.CurrentCamera.FieldOfView=IsADS and 30 or 70 end)
task.spawn(function()while gui.Parent do task.wait(.3)local v=S.Equip~=nil RelBtn.Visible=v ADSBtn.Visible=v end end)

BulF=Instance.new("Folder")BulF.Name="Bullets"BulF.Parent=City
function MkHole(pos,nrm)local h=NP(BulF,Vector3.new(.4,.4,.1),CFrame.new(pos,pos+nrm)*CFrame.Angles(0,0,math.random()*6.28),Color3.fromRGB(20,20,20))h.CanCollide=false
task.delay(5,function()if h.Parent then h:Destroy()end end)end
function MFlash(o,d)local f=NP(BulF,Vector3.new(1.2,1.2,1.2),CFrame.new(o+d*2),Color3.fromRGB(255,220,100),Enum.Material.Neon,Enum.PartType.Ball)
f.CanCollide=false local l=Instance.new("PointLight")l.Range=12 l.Brightness=3 l.Parent=f
task.delay(.05,function()if f.Parent then f:Destroy()end end)end
function ShowDmg(wp,dmg,crit)local p=NP(BulF,Vector3.new(.1,.1,.1),CFrame.new(wp),Color3.fromRGB(255,255,255))p.Transparency=1 p.CanCollide=false
local bb=Instance.new("BillboardGui")bb.Size=UDim2.fromOffset(100,40)bb.StudsOffset=Vector3.new(0,1,0)bb.AlwaysOnTop=true bb.Parent=p
local t=Instance.new("TextLabel")t.Size=UDim2.fromScale(1,1)t.BackgroundTransparency=1 t.Text=tostring(math.floor(dmg))
t.TextColor3=crit and Color3.fromRGB(255,220,60)or Color3.fromRGB(255,80,80)t.TextScaled=true
t.Font=Enum.Font.GothamBold t.TextStrokeTransparency=.3 t.Parent=bb
task.spawn(function()for i=1,15 do task.wait(.03)p.Position=p.Position+Vector3.new(0,.15,0)t.TextTransparency=i/15 end p:Destroy()end)end

function Fire()if not S.Equip or Reloading then return end
local g=S.GIdx[S.Equip]if not g then return end
local nw=tick()if nw-LastShot<1/g.fr then return end LastShot=nw
if CurAmmo<=0 then Noti("弹匣空",Color3.fromRGB(255,180,120))return end
CurAmmo=CurAmmo-1 UpdGunHUD()
local c=LP.Character local h=c and c:FindFirstChild("HumanoidRootPart")if not h then return end
local o=h.Position+Vector3.new(0,1.5,0)
local cam=workspace.CurrentCamera local ray=cam:ViewportPointToRay(cam.ViewportSize.X/2,cam.ViewportSize.Y/2)
local rp=RaycastParams.new()rp.FilterType=Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances={c,City}
local res=workspace:Raycast(ray.Origin,ray.Direction*2000,rp)local dir=ray.Direction
MFlash(o,dir.Unit)
if res then MkHole(res.Position,res.Normal)
local dmg=g.d local crit=math.random()<.15 if crit then dmg=dmg*1.5 end
ShowDmg(res.Position,dmg,crit)
local par=res.Instance while par and par~=workspace do
if par:IsA("Model")and par:FindFirstChildOfClass("Humanoid")then par:FindFirstChildOfClass("Humanoid"):TakeDamage(dmg)break end
par=par.Parent end end
local origCF=cam.CFrame cam.CFrame=origCF*CFrame.Angles(math.rad(math.random(-g.pr/500,g.pr/500)),math.rad(math.random(-g.pr/500,g.pr/500)),0)
task.spawn(function()task.wait(.08)if cam then cam.CFrame=origCF end end)
CDot.BackgroundColor3=Color3.fromRGB(255,100,100)task.delay(.1,function()CDot.BackgroundColor3=Color3.fromRGB(255,255,255)end)end

FireBtn=MkBtn(gui,"🔥",UDim2.fromScale(.14,.08),UDim2.new(.84,0,.78,0),0,Color3.fromRGB(200,60,60))
FireBtn.Visible=false Firing=false
FireBtn.MouseButton1Down:Connect(function()Firing=true end)
FireBtn.MouseButton1Up:Connect(function()Firing=false end)
FireBtn.MouseLeave:Connect(function()Firing=false end)
task.spawn(function()while gui.Parent do task.wait(.05)if Firing and S.Equip then Fire()end end end)
task.spawn(function()while gui.Parent do task.wait(.3)FireBtn.Visible=S.Equip~=nil end end)
UIS.InputBegan:Connect(function(i,gp)if gp then return end
if i.UserInputType==Enum.UserInputType.MouseButton1 and not UIS.TouchEnabled and S.Equip then Fire()end
if i.KeyCode==Enum.KeyCode.R and S.Equip and not Reloading then Reloading=true
local g=S.GIdx[S.Equip]task.wait(g.rl)CurAmmo=g.m Reloading=false UpdGunHUD()end
if i.UserInputType==Enum.UserInputType.MouseButton2 and S.Equip then IsADS=not IsADS workspace.CurrentCamera.FieldOfView=IsADS and 30 or 70 end end)Tick("枪械")

-- ============== 超市 ==============
S.Products={
{id="bread",n="面包",c="food",p=15,e={hunger=15},col=Color3.fromRGB(200,160,100)},
{id="burger",n="汉堡",c="food",p=35,e={hunger=30},col=Color3.fromRGB(180,120,60)},
{id="pizza",n="披萨",c="food",p=45,e={hunger=40},col=Color3.fromRGB(220,180,80)},
{id="sushi",n="寿司",c="food",p=55,e={hunger=35},col=Color3.fromRGB(240,240,240)},
{id="apple",n="苹果",c="food",p=8,e={hunger=10},col=Color3.fromRGB(220,50,50)},
{id="banana",n="香蕉",c="food",p=10,e={hunger=12},col=Color3.fromRGB(240,220,80)},
{id="salad",n="沙拉",c="food",p=25,e={hunger=20},col=Color3.fromRGB(100,180,80)},
{id="steak",n="牛排",c="food",p=90,e={hunger=60},col=Color3.fromRGB(140,60,50)},
{id="water",n="矿泉水",c="drink",p=5,e={thirst=25},col=Color3.fromRGB(180,220,255)},
{id="cola",n="可乐",c="drink",p=8,e={thirst=20},col=Color3.fromRGB(80,30,20)},
{id="juice",n="果汁",c="drink",p=12,e={thirst=25},col=Color3.fromRGB(255,150,60)},
{id="coffee",n="咖啡",c="drink",p=15,e={thirst=15,health=5},col=Color3.fromRGB(70,40,20)},
{id="energy",n="能量饮料",c="drink",p=25,e={thirst=30,health=10},col=Color3.fromRGB(80,220,120)},
{id="milk",n="牛奶",c="drink",p=10,e={thirst=20,hunger=5},col=Color3.fromRGB(250,250,250)},
{id="soap",n="肥皂",c="daily",p=6,e={},col=Color3.fromRGB(230,200,150)},
{id="tooth",n="牙膏",c="daily",p=8,e={},col=Color3.fromRGB(180,220,255)},
{id="tissue",n="纸巾",c="daily",p=4,e={},col=Color3.fromRGB(250,250,250)},
{id="bandaid",n="创可贴",c="med",p=10,e={health=10},col=Color3.fromRGB(240,200,180)},
{id="painkill",n="止痛药",c="med",p=30,e={health=25},col=Color3.fromRGB(240,240,240)},
{id="firstaid",n="急救包",c="med",p=80,e={health=60},col=Color3.fromRGB(220,40,40)},
{id="antibio",n="抗生素",c="med",p=50,e={health=40},col=Color3.fromRGB(150,200,220)},
}
S.PIdx={}for _,p in ipairs(S.Products)do S.PIdx[p.id]=p end
Cat={}for _,p in ipairs(S.Products)do Cat[p.c]=Cat[p.c]or{}table.insert(Cat[p.c],p)end

SMC=Instance.new("Folder")SMC.Name="Supermarkets"SMC.Parent=City
function MkProduct(pos,pr)local p=NP(SMC,Vector3.new(.6,.8,.6),CFrame.new(pos+Vector3.new(0,.4,0)),pr.col)
p.CanCollide=false p.Name="P_"..pr.id p:SetAttribute("PID",pr.id)
local pp=Instance.new("ProximityPrompt")pp.ActionText="加入购物车"pp.ObjectText=pr.n.." $"..pr.p
pp.MaxActivationDistance=10 pp.RequiresLineOfSight=false pp.HoldDuration=0 pp.Parent=p
pp.Triggered:Connect(function(pl)if pl==LP then AddCart(pr.id)end end)end
function MkShelfProd(pos,sz,prs)local sh=NP(SMC,sz,CFrame.new(pos+Vector3.new(0,sz.Y/2,0)),Color3.fromRGB(140,120,100),Enum.Material.Wood)
for i=1,3 do NP(SMC,Vector3.new(sz.X,.2,sz.Z),CFrame.new(pos+Vector3.new(0,sz.Y/4*i,0)),Color3.fromRGB(100,80,60),Enum.Material.Wood)end
local cols=math.max(2,math.floor(sz.X/1.5))local idx=1
for layer=1,3 do for col=1,cols do if idx>#prs then break end
local x=pos.X-sz.X/2+.8+(col-1)*1.5 MkProduct(Vector3.new(x,(sz.Y/4)*layer+.5,pos.Z),prs[idx])idx=idx+1 end end end
function MkSuper(pos,nm)local pr=SMC
NP(pr,Vector3.new(60,12,40),CFrame.new(pos+Vector3.new(0,6,0)),Color3.fromRGB(200,200,210),Enum.Material.Concrete)
NP(pr,Vector3.new(62,1,42),CFrame.new(pos+Vector3.new(0,12.5,0)),Color3.fromRGB(80,80,90),Enum.Material.Slate)
Hinge(pr,pos+Vector3.new(0,0,-20.3),Vector3.new(6,6,.3),Color3.fromRGB(180,210,230),Enum.Material.Glass,math.rad(90))
local s=NP(pr,Vector3.new(50,3,.5),CFrame.new(pos+Vector3.new(0,13.5,-20.5)),Color3.fromRGB(60,160,90),Enum.Material.Neon)
local sg=Instance.new("SurfaceGui")sg.Face=Enum.NormalId.Front sg.CanvasSize=Vector2.new(800,100)sg.Parent=s
local tl=Instance.new("TextLabel")tl.Size=UDim2.fromScale(1,1)tl.BackgroundTransparency=1 tl.Text="🛒 "..nm
tl.TextColor3=Color3.fromRGB(255,255,255)tl.TextScaled=true tl.Font=Enum.Font.GothamBold tl.Parent=sg
BFloor(pr,pos,58,38,.6,Color3.fromRGB(240,240,245),Enum.Material.Tile)BCeil(pr,pos,58,38,10,Color3.fromRGB(250,250,255))
for i=1,4 do for j=1,2 do BFlour(pr,pos+Vector3.new(-20+(i-1)*13,9.5,-10+(j-1)*20),5)end end
MkShelfProd(pos+Vector3.new(-18,0,-10),Vector3.new(12,6,3),Cat.food or{})
MkShelfProd(pos+Vector3.new(-18,0,-4),Vector3.new(12,6,3),Cat.food or{})
MkShelfProd(pos+Vector3.new(18,0,-10),Vector3.new(12,6,3),Cat.drink or{})
MkShelfProd(pos+Vector3.new(18,0,-4),Vector3.new(12,6,3),Cat.drink or{})
MkShelfProd(pos+Vector3.new(-18,0,5),Vector3.new(12,6,3),Cat.daily or{})
MkShelfProd(pos+Vector3.new(-18,0,11),Vector3.new(12,6,3),Cat.daily or{})
MkShelfProd(pos+Vector3.new(18,0,5),Vector3.new(12,6,3),Cat.med or{})
MkShelfProd(pos+Vector3.new(18,0,11),Vector3.new(12,6,3),Cat.med or{})
BFridge(pr,pos+Vector3.new(-8,0,16),Vector3.new(4,6,3))BFridge(pr,pos+Vector3.new(-3,0,16),Vector3.new(4,6,3))
BFridge(pr,pos+Vector3.new(2,0,16),Vector3.new(4,6,3))BCash(pr,pos+Vector3.new(0,0,-15))
RegisterPoint("sm_"..nm,pos+Vector3.new(0,3,-22),"结算",nm,function()OpenCheckout()end)
return{pos=pos,nm=nm}end
SM1=MkSuper(Vector3.new(1200,3,1200),"便利店")
SM2=MkSuper(Vector3.new(3800,3,2200),"大型超市")
S.Shops={SM1,SM2}Tick("超市")

Cart={}function AddCart(id)local p=S.PIdx[id]if not p then return end
Cart[id]=(Cart[id]or 0)+1 Noti("加入："..p.n,Color3.fromRGB(120,220,160))RefCart()end
function RmCart(id)if not Cart[id]then return end Cart[id]=Cart[id]-1 if Cart[id]<=0 then Cart[id]=nil end RefCart()end
function ClearCart()Cart={}RefCart()end
function CartTotal()local t=0 for id,c in pairs(Cart)do local p=S.PIdx[id]if p then t=t+p.p*c end end return t end

CartF=Instance.new("Frame")CartF.Size=UDim2.fromScale(.24,.5)CartF.Position=UDim2.new(.74,0,.25,0)
CartF.BackgroundColor3=Color3.fromRGB(24,28,38)CartF.BackgroundTransparency=.4 CartF.BorderSizePixel=0
CartF.Visible=false CartF.ZIndex=70 CartF.Parent=gui Glass(CartF,18,.65)
local cT=Instance.new("TextLabel")cT.Size=UDim2.fromScale(.9,.08)cT.Position=UDim2.fromScale(.05,.02)
cT.BackgroundTransparency=1 cT.Text="🛒 购物车"cT.TextColor3=Color3.fromRGB(240,245,255)
cT.TextScaled=true cT.Font=Enum.Font.GothamBold cT.ZIndex=71 cT.Parent=CartF
CartL=Instance.new("ScrollingFrame")CartL.Size=UDim2.fromScale(.9,.62)CartL.Position=UDim2.fromScale(.05,.11)
CartL.BackgroundTransparency=1 CartL.BorderSizePixel=0 CartL.ScrollBarThickness=3
CartL.CanvasSize=UDim2.new(0,0,0,0)CartL.AutomaticCanvasSize=Enum.AutomaticSize.Y CartL.ClipsDescendants=true CartL.ZIndex=71 CartL.Parent=CartF
local cl=Instance.new("UIListLayout")cl.Padding=UDim.new(0,3)cl.SortOrder=Enum.SortOrder.LayoutOrder cl.Parent=CartL
local cTot=Instance.new("TextLabel")cTot.Size=UDim2.fromScale(.9,.08)cTot.Position=UDim2.fromScale(.05,.75)
cTot.BackgroundTransparency=1 cTot.Text="总价 $0"cTot.TextColor3=Color3.fromRGB(255,220,120)
cTot.TextScaled=true cTot.Font=Enum.Font.GothamBold cTot.ZIndex=71 cTot.Parent=CartF
function RefCart()for _,c in ipairs(CartL:GetChildren())do if c:IsA("TextButton")then c:Destroy()end end
local o=0 for id,cnt in pairs(Cart)do local p=S.PIdx[id]if p then o=o+1
local b=MkBtn(CartL,string.format("%s ×%d $%d",p.n,cnt,p.p*cnt),UDim2.new(1,-6,0,26),UDim2.fromOffset(3,0),o,Color3.fromRGB(50,60,80))
b.ZIndex=72 local cid=id b.Activated:Connect(function()RmCart(cid)end)end end cTot.Text="总价 $"..CartTotal()end
local cCB=MkBtn(CartF,"结算",UDim2.fromScale(.4,.09),UDim2.fromScale(.05,.86),0,Color3.fromRGB(60,140,90))
cCB.ZIndex=72 cCB.Activated:Connect(function()OpenCheckout()end)
local cClr=MkBtn(CartF,"清空",UDim2.fromScale(.4,.09),UDim2.fromScale(.55,.86),0,Color3.fromRGB(140,60,60))
cClr.ZIndex=72 cClr.Activated:Connect(function()ClearCart()end)

ShopMode=false
task.spawn(function()while true do task.wait(.5)local p=PP()if p then local inS=false
for _,sm in ipairs(S.Shops)do if(p-sm.pos).Magnitude<35 then inS=true break end end
if inS and not ShopMode then ShopMode=true CartF.Visible=true Noti("购物模式",Color3.fromRGB(120,220,160))RefCart()
elseif not inS and ShopMode then ShopMode=false CartF.Visible=false end end end end)

COUI=Instance.new("Frame")COUI.Size=UDim2.fromScale(.6,.6)COUI.Position=UDim2.fromScale(.2,.2)
COUI.BackgroundColor3=Color3.fromRGB(24,28,38)COUI.BackgroundTransparency=.15 COUI.BorderSizePixel=0
COUI.Visible=false COUI.ZIndex=85 COUI.Parent=gui Glass(COUI,22,.6)
local cT2=Instance.new("TextLabel")cT2.Size=UDim2.fromScale(.9,.08)cT2.Position=UDim2.fromScale(.05,.03)
cT2.BackgroundTransparency=1 cT2.Text="💰 结算"cT2.TextColor3=Color3.fromRGB(240,245,255)
cT2.TextScaled=true cT2.Font=Enum.Font.GothamBold cT2.ZIndex=86 cT2.Parent=COUI
local cX=MkBtn(COUI,"✕",UDim2.fromScale(.08,.06),UDim2.fromScale(.88,.025),0,Color3.fromRGB(120,50,50))cX.ZIndex=86
cX.Activated:Connect(function()COUI.Visible=false end)
COList=Instance.new("ScrollingFrame")COList.Size=UDim2.fromScale(.9,.55)COList.Position=UDim2.fromScale(.05,.12)
COList.BackgroundTransparency=1 COList.BorderSizePixel=0 COList.ScrollBarThickness=3
COList.CanvasSize=UDim2.new(0,0,0,0)COList.AutomaticCanvasSize=Enum.AutomaticSize.Y COList.ClipsDescendants=true COList.ZIndex=86 COList.Parent=COUI
local col=Instance.new("UIListLayout")col.Padding=UDim.new(0,3)col.SortOrder=Enum.SortOrder.LayoutOrder col.Parent=COList
local coT=Instance.new("TextLabel")coT.Size=UDim2.fromScale(.9,.08)coT.Position=UDim2.fromScale(.05,.7)
coT.BackgroundTransparency=1 coT.Text="总价 $0"coT.TextColor3=Color3.fromRGB(255,220,120)
coT.TextScaled=true coT.Font=Enum.Font.GothamBold coT.ZIndex=86 coT.Parent=COUI
local coB=MkBtn(COUI,"确认支付",UDim2.fromScale(.5,.1),UDim2.fromScale(.25,.82),0,Color3.fromRGB(60,140,90))coB.ZIndex=87
function OpenCheckout()if next(Cart)==nil then Noti("购物车空",Color3.fromRGB(255,180,120))return end
COUI.Visible=true for _,c in ipairs(COList:GetChildren())do if c:IsA("TextButton")then c:Destroy()end end
local o=0 for id,cnt in pairs(Cart)do local p=S.PIdx[id]if p then o=o+1
local b=MkBtn(COList,string.format("%s ×%d $%d",p.n,cnt,p.p*cnt),UDim2.new(1,-6,0,30),UDim2.fromOffset(3,0),o,Color3.fromRGB(45,55,75))b.ZIndex=87 end end
coT.Text="总价 $"..CartTotal()end
coB.Activated:Connect(function()local t=CartTotal()if t<=0 then return end
if S.Money<t then Noti("金钱不足 需 $"..t,Color3.fromRGB(255,120,120))return end
AddM(-t)for id,cnt in pairs(Cart)do S.Inv[id]=(S.Inv[id]or 0)+cnt end
ClearCart()COUI.Visible=false Noti("结算成功",Color3.fromRGB(120,220,160))end)

BagBtn=MkBtn(gui,"🎒",UDim2.fromScale(.1,.05),UDim2.new(.88,0,.6,0),0,Color3.fromRGB(80,80,140))BagBtn.ZIndex=60
BagUI=Instance.new("Frame")BagUI.Size=UDim2.fromScale(.6,.65)BagUI.Position=UDim2.fromScale(.2,.175)
BagUI.BackgroundColor3=Color3.fromRGB(24,28,38)BagUI.BackgroundTransparency=.15 BagUI.BorderSizePixel=0
BagUI.Visible=false BagUI.ZIndex=85 BagUI.Parent=gui Glass(BagUI,22,.6)
local bT=Instance.new("TextLabel")bT.Size=UDim2.fromScale(.9,.08)bT.Position=UDim2.fromScale(.05,.03)
bT.BackgroundTransparency=1 bT.Text="🎒 背包"bT.TextColor3=Color3.fromRGB(240,245,255)
bT.TextScaled=true bT.Font=Enum.Font.GothamBold bT.ZIndex=86 bT.Parent=BagUI
local bX=MkBtn(BagUI,"✕",UDim2.fromScale(.08,.06),UDim2.fromScale(.88,.025),0,Color3.fromRGB(120,50,50))bX.ZIndex=86
bX.Activated:Connect(function()BagUI.Visible=false end)
BagL=Instance.new("ScrollingFrame")BagL.Size=UDim2.fromScale(.9,.82)BagL.Position=UDim2.fromScale(.05,.12)
BagL.BackgroundTransparency=1 BagL.BorderSizePixel=0 BagL.ScrollBarThickness=3
BagL.CanvasSize=UDim2.new(0,0,0,0)BagL.AutomaticCanvasSize=Enum.AutomaticSize.Y BagL.ClipsDescendants=true BagL.ZIndex=86 BagL.Parent=BagUI
local bl=Instance.new("UIListLayout")bl.Padding=UDim.new(0,3)bl.SortOrder=Enum.SortOrder.LayoutOrder bl.Parent=BagL
function UseItem(id)local p=S.PIdx[id]if not p then return end
if not S.Inv[id]or S.Inv[id]<=0 then return end S.Inv[id]=S.Inv[id]-1 if S.Inv[id]<=0 then S.Inv[id]=nil end
if p.e.hunger then FeedH(p.e.hunger)end if p.e.thirst then DrinkT(p.e.thirst)end
if p.e.health then HealP(p.e.health)end Noti("使用 "..p.n)RefBag()end
function RefBag()for _,c in ipairs(BagL:GetChildren())do if c:IsA("TextButton")then c:Destroy()end end
local o=0 for id,cnt in pairs(S.Inv)do if S.PIdx[id]then o=o+1
local p=S.PIdx[id]local b=MkBtn(BagL,string.format("%s ×%d [用]",p.n,cnt),UDim2.new(1,-6,0,32),UDim2.fromOffset(3,0),o,Color3.fromRGB(45,55,75))
b.ZIndex=87 local iid=id b.Activated:Connect(function()UseItem(iid)end)end end end
BagBtn.Activated:Connect(function()BagUI.Visible=not BagUI.Visible if BagUI.Visible then RefBag()end end)Tick("超市")

-- ============== 被动/投资 ==============
function MkSpecial(pos,sz,col,txt,scol)NP(City,sz,CFrame.new(pos+Vector3.new(0,sz.Y/2,0)),col)
local s=NP(City,Vector3.new(sz.X*.9,3,.4),CFrame.new(pos+Vector3.new(0,sz.Y+2.5,-sz.Z/2-.4)),scol,Enum.Material.Neon)
s.CanCollide=false local sg=Instance.new("SurfaceGui")sg.Face=Enum.NormalId.Front sg.CanvasSize=Vector2.new(500,100)sg.Parent=s
local tl=Instance.new("TextLabel")tl.Size=UDim2.fromScale(1,1)tl.BackgroundTransparency=1 tl.Text=txt
tl.TextColor3=Color3.fromRGB(255,255,255)tl.TextScaled=true tl.Font=Enum.Font.GothamBold tl.TextStrokeTransparency=.3 tl.Parent=sg
local m=NP(City,Vector3.new(.4,10,10),CFrame.new(pos.X,pos.Y+.3,pos.Z+sz.Z/2+6)*CFrame.Angles(0,0,math.rad(90)),scol,Enum.Material.Neon,Enum.PartType.Cylinder)
m.CanCollide=false return{pos=pos,iP=pos+Vector3.new(0,3,sz.Z/2+6)}end
CEN2=Vector3.new(2500,3,2500)
BS=MkSpecial(CEN2+Vector3.new(90,0,-60),Vector3.new(30,40,30),Color3.fromRGB(120,140,180),"STOCK 股票",Color3.fromRGB(90,200,255))
BH=MkSpecial(CEN2+Vector3.new(-90,0,-60),Vector3.new(26,22,26),Color3.fromRGB(160,140,120),"REALTY 房产",Color3.fromRGB(255,200,120))
BC=MkSpecial(CEN2+Vector3.new(0,0,90),Vector3.new(34,50,34),Color3.fromRGB(140,120,160),"CORP 公司",Color3.fromRGB(200,140,255))
function TryBuy(k,n,cost)if S.Pass[k]then Noti(n.." 已在运营",Color3.fromRGB(255,180,120))return end
if S.Money<cost then Noti("金钱不足 需 $"..cost,Color3.fromRGB(255,120,120))return end
AddM(-cost)S.Pass[k]=true Noti("购买 "..n.." +$"..S.PR[k].."/s",Color3.fromRGB(120,220,160))end
RegisterPoint("bs",BS.iP,"购买股票","$5000",function()TryBuy("stock","股票",5000)end)
RegisterPoint("bh",BH.iP,"购买房产","$12000",function()TryBuy("house","房产",12000)end)
RegisterPoint("bc",BC.iP,"购买公司","$30000",function()TryBuy("company","公司",30000)end)
task.spawn(function()while true do task.wait(1)local t=0
for k,v in pairs(S.Pass)do if v then t=t+S.PR[k]end end
if t>0 then t=t*S.Rate.mult S.Money=S.Money+t RefM()end end end)

BIV=MkSpecial(CEN2+Vector3.new(-120,0,60),Vector3.new(28,36,28),Color3.fromRGB(100,110,160),"INVEST 投资",Color3.fromRGB(100,200,255))
BCA=MkSpecial(CEN2+Vector3.new(120,0,60),Vector3.new(30,26,30),Color3.fromRGB(180,60,90),"CASINO 赌场",Color3.fromRGB(255,120,160))
BLO=MkSpecial(CEN2+Vector3.new(0,0,-120),Vector3.new(18,18,18),Color3.fromRGB(200,180,80),"LOTTERY 彩票",Color3.fromRGB(255,230,120))
BMI=MkSpecial(CEN2+Vector3.new(-150,0,-150),Vector3.new(24,16,24),Color3.fromRGB(120,90,60),"MINE 矿场",Color3.fromRGB(200,160,100))
BFI=MkSpecial(CEN2+Vector3.new(150,0,-150),Vector3.new(22,14,22),Color3.fromRGB(80,140,180),"FISH 渔场",Color3.fromRGB(120,200,255))
InvP=Instance.new("Frame")InvP.Size=UDim2.fromScale(.7,.4)InvP.Position=UDim2.fromScale(.15,.3)
InvP.Visible=false InvP.ZIndex=70 InvP.Parent=gui Glass(InvP,22,.6,Color3.fromRGB(24,28,38))
local iT=Instance.new("TextLabel")iT.Size=UDim2.fromScale(.9,.14)iT.Position=UDim2.fromScale(.05,.05)
iT.BackgroundTransparency=1 iT.Text="投资"iT.TextColor3=Color3.fromRGB(240,245,255)
iT.TextScaled=true iT.Font=Enum.Font.GothamBold iT.ZIndex=71 iT.Parent=InvP
local iI=Instance.new("TextLabel")iI.Size=UDim2.fromScale(.9,.12)iI.Position=UDim2.fromScale(.05,.2)
iI.BackgroundTransparency=1 iI.Text=""iI.TextColor3=Color3.fromRGB(200,210,235)
iI.TextScaled=true iI.Font=Enum.Font.GothamMedium iI.ZIndex=71 iI.Parent=InvP
local iIn=Instance.new("TextBox")iIn.Size=UDim2.fromScale(.6,.14)iIn.Position=UDim2.fromScale(.05,.4)
iIn.BackgroundColor3=Color3.fromRGB(40,46,58)iIn.BackgroundTransparency=.2 iIn.Text=""
iIn.PlaceholderText="金额"iIn.TextColor3=Color3.fromRGB(240,245,255)iIn.PlaceholderColor3=Color3.fromRGB(150,160,185)
iIn.TextScaled=true iIn.Font=Enum.Font.GothamMedium iIn.ClearTextOnFocus=false iIn.TextEditable=true iIn.ZIndex=72 iIn.Parent=InvP
local ic=Instance.new("UICorner")ic.CornerRadius=UDim.new(0,12)ic.Parent=iIn
local iOK=MkBtn(InvP,"确认",UDim2.fromScale(.22,.14),UDim2.fromScale(.7,.4),0,Color3.fromRGB(60,140,90))iOK.ZIndex=72
local iX=MkBtn(InvP,"✕",UDim2.fromScale(.08,.1),UDim2.fromScale(.88,.05),0,Color3.fromRGB(120,50,50))iX.ZIndex=72
iX.Activated:Connect(function()InvP.Visible=false end)
function OpenInv(k,t,i)InvP.Visible=true iT.Text=t iI.Text=i iIn.Text=""InvP:SetAttribute("k",k)end
iOK.Activated:Connect(function()local k=InvP:GetAttribute("k")local n=tonumber(iIn.Text)
if not n or n<=0 then Noti("请输入金额",Color3.fromRGB(255,120,120))return end n=math.floor(n)
if S.Money<n then Noti("金钱不足",Color3.fromRGB(255,120,120))return end AddM(-n)
local r=S.Rate[k]or.5 local mu=S.Rate.mult or 1 local won=math.random()<r
local pm=({invest=1.8,stock=2,gamble=2.2,lottery=20,mining=3.5,fishing=2.8})[k]or 1.5
if won then local w=math.floor(n*pm*mu)AddM(w)Noti("赢 $"..w,Color3.fromRGB(120,220,160))
else Noti("未中 -$"..n,Color3.fromRGB(255,120,120))end InvP.Visible=false end)
RegisterPoint("is",BIV.iP,"投资股票","成功率 "..math.floor(S.Rate.stock*100).."%",function()OpenInv("stock","投资","成功率 "..math.floor(S.Rate.stock*100).."% 赢 2 倍")end)
RegisterPoint("ig",BCA.iP,"赌博","胜率 "..math.floor(S.Rate.gamble*100).."%",function()OpenInv("gamble","赌博","胜率 "..math.floor(S.Rate.gamble*100).."% 赢 2.2 倍")end)
RegisterPoint("il",BLO.iP,"买彩票","中奖率 "..math.floor(S.Rate.lottery*100).."%",function()OpenInv("lottery","彩票","中奖率 "..math.floor(S.Rate.lottery*100).."% 赢 20 倍")end)
RegisterPoint("im",BMI.iP,"挖矿","稀有率 "..math.floor(S.Rate.mining*100).."%",function()OpenInv("mining","挖矿","稀有率 "..math.floor(S.Rate.mining*100).."% 赢 3.5 倍")end)
RegisterPoint("if",BFI.iP,"钓鱼","稀有率 "..math.floor(S.Rate.fishing*100).."%",function()OpenInv("fishing","钓鱼","稀有率 "..math.floor(S.Rate.fishing*100).."% 赢 2.8 倍")end)Tick("被动")

-- ============== 生存 ==============
SF=Instance.new("Frame")SF.Size=UDim2.fromScale(.28,.05)SF.Position=UDim2.new(.02,0,.93,0)
SF.BackgroundTransparency=1 SF.ZIndex=5 SF.Parent=gui
local svl=Instance.new("UIListLayout")svl.FillDirection=Enum.FillDirection.Horizontal
svl.Padding=UDim.new(0,4)svl.SortOrder=Enum.SortOrder.LayoutOrder svl.Parent=SF
function MkStat(o,ic,col)local b=Instance.new("Frame")b.Size=UDim2.fromScale(.32,1)
b.BackgroundColor3=Color3.fromRGB(30,34,44)b.BackgroundTransparency=.4 b.BorderSizePixel=0
b.LayoutOrder=o b.ZIndex=6 b.Parent=SF Glass(b,10,.75)
local f=Instance.new("Frame")f.Size=UDim2.fromScale(1,1)f.BackgroundColor3=col f.BorderSizePixel=0 f.ZIndex=7 f.Parent=b
local fc=Instance.new("UICorner")fc.CornerRadius=UDim.new(0,10)fc.Parent=f
local l=Instance.new("TextLabel")l.Size=UDim2.fromScale(1,1)l.BackgroundTransparency=1 l.Text=ic.." 100"
l.TextColor3=Color3.fromRGB(255,255,255)l.TextScaled=true l.Font=Enum.Font.GothamBold
l.TextStrokeTransparency=.4 l.ZIndex=8 l.Parent=b return{fill=f,lbl=l,ic=ic}end
HB=MkStat(1,"❤️",Color3.fromRGB(220,80,80))HuB=MkStat(2,"🍖",Color3.fromRGB(230,140,60))TB=MkStat(3,"💧",Color3.fromRGB(80,150,230))
function RefStat(b,v)v=math.clamp(v,0,100)b.fill.Size=UDim2.fromScale(v/100,1)
b.lbl.Text=string.format("%s %d",b.ic,math.floor(v))end
function BindHum()local c=LP.Character if not c then return end
local h=c:WaitForChild("Humanoid",5)if not h then return end h.MaxHealth=100
h.HealthChanged:Connect(function(hp)S.Surv.health=hp RefStat(HB,hp)
if hp<=0 and not S.Surv.dead then S.Surv.dead=true local lost=math.floor(S.Money*.1)
SetM(S.Money-lost)Noti("死亡 -$"..lost,Color3.fromRGB(255,100,100))
task.wait(3)S.Surv.health=100 S.Surv.hunger=math.max(S.Surv.hunger,40)S.Surv.thirst=math.max(S.Surv.thirst,40)
S.Surv.dead=false RefStat(HB,100)RefStat(HuB,S.Surv.hunger)RefStat(TB,S.Surv.thirst)end end)end
LP.CharacterAdded:Connect(function()task.wait(1)BindHum()end)task.spawn(function()task.wait(2)BindHum()end)
task.spawn(function()while true do task.wait(1)local nw=os.time()
if nw-S.Surv.lastH>=180 then S.Surv.lastH=nw S.Surv.hunger=math.max(0,S.Surv.hunger-1)RefStat(HuB,S.Surv.hunger)end
if nw-S.Surv.lastT>=120 then S.Surv.lastT=nw S.Surv.thirst=math.max(0,S.Surv.thirst-1)RefStat(TB,S.Surv.thirst)end
if(S.Surv.hunger<=0 or S.Surv.thirst<=0)and nw%5==0 then local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")if h then h:TakeDamage(1)end end
if S.Surv.hunger>50 and S.Surv.thirst>50 and nw%10==0 then local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")if h and h.Health<100 then h.Health=math.min(100,h.Health+1)end end
local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")if h then h.WalkSpeed=S.Surv.hunger<30 and 10 or 16 end end end)
function FeedH(a)S.Surv.hunger=math.clamp(S.Surv.hunger+(a or 10),0,100)RefStat(HuB,S.Surv.hunger)Noti("🍖 +"..(a or 10),Color3.fromRGB(230,180,120))end
function DrinkT(a)S.Surv.thirst=math.clamp(S.Surv.thirst+(a or 10),0,100)RefStat(TB,S.Surv.thirst)Noti("💧 +"..(a or 10),Color3.fromRGB(120,180,255))end
function HealP(a)local h=LP.Character and LP.Character:FindFirstChildOfClass("Humanoid")if h then h.Health=math.min(100,h.Health+(a or 20))end end

-- ============== 小地图 ==============
MM=Instance.new("Frame")MM.Size=UDim2.fromScale(.2,.2)MM.Position=UDim2.new(.79,0,.01,0)
MM.BackgroundColor3=Color3.fromRGB(20,24,32)MM.BackgroundTransparency=.3 MM.BorderSizePixel=0 MM.ZIndex=7 MM.Parent=gui Glass(MM,12,.7)
MC=Instance.new("Frame")MC.Size=UDim2.fromScale(1,1)MC.BackgroundTransparency=1
MC.ClipsDescendants=true MC.ZIndex=7 MC.Parent=MM
local mc2=Instance.new("UICorner")mc2.CornerRadius=UDim.new(0,12)mc2.Parent=MC
local rH=Instance.new("Frame")rH.Size=UDim2.fromScale(1,.08)rH.Position=UDim2.fromScale(0,.46)
rH.BackgroundColor3=Color3.fromRGB(90,90,100)rH.BackgroundTransparency=.3 rH.BorderSizePixel=0 rH.ZIndex=8 rH.Parent=MC
local rV=Instance.new("Frame")rV.Size=UDim2.fromScale(.08,1)rV.Position=UDim2.fromScale(.46,0)
rV.BackgroundColor3=Color3.fromRGB(90,90,100)rV.BackgroundTransparency=.3 rV.BorderSizePixel=0 rV.ZIndex=8 rV.Parent=MC
MArr=Instance.new("TextLabel")MArr.Size=UDim2.fromOffset(14,14)MArr.AnchorPoint=Vector2.new(.5,.5)
MArr.Position=UDim2.fromScale(.5,.5)MArr.BackgroundTransparency=1 MArr.Text="▲"
MArr.TextColor3=Color3.fromRGB(120,220,255)MArr.TextScaled=true MArr.Font=Enum.Font.GothamBold MArr.ZIndex=10 MArr.Parent=MC
MT=Instance.new("Frame")MT.Size=UDim2.fromOffset(10,10)MT.AnchorPoint=Vector2.new(.5,.5)
MT.BackgroundColor3=Color3.fromRGB(255,220,80)MT.BorderSizePixel=0 MT.Visible=false MT.ZIndex=9 MT.Parent=MC
local mtc=Instance.new("UICorner")mtc.CornerRadius=UDim.new(1,0)mtc.Parent=MT
task.spawn(function()while MM.Parent do task.wait(.2)local cf=PCF()
if cf then local p=cf.Position local lv=cf.LookVector
MArr.Rotation=-math.atan2(lv.X,lv.Z)*180/math.pi
local tp if S.JS=="pickup"and S.JD then tp=S.JD.getPoint()elseif S.JS=="deliver"and S.JD then tp=S.JD.deliverPoint()end
if tp then local rel=tp-p local nx=math.clamp(.5+rel.X/1000,.03,.97)local nz=math.clamp(.5+rel.Z/1000,.03,.97)
MT.Position=UDim2.fromScale(nx,nz)MT.Visible=true else MT.Visible=false end end end end)

-- ============== 工作列表 ==============
JP=Instance.new("Frame")JP.Size=UDim2.fromScale(.24,.48)JP.Position=UDim2.new(.02,0,.16,0)
JP.ZIndex=3 JP.Parent=gui Glass(JP,18,.7)
local JT=Instance.new("TextLabel")JT.Size=UDim2.fromScale(.9,.08)JT.Position=UDim2.fromScale(.05,.02)
JT.BackgroundTransparency=1 JT.Text="工作"JT.TextColor3=Color3.fromRGB(240,245,255)
JT.TextScaled=true JT.Font=Enum.Font.GothamBold JT.ZIndex=4 JT.Parent=JP
JS=Instance.new("ScrollingFrame")JS.Size=UDim2.fromScale(.9,.86)JS.Position=UDim2.fromScale(.05,.11)
JS.BackgroundTransparency=1 JS.BorderSizePixel=0 JS.ScrollBarThickness=3
JS.ScrollBarImageColor3=Color3.fromRGB(180,190,220)JS.CanvasSize=UDim2.new(0,0,0,0)
JS.AutomaticCanvasSize=Enum.AutomaticSize.Y JS.ClipsDescendants=true JS.ZIndex=4 JS.Parent=JP
local jl=Instance.new("UIListLayout")jl.Padding=UDim.new(0,4)jl.SortOrder=Enum.SortOrder.LayoutOrder jl.Parent=JS

function PickCell(o)o=o or 0 if #S.Cells==0 then return Vector3.new(0,3,0)end
return S.Cells[math.random(1,#S.Cells)]+Vector3.new(o,0,0)end
function MakeJob(id,nm,gl,dl,o1,o2,r1,r2,cd)return function()
local p=PickCell(o1)local d=PickCell(o2)local r=math.random(r1,r2)
return{id=id,name=nm,getPoint=function()return p end,deliverPoint=function()return d end,
getLabel=gl,deliverLabel=dl,reward=function()return r end,cooldown=cd}end end
JBs={}
local jobDefs={
{"delivery","送外卖","🍔","🏠",0,30,60,120,15},{"parcel","送快递","📦","🏢",-25,35,80,160,18},
{"taxi","开出租","🚕","📍",20,-40,100,200,20},{"market","超市打工","🛒","📦",10,-10,50,90,12},
{"waiter","餐厅服务","🍳","🍽️",0,15,70,130,14},{"cashier","便利店收银","🧾","📦",0,8,55,95,10},
{"cleaner","清洁工","🧹","🗑️",-15,25,45,80,12},{"brick","搬砖","🧱","🏗️",-20,30,90,150,16},
{"carwash","洗车","🚿","🚗",0,10,60,110,13},{"pizza","披萨","🍕","🏠",5,35,85,160,17},
{"dock","码头搬运","🚢","📦",-30,40,110,180,18},{"mail","邮差","📮","📬",0,20,70,120,14},
{"dogwalk","遛狗","🐕","🌳",10,45,60,100,15},{"nurse","护士","🏥","🛏️",0,15,90,160,16},
{"security","保安","🛡️","📍",-10,25,70,130,14},{"builder","建筑工","🏗️","🏗️",-20,30,110,180,18},
{"sorter","分拣","📦","🚚",0,8,60,100,10},{"gas","加油工","⛽","🚗",-8,20,75,130,14},
{"lifeguard","救生员","🏖️","🌊",5,40,80,140,16},{"petgroom","宠物美容","🐩","✂️",0,8,85,150,15},
{"florist","花店","💐","🏠",5,30,90,160,15},{"library","图书","📚","📖",0,10,50,90,10},
{"airport","机场地勤","🧳","🛫",-15,25,120,200,20},{"drone","无人机","🛸","📦",0,50,100,180,18},
{"designated","代驾","🍺","🏠",-30,45,130,220,20}}
for _,d in ipairs(jobDefs)do table.insert(JBs,MakeJob(d[1],d[2],d[3].." 取货",d[4].." 交付",d[5],d[6],d[7],d[8],d[9]))end
function BuildJobs()for _,c in ipairs(JS:GetChildren())do if c:IsA("TextButton")then c:Destroy()end end
for i,b in ipairs(JBs)do local sm=b()local jn,jid=sm.name,sm.id
local btn=MkBtn(JS,jn,UDim2.new(1,-6,0,30),UDim2.fromOffset(3,0),i)btn.ZIndex=6
local bld=b btn.Activated:Connect(function()
if S.JS then Noti("先完成当前任务",Color3.fromRGB(255,180,120))return end
local cu=S.Cool[jid]if cu and os.time()<cu then Noti(jn.." 冷却 "..math.ceil(cu-os.time()).."s",Color3.fromRGB(255,180,120))return end
StartJob(bld)end)end end
function StartJob(bld)local job=bld()S.JD=job S.JS="pickup"ClearMarks()
local gp=job.getPoint()WM=MkMark(gp,Color3.fromRGB(120,220,160),job.getLabel)
RegPt("jp",gp,"接单",job.getLabel,function()UnRegPt("jp")
if WM then WM.beam:Destroy()WM.ring:Destroy()WM=nil end S.JS="deliver"
SetHead(job.name.." 配送")SetTask(job.name.." → "..job.deliverLabel)
Noti("接单 "..job.name,Color3.fromRGB(120,220,160))
local dp=job.deliverPoint()WM2=MkMark(dp,Color3.fromRGB(255,200,120),job.deliverLabel)
RegPt("jd",dp,"交付",job.deliverLabel,function()UnRegPt("jd")
if WM2 then WM2.beam:Destroy()WM2.ring:Destroy()WM2=nil end
local r=math.floor(job.reward()*S.Rate.mult)AddM(r)SetHead("")SetTask("")
Noti("完成 "..job.name.." +$"..r,Color3.fromRGB(120,220,160))
S.Cool[job.id]=os.time()+job.cooldown S.JS=nil S.JD=nil
S.SkE.trade=S.SkE.trade+1 if S.SkE.trade>=100 then S.SkE.trade=0 S.Sk.trade=S.Sk.trade+1 end end)end)
SetHead("前往 "..job.getLabel)SetTask(job.name.." → "..job.getLabel)
Noti("新任务 "..job.name,Color3.fromRGB(180,220,255))end
BuildJobs()Tick("工作")

-- ============== 每日/成就/黑市 ==============
function GenDaily()local jobs={"送外卖","送快递","开出租","超市打工","餐厅服务","搬砖"}
local p1=jobs[math.random(1,#jobs)]local p2=jobs[math.random(1,#jobs)]
S.Daily={{text="完成3次"..p1,job=p1,need=3,have=0,reward=500},
{text="完成2次"..p2,job=p2,need=2,have=0,reward=800},
{text="赚$5000",type="money",need=5000,have=0,reward=1500}}
Noti("每日任务已刷新",Color3.fromRGB(120,220,255))end
GenDaily()
task.spawn(function()while true do task.wait(60)
if os.time()-S.DayC*1000>24*60 then GenDaily()end end end)

AchDefs={{id="j1",n="第一桶金"},{id="m10k",n="万元户"},{id="m100k",n="十万"},{id="m1m",n="百万"},
{id="j10",n="勤勤恳恳"},{id="j50",n="劳模"},{id="gun",n="枪械爱好者"},{id="passive",n="投资达人"},
{id="shop",n="购物达人"},{id="surv",n="生存者"}}
function UnlockAch(id)if S.Ach[id]then return end local d
for _,x in ipairs(AchDefs)do if x.id==id then d=x break end end if not d then return end
S.Ach[id]=os.time()Noti("🏆 "..d.n,Color3.fromRGB(255,220,80))end
JC=0
task.spawn(function()while true do task.wait(2)
if S.Money>=10000 then UnlockAch("m10k")end if S.Money>=100000 then UnlockAch("m100k")end
if S.Money>=1000000 then UnlockAch("m1m")end
if S.Pass.stock and S.Pass.house and S.Pass.company then UnlockAch("passive")end
if S.Surv.health>=50 and S.Surv.hunger>=50 and S.Surv.thirst>=50 then UnlockAch("surv")end end end)

BMPos=Vector3.new(850,3,3150)
NP(City,Vector3.new(16,8,12),CFrame.new(BMPos+Vector3.new(0,4,0)),Color3.fromRGB(40,35,35),Enum.Material.Concrete)
NP(City,Vector3.new(12,2,.4),CFrame.new(BMPos+Vector3.new(0,9,-6.2)),Color3.fromRGB(180,40,180),Enum.Material.Neon)
RegisterPoint("bm",BMPos+Vector3.new(0,3,-8),"进入黑市","风险交易",function()
if S.Money<1000 then Noti("金钱不足",Color3.fromRGB(255,120,120))return end
AddM(-1000)if math.random()<S.Rate.gamble*.7 then AddM(5000)Noti("黑市成功 +$5000",Color3.fromRGB(120,220,160))
else Noti("黑市失败 -$1000",Color3.fromRGB(255,120,120))end end)Tick("黑市")

-- ============== 时间/昼夜 ==============
task.spawn(function()while true do task.wait(1)
S.GMin=S.GMin+1 if S.GMin>=24*60 then S.GMin=0 S.DayC=S.DayC+1 end
local h=(8+S.GMin/60)%24 LT.ClockTime=h
local hh=math.floor(h)local mm=math.floor((h-hh)*60)
TimeH.Text=string.format("第%d天 %02d:%02d",S.DayC,hh,mm)
if h>=6 and h<18 then LT.Brightness=3 LT.Ambient=Color3.fromRGB(140,145,155)LT.OutdoorAmbient=Color3.fromRGB(155,160,170)
elseif h>=18 and h<20 then local t=(h-18)/2 LT.Brightness=2-t LT.Ambient=Color3.fromRGB(140,120,100):Lerp(Color3.fromRGB(80,70,90),t)
LT.OutdoorAmbient=Color3.fromRGB(180,140,100):Lerp(Color3.fromRGB(80,80,110),t)
elseif h>=20 or h<5 then LT.Brightness=.8 LT.Ambient=Color3.fromRGB(40,45,65)LT.OutdoorAmbient=Color3.fromRGB(50,55,80)
else local t=h-5 LT.Brightness=.8+t*2 LT.Ambient=Color3.fromRGB(40,45,65):Lerp(Color3.fromRGB(140,145,155),t)
LT.OutdoorAmbient=Color3.fromRGB(50,55,80):Lerp(Color3.fromRGB(155,160,170),t)end end end)

-- ============== 收尾 ==============
lfill.Size=UDim2.fromScale(1,1)lcnt.Text=LTot.."/"..LTot lh.Text="完成"
task.wait(.5)TS:Create(lbg,TweenInfo.new(.5),{BackgroundTransparency=1}):Play()
TS:Create(lc,TweenInfo.new(.5),{BackgroundTransparency=1}):Play()
task.wait(.6)LG:Destroy()
pcall(function()local c=LP.Character or LP.CharacterAdded:Wait()
local h=c:WaitForChild("HumanoidRootPart",5)if h then h.CFrame=CFrame.new(2500,8,2540)end end)
RefM()
Noti("✅ 完整版加载完成",Color3.fromRGB(120,220,160))
Noti("工作 "..#JBs.." · 枪械 "..#S.Guns.." · 商品 "..#S.Products,Color3.fromRGB(200,220,255))
Noti("管理员密码：6767",Color3.fromRGB(200,180,255))
print("===========================================")
print("  IncSim 完整版加载成功")
print("  工作 "..#JBs.." | 枪械 "..#S.Guns.." | 商品 "..#S.Products)
print("  NPC "..#S.NPCs.." | 车 "..#S.Cars.." | 超市 2")
print("  地图 5000x5000 | 8区域 | 高速+立交+隧道")
print("  管理员密码：6767")
print("===========================================")
