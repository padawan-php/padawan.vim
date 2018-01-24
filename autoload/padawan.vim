" Vim client for padawan.php
" Language: PHP
" Maintainer:     Aleh Kashnikau ( aleh.kashnikau AT gmail DOT com )

if exists('did_padawan_autoload')
    finish
endif
let did_padawan_autoload = 1
let g:padawanPath = expand('<sfile>:p:h:h')

if !exists('g:padawan#composer_command')
    let g:padawan#composer_command = 'composer.phar'
endif
if !exists('g:padawan#server_command')
    let g:padawan#server_command = 'padawan-server'
endif
if !exists('g:padawan#cli')
    let g:padawan#cli = 'padawan'
endif
if !exists('g:padawan#server_addr')
    let g:padawan#server_addr = 'http://localhost:15155'
endif
if !exists('g:padawan#timeout')
    let g:padawan#timeout = "0.75"
endif
if !exists('g:padawan#enabled')
    let g:padawan#enabled = 1
endif

python3 << EOF

import vim
import sys
import os

padawanPath = vim.eval('g:padawanPath')
lib_path = os.path.join(padawanPath, 'python')
sys.path.insert(0, lib_path)

EOF

function! padawan#Complete(findstart, base) " {{{
    if g:padawan#enabled == 0
        return -2
    endif
python3 << ENDPYTHON

import vim
from padawan import client, editor

def createDictionaryStr(completions):
    dic = ", ".join([
        "{'word': '%s', 'abbr': '%s', 'info': '%s', 'menu': '%s'}".replace("'","\"") % (
            editor.prepare(completion["word"]),
            editor.prepare(completion["abbr"]),
            editor.prepare(completion["info"]),
            editor.prepare(completion["menu"])
            )
        for completion in completions
    ])
    dic = str(dic).replace("'\\n',","',")
    return dic

findstart = vim.eval('a:findstart')
column = vim.eval("col('.')")
if findstart == '1':
    line = vim.eval("getline('.')")
    def findColumn(column, line):
        column = int(column)
        if not type(column) is int:
            return 0
        if not type(line) is str:
            return 0
        curColumn = column - 1
        while curColumn > 0:
            curChar = line[curColumn-1]
            if curChar == ' ':
                return column
            if curChar == '\\':
                return curColumn
            if curChar == '$':
                return curColumn
            if curChar == ';':
                return column
            if curChar == '=':
                return column
            if curChar == '(':
                return curColumn
            curChar = line[(curColumn-2):curColumn]
            if curChar == '->':
                return curColumn
            if curChar == '::':
                return curColumn
            curColumn -= 1
        return 0
    vim.command('return {0}'.format(findColumn(column, line)))
else:
    line = vim.eval('line(\'.\')')
    filepath = vim.eval('expand(\'%:p\')')
    contents = "\n".join(vim.current.buffer)
    completions = client.GetCompletion(filepath, line, column, contents)
    completions = [
        {
        'word': completion["name"].encode("ascii", 'ignore') if completion["name"] else '',
        'abbr': completion["menu"].encode("ascii", 'ignore') if completion["menu"] else '',
        'info': completion["description"].encode("ascii", 'ignore') if completion["description"] else '',
        'menu': completion["signature"].encode('ascii', 'ignore') if completion["signature"] else ''
        }
        for completion in completions["completion"]
    ]
    vim.command(("let completions = [%s]" % createDictionaryStr(completions)).replace('\\\\', '\\'))
ENDPYTHON
    return completions
endfunction
" }}}

function! padawan#Disable()
    let g:padawan#enabled = 0
endfunction

function! padawan#Enable()
    let g:padawan#enabled = 1
endfunction

function! padawan#StartServer()
python3 << EOF
from padawan import client
client.StartServer()
EOF
endfunction

function! padawan#StopServer()
python3 << EOF
from padawan import client
client.StopServer()
EOF
endfunction

function! padawan#RestartServer()
python3 << EOF
from padawan import client
client.RestartServer()
EOF
endfunction

function! padawan#SaveIndex()
python3 << EOF
import vim
from padawan import client
filepath = vim.eval("expand('%:p')")
client.SaveIndex(filepath)
EOF
endfunction

function! padawan#UpdateIndex()
python3 << endpython
import vim
from padawan import client
filepath = vim.eval("expand('%:p')")
client.UpdateIndex(filepath)
endpython
endfunction

function! padawan#GenerateIndex()
python3 << endpython
import vim
from padawan import client
filepath = vim.eval("expand('%:p')")
client.Generate(filepath)
endpython
endfunction

function! padawan#AddPlugin(pluginName)
python3 << endpython
import vim
from padawan import client
pluginName = vim.eval("a:pluginName")
client.AddPlugin(pluginName)
endpython
endfunction

function! padawan#RemovePlugin(pluginName)
python3 << endpython
import vim
from padawan import client
pluginName = vim.eval("a:pluginName")
client.RemovePlugin(pluginName)
endpython
endfunction
