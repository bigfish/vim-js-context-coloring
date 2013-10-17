"plugin to add javascript scope-coloring
"Author: David Wilhelm <dewilhelm@gmail.com>
"
"Note: highlights function scopes in JavaScript
"only supports terminal colors at this time	
"use XtermColorTable plugin to see what colors are available

"this acts as an overlay over the existing highlighting


let s:jscc = expand('<sfile>:p:h').'/../../bin/jscc-cli'

if !exists('g:js_context_colors')
	let g:js_context_colors = [ 252, 10, 11, 172, 1, 161, 63 ]
endif

if !exists('g:js_context_colors_enabled')
	let g:js_context_colors_enabled = 1
endif

if !exists('g:js_context_colors_usemaps')
	let g:js_context_colors_usemaps = 1
endif

"define highlight groups dynamically
function! JSCC_DefineHighlightGroups()
	let c = 0
	for colr in g:js_context_colors
		exe 'highlight JSCC_Level_' . c . '  ctermfg=' . colr . 'ctermbg=none cterm=none'
		let c += 1
	endfor
endfunction

function! JSCC_Colorize()

	let save_cursor = getpos(".")

	let colordata_result = system(s:jscc, join(getline(1, '$'), "\n"))
	call clearmatches()
	"colorize the lines based on the color data
	let colordata = eval(colordata_result)
	if type(colordata) == type([])
		for data in colordata
			call matchadd('JSCC_Level_' . data.level, '\%' . data.line . 'l\%>' . (data.from - 1) . 'c.*\%<' . data.thru . 'c' , data.level) 
		endfor
	else
		echom "unexpected output from jslint:"
		echom colordata_result
	endif

	call setpos('.', save_cursor)
endfunction

function! JSCC_Enable()
	augroup JSContextColorAug
		au!
		au! TextChangedI,TextChanged *.js :JSContextColor
	augroup END
	:JSContextColor
	"echo 'JSContextColor enabled'
endfunction

function! JSCC_Disable()
	call clearmatches()
	augroup JSContextColorAug
		au!
	augroup END
	"echo 'JSContextColor disabled'
endfunction

function! JSCC_Toggle()
	if g:js_context_colors_enabled
		let g:js_context_colors_enabled = 0
		call JSCC_Disable()
	else
		let g:js_context_colors_enabled = 1
		call JSCC_Enable()
	endif
endfunction

"define user commands
"command! -range=% -nargs=0 JSContextColor <line1>,<line2>:call JSCC_Colorize()
command! JSContextColor call JSCC_Colorize()

command! JSContextColorToggle call JSCC_Toggle()

command! JSContextColorUpdate call JSCC_DefineHighlightGroups()

"define highlight group and do colorizing once for buffer
:JSContextColorUpdate
call JSCC_Enable()
:JSContextColor

if g:js_context_colors_usemaps 
	if !hasmapto('<Plug>JSContextColor')
		"mnemonic (h)ighlight
		nnoremap <buffer> <silent> <localleader>h :JSContextColor<CR>
	endif

	if !hasmapto('<Plug>JSContextColorToggle')
		"mnemonic (t)oggle
		nnoremap <buffer> <silent> <localleader>t :JSContextColorToggle<CR>
	endif
endif

