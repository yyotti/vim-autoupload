scriptencoding utf-8
"=============================================================================
" FILE: autoupload.vim
" AUTHOR:  Y.Tsutsui
"=============================================================================

let s:save_cpo = &cpo
set cpo&vim

let s:autoupload_default_config = {
      \   'enable': 1,
      \   'timeout': -1,
      \   'remote_base': '',
      \   'path_map': {}
      \ }

function! autoupload#init(force) abort "{{{
  if get(b:, 'autoupload_init', 0) && !a:force
    return
  endif

  call autoupload#util#unlet_vars([
        \   'b:autoupload_init',
        \   'b:autoupload_remote_dir',
        \   'b:autoupload_config',
        \   'b:autoupload_local_path',
        \ ])

  if !executable('scp')
    let b:autoupload_init = 1
    return
  endif

  let conf_file_name = get(g:, 'autoupload#config_file', '.autoupload.json')
  let conf_file_path = findfile(
        \   conf_file_name, fnamemodify(expand('%'), ':p:h') . ';**/'
        \ )
  if empty(conf_file_path)
    let b:autoupload_init = 1
    return
  endif

  let conf_file_path = fnamemodify(conf_file_path, ':p')
  if !s:load_config(conf_file_path)
    let b:autoupload_init = 1
    return
  endif

  let local_base = autoupload#util#add_last_separator(
        \   fnamemodify(conf_file_path, ':p:h')
        \ )

  let relpath = autoupload#util#relative_path(expand('%:p'), local_base)
  let b:autoupload_remote_dir = fnamemodify(relpath, ':h')
  for from in keys(b:autoupload_config.path_map)
    let remote = autoupload#util#add_last_separator(b:autoupload_remote_dir)
    if stridx(remote, from) == 0
      let b:autoupload_remote_dir = autoupload#util#add_last_separator(
            \   substitute(
            \     remote, from, b:autoupload_config.path_map[from], ''
            \   )
            \ )
    endif
  endfor
  let b:autoupload_remote_dir = autoupload#util#add_last_separator(
        \   b:autoupload_config.remote_base
        \ ) . b:autoupload_remote_dir

  let b:autoupload_local_path = local_base . relpath

  let b:autoupload_init = 1
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

  let b:autoupload_config = json
  call extend(b:autoupload_config, s:autoupload_default_config, 'keep')

  return 1
endfunction " }}}

function! s:check_config(config) abort " {{{
  if !has_key(a:config, 'host') || type(a:config.host) != 1 || empty(a:config.host)
    call autoupload#util#err_msg('hostは文字列で必ず指定してください')
    return 0
  endif

  if !has_key(a:config, 'user') || type(a:config.user) != 1 || empty(a:config.user)
    call autoupload#util#err_msg('userは文字列で必ず指定してください')
    return 0
  endif

  if has_key(a:config, 'timeout') && (type(a:config.timeout) != 0 || a:config.timeout < 1)
    call autoupload#util#err_msg('timeoutは正数で指定してください')
    return 0
  endif

  if has_key(a:config, 'path_map') && (type(a:config.timeout) != 4)
    if type(a:config.path_map) != 4
      call autoupload#util#err_msg('path_mapは辞書型で指定してください')
      return 0
    endif

    for key in keys(a:config.path_map)
      if type(a:config.path_map[key]) != 1
        call autoupload#util#err_msg('path_mapの値は文字列でなければなりません')
        return 0
      endif
    endfor
  endif

  if has_key(a:config, 'enable') && type(a:config.enable) != 0
    call autoupload#util#err_msg('enableは真偽値で指定してください')
    return 0
  endif

  return 1
endfunction " }}}

function! autoupload#upload(force) abort "{{{
  if !exists('b:autoupload_config')
        \ || !a:force && !b:autoupload_config.enable
    return
  endif

  let remote = shellescape(b:autoupload_config.user) . '@' .
        \ shellescape(b:autoupload_config.host)

  let commands = []
  call add(
        \   commands,
        \   printf(
        \     'ssh %s "mkdir -p %s"',
        \     remote, shellescape(b:autoupload_remote_dir)
        \   )
        \ )

  let scp_cmd  = 'scp'
  if b:autoupload_config.timeout > 0
    let scp_cmd .= ' -o "ConnectTimeout ' .
          \ b:autoupload_config.timeout . '"'
  endif
  let scp_cmd .= ' %s %s'
  call add(
        \   commands,
        \   printf(
        \     scp_cmd,
        \     shellescape(b:autoupload_local_path),
        \     remote . ':' . shellescape(b:autoupload_remote_dir)
        \   )
        \ )


  let res = autoupload#util#system(join(commands, ' && '), 1)
  if !empty(res)
    call autoupload#util#err_msg(res)
  else
    echo 'uploaded.'
  endif
endfunction "}}}

function! autoupload#enable() abort "{{{
  if !exists('b:autoupload_config')
    call autoupload#util#err_msg('初期化されていません')
    return
  endif

  let b:autoupload_config.enable = 1
endfunction "}}}

function! autoupload#disable() abort "{{{
  if !exists('b:autoupload_config')
    call autoupload#util#err_msg('初期化されていません')
    return
  endif

  let b:autoupload_config.enable = 0
endfunction "}}}

function! autoupload#toggle() abort "{{{
  if !exists('b:autoupload_config')
    call autoupload#util#err_msg('初期化されていません')
    return
  endif

  let b:autoupload_config.enable = !b:autoupload_config.enable
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
