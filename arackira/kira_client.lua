-- ============================================
-- RP Arac Kiralama - client.lua
-- NPC'den Kiralama | Sultan Filo
-- ============================================

local ekranG, ekranY = guiGetScreenSize()

-- NPC konumu
local NPC_X    = 375.45001220703
local NPC_Y    = -2027.2161865234
local NPC_Z    = 7.8300905227661
local NPC_MESAFE = 4.0

-- =====================
-- STATE
-- =====================
local menuAcik    = false
local menuAlpha   = 0
local hoveredBtn  = nil
local kayitliButonlar = {}
local bildirimler = {}
local aracListesi = {}

local aktifKira   = false
local kiraIsim    = ""
local kiraTimer   = 0

local npcPed      = nil
local konusmaBubble = nil  -- NPC balonu zamani

-- =====================
-- YARDIMCILAR
-- =====================
local function tc(r,g,b,a) return tocolor(r,g,b,a or 255) end
local function fa(n) return math.floor(n) end

local function inRect(x,y,rx,ry,rw,rh)
    return x>=rx and x<=rx+rw and y>=ry and y<=ry+rh
end
local function butonTemizle() kayitliButonlar={} end
local function butonKaydet(id,x,y,w,h)
    kayitliButonlar[id]={x=fa(x),y=fa(y),w=fa(w),h=fa(h)}
end
local function drect(x,y,w,h,r,g,b,a)
    dxDrawRectangle(fa(x),fa(y),fa(w),fa(h),tc(r,g,b,a))
end
local function dtxt(t,x1,y1,x2,y2,r,g,b,a,sc,fn,ax,ay)
    dxDrawText(t,fa(x1),fa(y1),fa(x2),fa(y2),
        tc(r,g,b,a or 255),sc or 1.0,fn or "default-bold",
        ax or "left",ay or "top")
end

local function bildirimEkle(tip,mesaj)
    local r,g,b=80,180,255
    if tip=="success" then r,g,b=60,220,120
    elseif tip=="error" then r,g,b=255,70,70
    elseif tip=="warn"  then r,g,b=255,180,0 end
    table.insert(bildirimler,1,{mesaj=mesaj,r=r,g=g,b=b,zaman=getTickCount()})
    if #bildirimler>5 then table.remove(bildirimler) end
end

addEvent("kira:bildirim",true)
addEventHandler("kira:bildirim",localPlayer,function(tip,mesaj)
    bildirimEkle(tip,mesaj)
end)

local function npcYakinMi()
    local px,py,pz=getElementPosition(localPlayer)
    return getDistanceBetweenPoints3D(px,py,pz,NPC_X,NPC_Y,NPC_Z)<=NPC_MESAFE
end

-- =====================
-- NPC OLUŞTUR
-- =====================
local function npcOlustur()
    if npcPed and isElement(npcPed) then destroyElement(npcPed) end

    -- Kiyafet: araba galerisi satici (skin 270)
    npcPed = createPed(270, NPC_X, NPC_Y, NPC_Z, 180.0)
    if not npcPed then return end

    setPedCanBeKnockedOffBike(npcPed, false)
    setElementFrozen(npcPed, true)
    setElementInvincible(npcPed, true)

    -- NPC isim etiketi
    setElementData(npcPed, "npc:isim", "Ahmet - Kira Gorevlisi")
end

-- =====================
-- NPC İSİM ETİKETİ (3D)
-- =====================
local function npcEtiketCiz()
    if not npcPed or not isElement(npcPed) then return end
    local px,py,pz = getElementPosition(localPlayer)
    local nx,ny,nz = getElementPosition(npcPed)
    local d = getDistanceBetweenPoints3D(px,py,pz,nx,ny,nz)
    if d > 12 then return end

    local sx,sy,sd = getScreenFromWorldPosition(nx,ny,nz+1.2)
    if not sx then return end

    local a = d>8 and math.max(0,(12-d)/4) or 1.0

    -- İsim kutusu
    local bw,bh = 200,28
    local bx = sx-bw/2
    local by = sy-bh/2

    drect(bx,by,bw,bh, 0,0,0,fa(180*a))
    drect(bx,by,bw,3, 255,160,0,fa(255*a))
    dxDrawText("Ahmet  |  Kira Gorevlisi",bx,by,bx+bw,by+bh,
        tc(255,255,255,fa(240*a)),0.82,"default-bold","center","center")

    -- E ipucu (yakın olunca)
    if d <= NPC_MESAFE then
        local ew,eh = 220,32
        local ex = sx-ew/2
        local ey = sy+20
        drect(ex,ey,ew,eh, 0,0,0,fa(180*a))
        drect(ex,ey,ew,3, 255,160,0,fa(255*a))
        dxDrawText("[ E ]  Konuş",ex,ey,ex+ew,ey+eh,
            tc(255,160,0,fa(240*a)),0.88,"default-bold","center","center")
    end
end

-- =====================
-- MENU
-- =====================
local PW = 500
local PX = 0
local PY = 0

local function menuCiz(a)
    local satH = 86
    local topH = 82 + #aracListesi*satH + (aktifKira and 68 or 0) + 46

    PX = fa(ekranG/2 - PW/2)
    PY = fa(ekranY/2 - topH/2)

    -- Golge
    drect(PX+4,PY+4,PW,topH, 0,0,0,fa(80*a))
    -- Panel
    drect(PX,PY,PW,topH, 10,10,16,fa(245*a))

    -- HEADER
    drect(PX,PY,PW,6, 255,160,0,fa(255*a))
    drect(PX,PY+6,PW,72, 14,14,22,fa(255*a))
    drect(PX,PY+78,PW,2, 255,160,0,fa(100*a))

    -- NPC avatar dairesi
    drect(PX+16,PY+14,50,50, 255,160,0,fa(200*a))
    drect(PX+18,PY+16,46,46, 20,20,30,fa(255*a))
    dxDrawText("A",PX+18,PY+16,PX+64,PY+62,
        tc(255,160,0,fa(255*a)),1.8,"default-bold","center","center")

    dxDrawText("Ahmet - Kira Gorevlisi",PX+76,PY+12,PX+PW-14,PY+42,
        tc(255,255,255,fa(255*a)),1.3,"default-bold","left","top")
    dtxt("Sultan Rent A Car | $1.000 / Saat",
        PX+76,PY+44,PX+PW-14,PY+70,
        180,180,200,fa(200*a),0.85,"default","left","top")

    local y = PY+82

    -- AKTİF KİRA BANNER
    if aktifKira then
        drect(PX,y,PW,62, 0,55,18,fa(200*a))
        drect(PX,y,PW,3, 60,220,120,fa(255*a))
        drect(PX+14,y+10,42,42, 60,220,120,fa(55*a))
        dxDrawText("Kiralik: "..kiraIsim,PX+64,y+8,PX+PW-120,y+32,
            tc(255,255,255,fa(255*a)),1.0,"default-bold","left","top")
        local dk=fa(kiraTimer/60) local sn=fa(kiraTimer%60)
        dxDrawText(string.format("%02d:%02d",dk,sn),PX+PW-116,y+8,PX+PW-10,y+32,
            tc(60,220,120,fa(255*a)),1.1,"default-bold","right","top")
        dtxt("Arac kullanilmakta | Sure sayiliyor",PX+64,y+34,PX+PW-14,y+58,
            140,200,155,fa(190*a),0.8,"default","left","top")

        -- İADE
        local iy=y+62
        drect(PX,iy,PW,50, 160,70,0,fa(210*a))
        drect(PX,iy,PW,3, 255,130,0,fa(255*a))
        dxDrawText("ARACI İADE ET",PX,iy,PX+PW,iy+50,
            tc(255,255,255,fa(255*a)),1.1,"default-bold","center","center")
        butonKaydet("iade",PX,iy,PW,50)
        y=iy+50
    end

    -- ARAC SATIRLARI
    for i,arac in ipairs(aracListesi) do
        local isH    = hoveredBtn=="arac_"..i
        local musait = arac.musait and not aktifKira

        drect(PX,y,PW,satH-2,
            isH and musait and 22 or 13,
            13,
            isH and musait and 22 or 13,
            fa((isH and musait and 235 or 195)*a))
        drect(PX,y,PW,1, 35,35,50,fa(120*a))
        drect(PX,y,6,satH-2, arac.r,arac.g,arac.b,fa(arac.musait and 255 or 70)*a)

        -- Renk kutu
        drect(PX+16,y+18,46,46, arac.r,arac.g,arac.b,fa(arac.musait and 170 or 55)*a)
        drect(PX+18,y+20,42,42, 10,10,16,fa(arac.musait and 100 or 45)*a)
        dxDrawText("S",PX+18,y+20,PX+60,y+62,
            tc(arac.r,arac.g,arac.b,fa(arac.musait and 220 or 70)*a),
            1.3,"default-bold","center","center")

        -- İsim
        dxDrawText(arac.isim,PX+74,y+10,PX+PW-145,y+38,
            tc(arac.musait and 255 or 120,
               arac.musait and 255 or 120,
               arac.musait and 255 or 120,
               fa(255*a)),
            1.0,"default-bold","left","top")

        -- Sultan badge
        drect(PX+74,y+40,64,20, 255,160,0,fa(arac.musait and 40 or 18)*a)
        dtxt("Sultan RS",PX+74,y+40,PX+138,y+60,
            255,160,0,fa(arac.musait and 200 or 90)*a,0.72,"default-bold","center","center")

        -- Ucret
        dxDrawText("$1.000/saat",PX+PW-150,y+10,PX+PW-12,y+36,
            tc(255,160,0,fa(arac.musait and 240 or 90)*a),0.92,"default-bold","right","top")

        -- Durum
        if musait then
            drect(PX+PW-98,y+40,86,22, 25,110,25,fa(180*a))
            dtxt("Musait",PX+PW-98,y+40,PX+PW-12,y+62,
                60,220,120,fa(220*a),0.8,"default-bold","center","center")
            butonKaydet("arac_"..i,PX,y,PW,satH-2)
        elseif aktifKira and arac.index==nil then
            drect(PX+PW-98,y+40,86,22, 60,60,60,fa(160*a))
            dtxt("Sende",PX+PW-98,y+40,PX+PW-12,y+62,
                180,180,180,fa(200*a),0.78,"default-bold","center","center")
        else
            drect(PX+PW-98,y+40,86,22, 80,25,25,fa(160*a))
            dtxt("Kiralik",PX+PW-98,y+40,PX+PW-12,y+62,
                200,90,90,fa(200*a),0.78,"default-bold","center","center")
        end

        if isH and musait then
            dtxt(">",PX+PW-14,y,PX+PW,y+satH,
                255,160,0,fa(200*a),1.2,"default-bold","center","center")
        end
        y=y+satH
    end

    -- KAPAT
    drect(PX,y,PW,42, 28,12,12,fa(210*a))
    drect(PX,y,PW,2, 80,20,20,fa(255*a))
    dxDrawText("[ E / F5 ]  Kapat",PX,y,PX+PW,y+42,
        tc(170,80,80,fa(210*a)),0.95,"default-bold","center","center")
    butonKaydet("kapat",PX,y,PW,42)
