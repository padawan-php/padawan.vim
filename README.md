Padawan.vim
===========

Padawan.vim is a vim plugin for [padawan.php server
](https://github.com/mkusher/padawan.php).

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

Usage
-----

Open your php project that uses composer and then run
```
:call padawan#GenerateIndex()
```

It can take a while. You should generate index manually for each of your
project only one time. After it start server with
```
:call padawan#StartServer()
```
And that's all!

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

