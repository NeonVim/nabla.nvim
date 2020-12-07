-- Generated from parser.lua.tl using ntangle.nvim
local parse_all

local tokenize

local nextToken

local finish

local getToken

local parse

local AddExpression

local PrefixSubExpression

local SubExpression

local MulExpression

local DivExpression

local NumExpression

local SymExpression

local FunExpression

local parse_assert 

local ExpExpression

local putParen

tokens = {}

local errmsg = ""

local token_index

local priority_list = {
	["add"] = 50,
	
	["sub"] = 50,
	
	["mul"] = 60,
	
	["div"] = 70,
	
	["lpar"] = 100,
	
	["rpar"] = 10,
	
	["exp"] = 70,
	
	["rbra"] = 5,
	["comma"] = 5,
	["semi"] = 5,
	
	["mat"] = 110,
	
	["eq"] = 1,
	
	["presub"] = 90,
	["exp"] = 90,
	["sym"] = 110,
	["num"] = 110,
	["fun"] = 100,
	
}

function AddExpression(left, right) 
	local self = { kind = "addexp", left = left, right = right }
	function self.toString() 
		if self.right.kind == "presubexp" then
			return putParen(self.left, self.priority()) .. "-" .. putParen(self.right.left, self.right.priority())
		elseif self.right.kind == "numexp" and self.right.num < 0 then
			return putParen(self.left, self.priority()) .. "-" .. putParen(NumExpression(math.abs(self.right.num)), self.priority())
		else
			assert(self.priority, vim.inspect(self))
			return putParen(self.left, self.priority()) .. "+" .. putParen(self.right, self.priority())
		end
	end
	function self.priority() 
		return priority_list["add"]
	end
	function self.getLeft() 
		return self.left.getLeft()
	end
return self end

function PrefixSubExpression(left) 
	local self = { kind = "presubexp", left = left }
	function self.toString() 
		return "-" .. putParen(self.left, self.priority()) .. ""
	end
	function self.priority() 
		return priority_list["presub"]
	end
	function self.getLeft() 
		return self
	end
return self end

function SubExpression(left, right)
	local self = { kind = "subexp", left = left, right = right }
	function self.toString() 
		return putParen(self.left, self.priority()) .. "-" .. putParen(self.right, self.priority())
	end
	function self.priority() 
		return priority_list["sub"]
	end
	function self.getLeft() 
		return self.left.getLeft()
	end
return self end

function MulExpression(left, right)
	local self = { kind = "mulexp", left = left, right = right }
	function self.toString() 
		if self.left.kind == "numexp" and self.right.getLeft().kind ~= "numexp" then
			return putParen(self.left, self.priority()) .. putParen(self.right, self.priority())
		else 
			return putParen(self.left, self.priority()) .. "*" .. putParen(self.right, self.priority())
		end
	end
	function self.priority() 
		return priority_list["mul"]
	end
	function self.getLeft() 
		return self.left.getLeft()
	end
return self end

function DivExpression(left, right)
	local self = { kind = "divexp", left = left, right = right }
	function self.toString() 
		return putParen(self.left, self.priority()) .. "/" .. putParen(self.right, self.priority())
	end
	function self.priority() 
		return priority_list["div"]
	end
	function self.getLeft() 
		return self.left.getLeft()
	end
return self end


function NumExpression(num)
	local self = { kind = "numexp", num = num }
	function self.toString() 
		return tostring(self.num)
	end
	function self.priority() 
		return priority_list["num"]
	end
	function self.getLeft() 
		return self
	end
return self end

function SymExpression(sym)
	local self = { kind = "symexp", sym = sym }
	function self.toString() 
		return self.sym
	end
	function self.priority() 
		return priority_list["sym"]
	end
	function self.getLeft() 
		return self
	end
return self end

function FunExpression(name, args)
	local self = { kind = "funexp", name = name, args = args }
	function self.toString() 
		local fargs = {}
		for _,arg in ipairs(self.args) do
			table.insert(fargs, arg.toString())
		end
		return self.name .. "(" .. table.concat(fargs, ", ") .. ")"
	end
	
	function self.priority() 
		return priority_list["fun"]
	end
	function self.getLeft() 
		return self
	end
return self end

function ExpExpression(left, right)
	local self = { kind = "expexp", left = left, right = right }
	function self.toString() 
		return putParen(self.left, self.priority()) .. "^" .. putParen(self.right, self.priority())
	end
	function self.priority() 
		return priority_list["exp"]
	end
	function self.getLeft() 
		return self.left.getLeft()
	end
return self end

function MatrixExpression(rows, m, n)
	local self = { kind = "matexp", rows = rows, m = m, n = n }
	function self.priority() 
		return priority_list["mat"]
	end
	function self.toString()
		local rowsString = {}
		for _,row in ipairs(self.rows) do
			local cells = {}
			for _,cell in ipairs(row) do
				table.insert(cells, cell.toString())
			end
			local cellsString = table.concat(cells, ",")
			table.insert(rowsString, cellsString)
		end
		return "[" .. table.concat(rowsString, ";") .. "]"
	end
	
	function self.getLeft() 
		return self
	end
return self end

function EqualExpression(left, right) 
	local self = { kind = "eqexp", left = left, right = right }
	function self.toString()
		local t1 = self.left.toString()
		local t2 = self.right.toString()
		return t1 .. " = " .. t2
	end
	
return self end

-- closure-based object
local function AddToken() local self = { kind = "add" }
	function self.prefix()
		return parse(self.priority())
	end
	
	function self.infix(left)
		local t = parse(self.priority())
		if not t then
			return nil
		end
		return AddExpression(left, t)
	end
	function self.priority() return priority_list["add"] end
	
return self end
local function SubToken() local self = { kind = "sub" }
	function self.prefix()
		local t = parse(90)
		if not t then
			return nil
		end
		return PrefixSubExpression(t)
	end
	
	function self.infix(left)
		local t = parse(self.priority()+1)
		if not t then
			return nil
		end
		-- return SubExpression(left, t)
		if t.kind == "numexp" then
			return AddExpression(left, NumExpression(-t.num))
		else
			return AddExpression(left, PrefixSubExpression(t))
		end
	end
	function self.priority() return priority_list["sub"] end
	
return self end
local function MulToken() local self = { kind = "mul" }
	function self.infix(left)
		local t = parse(self.priority())
		if not t then
			return nil
		end
		return MulExpression(left, t)
	end
	function self.priority() return priority_list["mul"] end
	
return self end
local function DivToken() local self = { kind = "div" }
	function self.infix(left)
		local t = parse(self.priority()+1)
		if not t then
			return nil
		end
		return DivExpression(left, t)
	end
	function self.priority() return priority_list["div"] end
	
return self end

local function RParToken() local self = { kind = "rpar" }
	function self.priority() return priority_list["rpar"] end
	
return self end
local function LParToken() local self = { kind = "lpar" }
	function self.prefix()
		local exp = parse(20)
		if not exp then
			return nil
		end
		local rpar = nextToken()
		if not rpar or rpar.kind ~= "rpar" then 
			errmsg = "Unmatched '('"
			return nil
		end
		
		return exp
	end
	
	function self.priority() return priority_list["lpar"] end
	
	function self.infix(left)
		local args = {}
		while not finish() do
			local exp = parse(20)
			if not exp then
				return nil
			end
			table.insert(args, exp)
			local t = nextToken()
			if t.kind == "rpar" then
				break
			end
			
			if parse_assert(t.kind == "comma", "expected comma in function arg list") then
				return nil
			end
			
		end
		local name = left.sym
		return FunExpression(name, args)
	end
	
return self end

local function NumToken(num) local self = { kind = "num", num = num }
	function self.prefix()
		return NumExpression(self.num)
	end
	
return self end

local function SymToken(sym) local self = { kind = "sym", sym = sym }
	function self.prefix()
		return SymExpression(self.sym)
	end
	
return self end

local function ExpToken() local self = { kind = "exp" }
	function self.infix(left)
		local exp = parse(self.priority())
		if not exp then
			return nil
		end
		return ExpExpression(left, exp)
	end
	function self.priority() return priority_list["exp"] end
	
return self end

