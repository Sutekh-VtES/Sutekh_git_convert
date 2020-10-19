Sutekh git conversion
=====================

Tools used to convert Sutekh's SVN repository into a git version

Dependencies
------------

* reposurgeon

Steps
-----

# Copy the subversion repo
$ `make sutekh-mirror`
# Do the conversion
$ `make`
# Post conversion tag name fixes
$ `make fix-tags`

The `make` step will run several stages - the most important one for the conversion is the
`filter-branches` step. The results of that can be tweaked by editing the `pre-convert-step`
script.

`post-convert-step` is called by `make fix-tags` to rename the generated tags back to the
conventions of the SVN repository.
