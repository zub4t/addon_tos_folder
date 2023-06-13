
local json = require "json_imc"
local titleList = {}
local availableIdx=1
local member_droplists = {}
local selectedTitle = nil
local DEFAULT_CLAIM_LIST= ""
local show_claim_dispatching = false
local authlist = {}
local checkboxList = {}
local aidx_claimIDTable = {}

function GET_SELECTED_CONTROL()
    return 0, selectedTitle
end

function GUILDINFO_OPTION_INIT_SETTING_CLAIM_TAB()
  
end

function GET_CLAIM_NAME_BY_AIDX(aidx)
    local claimID = aidx_claimIDTable[tostring(aidx)]
    if claimID == nil then
        return nil
    end
    local claimTitle = titleList[tonumber(claimID)]
    return claimTitle
end

local function sort_by_key(tbl, sortFunction)
    local keys = {}
    for key in pairs(tbl) do
      table.insert(keys, key)
    end
  
    table.sort(keys, function(a, b)
      return sortFunction(tonumber(a), tonumber(b))
    end)
  
    return keys
end  

function ON_CLAIM_GET(code, ret_json) -- run once on zone enter
    DEFAULT_CLAIM_LIST= ""
    member_droplists = {}
    availableIdx = 1
    show_claim_dispatching = false
    selectedTitle = nil
    authlist = {}
    checkboxList = {}
    aidx_claimIDTable = {}
    local curFrame = ui.GetFrame("guildinfo")
  
	if code ~= 200 then
		SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_CLAIM_GET")
		return
    end
    local list = json.decode(ret_json)
    list = json.decode(list)
    local sortedKeys = sort_by_key(list, function(a, b) return a < b end)    
    local i = 0
    for j = 1, #sortedKeys do
        local authIdx = sortedKeys[j]
        local authName = list[authIdx]        
        if string.find(authName, "(default)") ~= nil then
            local front, back = string.find(authName, "(default)")
            authName = string.sub(authName, 1, front-2)
            if DEFAULT_CLAIM_LIST ~= "" then
                DEFAULT_CLAIM_LIST = DEFAULT_CLAIM_LIST .. ":" .. authIdx
            else
                DEFAULT_CLAIM_LIST = authIdx
            end
        end
        local authIndex = tonumber(authIdx)
        local layoutName = ""
        if authIndex < 10 then
            -- 길드 마스터 고유 권한이므로 표시하지 않음
        elseif authIndex < 100 then -- 길드 운영
            layoutName = "claimCheckbox2"
        elseif authIndex < 200 then -- 길드 자본
            layoutName = "claimCheckbox3"
        elseif authIndex < 300 then -- 길드 커뮤니티
            layoutName = "claimCheckbox4"
        elseif authIndex < 400 then -- PVP
            layoutName = "claimCheckbox5"
        elseif authIndex < 500 then -- 컨텐츠
            layoutName = "claimCheckbox6"
		elseif authIndex < 600 then	-- 하우징
			layoutName = "claimCheckbox7"
        end
        authlist[i] = { authName, authIdx }

        local grid = GET_CHILD_RECURSIVELY(curFrame, layoutName)
        if grid ~= nil then
            local checkbox = grid:CreateControl("checkbox", authName, 0, 0, 25, 25)
            checkboxList[authIdx] = checkbox
            checkbox:SetText("{@st42}" .. authName)
            --checkbox:SetCheck(1)
            checkbox:SetUserValue("authNum", authIdx)
        end
        i = i + 1
    end

    GUILDMEMBER_LIST_GET()
    GetGuildMemberTitleList("ON_MEMBER_TITLE_GET")
end

function ON_MEMBER_TITLE_GET(code, ret_json)  
    if code ~= 200 then
        SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_MEMBER_TITLE_GET")
    end
    selectedTitle = nil
    local decoded_json = json.decode(ret_json)
    decoded_json = json.decode(decoded_json)

    local list = decoded_json["title"]


    local frame = ui.GetFrame("guildinfo")
    local titleListPanel = GET_CHILD_RECURSIVELY(frame, "titleListPanel")
    titleListPanel:RemoveAllChild()
    titleList = {}

    for key, value in pairs(list) do
        titleList[tonumber(key)] = value
    end
    local titleIndex = 1
    for index, titleName in pairs(titleList) do
        local newTitleTxt = titleListPanel:CreateOrGetControlSet("selective_richtext", titleName, 0, 0)
        newTitleTxt:Resize(titleListPanel:GetWidth()-25, newTitleTxt:GetHeight())
        newTitleTxt = tolua.cast(newTitleTxt, 'ui::CControlSet')

        local NOT_SELECTED_BOX_SKIN = newTitleTxt:GetUserConfig('NOT_SELECTED_BOX_SKIN')  
        SET_TITLE_TXT_VALUE(newTitleTxt,"SHOW_TITLE_CLAIM", index, titleName)
        local bg = GET_CHILD_RECURSIVELY(newTitleTxt, "skinBox")
        if titleIndex % 2 == 0 then
            bg:SetSkinName(NOT_SELECTED_BOX_SKIN)
        else
            bg:SetSkinName('None')
        end
        bg:SetUserValue('defaultSkin', bg:GetSkinName())

        titleIndex = titleIndex + 1
    end
    GBOX_AUTO_ALIGN(titleListPanel, 0, 0, 0, true, false)
    titleListPanel:Invalidate()
    GUILDMEMBER_LIST_GET()
end

function SET_TITLE_TXT_VALUE(newTitleTxt, bindFunc, idx, titleText)
    local labelText = GET_CHILD_RECURSIVELY(newTitleTxt, "infoText")
    labelText:SetText("{@st41}" .. titleText)
    labelText:SetUserValue("name", titleText)
    labelText:SetTextAlign("center", "center")
    newTitleTxt:SetEventScript(ui.LBUTTONUP, bindFunc)
    newTitleTxt:SetUserValue("idx", idx)
    newTitleTxt:Invalidate()
end

local curPage = 1
local scrolledTime = 0
local finishedLoading = false
function GUILDMEMBER_LIST_GET()
    local frame = ui.GetFrame("guildinfo")
    
    curPage = 1
    scrolledTime = 0
    finishedLoading = false

    local memberList = GET_CHILD_RECURSIVELY(frame, "claimMemberList")
    if memberList:GetChildCount() ~= 0 then
        memberList:RemoveAllChild()		
    end
    memberList:SetScrollPos(0)

    for i = 1, curPage do
        GUILDMEMBER_LIST_CREATE(frame, i)
    end
end

function ON_PLAYER_MEMBER_TITLE_GET(code, ret_json)
    if ret_json == "\"null\"" or ret_json == "" then
        return
    end
    if code ~= 200 then        
        return
    end
    local decoded_json = json.decode(ret_json)
	
    local frame = ui.GetFrame("guildinfo")
    local memberList = GET_CHILD_RECURSIVELY(frame, "claimMemberList")    
    if memberList:GetChildCount() ~= 0 then
        if decoded_json['aidx'] ~= nil then            
            local controlset = memberList:GetControlSet("guild_claim_set", decoded_json['aidx'])
            local selectedDropList = GET_CHILD_RECURSIVELY(controlset, "claimList")
            if selectedDropList ~= nil and decoded_json['title_id'] ~= nil then
                selectedDropList:SelectItemByKey(decoded_json['title_id'])
            end

            if decoded_json['title_id'] ~= nil then
                aidx_claimIDTable[decoded_json['aidx']] = decoded_json['title_id']
            end
        end
    end
end

function ON_GUILDINFO_MEMBER_TITLE_GET(code, ret_json)
    if ret_json == "\"null\"" or ret_json == "" then
        return
    end

    if code ~= 200 then
        SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_GUILDINFO_MEMBER_TITLE_GET")
        return
    end

    local decoded_json = json.decode(ret_json)
    local aid = decoded_json['aidx']
    if aid == nil then
        return
    end

    if decoded_json['title_id'] ~= nil then
        aidx_claimIDTable[aid] = decoded_json['title_id']
    end
