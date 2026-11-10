# Scribe OnlyOffice Document Server overlay.
#
# Layers the Twake Scribe plugin of Twake Drive (sdkjs-plugins/twake-scribe) onto
# a base OnlyOffice image. The plugin runs on the stock editor API: no sdkjs is
# replaced.
#
# The build context (twake-scribe/) is assembled by build-scribe.sh.
# BASE_IMAGE selects the foundation: point it at stock
# onlyoffice/documentserver:9.4.0.1 or at the analytics-free image from this repo.

ARG BASE_IMAGE=onlyoffice/documentserver:9.4.0.1
FROM ${BASE_IMAGE}

# The Document Server finds the plugin in the folder alone, with no registration
# step.
COPY twake-scribe/ /var/www/onlyoffice/documentserver/sdkjs-plugins/twake-scribe/
