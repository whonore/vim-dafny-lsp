if exists('b:did_ftplugin')
  finish
endif
let b:did_ftplugin = 1

if executable('dafny')
  augroup dafnylsp
    autocmd! *
    autocmd User lsp_setup call dafnylsp#register()
  augroup END
endif
