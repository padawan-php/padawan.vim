Padawan.vim
===========

Padawan.vim is a vim plugin for [padawan.php server
](https://github.com/mkusher/padawan.php).

This plugin includes:
- Omnifunc(it is terrible, I'm using [this YCMD client
](https://gist.github.com/mkusher/43bcff85d5e2f3ec3c55) instead)
- Index generation and saving commands
- Server manipulating commands(start, stop, restart)

Requirements
------------

You should have:

1. PHP 5.4+
2. Composer(accesible via `composer` command in bash)

Installation
------------

I recommend you to use some of the popular plugin managers like pathogen,
vundle, neobundle and plug.

### Pathogen

To install it via pathogen do the following steps:
```bash
cd TO YOUR PLUGINS FOLDER
git clone https://github.com/mkusher/padawan.vim.git
cd padawan.vim
git submodule update --init --recursive
cd padawan.php
php composer.phar install
```

### Plug
Add this to your vimrc
```vim
Plug 'mkusher/padawan.vim'
```

After `source %` and `:PlugInstall` go to the padawan.vim directory and do:

```bash
cd path/to/padawan.vim
cd padawan.php
php composer.phar install
```

Vim functions
-------------

### Index generation
Use `padawan#GenerateIndex()` function for it. For example:
```vim
:call padawan#GenerateIndex()
```
I advise you to map it to some keys.

### Index saving
Use `padawan#SaveIndex()` function for it. For example:
```vim
:call padawan#SaveIndex()
```
I advise you to map it to some keys.

### Starting server
Use `padawan#StartServer()` function for it. For example:
```vim
:call padawan#StartServer()
```
I advise you to map it to some keys.

### Stoping server
Use `padawan#StopServer()` function for it. For example:
```vim
:call padawan#StopServer()
```
I advise you to map it to some keys.

### Restarting server
Use `padawan#RestartServer()` function for it. For example:
```vim
:call padawan#RestartServer()
```
I advise you to map it to some keys.