-- right bracket
local function LBraToken() local self = { kind = "lbra" }
	function self.prefix()
		local i, j = 1, 1
		rows = {}
		rows[1] = {}
		while true do
			local exp = parse(10)
			if not exp then
				return nil
			end
	
			rows[i][j] = exp
	
			local t = nextToken()
			if t.kind == "rbra" then
				break
			end
			
			if t.kind == "comma" then
				j = j+1
			end
			
			if t.kind == "semi" then
				rows[#rows+1] = {}
				i = i+1
				j = 1
			end
			
		end
		local curlen
		for _,row in ipairs(rows) do
			if not curlen then
				curlen = #row
			end
		
			if parse_assert(#row == curlen, "matrix dimension incorrect") then
				return nil
			end
		end
		
		local exp = MatrixExpression(rows, #rows, curlen)
		
		return exp
	end
	
return self end
-- left bracket
local function RBraToken() local self = { kind = "rbra" }
	function self.priority() return priority_list["rbra"] end
return self end
-- comma
local function CommaToken() local self = { kind = "comma" }
	function self.priority() return priority_list["comma"] end
return self end
-- semi-colon
local function SemiToken() local self = { kind = "semi" }
	function self.priority() return priority_list["semi"] end
return self end

-- right bracket
local function EqualToken() local self = { kind = "equal" }
	function self.infix(left)
		local t = parse(self.priority())
		if not t then
			return nil
		end
		return EqualExpression(left, t)
	end
	function self.priority() return priority_list["eq"] end
	
return self end


function tokenize(str)
	tokens = {}
	
	local i = 1
	while i <= string.len(str) do
		local c = string.sub(str, i, i)
		
		if string.match(c, "%s") then
			i = i+1 
		
		elseif c == "+" then table.insert(tokens, AddToken()) i = i+1
		elseif c == "-" then table.insert(tokens, SubToken()) i = i+1
		elseif c == "*" then table.insert(tokens, MulToken()) i = i+1
		elseif c == "/" then table.insert(tokens, DivToken()) i = i+1
		
		
		elseif c == "^" then table.insert(tokens, ExpToken()) i = i+1
		
		elseif c == "(" then table.insert(tokens, LParToken()) i = i+1
		elseif c == ")" then table.insert(tokens, RParToken()) i = i+1
			
		elseif c == "[" then table.insert(tokens, LBraToken()) i = i+1
		elseif c == "]" then table.insert(tokens, RBraToken()) i = i+1
		elseif c == "=" then table.insert(tokens, EqualToken()) i = i+1
		
		elseif c == "," then table.insert(tokens, CommaToken()) i = i+1
		elseif c == ";" then table.insert(tokens, SemiToken()) i = i+1
		
		elseif string.match(c, "%d") then 
			local parsed = string.match(string.sub(str, i), "%d+%.?%d*")
			i = i+string.len(parsed)
			table.insert(tokens, NumToken(tonumber(parsed))) 
		
		elseif string.match(c, "[%a_]") then
			if #tokens > 0 and tokens[#tokens].kind == "num" then
				table.insert(tokens, MulToken())
			end
			
			local parsed = string.match(string.sub(str, i), "[%w_]+")
			i = i+string.len(parsed)
			
		
		else
			errmsg = "Unexpected character insert " .. c
			i = i+1
		end
		
	end
	
end

function nextToken()
	local token = tokens[token_index]
	token_index = token_index + 1
	return token
end

function finish()
	return token_index > #tokens
end

function getToken()
	return tokens[token_index]
end

function parse(p)
	local t = nextToken()
	if not t or not t.prefix then
		return nil
	end

	local exp = t.prefix()

	while exp and not finish() and p <= getToken().priority() do
		t = nextToken()
		exp = t.infix(exp)
	end
	return exp
end

function parse_assert(c, msg)
	if not c then
		errmsg = msg
		return true
	end
	return false
end

function putParen(exp, p)
	if exp.priority() < p then
		return "(" .. exp.toString() .. ")"
	else
		return exp.toString()
	end
end


function parse_all(str)
	tokenize(str)
	errmsg = nil
	
	token_index = 1
	
	local exp = parse(0)
	
	if errmsg then
		return nil, errmsg
	end
	
	return exp
end


return {
parse_all = parse_all,

}
