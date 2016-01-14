scriptencoding utf-8
"=============================================================================
" FILE: autoupload/util.vim
" AUTHOR:  Y.Tsutsui
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

"-----------------------------------------------------------------------------
" Vital:
"
function! autoupload#util#get_vital() abort "{{{
  if !exists('s:V')
    let s:V = vital#of('autoupload')
  endif

  return s:V
endfunction "}}}

function! s:vital_prelude() abort "{{{
  if !exists('s:Prelude')
    let s:Prelude = autoupload#util#get_vital().import('Prelude')
  endif

  return s:Prelude
endfunction "}}}

function! s:vital_filepath() abort "{{{
  if !exists('s:Filepath')
    let s:Filepath = autoupload#util#get_vital().import('System.Filepath')
  endif

  return s:Filepath
endfunction "}}}

function! s:vital_process() abort "{{{
  if !exists('s:Process')
    let s:Process = autoupload#util#get_vital().import('Process')
  endif

  return s:Process
endfunction "}}}

function! s:vital_json() abort "{{{
  if !exists('s:Json')
    let s:Json = autoupload#util#get_vital().import('Web.JSON')
  endif

  return s:Json
endfunction "}}}

"-----------------------------------------------------------------------------
" Functions:
"
function! autoupload#util#remove_last_separator(...) abort "{{{
  return call(s:vital_filepath().remove_last_separator, a:000)
endfunction "}}}

function! s:separator() abort "{{{
  return call(s:vital_filepath().separator, [])
endfunction "}}}

function! autoupload#util#add_last_separator(path) abort "{{{
  return autoupload#util#remove_last_separator(a:path) .
        \ s:separator()
endfunction "}}}

function! autoupload#util#relative_path(path, base) abort "{{{
  let p = expand(a:path)
  let b = autoupload#util#add_last_separator(expand(a:base))

  return stridx(p, b) == 0 ? p[strlen(b):] : p
endfunction "}}}

function! autoupload#util#err_msg(msg) abort "{{{
  let msg = '[autoupload] '
  if type(a:msg) == type("")
    let msg .= a:msg
  else
    let msg .= string(a:msg)
  endif

  echohl WarningMsg
  echomsg msg
  echohl None
endfunction "}}}

function! autoupload#util#json_decode(json, ...) abort "{{{
  return call(s:vital_json().decode, [a:json], a:000)
endfunction "}}}

function! autoupload#util#unlet_vars(vars) abort "{{{
  for var in a:vars
    if exists({var})
      continue
    endif

    unlet {var}
  endfor
endfunction "}}}

function! autoupload#util#has_vimproc() abort "{{{
  return call(s:vital_process().has_vimproc, [])
endfunction "}}}

function! autoupload#util#system(cmd, async) abort "{{{
  if autoupload#util#has_vimproc() && a:async
    return s:system_async(a:cmd)
  else
    return call(s:vital_process().system, [a:cmd])
  endif
endfunction "}}}

function! s:system_async(cmd) abort "{{{
  let s:vimproc = vimproc#pgroup_open(a:cmd)
  call s:vimproc.stdin.close()

  let s:result = ''

  augroup vim-autoupload-async
    autocmd! CursorHold,CursorHoldI * call s:receive_vimproc_result()
  augroup END
endfunction "}}}

function! s:receive_vimproc_result() abort "{{{
  if !has_key(s:, 'vimproc')
    return
  endif

  try
    if !s:vimproc.stdout.eof
      let s:result .= s:vimproc.stdout.read()
    endif

    if !s:vimproc.stderr.eof
      let s:result .= s:vimproc.stderr.read()
    endif

    if !(s:vimproc.stdout.eof && s:vimproc.stderr.eof)
      return 0
    endif
  catch
    echomsg v:throwpoint
  endtry

  call s:finish_upload(s:result)

  augroup vim-autoupload-async
    autocmd!
  augroup END

  call s:vimproc.stdout.close()
  call s:vimproc.stderr.close()
  call s:vimproc.waitpid()
  unlet s:vimproc
  unlet s:result
endfunction "}}}

function! s:finish_upload(result) abort "{{{
  if !empty(a:result)
    call autoupload#util#err_msg('upload error: ' . a:result)
  else
    echo 'uploaded.'
  endif
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
