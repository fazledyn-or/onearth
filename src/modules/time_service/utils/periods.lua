local function isLeapYear(year)
	return year % 4 == 0 and year % 100 ~= 0 or year % 400 == 0
end

local function getDaysInMonth(month, year)
	local daysRef = {31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31}
	return month == 2 and (daysRef[2] + (isLeapYear(year) and 1 or 0)) or daysRef[month]
end

local function getDaysInYear(year)
	local days = 0
	local month = 1
	while month <= 12 do
		days = days + getDaysInMonth(month, year)
		month = month + 1
	end
	return days
end

local function calcDayOfYear(dateStr)
	local year = tonumber(dateStr:sub(1, 4))
	local month = tonumber(dateStr:sub(6, 7))
	local day = tonumber(dateStr:sub(9, 10))

	local counter = 1
	while counter < month do
		day = day + getDaysInMonth(counter, year)
		counter = counter + 1
	end
	return day
end

local function dayOfYearToDate(doy, year)
	local month = 1
	local dayCounter = 1

	local counting = true
	while counting do
		local daysInMonth = getDaysInMonth(month, year)
		if dayCounter + daysInMonth > doy then
			counting = false
		else 
			dayCounter = dayCounter + daysInMonth
			month = month + 1
		end
	end

	local monthStr = tostring(month)
	if monthStr:len() < 2 then
		monthStr = "0" .. monthStr
	end

	local dayStr = tostring(doy - dayCounter + 1)
	if dayStr:len() < 2 then
		dayStr = "0" .. dayStr
	end

	return year .. "-" .. monthStr .. "-" .. dayStr
end

local function calcDayDelta(date1, date2)
	local dates = {}
	for i, dateStr in ipairs({date1, date2}) do
		local year = tonumber(dateStr:sub(1, 4))
		local month = tonumber(dateStr:sub(6, 7))
		local day = tonumber(dateStr:sub(9, 10))
		dates[i] = {year=year, month=month, day=day}
	end
	
	local doy1 = calcDayOfYear(date1)
	local doy2 = calcDayOfYear(date2)

	if dates[1]['year'] == dates[2]['year'] then
		return doy2 - doy1
	end

	local counter = getDaysInYear(dates[1]['year']) - doy1
	local yearCounter = dates[1]['year'] + 1
	while yearCounter < dates[2]['year'] do
		counter = counter + getDaysInYear(yearCounter)
		yearCounter = yearCounter + 1
	end

	return counter + doy2
end

local function dateToEpoch(dateStr)
	local year = tonumber(dateStr:sub(1, 4))
	local month = tonumber(dateStr:sub(6, 7))
	local day = tonumber(dateStr:sub(9, 10))
	local hour = tonumber(dateStr:sub(12, 13)) or 0
	local minute = tonumber(dateStr:sub(15, 16)) or 0
	local second = tonumber(dateStr:sub(18, 19)) or 0
	local doy = calcDayOfYear(dateStr)

	local yearSecCounter = 0
	local yearCounter = 1970
	while yearCounter < year do
		yearSecCounter = yearSecCounter + (isLeapYear(yearCounter) and 366 or 365) * 24 * 60 * 60
		yearCounter = yearCounter + 1
	end

	return yearSecCounter + ((doy - 1) * 86400) + (hour * 60 * 60)  + (minute * 60) + second
end

local function calcIntervalFromSeconds(interval)
	if interval % 86400 == 0 then
		return math.floor(interval / 86400), "day"
	elseif interval % 3600 == 0 then
		return math.floor(interval / 3600), "hour"
	elseif interval % 60 == 0 then
		return math.floor(interval / 60), "minute"
	else
		return math.floor(interval), "second"
	end
end

local function padToLength(str, char, len, pos)
	while str:len() < len do
		if pos == "tail" then
			str = str .. char
		else
			str = char .. str
		end
	end
	return str
end

