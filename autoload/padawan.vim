" Vim client for padawan.php
" Language: PHP
" Maintainer:     Aleh Kashnikau ( aleh.kashnikau AT gmail DOT com )

if exists('did_padawan_autoload')
    finish
endif
let did_padawan_autoload = 1

if !exists('g:padawan#composer_command')
    let g:padawan#composer_command = 'composer'
endif
if !exists('g:padawan#server_path')
    let g:padawan#server_path = expand('<sfile>:p:h:h') . '/padawan.php'
endif
if !exists('g:padawan#server_addr')
    let g:padawan#server_addr = 'http://localhost:15155'
endif
if !exists('g:padawan#enabled')
    let g:padawan#enabled = 1
endif
if !exists('g:padawan#timeout')
    let g:padawan#timeout = 0.1
endif

python << EOF
import vim
from os import path
import urllib2
import httplib
import urllib
import json
import codecs
import subprocess
import time
import re


server_addr = vim.eval('g:padawan#server_addr')
server_path = vim.eval('g:padawan#server_path')
composer = vim.eval('g:padawan#composer_command')
timeout = float(vim.eval('g:padawan#timeout'))


class PadawanClient:
    server_process = 0

    def GetCompletion(self, filepath, line_num, column_num, contents):
        curPath = self.GetProjectRoot(filepath)

        params = {
            'filepath': filepath.replace(curPath, ""),
            'line': line_num,
            'column': column_num,
            'path': curPath
        }
        result = self.DoRequest('complete', params, contents)

        if not result:
            return {"completion": []}

        return result

    def SaveIndex(self, filepath):
        return self.DoRequest('save', {'filepath': filepath})

    def DoRequest(self, command, params, data=''):
        try:
            addr = server_addr + "/"+command+"?" + urllib.urlencode(params)
            response = urllib2.urlopen(
                addr,
                urllib.quote_plus(data),
                timeout
            )
            completions = json.load(response)
            if "error" in completions:
                raise ValueError(completions["error"])
            return completions
        except urllib2.URLError:
            vim.command('echo "Padawan.php is not running"')
        except Exception as e:
            vim.command('echom "Error occured {0}"'.format(e))

        return False

    def StartServer(self):
        command = '{0}/bin/server.php > {0}/../logs/server.log'.format(server_path)
        self.server_process = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )

    def StopServer(self):
        self.server_process.kill()

    def AddPlugin(self, plugin):
        curPath = self.GetProjectRoot(filepath)
        self.ComposerDumpAutoload(curPath)
        generatorCommand = server_path + '/bin/cli'

        stream = subprocess.Popen(
            'cd ' + curPath + ' && ' + generatorCommand + ' plugin add ' + plugin,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )
    def Generate(self, filepath):
        curPath = self.GetProjectRoot(filepath)
        self.ComposerDumpAutoload(curPath)
        generatorCommand = server_path + '/bin/cli'
        stream = subprocess.Popen(
            'cd ' + curPath + ' && ' + generatorCommand + ' generate',
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )
        while True:
            retcode = stream.poll()
            if retcode is not None:
                break
            line = stream.stdout.readline()
            match = re.search('Progress: ([0-9]+)', line)
            if match is None:
                continue
            progress = int(match.group(1))

            bars = int(progress / 5)
            barsStr = ''
            for i in range(20):
                if i < bars:
                    barsStr += '='
                else:
                    barsStr += ' '
            barsStr = '[' + barsStr + ']'

            vim.command("redraw | echo 'Progress "+barsStr+' '+str(progress)+"%'")
            time.sleep(0.005)
        time.sleep(0.005)
        barsStr = ''
        for i in range(20):
            barsStr += '='
        barsStr = '[' + barsStr + ']'
        vim.command("redraw | echo 'Progress "+barsStr+" 100%'")
        vim.command("echom 'Index generated'")

    def ComposerDumpAutoload(self, curProject):
        composerCommand = composer + ' dumpautoload -o'
        subprocess.call('cd {0} && {1}'.format(curProject, composerCommand), shell=True)

    def GetProjectRoot(self, filepath):
        curPath = path.dirname(filepath)
        while curPath != '/' and not path.exists(
            path.join(curPath, 'composer.json')
        ):
            curPath = path.dirname(curPath)

        if curPath == '/':
            curPath = path.dirname(filepath)

        return curPath

client = PadawanClient()
EOF

function! padawan#Complete(findstart, base) " {{{
python << ENDPYTHON

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
                return curColumn
            if curChar == '\\':
                return curColumn
            if curChar == '$':
                return curColumn
            if curChar == ';':
                return curColumn
            if curChar == '=':
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
            'word': completion["name"].encode("ascii"),
            'abbr': completion["menu"].encode("ascii"),
            'info': completion["description"].encode("ascii"),
            'menu': completion["signature"].encode('ascii')
        }
        for completion in completions["completion"]
    ]
    vim.command(("let completions = %s" % completions).replace('\\\\', '\\'))
ENDPYTHON
    return completions
endfunction
" }}}

function! padawan#Enable()
endfunction

function! padawan#Disable()
endfunction

function! padawan#StartServer()
python << EOF
client.StartServer()
EOF
endfunction

function! padawan#StopServer()
python << EOF
client.StopServer()
EOF
endfunction

function! padawan#RestartServer()
python << EOF
client.StopServer()
client.StartServer()
EOF
endfunction

function! padawan#SaveIndex()
python << EOF
filepath = vim.eval("expand('%:p')")
client.SaveIndex(filepath)
EOF
endfunction

function! padawan#GenerateIndex()
python << endpython
filepath = vim.eval("expand('%:p')")
client.Generate(filepath)
endpython
endfunction
