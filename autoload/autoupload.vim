scriptencoding utf-8
"=============================================================================
" FILE: autoupload.vim
" AUTHOR:  Y.Tsutsui
"=============================================================================

let s:save_cpo = &cpoptions
set cpoptions&vim

let s:autoupload_default_config = {
      \   'auto': 1,
      \   'async': 1,
      \   'timeout': -1,
      \   'remote_base': '',
      \   'path_map': {}
      \ }

function! s:is_initialized() abort "{{{
  return exists('b:autoupload') && has_key(b:autoupload, 'config')
endfunction "{{{ "}}} "}}}

function! autoupload#init(force) abort "{{{
  if s:is_initialized() && !a:force
    return
  endif

  if exists('b:autoupload')
    unlet b:autoupload
  endif

  if !executable('scp')
    return
  endif

  let l:conf_file_name = get(g:, 'autoupload#config_file', '.autoupload.json')
  let l:conf_file_path = findfile(
        \   l:conf_file_name, fnamemodify(expand('%'), ':p:h') . ';**/'
        \ )
  if empty(l:conf_file_path)
    return
  endif

  let b:autoupload = {}

  let l:conf_file_path = fnamemodify(l:conf_file_path, ':p')
  if !s:load_config(l:conf_file_path)
    return
  endif

  let l:local_base = autoupload#util#add_last_separator(
        \   fnamemodify(l:conf_file_path, ':p:h')
        \ )

  let l:relpath = autoupload#util#relative_path(expand('%:p'), l:local_base)
  let b:autoupload.remote_dir = fnamemodify(l:relpath, ':h')
  if b:autoupload.remote_dir ==# '.'
    let b:autoupload.remote_dir = ''
  endif
  for l:from in reverse(sort(keys(b:autoupload.config.path_map)))
    let l:remote = autoupload#util#add_last_separator(b:autoupload.remote_dir)
    if stridx(l:remote, l:from) == 0
      let b:autoupload.remote_dir = autoupload#util#add_last_separator(
            \   substitute(
            \     l:remote, l:from, b:autoupload.config.path_map[l:from], ''
            \   )
            \ )
    endif
  endfor
  let b:autoupload.remote_dir = autoupload#util#add_last_separator(
        \   b:autoupload.config.remote_base
        \ ) . b:autoupload.remote_dir

  let b:autoupload.local_path = l:local_base . l:relpath
endfunction "}}}

function! s:load_config(file_path) abort " {{{
  if !filereadable(a:file_path)
    return 0
  endif

  try
    let l:json_string = join(readfile(a:file_path), ' ')
    let l:json = autoupload#util#json_decode(l:json_string)
  catch
    return 0
  endtry

  if !s:check_config(l:json)
    return 0
  endif

  let b:autoupload.config = l:json
  call extend(b:autoupload.config, s:autoupload_default_config, 'keep')

  return 1
endfunction " }}}

function! s:check_config(config) abort " {{{
  if !has_key(a:config, 'host') || type(a:config.host) != type('')
        \ || empty(a:config.host)
    call autoupload#util#error_message('hostは文字列で必ず指定してください')
    return 0
  endif

  if !has_key(a:config, 'user') || type(a:config.user) != type('')
        \ || empty(a:config.user)
    call autoupload#util#error_message('userは文字列で必ず指定してください')
    return 0
  endif

  if has_key(a:config, 'timeout')
        \ && (type(a:config.timeout) != type(0) || a:config.timeout < 1)
    call autoupload#util#error_message('timeoutは正数で指定してください')
    return 0
  endif

  if has_key(a:config, 'path_map')
    if type(a:config.path_map) != type({})
      call autoupload#util#error_message('path_mapは辞書型で指定してください')
      return 0
    endif

    for l:key in keys(a:config.path_map)
      if type(a:config.path_map[l:key]) != type('')
        call autoupload#util#error_message(
              \   'path_mapの値は文字列でなければなりません'
              \ )
        return 0
      endif
    endfor
  endif

  if has_key(a:config, 'auto') && type(a:config.auto) != type(0)
    call autoupload#util#error_message('autoは真偽値で指定してください')
    return 0
  endif

  if has_key(a:config, 'async') && type(a:config.auto) != type(0)
    call autoupload#util#error_message('asyncは真偽値で指定してください')
    return 0
  endif

  return 1
endfunction " }}}

function! autoupload#upload(force) abort "{{{
  if !s:is_initialized()
        \ || !a:force && !b:autoupload.config.auto
    return
  endif

  let l:params = copy(b:autoupload.config)
  let l:params.remote_dir = b:autoupload.remote_dir
  let l:params.local_path = b:autoupload.local_path
  let l:params.on_exit = function('s:finish_upload')

  call autoupload#scp#upload(l:params)
endfunction "}}}

function! s:finish_upload(result) abort "{{{
  if !empty(a:result)
    call autoupload#util#error_message('upload error: ' . a:result)
  else
    call autoupload#util#message(
          \   printf('%s  uploaded.', strftime('%Y-%m-%d %H:%M:%S'))
          \ )
  endif
endfunction "}}}

function! autoupload#enable_auto() abort "{{{
  if !s:is_initialized()
    call autoupload#util#error_message('初期化されていません')
    return
  endif

  let b:autoupload.config.auto = 1
endfunction "}}}

function! autoupload#disable_auto() abort "{{{
  if !s:is_initialized()
    call autoupload#util#error_message('初期化されていません')
    return
  endif

  let b:autoupload.config.auto = 0
endfunction "}}}

function! autoupload#toggle_auto() abort "{{{
  if !s:is_initialized()
    call autoupload#util#error_message('初期化されていません')
    return
  endif

  let b:autoupload.config.auto = !b:autoupload.config.auto
  call autoupload#util#message(b:autoupload.config.auto ? 'auto' : 'manual')
endfunction "}}}

let &cpoptions = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
