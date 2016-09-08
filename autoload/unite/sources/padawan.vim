let s:save_cpo = &cpo
set cpo&vim

if !g:loaded_unite
    finish
endif

let padawanPath = expand('<sfile>:p:h:h:h:h')
python << EOF

import vim
import sys
import os

padawanPath = vim.eval('padawanPath')
lib_path = os.path.join(padawanPath, 'python')
sys.path.insert(0, lib_path)

EOF

function! unite#sources#padawan#define()
    return [s:source]
endfunction

let s:source = {
            \ 'name' : 'padawan/classes',
            \ 'description' : 'File candidates read from the padawan.php classes list',
            \ 'action_table' : {},
            \ 'default_kind' : 'file',
            \}

function! s:source.gather_candidates(args, context)
python << endpython
import vim
from padawan import client, editor

path = vim.eval("getcwd()")
classes = client.GetClassesList(path)
entries = ", ".join([
    "{'word': '%s', 'action__path': '%s', 'action__line': 0}" % (
        editor.prepare(class_entry["fqcn"]),
        editor.prepare(class_entry["filepath"])
    )
    for class_entry in classes
])
vim.command(("let entries = [%s]" % entries))
endpython
    return entries
endfunction
