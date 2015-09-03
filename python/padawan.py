import vim
from os import path
import urllib2
import urllib
import json
import subprocess
import time
import re

server_addr = vim.eval('g:padawan#server_addr')
server_command = vim.eval('g:padawan#server_command')
cli = vim.eval('g:padawan#cli')
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
        command = '{0} > {1}/logs/server.log'.format(
            server_command,
            padawanPath
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
        composerCommand = composer + ' global require '

        command = '{0} {2} && {1} plugin add {2}'.format(
            composerCommand,
            cli,
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
            if retcode == 127:
                message = '''padawan command is not found in your $PATH. Please\
 make sure you installed padawan.php package and\
 configured your $PATH'''
                vim.command("echom '{0}'".format(message))
            vim.command("echom 'Plugin installation failed'")

    def RemovePlugin(self, plugin):
        composerCommand = composer + ' global remove'

        command = '{0} {1}'.format(
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
            '{0}'.format(
                cli + ' plugin remove ' + plugin
            ),
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT
        ).wait()
        self.RestartServer()
        vim.command("echom 'Plugin removed'")

    def Generate(self, filepath):
        curPath = self.GetProjectRoot(filepath)
        stream = subprocess.Popen(
            'cd ' + curPath + ' && ' + cli + ' generate',
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
            if retcode == 127:
                message = '''padawan command is not found in your $PATH. Please\
 make sure you installed padawan.php package and\
 configured your $PATH'''
                vim.command("echom '{0}'".format(message))
            else:
                vim.command("echom 'Error occured, code: " + str(retcode) + "'")
            return
        self.RestartServer()
        barsStr = ''
        for i in range(20):
            barsStr += '='
        barsStr = '[' + barsStr + ']'
        vim.command("redraw | echo 'Progress "+barsStr+" 100%'")
        vim.command("echom 'Index generated'")

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
