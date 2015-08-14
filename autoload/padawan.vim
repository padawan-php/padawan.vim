" Vim client for padawan.php
" Language: PHP
" Maintainer:     Aleh Kashnikau ( aleh.kashnikau AT gmail DOT com )

if exists('did_padawan_autoload')
    finish
endif
let did_padawan_autoload = 1
let padawanPath = expand('<sfile>:p:h:h')

if !exists('g:padawan#composer_command')
    let g:padawan#composer_command = padawanPath . '/composer.phar'
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
    let g:padawan#timeout = 0.15
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
padawanPath = vim.eval('padawanPath')


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
            return self.SendRequest(command, params, data)
        except urllib2.URLError:
            vim.command('echo "Padawan.php is not running"')
        except Exception as e:
            vim.command('echom "Error occured {0}"'.format(e))

        return False

    def SendRequest(self, command, params, data=''):
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


    def StartServer(self):
        command = '{0}/bin/server.php > {0}/../logs/server.log'.format(server_path)
        subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )

    def StopServer(self):
        try:
            return self.SendRequest('kill', {})
        except Exception:
            return False

    def RestartServer(self):
        self.StopServer()
        self.StartServer()

    def AddPlugin(self, plugin):
        composerCommand = composer + ' require '
        generatorCommand = server_path + '/bin/cli'

        command = 'cd {0} && {1} {3} && {2} plugin add {3}'.format(
            self.PadawanPHPPath(),
            composerCommand,
            generatorCommand,
            plugin
        )

        stream = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )

        while True:
            retcode = stream.poll()
            if retcode is not None:
                break

            line = stream.stdout.readline()
            vim.command("echo '%s'" % line.replace("'", "''"))
            time.sleep(0.005)

        if not retcode:
            self.RestartServer()
            vim.command("echom 'Plugin installed'")
        else:
            vim.command("echom 'Plugin installation failed'")

    def RemovePlugin(self, plugin):
        composerCommand = composer + ' remove'
        generatorCommand = server_path + '/bin/cli'

        command = 'cd {0} && {1} {2}'.format(
            self.PadawanPHPPath(),
            composerCommand,
            plugin
        )

        stream = subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )

        while True:
            retcode = stream.poll()
            if retcode is not None:
                break

            line = stream.stdout.readline()
            vim.command("echo '%s'" % line)
            time.sleep(0.005)

        subprocess.Popen(
            'cd {0} && {1}'.format(
                self.PadawanPHPPath(),
                generatorCommand + ' plugin remove ' + plugin
            ),
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        ).wait()
        self.RestartServer()
        vim.command("echom 'Plugin removed'")

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
        self.RestartServer()
        barsStr = ''
        for i in range(20):
            barsStr += '='
        barsStr = '[' + barsStr + ']'
        vim.command("redraw | echo 'Progress "+barsStr+" 100%'")
        vim.command("echom 'Index generated'")

    def ComposerDumpAutoload(self, curProject):
        composerCommand = composer + ' dumpautoload -o'
        stream = subprocess.Popen('cd {0} && {1}'.format(curProject, composerCommand), shell=True)
        stream.wait()

    def GetProjectRoot(self, filepath):
        curPath = path.dirname(filepath)
        while curPath != '/' and not path.exists(
            path.join(curPath, 'composer.json')
        ):
            curPath = path.dirname(curPath)

        if curPath == '/':
            curPath = path.dirname(filepath)

        return curPath

    def PadawanPHPPath(self):
        return padawanPath + '/padawan.php/'

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
client.RestartServer()
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

function! padawan#AddPlugin(pluginName)
python << endpython
pluginName = vim.eval("a:pluginName")
client.AddPlugin(pluginName)
endpython
endfunction

function! padawan#RemovePlugin(pluginName)
python << endpython
pluginName = vim.eval("a:pluginName")
client.RemovePlugin(pluginName)
endpython
endfunction

command! -nargs=0 -bar PadawanStartServer call padawan#StartServer()
command! -nargs=0 -bar PadawanStopServer call padawan#StopServer()
command! -nargs=0 -bar PadawanRestartServer call padawan#RestartServer()
command! -nargs=0 -bar PadawanGenerateIndex call padawan#GenerateIndex()
command! -nargs=1 -bar PadawanAddPlugin call padawan#AddPlugin("<args>")
command! -nargs=1 -bar PadawanRemovePlugin call padawan#RemovePlugin("<args>")
