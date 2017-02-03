minpac: A minimal package manager for Vim 8
===========================================

Overview
--------

Minpac is a minimal package manager for Vim 8. This uses the packages
feature which was newly added on Vim 8.


Requirements
------------

* Vim 8.0
* Git 1.9 or later
* OS  
  Windows: tested  
  Linux: not tested  
  macOS: not tested


Installation
------------

### Windows

```cmd
cd /d %USERPROFILE%
mkdir vimfiles\pack\minpac\opt
cd vimfiles\pack\minpac\opt
git clone https://github.com/k-takata/minpac.git
```

### Linux, macOS

```sh
mkdir -p ~/.vim/pack/minpac/opt
cd ~/.vim/pack/minpac/opt
git clone https://github.com/k-takata/minpac.git
```

### Sample .vimrc

```vim
packadd minpac

call minpac#init()

call minpac#add('k-takata/minpac', {'type': 'opt'})
call minpac#add('vim-jp/syntax-vim-ex')

" Load the plugins right now. (optional)
packloadall
```

If you want to use `.vim` directory instead of `vimfiles` even on Windows,
you should add `~/.vim` on top of `'packpath'`:

```vim
set packpath^=~/.vim
packadd minpac

call minpac#init()
...
```

Usage
-----

### Functions

#### minpac#init([{opt}])

Initialize minpac.

#### minpac#add({name}, [{opt}])

Register a plugin.

#### minpac#update([{name}])

Install or update all plugins or the specified plugin.

#### minpac#clean([{name}])

Remove all plugins which are not registered, or remove the specified plugin.


License
-------

VIM License
