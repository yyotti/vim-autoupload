scriptencoding utf-8
"=============================================================================
" FILE: autoupload.vim
" AUTHOR:  Y.Tsutsui
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

if exists('g:loaded_autoupload')
  let &cpo = s:save_cpo
  unlet s:save_cpo

  finish
endif

" TODO

let g:loaded_autoupload = 1

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set sw=2 foldmethod=marker:
