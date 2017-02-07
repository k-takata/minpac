minpac: A minimal package manager for Vim 8
===========================================

Overview
--------

Minpac is a minimal package manager for Vim 8. This uses the
[packages](http://vim-jp.org/vimdoc-en/repeat.html#packages) feature and
the [jobs](http://vim-jp.org/vimdoc-en/channel.html#job-channel-overview)
feature which have been newly added on Vim 8.


Requirements
------------

* Vim 8.0
* Git 1.9 or later
* OS  
  Windows: tested  
  Linux: tested  
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

" minpac must have {'type': 'opt'} so that it can be loaded with `packadd`.
call minpac#add('k-takata/minpac', {'type': 'opt'})

" Add other plugins here.
call minpac#add('vim-jp/syntax-vim-ex')
...

" Load the plugins right now. (optional)
"packloadall
```

If you want to use `.vim` directory instead of `vimfiles` even on Windows,
you should add `~/.vim` on top of `'packpath'`:

```vim
set packpath^=~/.vim
packadd minpac

call minpac#init()
...
```

You can write a .vimrc which can be also used even if minpac is not installed.

```vim
" Try to load minpac.
silent! packadd minpac

if !exists('*minpac#init')
  " minpac is not avalable.

  " Minimal settings which are used when no plugins are loaded.
  ...
else
  " minpac is avalable.
  call minpac#init()
  call minpac#add('k-takata/minpac', {'type': 'opt'})

  " Additional plugins here.
  ...

  " Plugin settings here.
  ...
endif
```


Usage
-----

### Functions

#### minpac#init([{opt}])

Initialize minpac.

`{opt}` is a Dictionary which specifies options.

| option    | description |
|-----------|-------------|
| `'dir'`   | Base directory. Default: the first directory of the `'packpath'` option. |
| `'git'`   | Git command. Default: `'git'` |
| `'package_name'` | Package name. Default: `'minpac'` |
| `'depth'` | Default clone depth. Default: 1 |
| `'jobs'`  | Maximum job numbers. Default: 8 |

All plugins will be installed under the following directory:

    "start" plugins: <dir>/pack/<package_name>/start/<plugin_name>
    "opt" plugins:   <dir>/pack/<package_name>/opt/<plugin_name>


"start" plugins will be automatically loaded after processing your `.vimrc`, or you can load them explicitly using `:packloadall` command.
"opt" plugins can be loaded with `:packadd` command.
See `:help packages` for detail.

#### minpac#add({url}, [{opt}])

Register a plugin.

`{url}` is a URL of a plugin. It can be a short form (`'<github-account>/<repository>'`) or a valid git URL.

`{opt}` is a Dictionary which specifies options.

| option     | description |
|------------|-------------|
| `'name'`   | Unique name of the plugin (`plugin_name`). Also used as a local directory name. Default: derived from the repository name. |
| `'type'`   | Type of the plugin. `'start'` or `'opt'`. Default: `'start'` |
| `'frozen'` | If 1, the plugin will not be updated automatically. Default: 0 |
| `'depth'`  | If > 1, it is used as a depth to be cloned. Default: 1 or specified value by `minpac#init()`. |
| `'branch'` | Used as a branch name to be cloned. Default: empty |

#### minpac#update([{name}])

Install or update all plugins or the specified plugin.

`{name}` is a unique name of a plugin (`plugin_name`).

If `{name}` is omitted, all plugins will be installed or updated. Frozen plugins will be installed, but it will not be updated.

If `{name}` is specified, only specified plugin will be installed or updated. Frozen plugin will be also updated.
`{name}` can also be a list of plugin names.

#### minpac#clean([{name}])

Remove all plugins which are not registered, or remove the specified plugin.

`{name}` is a name of a plugin. It can be a unique plugin name (`plugin_name`) or a plugin name with wildcards.

If `{name}` is omitted, all plugins under the `minpac` directory will be checked. If unregistered plugins are found, they are listed and a prompt is shown. If you type `y`, they will be removed.

If `{name}` is specified, matched plugins are listed (even they are registered with `minpac#add()`) and a prompt is shown. If you type `y`, they will be removed.
`{name}` can also be a list of plugin names.

#### minpac#getpluginfo({name})

Get information of specified plugin. Mainly for debugging.

`{name}` is a unique name of a plugin (`plugin_name`).
A dictionary with following items will be returned:

| item       | description |
|------------|-------------|
| `'url'`    | URL of the plugin repository.  |
| `'dir'`    | Local directory of the plugin. |
| `'frozen'` | If 1, the plugin is frozen. |
| `'type'`   | Type of the plugin. |
| `'branch'` | Branch name to be cloned. |
| `'depth'`  | Depth to be cloned. |

License
-------

VIM License
