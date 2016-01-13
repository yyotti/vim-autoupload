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

" TODO

let g:loaded_autoupload = 1

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
