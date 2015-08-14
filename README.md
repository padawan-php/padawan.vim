Padawan.vim
===========

Padawan.vim is a vim plugin for [padawan.php server
](https://github.com/mkusher/padawan.php) - smart php intelligent code
completion server for composer projects.

This plugin includes:
- Omnifunc
- Index generation and saving commands
- Server manipulating commands(start, stop, restart)

### Demo video

Currently it has basic completion for classes and methods based on doc comments
and methods signature.

Watch this short video to see what it can already do(image is clickable)
[![ScreenShot](http://i1.ytimg.com/vi/Y54P2N1T6-I/maxresdefault.jpg)](https://www.youtube.com/watch?v=Y54P2N1T6-I)

Requirements
------------

You should have:

1. PHP 5.4+
2. Composer(accesible via `composer` command in bash)
3. Vim with +python

Installation
------------

I recommend you to use some of the popular plugin managers like pathogen,
vundle, neobundle and plug.

### Pathogen

To install it via pathogen do the following steps:
```bash
$ cd TO YOUR PLUGINS FOLDER
$ git clone https://github.com/mkusher/padawan.vim.git
$ cd padawan.vim
$ git submodule update --init --recursive
$ sh install.sh
```

### Plug
Add this to your vimrc
```vim
Plug 'mkusher/padawan.vim', { 'do': './install.sh' }
```

How to use
==========

- Run index generation command in your php composer
project folder using this vim command:
```vim
:PadawanGenerateIndex
```
- Start padawan's server with:
```vim
:PadawanStartServer
```
- Enjoy smart completion

It can take a while. You should generate index manually for each of your
project only one time.

Autocomplete engines
-------------------

### [YouCompleteMe](https://github.com/Valloric/YouCompleteMe)

You should set semantic triggers like
```vim
let g:ycm_semantic_triggers = {}
let g:ycm_semantic_triggers.php =
\ ['->', '::', '(', 'use ', 'namespace ', '\']
```

### [Neocomplete](https://github.com/Shougo/neocomplete.vim)

You should set omni input patterns like
```vim
let g:neocomplete#force_omni_input_patterns = {}
let g:neocomplete#force_omni_input_patterns.php =
\ '\h\w*\|[^- \t]->\w*'
```

Plugins(Extensions)
-------------------

You can extend padawan.php by installing different plugins.
See [Plugins List](https://github.com/mkusher/padawan.php/wiki/Plugins-list)
for more info.

### Installing
To install plugin run `:PadawanAddPlugin PLUGIN_NAME`, for example:
```vim
:PadawanAddPlugin mkusher/padawan-symfony
```

### Removing
To remove plugin run `:PadawanRemovePlugin PLUGIN_NAME`, for example:
```vim
:PadawanRemovePlugin mkusher/padawan-symfony
```

Configuring
-----------

You may want to change composer to the one installed in your system.
You can do it using:
```vim
let g:padawan#composer_command = 'php /usr/bin/composer.phar'
```
Another option you may want to change is http request timeout.
You can do it using
```vim
let g:padawan#timeout = 0.1
```
It will set timeout to 100 ms.

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

