#
# Makefile to run all tests, on MS-Windows.
#

VIMPROG = vim

default: all

!include Make_all.mak

.SUFFIXES: .res .vim

all:	nolog newtests report

report:
	@rem without the +eval feature test_result.log is a copy of test.log
	@if exist test.log ( copy /y test.log test_result.log > nul ) \
		else ( echo No failures reported > test_result.log )
	$(VIMPROG) -u NONE $(NO_INITS) -S summarize.vim messages
	@echo.
	@echo Test results:
	@cmd /c type test_result.log
	@if exist test.log ( echo TEST FAILURE & exit /b 1 ) \
		else ( echo ALL DONE )


# Execute an individual new style test, e.g.:
# 	nmake -f Make_dos.mak test_largefile
$(NEW_TESTS):
	-if exist $@.res del $@.res
	-if exist test.log del test.log
	-if exist messages del messages
	@$(MAKE) -nologo -f Make_win.mak $@.res VIMPROG=$(VIMPROG)
	@type messages
	@if exist test.log exit 1


# Delete files that may interfere with running tests.  This includes some files
# that may result from working on the tests, not only from running them.
clean:
	-if exist *.out del *.out
	-if exist *.failed del *.failed
	-if exist *.res del *.res
	-if exist $(DOSTMP) rd /s /q $(DOSTMP)
	-if exist test.in del test.in
	-if exist test.ok del test.ok
	-if exist Xdir1 rd /s /q Xdir1
	-if exist Xfind rd /s /q Xfind
	-if exist XfakeHOME rd /s /q XfakeHOME
	-if exist X* del X*
	-for /d %i in (X*) do @rd /s/q %i
	-if exist viminfo del viminfo
	-if exist test.log del test.log
	-if exist test_result.log del test_result.log
	-if exist messages del messages
	-if exist benchmark.out del benchmark.out
	-if exist opt_test.vim del opt_test.vim

nolog:
	-if exist test.log del test.log
	-if exist test_result.log del test_result.log
	-if exist messages del messages


# New style of tests uses Vim script with assert calls.  These are easier
# to write and a lot easier to read and debug.
# Limitation: Only works with the +eval feature.

newtests: newtestssilent
	@if exist messages type messages

newtestssilent: $(NEW_TESTS_RES)

.vim.res:
	@echo $(VIMPROG) > vimcmd
	$(VIMPROG) -u NONE $(NO_INITS) -S runtest.vim $*.vim
	@del vimcmd

# vim: ts=8 sw=8 sts=8
