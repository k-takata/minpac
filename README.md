[![Build Status](https://travis-ci.org/k-takata/minpac.svg?branch=master)](https://travis-ci.org/k-takata/minpac)
[![Build status](https://ci.appveyor.com/api/projects/status/qakftqoyx5m47ns3/branch/master?svg=true)](https://ci.appveyor.com/project/k-takata/minpac/branch/master)

minpac: A minimal package manager for Vim 8 (and Neovim)
========================================================

Overview
--------

Minpac is a minimal package manager for Vim 8 (and Neovim). This uses the
[packages](http://vim-jp.org/vimdoc-en/repeat.html#packages) feature and
the [jobs](http://vim-jp.org/vimdoc-en/channel.html#job-channel-overview)
feature which have been newly added on Vim 8.

Concept
-------

* Utilize Vim 8's packages feature.
* Parallel install/update using Vim 8's jobs feature.
* Simple.
* Fast.


Requirements
------------

* Vim 8.0.0050+ (or Neovim 0.2+)
* Git 1.9+
* OS: Windows, Linux or macOS


Installation
------------

Minpac should be installed under `pack/minpac/opt/` in the first directory
in the `'packpath'` option.
Plugins installed under `pack/*/start/` are automatically added to the `'runtimepath'` after `.vimrc` is sourced. However, minpac needs to be loaded before that. Therefore, minpac should be installed under "opt" directory, and should be loaded using `packadd minpac`.

### Windows

```cmd
cd /d %USERPROFILE%
git clone https://github.com/k-takata/minpac.git ^
    vimfiles\pack\minpac\opt\minpac
```

### Linux, macOS

Vim:

```sh
git clone https://github.com/k-takata/minpac.git \
    ~/.vim/pack/minpac/opt/minpac
```

Neovim (use `$XDG_CONFIG_HOME` in place of `~/.config` if set on your system):

```sh
git clone https://github.com/k-takata/minpac.git \
    ~/.config/nvim/pack/minpac/opt/minpac
```

### Sample .vimrc

#### Basic sample

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

#### Customizing 'packpath'

If you want to use `.vim` directory instead of `vimfiles` even on Windows,
you should add `~/.vim` on top of `'packpath'`:

```vim
set packpath^=~/.vim
packadd minpac

call minpac#init()
...
```

#### Advanced sample

You can write a .vimrc which can be also used even if minpac is not installed.

```vim
" Try to load minpac.
silent! packadd minpac

if !exists('*minpac#init')
  " minpac is not available.

  " Settings for plugin-less environment.
  ...
else
  " minpac is available.
  call minpac#init()
  call minpac#add('k-takata/minpac', {'type': 'opt'})

  " Additional plugins here.
  ...

  " Plugin settings here.
  ...
endif

" Common settings here.
...
```

#### Load minpac on demand

Very interestingly, minpac doesn't need to be loaded every time. Unlike other plugin managers, it is needed only when updating, installing or cleaning the plugins. This is because minpac itself doesn't handle the runtime path.
You can define a user command to load minpac, reload .vimrc to register the information of plugins, then call `minpac#update()` or `minpac#clean()`.

```vim
" For a paranoia.
" Normally `:set nocp` is not needed, because it is done automatically
" when .vimrc is found.
if &compatible
  " `:set nocp` has many side effects. Therefore this should be done
  " only when 'compatible' is set.
  set nocompatible
endif

if exists('*minpac#init')
  " minpac is loaded.
  call minpac#init()
  call minpac#add('k-takata/minpac', {'type': 'opt'})

  " Additional plugins here.
  call minpac#add('vim-jp/syntax-vim-ex')
  ...
endif

" Plugin settings here.
...

" Define user commands for updating/cleaning the plugins.
" Each of them loads minpac, reloads .vimrc to register the
" information of plugins, then performs the task.
command! PackUpdate packadd minpac | source $MYVIMRC | call minpac#update()
command! PackClean  packadd minpac | source $MYVIMRC | call minpac#clean()
```

Note that your .vimrc must be reloadable to use this. E.g.:

* `:set nocompatible` should not be executed twice to avoid side effects.
* `:function!` should be used to define a user function.
* `:command!` should be used to define a user command.
* `:augroup!` should be used properly to avoid the same autogroups are defined twice.


Usage
-----

### Commands

Minpac doesn't provide any commands. Use the `:call` command to call minpac
functions. E.g.:

```vim
" To install or update plugins:
call minpac#update()

" To uninstall unused plugins:
call minpac#clean()
```


### Functions

#### minpac#init([{config}])

Initialize minpac.

`{config}` is a Dictionary of options for configuring minpac.

| option    | description |
|-----------|-------------|
| `'dir'`   | Base directory. Default: the first directory of the `'packpath'` option. |
| `'package_name'` | Package name. Default: `'minpac'` |
| `'git'`   | Git command. Default: `'git'` |
| `'depth'` | Default clone depth. Default: 1 |
| `'jobs'`  | Maximum job numbers. If <= 0, unlimited. Default: 8 |
| `'verbose'` | Verbosity level (0 to 3). Default: 1 |

All plugins will be installed under the following directories:

    "start" plugins: <dir>/pack/<package_name>/start/<plugin_name>
    "opt" plugins:   <dir>/pack/<package_name>/opt/<plugin_name>


"start" plugins will be automatically loaded after processing your `.vimrc`, or you can load them explicitly using `:packloadall` command.
"opt" plugins can be loaded with `:packadd` command.
See `:help packages` for detail.

#### minpac#add({url}[, {config}])

Register a plugin.

`{url}` is a URL of a plugin. It can be a short form (`'<github-account>/<repository>'`) or a valid git URL.
Note: Unlike Vundle, a short form without `<github-account>/` is not supported. (Because vim-scripts.org is not maintained now.)

`{config}` is a Dictionary of options for configuring the plugin.

| option     | description |
|------------|-------------|
| `'name'`   | Unique name of the plugin (`plugin_name`). Also used as a local directory name. Default: derived from the repository name. |
| `'type'`   | Type of the plugin. `'start'` or `'opt'`. Default: `'start'` |
| `'frozen'` | If 1, the plugin will not be updated automatically. Default: 0 |
| `'depth'`  | If >= 1, it is used as a depth to be cloned. Default: 1 or specified value by `minpac#init()`. |
| `'branch'` | Used as a branch name to be cloned. Default: empty |
| `'do'`     | Post-update hook. See [Post-update hooks](#post-update-hooks). Default: empty |

#### minpac#update([{name}[, {config}]])

Install or update all plugins or the specified plugin.

`{name}` is a unique name of a plugin (`plugin_name`).

If `{name}` is omitted or an empty String, all plugins will be installed or updated. Frozen plugins will be installed, but it will not be updated.

If `{name}` is specified, only specified plugin will be installed or updated. Frozen plugin will be also updated.
`{name}` can also be a list of plugin names.

`{config}` is a Dictionary of options for configuring the function.

| option | description |
|--------|-------------|
| `'do'` | Finish-update hook. See [Finish-update hooks](#finish-update-hooks). Default: empty |

You can check the results with `:message` command.

Note: This resets the 'more' option temporarily to avoid jobs being interrupted.

#### minpac#clean([{name}])

Remove all plugins which are not registered, or remove the specified plugin.

`{name}` is a name of a plugin. It can be a unique plugin name (`plugin_name`) or a plugin name with wildcards (`*` and `?` are supported).

If `{name}` is omitted, all plugins under the `minpac` directory will be checked. If unregistered plugins are found, they are listed and a prompt is shown. If you type `y`, they will be removed.

If `{name}` is specified, matched plugins are listed (even they are registered with `minpac#add()`) and a prompt is shown. If you type `y`, they will be removed.
`{name}` can also be a list of plugin names.

#### minpac#getpluginfo({name})

Get information of specified plugin.

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

#### minpac#getpackages([{packname}[, {packtype}[, {plugname}[, {nameonly}]]]])

Get a list of plugins under the package directories.

`{packname}` specifies a package name. Wildcards can be used. If omitted or an empty string is specified, `"*"` is used.

`{packtype}` is a type of the package. `"*"`, `"start"`, `"opt"` or `"NONE"` can be used.
If `"*"` is specified, both start and opt packages are listed.
If omitted or an empty string is specified, `"*"` is used.
If `"NONE"` is specified, package directories are listed instead of plugin directories.

`{plugname}` specifies a plugin name. Wildcards can be used. If omitted or an empty string is specified, `"*"` is used.

If `{nameonly}` is 1, plugin (or package) names are listed instead of the direcotries. Default is 0.

E.g.:

```vim
" List the all plugin directories under the package directories.
" Includes plugins under "dist" package.
echo minpac#getpackages()

" List directories of "start" plugins under "minpac" package.
echo minpac#getpackages("minpac", "start")

" List plugin names under "minpac" package.
echo minpac#getpackages("minpac", "", "", 1)

" List package names.
echo minpac#getpackages("", "NAME", "", 1)
```


### Hooks

Currently, minpac supports two types of hook: Post-update hooks and Finish-update hooks.


#### Post-update hooks

If a plugin requires extra works (e.g. building a native module), you can use the post-update hooks.

You can specify the hook with the `'do'` item in the option of the `minpac#add()` function. It can be a String or a Funcref.
If a String is specified, it is executed as an Ex command.
If a Funcref is specified, it is called with two arguments; `hooktype` and `name`.

| argument   | description |
|------------|-------------|
| `hooktype` | Type of the hook. `'post-update'` for post-update hooks.  |
| `name`     | Unique name of the plugin. (`plugin_name`) |

The current directory is set to the directory of the plugin, when the hook is invoked.

E.g.:

```vim
" Execute an Ex command as a hook.
call minpac#add('Shougo/vimproc.vim', {'do': 'silent! !make'})

" Execute a lambda function as a hook.
" Parameters for a lambda can be omitted, if you don't need them.
call minpac#add('Shougo/vimproc.vim', {'do': {-> system('make')}})

" Of course, you can also use a normal user function as a hook.
function! s:hook(hooktype, name)
  echom a:hooktype
  " You can use `minpac#getpluginfo()` to get the information about
  " the plugin.
  echom 'Directory:' minpac#getpluginfo(a:name).dir
  call system('make')
endfunction
call minpac#add('Shougo/vimproc.vim', {'do': function('s:hook')})
```

The above examples execute the "make" command synchronously. If you want to execute an external command asynchronously, you should use the `job_start()` function on Vim 8 or the `jobstart()` function on Neovim.
You may also want to use the `minpac#job#start()` function, but this is mainly for internal use and the specification is subject to change without notice.

#### Finish-update hooks

If you want to execute extra works after all plugins are updated, you can use the finish-update hooks.

You can specify the hook with the `'do'` item in the option of the `minpac#update()` function. It can be a String or a Funcref.
If a String is specified, it is executed as an Ex command.
If a Funcref is specified, it is called with three arguments; `hooktype`, `updated` and `installed`.

| argument   | description |
|------------|-------------|
| `hooktype` | Type of the hook. `'finish-update'` for finish-update hooks.  |
| `updated`  | Number of the updated plugin. |
| `installed`| Number of the newly installed plugin. |

E.g.:

```vim
" Quit Vim immediately after all updates are finished.
call minpac#update('', {'do': 'quit'})
```

Similar projects
----------------

There are some other plugin managers built on top of the Vim 8's packages feature.

* [pack](https://github.com/maralla/pack): written in Rust
* [infect](https://github.com/csexton/infect): written in Ruby
* [vim-pck](https://github.com/nicodebo/vim-pck): written in Python
* [vim8-pack](https://github.com/mkarpoff/vim8-pack): written in Bash
* [volt](https://github.com/vim-volt/volt): written in Go


Credit
------

Prabir Shrestha (as the author of [async.vim](https://github.com/prabirshrestha/async.vim))


License
-------

VIM License

(`autoload/minpac/job.vim` is the MIT License.)
