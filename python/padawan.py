import vim
from os import path
import urllib2
import urllib
import json
import subprocess
import time
import re

server_addr = vim.eval('g:padawan#server_addr')
server_path = vim.eval('g:padawan#server_path')
composer = vim.eval('g:padawan#composer_command')
timeout = float(vim.eval('g:padawan#timeout'))
padawanPath = path.join(path.dirname(__file__), '..')


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
        command = '{0}/bin/server.php > {0}/../logs/server.log'.format(
            server_path
        )
        subprocess.Popen(
            command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        )

    def StopServer(self):
        try:
            self.SendRequest('kill', {})
            return True
        except Exception:
            return False

    def RestartServer(self):
        if self.StopServer():
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
            errorMatch = re.search('Error: (.*)', line)
            if errorMatch is not None:
                retcode = 1
                vim.command("echom '{0}'".format(
                    errorMatch.group(1).replace("'", "''")
                ))
                break
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

            vim.command(
                "redraw | echo 'Progress "+barsStr+' '+str(progress)+"%'"
            )
            time.sleep(0.005)
        time.sleep(0.005)
        if retcode > 0:
            vim.command("echom 'Error occured, code: " + str(retcode) + "'")
            return
        self.RestartServer()
        barsStr = ''
        for i in range(20):
            barsStr += '='
        barsStr = '[' + barsStr + ']'
        vim.command("redraw | echo 'Progress "+barsStr+" 100%'")
        vim.command("echom 'Index generated'")

    def ComposerDumpAutoload(self, curProject):
        composerCommand = composer + ' dumpautoload -o'
        stream = subprocess.Popen(
            'cd {0} && {1}'.format(
                curProject,
                composerCommand
            ), shell=True)
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
