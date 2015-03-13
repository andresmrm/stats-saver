#!/usr/bin/lua

---------------------------------------------------
-- GENERAL
---------------------------------------------------

QUOTA1 = 225
QUOTA2 = 150


-- Add possible interfaces that you want to record here. By order of priority.
possible_interfaces = {
  "br-lan",
  "wlp3s0"
}


-- Returns used filepaths
function get_filepaths(base_folder, kind)
  base_folder = base_folder or get_current_folder()
	local last_filepath = base_folder..kind.."_last"
  local save_filepath = base_folder..kind.."_total"
  local tmp_filepath = base_folder..kind.."_tmp"
  local mark_filepath = base_folder..kind.."_mark"
  return last_filepath, save_filepath, tmp_filepath, mark_filepath
end


-- Get date and byte values from file, if no file, return nil
function get_date_bytes(filepath)
	  local f = io.open(filepath, "r")
    if f then
        local line = f:read("*line")
        io.close(f)
        local split = split_str(line)
        return split[1], split[2]
    end
end


-- Get path to the folder where this script is
function get_current_folder()
    local str = debug.getinfo(2, "S").source:sub(2)
    return str:match("(.*/)") or "./"
end


function get_current_date()
    return os.date("%y/%m/%d-%H:%M:%S")
end


-- Get the total current value
function get_current_total(kind, base_folder)
	last_filepath, save_filepath = get_filepaths(base_folder, kind)

  _, last_bytes = get_date_bytes(last_filepath)
  last_bytes = last_bytes or 0
  _, save_bytes = get_date_bytes(save_filepath)
  save_bytes = save_bytes or 0

	return last_bytes + save_bytes
end



---------------------------------------------------
-- RECORD
---------------------------------------------------

-- Split a string
function split_str(inputstr, sep)
  -- Defaults to space
  sep = sep or "%s"
	local t={} ; i=1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
		t[i] = str
		i = i + 1
	end
	return t
end


-- Lists files in directory.
function scandir(directory)
    local i, t, popen = 0, {}, io.popen
    for filename in popen('ls -a "'..directory..'"'):lines() do
        i = i + 1
        t[i] = filename
    end
    return t
end


-- Finds correct interface to record.
function find_interface()
    files = scandir("/sys/class/net/")
    for i, file in pairs(files) do
    for j, possible in pairs(possible_interfaces) do
            if file == possible then
                interface = file
                -- print("Recording interface: ", interface)
                break
            end
        end
        if interface then break end
    end
    return interface
end


-- Update saved values for a given "kind" (rx or tx)
function process_bytes(system_folder, kind, base_folder)
	system_filepath = system_folder..kind.."_bytes"
	last_filepath, save_filepath, tmp_filepath = get_filepaths(base_folder, kind)
  current_date = get_current_date()

  -- Restore a possible tmp file (maybe from a previous crash)
	local f = io.open(tmp_filepath, "r")
  if f then
    io.close()
    os.rename(tmp_filepath, save_filepath)
    print("A tmp file ("..tmp_filepath..") was found! Restored.")
  end

  -- Get current system bytes
	io.input(system_filepath)
	system_bytes = io.read("*line")

  -- Try to get previous system bytes value
  last_date, last_bytes = get_date_bytes(last_filepath)
	if last_date then
    -- If system bytes decreased (probably system reboot)
		if tonumber(system_bytes) < tonumber(last_bytes) then
			f = io.open(save_filepath, 'r')
      save_date, save_bytes = get_date_bytes(save_filepath)
      if save_date == nil then
        -- There is no save bytes, add last bytes to saved bytes
        f = io.open(save_filepath, 'w')
        f:write(current_date..' '..last_bytes)
        io.close(f)
      elseif save_date <= last_date then
        -- There is an older save bytes, backup saved file,
        -- save sum bytes, remove backup
        os.rename(save_filepath, tmp_filepath)
        save_bytes = tonumber(last_bytes) + tonumber(save_bytes)
        io.output(save_filepath)
        io.write(current_date..' '..save_bytes)
        io.flush()
        os.remove(tmp_filepath)
      elseif save_date > last_date then
        -- The previous value date is the same than the last
        -- saved one. Maybe a crash in the middle of this function
        print("Rare situation! Last bytes already saved?")
        print("Maybe a double reboot?")
        print(save_date, last_date)
      end
		end
	end

  -- Save current system bytes
	io.output(last_filepath)
	io.write(current_date..' '..system_bytes)
end


-- Save values for an interface
function record_interface(interface)
    interface = interface or find_interface()
    if interface then
        system_folder = "/sys/class/net/"..interface.."/statistics/"
        process_bytes(system_folder, "rx")
        process_bytes(system_folder, "tx")
    else
        print("Error: no interface found!")
    end
end


-- Mark the current total value for a kind
function mark(kind)
	_, _, _, mark_filepath = get_filepaths(base_folder, kind)
	f = io.open(mark_filepath, 'a')
  f:write(get_current_date()..' '..get_current_total(kind)..'\n')
  io.close(f)
end


-- Mark the current total values
function mark_all()
  mark("rx")
  mark("tx")
end


---------------------------------------------------
-- REPORT
---------------------------------------------------

-- Rounds a number
function round(num, idp)
	return string.format("%." .. (idp or 0) .. "f", num)
end


-- Returns last line of file
function read_last_line(filepath)
    local prev_line = nil
    f = io.open(filepath, 'r')
    if f then
        for line in f:lines() do
            if line == nil then break end
            prev_line = line
        end
        io.close(f)
        return prev_line
   end
end


-- Calcule the Gb since last mark
function calculate_from_last_mark(kind, base_folder)
	_, _, _, mark_filepath = get_filepaths(base_folder, kind)
  local mark_value = 0
  local date = '---'
  local line = read_last_line(mark_filepath)
  if line then
     split = split_str(line)
     date = split[1]
     mark_value = split[2]
  end
  return (get_current_total(kind) - mark_value) / 1024^3, date
end


function display(label, abs, desc)
  -- Promissed quota
	perc = abs/QUOTA1*100
  -- Applyed quota
	perc2 = abs/QUOTA2*100
	-- print(label..round(abs, 6)..' GB   '..round(perc, 1)..'%   '..desc)
  print(label..round(abs, 6)..' GB\t   '..round(perc, 1)..'%     '..round(perc2, 1)..'%       '..desc)
end


function report()
    io.stdout:write("Content-Type: text/plain\r\n\r\n")
    rx, date = calculate_from_last_mark("rx")
    io.stdout:write("Sum from: "..date..'\n\n')
    display('RX:    ', rx, '(upload)')
    tx = calculate_from_last_mark("tx")
    display('TX:    ', tx, '(dowload)')
    total = rx + tx
    display('Total: ', total, '')
end



---------------------------------------------------
-- MAIN
---------------------------------------------------

-- Process input args
function process_args(args)
  if arg[1] == nil or arg[1] == "report" then
    report()
  elseif arg[1] == "save" then
    record_interface()
  elseif arg[1] == "mark" then
    mark_all()
  else
    print("Error: parameter not recognized!")
  end
end

process_args(arg)
