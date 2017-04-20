" Tests for minpac.

set rtp^=..
set packpath=.
runtime plugin/minpac.vim


" Tests for minpac#init()
func Test_minpac_init()
  call delete('pack', 'rf')

  " NOTE: The variables g:minpac#opt and g:minpac#pluglist are not the part
  " of public APIs.  Users should not access these variables.  They should
  " be used only for testing and/or debugging.

  " Default setting
  call minpac#init()
  call assert_true(isdirectory('pack/minpac/start'))
  call assert_true(isdirectory('pack/minpac/opt'))
  call assert_equal('git', g:minpac#opt.git)
  call assert_equal(1, g:minpac#opt.depth)
  call assert_equal(8, g:minpac#opt.jobs)
  call assert_equal(0, g:minpac#opt.verbose)
  call assert_equal({}, minpac#getpluglist())
  let g:minpac#pluglist.foo = 'bar'

  " Change settings
  call minpac#init({'package_name': 'm', 'git': 'foo', 'depth': 10, 'jobs': 2, 'verbose': 1})
  call assert_true(isdirectory('pack/m/start'))
  call assert_true(isdirectory('pack/m/opt'))
  call assert_equal('foo', g:minpac#opt.git)
  call assert_equal(10, g:minpac#opt.depth)
  call assert_equal(2, g:minpac#opt.jobs)
  call assert_equal(1, g:minpac#opt.verbose)
  call assert_equal({}, minpac#getpluglist())

  call delete('pack', 'rf')
endfunc

" Tests for minpac#add() and minpac#getpluginfo()
func Test_minpac_add()
  call delete('pack', 'rf')

  call minpac#init()

  " Default
  call minpac#add('k-takata/minpac')
  let p = minpac#getpluginfo('minpac')
  call assert_equal('https://github.com/k-takata/minpac.git', p.url)
  call assert_match('/pack/minpac/start/minpac$', p.dir)
  call assert_equal(0, p.frozen)
  call assert_equal('start', p.type)
  call assert_equal('', p.branch)
  call assert_equal(1, p.depth)

  " With configuration
  call minpac#add('k-takata/minpac', {'type': 'opt', 'frozen': 1, 'branch': 'master', 'depth': 10})
  let p = minpac#getpluginfo('minpac')
  call assert_equal('https://github.com/k-takata/minpac.git', p.url)
  call assert_match('/pack/minpac/opt/minpac$', p.dir)
  call assert_equal(1, p.frozen)
  call assert_equal('opt', p.type)
  call assert_equal('master', p.branch)
  call assert_equal(10, p.depth)

  " SSH URL
  call minpac#add('git@github.com:k-takata/minpac.git', {'name': 'm'})
  let p = minpac#getpluginfo('m')
  call assert_equal('git@github.com:k-takata/minpac.git', p.url)
  call assert_match('/pack/minpac/start/m$', p.dir)

  " Non GitHub URL with ".git"
  call minpac#add('https://example.com/foo.git')
  let p = minpac#getpluginfo('foo')
  call assert_equal('https://example.com/foo.git', p.url)

  " Non GitHub URL w/o ".git"
  call minpac#add('https://example.com/bar')
  let p = minpac#getpluginfo('bar')
  call assert_equal('https://example.com/bar', p.url)

  " Wrong type
  try
    call minpac#add('k-takata/minpac', {'type': 'foo'})
  catch
    call assert_exception('echoerr')
  endtry

  call delete('pack', 'rf')
endfunc

" Tests for minpac#getpackages()
func Test_minpac_getpackages()
  call delete('pack', 'rf')

  let plugs = [
	\ './pack/minpac/start/plug0',
	\ './pack/minpac/start/plug1',
	\ './pack/minpac/opt/plug2',
	\ './pack/minpac/opt/plug3',
	\ './pack/foo/start/plug4',
	\ './pack/foo/start/plug5',
	\ './pack/foo/opt/plug6',
	\ './pack/foo/opt/plug7',
	\ ]
  for dir in plugs
    call mkdir(dir, 'p')
  endfor

  " All plugins
  let p = minpac#getpackages()
  call filter(p, {-> v:val !~# 'pack/dist'})
  call assert_equal(sort(plugs[:]), sort(p))

  " All packages
  let p = minpac#getpackages('', 'NONE')
  call filter(p, {-> v:val !~# 'pack/dist'})
  call assert_equal(['./pack/foo', './pack/minpac'], sort(p))

  " Plugins under minpac
  let p = minpac#getpackages('minpac')
  call filter(p, {-> v:val !~# 'pack/dist'})
  call assert_equal(sort(plugs[0 : 3]), sort(p))

  " 'start' plugins
  let p = minpac#getpackages('', 'start')
  call filter(p, {-> v:val !~# 'pack/dist'})
  call assert_equal(sort(plugs[0 : 1] + plugs[4 : 5]), sort(p))

  " 'opt' plugins
  let p = minpac#getpackages('*', 'opt', '')
  call filter(p, {-> v:val !~# 'pack/dist'})
  call assert_equal(sort(plugs[2 : 3] + plugs[6 : 7]), sort(p))

  " Plugins with 'plug1*' name
  let p = minpac#getpackages('', '', 'plug1*')
  call filter(p, {-> v:val !~# 'pack/dist'})
  call assert_equal(plugs[1 : 1], p)

  " No match
  let p = minpac#getpackages('minpac', 'opt', 'plug1*')
  call assert_equal([], p)

  call delete('pack', 'rf')
endfunc

" Tests for minpac#update()
func Test_minpac_update()
endfunc

" Tests for minpac#clean()
func Test_minpac_clean()
  call delete('pack', 'rf')

  call minpac#init()

  let plugs = [
	\ 'pack/minpac/start/plug0',
	\ 'pack/minpac/start/plug1',
	\ 'pack/minpac/opt/plug2',
	\ 'pack/minpac/opt/plug3',
	\ 'pack/minpac/start/minpac',
	\ 'pack/minpac/opt/minpac',
	\ ]
  for dir in plugs
    call mkdir(dir, 'p')
  endfor

  " Just type Enter. All plugins should not be removed.
  call feedkeys(":call minpac#clean()\<CR>\<CR>", 'x')
  for dir in plugs
    call assert_true(isdirectory(dir))
  endfor

  " Register some plugins
  call minpac#add('foo', {'name': 'plug0'})
  call minpac#add('bar/plug2', {'type': 'opt'})
  call minpac#add('baz/plug3')

  " Type y and Enter. Unregistered plugins should be removed.
  " 'opt/minpac' should not be removed even it is not registered.
  call feedkeys(":call minpac#clean()\<CR>y\<CR>", 'x')
  call assert_equal(1, isdirectory(plugs[0]))
  call assert_equal(0, isdirectory(plugs[1]))
  call assert_equal(1, isdirectory(plugs[2]))
  call assert_equal(0, isdirectory(plugs[3]))
  call assert_equal(0, isdirectory(plugs[4]))
  call assert_equal(1, isdirectory(plugs[5]))

  " Specify a plugin. It should be removed even it is registered.
  call feedkeys(":call minpac#clean('plug0')\<CR>y\<CR>", 'x')
  call assert_equal(0, isdirectory(plugs[0]))
  call assert_equal(1, isdirectory(plugs[2]))
  call assert_equal(1, isdirectory(plugs[5]))

  " 'opt/minpac' can be also removed when it is specified.
  call minpac#add('k-takata/minpac', {'type': 'opt'})
  call feedkeys(":call minpac#clean('minpa?')\<CR>y\<CR>", 'x')
  call assert_equal(1, isdirectory(plugs[2]))
  call assert_equal(0, isdirectory(plugs[5]))

  " Type can be also specified.
  " Not match
  call minpac#clean('start/plug2')
  call assert_equal(1, isdirectory(plugs[2]))
  " Match
  call feedkeys(":call minpac#clean('opt/plug*')\<CR>y\<CR>", 'x')
  call assert_equal(0, isdirectory(plugs[2]))

  call delete('pack', 'rf')
endfunc

" vim: ts=8 sw=2 sts=2
