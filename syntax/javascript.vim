" Vim syntax file
" Language:	JavaScript
" Maintainer:	David Wilhelm <dewilhelm@gmail.com>
" Last Change:  2014 July 12

" The purpose of this syntax file is to prevent
" default javascript syntax from being loaded
" which is unnecessary in the context of this plugin

" The actual syntax definitions are done dynamically
" in the ftplugin/javascript.vim file.


if &filetype == 'javascript' && exists('g:js_context_colors_enabled') && g:js_context_colors_enabled

    setlocal iskeyword+=$

    call JSCC_Enable()

    "set syntax to javascript so another syntax for javascript isn't loaded
    let b:current_syntax="javascript"
endif