end

-- =====================
-- RENDER
-- =====================
addEventHandler("onClientRender",root,function()
    if menuAcik then
        if menuAlpha<255 then menuAlpha=math.min(menuAlpha+22,255) end
    else
        if menuAlpha>0   then menuAlpha=math.max(menuAlpha-22,0)   end
    end

    if menuAlpha>2 then
        butonTemizle()
        menuCiz(menuAlpha/255)
    end

    if aktifKira then
        kiraTimer=kiraTimer+0.016
    end

    -- NPC etiketi
    npcEtiketCiz()

    -- NPC yüzünü oyuncuya döndür (yakınsa)
    if npcPed and isElement(npcPed) then
        local px,py,pz=getElementPosition(localPlayer)
        local nx,ny,nz=getElementPosition(npcPed)
        local d=getDistanceBetweenPoints3D(px,py,pz,nx,ny,nz)
        if d<=8 then
            local angle=math.deg(math.atan2(px-nx,py-ny))
            setPedRotation(npcPed,angle)
        end
    end

    -- Mini HUD (sag alt) - kirali araç varken
    if aktifKira and not menuAcik then
        local hx=ekranG-218
        local hy=ekranY-66
        drect(hx,hy,208,56, 0,0,0,175)
        drect(hx,hy,208,3, 255,160,0,255)
        dtxt("KIRALIK ARAC",hx+10,hy+6,hx+208,hy+24, 255,160,0,220, 0.78,"default-bold")
        dtxt(kiraIsim,hx+10,hy+24,hx+208,hy+42, 255,255,255,210, 0.78,"default-bold")
        local dk=fa(kiraTimer/60) local sn=fa(kiraTimer%60)
        dtxt(string.format("%02d:%02d",dk,sn),hx+10,hy+40,hx+208,hy+56,
            60,220,120,200, 0.76,"default-bold")
    end

    -- Bildirimler
    local by2=ekranY-58
    for i=#bildirimler,1,-1 do
        local b=bildirimler[i]
        local g=getTickCount()-b.zaman
        local ba=g>3500 and math.max(0,255-fa(((g-3500)/700)*255)) or 255
        if g>4200 then
            table.remove(bildirimler,i)
        else
            local bw2=380 local bx2=ekranG-bw2-20
            dxDrawRectangle(bx2,by2,5,44,tocolor(b.r,b.g,b.b,ba))
            dxDrawRectangle(bx2+5,by2,bw2-5,44,tocolor(0,0,0,fa(ba*0.86)))
            dxDrawText(b.mesaj,bx2+16,by2,bx2+bw2-8,by2+44,
                tocolor(255,255,255,ba),0.95,"default-bold","left","center")
            by2=by2-50
        end
    end

    -- Hover
    if menuAcik and menuAlpha>100 then
        local cx,cy=getCursorPosition()
        if cx and cy then
            cx=cx*ekranG cy=cy*ekranY
            hoveredBtn=nil
            for id,b in pairs(kayitliButonlar) do
                if inRect(cx,cy,b.x,b.y,b.w,b.h) then hoveredBtn=id break end
            end
        end
    end
end)

