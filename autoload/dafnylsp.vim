if exists('g:loaded_dafny_lsp')
  finish
endif
let g:loaded_dafny_lsp = 1

let s:server_name = 'dafny'
let s:prefix = 'DafnyLsp'

let s:status_gutter_delay = 100

let s:status_nothing = 0
let s:status_scheduled = 1
let s:status_verifying = 2
let s:status_verified = 200
let s:status_error_context = 300
let s:status_assertion_verified_in_error_context = 350
let s:status_assertion_failed = 400
let s:status_resolution_error = 500

let s:statuses = {
  \ s:status_scheduled: {
    \ 'name': 'Scheduled',
    \ 'text': '..',
  \},
  \ s:status_verifying: {
    \ 'name': 'Verifying',
    \ 'text': '..',
  \},
  \ s:status_verified: {
    \ 'name': 'Verified',
    \ 'text': '✓',
  \},
  \ s:status_error_context: {
    \ 'name': 'ErrorContext',
    \ 'text': '*',
  \},
  \ s:status_assertion_verified_in_error_context: {
    \ 'name': 'AssertionVerifiedInErrorContext',
    \ 'text': '✓',
  \},
  \ s:status_assertion_failed: {
    \ 'name': 'AssertionFailed',
    \ 'text': '✗',
  \},
  \ s:status_resolution_error: {
    \ 'name': 'ResolutionError',
    \ 'text': '!',
  \},
\}
let s:statuses_with_mods = [
  \ s:status_verified,
  \ s:status_error_context,
  \ s:status_assertion_verified_in_error_context,
  \ s:status_assertion_failed,
\]
let s:status_mod_suffix = {
  \ s:status_nothing: '',
  \ s:status_scheduled: 'Obsolete',
  \ s:status_verifying: 'Verifying',
\}

function! s:hilink(name, hlgroup)
  if !hlexists(s:prefix . a:name)
    call hlset([{'name': s:prefix . a:name, 'linksto': a:hlgroup}])
  endif
endfunction

call s:hilink('Scheduled', 'Todo')
call s:hilink('Verifying', 'Normal')
call s:hilink('Verified', 'LineNr')
call s:hilink('VerifiedObsolete', 'Todo')
call s:hilink('VerifiedVerifying', 'Normal')
call s:hilink('ErrorContext', 'Normal')
call s:hilink('ErrorContextObsolete', 'Todo')
call s:hilink('ErrorContextVerifying', 'Normal')
call s:hilink('AssertionVerifiedInErrorContext', 'LineNr')
call s:hilink('AssertionVerifiedInErrorContextObsolete', 'Todo')
call s:hilink('AssertionVerifiedInErrorContextVerifying', 'Normal')
call s:hilink('AssertionFailed', 'Error')
call s:hilink('AssertionFailedObsolete', 'Todo')
call s:hilink('AssertionFailedVerifying', 'Normal')
call s:hilink('ResolutionError', 'Error')

function! s:parse_status(status) abort
  if a:status < 100
    return [a:status, s:status_nothing]
  else
    let l:mod = a:status % 10
    let l:base = a:status - l:mod
    return [l:base, l:mod]
  endif
endfunction

function! s:define_sign(name, text) abort
  call sign_define(
    \ s:prefix . a:name,
    \ {'text': a:text, 'texthl': s:prefix . a:name}
  \)
endfunction

function! s:define_signs() abort
  for [l:status, l:info] in items(s:statuses)
    if index(s:statuses_with_mods, str2nr(l:status)) != -1
      for l:suffix in values(s:status_mod_suffix)
        call s:define_sign(l:info.name . l:suffix, l:info.text)
      endfor
    else
      call s:define_sign(l:info.name, l:info.text)
    endif
  endfor
endfunction

function! s:on_status_gutter(params) abort
  let l:bnum = bufname(lsp#utils#uri_to_path(a:params.uri))
  if l:bnum == -1 || !bufloaded(l:bnum)
    return
  endif

  call sign_unplace(s:prefix)

  for l:lnum in range(len(a:params.perLineStatus))
    let [l:status, l:mod] = s:parse_status(a:params.perLineStatus[l:lnum])
    if has_key(s:statuses, l:status)
      call sign_place(
        \ 0,
        \ s:prefix,
        \ s:prefix . s:statuses[l:status].name . s:status_mod_suffix[l:mod],
        \ l:bnum,
        \ {'lnum': l:lnum + 1}
      \)
    endif
  endfor
endfunction

function! s:on_notification(method, callback, delay) abort
  call lsp#callbag#pipe(
    \ lsp#stream(),
    \ lsp#callbag#filter({msg ->
      \ has_key(msg, 'response')
      \ && !lsp#client#is_error(msg.response)
      \ && get(msg.response, 'method', '') == a:method
    \}),
    \ lsp#callbag#debounceTime(a:delay),
    \ lsp#callbag#map({msg -> msg.response.params}),
    \ lsp#callbag#subscribe({'next': a:callback}),
  \)
endfunction

function! dafnylsp#register() abort
  call lsp#register_server({
    \ 'name': s:server_name,
    \ 'cmd': ['dafny', 'server', '--notify-line-verification-status:true'],
    \ 'root_uri': {server_info -> lsp#utils#path_to_uri(
      \ lsp#utils#find_nearest_parent_file_directory(
        \ lsp#utils#get_buffer_path(),
        \ ['.git/'],
      \)
    \)},
    \ 'allowlist': ['dafny'],
  \})

  call s:on_notification(
    \ 'dafny/verification/status/gutter',
    \ function('s:on_status_gutter'),
    \ s:status_gutter_delay,
  \)

  call s:define_signs()
endfunction
