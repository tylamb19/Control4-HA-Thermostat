TARGET_TEMPERATURE = 1
TARGET_TEMPERATURE_RANGE = 2
TARGET_HUMIDITY = 4
FAN_MODE = 8
PRESET_MODE = 16
SWING_MODE = 32
AUX_HEAT = 64

HVAC_MODES = {}
FAN_MODES = {}
PRESET_MODES = {}

HAS_HUMIDITY = false

local EnumToCapability = {
    [TARGET_TEMPERATURE] = "TARGET_TEMPERATURE",
    [TARGET_TEMPERATURE_RANGE] = "TARGET_TEMPERATURE_RANGE",
    [TARGET_HUMIDITY] = "TARGET_HUMIDITY",
    [FAN_MODE] = "FAN_MODE",
    [PRESET_MODE] = "PRESET_MODE",
    [SWING_MODE] = "SWING_MODE",
    [AUX_HEAT] = "AUX_HEAT",
}

function RFP.SET_MODE_HVAC(idBinding, strCommand, tParams)
    local mode = tParams["MODE"]

    if mode == "Auto" then
        mode = "heat_cool"
    end

    local hvacModeServiceCall = {
        domain = "climate",
        service = "set_hvac_mode",

        service_data = {
            hvac_mode = mode
        },

        target = {
            entity_id = EntityID
        }
    }

    tParams = {
        JSON = JSON:encode(hvacModeServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_MODE_FAN(idBinding, strCommand, tParams)
    local mode = tParams["MODE"]

    local hvacModeServiceCall = {
        domain = "climate",
        service = "set_fan_mode",

        service_data = {
            fan_mode = mode
        },

        target = {
            entity_id = EntityID
        }
    }

    tParams = {
        JSON = JSON:encode(hvacModeServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_SETPOINT_HEAT(idBinding, strCommand, tParams)
    local fTemperature = tonumber(tParams["FAHRENHEIT"])
    local temperatureServiceCall = {}

    if fTemperature <= 0 then
        return
    end

    if MODE == "heat_cool" then
        temperatureServiceCall = {
            domain = "climate",
            service = "set_temperature",

            service_data = {
                target_temp_low = fTemperature,
                target_temp_high = HIGH_TEMP
            },

            target = {
                entity_id = EntityID
            }
        }
    elseif MODE == "heat" then
        temperatureServiceCall = {
            domain = "climate",
            service = "set_temperature",

            service_data = {
                temperature = fTemperature
            },

            target = {
                entity_id = EntityID
            }
        }
    end

    tParams = {
        JSON = JSON:encode(temperatureServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_SETPOINT_COOL(idBinding, strCommand, tParams)
    local fTemperature = tonumber(tParams["FAHRENHEIT"])
    local temperatureServiceCall = {}

    if fTemperature <= 0 then
        return
    end

    if MODE == "heat_cool" then
        temperatureServiceCall = {
            domain = "climate",
            service = "set_temperature",

            service_data = {
                target_temp_high = fTemperature,
                target_temp_low = LOW_TEMP
            },

            target = {
                entity_id = EntityID
            }
        }
    elseif MODE == "cool" then
        temperatureServiceCall = {
            domain = "climate",
            service = "set_temperature",

            service_data = {
                temperature = fTemperature
            },

            target = {
                entity_id = EntityID
            }
        }
    end

    tParams = {
        JSON = JSON:encode(temperatureServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.RECEIEVE_STATE(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.response)

    local stateData

    if jsonData ~= nil then
        stateData = jsonData
    end

    Parse(stateData)
end

function RFP.RECEIEVE_EVENT(idBinding, strCommand, tParams)
    local jsonData = JSON:decode(tParams.data)

    local eventData

    if jsonData ~= nil then
        eventData = jsonData["event"]["data"]["new_state"]
    end

    Parse(eventData)
end

function Parse(data)
    if data == nil then
        print("NO DATA")
        return
    end

    if data["entity_id"] ~= EntityID then
        return
    end

    if not Connected then
        Connected = true

        local tParams =
        {
            CONNECTED = "true"
        }

        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
    end

    local attributes = data["attributes"]
    local state = data["state"]

    if attributes == nil then
        local tParams =
        {
            CONNECTED = "false"
        }

        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
        return
    end

    local selectedAttribute = attributes["hvac_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, HVAC_MODES) then
        HVAC_MODES = attributes["hvac_modes"]

        local modes = table.concat(HVAC_MODES,",")

        modes = modes:gsub("heat_cool", "Auto")

        local tParams = {
            MODES = modes
        }

        C4:SendToProxy(5001, 'ALLOWED_HVAC_MODES_CHANGED', tParams, "NOTIFY")
    end

    selectedAttribute = attributes["fan_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, FAN_MODES) then
        FAN_MODES = attributes["fan_modes"]

        local modes = table.concat(FAN_MODES,",")

        local tParams = {
            MODES = modes
        }

        C4:SendToProxy(5001, 'ALLOWED_FAN_MODES_CHANGED', tParams, "NOTIFY")
    end

    selectedAttribute = attributes["preset_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, PRESET_MODES) then
        PRESET_MODES = attributes["preset_modes"]
    end

    if attributes["current_temperature"] ~= nil then
        local temperature = tonumber(attributes["current_temperature"])

        local tParams = {
            TEMPERATURE = temperature,
            SCALE = "F"
        }

        C4:SendToProxy(5001, "TEMPERATURE_CHANGED", tParams, "NOTIFY")
    end

    selectedAttribute = attributes["current_humidity"]
    if selectedAttribute ~= nil then
        local tParams = {
            HUMIDITY = tonumber(attributes["current_humidity"])
        }

        C4:SendToProxy(5001, "HUMIDITY_CHANGED", tParams, "NOTIFY")

        if HAS_HUMIDITY == false then
            HAS_HUMIDITY = true

            local tParams = {
                HAS_HUMIDITY = HAS_HUMIDITY
            }
    
            C4:SendToProxy(5001, 'DYNAMIC_CAPABILITIES_CHANGED', tParams, "NOTIFY")
        end
    else
        if HAS_HUMIDITY == true then
            HAS_HUMIDITY = false
            
            local tParams = {
                HAS_HUMIDITY = HAS_HUMIDITY
            }
    
            C4:SendToProxy(5001, 'DYNAMIC_CAPABILITIES_CHANGED', tParams, "NOTIFY")
        end
    end

    if attributes["fan_mode"] ~= nil then
        local value = attributes["fan_mode"]

        local tParams = {
            MODE = value
        }

        C4:SendToProxy(5001, "FAN_MODE_CHANGED", tParams, "NOTIFY")
    end

    if attributes["fan_state"] ~= nil then
        local value = attributes["fan_state"]
        local fanStateString = ""
        if string.find(value, "off") or string.find(value, "Idle") then
            fanStateString = "Off"
        else
            fanStateString = "On"
        end

        local tParams = {
            STATE = fanStateString
        }

        C4:SendToProxy(5001, "FAN_STATE_CHANGED", tParams, "NOTIFY")
    end

    if attributes["hvac_action"] ~= nil then
        local value = attributes["hvac_action"]

        local tParams = {
            STATE = value
        }

        C4:SendToProxy(5001, "HVAC_STATE_CHANGED", tParams, "NOTIFY")
    end

    if state ~= nil then
        MODE = state

        if state == "heat_cool" then
            state = "Auto"
        end

        local tParams = {
            MODE = state
        }

        C4:SendToProxy(5001, "HVAC_MODE_CHANGED", tParams, "NOTIFY")
    end

    if attributes["temperature"] ~= nil and attributes["temperature"] ~= "null" then
        local tempValue = tonumber(attributes["temperature"])

        if state == nil then
            return
        end

        if state == "heat" then
            local tParams = {
                SETPOINT = tempValue,
                SCALE = "F"
            }

            C4:SendToProxy(5001, "HEAT_SETPOINT_CHANGED", tParams, "NOTIFY")

            LOW_TEMP = tempValue
        elseif state == "cool" then
            local tParams = {
                SETPOINT = tempValue,
                SCALE = "F"
            }

            C4:SendToProxy(5001, "COOL_SETPOINT_CHANGED", tParams, "NOTIFY")

            HIGH_TEMP = tempValue
        end
    end

    if attributes["target_temp_high"] ~= nil and attributes["target_temp_high"] ~= "null" then
        local tempValue = tonumber(attributes["target_temp_high"])
        local otherValue = tonumber(attributes["target_temp_low"])

        local tParams = {
            SETPOINT = tempValue,
            SCALE = "F"
        }

        C4:SendToProxy(5001, "COOL_SETPOINT_CHANGED", tParams, "NOTIFY")

        HIGH_TEMP = tempValue
        LOW_TEMP = otherValue
    end

    if attributes["target_temp_low"] ~= nil and attributes["target_temp_low"] ~= "null" then
        local tempValue = tonumber(attributes["target_temp_low"])
        local otherValue = tonumber(attributes["target_temp_high"])

        local tParams = {
            SETPOINT = tempValue,
            SCALE = "F"
        }

        C4:SendToProxy(5001, "HEAT_SETPOINT_CHANGED", tParams, "NOTIFY")

        LOW_TEMP = tempValue
        HIGH_TEMP = otherValue
    end
end