local function calcSecondsInYear(year)
	local days = isLeapYear(year) and 366 or 365
	return days * 24 * 60 * 60
end

local function epochToDate(epoch) 
	local year = 1970
	local secCounter = epoch

	-- Get the year
	local loop = true
	repeat
		local secondsInYear = calcSecondsInYear(year)	
		if secCounter >= secondsInYear then
			secCounter = secCounter - secondsInYear
			year = year + 1			
		else
			loop = false
		end
	until not loop

	-- Get the date
	local doy = math.floor(secCounter / 86400) + 1
	local date = dayOfYearToDate(doy, year)
	secCounter = secCounter - ((doy - 1) * 86400)

	-- Get the time
	local hours = tostring(math.floor(secCounter / 3600))
	hours = padToLength(hours, "0", 2)
	secCounter = secCounter - hours * 3600

	local minutes = tostring(math.floor(secCounter / 60))
	minutes = padToLength(minutes, "0", 2)
	secCounter = secCounter - minutes * 60

	local seconds = padToLength(tostring(math.floor(secCounter)), "0", 2)

	return date .. "T" .. hours .. ":" .. minutes .. ":" .. seconds
end

local function addDaysToDate(date, days)
	local doy = calcDayOfYear(date)
	local year = tonumber(date:sub(1, 4))
	local daysInYear = getDaysInYear(year)
	if doy + days <= daysInYear then
		return dayOfYearToDate(doy + days, year)
	end
end

local function dateAtInterval(baseDate, interval, dateList, unit)
	if unit == "year" then
		local baseYear = baseDate:sub(1 ,4)
		for i, date in ipairs(dateList) do
			local year = tonumber(date:sub(1, 4))
			if year == baseYear + interval then
				return date
			end
		end
	elseif unit == "day" then
		local nextDate = addDaysToDate(baseDate, interval)
		for i, date in ipairs(dateList) do
			if date == nextDate then
				return date
			end
		end
	end
	return false
end

local function dateAtFixedInterval(baseEpoch, intervalInSec, dateList)
	for i, date in ipairs(dateList) do
		local epoch = dateToEpoch(date)
		if epoch - baseEpoch == intervalInSec then
			return epoch
		end
	end
	return false
end

local function itemInList(item, list) 
	for i, v in ipairs(list) do
		if v == item then
			return true
		end
	end
	return false
end


local function listContainsList(long, short) 
	for i, v in ipairs(short) do
		if not itemInList(v, long) then
			return false
		end
	end
	return true
end

local function listEqualsList(list1, list2)
	if #list1 ~= #list2 then
		return false
	end
	for i, v in ipairs(list1) do
		if not itemInList(v, list2) then
			return false
		end
	end
	return true
end

local function getIntervalLetter(unit)
	if unit == "year" then
		return "Y"
	elseif unit == "month" then
		return "M"
	elseif unit == "day" then
		return "D"
	elseif unit == "hour" then
		return "H"
	elseif unit == "minute" then
		return "MM"
	elseif unit == "second" then
		return "S"
	end
end

local function isValidPeriod(size, unit)
	if unit == "day" and size >= 365 then
		return false
	end
	return true
end


