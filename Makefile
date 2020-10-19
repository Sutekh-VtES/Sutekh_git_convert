# Makefile for sutekh conversion using reposurgeon
#
# Steps to using this:
# 1. Make sure reposurgeon and repotool are on your $PATH.
#    For large repositories It is usually best to run reposurgeon using
#    PyPy: set REPOSURGEON to "pypy" followed by an absolute pathname
#    to reposurgeon.
# 2. (Skip this step if you're starting from a stream file.) For svn, set
#    REMOTE_URL to point at the remote repository you want to convert.
#    If the repository is already in a DVCS such as hg or git,
#    set REMOTE_URL to either the normal cloning URL (starting with hg://,
#    git://, etc.) or to the path of a local clone.
# 3. For cvs, set CVS_HOST to the repo hostname and CVS_MODULE to the module,
#    then uncomment the line that builds REMOTE_URL 
#    Note: for CVS hosts other than Sourceforge or Savannah you will need to 
#    include the path to the CVS modules directory after the hostname.
# 4. Set any required read options, such as --user-ignores or --nobranch,
#    by setting READ_OPTIONS.
# 5. Run 'make stubmap' to create a stub author map.
# 6. (Optional) set REPOSURGEON to point at a faster cython build of the tool.
# 7. Run 'make' to build a converted repository.
#
# The reason both first- and second-stage stream files are generated is that,
# especially with Subversion, making the first-stage stream file is often
# painfully slow. By splitting the process, we lower the overhead of
# experiments with the lift script.
#
# For a production-quality conversion you will need to edit the map
# file and the lift script.  During the process you can set EXTRAS to
# name extra metadata such as a comments mailbox.
#
# Afterwards, you can use the headcompare and tagscompare productions
# to check your work.
#

EXTRAS = pre-convert-step post-convert-step
REMOTE_URL = http://svn.code.sf.net/p/sutekh/code
#REMOTE_URL = https://sutekh.googlecode.com/svn/
CVS_HOST = sutekh.cvs.sourceforge.net
#CVS_HOST = cvs.savannah.gnu.org
CVS_MODULE = sutekh
#REMOTE_URL = cvs://$(CVS_HOST)/sutekh\#$(CVS_MODULE)
READ_OPTIONS =
VERBOSITY = "verbose 1"
REPOSURGEON = reposurgeon

# Configuration ends here

.PHONY: local-clobber remote-clobber gitk gc compare clean dist stubmap
# Tell make not to auto-remove tag directories, because it only tries rm 
# and hence fails
.PRECIOUS: sutekh-%-checkout sutekh-%-git

default: sutekh-git

# Build the converted repo from the second-stage fast-import stream
sutekh-git: sutekh.fi
	rm -fr sutekh-git; $(REPOSURGEON) 'read <sutekh.fi' 'prefer git' 'rebuild sutekh-git'

# Build the second-stage fast-import stream from the first-stage stream dump
sutekh.fi: filter-branches sutekh.opts sutekh.lift sutekh.map $(EXTRAS)
	$(REPOSURGEON) $(VERBOSITY) 'script sutekh.opts' "read $(READ_OPTIONS) <sutekh.svn" 'authors read <sutekh.map' 'sourcetype svn' 'prefer git' 'script sutekh.lift' 'legacy write >sutekh.fo' 'write >sutekh.fi'

# Build the first-stage stream dump from the local mirror
sutekh.svn: sutekh-mirror
	(cd sutekh-mirror/ >/dev/null; repotool export) >sutekh.svn

# Build a local mirror of the remote repository
sutekh-mirror:
	repotool mirror $(REMOTE_URL) sutekh-mirror

# Make a local checkout of the source mirror for inspection
sutekh-checkout: sutekh-mirror
	cd sutekh-mirror >/dev/null; repotool checkout $(PWD)/sutekh-checkout

# Make a local checkout of the source mirror for inspection at a specific tag
sutekh-%-checkout: sutekh-mirror
	cd sutekh-mirror >/dev/null; repotool checkout $(PWD)/sutekh-$*-checkout $*

# Force rebuild of first-stage stream from the local mirror on the next make
local-clobber: clean
	rm -fr sutekh.fi sutekh-git *~ .rs* sutekh-conversion.tar.gz sutekh-*-git

# Force full rebuild from the remote repo on the next make.
remote-clobber: local-clobber
	rm -fr sutekh.svn sutekh-mirror sutekh-checkout sutekh-*-checkout

# Get the (empty) state of the author mapping from the first-stage stream
stubmap: sutekh.svn
	$(REPOSURGEON) "read $(READ_OPTIONS) <sutekh.svn" 'authors write >sutekh.map'

# Compare the histories of the unconverted and converted repositories at head
# and all tags.
EXCLUDE = -x CVS -x .svn -x .git
EXCLUDE += -x .svnignore -x .gitignore
headcompare: sutekh-mirror sutekh-git
	repotool compare $(EXCLUDE) sutekh-mirror sutekh-git
tagscompare: sutekh-mirror sutekh-git
	repotool compare-tags $(EXCLUDE) sutekh-mirror sutekh-git
branchescompare: sutekh-mirror sutekh-git
	repotool compare-branches $(EXCLUDE) sutekh-mirror sutekh-git
allcompare: sutekh-mirror sutekh-git
	repotool compare-all $(EXCLUDE) sutekh-mirror sutekh-git

# General cleanup and utility
clean:
	rm -fr *~ .rs* sutekh-conversion.tar.gz *.svn *.fi *.fo

# Bundle up the conversion metadata for shipping
SOURCES = Makefile sutekh.lift sutekh.map $(EXTRAS)
sutekh-conversion.tar.gz: $(SOURCES)
	tar --dereference --transform 's:^:sutekh-conversion/:' -czvf sutekh-conversion.tar.gz $(SOURCES)

dist: sutekh-conversion.tar.gz

filter-branches: sutekh.svn
	./pre-convert-step

fix-tags:
	./post-convert-step

#
# The following productions are git-specific
#

# Browse the generated git repository
gitk: sutekh-git
	cd sutekh-git; gitk --all

# Run a garbage-collect on the generated git repository.  Import doesn't.
# This repack call is the active part of gc --aggressive.  This call is
# tuned for very large repositories.
gc: sutekh-git
	cd sutekh-git; time git -c pack.threads=1 repack -AdF --window=1250 --depth=250
