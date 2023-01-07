#!/bin/sh

cd "${GITHUB_WORKSPACE}/${WORKDIR}" || exit 1

TEMP_PATH="$(mktemp -d)"
PREV_PATH=$PATH
PATH="${TEMP_PATH}:$PATH"
export REVIEWDOG_GITHUB_API_TOKEN="${GITHUB_TOKEN}"

echo '::group:: Installing reviewdog 🐶... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/master/install.sh | sh -s -- -b "${TEMP_PATH}" "latest" 2>&1
echo '::endgroup::'

echo '::group:: phpcs'
echo "Using: $(./vendor/squizlabs/php_codesniffer/bin/phpcs --version)"
echo '::endgroup::'

echo '::group:: Running phpcs with reviewdog 🐶...'
if [ "${REVIEWDOG_REPORTER}" = 'github-pr-review' ]; then
  composer run "${COMPOSER_COMMAND}" \
      | jq -r ' .files | to_entries[] | .key as $path | .value.messages[] as $msg | "\($path):\($msg.line):\($msg.column):`\($msg.source)`<br>\($msg.message)" ' \
      | reviewdog -efm="%f:%l:%c:%m" -name="phpcs" -reporter="${REVIEWDOG_REPORTER}" -filter-mode="${REVIEWDOG_FILTER_MODE}" -fail-on-error="${REVIEWDOG_FAIL_ON_ERROR}" -level="${REVIEWDOG_LEVEL}" -diff="git diff"
  else
    composer run "${COMPOSER_COMMAND}" \
      | reviewdog -f="checkstyle" -name="phpcs" -reporter="${REVIEWDOG_REPORTER}" -filter-mode="${REVIEWDOG_FILTER_MODE}" -fail-on-error="${REVIEWDOG_FAIL_ON_ERROR}" -level="${REVIEWDOG_LEVEL}"
fi

output=$?
echo '::endgroup::'

echo '::group:: Removing rewiewdog 🐶 files...'
PATH="$PREV_PATH"
rm -rf "$TEMP_PATH"
echo '::endgroup::'

exit $output
