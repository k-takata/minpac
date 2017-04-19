
func Test_minpac()
  call minpac#init()
  call assert_true(isdirectory('pack/minpac/start'))
  call assert_true(isdirectory('pack/minpac/opt'))

  call assert_equal(0, 1)
endfunc

" vim: set ts=8 sw=2 sts=2:
