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

Vim:

```cmd
git clone https://github.com/k-takata/minpac.git %USERPROFILE%\vimfiles\pack\minpac\opt\minpac
```

Neovim:

```cmd
git clone https://github.com/k-takata/minpac.git %LOCALAPPDATA%\nvim\pack\minpac\opt\minpac
```

### Linux, macOS

Vim:

```sh
git clone https://github.com/k-takata/minpac.git ~/.vim/pack/minpac/opt/minpac
```

Neovim (use `$XDG_CONFIG_HOME` in place of `~/.config` if set on your system):

```sh
git clone https://github.com/k-takata/minpac.git ~/.config/nvim/pack/minpac/opt/minpac
```

### Sample .vimrc

#### Basic sample

```vim
" Normally this if-block is not needed, because `:set nocp` is done
" automatically when .vimrc is found. However, this might be useful
" when you execute `vim -u .vimrc` from the command line.
if &compatible
  " `:set nocp` has many side effects. Therefore this should be done
  " only when 'compatible' is set.
  set nocompatible
endif

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

Minpac itself requires 'compatible' to be unset. However, the `if &compatible`-block is optional.

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
packadd minpac

if !exists('g:loaded_minpac')
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

Very interestingly, minpac doesn't need to be loaded every time when you execute Vim. Unlike other plugin managers, it is needed only when updating, installing or cleaning the plugins. This is because minpac itself doesn't handle the runtime path.

You can define user commands to load minpac, register the information of plugins, then call `minpac#update()`, `minpac#clean()` or `minpac#status()`.

```vim
function! PackInit() abort
  packadd minpac

  call minpac#init()
  call minpac#add('k-takata/minpac', {'type': 'opt'})

  " Additional plugins here.
  call minpac#add('vim-jp/syntax-vim-ex')
  call minpac#add('tyru/open-browser.vim')
  ...
endfunction

" Plugin settings here.
...

" Define user commands for updating/cleaning the plugins.
" Each of them calls PackInit() to load minpac and register
" the information of plugins, then performs the task.
command! PackUpdate call PackInit() | call minpac#update()
command! PackClean  call PackInit() | call minpac#clean()
command! PackStatus packadd minpac | call minpac#status()
```

If you make your .vimrc reloadable, you can reflect the setting of the .vimrc immediately after you edit it by executing `:so $MYVIMRC | PackUpdate`. Or you can define the commands like this:

```vim
command! PackUpdate source $MYVIMRC | call PackInit() | call minpac#update()
command! PackClean  source $MYVIMRC | call PackInit() | call minpac#clean()
command! PackStatus packadd minpac | call minpac#status()
```

To make your .vimrc reloadable:

* `:set nocompatible` should not be executed twice to avoid side effects.
* `:function!` should be used to define a user function.
* `:command!` should be used to define a user command.
* `:augroup!` should be used properly to avoid the same autogroups are defined twice.


Sometimes, you may want to open a shell at the directory where a plugin is installed.  The following example defines a command to open a terminal window at the directory of a specified plugin.  (Requires Vim 8.0.902 or later.)

```vim
function! PackList(...)
  call PackInit()
  return join(sort(keys(minpac#getpluglist())), "\n")
endfunction

command! -nargs=1 -complete=custom,PackList
      \ PackOpenDir call PackInit() | call term_start(&shell,
      \    {'cwd': minpac#getpluginfo(<q-args>).dir,
      \     'term_finish': 'close'})
```

If you execute `:PackOpenDir minpac`, it will open a terminal window at `~/.vim/pack/minpac/opt/minpac` (or the directory where minpac is installed).

To define a command to open the repository of a plugin in a web browser:

```vim
command! -nargs=1 -complete=custom,PackList
      \ PackOpenUrl call PackInit() | call openbrowser#open(
      \    minpac#getpluginfo(<q-args>).url)
```

