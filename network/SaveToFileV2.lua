function Initialize()
    CurrPath = SKIN:GetVariable('CURRENTPATH')
    filePath = SKIN:MakePathAbsolute('CumulativeDataV2.txt')
    dailyPath = SKIN:MakePathAbsolute('DailyData.json')
    dailyDataTable = {}
    print('it is running initialize')
end

function Update()
    local cumulativeDownload = SKIN:GetMeasure('measureNetTotalNonCum'):GetValue()
    local cumulativeDownloadCumulative = SKIN:GetMeasure('measureNetTotal'):GetValue()

    -- Update
    local fileOpen = io.open(filePath, 'r')
    local fileContent = fileOpen:read() or string.format("%.0f,%d", cumulativeDownloadCumulative, 0)
    -- print(fileContent)
    local current_number_num, dataMenit = fileContent:match("(%d+),(%d+)")
    fileOpen:close()

    current_cumulative = current_number_num + cumulativeDownload
    dataMenit_cumulative = dataMenit + cumulativeDownload

    -- Handling Send Usage Every 1 minute
    if (os.date("%S")) == "00" then
    -- if true then
        updateDailyData()
        sendUsage()
        dataMenit_cumulative = 0
    end

    local variable_to_write_to_file = string.format("%.0f,%d", current_cumulative, dataMenit_cumulative)
    local fileWrite = io.open(filePath, 'w+')
    fileWrite:write(variable_to_write_to_file)
    fileWrite:close()

    return current_cumulative
end

-- Fungsi Update Daily Data
function updateDailyData()
    -- Handling daily cumulative data with Hour intervals
    currentDate = os.date("%Y-%m-%d")
    currentTime = os.date("%H")
    local dailyFileOpen = io.open(dailyPath, 'r')
    local dailyFileContent = dailyFileOpen:read()    
    local dailyData = dailyFileContent and LoadJSON(dailyFileContent) or {}
    dailyFileOpen:close()
    
    dailyData[currentDate] = dailyData[currentDate] or {}
    dailyData[currentDate][currentTime] = dailyData[currentDate][currentTime] or 0
      
    local dailyFileWrite = io.open(dailyPath, 'w+')
    dailyData[currentDate][currentTime] = dailyData[currentDate][currentTime] + dataMenit_cumulative
    SaveJSON(dailyData, dailyFileWrite)
    dailyFileWrite:close()
    
    dailyDataTable = dailyData
        
    -- Handling rainmeter send Hourly data
    local hourlyUsageInKB = (dailyData[currentDate][currentTime])/(1024)
    local hourlyUsageInKBWithUnit = string.format("%d KB", hourlyUsageInKB)
    SKIN:Bang('!SetOption', 'meterTotalHourlyUsageValue', 'Text', hourlyUsageInKBWithUnit)
    backupData()
end

-- Fungsi bantu untuk mengurai data JSON-like
function LoadJSON(jsonContent)
    local data = {}
    for date, entries in jsonContent:gmatch('"(%d%d%d%d%-%d%d%-%d%d)":%s-{(.-)}') do
        data[date] = {}
        for time, value in entries:gmatch('"(%d%d)":%s-([%d%.]+),?') do
            data[date][time] = tonumber(value)
        end
    end
    return data
end

-- Fungsi bantu untuk menyimpan data JSON-like
function SaveJSON(data, file)
    file:write("{")
    for date, entries in pairs(data) do
        file:write(string.format('"%s": {', date))
        for time, value in pairs(entries) do
            file:write(string.format('"%s": %d,', time, value))
        end
        file:write("},")
    end
    file:write("}")
end

--  fungsi mengirim data ke rainmeter
function sendUsage()
    DailyUsage()
    MonthlyUsage()
end

-- Handling rainmeter send daily data
function DailyUsage()
    local dailyUsage = GetDailyUsage(currentDate)
    local dailyUsageInMB = dailyUsage/(1024 * 1024)
    local dailyUsageInMBWithUnit = string.format("%d MB", dailyUsageInMB)
    SKIN:Bang('!SetOption', 'meterTotalDailyUsageValue', 'Text', dailyUsageInMBWithUnit)
end

-- Get rainmeter send daily data
function GetDailyUsage(date)
    local totalUsage = 0
    if dailyDataTable[date] then
        for hour, value in pairs(dailyDataTable[date]) do
            totalUsage = totalUsage + value
        end
    end
    return totalUsage
end

-- Handling rainmeter send monthly data
function MonthlyUsage()
    local year = os.date("%Y")
    local month = os.date("%m")
    local MonthlyUsage = GetMonthlyUsage(year, month)
    local MonthlyUsageInMB = MonthlyUsage/(1024 * 1024)
    local MonthlyUsageInMBWithUnit = string.format("%d MB", MonthlyUsageInMB)
    SKIN:Bang('!SetOption', 'meterTotalMonthlyUsageValue', 'Text', MonthlyUsageInMBWithUnit)
end

-- Get rainmeter send monthly data
function GetMonthlyUsage(year, month)
    local totalUsage = 0
    for date, hourlyUsage in pairs(dailyDataTable) do
        local dateYear, dateMonth, _ = date:match("(%d%d%d%d)-(%d%d)-%d%d")
        if (dateYear) == year and (dateMonth) == month then
            for hour, value in pairs(hourlyUsage) do
                totalUsage = totalUsage + value
            end
        end
    end
    return totalUsage
end

function backupData()
    local filePath_backup_daily = CurrPath .. "/Data/DailyData_" .. currentDate .. ".json"
    local filePath_backup_cumulative = CurrPath .. "/Data/CumulativeData_" .. currentDate .. ".txt"
    local dailyFileOpen
    local cumulativeFileOpen
    local function fileExists(name)
        local f = io.open(name, "r")
        if f ~= nil then
            io.close(f)
            return true
        else
            return false
        end
    end

    if fileExists(filePath_backup_daily) then
        dailyFileOpen = io.open(filePath_backup_daily, 'w+')
        SaveJSON(dailyDataTable, dailyFileOpen)
    else
        dailyFileOpen,e = io.open(filePath_backup_daily, 'w+')
        assert(dailyFileOpen,e)
        dailyFileOpen:write('{}')
        SaveJSON(dailyDataTable, dailyFileOpen)
    end

    if fileExists(filePath_backup_cumulative) then
        cumulativeFileOpen = io.open(filePath_backup_cumulative, 'w+')
        cumulativeFileOpen:write(current_cumulative)
        cumulativeFileOpen:close()
        print(current_cumulative)
    else
        cumulativeFileOpen,e = io.open(filePath_backup_cumulative, 'w+')
        assert(cumulativeFileOpen,e)
        cumulativeFileOpen:write(current_cumulative)
        cumulativeFileOpen:close()
    end

end