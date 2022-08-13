##../nabla
@declare_functions+=
local enable_virt

@functions+=
function enable_virt()
  local buf = vim.api.nvim_get_current_buf()
  @read_whole_buffer
  @foreach_line_generate_drawings
  @place_drawings_above_lines
  @enable_conceal_for_formulas
end

@export_symbols+=
enable_virt = enable_virt,

@foreach_line_generate_drawings+=
local annotations = {}

for _, str in ipairs(lines) do
  @detect_formulas_in_line
  @foreach_formulas_generate_drawing
end

@detect_formulas_in_line+=
local formulas = {}

local rem = str
local acc = 0
while true do
  local p1 = rem:find("%$")
  if not p1 then break end

  rem = rem:sub(p1+1)

  local p2 = rem:find("%$")
  if not p2 then break end

  rem = rem:sub(p2+1)
  table.insert(formulas, {p1+acc+1, p2+p1+acc-1})

  acc = acc + p1 + p2
end

@foreach_formulas_generate_drawing+=
local line_annotations = {}

for _, form in ipairs(formulas) do
  local p1, p2 = unpack(form)
  local line = str:sub(p1, p2)

  @parse_math_expression

  if success and exp then
    @generate_ascii_art
    @convert_drawing_to_virt_lines
    @colorize_drawing
    table.insert(line_annotations, { p1, p2, drawing_virt })
  else
    print(exp)
  end
end

table.insert(annotations, line_annotations)

@script_variables+=
local mult_virt_ns

@place_drawings_above_lines+=
if mult_virt_ns then
  vim.api.nvim_buf_clear_namespace(buf, mult_virt_ns, 0, -1)
end

mult_virt_ns = vim.api.nvim_create_namespace("")

for i, line_annotations in ipairs(annotations) do
  if #line_annotations > 0 then
    @compute_min_number_of_lines
    @fill_lines_progressively_with_drawings
    @create_virtual_line_annotation_above
  end
end

@compute_min_number_of_lines+=
local num_lines = 0
for _, annotation in ipairs(line_annotations) do
  local _, _, drawing_virt = unpack(annotation)
  num_lines = math.max(num_lines, #drawing_virt)
end

local virt_lines = {}
for i=1,num_lines do
  table.insert(virt_lines, {})
end

@fill_lines_progressively_with_drawings+=
for ai, annotation in ipairs(line_annotations) do
  local p1, p2, drawing_virt = unpack(annotation)

  @compute_col_to_place_drawing
  @fill_lines_to_go_to_col
  @fill_drawing
end

@compute_col_to_place_drawing+=
local desired_col = (p1-1) - math.floor(#drawing_virt[1]/2) -- substract because of conceals

@fill_lines_to_go_to_col+=
local col = #virt_lines[1]
if desired_col-col > 0 then
  local fill = {{(" "):rep(desired_col-col), "Normal"}}
  for j=1,num_lines do
    vim.list_extend(virt_lines[j], fill)
  end
end

@fill_drawing+=
local off = num_lines - #drawing_virt
for j=1,#drawing_virt do
  vim.list_extend(virt_lines[j+off], drawing_virt[j])
end

@create_virtual_line_annotation_above+=
vim.api.nvim_buf_set_extmark(buf, mult_virt_ns, i-1, 0, {
  virt_lines = virt_lines,
  virt_lines_above = i > 1,
})

@declare_functions+=
local disable_virt

@functions+=
function disable_virt()
  local buf = vim.api.nvim_get_current_buf()
  if mult_virt_ns then
    vim.api.nvim_buf_clear_namespace(buf, mult_virt_ns, 0, -1)
    mult_virt_ns = nil
  end

  @disable_conceal_for_formulas
end

@export_symbols+=
disable_virt = disable_virt,

@convert_drawing_to_virt_lines+=
local drawing_virt = {}

for j=1,#drawing do
  local len = vim.str_utfindex(drawing[j])
  local new_virt_line = {}
  for i=1,len do
    local a = vim.str_byteindex(drawing[j], i-1)
    local b = vim.str_byteindex(drawing[j], i)

    local c = drawing[j]:sub(a+1, b)
    table.insert(new_virt_line, { c, "Normal" })
  end

  table.insert(drawing_virt, new_virt_line)
end

@colorize_drawing+=
colorize_virt(g, drawing_virt, 0, 0, 0)

@script_variables+=
local conceal_defined = false

@enable_conceal_for_formulas+=
vim.api.nvim_command([[syn match NablaFormula /\$[^$]\{-1,}\$/ conceal cchar=⮥]])
-- vim.api.nvim_command([[syn match NablaDelimiter /\$/ contained conceal]])
vim.api.nvim_command([[setlocal conceallevel=2]])
-- vim.api.nvim_command([[setlocal concealcursor=nc]])
conceal_defined = true

@disable_conceal_for_formulas+=
if conceal_defined then
  vim.api.nvim_command([[syn clear NablaFormula]])
  -- vim.api.nvim_command([[syn clear NablaDelimiter]])
  conceal_defined = false
end