end

function SAVE_TITLE(frame, control)
    if selectedTitle == nil or authlist == nil then
        return
    end
    local curFrame = ui.GetFrame("guildinfo")
    local authPanel = GET_CHILD_RECURSIVELY(curFrame, "claimAuthPanel", "ui::CScrollPanel")
    local authStr = ""
    for idx, authName in pairs(authlist) do
        local checkbox = GET_CHILD_RECURSIVELY(authPanel, authName[1], "ui::CCheckBox")
        checkbox = tolua.cast(checkbox, "ui::CCheckBox")
        if checkbox ~= nil and checkbox:IsChecked() == 1 then
            authStr = authStr .. authName[2] ..":"
        end
    end
    if string.len(authStr) ~= 0 then 
        authStr = authStr:sub(1, -2)
    end
    local titleName = GET_CHILD(selectedTitle, "infoText"):GetUserValue("name")
    local claimInputTxt = GET_CHILD_RECURSIVELY(curFrame, "claimInputTxt", "ui::CEdit")
    local newName = claimInputTxt:GetText()
    if newName ~= "" then
        titleName = newName
    end
    claimInputTxt:SetEnable(0)
    PutGuildMemberTitle("ON_PUT_GUILDMEMBER", selectedTitle:GetUserValue("idx"), titleName, authStr)    
end

local delete_player_aid = '0'

function PUT_PLAYER_TITLE(frame, control)    
    delete_player_aid = '0'
    local selectedKey = control:GetSelItemKey()
    if selectedKey == "" then        
        DeletePlayerMemberTitle('ON_DELETE_PLAYER_MEMBERTITLE', tostring(control:GetUserValue("account_idx")))
        delete_player_aid = tostring(control:GetUserValue("account_idx"))
        aidx_claimIDTable[control:GetUserValue("account_idx")] = control:GetSelItemKey()
        return
    end

    aidx_claimIDTable[control:GetUserValue("account_idx")] = control:GetSelItemKey()
    PutPlayerMemberTitle("ON_PLAYER_PUT_TITLE", control:GetUserValue("account_idx"), control:GetSelItemKey())
end

function ON_DELETE_PLAYER_MEMBERTITLE(code, ret_json)
    if code ~= 200 then
        SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_DELETE_PLAYER_MEMBERTITLE")
        return
    end

    if delete_player_aid ~= '0' then
        GetPlayerMemberTitle("ON_PLAYER_MEMBER_TITLE_GET", delete_player_aid)
    end
end

function ON_PLAYER_PUT_TITLE(code, ret_json)
    if code ~= 200 then
        SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_PLAYER_PUT_TITLE")
        return
    end
end

function ADD_NEW_TITLE()
    local curFrame = ui.GetFrame("guildinfo")
    local claimInput = GET_CHILD_RECURSIVELY(curFrame, "claimInputTxt", "ui::CEditBox")
    if claimInput:GetText() == "" then
        return
    end

    local titleListPanel = GET_CHILD_RECURSIVELY(curFrame, "titleListPanel", "ui::CScrollPanel")
    if GET_CHILD_RECURSIVELY(titleListPanel, claimInput:GetText()) ~= nil then
        ui.MsgBox(ClMsg("DuplicateClaim")) -- 중복되는 직급이 있습니다.
        return
    end

    local curFrame = ui.GetFrame("guildinfo")

    local claimInput = GET_CHILD_RECURSIVELY(curFrame, "claimInputTxt", "ui::CEditBox")
   
    availableIdx = 1
    for index = 1, #titleList do
        if titleList[index] == nil then
            availableIdx = index

            PutGuildMemberTitle("ON_PUT_GUILDMEMBER_NEW", availableIdx, claimInput:GetText(), DEFAULT_CLAIM_LIST)
            return
        else
            availableIdx = availableIdx + 1
        end
    end
    PutGuildMemberTitle("ON_PUT_GUILDMEMBER_NEW", availableIdx, claimInput:GetText(), DEFAULT_CLAIM_LIST)
    return

