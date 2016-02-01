GBM = LibStub("AceAddon-3.0"):NewAddon("GugiBankMan", "AceConsole-3.0", "AceEvent-3.0")
local GUI = LibStub("AceGUI-3.0")
local Frame = nil
local Group = nil
local Tabs = nil
local CurrentTab = 0
local Check
GBM:RegisterChatCommand("gbm", "OnSlashCommand")
GBM:RegisterChatCommand("tic", "OnTic")
GBM:RegisterChatCommand("tac", "OnTac")
local StartTime = 0
local StartGold = 0


local CURRENT_LEVEL = 60
local MIN_LEVEL = CURRENT_LEVEL - 20
local MAIN_STACK_LIMIT = 5
local SEC_STACK_LIMIT = 3

function GBM:OnInitialize()
    GBM:RegisterEvent("GUILDBANKFRAME_OPENED", "OnGuildBank")
end

function GBM:OnSlashCommand(msg)
    if not Frame then
        GBM:OnUI()
    else
        Frame:Show()
    end
end

local function OnTabChange(container, event, group)
    CurrentTab = group
    container:ReleaseChildren()
    if group == 0 then
        local total = GBM:CombinedTabs({1, 2, 3, 4, 5, 6, 7})
        GBM:FillTotal(total, container)
    else
        local items = GBM:LoadTab(group)
        GBM:FillBankTab(items, container)
    end
end

function GBM:OnGuildBank(name)
    GBM:OnUI()
    OnTabChange(Tabs, nil, 0)
end

function GBM:ReloadTab()
    OnTabChange(Tabs, nil, CurrentTab)
end

function GBM:OnUI()
    if Frame then return end
    Frame = GUI:Create("Frame")
    Frame:SetCallback("OnClose", function(widget)
        GUI:Release(widget)
        Frame = nil
        end)
    Frame:SetTitle("GBM")
    Frame:SetLayout("List")
    
    Check = GUI:Create("CheckBox")
    Check:SetLabel("Show only problems")
    Check:SetValue(true)
    Frame:AddChild(Check)
    Group = GUI:Create("SimpleGroup")
    Group:SetFullWidth(true)
    Group:SetFullHeight(true)
    Group:SetLayout("Fill")
    Frame:AddChild(Group)
    
    Tabs = GUI:Create("TabGroup")
    Tabs:SetLayout("Flow")
    local meta = {{text="Duplicate", value=0}}
    for tab = 1,7 do
        local name, _ = GetGuildBankTabInfo(tab);
        table.insert(meta, {text=name, value=tab})
    end
    Tabs:SetTabs(meta)
    Tabs:SetCallback("OnGroupSelected", OnTabChange)
    Tabs:SelectTab(0)
    Group:AddChild(Tabs)
    
    Check:SetCallback("OnValueChanged", function()
        GBM:ReloadTab()
    end)
end


function GBM:FillBankTab(items, container)
    for id, record in pairs(items) do
        local label = GUI:Create("Label")
        local problem, name = GBM:RateItem(record)
        if problem or not Check:GetValue() then
            label:SetText(name)
            container:AddChild(label)
        end
    end
end

function GBM:FillTotal(total, container)
    for id, record in pairs(total) do
        if table.getn(record.tabs) > 1 then
            local label = GUI:Create("Label")
            label:SetText(record.link.. " {"..table.concat(record.tabs, ", ").."}")
            container:AddChild(label)
        end
    end
end

function GBM:LoadTab(tab)
    local items = {}
    for slot = 1,14*7 do
        local link, id = GBM:GetItem(tab, slot)
        if link then
            if not items[id] then
                items[id]= {stacks=0, link=link, link=link}
            end
            items[id].stacks = items[id].stacks + 1
        end
    end
    return items
end

function GBM:CombinedTabs(tabs)
    local total = {}
    for i, tab in ipairs(tabs) do
        local items = GBM:LoadTab(tab)
        GBM:CombineInto(total, items, tab)
    end
    return total
