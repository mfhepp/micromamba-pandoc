#!/bin/sh

usage ()
{
    printf 'Generates all parameters for the docker image\n'
    printf 'Usage: %s ACTION [OPTIONS] [EXTRA BUILD ARGS]\n\n' "$0"
    printf 'Actions:\n'
    printf '\tbuild: build and tag the image\n'
    printf '\tpush: push the tags to Docker Hub\n'
    printf 'Options:\n'
    printf '  -c: targeted pandoc commit, e.g. 2.9.2.1\n'
    printf '  -d: directory\n'
    printf '  -r: targeted image repository/flavor, e.g. core or latex\n'
    printf '  -t: docker build target\n'
    printf '  -v: increase verbosity\n'
}

if ! args=$(getopt 'c:d:pr:t:v' "$@"); then
    usage && exit 1
fi
# The variable is intentionally left unquoted.
# shellcheck disable=SC2086
set -- $args

directory=.
pandoc_commit=main
repo=core
stack=micromamba
target=${stack}-${repo}
verbosity=0

while true; do
    case "$1" in
        (-c)
            pandoc_commit="${2}"
            shift 2
            ;;
        (-d)
            directory="${2}"
            shift 2
            ;;
        (-r)
            repo="${2}"
            shift 2
            ;;
        (-t)
            target="${2}"
            shift 2
            ;;
        (-v)
            verbosity=$((verbosity + 1))
            shift 1
            ;;
        (--)
            shift
            break
            ;;
        (*)
            printf 'Unknown option: %s\n' "$1"
            usage
            exit 1
            ;;
    esac
done

### Actions
action=${1}
shift

pandoc_version=${pandoc_commit}
if [ "$pandoc_commit" = "main" ]; then
    pandoc_version=edge
fi


base_image_version="latest"
# tag_versions=$(version_table_field 3)
texlive_version=2004
lua_version=5.4

# Crossref
extra_packages=pandoc-crossref
without_crossref=

# Debug output
if [ "$verbosity" -gt 0 ]; then
    printf 'Building with these parameters:\n'
    printf '\tpandoc_commit: %s\n' "$pandoc_commit"
    printf '\tstack: %s\n' "$stack"
    printf '\tbase_image_version: %s\n' "$base_image_version"
    printf '\ttag_versions: %s\n' "$tag_versions"
    printf '\ttexlive_version: %s\n' "$texlive_version"
    printf '\tlua_version: %s\n' "$lua_version"
    printf '\tverbosity: %s\n' "${verbosity}"
    printf '\textra_packages: %s\n' "$extra_packages"
    printf '\twithout_crossref: %s\n' "${without_crossref}"
    printf '\tversion_table_file: %s\n' "${version_table_file}"
fi

# ARG 1: pandoc version
# ARG 2: stack
image_name ()
{
    if [ -z "$2" ]; then
        printf 'pandoc/%s:%s' "$repo" "${1:-edge}"
    else
        printf 'pandoc/%s:%s-%s' "$repo" "${1:-edge}" "$2"
    fi
}

case "$action" in
    (push)
        for tag in $(tags); do
            printf 'Pushing %s...\n' "$tag"
            docker push "${tag}" ||
                exit 5
        done
        ;;
    (build)
        ## build images
        # The use of $(tag_arguments) is correct here
        # shellcheck disable=SC2046
        docker build "$@" \
               $(tag_arguments) \
               --build-arg pandoc_commit="${pandoc_commit}" \
               --build-arg pandoc_version="${pandoc_version}" \
               --build-arg without_crossref="${without_crossref}" \
               --build-arg extra_packages="${extra_packages}"\
               --build-arg base_image_version="${base_image_version}" \
               --build-arg texlive_version="${texlive_version}" \
               --build-arg texlive_mirror_url="${TEXLIVE_MIRROR_URL}" \
               --build-arg lua_version="${lua_version}" \
               --target "${target}"\
               -f "${directory}/${stack}/Dockerfile"\
               "${directory}"
        ;;
    (*)
        printf 'Unknown action: %s\n' "$action"
        exit 2
        ;;
esac