end

function ON_PUT_GUILDMEMBER_NEW(code, ret_json)    
    if code ~= 200 then
        SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_PUT_GUILDMEMBER_NEW")

        return
    end

    local curFrame = ui.GetFrame("guildinfo")
    local claimInput = GET_CHILD_RECURSIVELY(curFrame, "claimInputTxt", "ui::CEditBox")    
    local titleListPanel = GET_CHILD_RECURSIVELY(curFrame, "titleListPanel", "ui::CScrollPanel")
    titleList[availableIdx] = claimInput:GetText()
    local textName = claimInput:GetText()
    local newClaimTxt = titleListPanel:CreateOrGetControlSet("selective_richtext", textName, 0, 0)
    newClaimTxt:Resize(titleListPanel:GetWidth()-25, newClaimTxt:GetHeight())
    local infoText = GET_CHILD(newClaimTxt, "infoText")
    infoText:SetText("{@st41}" .. textName)
    infoText:SetUserValue("name", textName)

    newClaimTxt:SetEventScript(ui.LBUTTONUP, "SHOW_TITLE_CLAIM")
    newClaimTxt:SetUserValue("idx", availableIdx)

    REPAINT_TITLE_BG()

    local size=0
    local memberList = GET_CHILD_RECURSIVELY(curFrame, "claimMemberList")    
    for index, aid in pairs(member_droplists) do
        local memberCtrlSet = memberList:GetControlSet("guild_claim_set", aid)
        local droplist = GET_CHILD_RECURSIVELY(memberCtrlSet, "claimList", "ui::CDropList")
        if droplist ~= nil then
            droplist = tolua.cast(droplist, "ui::CDropList")
            droplist:AddItem(availableIdx, textName, size)  
            size = size + 1
        end
    end

    claimInput:SetText("")
    GBOX_AUTO_ALIGN(titleListPanel, 0, 0, 45, true, false, true)    
end

function ON_PUT_GUILDMEMBER(code, ret_json)
    local curFrame = ui.GetFrame("guildinfo")
    
    local claimInput = GET_CHILD_RECURSIVELY(curFrame, "claimInputTxt", "ui::CEditBox")
    claimInput:SetEnable(1)

    if code ~= 200 then
        SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_PUT_GUILDMEMBER")

        return
    end

    if selectedTitle == nil then
        return
    end

    ui.SysMsg(ClMsg("UpdateSuccess"))
    
  
    local textName = claimInput:GetText()

    if textName ~= "" then
        --직급 이름 수정함
        local titleName = GET_CHILD(selectedTitle, "infoText")
        titleName:SetUserValue("name", textName)
        titleName:SetText("{@st41}" .. textName)
        titleList[selectedTitle:GetUserValue("idx")] = textName
        local memberList = GET_CHILD_RECURSIVELY(curFrame, "claimMemberList")
        for index, aid in pairs(member_droplists) do
            local memberCtrlSet = memberList:GetControlSet("guild_claim_set", aid)     
            local droplist = GET_CHILD_RECURSIVELY(memberCtrlSet, "claimList", "ui::CDropList")
            if droplist ~= nil then
                droplist:SetItemTextByKey(selectedTitle:GetUserValue("idx"), textName)
            end
        end
        selectedTitle:SetName(textName)
    end
    claimInput:SetText("")
end


function SHOW_TITLE_CLAIM(frame, control)
    if control == nil or show_claim_dispatching == true then
        return
    end

    control =  tolua.cast(control, 'ui::CControlSet')

    if selectedTitle ~= nil then
        if control:GetName() == selectedTitle:GetName() then
            return
        end
    end
    
    local unselectedSkin = control:GetUserConfig("NOT_SELECTED_BOX_SKIN")
    local selectedSkin = control:GetUserConfig("SELECTED_BOX_SKIN")
    local currentSkinBox = GET_CHILD(control, "skinBox") 
    currentSkinBox:SetSkinName(selectedSkin)
    if selectedTitle ~= nil then
        local previousSkinbox = GET_CHILD_RECURSIVELY(selectedTitle, "skinBox")
        previousSkinbox:SetSkinName(previousSkinbox:GetUserValue('defaultSkin'))
    end
    selectedTitle = control
    local curFrame = ui.GetFrame("guildinfo")

    local claimInput = GET_CHILD_RECURSIVELY(curFrame, "claimInputTxt", "ui::CEditBox")
    claimInput:Invalidate()
    GetGuildMemberTitle("ON_UPDATE_CLAIM", control:GetUserValue("idx"))
    show_claim_dispatching = true


