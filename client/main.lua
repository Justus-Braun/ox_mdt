if not lib then return end

local hasLoadedUi = false

local function openMdt()
    local isAuthorised, callSign = lib.callback.await('ox_mdt:openMdt', 500)

    if isAuthorised then
        if not hasLoadedUi then
            SendNUIMessage({
                action = 'setLocales',
                data = lib.getLocales()
            })

            hasLoadedUi = true
        end

        local group = GlobalState['group.police'] --[[@as OxGroupProperties]]
        local grade = player.groups.police

        SendNUIMessage({
            action = 'setVisible',
            data = {
                stateId = player.stateid,
                firstName = player.firstname,
                lastName = player.lastname,
                unit = LocalPlayer.state.mdtUnitId,
                title = ('%s %s'):format(group.label:gsub('[%U]', ''), group.grades[player.groups.police]),
                grade = grade,
                callSign = callSign,
                isDispatch = true
            }
        })

        SetNuiFocus(true, true)
    end
end

exports('openMdt', openMdt)

lib.addKeybind({
    defaultKey = 'm',
    description = 'Open the Police MDT',
    name = 'openMdt',
    onPressed = openMdt
})

local callsAreFocused = false

lib.addKeybind({
    defaultKey = 'GRAVE',
    description = 'Toggle MDT calls focus',
    name = 'focusCalls',
    onPressed = function()
        if callsAreFocused then
            callsAreFocused = false
            SetNuiFocus(false, false)
            SetNuiFocusKeepInput(false)
            return
        end

        if IsNuiFocused() or IsPauseMenuActive() then return end

        callsAreFocused = true

        SetNuiFocus(true, true)
        SetNuiFocusKeepInput(true)
        SetCursorLocation(0.5, 0.5)

        while callsAreFocused do
            DisablePlayerFiring(cache.playerId, true)
            DisableControlAction(0, 1, true)
            DisableControlAction(0, 2, true)
            DisableControlAction(2, 199, true)
            DisableControlAction(2, 200, true)
            Wait(0)
        end
    end
})

AddEventHandler('ox:playerLoaded', function(data)
    hasLoadedUi = false
end)

RegisterNuiCallback('hideMDT', function(_, cb)
    cb(1)
    SetNuiFocus(false, false)
end)

---@param event string
---@param clientCb? fun(data: any, cb: function)
local function serverNuiCallback(event, clientCb)
    RegisterNuiCallback(event, function(data, cb)
        print('triggered ' .. event)
        local response = lib.callback.await('ox_mdt:' .. event, false, data)
        print('response ' .. event, json.encode(response, { indent = true, sort_keys = true }))
        if clientCb then return clientCb(response, cb) end
        cb(response)
    end)
end


-- Dashboard
serverNuiCallback('getAnnouncements')
serverNuiCallback('getWarrants')
serverNuiCallback('createAnnouncement')
serverNuiCallback('editAnnouncement')
serverNuiCallback('deleteAnnouncement')

-- Reports
serverNuiCallback('getCriminalProfiles')
serverNuiCallback('createReport')
serverNuiCallback('getReports')
serverNuiCallback('getReport')
serverNuiCallback('deleteReport')
serverNuiCallback('setReportTitle')
serverNuiCallback('getSearchOfficers')
serverNuiCallback('addCriminal')
serverNuiCallback('removeCriminal')
serverNuiCallback('saveCriminal')
serverNuiCallback('addOfficer')
serverNuiCallback('removeOfficer')
serverNuiCallback('addEvidence')
serverNuiCallback('removeEvidence')
serverNuiCallback('saveReportContents')
serverNuiCallback('getRecommendedWarrantExpiry')

-- Profiles
serverNuiCallback('getProfiles')
serverNuiCallback('getProfile')
serverNuiCallback('saveProfileImage')
serverNuiCallback('saveProfileNotes')

-- Dispatch
serverNuiCallback('attachToCall')
serverNuiCallback('completeCall')
serverNuiCallback('detachFromCall')
---@param data Calls
---@param cb fun(data: Calls)
serverNuiCallback('getCalls', function(data, cb)
    -- Assign street names to data from the sever to be sent to UI

    for _, call in pairs(data) do
        call.info.location = GetStreetNameFromHashKey(GetStreetNameAtCoord(call.coords[1], call.coords[2], 0))
    end

    cb(data)
end)
serverNuiCallback('getUnits')
serverNuiCallback('createUnit')
serverNuiCallback('joinUnit')
serverNuiCallback('leaveUnit')
serverNuiCallback('setCallUnits')

---@param data table
---@param cb function
RegisterNuiCallback('setWaypoint', function(data, cb)
    SetNewWaypoint(data[1], data[2])
    cb(1)
end)

---@param data {id: number, call: Call}
RegisterNetEvent('ox_mdt:createCall', function(data)
    data.call.id = data.id
    data.call.info.location = GetStreetNameFromHashKey(GetStreetNameAtCoord(data.call.coords[1], data.call.coords[2], 0))

    -- TODO: play sound (maybe isEmergency later?)

    SendNUIMessage({
        action = 'addCall',
        data = data.call
    })
end)

---@param data {id: number, call: Call}
RegisterNetEvent('ox_mdt:editCallUnits', function(data)
    SendNUIMessage({
        action = 'editCallUnits',
        data = data
    })
end)

---@param data {id: number, coords: table}
RegisterNetEvent('ox_mdt:updateCallCoords', function(data)
    SendNUIMessage({
        action = 'updateCallCoords',
        data = data
    })
end)

---@param data {id: number, units: Units}
RegisterNetEvent('ox_mdt:setCallUnits', function(data)
    SendNUIMessage({
        action = 'setCallUnits',
        data = data
    })
end)

local blips = {}

---@param data Officer[]
RegisterNetEvent('ox_mdt:updateOfficerPositions', function(data)
    if not hasLoadedUi then return end

    for i = 1, #data do
        local officer = data[i]

        if officer.stateId ~= player.stateid then
            local blip = blips[officer.stateId]

            if not blip then
                local name = ('police:%s'):format(officer.stateId)
                blip = AddBlipForCoord(officer.position[2], officer.position[1], officer.position[3])
                blips[officer.stateId] = blip

                SetBlipSprite(blip, 1)
                SetBlipDisplay(blip, 3)
                SetBlipColour(blip, 42)
                ShowFriendIndicatorOnBlip(blip, true)
                AddTextEntry(name, ('%s %s (%s)'):format(officer.firstName, officer.lastName, officer.callSign))
                BeginTextCommandSetBlipName(name)
                EndTextCommandSetBlipName(blip)
                SetBlipCategory(blip, 7)
            else
                SetBlipCoords(blip, officer.position[2], officer.position[1], officer.position[3])
            end
        end
    end

    SendNUIMessage({
        action = 'updateOfficerPositions',
        data = data
    })
end)
