
; ==============================================================
; --------------------------------------------------------------
; Mega PCM 2.0
; --------------------------------------------------------------
; Trace data output module
;
; (c) 2023-2024, Vladikcomper
; --------------------------------------------------------------

; --------------------------------------------------------------
; Initialize trace data
; --------------------------------------------------------------

	lua
		trace_msg_table = {}
		trace_exception_table = {}

		-- Converts raw string literal expression (e.g. '"Hello"') to a Lua string (e.g. 'Hello')
		function asStringLiteral(expr)
			if not expr or expr == "" then
				return nil
			end

			if expr:sub(1, 1) == '"' and expr:sub(-1) == '"' then
				return expr:sub(2, -2)
			else
				return nil
			end
		end

		function saveTraceData(path, msg_table, exception_table)
			if not path or path == "" then
				return
			end

			local fp
			fp = assert(io.open(path, 'wb'))
			
			-- Trace messages section
			fp:write('[TraceMsg]\n')
			for offset, message in pairs(msg_table) do
				fp:write(offset .. ': "' .. message:gsub('"', '\\"') .. '"\n')
			end

			-- Trace exceptions section
			fp:write('[TraceException]\n')
			for offset, message in pairs(exception_table) do
				fp:write(offset .. ': "' .. message:gsub('"', '\\"') .. '"\n')
			end

			assert(fp:flush())
			assert(fp:close())
		end
	endlua

; --------------------------------------------------------------
; Prints an info message in Z80VM at current address
; --------------------------------------------------------------

	macro	TraceMsg msg
	lua
		trace_msg_table[sj.current_address] = asStringLiteral(sj.get_define("msg", true))
	endlua
	endm

; --------------------------------------------------------------
; Throws an error message in Z80VM at current address
; --------------------------------------------------------------

	macro	TraceException	msg
	lua
		trace_exception_table[sj.current_address] = asStringLiteral(sj.get_define("msg", true))
	endlua
	endm

; --------------------------------------------------------------
; Dumps current trace data
; --------------------------------------------------------------

	macro	TraceDataSave path
	lua
		saveTraceData(
			asStringLiteral(sj.get_define("path", true)),
			trace_msg_table,
			trace_exception_table
		)
	endlua
	endm