end

function ON_UPDATE_CLAIM(code, ret_json)
    show_claim_dispatching = false
    if code ~= 200 then
        SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_UPDATE_CLAIM")
        return
    end

    local decoded_json = json.decode(ret_json)
    local i = 1
    for k, v in pairs(checkboxList) do
        v = AUTO_CAST(v)
        v:SetCheck(0)
    end
    for k, v in pairs(decoded_json) do
        local claimCheckbox = checkboxList[tostring(v)]
        claimCheckbox = AUTO_CAST(claimCheckbox)
        claimCheckbox:SetCheck(1)
    end

end

function DELETE_TITLE(frame, control)
    if selectedTitle == nil then
        return
    end
    DeleteGuildMemberTitle("ON_DELETE_TITLE",  tostring(selectedTitle:GetUserValue("idx")))

end
function ON_DELETE_TITLE(code, ret_json)    
    if code ~= 200 then
        SHOW_GUILD_HTTP_ERROR(code, ret_json, "ON_DELETE_TITLE")
        return
    end
    local curFrame = ui.GetFrame("guildinfo")
    local titleListPanel = GET_CHILD_RECURSIVELY(curFrame, "titleListPanel", "ui::CScrollPanel")
    titleListPanel:RemoveChild(selectedTitle:GetName())
    REPAINT_TITLE_BG()

    local memberList = GET_CHILD_RECURSIVELY(curFrame, "claimMemberList")    
    for index, aid in pairs(member_droplists) do
        local memberCtrlSet = memberList:GetControlSet("guild_claim_set", aid)     
        local droplist = GET_CHILD_RECURSIVELY(memberCtrlSet, "claimList", "ui::CDropList")
        if droplist ~= nil then
            droplist = tolua.cast(droplist, "ui::CDropList")
            if droplist:GetSelItemKey() == selectedTitle:GetUserValue("idx") then
                droplist:SelectItemByKey("")
            end
            droplist:RemoveItem(selectedTitle:GetUserValue("idx"))
        end
    end
    GetGuildMemberTitleList("ON_MEMBER_TITLE_GET")

end

function REPAINT_TITLE_BG()
    local curFrame = ui.GetFrame("guildinfo")
    local titleListPanel = GET_CHILD_RECURSIVELY(curFrame, "titleListPanel", "ui::CScrollPanel")
     
    local childCount = titleListPanel:GetChildCount()

    local ctrlsetIndex=1
	for i=0, childCount-1 do
        local child = titleListPanel:GetChildByIndex(i)
        if child:GetClassName() == "controlset" then
            child = tolua.cast(child, 'ui::CControlSet')
            local NOT_SELECTED_BOX_SKIN = child:GetUserConfig('NOT_SELECTED_BOX_SKIN')
            local bg = GET_CHILD_RECURSIVELY(child, "skinBox")
            if ctrlsetIndex % 2 == 0 then
                bg:SetSkinName(NOT_SELECTED_BOX_SKIN)
            else
                bg:SetSkinName('None')
            end
            bg:SetUserValue('defaultSkin', bg:GetSkinName())
            ctrlsetIndex = ctrlsetIndex + 1
        end
    end

end

