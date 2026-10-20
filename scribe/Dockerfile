# Scribe-patched OnlyOffice Document Server overlay.
#
# Layers two artifacts onto a base OnlyOffice image (build 10.0.0-169):
#   • a patched sdkjs word bundle (sdk-all.js + sdk-all-min.js, with
#     ApiRun.GetInlineDrawings and Api.GetSelectionScreenRect)
#   • the Twake Scribe plugin of Twake Drive (sdkjs-plugins/twake-scribe)
#
# The build context (sdk-all.js + sdk-all-min.js + twake-scribe/) is assembled by
# build-scribe.sh. BASE_IMAGE selects the foundation: stock
# onlyoffice/documentserver:10.0.0.1 or the onlyoffice-noanalytics image from this repo.

ARG BASE_IMAGE=onlyoffice/documentserver:10.0.0.1
FROM ${BASE_IMAGE}

# Fail early if the base is not the exact OO build the compiled patch targets —
# a version-locked bundle on a different build breaks the editor.
ARG EXPECT_OO_VERSION=10.0.0-169
RUN dpkg-query -W -f='${Version}\n' onlyoffice-documentserver | grep -qx "${EXPECT_OO_VERSION}" \
    || (echo "ERROR: base OnlyOffice is not ${EXPECT_OO_VERSION} — the compiled sdkjs patch is version-locked and would break the editor." >&2; exit 1)

# Patched sdkjs word bundle. The patch lives in sdk-all.js, but the stock 10.0
# pair is closure-compiled with names renamed across both files, so the two must
# come from the same build.
COPY sdk-all-min.js sdk-all.js /var/www/onlyoffice/documentserver/sdkjs/word/

# Twake Scribe plugin, built from Twake Drive by build-scribe.sh. The Document
# Server finds it in the folder alone, with no registration step.
COPY twake-scribe/ /var/www/onlyoffice/documentserver/sdkjs-plugins/twake-scribe/
