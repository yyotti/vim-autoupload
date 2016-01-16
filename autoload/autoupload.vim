scriptencoding utf-8
"=============================================================================
" FILE: autoupload.vim
" AUTHOR:  Y.Tsutsui
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

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

  let conf_file_name = get(g:, 'autoupload#config_file', '.autoupload.json')
  let conf_file_path = findfile(
        \   conf_file_name, fnamemodify(expand('%'), ':p:h') . ';**/'
        \ )
  if empty(conf_file_path)
    return
  endif

  let b:autoupload = {}

  let conf_file_path = fnamemodify(conf_file_path, ':p')
  if !s:load_config(conf_file_path)
    return
  endif

  let local_base = autoupload#util#add_last_separator(
        \   fnamemodify(conf_file_path, ':p:h')
        \ )

  let relpath = autoupload#util#relative_path(expand('%:p'), local_base)
  let b:autoupload.remote_dir = fnamemodify(relpath, ':h')
  for from in keys(b:autoupload.config.path_map)
    let remote = autoupload#util#add_last_separator(b:autoupload.remote_dir)
    if stridx(remote, from) == 0
      let b:autoupload.remote_dir = autoupload#util#add_last_separator(
            \   substitute(
            \     remote, from, b:autoupload.config.path_map[from], ''
            \   )
            \ )
    endif
  endfor
  let b:autoupload.remote_dir = autoupload#util#add_last_separator(
        \   b:autoupload.config.remote_base
        \ ) . b:autoupload.remote_dir

  let b:autoupload.local_path = local_base . relpath
endfunction "}}}

function! s:load_config(file_path) abort " {{{
  if !filereadable(a:file_path)
    return 0
  endif

  try
    let json_string = join(readfile(a:file_path), ' ')
    let json = autoupload#util#json_decode(json_string)
  catch
    return 0
  endtry

  if !s:check_config(json)
    return 0
  endif

  let b:autoupload.config = json
  call extend(b:autoupload.config, s:autoupload_default_config, 'keep')

  return 1
endfunction " }}}

function! s:check_config(config) abort " {{{
  if !has_key(a:config, 'host') || type(a:config.host) != 1
        \ || empty(a:config.host)
    call autoupload#util#error_message('hostは文字列で必ず指定してください')
    return 0
  endif

  if !has_key(a:config, 'user') || type(a:config.user) != 1
        \ || empty(a:config.user)
    call autoupload#util#error_message('userは文字列で必ず指定してください')
    return 0
  endif

  if has_key(a:config, 'timeout')
        \ && (type(a:config.timeout) != 0 || a:config.timeout < 1)
    call autoupload#util#error_message('timeoutは正数で指定してください')
    return 0
  endif

  if has_key(a:config, 'path_map') && (type(a:config.timeout) != 4)
    if type(a:config.path_map) != 4
      call autoupload#util#error_message('path_mapは辞書型で指定してください')
      return 0
    endif

    for key in keys(a:config.path_map)
      if type(a:config.path_map[key]) != 1
        call autoupload#util#error_message(
              \   'path_mapの値は文字列でなければなりません'
              \ )
        return 0
      endif
    endfor
  endif

  if has_key(a:config, 'auto') && type(a:config.auto) != 0
    call autoupload#util#error_message('autoは真偽値で指定してください')
    return 0
  endif

  if has_key(a:config, 'async') && type(a:config.auto) != 0
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

  let remote = shellescape(b:autoupload.config.user) . '@' .
        \ shellescape(b:autoupload.config.host)

  let commands = []
  call add(
        \   commands,
        \   printf(
        \     'ssh %s "mkdir -p %s"',
        \     remote, shellescape(b:autoupload.remote_dir)
        \   )
        \ )

  let scp_cmd  = 'scp'
  if b:autoupload.config.timeout > 0
    let scp_cmd .= ' -o "ConnectTimeout ' .
          \ b:autoupload.config.timeout . '"'
  endif
  let scp_cmd .= ' %s %s'
  call add(
        \   commands,
        \   printf(
        \     scp_cmd,
        \     shellescape(b:autoupload.local_path),
        \     remote . ':' . shellescape(b:autoupload.remote_dir)
        \   )
        \ )

  call autoupload#util#system(
        \   join(commands, ' && '),
        \   function('s:finish_upload'),
        \   b:autoupload.config.async
        \ )
endfunction "}}}

function! s:finish_upload(result) abort "{{{
  if !empty(a:result)
    call autoupload#util#error_message('upload error: ' . a:result)
  else
    call autoupload#util#message('uploaded')
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

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
