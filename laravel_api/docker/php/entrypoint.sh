#!/bin/sh

set -eu

# palm_images is a named volume, so its ownership is not affected by the
# Dockerfile's build-time chown. Prepare it before PHP-FPM drops privileges to
# www-data. This also keeps the queue worker and future volume recreations
# consistent with the web process.
mkdir -p /var/www/html/storage/app/palms
chown -R www-data:www-data /var/www/html/storage/app/palms

exec "$@"