local function calculatePeriods(dates)
	local periods = {}

	-- Check for year matches
	for i, date in ipairs(dates) do
		local tail = date:sub(5)

		local baseYear = tonumber(date:sub(1, 4))
		
		local possibleMatches = {}
		for i, d in ipairs(dates) do
			if d ~= date and d:sub(5) == tail and tonumber(d:sub(1, 4)) > baseYear then
				possibleMatches[#possibleMatches + 1] = d
			end
		end
		
		for i, possibleMatch in ipairs(possibleMatches) do
			local year = tonumber(possibleMatch:sub(1, 4))
			local interval = year - baseYear
			
			local nextInterval = dateAtInterval(possibleMatch, interval, possibleMatches, "year")
			if nextInterval then
				local dateList = {date, possibleMatch}
				
				-- At least one match, find the end
				while nextInterval do
					dateList[#dateList + 1] = nextInterval
					nextInterval = dateAtInterval(nextInterval, interval, possibleMatches, "year")
				end

				periods[#periods + 1] = {size=interval, dates=dateList, unit="year"}
			end
		end
	end

	-- Check for time period matches
	for i, date in ipairs(dates) do
		for idx, d in ipairs(dates) do
			if i ~= idx then
				local dateEpoch1 = dateToEpoch(date)
				local dateEpoch2 = dateToEpoch(d)
				if dateEpoch1 < dateEpoch2 then
					local intervalInSec = dateEpoch2 - dateEpoch1
					local nextInterval = dateAtFixedInterval(dateEpoch2, intervalInSec, dates)
					if nextInterval then
						local epochDateList = {dateEpoch1, dateEpoch2}
						while nextInterval do
							epochDateList[#epochDateList + 1] = nextInterval
							nextInterval = dateAtFixedInterval(nextInterval, intervalInSec, dates)
						end		
						
						local dateList = {}
						for i, epoch in ipairs(epochDateList) do
							dateList[#dateList + 1] = epochToDate(epoch)
						end

						local size, unit = calcIntervalFromSeconds(intervalInSec)
						if isValidPeriod(size, unit) then
							periods[#periods + 1] = {size=size, dates=dateList, unit=unit}
						end
					end
				end
			end
		end
	end

	-- Remove duplicates and periods that are contained by other periods
	local deduped = {}
	local dupeIndexes = {}
	for i, period in ipairs(periods) do
		if not itemInList(i, dupeIndexes) then
			for idx, p in ipairs(periods) do
				if i ~= idx and not itemInList(idx, dupeIndexes) then
					if listEqualsList(period["dates"], p["dates"]) then
						dupeIndexes[#dupeIndexes + 1] = idx
					end
				end
			end
			deduped[#deduped + 1] = period
		end
	end

	local reducedPeriods = {}
	local redundantIndexes = {}
	for i, period in ipairs(deduped) do
		if not itemInList(i, redundantIndexes) then
			for idx, p in ipairs(deduped) do
				if i ~= idx and not itemInList(idx, redundantIndexes) and #period["dates"] > #p["dates"] then
					if listContainsList(period["dates"], p["dates"]) then
						redundantIndexes[#redundantIndexes + 1] = idx
					end
				end
			end
			reducedPeriods[#reducedPeriods + 1] = period
		end
	end


	-- Any dates that didn't end up in any period are loner dates
	local function dateInPeriods(date, periods) 
		for i, period in ipairs(periods) do
			if itemInList(date, period["dates"]) then
				return true
			end
		end
		return false
	end

	for i, date in ipairs(dates) do
		if not dateInPeriods(date, reducedPeriods) then
			reducedPeriods[#reducedPeriods + 1] = {dates={date}}
		end
	end

	-- Create formatted list
	local periodStrings = {}
	for _, period in pairs(reducedPeriods) do
		local periodStr
		if #period["dates"] > 1 then
			periodStr =  period["dates"][1] .. "/" .. period["dates"][#period["dates"]] .. "/P" .. period["size"] .. getIntervalLetter(period["unit"])
		else
			periodStr = period["dates"][1]
		end
		periodStrings[#periodStrings + 1] = periodStr
	end

	return periodStrings
end

-- REDIS SYNTAX == EVAL {script} layer_prefix:layer_name
-- Routine called by Redis. Read all dates, create periods, and replace old period entries
-- with new list.
local dates = redis.call("SMEMBERS", KEYS[1] .. ":dates")
local periodStrings = calculatePeriods(dates)
for i, periodString in ipairs(periodStrings) do
	if redis.call("EXISTS", KEYS[1] .. ":periods") then
		redis.call("DEL", KEYS[1] .. ":periods")
	end
	redis.call("SADD", KEYS[1] .. ":periods", periodString)
end
