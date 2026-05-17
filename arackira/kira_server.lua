-- ============================================
-- RP Arac Kiralama - server.lua
-- NPC'den Kiralama | Sultan Filo
-- ============================================

local KIRA_UCRET_SAAT = 1000
local kiralikAraclar  = {}   -- arac -> {oyuncu, baslangic, index}
local oyuncuArac      = {}   -- oyuncu -> arac

local SULTAN_BILGI = {
    {r=255,g=0,  b=0,  r2=255,g2=0,  b2=0,  isim="Sultan #1 (Kirmizi)"},
    {r=0,  g=80, b=200,r2=0,  g2=80, b2=200,isim="Sultan #2 (Mavi)"},
    {r=30, g=160,b=50, r2=30, g2=160,b2=50, isim="Sultan #3 (Yesil)"},
    {r=20, g=20, b=20, r2=20, g2=20, b2=20, isim="Sultan #4 (Siyah)"},
    {r=220,g=220,b=220,r2=220,g2=220,b2=220,isim="Sultan #5 (Beyaz)"},
}

-- Arac spawn noktasi (NPC'nin biraz yanı)
local SPAWN_X = 343.0231628418
local SPAWN_Y = -1809.8884277344
local SPAWN_Z = 4.5021934509277

local musaitlik = {true,true,true,true,true}  -- her sultan musait mi

-- =====================
-- KİRALAMA
-- =====================
addEvent("kira:araciKirala", true)
addEventHandler("kira:araciKirala", root, function(idx)
    local oyuncu = source

    if oyuncuArac[oyuncu] then
        triggerClientEvent(oyuncu,"kira:bildirim",oyuncu,"error","Zaten kirali araciniz var! Once iade edin.")
        return
    end

    if idx < 1 or idx > 5 then return end

    if not musaitlik[idx] then
        triggerClientEvent(oyuncu,"kira:bildirim",oyuncu,"error","Bu arac su an kiralik!")
        return
    end

    local para = getElementData(oyuncu,"rp:para") or 0
    if para < KIRA_UCRET_SAAT then
        triggerClientEvent(oyuncu,"kira:bildirim",oyuncu,"error",
            string.format("Yetersiz para! Depozito: $%d",KIRA_UCRET_SAAT))
        return
    end

    -- Depozito al
    setElementData(oyuncu,"rp:para",para - KIRA_UCRET_SAAT)

    -- Arac spawnla
    local bilgi = SULTAN_BILGI[idx]
    local oy    = SPAWN_Y - (idx-1)*5.5   -- Y ekseninde yan yana park
    local arac  = createVehicle(560, SPAWN_X, oy, SPAWN_Z, 0,0,0)

    setVehicleColor(arac,bilgi.r,bilgi.g,bilgi.b,bilgi.r2,bilgi.g2,bilgi.b2)
    setVehicleLocked(arac,false)
    setElementData(arac,"kira:kiraci",getPlayerName(oyuncu))

    musaitlik[idx]      = false
    kiralikAraclar[arac]= {oyuncu=oyuncu,baslangic=os.time(),index=idx}
    oyuncuArac[oyuncu]  = arac

    setElementData(oyuncu,"kira:odenenSaat",1)

    warpPedIntoVehicle(oyuncu,arac,0)

    triggerClientEvent(oyuncu,"kira:kiralamaBasladi",oyuncu,bilgi.isim,KIRA_UCRET_SAAT)
    triggerClientEvent(oyuncu,"kira:bildirim",oyuncu,"success",
        string.format("%s kiralandi! Saatlik $%d",bilgi.isim,KIRA_UCRET_SAAT))

    outputServerLog("[KIRA] "..getPlayerName(oyuncu).." -> "..bilgi.isim)
end)

-- =====================
-- İADE
-- =====================
addEvent("kira:araciIadeEt", true)
addEventHandler("kira:araciIadeEt", root, function()
    local oyuncu = source
    local arac   = oyuncuArac[oyuncu]

    if not arac or not isElement(arac) then
        triggerClientEvent(oyuncu,"kira:bildirim",oyuncu,"error","Kirali araciniz yok!")
        return
    end

    local kira   = kiralikAraclar[arac]
    if not kira  then return end

    local sureSn  = os.time()-kira.baslangic
    local tamSaat = math.ceil(sureSn/3600)
    local ucret   = tamSaat * KIRA_UCRET_SAAT
    local ekUcret = ucret - KIRA_UCRET_SAAT
    if ekUcret > 0 then
        local p = getElementData(oyuncu,"rp:para") or 0
        setElementData(oyuncu,"rp:para",math.max(0,p-ekUcret))
    end

    musaitlik[kira.index] = true
    kiralikAraclar[arac]  = nil
    oyuncuArac[oyuncu]    = nil
    destroyElement(arac)

    local sureDk = math.ceil(sureSn/60)
    triggerClientEvent(oyuncu,"kira:bildirim",oyuncu,"success",
        string.format("Arac iade edildi! Sure: %d dk | Toplam: $%d",sureDk,ucret))
    triggerClientEvent(oyuncu,"kira:iadeBitti",oyuncu,sureDk,ucret)

    outputServerLog("[KIRA] "..getPlayerName(oyuncu).." iade etti. "..sureDk.."dk $"..ucret)
end)

-- Saatlik otomatik kesim
setTimer(function()
    for arac,kira in pairs(kiralikAraclar) do
        if isElement(arac) and isElement(kira.oyuncu) then
            local sureSn  = os.time()-kira.baslangic
            local tamSaat = math.floor(sureSn/3600)
            local odenen  = getElementData(kira.oyuncu,"kira:odenenSaat") or 1
            if tamSaat >= odenen then
                local p = getElementData(kira.oyuncu,"rp:para") or 0
                if p >= KIRA_UCRET_SAAT then
                    setElementData(kira.oyuncu,"rp:para",p-KIRA_UCRET_SAAT)
                    setElementData(kira.oyuncu,"kira:odenenSaat",odenen+1)
                    triggerClientEvent(kira.oyuncu,"kira:bildirim",kira.oyuncu,"warn",
                        string.format("Saatlik kira: -$%d kesildi.",KIRA_UCRET_SAAT))
                else
                    triggerClientEvent(kira.oyuncu,"kira:bildirim",kira.oyuncu,"error",
                        "Para yetmedi! Arac geri alindi.")
                    musaitlik[kira.index]=true
                    kiralikAraclar[arac]=nil
                    oyuncuArac[kira.oyuncu]=nil
                    if isElement(arac) then destroyElement(arac) end
                    triggerClientEvent(kira.oyuncu,"kira:iadeBitti",kira.oyuncu,0,0)
                end
            end
        end
    end
end,60000,0)

-- Oyuncu ayrılınca
addEventHandler("onPlayerQuit",root,function()
    local oyuncu=source
    local arac=oyuncuArac[oyuncu]
    if arac and isElement(arac) then
        local kira=kiralikAraclar[arac]
        if kira then musaitlik[kira.index]=true end
        kiralikAraclar[arac]=nil
        destroyElement(arac)
    end
    oyuncuArac[oyuncu]=nil
end)

-- Liste gönder
addEvent("kira:listeIste",true)
addEventHandler("kira:listeIste",root,function()
    local liste={}
    for i,bilgi in ipairs(SULTAN_BILGI) do
        table.insert(liste,{
            index=i, isim=bilgi.isim, ucret=KIRA_UCRET_SAAT,
            musait=musaitlik[i],
            r=bilgi.r, g=bilgi.g, b=bilgi.b,
        })
    end
    triggerClientEvent(source,"kira:listeGeldi",source,liste)
end)
