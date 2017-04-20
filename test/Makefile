#
# Makefile to run all tests
#

VIMPROG = vim

# The list of tests is common to all systems.
# This defines NEW_TESTS.
include Make_all.mak

.SUFFIXES: .res .vim

#all:	newtests report
all:	newtestssilent report

report:
	@echo
	@echo 'Test results:'
	@/bin/sh -c "if test -f test.log; \
		then cat test.log; echo TEST FAILURE; exit 1; \
		else echo ALL DONE; \
		fi"

clean:
	-rm -rf *.res test.log messages
	-rm -rf pack
nolog:
	-rm -f test.log messages


# New style of tests uses Vim script with assert calls.  These are easier
# to write and a lot easier to read and debug.
# Limitation: Only works with the +eval feature.
RUN_VIMTEST = $(VIMPROG) -u NONE

newtests: newtestssilent
	@/bin/sh -c "if test -f messages && grep -q 'SKIPPED\|FAILED' messages; then cat messages && if test -f test.log; then cat test.log; fi ; fi"

newtestssilent: $(NEW_TESTS)


.vim.res:
	@echo "$(RUN_VIMTEST)" > vimcmd
	$(RUN_VIMTEST) $(NO_INITS) -S runtest.vim $*.vim
	@rm vimcmd

# vim: ts=8 sw=8 sts=8
