if exists('g:loaded_dafny_lsp')
  finish
endif
let g:loaded_dafny_lsp = 1

let s:server_name = 'dafny'

function! dafnylsp#register() abort
  call lsp#register_server({
    \ 'name': s:server_name,
    \ 'cmd': ['dafny', 'server'],
    \ 'root_uri': {server_info -> lsp#utils#path_to_uri(
      \ lsp#utils#find_nearest_parent_file_directory(
        \ lsp#utils#get_buffer_path(),
        \ ['.git/'],
      \)
    \)},
    \ 'allowlist': ['dafny'],
  \})
endfunction
