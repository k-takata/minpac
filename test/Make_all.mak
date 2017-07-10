#
# Common Makefile, defines the list of tests to run.
#

# Options for protecting the tests against undesirable interaction with the
# environment
NO_PLUGINS = --noplugin # --not-a-term
NO_INITS = -U NONE $(NO_PLUGINS)

# Tests using runtest.vim.
NEW_TESTS = \
	    test_minpac.res

# vim: ts=8 sw=8 sts=8
