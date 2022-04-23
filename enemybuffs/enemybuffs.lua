_addon.author   = 'Jaza (Jaza#6599)';
_addon.name     = 'EnemyBuffs';
_addon.version  = '0.1.0';

require 'common'
require 'd3d8'
require 'imguidef'
require 'debuffed'

-- local fps = { }
-- fps.count = 0
-- fps.timer = 0
-- fps.frame = 0

-- adjustable
local size = 20
local exclusions = {}

-- reassign via script
local winx = 800
local winy = 600
local menux = 0
local menuy = 0
local scalex = 1
local scaley = 1
local sprite = nil
local icons = {}

-- needs to be global so debuffed.lua can access
debuffed_config = {
    durations = {},
    abilityNames = {}
}

ashita.register_event('load', function()
    debuffed_config = ashita.settings.load_merged(_addon.path..'debuffed_settings.json', debuffed_config)

    winx = AshitaCore:GetConfigurationManager():get_int32('boot_config', 'window_x', 800);
	winy = AshitaCore:GetConfigurationManager():get_int32('boot_config', 'window_y', 600);
	menux = AshitaCore:GetConfigurationManager():get_int32('boot_config', 'menu_x', 0);
	menuy = AshitaCore:GetConfigurationManager():get_int32('boot_config', 'menu_y', 0);
	if (menux <= 0) then menux = winx end
    if (menuy <= 0) then menuy = winy end
    scalex = winx/menux
    scaley = winy/menuy

    local res, sp = ashita.d3dx.CreateSprite()
    if (res ~= 0) then
		local _, err = ashita.d3dx.GetErrorStringA(res);
		error(string.format('[Error] Failed to create sprite. - Error: (%08X) %s', res, err));
	end
    sprite = sp

    local f = AshitaCore:GetFontManager():Create("__enemy_buffs_distance")
    f:SetColor(0xFFFFFFFF)
    f:SetFontFamily('Arial')
    f:SetFontHeight(10 * scaley)
    f:SetBold(true)
    f:SetRightJustified(true)
    f:SetPositionX(0)
    f:SetPositionY(0)
    f:SetText('0.0')
    f:SetLocked(true)
    f:SetVisibility(true)
end)

ashita.register_event('render', function()
    -- fps.count = fps.count + 1;
    -- if (os.time() >= fps.timer + 1) then
    --     fps.frame = fps.count;
    --     fps.count = 0;
    --     fps.timer = os.time();
    -- end
    if (AshitaCore:GetFontManager():GetHideObjects()) then
        return
    end

    local f = AshitaCore:GetFontManager():Get("__enemy_buffs_distance")
    local target = AshitaCore:GetDataManager():GetTarget()
    local entity = GetEntity(target:GetTargetIndex())
    
    if (sprite == nil or entity == nil) then
        f:SetVisibility(false)    
        return
    end
	
    local spawn = entity.SpawnFlags
    local status = entity.Status
    local distance = string.format('%.1f', math.sqrt(entity.Distance))

    -- self target
    if (spawn == 525) then
        f:SetVisibility(false)    
        return
    end

    -- calculate position offset from bottom right of window
    local ptoffset = AshitaCore:GetDataManager():GetParty():GetAllianceParty0MemberCount() - 1
    local x_origin = winx - (131 * scalex)
    local y_origin = winy - (74 + (20*ptoffset) ) * scaley
    
    f:SetText(distance)
    f:SetPositionX(x_origin)
    f:SetPositionY(y_origin)
    f:SetVisibility(true)

    local debuffs = get_debuffs_from_entity(entity)
    if (debuffs ~= nil) then
        local xoffset = 0
        local rect = RECT()
        rect.left, rect.top = 0,0
        rect.right, rect.bottom = size, size
        local color = math.d3dcolor(255, 255, 255, 255)

        sprite:Begin()
        local x_debuff = x_origin - (45*scalex)
        local y_debuff = y_origin - (scaley)
        for i, spell_id in pairs(debuffs.debuff) do
            load_icon(spell_id)
            if (icons[spell_id] ~= nil) then
                x_offset = x_debuff - ((i-1)*size*scalex)
                sprite:Draw(
                    icons[spell_id]:Get(),
                    rect, nil, nil, 0.0, 
                    D3DXVECTOR2(x_offset, y_debuff), color
                )
            end
        end
        
        local x_buff = x_origin - (45*scalex)
        local y_buff = y_origin - (size*scaley)
        for i, spell_id in pairs(debuffs.buff) do
            load_icon(spell_id)
            if (icons[spell_id] ~= nil) then
                x_offset = x_buff - ((i-1)*size*scalex)
                sprite:Draw(
                    icons[spell_id]:Get(),
                    rect, nil, nil, 0.0, 
                    D3DXVECTOR2(x_offset, y_buff), color
                )
            end
        end
        sprite:End()
    end
end)


ashita.register_event('unload', function()
    ashita.settings.save(_addon.path..'debuffed_settings.json', debuffed_config);
    AshitaCore:GetFontManager():Delete("__enemy_buffs_distance")
    for key, value in pairs(icons) do
		if (value ~= nil) then value:Release() end
	end
    if (sprite ~= nil) then sprite:Release() end
end)


ashita.register_event('incoming_text', function(mode, message, modifiedmode, modifiedmessage, blocked)
    debuffed_incoming_text(mode, message, modifiedmode, modifiedmessage, blocked)
    return false
end)

ashita.register_event('incoming_packet', function(id, size, data)
    debuffed_incoming_packet(id, size, data)
    -- zone packet, clear anim data
	if (id == 0x0A) then
        for key, value in pairs(icons) do
            if (value ~= nil) then value:Release() end
        end
        icons = {}
    end
    return false
end)


function load_icon(spell_id)
    if (icons[spell_id] == nil) then
        local path = string.format(_addon.path..'\\icons\\%s.png', spell_id)
        local res, _, _, texture = ashita.d3dx.CreateTextureFromFileExA(
            path, size, size, 1, 0, D3DFMT_A8R8G8B8, 1, 0xFFFFFFFF, 0xFFFFFFFF, 0xFF000000)
        if (res ~= 0) then
            local _, err = ashita.d3dx.GetErrorStringA(res);
            print(string.format('[Error] Failed to load background texture for slot: %s - Error: (%08X) %s', name, res, err));
            return
        end
        icons[spell_id] = texture
    end
end

ashita.register_event('command', function(cmd, nType)
    return false
end)