This uses [open-browser.vim](https://github.com/tyru/open-browser.vim).


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

" To see plugins status:
call minpac#status()
```

Or define commands by yourself as described in the previous section.


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
| `'verbose'` | Verbosity level (0 to 4).<br/>0: Show only important messages.<br/>1: Show the result of each plugin.<br/>2: Show error messages from external commands.<br/>3: Show start/end messages for each plugin.<br/>4: Show debug messages.<br/>Default: 2 |
| `'confirm'` | Show interactive confirmation prompts, such as in `minpac#clean()`.<br/>Default: TRUE |
| `'progress_open'` | Specify how to show the progress of `minpac#update()`.<br/>`'none'`: Do not open the progress window. (Compatible with minpac v2.0.x or earlier.)<br/>`'horizontal'`: Open the progress window by splitting horizontally.<br/>`'vertical'`: Open the progress window by splitting vertically.<br/>`'tab'`: Open the progress window in a new tab.<br/>Default: `'horizontal'` |
| `'status_open'` | Default setting for the open option of `minpac#status()`. Default: `'horizontal'` |
| `'status_auto'` | Specify whether the status window will open automatically after `minpac#update()` is finished.<br/>TRUE: Open the status window automatically, when one or more plugins are updated or installed.<br/>FALSE: Do not open the status window automatically.<br/>Default: FALSE |

All plugins will be installed under the following directories:

    "start" plugins: <dir>/pack/<package_name>/start/<plugin_name>
    "opt" plugins:   <dir>/pack/<package_name>/opt/<plugin_name>


"start" plugins will be automatically loaded after processing your `.vimrc`, or you can load them explicitly using `:packloadall` command.
"opt" plugins can be loaded with `:packadd` command.
See `:help packages` for detail.

#### minpac#add({url}[, {config}])

Register a plugin.

`{url}` is a URL of a plugin. It can be a short form (`'<github-account>/<repository>'`) or a valid git URL.  If you use the short form, `<repository>` should not include the ".git" suffix.
Note: Unlike Vundle, a short form without `<github-account>/` is not supported. (Because vim-scripts.org is not maintained now.)

`{config}` is a Dictionary of options for configuring the plugin.

| option     | description |
|------------|-------------|
| `'name'`   | Unique name of the plugin (`plugin_name`). Also used as a local directory name. Default: derived from the repository name. |
| `'type'`   | Type of the plugin. `'start'` or `'opt'`. Default: `'start'` |
| `'frozen'` | If TRUE, the plugin will not be updated automatically. Default: FALSE |
| `'depth'`  | If >= 1, it is used as a depth to be cloned. Only effective when install the plugin newly. Default: 1 or specified value by `minpac#init()`. |
| `'branch'` | Used as a branch name to be cloned. Only effective when install the plugin newly. Default: empty |
| `'rev'`    | Commit ID, branch name or tag name to be checked out. If this is specified, `'depth'` will be ignored. Default: empty |
| `'do'`     | Post-update hook. See [Post-update hooks](#post-update-hooks). Default: empty |
| `'subdir'` | Subdirectory that contains Vim plugin. Default: empty |
| `'pullmethod'` | Specify how to update the plugin.<br/>Empty: Update with `--ff-only` option.<br/>`'autostash'`: Update with `--rebase --autostash` options.<br/>Default: empty |

The `'branch'` and `'rev'` options are slightly different.  
The `'branch'` option is used only when the plugin is newly installed. It clones the plugin by `git clone <URL> --depth=<DEPTH> -b <BRANCH>`. This is faster at the installation, but it can be slow if you want to change the branch (by the `'rev'` option) later. This cannot specify a commit ID.
The `'rev'` option is used both for installing and updating the plugin. It installs the plugin by `git clone <URL> && git checkout <REV>` and updates the plugin by `git fetch && git checkout <REV>`. This is slower because it clones the whole repository, but you can change the rev (commit ID, branch or tag) later.
So, if you want to change the branch frequently or want to specify a commit ID, you should use the `'rev'` option. Otherwise you can use the `'branch'` option.

If you include `*` in `'rev'`, minpac tries to checkout the latest tag name which matches the `'rev'`.

When `'subdir'` is specified, the plugin will be installed as usual (e.g. in `pack/minpac/start/pluginname`), however, another directory is created and a symlink (or a junction on Windows) will be created in it. E.g.:

```
ln -s pack/minpac/start/pluginname/subdir pack/minpac-sub/start/pluginname
```

This way, Vim can load the plugin from its subdirectory.


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

`{name}` is a name of a plugin. It can be a unique plugin name (`plugin_name`) or a plugin name with wildcards (`*` and `?` are supported). It can also be a list of plugin names.

If `{name}` is omitted, all plugins under the `minpac` directory will be checked. If unregistered plugins are found, they are listed and a prompt is shown. If you type `y`, they will be removed.

When called, matched plugins are listed (even they are registered with `minpac#add()`) and a prompt is shown. If you type `y`, they will be removed.
`{name}` can also be a list of plugin names. If the `'confirm'` option is not |TRUE|, the prompt will not be shown.

#### minpac#getpluginfo({name})

Get information of specified plugin.

`{name}` is a unique name of a plugin (`plugin_name`).
A dictionary with following items will be returned:

| item       | description |
|------------|-------------|
| `'name'`   | Name of the plugin.  |
| `'url'`    | URL of the plugin repository.  |
| `'dir'`    | Local directory of the plugin. |
| `'subdir'` | Subdirectory that contains Vim plugin. |
| `'frozen'` | If TRUE, the plugin is frozen. |
| `'type'`   | Type of the plugin. |
| `'depth'`  | Depth to be cloned. |
| `'branch'` | Branch name to be cloned. |
| `'rev'`    | Revision to be checked out. |
| `'do'`     | Post-update hook. |
| `'stat'`   | Status of last update. |

#### minpac#getpluglist()

Get a list of plugin information. Mainly for debugging.

#### minpac#getpackages([{packname}[, {packtype}[, {plugname}[, {nameonly}]]]])

Get a list of plugins under the package directories.

`{packname}` specifies a package name. Wildcards can be used. If omitted or an empty string is specified, `"*"` is used.

`{packtype}` is a type of the package. `"*"`, `"start"`, `"opt"` or `"NONE"` can be used.
If `"*"` is specified, both start and opt packages are listed.
If omitted or an empty string is specified, `"*"` is used.
If `"NONE"` is specified, package directories are listed instead of plugin directories.

`{plugname}` specifies a plugin name. Wildcards can be used. If omitted or an empty string is specified, `"*"` is used.

If `{nameonly}` is TRUE, plugin (or package) names are listed instead of the direcotries. Default is FALSE.

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

#### minpac#status([{config}])

Print status of plugins.

When ran after `minpac#update()`, shows only installed and updated plugins.

Otherwise, shows the status of the plugin and commits of last update (if any).

`{config}` is a Dictionary of options for configuring the function.

| option   | description |
|----------|-------------|
| `'open'` | Specify how to open the status window.<br/>`'vertical'`: Open in vertical split.<br/>`'horizontal'`: Open in horizontal split.<br/>`'tab'`: Open in a new tab.<br/>Default: `'horizontal'` or specified value by `minpac#init()`.  |

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

### Mappings

List of mappings available only in progress window.

| mapping | description |
|---------|-------------|
|`s`      | Open the status window. |
|`q`      | Exit the progress window. |

List of mappings available only in status window.

| mapping | description |
|---------|-------------|
|`<CR>`   | Preview the commit under the cursor. |
|`<C-j>`  | Jump to next package in list. |
|`<C-k>`  | Jump to previous package in list. |
|`q`      | Exit the status window.<br/>(Also works for commit preview window) |


Similar projects
----------------

There are some other plugin managers built on top of the Vim 8's packages feature.

* [vim-packager](https://github.com/kristijanhusak/vim-packager): written in Vim script
* [pack](https://github.com/maralla/pack): written in Rust
* [infect](https://github.com/csexton/infect): written in Ruby
* [vim-pck](https://github.com/nicodebo/vim-pck): written in Python
* [vim8-pack](https://github.com/mkarpoff/vim8-pack): written in Bash
* [volt](https://github.com/vim-volt/volt): written in Go
* [autopac](https://github.com/meldavis/autopac): modified version of minpac
* [plugpac.vim](https://github.com/bennyyip/plugpac.vim): thin wrapper of minpac, provides vim-plug like experience


Credit
------

Prabir Shrestha (as the author of [async.vim](https://github.com/prabirshrestha/async.vim))  
Kristijan Husak (status window)  


License
-------

VIM License

(`autoload/minpac/job.vim` is the MIT License.)
