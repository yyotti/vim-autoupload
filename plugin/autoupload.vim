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
nnoremap <silent> <Plug>(autoupload-toggle)
      \ :<C-u>call autoupload#toggle_auto()<CR>

"-----------------------------------------------------------------------------
" Commands:
"
command! AutouploadUpload call autoupload#upload(1)
command! AutouploadToggle call autoupload#toggle_auto()

let g:loaded_autoupload = 1

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