function GUILDMEMBER_LIST_CREATE(frame, page)
    finishedLoading = true
    
    local memberList = GET_CHILD_RECURSIVELY(frame, "claimMemberList")

    local guild = GET_MY_GUILD_INFO()
    local list = session.party.GetPartyMemberListbyPage(PARTY_GUILD, page)
    local count = list:Count()

    if count == 0 then
        return;
    end

    local edit = GET_CHILD_RECURSIVELY(frame, "memberSearch");
    local cap = edit:GetText();

    local call_count = 0

    for i = 0, count - 1 do
        local partyMemberInfo = list:Element(i)
        if partyMemberInfo:GetAID() ~= guild.info:GetLeaderAID() then
            if SEARCH_GUILD_MEMBER_MATCH_NAME(partyMemberInfo:GetName() ,cap) == true then
                local memberCtrlSet = memberList:CreateOrGetControlSet("guild_claim_set", partyMemberInfo:GetAID(), 0, 0)            
                
                local memberText = GET_CHILD_RECURSIVELY(memberCtrlSet, "memberNameLabel", "ui::CRichText")
                memberText:SetText(partyMemberInfo:GetName())
                -- job
                local jobID = partyMemberInfo:GetIconInfo().job
                local jobCls = GetClassByType('Job', jobID)
                local jobName = TryGetProp(jobCls, 'Name')
                local memberJob =  GET_CHILD_RECURSIVELY(memberCtrlSet, "memberJobLabel") 
                if jobName ~= nil then
                    memberJob:SetText(jobName)
                else
                    memberJob:SetText("None")
                end

                local memberLvl = GET_CHILD_RECURSIVELY(memberCtrlSet, "memberLvlLabel")
                memberLvl:SetText(partyMemberInfo:GetLevel())

                local memberObj = GetIES(partyMemberInfo:GetObject())
                local membercontribLabel = GET_CHILD_RECURSIVELY(memberCtrlSet, "memberContribLabel")
                membercontribLabel:SetText(memberObj.Contribution)

                local memberTitleList = GET_CHILD_RECURSIVELY(memberCtrlSet, "claimList", "ui::CDropList")
                memberTitleList:SetUserValue("account_idx", partyMemberInfo:GetAID())
                memberTitleList:AddItem("", "", 0)

			    member_droplists[partyMemberInfo:GetAID()] = partyMemberInfo:GetAID()

                local i = 1
                if titleList ~= nil then                    
                    for index, titleName in pairs(titleList) do
                        memberTitleList:AddItem(index, titleName, i)
                        i = i + 1
                    end
                end

                -- 설정 - 직급과 권한 , 직급 드랍리스트에 현재 길드원의 직급 표시
                if aidx_claimIDTable[tostring(partyMemberInfo:GetAID())] ~= nil then
                    memberTitleList:SelectItemByKey(aidx_claimIDTable[tostring(partyMemberInfo:GetAID())])
                else
                    call_count = call_count + 1
                    ReserveScript('GET_PLAYER_MEMBER_TITLE(\"' .. partyMemberInfo:GetAID() .. "\")", call_count * 0.3)
                end
            end       
        end
    end

    GBOX_AUTO_ALIGN(memberList, 0, 0, 45, true, false, true)

    if  memberList:IsScrollBarVisible() == false then
        curPage = curPage + 1
        GUILDMEMBER_LIST_CREATE(frame, curPage)
    end
end

function GET_PLAYER_MEMBER_TITLE(aid)
    GetPlayerMemberTitle("ON_PLAYER_MEMBER_TITLE_GET", aid)
end

function GUILDMEMBER_LIST_GET_SCROLL(parent, ctrl)
    local frame = parent:GetTopParentFrame()
    if frame:IsVisible() == 0 then
        return
    end

    if ctrl:IsScrollEnd() == true and finishedLoading == true then
        local now = imcTime.GetAppTime()
        local dif = now - scrolledTime

        if 1 < dif then
            finishedLoading = false
            curPage = curPage + 1
            
            GUILDMEMBER_LIST_CREATE(frame, curPage)

            scrolledTime = now
        end
    end
end

function SEARCH_GUILD_MEMBER_MATCH_NAME(name, cap)
	if cap == "" then
		return true
	end

	if string.find(name, cap) ~= nil then
		return true;
	end

	return false;
end