-- =====================
-- TIKLAMA
-- =====================
addEventHandler("onClientClick",root,function(btn,durum,x,y)
    if btn~="left" or durum~="down" then return end
    if not menuAcik or menuAlpha<140 then return end

    local t=nil
    for id,b in pairs(kayitliButonlar) do
        if inRect(x,y,b.x,b.y,b.w,b.h) then t=id break end
    end
    if not t then return end

    if t=="kapat" then
        menuAcik=false showCursor(false)
        -- NPC tekrar orijinal yöne baksın
        if npcPed and isElement(npcPed) then setPedRotation(npcPed,180) end

    elseif t=="iade" then
        triggerServerEvent("kira:araciIadeEt",localPlayer)

    elseif t:sub(1,5)=="arac_" then
        local i=tonumber(t:sub(6))
        if i then
            triggerServerEvent("kira:araciKirala",localPlayer,i)
        end
    end
end)

-- =====================
-- E TUŞU - NPC ile konuş
-- =====================
addEventHandler("onClientKey",root,function(key,press)
    if not press then return end

    if key=="e" then
        if menuAcik then
            menuAcik=false showCursor(false) return
        end
        if npcYakinMi() then
            menuAcik=true showCursor(true)
            butonTemizle()
            triggerServerEvent("kira:listeIste",localPlayer)
            -- NPC oyuncuya baksın
            if npcPed and isElement(npcPed) then
                local px,py=getElementPosition(localPlayer)
                local nx,ny=getElementPosition(npcPed)
                setPedRotation(npcPed,math.deg(math.atan2(px-nx,py-ny)))
            end
        end
    end

    if key=="F5" then
        if menuAcik then
            menuAcik=false showCursor(false) return
        end
        if npcYakinMi() then
            menuAcik=true showCursor(true)
            butonTemizle()
            triggerServerEvent("kira:listeIste",localPlayer)
        else
            bildirimEkle("warn","NPC'ye yaklasın! (Ahmet - Kira Gorevlisi)")
        end
    end
end)

addCommandHandler("kirala",function()
    if not npcYakinMi() then
        bildirimEkle("warn","Once Ahmet'e yaklasın!")
        return
    end
    menuAcik=not menuAcik
    showCursor(menuAcik)
    if menuAcik then
        butonTemizle()
        triggerServerEvent("kira:listeIste",localPlayer)
    end
end)

-- =====================
-- SERVER EVENTLER
-- =====================
addEvent("kira:listeGeldi",true)
addEventHandler("kira:listeGeldi",localPlayer,function(liste)
    aracListesi=liste
end)

addEvent("kira:kiralamaBasladi",true)
addEventHandler("kira:kiralamaBasladi",localPlayer,function(isim)
    aktifKira=true kiraIsim=isim kiraTimer=0
    menuAcik=false showCursor(false)
end)

addEvent("kira:iadeBitti",true)
addEventHandler("kira:iadeBitti",localPlayer,function()
    aktifKira=false kiraIsim="" kiraTimer=0
    triggerServerEvent("kira:listeIste",localPlayer)
end)

addEventHandler("onClientResourceStart",resourceRoot,function()
    -- NPC oluştur
    npcOlustur()

    -- Haritada blip
    createBlip(NPC_X,NPC_Y,NPC_Z,55,2,255,160,0,255)

    outputChatBox("Sultan Rent A Car: Ahmet'e git ve [ E ] tusuna bas!",255,160,0)
    triggerServerEvent("kira:listeIste",localPlayer)
end)
