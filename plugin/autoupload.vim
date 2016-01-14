scriptencoding utf-8
"=============================================================================
" FILE: autoupload.vim
" AUTHOR:  Y.Tsutsui
"=============================================================================

if exists('g:loaded_autoupload')
  finish
endif

let s:save_cpo = &cpo
set cpo&vim

"-----------------------------------------------------------------------------
" Mappings:
"

"-----------------------------------------------------------------------------
" Commands:
"
command! AutoScpUpload call s:autoscp_upload(1)
command! AutoScpToggle call autoupload#toggle()

let g:loaded_autoupload = 1

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
