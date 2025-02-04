HVAC_MODES = {}
FAN_MODES = {}
PRESET_MODES = {}
CLIMATE_MODES = {}

HAS_REMOTE_SENSOR = false
REMOTE_SENSOR_UNAVAIL = false
HAS_HUMIDITY = false
SELECTED_SCALE = ""
HOLD_MODES_ENABLED = false
MODE_STATES_ENABLED = false
HOLD_TIMER = nil
HOLD_TIMER_EXPIRED = true

function DRV.OnDriverLateInit(init)
    SELECTED_SCALE = C4:PersistGetValue("CurrentTemperatureScale") or "FAHRENHEIT"
    HAS_REMOTE_SENSOR = C4:PersistGetValue("RemoteSensor") or false
    HOLD_MODES_ENABLED = Properties["Hold Modes Enabled"] or false
    MODE_STATES_ENABLED = Properties["Mode States Enabled"] or false
    local tParams = {
        IN_USE = HAS_REMOTE_SENSOR
    }
    RFP.SET_REMOTE_SENSOR(nil, nil, tParams)
    C4:SetTimer(30000, OnRefreshTimerExpired, true)
    OPC.Hold_Modes_Enabled()
    OPC.Mode_States_Enabled()

    if (SELECTED_SCALE == "FAHRENHEIT") then
        SetCurrentTemperatureScale("FAHRENHEIT")
    else
        SetCurrentTemperatureScale("CELSIUS")
    end
end

function DRV.OnBindingChanged(idBinding, strClass, bIsBound)
    if (bIsBound) then
        if idBinding == 1 then
            C4:SendToProxy(idBinding, "QUERY_SETTINGS", {})
            C4:SendToProxy(idBinding, "GET_SENSOR_VALUE", {})
        end
    end
end

function OPC.Hold_Modes_Enabled(strProperty)
    if (Properties["Hold Modes Enabled"] == "True") then
        C4:SetPropertyAttribs("Clear Hold Entity ID", 0)
        HOLD_MODES_ENABLED = true
        local modes = "Off,Permanent,2 Hours,4 Hours"
        local tParams = {
            MODES = modes
        }
        C4:SendToProxy(5001, 'ALLOWED_HOLD_MODES_CHANGED', tParams, "NOTIFY")
    else
        C4:SetPropertyAttribs("Clear Hold Entity ID", 1)
        HOLD_MODES_ENABLED = false
        C4:SendToProxy(5001, 'ALLOWED_HOLD_MODES_CHANGED', { MODES = "Permanent" }, "NOTIFY")
        C4:SendToProxy(5001, 'HOLD_MODE_CHANGED', { MODE = "Permanent" }, "NOTIFY")
    end
end

function OPC.Mode_States_Enabled(strProperty)
    if (Properties["Mode States Enabled"] == "True") then
        if (MODE_STATES_ENABLED == false) then
            C4:SetPropertyAttribs("Mode Selection Entity ID", 0)
            C4:SetPropertyAttribs("Home Mode Selection", 0)
            C4:SetPropertyAttribs("Away Mode Selection", 0)
            C4:SetPropertyAttribs("Sleep Mode Selection", 0)
        end
        MODE_STATES_ENABLED = true
        tParams = {
            entity = Properties["Mode Selection Entity ID"]
        }
        C4:SendToProxy(999, "HA_GET_STATE", tParams)
        UpdateClimateModes()
        SetupComfortExtras()
    else
        C4:SetPropertyAttribs("Mode Selection Entity ID", 1)
        C4:SetPropertyAttribs("Home Mode Selection", 1)
        C4:SetPropertyAttribs("Away Mode Selection", 1)
        C4:SetPropertyAttribs("Sleep Mode Selection", 1)
        C4:UpdateProperty("Home Mode Selection", "")
        C4:UpdateProperty("Away Mode Selection", "")
        C4:UpdateProperty("Sleep Mode Selection", "")
        MODE_STATES_ENABLED = false
        UpdateClimateModes()
        SetupComfortExtras()
    end
end

function OPC.Home_Mode_Selection(strProperty)
    UpdateClimateModes()
    SetupComfortExtras()
end

function OPC.Away_Mode_Selection(strProperty)
    UpdateClimateModes()
    SetupComfortExtras()
