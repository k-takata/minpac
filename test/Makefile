#
# Makefile to run all tests
#

VIMPROG = vim

# Comment out this line to see the verbose output of tests.
#
# Catches SwapExists to avoid hanging at the ATTENTION prompt.
REDIR_TEST_TO_NULL = --cmd 'au SwapExists * let v:swapchoice = "e"' | LC_ALL=C LANG=C LANGUAGE=C awk '/Executing Test_/{match($$0, "Executing Test_[^\\)]*\\)"); print substr($$0, RSTART, RLENGTH) "\r"; fflush()}'

# The list of tests is common to all systems.
# This defines NEW_TESTS and NEW_TESTS_RES.
include Make_all.mak


.SUFFIXES: .res .vim

all:	nolog newtests report

report:
	@# without the +eval feature test_result.log is a copy of test.log
	@/bin/sh -c "if test -f test.log; \
		then cp test.log test_result.log; \
		else echo No failures reported > test_result.log; \
		fi"
	$(VIMPROG) -u NONE $(NO_INITS) -S summarize.vim messages $(REDIR_TEST_TO_NULL)
	@echo
	@echo 'Test results:'
	@cat test_result.log
	@/bin/sh -c "if test -f test.log; \
		then echo TEST FAILURE; exit 1; \
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

# Delete files that may interfere with running tests.  This includes some files
# that may result from working on the tests, not only from running them.
clean:
	-rm -rf *.out *.failed *.res *.rej *.orig XfakeHOME Xdir1 Xfind
	-rm -f opt_test.vim test.log test_result.log messages
	-rm -f $(RM_ON_RUN) $(RM_ON_START)
	-rm -f valgrind.*
	-rm -f asan.*

nolog:
	-rm -f test.log test_result.log messages


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
