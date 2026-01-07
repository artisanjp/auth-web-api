#!/bin/sh

# Fail fast
set -e

# Set up notifier config based on USE_SMTP env var
NOTIFIER_CONFIG="/tmp/notifier.yml"
MAIN_CONFIG="/tmp/configuration.yml"

echo "Debugging Env Vars:"
echo "HOST=$HOST"
echo "PUBLIC_PORT=$PUBLIC_PORT"

if [ "$USE_SMTP" = "true" ]; then
    echo "Configuring SMTP notifier..."
    cat <<EOF > "$NOTIFIER_CONFIG"
notifier:
  smtp:
    host: $SMTP_HOST
    port: $SMTP_PORT
    username: $SMTP_USERNAME
    password: $SMTP_PASSWORD
    sender: Authelia <admin@$HOST>
EOF
else
    echo "Configuring Filesystem notifier..."
    cat <<EOF > "$NOTIFIER_CONFIG"
notifier:
  filesystem:
    filename: /data/notification.txt
EOF
fi

# Pre-process configuration.yml to handle variables manually
# We use sed to replace the specific templates we used.
# We are doing this because Authelia's native templating seems to be having issues with URL validation.
echo "Processing configuration template..."
cp /config/configuration.yml "$MAIN_CONFIG"

# Replace {{ env "HOST" }}
sed -i "s/{{ env \"HOST\" }}/$HOST/g" "$MAIN_CONFIG"

# Replace {{ env "PUBLIC_PORT" }}
sed -i "s/{{ env \"PUBLIC_PORT\" }}/$PUBLIC_PORT/g" "$MAIN_CONFIG"

# Run Authelia with processed configs
echo "Starting Authelia..."
exec authelia --config "$MAIN_CONFIG" --config "$NOTIFIER_CONFIG"
