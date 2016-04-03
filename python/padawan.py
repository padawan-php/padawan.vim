import vim
from os import path
import json
import subprocess
import time
import re
import socket

server_addr = vim.eval('g:padawan#server_addr')
server_command = vim.eval('g:padawan#server_command')
cli = vim.eval('g:padawan#cli')
composer = vim.eval('g:padawan#composer_command')
timeout = float(vim.eval('g:padawan#timeout'))
padawanPath = path.join(path.dirname(__file__), '..')

BUFFER_SIZE = 1024

class Server:
    def __init__(self):
        fullAddr = server_addr.split(":")
        self.addr = (
            fullAddr[0],
            int(fullAddr[1])
        )

    def start(self):
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
        self.socket = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    def stop(self):
        try:
            self.sendRequest('kill', {})
            return True
        except Exception:
            return False

    def restart(self):
        if self.stop():
            self.start()

    def sendRequest(self, command, params):
        s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        s.connect(self.addr)
        s.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
        requestData = json.dumps({
            'command': command,
            'params': params
        })
        s.send(requestData)
        response = ""
        while 1:
            chunk = s.recv(BUFFER_SIZE)
            if not chunk:
                break
            response += chunk
        result = json.loads(response)
        if "error" in result:
            raise Exception(result["error"])
        return result


class Editor:

    def prepare(self, message):
        return message.replace("'", "''")

    def log(self, message):
        vim.command("echo '%s'" % self.prepare(message))

    def notify(self, message):
        vim.command("echom '%s'" % self.prepare(message))

    def progress(self, progress):
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
        return

    def error(self, error):
        self.notify(error)

    def callAfter(self, timeout, callback):
        time.sleep(timeout)
        while callback():
            time.sleep(timeout)

server = Server()
editor = Editor()
pathError = '''padawan command is not found in your $PATH. Please\
make sure you installed padawan.php package and\
configured your $PATH'''


class PadawanClient:
    def GetCompletion(self, filepath, line_num, column_num, contents):
        curPath = self.GetProjectRoot(filepath)

        params = {
            'filepath': filepath.replace(curPath, ""),
            'line': line_num,
            'column': column_num,
            'path': curPath,
            'data': contents
            }
        result = self.DoRequest('complete', params, contents)

        if not result:
            return {"completion": []}

        return result

    def SaveIndex(self, filepath):
        return self.DoRequest('save', {'filepath': filepath})

    def DoRequest(self, command, params, data='', tries=1):
        try:
            return server.sendRequest(command, params)
        except socket.error as e:
            if tries > 3:
                editor.error("Padawan.php is not running")
            else:
                self.StartServer()
                return self.DoRequest(command, params, tries+1)
        except Exception as e:
            editor.error("Error occured {0}".format(e.message))

        return False

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

        def OnAdd(retcode):
            if not retcode:
                server.restart()
                editor.notify("Plugin installed")
            else:
                if retcode == 127:
                    editor.error(pathError)
                editor.error("Plugin installation failed")

        def LogAdding():
            retcode = stream.poll()
            if retcode is not None:
                return OnAdd(retcode)

            line = stream.stdout.readline()
            editor.log(line)
            return True

        editor.callAfter(1e-4, LogAdding)


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

        def onRemoved():
            subprocess.Popen(
                    '{0}'.format(
                        cli + ' plugin remove ' + plugin
                        ),
                    shell=True,
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT
                    ).wait()
            self.RestartServer()
            return editor.notify("Plugin removed")

        def LogRemoving():
            retcode = stream.poll()
            if retcode is not None:
                return onRemoved()

            line = stream.stdout.readline()
            editor.log(line)
            return True

        editor.callAfter(1e-4, LogRemoving)


    def Generate(self, filepath):
        curPath = self.GetProjectRoot(filepath)
        stream = subprocess.Popen(
                'cd ' + curPath + ' && ' + cli + ' generate',
                shell=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT
                )

        def onGenerationEnd(retcode):
            if retcode > 0:
                if retcode == 127:
                    editor.error(pathError)
                else:
                    editor.error("Error occured, code: {0}".format(str(retcode)))
                return
            server.restart()
            editor.progress(100)
            editor.notify("Index generated")

        def ProcessGenerationPoll():
            retcode = stream.poll()
            if retcode is not None:
                onGenerationEnd(retcode)
                return
            line = stream.stdout.readline()
            errorMatch = re.search('Error: (.*)', line)
            if errorMatch is not None:
                retcode = 1
                editor.error("{0}".format(
                    errorMatch.group(1).replace("'", "''")
                    ))
                return
            match = re.search('Progress: ([0-9]+)', line)
            if match is None:
                return True
            progress = int(match.group(1))
            editor.progress(progress)
            return True

        editor.callAfter(1e-4, ProcessGenerationPoll)

    def StartServer(self):
        server.start()

    def StopServer(self):
        server.stop()

    def RestartServer(self):
        server.restart()

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
