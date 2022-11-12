#!/bin/bash
#
# Check for version changes between two revisions/branches.
# Takes two argument, one for current and one for comparison.
# If there's only one specified, then the specified one will be the one to compare.
#

usage() {
	cat << EOF
Usage: $0 [current_revision] revision-to-compare

Compare package versions between two revisions.
Revision can be branch, commit, or tag.
EOF
}

set -e
# Make sure we can run
if [ ! -e .git ]; then
	echo "[!] Not a Git repository. Make sure you are executing within an ABBS tree."
	exit 1
fi

if [ ! "$1" ] ; then
	echo "[!] Please specify versions to compare."
	usage
	exit 1
fi
# Make sure these specified revisions are valid
if [ ! "$2" ] ; then
	_b=`git branch --show-current`
	if [ "$?" != "0" ]; then
		echo "[!] Can not determine current branch with \`git branch'. You need to specify which current revision is."
		usage
		exit 1
	fi
	CMP_BRANCH=$1
	CUR_BRANCH=$_b
else
	CMP_BRANCH=$2
	CUR_BRANCH=$1
fi

if ! git cat-file -e $CUR_BRANCH ; then
	echo "[!] Revision $CUR_BRANCH does not exist."
	exit 1
fi

if ! git cat-file -e $CMP_BRANCH ; then
	echo "[!] Revision $CMP_BRANCH does not exist."
	exit 1
fi

CHANGED_SPECS=()

CUR_VER=
CUR_REL=

WORKDIR=$(mktemp -d)
export TMPDIR=$WORKDIR

clean() {
	rm -r $WORKDIR
	unset TMPDIR
}

trap cleanup ERR

WARNINGS=()
SKIPPEDPKGS=()
echo -e "Package                       Current Version  Version in stable"
echo "---------------------------------------------------------------------"

# Get list of files with location changes
for i in `git diff --summary  $CUR_BRANCH..$CMP_BRANCH | grep rename.*\/spec | sed -e 's/\ =>\ /,/g' -e 's/^.*rename\ //g' -e 's/\/spec.*$/\/spec/g'` ; do
	CHG=`eval echo $i`
	cur_loc=`echo $CHG | cut -d' ' -f1`
	orig_loc=`echo $CHG | cut -d' ' -f2`
	pkg=`echo $orig_loc | cut -d'/' -f2`
	WARNINGS+=("Warning: package $pkg was moved: was ${orig_loc/spec\//}, now ${cur_loc/spec\//}")
	cur_spec=$(mktemp)
	cmp_spec=$(mktemp)
	git show $CUR_BRANCH:$cur_loc > $cur_spec
	git show $CMP_BRANCH:$orig_loc > $cmp_spec
	source $cur_spec
	cur_ver=$VER
	cur_rel=${REL:-0}
	source $cmp_spec
	cmp_ver=$VER
	cmp_rel=${REL:-0}
	cur_ver="$cur_ver-$cur_rel"
	cmp_ver="$cmp_ver-$cmp_rel"
	if [ "x$cur_ver" != "x$cmp_ver" ]; then
		printf "%-30s" $pkg
		echo -e "$cur_ver\t->\t$cmp_ver"
	fi
	SKIPPEDPKGS+=($pkg)
done

for i in `git diff --name-only ${CUR_BRANCH}..${CMP_BRANCH} | grep /spec` ; do
	found=0
	for j in ${SKIPPEDPKGS[@]} ; do
		if [[ $i =~ "\/$j\/spec" ]]; then
			found=1
		fi
	done
	[ $found == 1 ] && continue
	CHANGED_SPECS+=($i)
done

for i in ${CHANGED_SPECS[@]} ; do
	pkgname=$(echo $i | cut -d'/' -f2)
	cur_spec=$(mktemp)
	cmp_spec=$(mktemp)
	git show $CUR_BRANCH:$i > $cur_spec 2>/dev/null || continue
	git show $CMP_BRANCH:$i > $cmp_spec 2>/dev/null || continue
	source $cur_spec
	cur_ver=$VER
	cur_rel=${REL:-0}
	source $cmp_spec
	cmp_ver=$VER
	cmp_rel=${REL:-0}
	cur_ver="$cur_ver-$cur_rel"
	cmp_ver="$cmp_ver-$cmp_rel"
	if [ "$cur_ver" != "$cmp_ver" ]; then
		printf "%-30s" $pkgname
		echo -e "$cur_ver\t->\t$cmp_ver"
	fi
	unset VER REL cur_ver cmp_ver cur_rel cmp_rel
done

for i in "${WARNINGS[@]}" ; do
	echo $i >&2
done

unset TMPDIR
rm -r $WORKDIR
trap ERR