end

function GBM:CombineInto(total, items, tab)
    for id, record in pairs(items) do
        total[id] = total[id] or {tabs={}, link=record.link}
        table.insert(total[id].tabs, tab)
    end
end

function GBM:GetItem(tab, slot)
    local link = GetGuildBankItemLink(tab, slot)
    if not link then
        return
    end
    local id = string.match(link, "item:(%d+)")

    return link, id
end

function GBM:RateItem(record)
    local link = record.link
    local stacks = record.stacks
    local name,_,rarity,level,minLevel,t,s,stack,loc = GetItemInfo(link)
    
    local text = link
    local prefix = ""
    if stacks and stacks > 1 then
        text = text.." x("..stacks..")"
    end
    local HARDCODE = t == "Edelstein"
    HARDCODE = HARDCODE or t == "Quest" or t == "Glyphe"
    HARDCODE = HARDCODE or t == "Beh\195\164lter" or t == "Rezept"
    HARDCODE = HARDCODE or t == "Verschiedenes"
    
    local craft = t == "Handwerkswaren"
    local gather = s =="Leder" or s == "Stoff" or s == "Kr\195\164uter"
    local other = s == "Teile" or s == "Sonstige" or s == "Elementar"
    local main = gather or s == "Metall & Stein" or s == "Ger\195\164te" or other 
    local sec = s == "Kochkunst"
    local scroll = s == "Rolle"
    local enchantScroll = s == "Gegenstandsverzauberung"
    local enchant = s == "Gegenstandsverbesserung"
    local pet = t == "Kampfhaustier"
    local wearable = t == ARMOR or t == WEAPON
    local recipe = t == "Rezept"
    local hasMinLevel = wearable or t == "Verbrauchbar"
    
    if enchantScroll then
        prefix = "|cffff0000[SELL]|r"
    elseif hasMinLevel and minLevel and minLevel > 0 and minLevel < MIN_LEVEL then
        prefix = "|cffff0000[LOW]|r"
    elseif craft and stacks > MAIN_STACK_LIMIT then
        prefix = "|cffff0000[MUCH]|r"
    elseif craft and sec and stacks > SEC_STACK_LIMIT then
        prefix = "|cffff0000[MUCH]|r"
    elseif recipe and stacks > SEC_STACK_LIMIT then
        prefix = "|cffffcc00[MUCH]|r"
    elseif enchant then
        prefix = "|cffffcc00[VZ]|r"
    end
    
    if craft and not main and not sec and not enchantScroll then
        print(s, link)
    end
    
    return prefix ~= "", prefix.." "..text
end


function GBM:FormatTime(seconds)
    local minutes = floor(seconds / 60) % 60
    local hours = floor(minutes / 60)
    seconds = seconds % 60
    
    t = ""
    if hours > 0 then
        if hours < 10 then
            t = t.."0"
        end
        t = t..hours.."h:"
    end
    if hours > 0 or minutes > 0 then
        if minutes < 10 then
            t = t.."0"
        end
        t = t..minutes.."m:"
    end
    return t..(floor(seconds * 100 + 0.5)/100).."s"
end


function GBM:FormatMoney(copper)
    local str = GetCoinText(abs(copper))
    local pre = ""
    local suf = ""
    if copper < 0 then
        pre = "|cffcc0000- "
        suf = "|r"
    else
        pre = "+ "
    end
    return pre..str..suf
end

function GBM:OnTic()
    GBM:Print("Tic")
    StartTime = GetTime()
    StartGold = GetMoney()
end


function GBM:OnTac()
    GBM:Print("Tac", GBM:FormatTime(GetTime() - StartTime))
    local copper = GetMoney() - StartGold
    GBM:Print(GBM:FormatMoney(copper))
    DepositGuildBankMoney(copper)
end