end

function OPC.Sleep_Mode_Selection(strProperty)
    UpdateClimateModes()
    SetupComfortExtras()
end

function OPC.Precision(strProperty)
    local precisionStr = Properties["Precision"]
    local precisionStrF = Properties["Precision"]
    if precisionStrF == ".1" then precisionStrF = ".2" end
    local tParams = {
        TEMPERATURE_RESOLUTION_C = precisionStr,
        TEMPERATURE_RESOLUTION_F = precisionStrF,
        OUTDOOR_TEMPERATURE_RESOLUTION_C = precisionStr,
        OUTDOOR_TEMPERATURE_RESOLUTION_F = precisionStrF,
    }
    C4:SendToProxy(5001, 'DYNAMIC_CAPABILITIES_CHANGED', tParams, "NOTIFY")
end

function RFP.SET_REMOTE_SENSOR(idBinding, strCommand, tParams)
    if tParams.IN_USE == false or tParams.IN_USE == "False" then
        HAS_REMOTE_SENSOR = false
    else
        HAS_REMOTE_SENSOR = true
    end

    C4:SendToProxy(5001, "REMOTE_SENSOR_CHANGED", tParams, "NOTIFY")
    C4:PersistSetValue("RemoteSensor", tParams.IN_USE, false)

    EC.REFRESH()
end

function RFP.VALUE_INITIALIZE(idBinding, strCommand, tParams)
    RFP.VALUE_INITIALIZED(idBinding, strCommand, tParams)
end

function RFP.VALUE_INITIALIZED(idBinding, strCommand, tParams)
    if HAS_REMOTE_SENSOR and idBinding == 1 then
        REMOTE_SENSOR_UNAVAIL = false
        local ScaleStr = SELECTED_SCALE
        local SensorValue
        Connected = true
        local connectParams =
        {
            CONNECTED = "true"
        }

        C4:SendToProxy(5001, "CONNECTION", connectParams, "NOTIFY")

        if (tParams.CELSIUS ~= nil and SELECTED_SCALE == "CELSIUS") then
            SensorValue = tonumber(tParams.CELSIUS)
        else
            SensorValue = tonumber(tParams.FAHRENHEIT)
        end

        local TimeStamp = (tParams.TIMESTAMP ~= nil) and tParams.TIMESTAMP or tostring(os.time())
        C4:SendToProxy(5001, "VALUE_INITIALIZED", { STATUS = "active", TimeStamp }, "NOTIFY")
        C4:SendToProxy(5001, "TEMPERATURE_CHANGED", { TEMPERATURE = tostring(SensorValue), SCALE = ScaleStr }, "NOTIFY")
    end
end

function RFP.VALUE_CHANGED(idBinding, strCommand, tParams)
    if HAS_REMOTE_SENSOR and idBinding == 1 then
        local SensorValue
        if (HAS_REMOTE_SENSOR and REMOTE_SENSOR_UNAVAIL and not (tParams.CELSIUS ~= nil or tParams.FAHRENHEIT ~= nil)) then
            RFP:VALUE_INITIALIZE(strCommand, tParams)
        end
        if (tParams.CELSIUS ~= nil and SELECTED_SCALE == "CELSIUS") then
            SensorValue = tonumber(tParams.CELSIUS)
        elseif (tParams.FAHRENHEIT ~= nil and SELECTED_SCALE == "FAHRENHEIT") then
            SensorValue = tonumber(tParams.FAHRENHEIT)
        else
            SensorValue = tonumber(tParams.FAHRENHEIT)
        end
        C4:SendToProxy(5001, "TEMPERATURE_CHANGED", { TEMPERATURE = tostring(SensorValue), SCALE = SELECTED_SCALE },
            "NOTIFY")
    end
end

function RFP.VALUE_UNAVAILABLE(idBinding, strCommand, tParams)
    if HAS_REMOTE_SENSOR and idBinding == 1 then
        REMOTE_SENSOR_UNAVAIL = true
        Connected = false
        local connectParams =
        {
            CONNECTED = "false"
        }

        C4:SendToProxy(5001, "CONNECTION", connectParams, "NOTIFY")
    end
end

function RFP.SET_MODE_HOLD(idBinding, strCommand, tParams)
    SetHoldMode(tParams)
end

function RFP.EXTRAS_CHANGE_COMFORT(idBinding, strCommand, tParams)
    SelectClimateMode(tParams)
end

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

function RFP.SET_SCALE(bindingID, action, tParams)
    SetCurrentTemperatureScale(tParams.SCALE)
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
    local cTemperature = tonumber(tParams["CELSIUS"])
    local fTemperature = tonumber(tParams["FAHRENHEIT"])
    local temperatureServiceCall = {}

    if fTemperature <= 0 or cTemperature <= 0 then
        return
    end

    if MODE == "heat_cool" then
        if SELECTED_SCALE == "FAHRENHEIT" then
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
        elseif SELECTED_SCALE == "CELSIUS" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    target_temp_low = cTemperature,
                    target_temp_high = HIGH_TEMP
                },

                target = {
                    entity_id = EntityID
                }
            }
        else
            return
        end
    elseif MODE == "heat" then
        if SELECTED_SCALE == "FAHRENHEIT" then
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
        elseif SELECTED_SCALE == "CELSIUS" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    temperature = cTemperature
                },

                target = {
                    entity_id = EntityID
                }
            }
        else
            return
        end
    end
    if (HOLD_TIMER_EXPIRED == true) then
        RFP:SET_MODE_HOLD("SET_MODE_HOLD", { MODE = "Permanent" })
    end
    tParams = {
        JSON = JSON:encode(temperatureServiceCall)
    }

    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function RFP.SET_SETPOINT_COOL(idBinding, strCommand, tParams)
    local cTemperature = tonumber(tParams["CELSIUS"])
    local fTemperature = tonumber(tParams["FAHRENHEIT"])
    local temperatureServiceCall = {}

    if fTemperature <= 0 then
        return
    end

    if MODE == "heat_cool" then
        if SELECTED_SCALE == "FAHRENHEIT" then
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
        elseif SELECTED_SCALE == "CELSIUS" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    target_temp_low = cTemperature,
                    target_temp_high = HIGH_TEMP
                },

                target = {
                    entity_id = EntityID
                }
            }
        else
            return
        end
    elseif MODE == "cool" then
        if SELECTED_SCALE == "FAHRENHEIT" then
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
        elseif SELECTED_SCALE == "CELSIUS" then
            temperatureServiceCall = {
                domain = "climate",
                service = "set_temperature",

                service_data = {
                    temperature = cTemperature
                },

                target = {
                    entity_id = EntityID
                }
            }
        else
            return
        end
        if (HOLD_TIMER_EXPIRED == true) then
            RFP:SET_MODE_HOLD("SET_MODE_HOLD", { MODE = "Permanent" })
        end
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
        return
    end

    if data["entity_id"] == Properties["Mode Selection Entity ID"] and MODE_STATES_ENABLED then
        local options = data["attributes"]["options"]
        local currentMode = data["state"]
        local optionsStringCSV = ""
        for k, v in pairs(options) do
            optionsStringCSV = optionsStringCSV .. tostring(v) .. ","
        end
        if (not string.find(optionsStringCSV, Properties["Home Mode Selection"])) then
            optionsStringCSV = optionsStringCSV .. tostring(Properties["Home Mode Selection"]) .. ","
        end
        if (not string.find(optionsStringCSV, Properties["Away Mode Selection"])) then
            optionsStringCSV = optionsStringCSV .. tostring(Properties["Away Mode Selection"]) .. ","
        end
        if (not string.find(optionsStringCSV, Properties["Sleep Mode Selection"])) then
            optionsStringCSV = optionsStringCSV .. tostring(Properties["Sleep Mode Selection"]) .. ","
        end
        optionsStringCSV = optionsStringCSV:sub(1, -2)
        C4:UpdatePropertyList("Home Mode Selection", optionsStringCSV, Properties["Home Mode Selection"])
        C4:UpdatePropertyList("Away Mode Selection", optionsStringCSV, Properties["Away Mode Selection"])
        C4:UpdatePropertyList("Sleep Mode Selection", optionsStringCSV, Properties["Sleep Mode Selection"])
        UpdateCurrentClimateMode(currentMode)
    end
    if data["entity_id"] ~= EntityID then
        return
    end

    local attributes = data["attributes"]
    local state = data["state"]

    if state == "unavailable" or attributes == nil or (REMOTE_SENSOR_UNAVAIL and HAS_REMOTE_SENSOR) then
        Connected = false
        local tParams =
        {
            CONNECTED = "false"
        }

        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
        return
    end

    if not Connected and state ~= "unavailable" then
        Connected = true

        local tParams =
        {
            CONNECTED = "true"
        }

        C4:SendToProxy(5001, "CONNECTION", tParams, "NOTIFY")
    end

    local selectedAttribute = attributes["hvac_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, HVAC_MODES) then
        HVAC_MODES = attributes["hvac_modes"]

        local modes = table.concat(HVAC_MODES, ",")

        modes = modes:gsub("heat_cool", "Auto")

        local tParams = {
            MODES = modes
        }

        C4:SendToProxy(5001, 'ALLOWED_HVAC_MODES_CHANGED', tParams, "NOTIFY")
    end

    selectedAttribute = attributes["fan_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, FAN_MODES) then
        FAN_MODES = attributes["fan_modes"]

        local modes = table.concat(FAN_MODES, ",")

        local tParams = {
            MODES = modes
        }

        C4:SendToProxy(5001, 'ALLOWED_FAN_MODES_CHANGED', tParams, "NOTIFY")
    end

    selectedAttribute = attributes["preset_modes"]
    if selectedAttribute ~= nil and not TablesMatch(selectedAttribute, PRESET_MODES) then
        PRESET_MODES = attributes["preset_modes"]
    end

    if attributes["current_temperature"] ~= nil and not HAS_REMOTE_SENSOR then
        local temperature = tonumber(attributes["current_temperature"])

        local tParams = {
            TEMPERATURE = temperature,
            SCALE = SELECTED_SCALE
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
    else
        local hvacActionValue = attributes["hvac_action"]
        local fanModeValue = attributes["fan_mode"]
        local fanStateString = ""
        if ((not string.find(hvacActionValue, "idle")) or (string.find(fanModeValue, "on"))) then
            fanStateString = "On"
        else
            fanStateString = "Off"
        end

        local tParams = {
            STATE = fanStateString
        }

        C4:SendToProxy(5001, "FAN_STATE_CHANGED", tParams, "NOTIFY")
    end


    if attributes["hvac_action"] ~= nil then
        local value = attributes["hvac_action"]
        local c4ReportableState = ""
        if (string.find(value, "cool")) then
            c4ReportableState = "Cool"
        else
            if (string.find(value, "heat")) then
                c4ReportableState = "Heat"
            else
                c4ReportableState = "Off"
            end
        end
        local tParams = {
            STATE = c4ReportableState
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
                SCALE = SELECTED_SCALE
            }

            C4:SendToProxy(5001, "HEAT_SETPOINT_CHANGED", tParams, "NOTIFY")

            LOW_TEMP = tempValue
        elseif state == "cool" then
            local tParams = {
                SETPOINT = tempValue,
                SCALE = SELECTED_SCALE
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
            SCALE = SELECTED_SCALE
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
            SCALE = SELECTED_SCALE
        }

        C4:SendToProxy(5001, "HEAT_SETPOINT_CHANGED", tParams, "NOTIFY")

        LOW_TEMP = tempValue
        HIGH_TEMP = otherValue
    end
end

function SetCurrentTemperatureScale(scaleStr)
    SELECTED_SCALE = scaleStr
    C4:PersistSetValue("CurrentTemperatureScale", SELECTED_SCALE)
    NotifyCurrentTemperatureScale()
end

function NotifyCurrentTemperatureScale()
    C4:SendToProxy(5001, "SCALE_CHANGED", { SCALE = SELECTED_SCALE }, "NOTIFY")
end

function SetupComfortExtras()
    local defaultExtras = nil
    if (not MODE_STATES_ENABLED) then
        defaultExtras = [[
		
	    ]]
    else
        defaultExtras = [[
		    <section label="Comfort Setting Select">
			    <object type="list" id="comfortSwitch" label="Comfort Setting" command="EXTRAS_CHANGE_COMFORT">
				    <list maxselections="1" minselections="1">
	    ]]

        for k, v in pairs(CLIMATE_MODES or {}) do
            defaultExtras = defaultExtras .. '<item text="' .. v.name .. '" value="' .. v.ref .. '"/>'
        end

        defaultExtras = defaultExtras .. [[
				    </list>
			    </object>
		    </section>
	    ]]
    end
    local xml = {
        [[<extras_setup><extra>]],
        defaultExtras,
        [[</extra></extras_setup>]],
    }
    xml = table.concat(xml)
    C4:SendToProxy(5001, "EXTRAS_SETUP_CHANGED", { XML = xml })
end

function HoldTimerExpired(timer, skips)
    HOLD_TIMER_EXPIRED = true
    timer.Cancel()
    ClearThermostatHold()
    RFP:SET_MODE_HOLD("SET_MODE_HOLD", { MODE = "Off" })
end

function UpdateClimateModes()
    if (MODE_STATES_ENABLED == true) then
        CLIMATE_MODES = {
            {
                ref = Properties["Away Mode Selection"] or "away",
                name = "Away",
            },
            {
                ref = Properties["Home Mode Selection"] or "home",
                name = "Home",
            },
            {
                ref = Properties["Sleep Mode Selection"] or "sleep",
                name = "Sleep",
            },
        }
    else
        CLIMATE_MODES = {}
    end
end

function UpdateCurrentClimateMode(ref)
    local xml = '<object id="comfortSwitch" value="' .. ref .. '"/>'
    UpdateExtras(xml)
end

function UpdateExtras(xml)
    local xmlPackage = {
        [[<extras_state><extra>]],
        (xml or ''),
        [[</extra></extras_state>]],
    }
    xmlPackage = table.concat(xmlPackage)

    C4:SendToProxy(5001, 'EXTRAS_STATE_CHANGED', { XML = xmlPackage }, "NOTIFY")
end

function GetNumbersFromText(txt)
    local str = ""
    string.gsub(txt, "%d+", function(e) str = str .. e end)
    return str;
end

function ClearThermostatHold()
    local buttonPressServiceCall = {
        domain = "button",
        service = "press",
        service_data = {
        },
        target = {
            entity_id = Properties["Clear Hold Entity ID"]
        }
    }

    local tParams = {
        JSON = JSON:encode(buttonPressServiceCall)
    }
    C4:SendToProxy(999, "HA_CALL_SERVICE", tParams)
end

function SetHoldMode(tParams)
    if (tostring(tParams.MODE) == "Permanent") then
        if HOLD_TIMER ~= nil then
            HOLD_TIMER.Cancel()
            HOLD_TIMER_EXPIRED = true
        end
    elseif (tostring(tParams.MODE) == "Off") then
        if HOLD_TIMER ~= nil then
            HOLD_TIMER.Cancel()
            HOLD_TIMER_EXPIRED = true
        end
        ClearThermostatHold()
    else
        local hourValue = tonumber(GetNumbersFromText(tParams.MODE))
        if (HOLD_TIMER_EXPIRED == false) then
            HOLD_TIMER.Cancel()
            HOLD_TIMER_EXPIRED = true
        end
        HOLD_TIMER = C4:SetTimer(hourValue * 60 * 60 * 1000, function(timer, skips) HoldTimerExpired(timer, skips) end,
            false)
        HOLD_TIMER_EXPIRED = false
    end
    C4:SendToProxy(5001, 'HOLD_MODE_CHANGED', tParams, "NOTIFY")
end

function SelectClimateMode(tParams)
    local selectServiceCall = {
        domain = "select",
        service = "select_option",
        service_data = {
            option = tParams.value,
        },
        target = {
            entity_id = Properties["Mode Selection Entity ID"]
        }
    }
    local requestParams = {
        JSON = JSON:encode(selectServiceCall)
    }
    C4:SendToProxy(999, "HA_CALL_SERVICE", requestParams)
end

function OnRefreshTimerExpired()
    EC.REFRESH()
    if (MODE_STATES_ENABLED) then
        tParams = {
            entity = Properties["Mode Selection Entity ID"]
        }
        C4:SendToProxy(999, "HA_GET_STATE", tParams)
    end
end
