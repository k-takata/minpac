#
# Makefile to run all tests
#

VIMPROG = vim

# Comment out this line to see the verbose output of tests.
#
# Catches SwapExists to avoid hanging at the ATTENTION prompt.
REDIR_TEST_TO_NULL = --cmd 'au SwapExists * let v:swapchoice = "e"' > /dev/null

# The list of tests is common to all systems.
# This defines NEW_TESTS.
include Make_all.mak

.SUFFIXES: .res .vim

all:	nolog newtests report

report:
	@echo
	@echo 'Test results:'
	@/bin/sh -c "if test -f test.log; \
		then cat test.log; echo TEST FAILURE; exit 1; \
		else echo ALL DONE; \
		fi"

# Execute an individual new style test, e.g.:
# 	make test_largefile
$(NEW_TESTS):
	rm -f $@.res test.log messages
	@MAKEFLAGS=--no-print-directory $(MAKE) -f Makefile $@.res VIMPROG=$(VIMPROG) XXDPROG=$(XXDPROG) SCRIPTSOURCE=$(SCRIPTSOURCE)
	@cat messages
	@if test -f test.log; then \
		exit 1; \
	fi

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
	@if test -f messages; then cat messages; fi

newtestssilent: $(NEW_TESTS_RES)


.vim.res:
	@echo "$(VIMPROG)" > vimcmd
	@echo "$(RUN_VIMTEST)" >> vimcmd
	$(RUN_VIMTEST) $(NO_INITS) -S runtest.vim $*.vim $(REDIR_TEST_TO_NULL)
	@rm vimcmd

# vim: ts=8 sw=8 sts=8
