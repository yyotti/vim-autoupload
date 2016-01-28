scriptencoding utf-8
"=============================================================================
" FILE: scp.vim
" AUTHOR: Y.Tsutsui
"=============================================================================
let s:save_cpo = &cpo
set cpo&vim

let s:jobs = {}

function! autoupload#scp#upload(params) abort "{{{
  if has('nvim')
    call s:nvim_upload(a:params)
  else
    call s:upload(a:params)
  endif
endfunction "}}}

function! s:nvim_upload(params) abort "{{{
  let remote = a:params.user . '@' . a:params.host

  let mkdir_cmd = [
        \   'ssh',
        \   remote,
        \   'mkdir',
        \   '-p',
        \   shellescape(a:params.remote_dir),
        \ ]

  let scp_cmd = [ 'scp' ]
  if a:params.timeout > 0
    let scp_cmd += [ '-o', 'ConnectTimeout ' . a:params.timeout ]
  endif
  let scp_cmd += [
        \   a:params.local_path,
        \   remote . ':' . a:params.remote_dir,
        \ ]

  let commands = [ mkdir_cmd, scp_cmd ]

  call s:start_job(commands, a:params.on_exit)
endfunction "}}}

function! s:start_job(commands, func) abort "{{{
  if empty(a:commands)
    return
  endif

  let cmd = a:commands[0]
  let next_commands = copy(a:commands)
  call remove(next_commands, 0)

  let options = {
        \   'on_stdout': function('s:on_progress'),
        \   'on_stderr': function('s:on_progress'),
        \   'on_exit': function('s:on_exit'),
        \ }

  let id = jobstart(cmd, options)

  let s:jobs[id] = {
        \   'id': id,
        \   'next_commands': next_commands,
        \   'lines': [],
        \   'func': a:func,
        \ }
endfunction "}}}

" @vimlint(EVL103, 1, a:event)
function! s:on_progress(job_id, data, event) abort "{{{
  if !has_key(s:jobs, a:job_id)
    return
  endif

  let s:jobs[a:job_id].lines += a:data
endfunction "}}}
" @vimlint(EVL103, 0, a:event)

" @vimlint(EVL103, 1, a:event)
function! s:on_exit(job_id, data, event) abort "{{{
  if !has_key(s:jobs, a:job_id)
    return
  endif

  let job = s:jobs[a:job_id]
  unlet s:jobs[a:job_id]

  if a:data != 0
    call job.func(join(job.lines, "\n"))
    return
  endif

  if empty(job.next_commands)
    call job.func('')
  else
    call s:start_job(job.next_commands, job.func)
  endif
endfunction "}}}
" @vimlint(EVL103, 0, a:event)

function! s:upload(params) abort "{{{
  let remote = shellescape(a:params.user) . '@' . shellescape(a:params.host)

  let cmd  = 'ssh'
  let cmd .= ' '
  let cmd .= remote
  let cmd .= ' '
  let cmd .= '"mkdir -p ' . shellescape(a:params.remote_dir) . '"'

  let cmd .= ' && '

  let cmd .= 'scp'
  if a:params.timeout > 0
    let cmd .= ' -o "ConnectTimeout ' . a:params.timeout . '"'
  endif
  let cmd .= ' '
  let cmd .= shellescape(a:params.local_path)
  let cmd .= ' '
  let cmd .= remote . ':' . shellescape(a:params.remote_dir)

  call autoupload#util#system(cmd, a:params.on_exit, a:params.async)
endfunction "}}}

let &cpo = s:save_cpo
unlet s:save_cpo

" vim:set foldmethod=marker:
