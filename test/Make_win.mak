#
# Makefile to run all tests, on MS-Windows.
#

VIMPROG = vim

# The list of tests is common to all systems.
# This defines NEW_TESTS.
!include Make_all.mak

.SUFFIXES: .res .vim

all:	nolog newtests report

report:
	@echo.
	@echo Test results:
	@if exist test.log ( type test.log & echo TEST FAILURE & exit /b 1 ) \
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

clean:
	-del *.res
	-if exist test.log del test.log
	-if exist messages del messages
	-if exist pack rd /s /q pack

nolog:
	-if exist test.log del test.log
	-if exist messages del messages


# New style of tests uses Vim script with assert calls.  These are easier
# to write and a lot easier to read and debug.
# Limitation: Only works with the +eval feature.

newtests: newtestssilent
	@if exist messages type messages

newtestssilent: $(NEW_TESTS_RES)

.vim.res:
	@echo "$(VIMPROG)" > vimcmd
	$(VIMPROG) -u NONE $(NO_INITS) -S runtest.vim $*.vim
	@del vimcmd

# vim: ts=8 sw=8 sts=8
